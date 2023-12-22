library(dplyr)
library(terra)
library(stringr)
library(lubridate)
library(parallel)

FillRastersParallel <- function(files, n_cores = NULL) {
  # Set number of cores
  available_cores <- detectCores() - 2
  if (is.null(n_cores)) {
    if (length(files) < available_cores) {
      n_cores <- length(files)
    } else {
      n_cores <- available_cores
    }
  }
  # Spin up cluster and parse objects
  cl <- makeCluster(n_cores)
  clusterEvalQ(cl, {
    library(dplyr)
    library(terra)
    library(stringr)
    library(lubridate)
  })
  clusterExport(
    cl,
    varlist = "InterpRaster"
  )
  # Dynamically construct jobs
  commands <- lapply(
    files,
    function(file) {
      function_code <- paste0("function() InterpRaster('./", file, "')")
      function_expr <- parse(text = function_code)
      eval(function_expr)
    }
  )
  # Run jobs on cluster
  results <- clusterApply(cl, commands, function(f) f())
  stopCluster(cl)
}

InterpRaster <- function(days_dir) {
  rast_files <- list.files(days_dir, full.names = TRUE, pattern = ".tif")
  rast_stack <- rast(rast_files)
  file_dates <- str_extract(
    rast_files,
    regex("[:digit:]{4}-[:digit:]{2}-[:digit:]{2}")
  ) %>%
    ymd()
  time(rast_stack) <- file_dates
  approximate(
    rast_stack,
    filename = paste0(days_dir, ".tif"),
    overwrite = TRUE
  )
}