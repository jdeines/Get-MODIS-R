Get-MODIS-R
===========

Generic script to batch process MODIS tiles based on input shapefile. It is
currently set up to process MODIS LAI data products, but should work with any
MODIS product by changing the `shortname` variable based on the 
[MODIS Product List](https://lpdaac.usgs.gov/products/modis_products_table).

### Depends
#### MODIS package
This script uses the MODIS package currently on R-Forge (pre-release) at  
https://r-forge.r-project.org/R/?group_id=1252. To install:

```
install.packages("MODIS", repos="http://R-Forge.R-project.org")
```
#### GDAL binaries
You will need to have the GDAL binaries installed on your computer (and the file path
to the bin folder set in the `gdalpath` variable. You can get GDAL at
http://trac.osgeo.org/osgeo4w/
