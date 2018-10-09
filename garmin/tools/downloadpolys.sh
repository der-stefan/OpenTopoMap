#!/bin/bash

# (c) OpenTopoMap under CC-BY-SA license
# author: Martin Schuetz
# A download script for the polygons of all countries worldwide

dirs="africa antarctica asia australia-oceania central-america europe north-america south-america"

for d in $dirs
do
	echo $d
	wget -w 0.1 -np -r -l 1 -A poly http://download.geofabrik.de/$d/
done
