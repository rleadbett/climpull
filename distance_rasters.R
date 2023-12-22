library(terra)

bathy_rast <- rast(
  file.path(".", "data", "bathymetry", "bathymetry.nc")
)

distanceTo <- function(
  shape_file_path,
  extent = c(
    xmin = 110,
    xmax = 135,
    ymin = -25,
    ymax = -9
  ),
  reference_rast_obj = NULL,
  mask_shape_obj = NA,
  ...
){
  # Create a reference raster (I should change this later)
  if(!is.null(reference_rast_obj)){
    r <- reference_rast_obj
  } else {
    r <- rast(
      ncol = 1000,
      nrow = 1000,
      ext = extent,
      crs = "+proj=longlat +datum=WGS84 +no_defs"
    )
  }

  # Reed the shape file as Spatvect object
  v <- vect(
    shape_file_path
  )

  # Crop and define CRS
  v <- crop(
    v,
    extent
  )
  v <- project(v, crs(reference_rast_obj))

  # Convert to raster
  rasterized_v <- rasterize(v, r)

  # Calculate the distances
  dist_raster <- distance(rasterized_v)

  if(class(mask_shape_obj) == "SpatVector") {
    dist_raster <- mask(
      dist_raster,
      mask_shape_obj,
      ...
    )
  }

  return(dist_raster)
}

# Define extent of NWS
nws_extent <- ext(c(
  xmin = 110,
  xmax = 135,
  ymin = -25,
  ymax = -9
))

# Get aus shape for masking
aus_shape <- vect(
  file.path(".", "data", "shape-files", "land", "STE11aAust.shp")
)
aus_shape <- project(
  aus_shape,
  "+proj=longlat +datum=WGS84 +no_defs"
)
nws_shape <- crop(aus_shape, nws_extent)

# Create the template raster from bathymetry raster
bathy_rast <-  rast(
  file.path(".", "data", "bathymetry", "bathymetry.nc")
)
template_rast <- rast(
  ncols = dim(bathy_rast)[2],
  nrows = dim(bathy_rast)[1],
  ext = ext(bathy_rast),
  crs = "+proj=longlat +datum=WGS84 +no_defs"
)

# Calculate distance to coast and reef
dist_to_coast <- distanceTo(
  shape_file_path = file.path(
    ".", "data", "shape-files", "land", "STE11aAust.shp"
  ),
  extent = nws_extent,
  reference_rast = template_rast,
  mask_shape_obj = nws_shape,
  inverse = TRUE,
  touches = FALSE
)
dist_to_reef <- distanceTo(
  shape_file_path = file.path(
    ".", "data", "shape-files", "reefs", "Cor.shp"
  ),
  extent = nws_extent,
  reference_rast = template_rast,
  mask_shape_obj = nws_shape,
  inverse = TRUE,
  touches = FALSE
)
dist_to_200m <- distanceTo(
  shape_file_path = file.path(
    ".", "data", "shape-files", "contours", "Bath_200.shp"
  ),
  extent = nws_extent,
  reference_rast = template_rast,
  mask_shape_obj = nws_shape,
  inverse = TRUE,
  touches = FALSE
)
dist_to_500m <- distanceTo(
  shape_file_path = file.path(
    ".", "data", "shape-files", "contours", "Bath_500.shp"
  ),
  extent = nws_extent,
  reference_rast = template_rast,
  mask_shape_obj = nws_shape,
  inverse = TRUE,
  touches = FALSE
)

writeCDF(dist_to_coast, file = "dist_to_coast.nc", overwrite = TRUE)
writeCDF(dist_to_reef, file = "dist_to_reef.nc", overwrite = TRUE)
writeCDF(dist_to_200m, file = "dist_to_200m.nc", overwrite = TRUE)
writeCDF(dist_to_500m, file = "dist_to_500m.nc", overwrite = TRUE)