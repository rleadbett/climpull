library(aws.s3)
library(terra)

# Load custom functions
source("./read-functions/read_ERDDAP.R", chdir = TRUE)
source("./read-functions/raster_toolbox.R", chdir = TRUE)
source("./read-functions/get_dataset.R", chdir = TRUE)

# Define the S3 bucket
s3_bucket <- get_bucket(
  key = "P0UZLYNCYTVQECBH2L9I",
  secret = "lmSS9tLy6RNQquAANZExYOizOc24RK0qJOpd6BOD",
  base_url = "projects.pawsey.org.au",
  bucket = "mma-species-distribution",
  region = ""
)

# Dataset query params
time_window <- c("2000-01-01", "2022-07-27")#"2000-01-01"
latitude_range <- c(-25, -10)
longitude_range <- c(110, 135)

# Get data from ERDDAP and convert from NetCDF to raster
wind_raster_raw <- getNOAAData(
  ds_ids = "noaacwBlendedWindsDaily",
  time_range = time_window,
  lat_range = latitude_range,
  lon_range = longitude_range,
  # The NOAA ERDDAP server has a limit of 2Gb per request
  chunks = months(8),
  url = "https://coastwatch.noaa.gov/erddap/",
  # Specify variable to retrieve
  var = "windspeed",
  # The ncdf file is too big to hold in memory and so must be split
  parts = 10
)

# Save the raw request in s3 bucket
temp_dir <- "./tmp"#tempdir()
if (!dir.exists(temp_dir)) dir.create(temp_dir, )
temp_path <- file.path(temp_dir, "raw", "wind_vel.nc")
s3_path <- file.path("raw", "wind_vel.nc")
writeCDF(wind_raster_raw, temp_path)
put_object(
  file = temp_path,
  object = s3_path,
  bucket = s3_bucket,
  region = ""
)

# Fill the NA values
wind_raster_filled <- focal(
  wind_raster_raw,
  w = 9,
  fun = mean,
  na.policy = "only",
  na.rm = TRUE
)

wind_raster_interpolated <- approximate(
  wind_raster_filled
)

aus_shape <- vect("./data/shape-files/land/STE11aAust.shp")
crs(aus_shape) <- "+proj=utm +zone=48 +datum=WGS84"
aus_shape <- crop(aus_shape, ext(wind_raster_raw))

wind_raster_interpolated <- mask(
  wind_raster_interpolated,
  aus_shape,
  inverse = TRUE,
  touches = FALSE
)

# Save the interpolated data in s3 bucket
temp_path <- file.path("tmp", "filled", "wind_vel.nc")
s3_path <- file.path("filled", "wind_vel.nc")
writeCDF(wind_raster_interpolated, temp_path)
put_object(
  file = temp_path,
  object = s3_path,
  bucket = s3_bucket,
  region = ""
)