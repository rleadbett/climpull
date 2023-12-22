library(terra)
library(ncdf4)
library(lubridate)

nc_file_dir <- file.path(".", "data", "current")
nc_files <- list.files(
  nc_file_dir,
  pattern = "*.nc",
  full.names = TRUE
)

currentNCtoRast <- function(file_path, var) {
  if (!is.character(file_path)) {
    stop("file_path must be a string.")
  } else if (!is.character(var)) {
    stop("var must be a string.")
  }
  # Open and extract dimension of netCDF4 file.
  nc <- nc_open(file_path)
  lat <- ncvar_get(nc, "latitude")
  lon <- ncvar_get(nc, "longitude")
  time_days <- ncvar_get(nc, "time")
  time_base <- ncatt_get(nc, "time", "units")$value
  date <- ymd_hms(time_base) + days(time_days)
  # Get the values of var.
  values <- ncvar_get(nc, var)
  # Create raster object and fill.
  raster_ext <- ext(c(min(lon), max(lon), min(lat), max(lat)))
  r <- rast(
    ncol = length(lon),
    nrow = length(lat),
    ext = raster_ext,
    nlyr = length(date),
    time = date
  )
  values_rot <- aperm(values, c(2, 1, 3))
  values(r) <- values_rot
  # Crop to north west shelf extent.
  #nws_ext <- ext(c(xmin = 110, xmax = 135, ymin = -25, ymax = -10))
  #r <- crop(r, nws_ext)

  return(r)
}

currentVarRast <- function(var) {
  # Convert the netCDF4 files into stacked
  # rasters and combine into a single stack.
  current_data_sets <- lapply(
    nc_files,
    function(file) currentNCtoRast(file, var)
  )
  current_data_sets <- rast(current_data_sets)
  # Append blank day to make min diff 1Day (currently 5Day).
  dummy_rast <- current_data_sets[[1:2]]
  time(dummy_rast) <- max(time(current_data_sets)) + days(c(1, 2))
  values(dummy_rast) <- NA
  current_data_sets <- c(dummy_rast, current_data_sets)
  # Fill rast using neighbors of NA values
  current_data_sets <- focal(
    current_data_sets,
    w = 3,
    fun = mean,
    na.policy = "only",
    na.rm = TRUE
  )
  # Interpolate through time to get data all days.
  current_data_sets <- fillTime(current_data_sets)
  current_data_sets <- approximate(current_data_sets)

  return(current_data_sets)
}

# Get u and v components of current from NASA netCDF4 files.
current_data_u <- currentVarRast(var = "u")
current_data_v <- currentVarRast(var = "v")

aus_shape <- vect(
  file.path(".", "data", "shape-files", "land", "STE11aAust.shp")
)

# Crop to North west shelf.
nws_ext <- ext(c(xmin = 110, xmax = 135, ymin = -25, ymax = -9))
current_data_u <- crop(current_data_u, nws_ext)
current_data_v <- crop(current_data_v, nws_ext)

writeCDF(current_data_u, "current_u.nc", overwrite = TRUE)
writeCDF(current_data_v, "current_v.nc", overwrite = TRUE)
