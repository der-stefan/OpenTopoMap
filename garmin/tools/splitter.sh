#!/bin/bash

DATA_DIR=/home/garminotm/garmin_world
SPLITTER_OUTPUT_DIR=$DATA_DIR/out/splitter_out

SPLITTER_JAR=/home/garminotm/src/splitter-r592/splitter.jar

continents="africa antarctica asia australia-oceania central-america europe north-america south-america"
#continents="australia-oceania"
#continents="africa"
#continents="south-america"
#continents="asia north-america"
#continents="central-america"
#continents="europe"

for c in $continents
do
    echo "Splitting $c"

    mkdir -p $SPLITTER_OUTPUT_DIR/$c-splitter-out

    java -Xmx10000m -jar $SPLITTER_JAR $DATA_DIR/$c-latest.osm.pbf  --output-dir=$SPLITTER_OUTPUT_DIR/$c-splitter-out --max-threads=32 --geonames-file=$DATA_DIR/cities15000.txt --mapid=53530001

done
