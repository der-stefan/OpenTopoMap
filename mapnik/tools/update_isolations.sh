#!/bin/bash
#
# get all natural=peak and natural volcano without otm_isolation=*,
# calculates the topographic isolation of each peak and writes this back
# to the database.
# The isolation is calculated based on the distance to the next neighbours 
# in a first step. In a second step it is calculated based on DEM data.
#
# The first run will calculate each peak in the DB, because otm_isolation
# is empty. If otm_isolation doesn't exist, it will be created.
#
# The following runs will update only some newly mapped peaks. Most of them
# only based on DEM data, because their neighbour are not newly mapped. That
# will leed to some different isolations than we could get in the first run
# (with all the neighbours).  
#
# The first run may take a hour, following runs some seconds.
#


DBname='gis'
toolpath='mapnik/tools'
demfile='mapnik/dem/dem-srtm.tiff'

cd ~/OpenTopoMap/


###### Prepare #########
#
# Check if otm_isolation is a column of planet_osm_point, if not, create it
#

column=`psql -d $DBname -t -c "SELECT attname FROM pg_attribute \
         WHERE attrelid = ( SELECT oid FROM pg_class WHERE relname = 'planet_osm_point' ) \
         AND attname = 'otm_isolation';"`

if [ "$column" != " otm_isolation" ] ; then
 psql -d $DBname -c "ALTER TABLE planet_osm_point ADD COLUMN otm_isolation text;"
fi

#
# Check once again. If the column doesn't exist -> EXIT
#

column=`psql -d $DBname -t -c "SELECT attname FROM pg_attribute \
         WHERE attrelid = ( SELECT oid FROM pg_class WHERE relname = 'planet_osm_point' ) \
         AND attname = 'otm_isolation';"`

if [ "$column" != " otm_isolation" ] ; then
 echo "Sorry, no column otm_isolation in planet_osm_point"
 exit 1
fi


########## Update ###########
#
# Get all peaks without isolation, pipe it through toolpath/isolation and update this column in DB
#

psql -A -t -F ";" $DBname -c \
  "SELECT osm_id,ST_X(ST_Astext(ST_Transform(way,4326))),ST_Y(ST_Astext(ST_Transform(way,4326))),ele \
   FROM planet_osm_point WHERE \"natural\" IN ('peak','volcano') AND \
                               (otm_isolation IS NULL or otm_isolation NOT SIMILAR TO '[0-9]+');;" \
  | $toolpath/isolation -f $demfile -o sql | psql $DBname 

