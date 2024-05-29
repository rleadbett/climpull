library(terra)
library(dplyr)
library(lubridate)
library(stringr)
library(readxl)

# Function to convert the lat and lon strings
# from minutes and seconds to minutes.
toMinutes <- function(ms_string) {
    lat_long_sec <- ms_string %>%
        str_remove("( |')") %>%
        str_replace("°", ":") %>%
        ms() %>%
        period_to_seconds()

    lat_long_min <- lat_long_sec / 60

    return(lat_long_min)
}

# Read in the logger meta data and tidy up.
logger_locations <- read.csv(
    "./data/logger-locations/NWS_DutyCycle_Table.csv"
) %>%
  mutate(
    Start.Time = mdy(Start.Time),
    End.Time = mdy(End.Time),
    Latitude..N = - toMinutes(Latitude..S.),
    Longitude..E = toMinutes(Longitude..E)
  ) %>%
  select(-c("Latitude..S."))

# Print the extent.
cat(
    "\n",
    "Lat range: \n",
    range(logger_locations$Latitude..N),
    "\n",
    "lon range: \n",
    range(logger_locations$Longitude..E),
    "\n",
    "time range: \n",
    range(
        c(logger_locations$Start.Time,
          logger_locations$End.Time)
    ) %>% as.character(),
    "\n"
)

# Crop the aus shape object to match loggers
aus_shape <- vect("./data/shape-files/STE11aAust.shp")
study_ext <- ext(110, 135, -25, -5)
study_region_shape <- crop(x = aus_shape, y = study_ext)
crs(study_region_shape) <- "+proj=utm +zone=48 +datum=WGS84"


# Create vector object for logger locations and plot
logger_points <- vect(
    logger_locations,
    geom = c("Longitude..E", "Latitude..N"),
    crs = "+proj=utm +zone=48 +datum=WGS84",
    ext = study_ext
)
plot(study_region_shape)
plot(logger_points, add = TRUE)

# Add omorus whale logger locations

omorus_sites <- read.csv("./data/logger-locations/omorus-whale-loggers.csv")
omorus_logger_points <- vect(
    omorus_sites,
    geom = c("Longitude", "Latitude"),
    crs = "+proj=utm +zone=48 +datum=WGS84"
)

# Pauls hump back loggers

hbw_sites <- read.csv("./data/logger-locations/hbw-loggers.csv") %>%
filter(lat > -30)
hbw_logger_points <- vect(
    hbw_sites,
    geom = c("lon", "lat"),
    crs = "+proj=utm +zone=48 +datum=WGS84"
)

plot(chl_a_ras[[20]])
plot(study_region_shape, add = TRUE)
plot(logger_points, add = TRUE)
plot(omorus_logger_points, add = TRUE, col = "red")
plot(hbw_logger_points, add = TRUE, col = "blue")


# Explore the call data

library(readxl)
library(tidyr)
library(ggplot2)

test_counts <- read_xlsx(
    "./data/test-call-data/3757_DayTimeCounts.xlsx",
    col_types = c("date", "numeric")
) %>%
replace_na(list(calls = 0))

hourly_counts <- test_counts %>%
group_by(floor_date(timestamp, "1 hour")) %>%
summarize(hourly_count = sum(calls)) %>%
rename(
  time = `floor_date(timestamp, "1 hour")`
)

hourly_counts %>%
ggplot(aes(x = hourly_count)) +
geom_density()

hourly_counts %>%
ggplot(aes(x = time, y = hourly_count)) +
geom_line()

hourly_counts %>%
arrange(hourly_count) %>%
mutate(n = 1:nrow(hourly_counts)) %>%
ggplot(aes(x = n, y = hourly_count)) +
geom_line()


## PAMsetsCE

recorder_loc_df <- read_xlsx(
  "./data/logger-locations/PAMsetsCE raw.xlsx"
) %>%
  mutate(
    Latitude = Latitude %>%
      str_replace(" ", ":") %>%
      str_replace(" ", "0") %>%
      ms() %>%
      period_to_seconds() / 60,
    Longitude = Longitude %>%
      str_replace(" ", ":") %>%
      str_replace(" ", "0") %>%
      ms() %>%
      period_to_seconds() / 60
  ) %>%
  rename(
    set_number = `Set number`,
    start_time = `Start time (good records)`,
    end_time = `End time (good records)`
  )

sets_in_ext <- recorder_loc_df %>%
  filter(
    between(Latitude, left = 5, right = 25),
    between(Longitude, left = 110, right = 135),
    (between(start_time, left = ymd("2000-01-01"), right = ymd("2023-01-01")) |
       between(end_time, left = ymd("2000-01-01"), right = ymd("2023-01-01")))
  ) %>%
  select(set_number, Latitude, Longitude, start_time, end_time)

# Throw away repeated locations

sets_in_ext <- sets_in_ext[!duplicated(sets_in_ext[, 2:3]), ]

sets_in_ext_vec <- vect(
  sets_in_ext %>% 
    select(Latitude, Longitude) %>%
    mutate(Latitude = -Latitude),
  geom = c("Longitude", "Latitude"),
  crs = "+proj=utm +zone=48 +datum=WGS84"
)

plot(study_region_shape)
plot(sets_in_ext_vec, add = TRUE)

write.csv(sets_in_ext, file = "./outputs/nws_sets.csv")
