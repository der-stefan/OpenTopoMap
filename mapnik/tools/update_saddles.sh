#!/bin/bash
#
#  get all saddles, cols and notches with no direction, direction
#  described as text ("north", "nne" ..) or negative directions ("-10" is not
#  an error, but "170" is the same direction). Estimate directions with
#  height data and write this estimation back to datsabase.
#
#  The first run will update nearly all saddles, because most saddles has no
#  mapped direction. The following runs will be faster, because only new
#  saddles will be calculated.


# Constants: Name of the database, path tools and DEM file

DBname='gis'
toolpath='mapnik/tools'
demfile='mapnik/dem/dem-srtm.tiff'

psql -A -t -F ";" $DBname -c \
  "SELECT osm_id,ST_X(ST_Astext(ST_Transform(way,4326))),ST_Y(ST_Astext(ST_Transform(way,4326))),direction \
   FROM planet_osm_point WHERE \"natural\" IN ('saddle','col','notch') AND \
                               (direction IS NULL or direction NOT SIMILAR TO '[0-9]+');;" \
   | $toolpath/saddledirection -f $demfile -o sql | psql $DBname 

