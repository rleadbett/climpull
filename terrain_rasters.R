library(terra)

# Read in bathymetry data.
bathy_rast <- rast(
  file.path(".", "data", "bathymetry", "bathymetry.nc")
)

# Crop to North-West Shelf to save compute.
nws_extent <- ext(c(
  xmin = 110,
  xmax = 132,
  ymin = -25,
  ymax = -9
))

bathy_rast <- crop(bathy_rast, nws_extent)

# Calculate terrain variables.
roughness_rast <- terrain(bathy_rast, "roughness")
slope_rast <- terrain(bathy_rast, "slope")

roughness_rast <- focal(
  roughness_rast, w = 9, fun = "mean", na.policy = "all", na.rm = TRUE
)
slope_rast <- focal(
  slope_rast, w = 9, fun = "mean", na.policy = "all", na.rm = TRUE
)

aus_shape <- vect("./data/shape-files/land/STE11aAust.shp")
crs(aus_shape) <- "+proj=longlat +datum=WGS84 +no_defs"
nws_shape <- crop(
  aus_shape,
  nws_extent
)

roughness_rast <- mask(
  roughness_rast, nws_shape, touches = FALSE, inverse = TRUE
)
slope_rast <- mask(
  slope_rast, nws_shape, touches = FALSE, inverse = TRUE
)

# Save and NetCDF files.
writeCDF(roughness_rast, file = "roughness.nc", overwrite = TRUE)
writeCDF(slope_rast, file = "slope.nc", overwrite = TRUE)
