library(aws.s3)
library(terra)

# Load custom functions
source("./read-functions/read_ERDDAP.R", chdir = TRUE)
source("./read-functions/raster_toolbox.R", chdir = TRUE)
source("./read-functions/get_dataset.R", chdir = TRUE)

# Define the S3 bucket
s3_bucket <- get_bucket(
  bucket = "mma-species-distribution",
  region = ""
)

# Dataset query params
time_window <- c("2000-01-01", "2022-07-27")#"2000-01-01"
latitude_range <- c(-25, -10)
longitude_range <- c(110, 135)

# Get data from ERDDAP and convert from NetCDF to raster
sst_raster_raw <- getNOAAData(
  ds_ids = "nceiPH53sstn1day",
  time_range = time_window,
  lat_range = latitude_range,
  lon_range = longitude_range,
  # The NOAA ERDDAP server has a limit of 2Gb per request
  chunks = months(6),
  # Specify variable to retrieve
  var = "sea_surface_temperature",
  # The ncdf file is too big to hold in memory and so must be split
  parts = 10
)

replaceNAs <- function(x) {
  x[x < 0] <- NA
  return(x)
}

tt <- time(sst_raster_raw)

sst_raster_raw <- terra::app(
  sst_raster_raw,
  replaceNAs,
  cores = 12
)

# Crop the raster file
aus_shape <- vect("./data/shape-files/land/STE11aAust.shp")
crs(aus_shape) <- "+proj=utm +zone=48 +datum=WGS84"
aus_shape <- crop(aus_shape, ext(sst_raster_raw))
sst_raster_raw <- mask(
  sst_raster_raw,
  aus_shape,
  inverse = TRUE,
  touches = FALSE
)

# Save the raw request in s3 bucket
temp_path <- file.path(tempdir(), "raw", "sst.nc")
s3_path <- file.path("raw", "sst.nc")
writeCDF(sst_raster_raw, temp_path)
put_object(
  file = temp_path,
  object = s3_path,
  bucket = s3_bucket,
  region = ""
)

# Fill the NA values
sst_raster_filled <- focal(
  sst_raster_raw,
  w = 9,
  fun = mean,
  na.policy = "only",
  na.rm = TRUE
)
sst_raster_interpolated <- approximate(
  sst_raster_filled
)
sst_raster_interpolated <- mask(
  sst_raster_interpolated,
  aus_shape,
  inverse = TRUE,
  touches = FALSE
)

# Save the interpolated data in s3 bucket
temp_path <- file.path(tempdir(), "interpolated", "sst.nc")
s3_path <- file.path("interpolated", "sst.nc")
writeCDF(sst_raster_interpolated, temp_path)
put_object(
  file = temp_path,
  object = s3_path,
  bucket = s3_bucket,
  region = ""
)

# rastStackToMov(sst_raster_interpolated, output_file = "./sst_test.gif")
# plot(sst_raster_interpolated[[15]])
# for (i in 10:20) plot(sst_raster_interpolated[[i]])
