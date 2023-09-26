library(ncdf4)
library(rerddap)
library(terra)
library(dplyr)
library(stringr)

source("./read-functions/read_ERDDAP.R", chdir = TRUE)
source("./read-functions/raster_toolbox.R", chdir = TRUE)

servers() %>% View()

ed_search_adv(
    query = 'current',
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    protocol = "griddap",
    url = "https://coastwatch.noaa.gov/erddap/"
) %>% View()

ed_search_adv(
    query = 'salinity',
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    url = "https://polarwatch.noaa.gov/erddap/"
) %>% View()

ed_search_adv(
    query = 'sst',
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    protocol = "griddap",
    url = "https://www.ncei.noaa.gov/erddap/"
) %>% View()

ed_search_adv(
    query = 'chl',
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    protocol = "griddap",
    url = "https://coastwatch.pfeg.noaa.gov/erddap/"
) %>% View()


ed_search_adv(
    query = 'salinity',
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    protocol = "griddap",
    url = "https://coastwatch.pfeg.noaa.gov/erddap/"
) %>% View()

ed_search_adv(
    query = 'salinity',
    minLat = -25,
    maxLat = -15,
    minLon = 115,
    maxLon = 125,
    protocol = "griddap",
    url = "https://www.ncei.noaa.gov/erddap/"
) %>% View()

test_chl_a <- getNCDF(
    ds_ids = c(
        # Aqua MODIS
        "erdMH1chla1day",
        # SeaWiFS
        "erdSW2018chla1day"#,
        # Nasa
        #"erdVH2018chla1day"
    ), 
    time_range = c("2002-01-01", "2004-01-01"), 
    lat_range = c(-25, -15), 
    lon_range = c(115, 125)
    
)

ras_clean <- ncdfToRast(ncdf_list = test_chl_a, var = "chl")

rastStackToMov(
    ras_clean,
    shape_file = terra::vect("./data/Australia_shp/STE11aAust.shp"),
    output_file = "./static/test.gif"
)
