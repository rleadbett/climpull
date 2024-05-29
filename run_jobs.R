library(dplyr)
library(terra)
library(stringr)
library(lubridate)
library(parallel)
library(ncdf4)

source(
  file.path(".", "read-functions", "RequestData.R")
)
source(
  file.path(".", "read-functions", "FillRastersParallel.R")
)

# Define request
request_lat <- c(-9, -25)
request_lon <- c(110, 135)
request_time <- c(
  ymd_hms("2005-01-01 00:00:00"),
  ymd_hms("2023-09-01 00:00:00")
)

# Request SST
RequestData(
  dataset_info_list = list(
    list(
      datasetid	= "nceiPH53sstn1day",
      url = eurl()
    )
  ),
  time_range = request_time,
  latitude_range = request_lat,
  longitude_range = request_lon,
  n_workers = 12,
  output_path = ".",
  output_folder_name = "sst",
  var_name = "sea_surface_temperature",
  mask_var_name = "l2p_flags",
  quality_var_name = "quality_level"
)

# Request Chl_a
RequestData(
  dataset_info_list = list(
    list(
      datasetid	= "erdMH1chla1day_R2022SQ",
      url = "https://coastwatch.pfeg.noaa.gov/erddap"
    )#,
#    list(
#      datasetid	= "erdMH1chla1day",
#      url = eurl()
#    )#,
#    list(
#      datasetid	= "erdSW2018chla1day",
#      url = eurl()
#    )
  ),
  time_range = request_time,
  latitude_range = request_lat,
  longitude_range = request_lon,
  n_workers = 12,
  output_path = ".",
  output_folder_name = "chl_a",
  var_name = c("chlor_a"),
  mask_var_name = NULL,
  quality_var_name = NULL
)

# Request wind mag
RequestData(
  dataset_info_list = list(
    list(
      datasetid	= "noaacwBlendedWindsDaily",
      url = "https://coastwatch.noaa.gov/erddap/"
    )
  ),
  time_range = request_time,
  latitude_range = request_lat,
  longitude_range = request_lon,
  n_workers = 12,
  output_path = ".",
  output_folder_name = "wind",
  var_name = "windspeed",
  mask_var_name = NULL,
  quality_var_name = NULL
)

# Request SSS
RequestData(
  dataset_info_list = list(
    list(
      datasetid	= "coastwatchSMOSv662SSS1day",
      url = "https://coastwatch.pfeg.noaa.gov/erddap/"
    )
  ),
  time_range = c(
    ymd_hms("2010-06-02 12:00:00"),
    request_time[2]
  ),
  latitude_range = request_lat,
  longitude_range = request_lon,
  n_workers = 12,
  output_path = ".",
  output_folder_name = "sss",
  var_name = "sss",
  mask_var_name = NULL,
  quality_var_name = NULL
)

# Request ekman current
#RequestData(
#  dataset_info_list = list(
#   list(
#      datasetid	= "erdQAekm1day",
#      url = eurl()
#    ),
#    list(
#      datasetid	= "erdQSekm1day",
#      url = eurl()
#    )
#  ),
#  time_range = request_time,
#  latitude_range = request_lat,
#  longitude_range = request_lon,
#  n_workers = 12,
#  output_path = ".",
#  output_folder_name = "e_current",
#  var_name = "mod_current",
#  mask_var_name = NULL,
#  quality_var_name = NULL
#)

FillRastersParallel(
  c("sst", "chl_a", "wind", "sss")
)

# Add CSIRO historical reconstruction to the SSS data
nc <- nc_open(
  file.path(".", "data", "sss", "sss_csiro_historic_reconstruction.nc")
)
sss_hist_lat <- ncvar_get(nc, "LATITUDE")
sss_hist_lon <- ncvar_get(nc, "LONGITUDE")
sss_hist_time <- ncvar_get(nc, "TIME")
time_units <- ncatt_get(nc, "TIME", "units")$value

sss_hist_time_ymd <- ymd_hms(time_units) +
  days(15) +
  months(floor(sss_hist_time))

sss_hist_values <- ncvar_get(nc, "SSS")
nc_close(nc)
rast_values <- sss_hist_values[, length(sss_hist_lat):1, ]
sss_hist_ext <- ext(
  c(
    xmin = min(sss_hist_lon),
    xmax = max(sss_hist_lon),
    ymin = min(sss_hist_lat),
    ymax = max(sss_hist_lat)
  )
)
sss_hist_rast <- rast(
  nrow = length(sss_hist_lat),
  ncol = length(sss_hist_lon),
  nlyrs = length(sss_hist_time_ymd),
  vals = aperm(rast_values, c(2, 1, 3)),
  ext = sss_hist_ext
)
time(sss_hist_rast) <- sss_hist_time_ymd
sss_hist_rast <- c(
  rast(
    nrow = length(sss_hist_lat),
    ncol = length(sss_hist_lon),
    ext = sss_hist_ext,
    time = sss_hist_time_ymd[1] - days(1),
    vals = NA
  ),
  sss_hist_rast
)
sss_hist_rast <- focal(
  sss_hist_rast,
  w = 3,
  na.policy = "only",
  fun = "mean",
  na.rm = TRUE
)
sss_hist_rast <- fillTime(sss_hist_rast)
names(sss_hist_rast) <- str_c("lyr.", 1:nlyr(sss_hist_rast))
sss_hist_rast <- approximate(sss_hist_rast)

sss <- rast("sss.tif")
sss_hist_rast <- resample(
  sss_hist_rast,
  sss[[10]],
  threads = TRUE
)
new_days <- !between(time(sss_hist_rast), min(time(sss)), max(time(sss)))
sss <- c(sss_hist_rast[[new_days]], sss)

# Read in current data
source(
  file.path(".", "get_curents.R")
)
current_u <- rast("current_u.nc")
current_v <- rast("current_v.nc")
current_u <- focal(
  current_u,
  w = 9,
  na.policy = "only",
  fun = "mean",
  na.rm = TRUE
)
current_v <- focal(
  current_v,
  w = 9,
  na.policy = "only",
  fun = "mean",
  na.rm = TRUE
)

# Read in other rasters
sst <- rast("sst.tif")
chl_a <- rast("chl_a.tif")
wind <- rast("wind.tif")

# Resample to same res as sst
chl_a <- resample(
  chl_a,
  sst[[1]],
  threads = TRUE,
  filename = "chl_a_resamp.tif",
  overwrite = TRUE
)
wind <- resample(
  wind,
  sst[[1]],
  threads = TRUE,
  filename = "wind_resamp.tif",
  overwrite = TRUE
)
sss <- resample(
  sss,
  sst[[1]],
  threads = TRUE,
  filename = "sss_resamp.tif",
  overwrite = TRUE
)
current_u <- resample(
  current_u,
  sst[[1]],
  threads = TRUE,
  filename = "current_u_resamp.tif",
  overwrite = TRUE
)
current_v <- resample(
  current_v,
  sst[[1]],
  threads = TRUE,
  filename = "current_v_resamp.tif",
  overwrite = TRUE
)

# Final smoothing step
sst <- focal(
  sst,
  w = 9,
  fun = "mean",
  filename = "sst_final.tif",
  overwrite = TRUE
)
chl_a <- focal(
  chl_a,
  w = 9,
  fun = "mean",
  filename = "chl_a_final.tif",
  overwrite = TRUE
)
wind <- focal(
  wind,
  w = 9,
  fun = "mean",
  filename = "wind_final.tif",
  overwrite = TRUE
)
sss <- focal(
  sss,
  w = 9,
  fun = "mean",
  filename = "sss_final.tif",
  overwrite = TRUE
)
current_u <- focal(
  current_u,
  w = 9,
  fun = "mean",
  filename = "current_u_final.tif",
  overwrite = TRUE
)
current_v <- focal(
  current_v,
  w = 9,
  fun = "mean",
  filename = "current_v_final.tif",
  overwrite = TRUE
)

writeCDF(sst, "sst_final.nc", overwrite = TRUE)
writeCDF(chl_a, "chl_a_final.nc", overwrite = TRUE)
writeCDF(wind, "wind_final.nc", overwrite = TRUE)
writeCDF(sss, "sss_final.nc", overwrite = TRUE)
writeCDF(current_u, "current_u_final.nc", overwrite = TRUE)
writeCDF(current_v, "current_v_final.nc", overwrite = TRUE)
