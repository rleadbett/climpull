# climpull

Code for retrieving and wrangling data needed to build species distribution models. Most of this code uses the [`rerddap`](https://github.com/ropensci/rerddap) package which gives access to [ERDDAP](https://coastwatch.pfeg.noaa.gov/erddap/index.html) servers hosted by NOAA. Where data was not available on the [National Oceanic and Atmospheric Administration (NOAA)](https://www.noaa.gov/) ERDDAP servers, the [`ncdf4`](https://cirrus.ucsd.edu/~pierce/ncdf/) package is used to retrieve the data from [THREDDS](https://github.com/Unidata/tds) servers (i.e. if the data is only available on CSIRO or AODN servers).

## Data set origins

The code returns a single stacked SpatRaster object for each variable (see the `terra` package for info details about `SpatRaster` objects). However, `SpatRaster` objects are sourced from multiple data sets depending on the time period that data is required for. The general method used when retrieving data from multiple sources is to use the entirety of the most resent source first then use from the beginning of the second source up to when the most resent source becomes available and so fourth. For example, if we are trying to request sea surface temperature (SST) over a specific time window and there are three different sources (products) available--with source 3 being the most current and source 1 being the oldest--then the request will look as follows:

window &emsp; &emsp; &emsp; &nbsp;&nbsp; |-------------------|

source 1 &emsp; &emsp; &emsp;|----------|

source 2 &emsp; &emsp; &emsp; &emsp; &emsp;&nbsp;&nbsp; |---------|

source 3 &emsp; &emsp; &emsp; &emsp; &emsp; &emsp; &emsp; |------------|

request &emsp; &emsp; &emsp; &emsp;&nbsp;|-S1-|-S2-|---S3---|

As of this time we do not average over data sets that overlap, i.e. source 2 and 3. Bellow we provide details about the sources for the different variables.

### SSS

- [Sea Surface Salinity - Near Real Time - MIRAS SMOS (2010 to present):](https://coastwatch.noaa.gov/cwn/products/sea-surface-salinity-near-real-time-miras-smos.html) <br> dataset_id: "coastwatchSMOSv662SSS1day" <br> url: "https://coastwatch.pfeg.noaa.gov/erddap/"

- [Ocean acidification historical reconstruction (1870-2013):](https://catalogue-imos.aodn.org.au/geonetwork/srv/eng/catalog.search#/metadata/7709f541-fc0c-4318-b5b9-9053aa474e0e) Product info.

### SST

- [AVHRR Pathfinder Version 5.3 L3-Collated (L3C) SST, Global, 0.0417°, 1981-present, Nighttime (1 Day Composite):](https://www.ncei.noaa.gov/access/metadata/landing-page/bin/iso?id=gov.noaa.nodc:AVHRR_Pathfinder-NCEI-L3C-v5.3) <br> dataset_id: "nceiPH53sstn1day" <br> url: "https://coastwatch.pfeg.noaa.gov/erddap/"

<!-- partial coverage:

- [GHRSST Level 4 OSPO Global Nighttime Foundation Sea Surface Temperature Analysis (2002-present):](https://podaac.jpl.nasa.gov/dataset/Geo_Polar_Blended_Night-OSPO-L4-GLOB-v1.0) Product info.

- [SST, Daily Optimum Interpolation (OI), AVHRR Only, Version 2, Final, Global, 0.25°, 1982-2020, Lon+/-180:](https://catalog.data.gov/dataset/sst-daily-optimum-interpolation-oi-avhrr-only-version-2-1-preliminary-global-0-25a-2020-pre-180) Product info. dataset_id: "ncdcOisst2Agg" -->

### Currents

### Surface Winds

### Chlorophyll-a

- Aqua MODIS: erdMH1chla1day

- SeaWiFS: erdSW2018chla1day

### Bathymetry

### Distances

- Aus shape file

- Key features https://www.environment.gov.au/fed/catalog/search/resource/details.page?uuid=%7B39FE3093-2E53-45C5-8F98-F8FDEB4AD77B%7D

## Data cleaning

For the remote sensed data (all of the dynamic variables), any missing data points are filled by first locally filling NA values where posible using `terra::focal()` with a 3x3 window and then interpolating over time using `terra::approximate()`.

#### NOAA

- https://www.ncei.noaa.gov/access/metadata/landing-page/bin/iso?id=gov.noaa.ncdc:C00680

### Surface wind

https://oceanwatch.noaa.gov/cwn/products/noaa-ncei-blended-seawinds-nbs-v2.html

https://apply.pawsey.org.au/notifications/83591/redirect/