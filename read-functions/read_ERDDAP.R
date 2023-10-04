library(ncdf4)
library(rerddap)
library(terra)
library(dplyr)
library(stringr)
library(lubridate)

getNCDF <- function(
  ds_ids,
  time_range,
  lat_range,
  lon_range,
  ...
) {
  # re-order lat/lon in the case that they are entered wrong
  lat_range <- lat_range[order(lat_range, decreasing = FALSE)]
  lon_range <- lon_range[order(lon_range, decreasing = FALSE)]

  # get the info of the nc file
  out <- lapply(
    ds_ids,
    function(id) info(id, ...)
  )

  # info list by date
  if (length(out) > 1) {
    out <- sortInfo(
      list_of_ranges = lapply(
        out,
        function(ds) getTimeRange(ds)
      ),
      erddap_info_list = out
    )
  }

  # prepare time query
  nc_files <- callErddap(
    erddap_info_list = out,
    time_query = prepareQuery(time_range, out),
    lat_range = lat_range,
    lon_range = lon_range,
    ...
  )

  return(nc_files)
}

getTimeRange <- function(erddap_info_obj) {
  # function to get the date range of data
  global <- erddap_info_obj$alldata$NC_GLOBAL
  global_att <- global$attribute_name %in%
    c("time_coverage_end", "time_coverage_start")
  tt <- global[global_att, "value", ]
  start_date <- as.character(date(tt[2]))
  end_date <- as.character(date(tt[1]))
  return(c(start_date, end_date))
}

sortInfo <- function(list_of_ranges, erddap_info_list) {
  time_order <- lapply(
    list_of_ranges,
    function(tt) tt[2]
  ) %>%
    unlist() %>%
    order(decreasing = TRUE)

  erddap_info_sorted <- erddap_info_list[time_order]

  return(erddap_info_sorted)
}

prepareQuery <- function(time_range, erddap_info_list, chucks) {
  time_range <- time_range[order(time_range, decreasing = FALSE)]

  # get ranges
  info_time_range <- lapply(erddap_info_list, getTimeRange)

  # adjust for overlapping data sets
  if (length(info_time_range) > 1) {
    for (i in 1:(length(info_time_range) - 1)) {
      if (info_time_range[[i]][1] < info_time_range[[i + 1]][2]) {
        info_time_range[[i + 1]][2] <- info_time_range[[i]][1]
      }
    }
  }

  # check time_range overlap
  time_range_check <- lapply(
    time_range,
    function(time) {
      lapply(
        info_time_range,
        function(range) {
          between(
            time,
            range[1],
            range[2]
          )
        }
      ) %>% unlist()
    }
  )

  # change start date
  data_set_range <- c(
    which(time_range_check[[1]]),
    which(time_range_check[[2]])
  )

  time_query <- as.list(rep(NA, length(info_time_range)))
  time_query[data_set_range[1]:data_set_range[2]] <-
    info_time_range[data_set_range[1]:data_set_range[2]]
  time_query[[data_set_range[1]]][1] <- time_range[1]
  time_query[[data_set_range[2]]][2] <- time_range[2]

  return(time_query)
}

callErddap <- function(
  erddap_info_list,
  time_query,
  lat_range,
  lon_range,
  ...
) {
  data_sets_in_time_window <- lapply(
    time_query,
    function(tt) sum(is.na(tt)) == 0
  ) %>%
    unlist() %>%
    which()

  if ("chunks" %in% ...names()) {
    chunks <- ...elt(which(...names() == "chunks"))

    new_query <- chunkQuery(
      chunks = chunks,
      time_query = time_query,
      erddap_info_list = erddap_info_list
    )
    erddap_info_list <- new_query[[1]]
    time_query <- new_query[[2]]
    data_sets_in_time_window <- new_query[[3]]
  }

  nc_files <- lapply(
    data_sets_in_time_window,
    function(i) {
      griddap(
        erddap_info_list[[i]],
        latitude = lat_range,
        longitude = lon_range,
        time = str_c(time_query[[i]], "T12:00:00Z")#,
        #store = memory()
      )
    }
  )

  return(nc_files)
}

chunkQuery <- function(
  chunks,
  time_query,
  erddap_info_list
) {
  # check inputs
  if (!is.period(chunks)) {
    stop("The input 'chunks' must be a lubridate period.")
  }
  # get valid time_queries
  time_query_new <- list()
  erddap_info_list_new <- list()
  data_sets_in_time_window_new <- c()
  i <- 1
  for (j in 1:length(time_query)){
    if (is.na(time_query[j])) {
      time_query_new[[i]] <- NA
      erddap_info_list_new[[i]] <- erddap_info_list[[j]]
      i <- i + 1
    } else {
      time_chunk <- ymd(time_query[[j]][1])
      t_end <- ymd(time_query[[j]][2])
      while ((time_chunk + chunks) < t_end) {
        time_query_new[[i]] <- c(
          as.character(time_chunk),
          as.character(time_chunk + chunks - days(1))
        )
        erddap_info_list_new[[i]] <- erddap_info_list[[j]]
        data_sets_in_time_window_new <- append(
          data_sets_in_time_window_new,
          i
        )
        time_chunk <- time_chunk + chunks
        i <- i + 1
      }
      time_query_new[[i]] <- c(
        as.character(time_chunk),
        as.character(t_end)
      )
      erddap_info_list_new[[i]] <- erddap_info_list[[j]]
      data_sets_in_time_window_new <- append(
        data_sets_in_time_window_new,
        i
      )
      i <- i + 1
    }
  }

  return(
    list(erddap_info_list_new, time_query_new, data_sets_in_time_window_new)
  )
}