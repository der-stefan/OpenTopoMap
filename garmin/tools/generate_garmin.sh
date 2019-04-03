#!/bin/bash

# (c) 2018-2019 OpenTopoMap under CC-BY-SA license
# authors: Martin Schuetz, Stefan Erhardt
# A script for generating worldwide Garmin files

GIT_DIR=/home/garminotm/OpenTopoMap/garmin
DATA_DIR=/home/garminotm/garmin_world

# Programs
SPLITTER_JAR=/home/garminotm/src/splitter-r592/splitter.jar
MKGMAP_JAR=/home/garminotm/src/mkgmap-r4284/mkgmap.jar
POLY2TILELIST_CMD=$GIT_DIR/tools/poly2tilelist.py

# Temp dirs
SPLITTER_OUTPUT_ROOT_DIR=$DATA_DIR/out/splitter_out
MKGMAP_OUTPUT_ROOT_DIR=$DATA_DIR/out/mkgmap_out
#MKGMAP_CONTOURS_OUTPUT_ROOT_DIR=$MKGMAP_OUTPUT_ROOT_DIR

# Log files
SPLITTER_LOG=$DATA_DIR/splitter.log
MKGMAP_LOG=$DATA_DIR/mkgmap.log

# Option files
MKGMAP_OPTS=$GIT_DIR/mkgmap_options
MKGMAP_STYLE_FILE=$GIT_DIR/style/opentopomap
#MKGMAP_TYP_FILE=$GIT_DIR/style/typ/OpenTopoMap.txt

#README_FILE=/var/www/otm_garmin/osm/readme.txt
#OSM_DATA_DIR=/var/www/otm_garmin/osm/data
#BOUNDS_DATA_DIR=/usr/src/bounds/bounds
#SEA_DATA_DIR=/usr/src/sea/sea
#WWW_OUT_ROOT_DIR=/var/www/otm_garmin/www/data

echo "******************************************"
echo "*	   This is the generate_garmin skript  "
echo "*                                        "
echo "*  splitter jar: $SPLITTER_JAR           "
echo "*  mkgmap   jar: $MKGMAP_JAR              "
echo "*"  
echo "*  splitter out dir: $SPLITTER_OUTPUT_ROOT_DIR"
echo "*                                        "
echo "*  mkgmaps opts: $MKGMAP_OPTS             "
echo "******************************************"

echo "Press enter to continue"
# temp removed #read continue

if [ ! -d $SPLITTER_OUTPUT_ROOT_DIR ]
then
	mkdir -p $SPLITTER_OUTPUT_ROOT_DIR
fi

if [ ! -d $MKGMAP_OUTPUT_ROOT_DIR ]
then
	mkdir -p $MKGMAP_OUTPUT_ROOT_DIR
fi



#continents="africa antarctica asia australia-oceania central-america europe north-america south-america"
continents="europe"

for continent in $continents
do
	echo "Generate continent $continent"
	
	for polyfile in $DATA_DIR/download.geofabrik.de/$continent/*.poly
	do
		countryname=${polyfile%.*}
		countryname=${countryname##*/}

		echo "Generate $countryname with polyfile $polyfile"

		SPLITTER_OUTPUT_DIR="$SPLITTER_OUTPUT_ROOT_DIR/$continent-splitter-out"
		MKGMAP_OUTPUT_DIR=$MKGMAP_OUTPUT_ROOT_DIR/$continent/$countryname
		mkdir -p $MKGMAP_OUTPUT_DIR
		echo "mkgmap output dir: $MKGMAP_OUTPUT_DIR"
		
		countrypbfs=`$POLY2TILELIST_CMD $polyfile $SPLITTER_OUTPUT_DIR/areas.list`

		mkgmapin=""
		for p in $countrypbfs
		do
			mkgmapin="${mkgmapin}$SPLITTER_OUTPUT_DIR/$p "
		done

		echo "mkmapin: $mkgmapin"
		echo -ne $mkgmapin > /tmp/mkgmapopts.txt

		java -Xmx10000m -jar $MKGMAP_JAR --output-dir=$MKGMAP_OUTPUT_DIR --style-file=$MKGMAP_STYLE_FILE --description="OTM $countryname" -c $MKGMAP_OPTS $mkgmapin

		mv *.img $MKGMAP_OUTPUT_DIR/.
	done
done
