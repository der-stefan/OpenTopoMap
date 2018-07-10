<!--
OpenTopoMap
(c) 2012-2018 Stefan Erhardt
https://github.com/der-stefan/OpenTopoMap

opentopomap.org
-->

# How To Create a DEM for Contours and Hillshade
This document will guide you through creating DEMs used for hillshading and contours.  These instructions are for Ubuntu 16.04 only.

## Install required packages
`sudo apt-get install gdal-bin python-gdal`

## Do our work in the dem directory
`cd dem;`

## Download some elevation data
NASA provides elevation data in hgt.zip files from the Shuttle Radar Topography Mission (SRTM): https://dds.cr.usgs.gov/srtm/version2_1/
These websites can be used to help explore this data as well:
http://viewfinderpanoramas.org/
http://www.imagico.de/map/demsearch.php

Here's how you might download and extract some of this data:
```
cd hgt;
while read l; do wget "$l" && unzip "*.zip" && rm *.zip; done < files_to_download.txt;
```

## Fill the voids in the hgt data and convert to tif files
```
for hgtfile in *.hgt; do gdal_fillnodata.py $hgtfile $hgtfile.tif && rm $hgtfile; done;
```

## Merge .tifs into one large .tif
`gdal_merge.py -n 32767 -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -o ../raw.tif *.hgt.tif`

This above command combines all the tifs into one raw.tif.  The raw.tif is the full resolution DEM.  This data will be passed through gdal to create the contours and hillshades.  It can also be used to estimate saddle directions.

Optionally, you can now remove the hgt.tif files:  
```
rm *hgt.tif
```

## Reproject raw.tif into Mercator projection, interpolate, and shrink
```
cd ..;
gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 5000 5000 raw.tif warp-5000.tif
gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 1000 1000 raw.tif warp-1000.tif
gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 700 700 raw.tif warp-700.tif
gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 500 500 raw.tif warp-500.tif
gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 90 90 raw.tif warp-90.tif
```

Note the gdalwarp arguments:
```
-co BIGTIFF=YES: if output > 4 GB
-co TILED=YES: intern tiles
-co COMPRESS=LZW -co PREDICTOR=2: lossless compression with prediction
-t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m": convert into Mercator
-r cubicspline: interpolation for tr < 90 m, bilinear: for tr > 90 m
-tr 30 30: desired resolution in meters
```

## Create color relief for different zoom levels
```
gdaldem color-relief -co COMPRESS=LZW -co PREDICTOR=2 -alpha warp-5000.tif relief_color_text_file.txt relief-5000.tif
gdaldem color-relief -co COMPRESS=LZW -co PREDICTOR=2 -alpha warp-500.tif relief_color_text_file.txt relief-500.tif
```

relief_color_text_file.txt contains the color information for certain elevations.

## Create hillshade for different zoom levels
```
gdaldem hillshade -z 7 -compute_edges -co COMPRESS=JPEG warp-5000.tif hillshade-5000.tif
gdaldem hillshade -z 7 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-1000.tif hillshade-1000.tif
gdaldem hillshade -z 4 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-700.tif hillshade-700.tif
gdaldem hillshade -z 4 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-500.tif hillshade-500.tif
gdaldem hillshade -z 2 -co compress=lzw -co predictor=2 -co bigtiff=yes -compute_edges warp-90.tif hillshade-90.tif && gdal_translate -co compress=JPEG -co bigtiff=yes -co tiled=yes hillshade-90.tif hillshade-90-jpeg.tif
```
Note: gdaldem and gdalwarp have problems compressing huge files while generation. You can compress those afterwards by using `gdal_translate -co compress=...`


## Create contour lines
We are using a tool called phyghtmap to generate the contours: http://katze.tfiu.de/projects/phyghtmap/#Download  

Install dependencies:  
`sudo apt-get install python-setuptools python-matplotlib python-beautifulsoup python-numpy`

Install phyghtmap (=>2.20) on your system: http://katze.tfiu.de/projects/phyghtmap/#Download

Run phyghtmap and generate contours:  
`phyghtmap -o contour --max-nodes-per-tile=0 -s 10 -0 --pbf warp-90.tif`

The output of this will be  in a OpenStreetMap Protocolbuffer Binary Format called something like `contour_lon-126.00_-117.00lat38.00_50.00_local-source.osm.pbf`.


## Create contours database if needed
If you haven't create an osm database as documented in the HOWTO_Ubuntu_16.04 instructions, go there first.  We will load the contours into a database called `contours`.  If a `contours` database exists already, you will need to drop it and recreate it:

```
sudo -u postgres psql
postgres=# \l
postgres=# DROP DATABASE contours;
postgres=# \q
```
```
sudo -u postgres createdb contours -O $USER
sudo -u postgres psql contours -c 'CREATE EXTENSION postgis;'
```

## Load contour file into postgres
Load the data into the contours database:

```
osm2pgsql --slim -d contours --cache 5000 --style ./mapnik/osm2pgsql/contours.style ./mapnik/dem/contour*.pbf
```

The above command will take some time.

## Verify that you can render tiles with mapnik
```
python ./mapnik_render_tile.py
```
