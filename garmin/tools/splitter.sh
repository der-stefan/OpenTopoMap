#!/bin/bash

#java -jar /usr/src/splitter-r590/splitter.jar mittelfranken-latest.osm.pbf  --output-dir=splitter-out

DATA_DIR=/home/garminotm/garmin_world
SPLITTER_OUTPUT_ROOT_DIR=$DATA_DIR/out/splitter_out

#continents="africa antarctica asia australia-oceania central-america europe north-america south-america"
continents="australia-oceania"
continents="africa"
continents="south-america"
continents="asia north-america"
continents="central-america"
continents="europe"

for c in $continents
do
    echo "Splitting $c"

    mkdir -p $SPLITTER_OUTPUT_ROOT_DIR/$c-splitter-out

    java -Xmx10000m -jar /home/garminotm/src/splitter-r591/splitter.jar $c-latest.osm.pbf  --output-dir=$SPLITTER_OUTPUT_ROOT_DIR/$c-splitter-out --max-threads=32

done
