library(terra)

# Read raw rasters
sst_raster_stack <- rast("sst_NAs.nc")
chl_a_raster_stack <- rast("chl_a_focal.nc")
chl_a_raster_stack <- crop(chl_a_raster_stack, ext(sst_raster_stack))
wind_mag_raster_stack <- rast("wind_mag_raw.nc")
current_u_raster_stack <- rast("current_u.nc")
current_v_raster_stack <- rast("current_v.nc")
print("all files read in")

# Resample to same res as sst
chl_a_raster_stack <- resample(
  chl_a_raster_stack, sst_raster_stack, threads = TRUE,
  filename = "chl_a_resamp.tif", overwrite = TRUE
)
print("resampled chl-a")
wind_mag_raster_stack <- resample(
  wind_mag_raster_stack, sst_raster_stack, threads = TRUE,
  filename = "wind_resamp.tif", overwrite = TRUE
)
print("resampled wind")
current_u_raster_stack <- resample(
  current_u_raster_stack, sst_raster_stack, threads = TRUE,
  filename = "current_u_resamp.tif", overwrite = TRUE
)
print("resampled current-u")
current_v_raster_stack <- resample(
  current_v_raster_stack, sst_raster_stack, threads = TRUE,
  filename = "current_v_resamp.tif", overwrite = TRUE
)
print("resampled current-v")

# Fill small gaps with focal (should read these on different nodes...)
sst_raster_stack_focal <- focal(
  sst_raster_stack, w = 9, fun = "mean", na.policy = "only", na.rm = TRUE,
  filename = "sst_focal.tif", overwrite = TRUE
)
print("filled local NAs of sst")
chl_a_raster_stack_focal <- focal(
  chl_a_raster_stack, w = 9, fun = "mean", na.policy = "only", na.rm = TRUE,
  filename = "chl_a_focal.tif", overwrite = TRUE
)
print("filled local NAs of chl-a")
wind_mag_raster_stack_focal <- focal(
  wind_mag_raster_stack, w = 9, fun = "mean", na.policy = "only", na.rm = TRUE,
  filename = "wind_focal.tif", overwrite = TRUE
)
print("filled local NAs of wind")
current_u_raster_stack_focal <- focal(
  current_u_raster_stack, w = 9, fun = "mean", na.policy = "only", na.rm = TRUE,
  filename = "current_u_focal.tif", overwrite = TRUE
)
print("filled local NAs of current-u")
current_u_raster_stack_focal <- focal(
  current_u_raster_stack, w = 9, fun = "mean", na.policy = "only", na.rm = TRUE,
  filename = "current_v_focal.tif", overwrite = TRUE
)
print("filled local NAs of current-v")

# Interpolate through time
sst_raster_filled <- fillTime(sst_raster_filled)
sst_raster_interpolated <- approximate(
  sst_raster_filled,
  filename = "sst_interpolated.tif",
  overwrite = TRUE
)
print("filled time gaps of sst")
chl_a_raster_filled <- fillTime(chl_a_raster_filled)
chl_a_raster_interpolated <- approximate(
  chl_a_raster_filled,
  filename = "chl_a_interpolated.tif",
  overwrite = TRUE
)
print("filled time gaps of chl_a")
wind_raster_filled <- fillTime(wind_raster_filled)
wind_raster_interpolated <- approximate(
  wind_raster_filled,
  filename = "wind_interpolated.tif",
  overwrite = TRUE
)
print("filled time gaps of wind")
current_u_raster_filled <- fillTime(current_u_raster_filled)
current_u_raster_interpolated <- approximate(
  current_u_raster_filled,
  filename = "current_u_interpolated.tif",
  overwrite = TRUE
)
print("filled time gaps of current_u")
current_v_raster_filled <- fillTime(current_v_raster_filled)
current_v_raster_interpolated <- approximate(
  current_v_raster_filled,
  filename = "current_v_interpolated.tif",
  overwrite = TRUE
)
print("filled time gaps of current_v")

# Last focal
sst_raster_filled <- focal(
  sst_raster_interpolated, w = 9, fun = "mean",
  na.policy = "only", na.rm = TRUE,
  filename = "sst_filled.tif", overwrite = TRUE
)
print("final local fill NAs of sst")
chl_a_raster_filled <- focal(
  chl_a_raster_interpolated, w = 9, fun = "mean",
  na.policy = "only", na.rm = TRUE,
  filename = "chl_a_filled.tif", overwrite = TRUE
)
print("final local fill NAs of chl-a")
wind_mag_raster_filled <- focal(
  wind_mag_raster_interpolated, w = 9, fun = "mean",
  na.policy = "only", na.rm = TRUE,
  filename = "wind_filled.tif", overwrite = TRUE
)
print("final local fill NAs of wind")
current_u_raster_filled <- focal(
  current_u_raster_interpolated, w = 9, fun = "mean",
  na.policy = "only", na.rm = TRUE,
  filename = "current_u_filled.tif", overwrite = TRUE
)
print("final local fill NAs of current-u")
current_u_raster_filled <- focal(
  current_u_raster_interpolated, w = 9, fun = "mean",
  na.policy = "only", na.rm = TRUE,
  filename = "current_v_filled.tif", overwrite = TRUE
)
print("final local fill NAs of current-v")

# Mask to NWS extent (keeping cells that touch coast)
aus_shape <- vect("./data/shape-files/land/STE11aAust.shp")
crs(aus_shape) <- "+proj=utm +zone=48 +datum=WGS84"
aus_shape <- crop(aus_shape, ext(wind_raster_raw))

sst_rast_final <- mask(
  sst_raster_filled, aus_shape, inverse = TRUE, touches = FALSE,
  filename = "sst_final.tif", overwrite = TRUE
)
print("sst masked")
chl_a_rast_final <- mask(
  chl_a_raster_filled, aus_shape, inverse = TRUE, touches = FALSE,
  filename = "chl_a_final.tif", overwrite = TRUE
)
print("chl_a masked")
wind_rast_final <- mask(
  wind_raster_filled, aus_shape, inverse = TRUE, touches = FALSE,
  filename = "wind_final.tif", overwrite = TRUE
)
print("wind masked")
current_u_rast_final <- mask(
  current_u_raster_filled, aus_shape, inverse = TRUE, touches = FALSE,
  filename = "current_u_final.tif", overwrite = TRUE
)
print("current_u masked")
current_v_rast_final <- mask(
  current_v_raster_filled, aus_shape, inverse = TRUE, touches = FALSE,
  filename = "current_v_final.tif", overwrite = TRUE
)
print("current_v masked")
print("Done.")