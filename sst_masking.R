library(terra)

sst_raw_rast <- rast("sst.nc")
sst_quality_rast <- rast("sst_quality.nc")

sst_raster_NA <- ifel(sst_quality_rast < 4, NA, sst_raw_rast)
writeCDF(sst_raster_NA, "sst_NAs.nc", overwrite = TRUE)

print("done")
