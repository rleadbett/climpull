library(rerddap)
library(dplyr)
library(terra)
library(stringr)
library(lubridate)
library(parallel)

## Example request
RequestData(
  dataset_info_list = c("nceiPH53sstn1day"),
  time_range = c(
    ymd_hms("2020-01-01 00:00:00"),
    ymd_hms("2021-01-01 00:00:00")
  ),
  latitude_range = c(-9, -25),
  longitude_range = c(110, 135),
  n_workers = 4,
  output_path = NULL,
  output_folder_name = "sst",
  var_name = "sea_surface_temperature",
  mask_var_name = "l2p_flags",
  quality_var_name = "quality_level"
)

# Example of reading in raster files
rast_files <- list.files("./sst", full.names = TRUE, pattern = ".tif")
sst_rast <- rast(rast_files)
file_dates <- str_extract(
  rast_files,
  regex("[:digit:]{4}-[:digit:]{2}-[:digit:]{2}")
) %>%
  ymd()
time(sst_rast) <- file_dates

RequestData <- function(
  dataset_info_list,
  time_range,
  latitude_range,
  longitude_range,
  n_workers,
  output_path = NULL,
  output_folder_name,
  var_name,
  mask_var_name = NULL,
  quality_var_name = NULL
) {
  # Create directory for output
  if (!is.null(output_path)) {
    base_path <- output_path
  } else {
    base_path <- getwd()
  }
  path <- file.path(base_path, output_folder_name)
  dir.create(
    path
  )
  # Fetch data set info objects.
  ds_info <- lapply(
    dataset_info_list,
    function(ds_name) info(ds_name)
  )
  # Construct requests for ERDDAP server.
  days <- seq(time_range[1], time_range[2], by = "day")
  queries <- lapply(
    days,
    function(d) {
      query <- FormatDayQuery(
        d,
        ds_info_list = ds_info,
        latitude_range,
        longitude_range
      )
      qq <- list(
        query_list = query,
        var_name = var_name,
        mask_var_name = mask_var_name,
        quality_var_name = quality_var_name,
        output_path = path
      )
      return(qq)
    }
  )
  # Set up workers for parallel compute
  cl <- makeCluster(n_workers)
  clusterEvalQ(cl, {
    library(rerddap)
    library(dplyr)
    library(terra)
    library(stringr)
    library(lubridate)
  })
  clusterExport(
    cl,
    varlist = c(
      "MakeRequests",
      "QueryOpenDAP"
    )
  )
  parLapply(
    cl,
    queries,
    function(x) do.call(MakeRequests, x)
  )
  stopCluster(cl)
}

GetTimeRange <- function(erddap_info) {
  # Function gets the time span of a data set.
  erddap_global <- erddap_info$alldata$NC_GLOBAL
  t_start_pos <- erddap_global$attribute_name == "time_coverage_start"
  t_end_pos <- erddap_global$attribute_name == "time_coverage_end"  
  t_start <- erddap_global$value[t_start_pos]
  t_end <- erddap_global$value[t_end_pos]  

  tt <- c(
    ymd_hms(t_start),
    ymd_hms(t_end)
  )

  return(tt)
}

FormatDayQuery <- function(dd,
                           ds_info_list,
                           latitude_range,
                           longitude_range) {
  # Check which data set the day should come from.
  erddap_info <- NA
  ds_id <- 1
  while (!(class(erddap_info) == "info")) {
    if (ds_id > length(ds_info_list)) {
      stop("Requested dates are not covered by the ranges of the data sets.")
    }
    time_range <- GetTimeRange(ds_info_list[[ds_id]])
    if (between(dd, time_range[1], time_range[2])) {
      erddap_info <- ds_info_list[[ds_id]]
    }
    ds_id <- ds_id + 1
  }
  # Save request object as list
  request <- list(
    datasetx = erddap_info,
    latitude = latitude_range,
    longitude = longitude_range,
    time = as.character(c(dd, dd))
  )
  return(request)
}

MakeRequests <- function(
  query_list,
  var_name,
  mask_var_name = NULL,
  quality_var_name = NULL,
  output_path
) {
  # Requests the data from OpenDap and returns a raster object.
  # Make request.
  data <- QueryOpenDAP(query_list)

  # Extract data and mask if necessary.
  select_cols <- c(
    "latitude", "longitude", var_name, quality_var_name, mask_var_name
  )
  df <- data$data[, select_cols]
  if (!is.null(quality_var_name)) {
    df[is.na(df[, quality_var_name]), quality_var_name] <- 0
    df[(df[, quality_var_name] < 3), var_name] <- NA
  }
  if (!is.null(mask_var_name)) {
    df[(df[, mask_var_name] > 0), var_name] <- NA
  }
  # Create SpatRaster object
  lat <- unique(df[, 1])
  lon <- unique(df[, 2])
  r <- rast(
    nrow = length(lat),
    ncol = length(lon),
    ymin = min(lat),
    ymax = max(lat),
    xmin = min(lon),
    xmax = max(lon),
    crs = "WGS84"
  )
  values(r) <- df %>%
    arrange(desc(latitude), longitude) %>%
    pull(var_name)
  # Locally fill NA's
  r <- focal(
    r,
    w = 9,
    fun = mean,
    na.policy = "only",
    na.rm = TRUE
  )
  writeRaster(
    r,
    file.path(
      output_path,
      paste0(basename(output_path), unique(query_list$time), ".tif")
    ),
    overwrite = TRUE
  )
}

QueryOpenDAP <- function(query_list, max_retries = 5) {
  attempt <- 1
  sleep_time <- 1
  while (attempt <= max_retries) {
    result <- tryCatch({
      do.call(griddap, query_list)
    }, error = function(e) {
      if (grepl("code=503", e$message)) {
        message(
          "Service Unavailable error encountered. Retrying in 1 second..."
        )
        Sys.sleep(sleep_time)
        return(NULL)
      } else {
        stop(e)
      }
    })

    if (!is.null(result)) {
      return(result)
    }
    attempt <- attempt + 1
    sleep_time <- sleep_time * 2
  }
  stop("Maximum number of retries reached without success.")
}
