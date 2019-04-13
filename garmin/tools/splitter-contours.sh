#!/bin/bash

DATA_DIR=/home/garminotm/garmin_world
SPLITTER_OUTPUT_DIR=$DATA_DIR/dem/contours/splitter_out

SPLITTER_JAR=/home/garminotm/src/splitter-r592/splitter.jar

#continents="africa antarctica asia australia-oceania central-america europe north-america south-america"
continents="africa antarctica asia australia-oceania central-america north-america south-america"
#continents="africa"
#continents="antarctica"
#continents="asia"
#continents="australia-oceania"
#continents="central-america"
#continents="europe"
#continents="south-america"
#continents="north-america"

for c in $continents
do
    echo "Splitting $c"

    mkdir -p $SPLITTER_OUTPUT_DIR/$c-splitter-out

    java -Xmx10000m -jar $SPLITTER_JAR $DATA_DIR/dem/contours/contours-$c.pbf  --output-dir=$SPLITTER_OUTPUT_DIR/$c-splitter-out --max-threads=32 --mapid=53350001

done
