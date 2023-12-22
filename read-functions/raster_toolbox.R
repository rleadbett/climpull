library(ncdf4)
library(rerddap)
library(terra)
library(dplyr)
library(stringr)

# write script to convert to raster
ncdfToRast <- function(ncdf_list, var) {
  # convert to spatRaster
  rast_list <- lapply(
    ncdf_list,
    function(ncdf) ncdfFileToRast(ncdf, var)
  )
  # make sure all rasters have same extent
  if (length(rast_list) > 1) {
    for (i in 2:length(rast_list)) {
      if (ext(rast_list[[1]]) != ext(rast_list[[i]])) {
        rast_list[[i]] <- resample(
          rast_list[[i]],
          rast_list[[1]],
          threads = TRUE
        )
      }
    }
  }

  # combine rasters into one stack
  full_rast <- rast(rast_list)

  # sort by date
  full_rast <- full_rast[[order(time(full_rast))]]

  return(full_rast)
}

fillRast <- function(ras) {
  # fill missing values
  full_rast_clean <- focal(
    ras,
    w = 3,
    fun = mean,
    na.policy = "only",
    na.rm = TRUE
  )

  full_rast_clean <- approximate(full_rast_clean)

  return(full_rast_clean)
}

ncdfFileToRast <- function(ncdf_obj, var) {
  lon <- unique(ncdf_obj$data$longitude)
  lat <- unique(ncdf_obj$data$latitude)
  time <- unique(ncdf_obj$data$time)

  ras <- terra::rast(
    nrow = length(lat),
    ncol = length(lon),
    ymin = min(lat),
    ymax = max(lat),
    xmin = min(lon),
    xmax = max(lon),
    nlyrs = length(time),
    crs = "+proj=utm +zone=48 +datum=WGS84",
    time = lubridate::ymd_hms(time)
  )

  # Get full name of shortest var match
  var_names <- names(ncdf_obj$data)
  var_name_matches <- which(
    str_detect(var_names, regex(var, ignore_case = TRUE))
  )
  match_lengths <- nchar(var_names[var_name_matches])
  shotest_match <- which.min(match_lengths)
  var_select <- var_names[var_name_matches[shotest_match]]
  print(paste("extracting", var_select))

  values(ras) <- ncdf_obj$data %>%
    arrange(time, desc(latitude), longitude) %>%
    pull(var_select)

  ras <- fillTime(ras)

  return(ras)
}


rastStackToMov <- function(stacked_raster, shape_file = NULL, output_file) {
  # This function requires the command line tool ImageMagick:
  # https://imagemagick.org/script/command-line-tools.php

  # make temporary directory to save plots
  if (!dir.exists("tmp")) dir.create("tmp")

  # crop plots
  if (!is.null(shape_file)) {
    v_crop <- crop(x = shape_file, y = ext(stacked_raster))
    crs(v_crop) <- "+proj=utm +zone=48 +datum=WGS84"

    stacked_raster <- mask(
      stacked_raster,
      v_crop,
      inverse = TRUE,
      touches = FALSE
    )
  }

  # Plot each frame and save to .png
  times <- time(stacked_raster)
  val_range <- range(values(stacked_raster), na.rm = TRUE)

  for (i in 1:length(times)) {
    png(
      file = file.path(
        "./temp",
        str_c(str_remove_all(times[i], "(:| )"), ".png")
      ),
      width = 600,
      height = 600
    )
    plot(
      stacked_raster[[i]],
      main = as.character(times[i]),
      range = val_range
    )
    if (!is.null(shape_file)) plot(v_crop, add = TRUE)

    dev.off()
  }

  # write system command
  cmd <- paste0("magick", " ", "./temp", "/*.png", " ", output_file)

  # execute system command
  system(cmd)

  unlink("temp", recursive = T)
}
