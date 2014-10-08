# Script to batch download MODIS
# Jill Deines
# Updated September 10, 2014

# This script written for MODIS package pre-release 0.10-17 from 
# https://r-forge.r-project.org/R/?group_id=1252, dated 2014-08-12. A zip version 
# of this package can be found at S:\Users\deinesji\modis and installed from here
# if needed

# GDAL binaries will need to be installed and the gdalPath set if you don't have 
# access to my network S Drive.

# Packages ---------------------------------------------------------------------
library(rgdal)
library(mapdata)
library(snow)
library(ptw)
library(XML)
# install.packages("MODIS", repos="http://R-Forge.R-project.org")
library(MODIS)

# User Specified Input ---------------------------------------------------------

# filepath to shapefile denoting extent of interest
shapeDir <- 'S:/Data/GIS_Data/Derived/Wisconsin_USGS/Boundaries'
# name of shapefile with no extension
shapeName <- 'FB_MR_buffered'
# Project/Region Name (used to name folder of LAI products on output)
projectName <- 'WI_FB_MR'

# data product
shortname <- 'MOD15A2'  # LAI is 'MOD15A2'
# specify layers to get
layer <- '010000'       # LAI 1km product is position 2 of 6 (indicated by binary)

# output cellSize
cellSize <- 1000        # can vary by latitude...

# Set time period of interest
startDate <- '2000-02-18' # first day of LAI availability
endDate <- Sys.Date()     # gets the current date


# generic filepaths for MODIS downloads storage
rawFileBase <- 'S:/Data/Remote_Sensing/MODIS_LAI/Version_5/HDF_Data'
outputFileBase <- 'S:/Data/Remote_Sensing/MODIS_LAI/Version_5/Processed_Data'
# make folders for project if they does not exist
dir.create(file.path(rawFileBase, projectName), showWarnings=F) # raw data
dir.create(file.path(outputFileBase, projectName), showWarnings=F) # processed

# filepath to GDAL binaries
gdalpath <- 'S:/Software/GDAL/OSGeo4W/bin'

# end user specifications-------------------------------------------------------


# set directory locations in MODIS package options
MODISoptions(localArcPath = paste(rawFileBase,projectName,sep='/'))
MODISoptions(outDirPath = paste(outputFileBase,projectName,sep='/'))
MODISoptions(gdalPath = gdalpath)

# test that all MODIS package options have been set
# MODISoptions()

# Set extent of interest -------------------------------------------------------

# get lat/long bounding coordinates from buffer (see help for other methods)
buffer <- readOGR(shapeDir,shapeName, verbose=F)    # load buffer shapefile
# convert to lat long
buffLatLong <- spTransform(buffer, CRS("+proj=longlat +datum=WGS84"))
# extract bounding box
buffExtent <- list(xmin = bbox(buffLatLong)[1,1], xmax = bbox(buffLatLong)[1,2],
                   ymax = bbox(buffLatLong)[2,2], ymin = bbox(buffLatLong)[2,1])
                   
# check to make sure it's selecting reasonable tiles (ie, 'google MODIS tile map')
# getTile(extent=buffExtent)

# set the output projection from the buffer shapefile
proj <- proj4string(buffer)

# Parse years of interest into vector of years used to break down jobs
year1    <- as.numeric(format(as.Date(startDate), "%Y"))
yearLast <- as.numeric(format(as.Date(endDate), "%Y"))
years    <- as.character(year1:yearLast)

startDates <- paste0(years,'-01-01')
endDates   <- paste0(years,'-12-31')

# Get Data ---------------------------------------------------------------------

# Occasionally there are files missing in the server for a date, which throws
# an error and stops the function. I use tryCatch to prevent these breakages
# and complete the run. Warning messages will be output once the full run 
# completes. 'No file found for date: XXXX-XX-XX' messages are expected. Others
# should be investigated.

# download and process MODIS for each year
for (m in 1:length(years)) {
    tryCatch({
        runGdal(product = shortname, begin = startDates[m],  end = endDates[m], 
            extent = buffExtent, SDSstring = layer,outProj = proj, 
            pixelSize = cellSize, job = years[m], quiet = T, collection = 005)
    }, error=function(e) {
        cat("ERROR :",conditionMessage(e), "\n")
    })  
}

