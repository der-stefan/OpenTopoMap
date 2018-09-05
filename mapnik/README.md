# Setting up a OpenTopoMap tile server - a complete walkthrough

Based on the [HOWTO](HOWTO_Ubuntu_16.04) this guide describes how to install your own OpenTopoMap tile server on Ubuntu 16.04.

## Create a virtual computer
* Generation 2
* Memory: 32000MB (not dynamic)
* Virtual Harddisk: 1024GB

## Install ubuntu
* Download [Ubuntu Server 16.04.4 LTS](https://www.ubuntu.com/download/server)
* Attach iso, start
* Install Ubuntu Server
* Language: English - English
* Country: other - Europe - Switzerland - United States en_US.UTF-8
* Detect keyboard layout: No
* Country of origin for the keyboard: Switzerland
* Keyboard layout: Switzerland
* Hostname: MapServer
* Full name for new user: gis
* Username for your account: gis
* Choose password for the new user: geheim
* Use weak password: Yes
* Encrypt your home directory: No
* Is this time zone correct: Yes
* Partitioning method: Guided - use entire disk
* Select disk to partition: SCSI1
* Write changes to disks: Yes
* HTTP proxy: Continue
* No automatic updates
* Software selection:
** standard system utilities
** OpenSSH Server
* Wait...
* Installation complete: Continue
* Fix IP address on your router/dhcp (e.g. 192.168.2.63)
* Login with user gis
* ``` sudo shutdown -P now ```
* Create a snapshot
* Start server

From now on you can connect with PuTTY.

## Install updates
```
sudo -i
apt update
apt upgrade
sync;sync;shutdown -r now
```

## Install Software
```
sudo apt install libboost-all-dev git-core tar unzip wget bzip2 build-essential autoconf libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin libprotobuf-c0-dev protobuf-c-compiler libfreetype6-dev libpng12-dev libtiff5-dev libicu-dev libgdal-dev libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont lua5.1 liblua5.1-dev libgeotiff-epsg cmake lua5.3 liblua5.3-dev devscripts libjson-perl libipc-sharelite-perl libgd-perl debhelper
```
Wait a moment...

## Install Postgres database
```
sudo apt-get install postgresql postgresql-contrib postgis postgresql-9.5-postgis-2.2
```
Wait...
```
sudo nano /etc/postgresql/9.5/main/postgresql.conf
```
In nano you can search with ```Ctrl-w```. Check/edit the following values:
```
shared_buffers = 128MB
work_mem = 256MB			
maintenance_work_mem = 256MB
autovacuum = off
```
save with ```Ctrl-x``` then ```y``` then ```Enter```
```
sudo nano /etc/sysctl.conf
```
At the top, after the other kernel-definitions, insert the following and save it:
```
kernel.shmmax=268435456
```

## Install mapnik renderer
```
sudo apt install libmapnik3.0 libmapnik-dev mapnik-utils python-mapnik unifont
```
Create a snapshot.

## Compile and install osm2pgsql
```
mkdir ~/src
cd ~/src
git clone git://github.com/openstreetmap/osm2pgsql.git
cd osm2pgsql
mkdir build && cd build
cmake ..
make
sudo make install
```

## Compile and install mod_tile
```
cd ~/src
git clone -b switch2osm git://github.com/SomeoneElseOSM/mod_tile.git
cd mod_tile
./autogen.sh
./configure
make
sudo make install
sudo make install-mod_tile
sudo ldconfig
```

## Setting up the apache webserver
### Configure renderd
edit renderd.conf:
```
sudo nano /usr/local/etc/renderd.conf
```
Check/Update this parameters and save the file:
```
num_threads=4
XML=/home/gis/OpenTopoMap/mapnik/opentopomap.xml
URI=/hot/
```

### Configure apache
```
sudo mkdir /var/lib/mod_tile
sudo chown gis /var/lib/mod_tile

sudo mkdir /var/run/renderd
sudo chown gis /var/run/renderd
```
Edit mod_tile.conf:
```
sudo nano /etc/apache2/conf-available/mod_tile.conf
```
Add the following line to that new file and save it:
```
LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so
```
Then:
```
sudo a2enconf mod_tile
```
Do not reload apache now. Edit 000-default.conf:
```
sudo nano /etc/apache2/sites-available/000-default.conf
```
Add the following between the "ServerAdmin" and "DocumentRoot" lines:
```
LoadTileConfigFile /usr/local/etc/renderd.conf
ModTileRenderdSocketName /var/run/renderd/renderd.sock
# Timeout before giving up for a tile to be rendered
ModTileRequestTimeout 0
# Timeout before giving up for a tile to be rendered that is otherwise missing
ModTileMissingRequestTimeout 30
```
Reload apache twice:
```
sudo service apache2 reload
sudo service apache2 reload
```
## Create database
```
sudo -u postgres -i
createuser --createdb gis -s
exit
createdb gis
psql -d gis -c 'CREATE EXTENSION postgis;'
```
## Download OpenTopoMap data
```
cd ~
git clone https://github.com/der-stefan/OpenTopoMap.git
cd OpenTopoMap/mapnik
```
Get the generalized water polygons from http://openstreetmapdata.com/:
```
mkdir data && cd data
wget http://data.openstreetmapdata.com/water-polygons-generalized-3857.zip
wget http://data.openstreetmapdata.com/water-polygons-split-3857.zip
unzip water-polygons-generalized-3857.zip
unzip water-polygons-split-3857.zip
```

## Configure Python 3 as default
```
sudo nano ~/.bashrc
```
Insert the following at the bottom and save it:
```
alias python=python3
```
Then
```
source ~/.bashrc
```
Check Python version with ```python --version```

## Install phyghtmap
```
sudo apt-get install python3-setuptools python3-matplotlib python3-bs4 python3-numpy python3-gdal
cd ~/src
wget http://katze.tfiu.de/projects/phyghtmap/phyghtmap_2.10.orig.tar.gz
tar -xvzf phyghtmap_2.10.orig.tar.gz
cd phyghtmap-2.10
sudo python3 setup.py install
```

## Hillshade and countours
### Install Software
```
sudo apt-get install gdal-bin python-gdal
```
### Download all SRTM tiles you need (or follow this example)
```
mkdir ~/srtm
cd ~/srtm
sudo nano list.txt
```
Insert the following:
```
http://viewfinderpanoramas.org/dem3/M31.zip
http://viewfinderpanoramas.org/dem3/M32.zip
http://viewfinderpanoramas.org/dem3/M33.zip
http://viewfinderpanoramas.org/dem3/L31.zip
http://viewfinderpanoramas.org/dem3/L32.zip
```
Save it and continue with:
```
wget -i list.txt
```
Unpack all zip files
```
for zipfile in *.zip;do unzip -j -o "$zipfile" -d unpacked; done
```
Fill all voids
```
cd unpacked
for hgtfile in *.hgt;do gdal_fillnodata.py $hgtfile $hgtfile.tif; done
```
Merge all .tifs into one huge tif. This file is the raw DEM with full resolution and the start for any further steps. Don't delete raw.tif after these steps, you may use it for estimation of saddle directions.
```
mkdir ~/data
gdal_merge.py -n 32767 -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -o ../../data/raw.tif *.hgt.tif
```

Convert the raw file into Mercator projection, interpolate and shrink
```
cd ~/data
gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 1000 1000 raw.tif warp-1000.tif

gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 5000 5000 raw.tif warp-5000.tif

gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 500 500 raw.tif warp-500.tif

gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 700 700 raw.tif warp-700.tif

gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 90 90 raw.tif warp-90.tif
```
```
sudo shutdown -P now
```
Create snapshot, start

Create color relief for different zoom level
```
cd ~/data
gdaldem color-relief -co COMPRESS=LZW -co PREDICTOR=2 -alpha warp-5000.tif ~/OpenTopoMap/mapnik/relief_color_text_file.txt relief-5000.tif

gdaldem color-relief -co COMPRESS=LZW -co PREDICTOR=2 -alpha warp-500.tif ~/OpenTopoMap/mapnik/relief_color_text_file.txt relief-500.tif
```
### Create hillshade for different zoom levels
```
gdaldem hillshade -z 7 -compute_edges -co COMPRESS=JPEG warp-5000.tif hillshade-5000.tif

gdaldem hillshade -z 7 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-1000.tif hillshade-1000.tif

gdaldem hillshade -z 4 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-700.tif hillshade-700.tif

gdaldem hillshade -z 2 -co compress=lzw -co predictor=2 -co bigtiff=yes -compute_edges warp-90.tif hillshade-90.tif && gdal_translate -co compress=JPEG -co bigtiff=yes -co tiled=yes hillshade-90.tif hillshade-90-jpeg.tif
```

### Create contour lines
```
phyghtmap --max-nodes-per-tile=0 -s 10 -0 --pbf warp-90.tif
```
Wait...
```
mv lon-*.osm.pbf contours.pbf
```

### Create contours database
```
createdb contours
sudo -u postgres psql -d contours -c 'CREATE EXTENSION postgis;'
```

### Load contour file into database
```
cd ~
nano loadcontours.sh
```
Insert the following:
```
#!/bin/bash
screen osm2pgsql --slim -d contours -C 12000 --number-processes 10 --style ~/OpenTopoMap/mapnik/osm2pgsql/contours.style data/contours.pbf
```
Save, exit, then:
```
chmod +x loadcontours.sh

cd ~/data
wget http://download.geofabrik.de/europe/switzerland-latest.osm.pbf
mkdir ~/data/updates
cd ~/data/updates
wget http://download.geofabrik.de/europe-updates/state.txt

cd ~
nano loaddata.sh
```
Insert the following:
```
#!/bin/bash
screen osm2pgsql --slim -d gis -C 12000 --number-processes 10 --style ~/OpenTopoMap/mapnik/osm2pgsql/opentopomap.style data/switzerland-latest.osm.pbf
```
Save, exit, then:
```
chmod +x loaddata.sh
```

Login directly to the server, not via SSH (I'm not sure, if/how the screen command works with PuTTY)
```
./loadcontours.sh
./loaddata.sh
```
Wait...
Now you can Login via SSH (PuTTY) again.

## Preprocessing
```
cd ~/OpenTopoMap/mapnik/tools/
cc -o saddledirection saddledirection.c -lm -lgdal
cc -Wall -o isolation isolation.c -lgdal -lm -O2
psql gis < arealabel.sql
./update_lowzoom.sh
```

### Edit update_saddles.sh
```
nano update_saddles.sh
```
Replace ```mapnik/dem/dem-srtm.tiff``` with ```/home/gis/data/raw.tif``` and save it.
```
./update_saddles.sh
```

```
nano update_isolations.sh
```
Replace ```mapnik/dem/dem-srtm.tiff``` with ```/home/gis/data/raw.tif``` and save it.
```
./update_isolations.sh
```

```
psql gis < stationdirection.sql
psql gis < viewpointdirection.sql
psql gis < pitchicon.sql
```

# Find out the sizes of the databases:
```
psql -d gis -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;"
```

# Edit opentopomap.xml
```
nano ~/OpenTopoMap/mapnik/opentopomap.xml
```
Find "If you imported the contour lines as suggested in the HOWTO_DEM, use following" (about row 308). Comment out the other line, so that it shows as following:
```
<Datasource>
	<!-- If you imported the contour lines as suggested in the HOWTO_DEM, use following:-->
	<Parameter name="table">(SELECT way,ele FROM planet_osm_line) AS contours </Parameter>
	<!--<Parameter name="table">(SELECT way,ele FROM contours) AS contours </Parameter>-->
	<Parameter name="dbname">contours</Parameter>
	&postgis-settings;
</Datasource>
```
Save it, then
```
cd ~/data
gdaldem hillshade -z 5 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-500.tif hillshade-500.tif
gdaldem hillshade -z 5 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-90.tif hillshade-30m-jpeg.tif

mkdir ~/OpenTopoMap/mapnik/dem
cd ~/OpenTopoMap/mapnik/dem
ln -s ~/data/*.tif .

```


# Start renderd
```
sudo mkdir /var/run/renderd
sudo chown gis /var/run/renderd

renderd -f -c /usr/local/etc/renderd.conf
```
In a browser open http://192.168.2.63/hot/16/34343/23014.png

# Running renderd in the background
Change RUNASUSER from renderaccount to gis and save the file:
```
nano ~/src/mod_tile/debian/renderd.init
```

```
sudo cp ~/src/mod_tile/debian/renderd.init /etc/init.d/renderd
sudo chmod u+x /etc/init.d/renderd
sudo cp ~/src/mod_tile/debian/renderd.service /lib/systemd/system/

sudo /etc/init.d/renderd start
```

Automatic start:
```
sudo systemctl enable renderd
```
