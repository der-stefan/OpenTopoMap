#!/bin/bash

# (c) 2018 OpenTopoMap under CC-BY-SA license
# authors: Martin Schuetz, Stefan Erhardt
# An interactive script for generating worldwide Garmin files

GIT_DIR=/home/garminotm/OpenTopoMap/garmin
DATA_DIR=/home/garminotm/garmin_world

# Programs
SPLITTER_JAR=/home/garminotm/src/splitter-r591/splitter.jar
MKGMAP_JAR=/home/garminotm/src/mkgmap-r4245/mkgmap.jar
POLY24_CMD=$GIT_DIR/tools/poly24.py

# Temp dirs
SPLITTER_OUTPUT_ROOT_DIR=$DATA_DIR/out/splitter_out
MKGMAP_OUTPUT_ROOT_DIR=$DATA_DIR/out/mkgmap_out
MKGMAP_CONTOURS_OUTPUT_ROOT_DIR=$MKGMAP_OUTPUT_ROOT_DIR

# Data dirs
OSM_WORLD_FILE=$DATA_DIR/bayern-latest.osm.pbf

# Log files
SPLITTER_LOG=$DATA_DIR/splitter.log
MKGMAP_LOG=$DATA_DIR/mkgmap.log

# Option files
MKGMAP_OPTS=$GIT_DIR/mkgmap_options
MKGMAP_STYLE_FILE=$GIT_DIR/style/opentopomap
MKGMAP_TYP_FILE=$GIT_DIR/style/typ/OpenTopoMap.txt

#README_FILE=/var/www/otm_garmin/osm/readme.txt
#OSM_DATA_DIR=/var/www/otm_garmin/osm/data
#BOUNDS_DATA_DIR=/usr/src/bounds/bounds
#SEA_DATA_DIR=/usr/src/sea/sea
#WWW_OUT_ROOT_DIR=/var/www/otm_garmin/www/data

echo "******************************************"
echo "*	   This is the generate_garmin skript  "
echo "*                                        "
echo "*  splitter jar: $SPLITTER_JAR           "
echo "*  mkgmap   jar: $MKMAP_JAR              "
echo "*"
echo "*  osm world file: $OSM_WORLD_FILE"
echo "*"  
echo "*  splitter out dir: $SPLITTER_OUTPUT_ROOT_DIR"
echo "*                                        "
echo "o  mkgmaps opts: $MKGMAP_OPTS             "
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

#echo "Split World file"
# temp removed #java -jar $SPLITTER_JAR $OSM_WORLD_FILE --output-dir=$SPLITTER_OUTPUT_ROOT_DIR 2>&1 > $SPLITTER_LOG

continents="bayern"
#continents="africa antarctica asia australia-oceania central-america europe north-america south-america"
#continents="australia-oceania"
#continents="africa"
continents="asia"
continents="north-america"
continents="antarctica central-america south-america"
continents="europe"

for continent in $continents
do
	echo "Generate Continent $continent"

	#for polyfile in download.geofabrik.de/europe/germany/bayern/*.poly
	#for polyfile in download.geofabrik.de/europe/germany/bayern/mittelfranken.poly
	
        for polyfile in download.geofabrik.de/$continent/*.poly
        do
		countryname=${polyfile%.*}
		countryname=${countryname##*/}

		echo "Generate $countryname with polyfile $polyfile"

                SPLITTER_OUTPUT_DIR="$SPLITTER_OUTPUT_ROOT_DIR/$continent-splitter-out"

		osmpbfs=`$POLY24_CMD $polyfile $SPLITTER_OUTPUT_DIR/areas.list`

		mkgmapin=""

		for p in $osmpbfs
		do
#			mkgmapin="${mkgmapin}input-file=$SPLITTER_OUTPUT_ROOT_DIR/$p\n"
			mkgmapin="${mkgmapin}$SPLITTER_OUTPUT_DIR/$p "
		done

                echo "mkmapin: $mkgmapin"

		echo -ne $mkgmapin > /tmp/mkgmapopts.txt

#		java -jar $MKGMAP_JAR -c /tmp/mkgmapopts.txt --output-dir=$MKGMAP_OUTPUT_ROOT_DIR -c $MKGMAP_OPTS --style-file=$MKGMAP_STYLE_FILE $MKGMAP_TYP_FILE
#		java -jar $MKGMAP_JAR $mkgmapin --output-dir=$MKGMAP_OUTPUT_ROOT_DIR -c $MKGMAP_OPTS --style-file=$MKGMAP_STYLE_FILE $MKGMAP_TYP_FILE

                MKGMAP_OUTPUT_DIR=$MKGMAP_OUTPUT_ROOT_DIR/$continent/$countryname

                mkdir -p $MKGMAP_OUTPUT_DIR

                echo "mkgmap output dir: $MKGMAP_OUTPUT_DIR"

                rm *.img

		        java -Xmx10000m -jar $MKGMAP_JAR --output-dir=$MKGMAP_OUTPUT_DIR --style-file=$MKGMAP_STYLE_FILE -c $MKGMAP_OPTS $mkgmapin $MKGMAP_TYP_FILE

                mv *.img $MKGMAP_OUTPUT_DIR/.
	done
done
