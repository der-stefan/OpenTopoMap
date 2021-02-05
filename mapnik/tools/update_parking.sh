#!/bin/bash
#
# update_parking.sh: Try to find parking places useful for hiking. These places may
# be mapped with hiking=yes, but most are not. Such places are not located in "urban" areas
# (not near landuse=industrial, residential...) and are marked as hiking=_otm_yes in our
# database.
#


DBname='gis'
cd /home/otmuser/OpenTopoMap/mapnik/tools/

###### Prepare #########
#
# Check if hiking is a column of planet_osm_point and planet_osm_polygon, if not, create it
#

column=`psql -d $DBname -t -c "SELECT attname FROM pg_attribute \
         WHERE attrelid = ( SELECT oid FROM pg_class WHERE relname = 'planet_osm_point' ) \
         AND attname = 'hiking';"`

if [ "$column" != " hiking" ] ; then
 psql -d $DBname -c "ALTER TABLE planet_osm_point ADD COLUMN hiking text;"
fi

column=`psql -d $DBname -t -c "SELECT attname FROM pg_attribute \
         WHERE attrelid = ( SELECT oid FROM pg_class WHERE relname = 'planet_osm_polygon' ) \
         AND attname = 'hiking';"`

if [ "$column" != " hiking" ] ; then
 psql -d $DBname -c "ALTER TABLE planet_osm_polygon ADD COLUMN hiking text;"
fi

column=`psql -d $DBname -t -c "SELECT attname FROM pg_attribute \
         WHERE attrelid = ( SELECT oid FROM pg_class WHERE relname = 'planet_osm_point' ) \
         AND attname = 'otm_isolation';"`

if [ "$column" != " otm_isolation" ] ; then
 psql -d $DBname -c "ALTER TABLE planet_osm_point ADD COLUMN otm_isolation text;"
fi

column=`psql -d $DBname -t -c "SELECT attname FROM pg_attribute \
         WHERE attrelid = ( SELECT oid FROM pg_class WHERE relname = 'planet_osm_polygon' ) \
         AND attname = 'otm_isolation';"`

if [ "$column" != " otm_isolation" ] ; then
 psql -d $DBname -c "ALTER TABLE planet_osm_polygon ADD COLUMN otm_isolation text;"
fi



########## Update ###########
#
# Mark amenity=parking with hiking=_otm_yes if these parking places are not in urban areas
# already as hiking=yes marked places are not touched

echo -n "update_parking: update planet_osm_polygon "
date

psql -d $DBname  -c "UPDATE planet_osm_polygon AS t1 set hiking='_otm_yes' \
            WHERE amenity='parking' AND  \
            (access IS NULL OR access IN ('yes','public')) AND \
            (hiking IS NULL OR (hiking!='no' AND hiking!='yes')) AND  \
             NOT EXISTS(SELECT osm_id FROM planet_osm_polygon AS t2 \
              WHERE (landuse IN ('industrial','commercial','retail','residential','military','cemetery','allotments','farmyard') OR \
                     amenity IN ('hospital','school','university') OR \
                     leisure IN ('sports_centre','pitch') OR \
                     aeroway IN ('aerodrome')) AND \
              ST_INTERSECTS(t2.way,ST_EXPAND(t1.way,50)));" 
              
echo -n "update_parking: update planet_osm_point "
date              

psql -d $DBname  -c "UPDATE planet_osm_point AS t1 set hiking='_otm_yes' \
            WHERE amenity='parking' AND  \
            (hiking IS NULL OR (hiking!='no' AND hiking!='yes')) AND  \
            (access IS NULL OR access IN ('yes','public')) AND \
             NOT EXISTS(SELECT osm_id FROM planet_osm_polygon AS t2 \
              WHERE (landuse IN ('industrial','commercial','retail','residential','military','cemetery','allotments','farmyard') OR \
                     amenity IN ('hospital','school','university','parking') OR \
                     leisure IN ('sports_centre','pitch') OR \
                     aeroway IN ('aerodrome')) AND \
              ST_INTERSECTS(t2.way,ST_EXPAND(t1.way,50)));" 
              
# Export these parking places to a csv and calculate their isolation in an external script
#              
              
echo -n "update_parking: exporting polygon "
date              

rm -f /tmp/parking_polygon.csv /tmp/parking_point.csv

psql -A -t -F ";" $DBname  -c "SELECT osm_id,ST_X(ST_CENTROID(way)),ST_Y(ST_CENTROID(way)),way_area::INTEGER \
      FROM planet_osm_polygon WHERE amenity='parking' AND (hiking='yes' or hiking='_otm_yes');" > /tmp/parking_polygon.csv
      
echo -n "update_parking: exporting point "
date
            
psql -A -t -F ";" $DBname  -c "SELECT osm_id,ST_X(way),ST_Y(way),osm_id \
      FROM planet_osm_point WHERE amenity='parking' AND (hiking='yes' or hiking='_otm_yes');" > /tmp/parking_point.csv

rm -f tmp/parking_point.sql tmp/parking_polygon.sql

# Import the calculated isolations
#

echo -n "update_parking: isolations of points "
date
./parkingisolation.pl planet_osm_point   /tmp/parking_point.csv   5000 > /tmp/parking_point.sql
echo -n "update_parking: isolations of polygons "
date
./parkingisolation.pl planet_osm_polygon /tmp/parking_polygon.csv 5000 > /tmp/parking_polygon.sql
echo -n "update_parking: updating DB "
date
psql $DBname < /tmp/parking_point.sql   >/dev/null 2>>/dev/null
psql $DBname < /tmp/parking_polygon.sql >/dev/null 2>>/dev/null

# cleaning
#

rm -f /tmp/parking_point.sql /tmp/parking_polygon.sql
rm -f /tmp/hiking_polygon.csv /tmp/hiking_point.csv

# finish
#

echo -n "update_parking: finish "
date 
