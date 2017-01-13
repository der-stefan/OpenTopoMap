#!/bin/bash

#
#  get all saddles, cols and notches with no direction, direction
#  described as text ("north", "nne" ..) or negative directions ("-10" is not
#  an error, but "170" is the same direction). 
#  Write the result of getsaddledirection() to direction. 
#
#  The first run will take a long time, because nearly no saddle has a
#  mapped direction. The following runs will be faster, because only new
#  saddles will be calculated.


# Constants: Name of the database, path to saddledirection.sql

DBname='gis'
Path='mapnik/tools/'


#
# (re)install the function "getsaddledirection()" 
#
psql $DBname < $Path/saddledirection.sql

#
# Update all saddles with direction!=[0-180]
#
psql $DBname -c "UPDATE planet_osm_point SET direction=getsaddledirection(way,direction) WHERE \"natural\" IN ('saddle','col','notch') AND (direction IS NULL or direction NOT SIMILAR TO '[0-9]+');"

