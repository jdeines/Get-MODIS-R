# Script to batch download MODIS
# Jill Deines
# Updated September 10, 2014

# NOT YET MODIFIED

# This script uses the MODIS package, which is still in development. See the 
# Confluence wiki for instructions on software set up.

# This script written for MODIS package pre-release 0.10-17 from 
# https://r-forge.r-project.org/R/?group_id=1252, dated 2014-08-12. A zip version 
# of this package can be found at S:\Users\deinesji\modis and installed from here
# if needed

# GDAL binaries will need to be installed if you don't have access to the S Drive

# Packages ---------------------------------------------------------------------
library(rgdal)
library(mapdata)
library(snow)
library(ptw)
library(XML)
# install.packages("MODIS", repos="http://R-Forge.R-project.org")
library(MODIS)

# User Specified Input ---------------------------------------------------------

# filepath to model buffer SHAPEFILE directory (not geodatabase file)
shapeDir <- 'S:/Data/GIS_Data/Derived/Wisconsin_USGS/Boundaries'
# name of shapefile with no extension
shapeName <- 'FB_MR_buffered'

# Project/Region Name (used to name folder of LAI products on S: drive)
projectName <- 'WI_FB_MR'

# Set dataset variables and output folders--------------------------------------
# defaults are acceptable for LAI

# data product
shortname <- 'MOD15A2'  # LAI is 'MOD15A2'
# specify layers to get
layer <- '010000'       # LAI 1km product is position 2 of 6 (indicated by binary)
cellSize <- 1000        # can vary by latitude...

# Set time period of interest
startDate <- '2000-02-18' # first day of LAI availability
endDate <- Sys.Date()     # gets the current date

# generic filepaths for MODIS downloads 
rawFileBase <- 'S:/Data/Remote_Sensing/MODIS_LAI/Version_5/HDF_Data'
outputFileBase <- 'S:/Data/Remote_Sensing/MODIS_LAI/Version_5/Processed_Data'

# make subfolders for project if they does not exist
dir.create(file.path(rawFileBase, projectName), showWarnings=F) # raw data
dir.create(file.path(outputFileBase, projectName), showWarnings=F) # processed

# filepath to GDAL binaries
gdalpath <- 'S:/Software/GDAL/OSGeo4W/bin'

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

# Occasionally there are files missing in the server for a date, which 
# terminates the job. For each year of interest, run the job for the full year,
# but check the date on the last file processed to see if it made it through the 
# full year. If not, re-start the job 9 days after the last complete file, to 
# skip the missing date that makes it stop.

for (m in 1:length(years)) {
    # download and process LAI for the year
    runGdal(product = shortname, begin = startDates[m],  end = endDates[m], 
            extent = buffExtent, SDSstring = layer,outProj = proj, 
            pixelSize = cellSize, job = years[m], quiet = T)
    
    # Check completeness and re-run if necessary

    # set final day expected:
        # years before current: day 361 
        # current year: 60 days before current date 
    if (years[m] != yearLast) {
        finaltarget <- as.numeric(paste0(years[m],'361'))
    } else {
        finaltarget <- endDate - 60
    }
    
    checkDone <- 1  # default: file checking on
    while (checkDone != 0) {
        if (checkDone == 1) {
            # get last day completed from output folder filenames
            jobdir <- paste(outputFileBase, projectName, years[m], sep = '/')
            done <- list.files(jobdir, pattern = "\\.tif")
            latestday <- max(as.numeric(substr(done, start = 10, stop = 16)))
        
            if (latestday < finaltarget) {
                # set new start date
                newStart <- as.character(latestday + 9)
                # run remaining part of year
                runGdal(product = shortname, begin = newStart,  end = endDates[m], 
                        extent = buffExtent, SDSstring = layer,outProj = proj, 
                        pixelSize = cellSize, job = years[m], quiet = T)
                print(paste("***********restarting",year[m],'*****************'))
            } else {
                # check finished, year run successful. Turn check off.
                checkDone <- 0  
            }  
        }
    }
}

print('Finished')
