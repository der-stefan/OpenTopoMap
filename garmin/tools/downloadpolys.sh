#!/bin/bash

# (c) 2018-2020 OpenTopoMap under CC-BY-SA license
# author: Martin Schuetz, Stefan Erhardt
# A download script for the polygons of all countries worldwide

DATA_DIR=/home/garminotm/garmin_world/


continents="africa antarctica asia australia-oceania central-america europe north-america south-america"

for continent in $continents
do
	echo $continent
	wget -w 0.1 -np -r -l 1 -A poly http://download.geofabrik.de/$continent/ -P $DATA_DIR
done
