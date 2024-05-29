library(terra)

print(getwd())

chl_a_rast_unique <- readRDS("climpull/temp_rast_chl-a_focal.rds")

chl_a_rast <- terra::approximate(
    chl_a_rast_unique,
    filename = "temp_rast_chl-a_app.tif"
)

saveRDS(chl_a_rast, file = "temp_rast_chl-a_app.rds")