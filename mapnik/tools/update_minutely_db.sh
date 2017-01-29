#!/bin/bash

HOME_PATH=/home/otmuser
FLATNODES_PATH=/mnt/database/flat-nodes

n=`ps -ef | grep -v grep | grep osmosis | wc -l`
m=`ps -ef | grep -v grep | grep osm2pgsql | wc -l`

let i=n+m
date
if [ $i -gt 0 ]; then
	echo osmosis or osm2pgsql running
else
	echo starting update...
	osmosis --rri workingDirectory=$HOME_PATH/data/updates --simplify-change --write-xml-change $HOME_PATH/data/updates/changes.osc.gz 2> $HOME_PATH/data/updates/log
	echo $?
	osm2pgsql --append --slim -d gis  -C 8000 --number-processes 2 --flat-nodes $FLATNODES_PATH/gis-flat-nodes.bin --style $HOME_PATH/OpenTopoMap/mapnik/osm2pgsql/opentopomap.style $HOME_PATH/data/updates/changes.osc.gz -e 14-17 -o $HOME_PATH/data/updates/expire.list
	echo $?
	rm $HOME_PATH/data/updates/changes.osc.gz
	#cat $HOME_PATH/data/updates/expire.list | /usr/local/bin/render_expired --map=opentopomap --min-zoom=14 --touch-from=12 -t /mnt/tiles/
	# modify timestamp of meta tiles from exire list here...
	rm $HOME_PATH/data/updates/expire.list
	date
fi
