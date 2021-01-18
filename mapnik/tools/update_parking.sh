#!/bin/bash
#
#


DBname='gis'
toolpath='mapnik/tools'

cd ~/OpenTopoMap/


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
# already marked places are not touched

echo -n "update_parking: update planet_osm_polygon "
date

psql -d $DBname  -c "UPDATE planet_osm_polygon AS t1 set hiking='_otm_yes' \
            WHERE amenity='parking' AND  \
            (access IS NULL OR access IN ('yes','public')) AND \
            (hiking IS NULL OR (hiking!='no' AND hiking!='yes' AND hiking!='_otm_yes')) AND  \
             NOT EXISTS(SELECT osm_id FROM planet_osm_polygon AS t2 \
              WHERE (landuse IN ('industrial','commercial','residential','military','cemetery') OR \
                     amenity IN ('hospital','school','university') OR
                     aeroway IN ('aerodrome')) AND \
              ST_INTERSECTS(t2.way,ST_EXPAND(t1.way,50)));" 
              
echo -n "update_parking: update planet_osm_point "
date              

psql -d $DBname  -c "UPDATE planet_osm_point AS t1 set hiking='_otm_yes' \
            WHERE amenity='parking' AND  \
            (hiking IS NULL OR (hiking!='no' AND hiking!='yes' AND hiking!='_otm_yes')) AND  \
            (access IS NULL OR access IN ('yes','public')) AND \
             NOT EXISTS(SELECT osm_id FROM planet_osm_polygon AS t2 \
              WHERE (landuse IN ('industrial','commercial','residential','military','cemetery') OR \
                     amenity IN ('hospital','school','university','parking') OR
                     aeroway IN ('aerodrome')) AND \
              ST_INTERSECTS(t2.way,ST_EXPAND(t1.way,50)));" 

#
# set otm_isolation=200/500/1000 for each node where is no other node in 200/500/1000"m" distance with higher id
# so only one of a cluster of many nodes gets this otm_isolation
#


for dist in 1000 500 200 ; do
 echo -n "update_parking: isolation planet_osm_point $dist "
 date 
 psql -d $DBname  -c "UPDATE planet_osm_point AS t1 SET otm_isolation='$dist' \
                      WHERE amenity='parking' AND (hiking='yes' OR hiking='_otm_yes') AND otm_isolation IS NULL AND  \
                      NOT EXISTS (SELECT osm_id FROM planet_osm_point AS t2 \
                       WHERE amenity='parking' AND (hiking='yes' OR hiking='_otm_yes') AND t2.osm_id>t1.osm_id AND \
                       ST_INTERSECTS(t2.way,ST_EXPAND(t1.way,$dist)));"

 echo -n "update_parking: isolation planet_osm_polygon $dist "
 date 
 psql -d $DBname  -c "UPDATE planet_osm_polygon AS t1 SET otm_isolation='$dist' \
                      WHERE amenity='parking' AND (hiking='yes' OR hiking='_otm_yes') AND otm_isolation IS NULL AND  \
                      NOT EXISTS (SELECT osm_id FROM planet_osm_polygon AS t2 \
                       WHERE amenity='parking' AND (hiking='yes' OR hiking='_otm_yes') AND t2.way_area>t1.way_area AND \
                       ST_INTERSECTS(t2.way,ST_EXPAND(t1.way,$dist)));"

done                       

echo -n "update_parking: finish "
date 

