library(ncdf4)
library(rerddap)
library(terra)
library(dplyr)
library(stringr)

setwd("./climpull/")

source("./read-functions/read_ERDDAP.R", chdir = TRUE)
source("./read-functions/raster_toolbox.R", chdir = TRUE)

time_window <- c("2000-01-01", "2022-07-27")
latitude_range <- c(-25, -5)
longitude_range <- c(110, 135)

chl_a_nc <- getNCDF(
    ds_ids = c(
        # Aqua MODIS
        "erdMH1chla1day",
        # SeaWiFS
        "erdSW2018chla1day" # ,
        # Nasa
        # "erdVH2018chla1day"
    ),
    time_range = time_window,
    lat_range = latitude_range,
    lon_range = longitude_range,
    chunks = years(2)
)

chl_a_ras <- ncdfToRast(chl_a_nc)

sst_nc <- getNCDF(
    ds_ids = "nceiPH53sstn1day",
    url = "https://coastwatch.pfeg.noaa.gov/erddap/",
    time_range = time_window,
    lat_range = latitude_range,
    lon_range = longitude_range
)

sst_ras <- ncdfToRast(sst_nc, var = "sea_surface_temperature")

servers() %>% View()

ed_search_adv(
    query = "current",
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    protocol = "griddap",
    url = "https://coastwatch.noaa.gov/erddap/"
) %>% View()

ed_search_adv(
    query = "current",
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    protocol = "griddap",
    url = "https://www.ncei.noaa.gov/erddap/"
) %>% View()

ed_search_adv(
    query = "sst",
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    protocol = "griddap",
    url = "https://www.ncei.noaa.gov/erddap/"
) %>% View()

ed_search_adv(
    query = "chl",
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    protocol = "griddap",
    url = "https://coastwatch.pfeg.noaa.gov/erddap/"
) %>% View()


ed_search_adv(
    query = "sss",
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    protocol = "griddap",
    url = "https://coastwatch.pfeg.noaa.gov/erddap/"
) %>% View()


test_chl_a <- getNCDF(
    ds_ids = c(
        # Aqua MODIS
        "erdMH1chla1day",
        # SeaWiFS
        "erdSW2018chla1day" # ,
        # Nasa
        # "erdVH2018chla1day"
    ),
    time_range = c("2002-01-01", "2004-01-01"),
    lat_range = c(-25, -15),
    lon_range = c(115, 125)
)

chl_a_ras <- ncdfToRast(ncdf_list = chl_a_nc, var = "chl")

rastStackToMov(
    ras_clean,
    shape_file = terra::vect("./data/Australia_shp/STE11aAust.shp"),
    output_file = "./static/test.gif"
)


writeRaster(
    chl_a_ras,
    filename = "./outputs/chl_a_2018-2022.tif"
)

nc <- nc_open("https://projects.pawsey.org.au/mma-species-distribution/test.nc?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=P0UZLYNCYTVQECBH2L9I%2F20230929%2Fdefault%2Fs3%2Faws4_request&X-Amz-Date=20230929T081654Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=b066bec3a26fcbc25aa686e3f09cbeb48c168b5d329dcdaa88514d89c791372a")


 ## setup the connection

library(aws.s3)
b <- get_bucket("mma-species-distribution", region = "")
b

nc <- s3read_using(
    FUN = ncdf4::nc_open(),
    object = "s3://mma-species-distribution/test.nc",
    region = ""
)

con <- s3connection(
    "test.nc",
    bucket = b,
    region = ""
)

s3read_using()
nc <- ncdf4::nc_open(con)


close(con)

