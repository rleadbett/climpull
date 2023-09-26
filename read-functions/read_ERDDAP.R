library(ncdf4)
library(rerddap)
library(terra)
library(dplyr)
library(stringr)

getNCDF <- function(ds_ids, time_range, lat_range, lon_range) {

    lat_range <- lat_range[order(lat_range, decreasing = FALSE)]
    lon_range <- lon_range[order(lon_range, decreasing = FALSE)]

    # get the info
    out <- lapply(
        ds_ids,
        function(id) info(id)
    )

    # sort by date
    out <- sortInfo(
        list_of_ranges = lapply(out, getTimeRange), 
        erddap_info_list = out
    )

    # prepare time query
    
    nc_files <- callErddap(
        erddap_info_list = out, 
        time_query = prepareQuery(time_range, out), 
        lat_range = lat_range, 
        lon_range = lon_range
    )

    return(nc_files)

}

getTimeRange <- function(erddap_info_obj) {
    # function to get the date range of data
    global <- erddap_info_obj$alldata$NC_GLOBAL
    tt <- global[global$attribute_name %in% c('time_coverage_end','time_coverage_start'), "value", ]
    return(c(tt[2], tt[1]))
}

sortInfo <- function(list_of_ranges, erddap_info_list) {
    time_order <- lapply(
        list_of_ranges, 
        function(tt) tt[2]
    )  %>% 
    unlist() %>% 
    order(decreasing = TRUE)
    
    erddap_info_sorted <- erddap_info_list[time_order]

    return(erddap_info_sorted)
}

prepareQuery <- function(time_range, erddap_info_list) {
    time_range <- time_range[order(time_range, decreasing = FALSE)]

    # get ranges
    info_time_range <- lapply(erddap_info_list, getTimeRange)

    # adjust for overlapping data sets
    for (i in 1:(length(info_time_range) - 1)) {
        if (info_time_range[[i]][1] < info_time_range[[i + 1]][2]) {
            info_time_range[[i + 1]][2] <- info_time_range[[i]][1]
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
    time_query[data_set_range[1]:data_set_range[2]] <- info_time_range[data_set_range[1]:data_set_range[2]]
    time_query[[data_set_range[1]]][1] <- time_range[1]
    time_query[[data_set_range[2]]][2] <- time_range[2]

    return(time_query)
}

callErddap <- function(erddap_info_list, time_query, lat_range, lon_range) {
    
    data_sets_in_time_window <- lapply(
        time_query, 
        function(tt) sum(is.na(tt)) == 0
    ) %>%
    unlist() %>%
    which()

    nc_files <- lapply(
        data_sets_in_time_window,
        function(i) {
            griddap(
                erddap_info_list[[i]],
                latitude = lat_range,
                longitude = lon_range,
                time = time_query[[i]]
            )
        }
    )

    return(nc_files)
}
