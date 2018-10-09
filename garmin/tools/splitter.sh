#!/bin/bash

#java -jar /usr/src/splitter-r590/splitter.jar mittelfranken-latest.osm.pbf  --output-dir=splitter-out

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

    mkdir -p $c-splitter-out

    java -jar /usr/src/splitter-r591/splitter.jar $c-latest.osm.pbf  --output-dir=$c-splitter-out --max-threads=32

done
