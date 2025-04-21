#!/bin/bash

# (c) 2018-2020 OpenTopoMap under CC-BY-SA license
# authors: Martin Schuetz, Stefan Erhardt
# A script for generating worldwide Garmin files

GIT_DIR=/home/garminotm/OpenTopoMap/garmin
DATA_DIR=/home/garminotm/garmin_world

# Programs
SPLITTER_JAR=/home/garminotm/src/splitter-r597/splitter.jar
MKGMAP_JAR=/home/garminotm/src/mkgmap-r4588/mkgmap.jar
TILESINPOLY_CMD=$GIT_DIR/tools/tiles_in_poly.py

# Temp dirs
SPLITTER_OUTPUT_ROOT_DIR=$DATA_DIR/dem/contours/splitter_out
MKGMAP_OUTPUT_ROOT_DIR=$DATA_DIR/dem/contours/mkgmap_out

# Log files
SPLITTER_LOG=$DATA_DIR/splitter.log
MKGMAP_LOG=$DATA_DIR/mkgmap.log

# Option files
MKGMAP_OPTS=$GIT_DIR/contours_options
MKGMAP_STYLE_FILE=$GIT_DIR/style/contours
MKGMAP_TYP_FILE=$GIT_DIR/style/typ/contours.txt

BOUNDS_FILE=$DATA_DIR/bounds-latest.zip
SEA_FILE=$DATA_DIR/sea-latest.zip
DEM_FILE=$DATA_DIR/dem/viewfinderpanoramas.zip
WWW_OUT_ROOT_DIR=/var/www/garmin.opentopomap.org


if [ ! -d $SPLITTER_OUTPUT_ROOT_DIR ]
then
	mkdir -p $SPLITTER_OUTPUT_ROOT_DIR
fi

if [ ! -d $MKGMAP_OUTPUT_ROOT_DIR ]
then
	mkdir -p $MKGMAP_OUTPUT_ROOT_DIR
fi

continents=("africa" "asia" "australia-oceania" "central-america" "europe" "north-america" "south-america")

# if script is called with number, select this continent. Else go through all continents by default.
case "$1" in
    (*[0-9]*)
        continent_selection=${continents[$1]}
        continents=("${continent_selection[@]}")
esac

for continent in $continents
do

	echo "Split $continent..."
	mkdir -p $SPLITTER_OUTPUT_ROOT_DIR/$continent
	java -Xmx14000m -jar $SPLITTER_JAR $DATA_DIR/dem/contours/contours-$continent.pbf  --output-dir=$SPLITTER_OUTPUT_ROOT_DIR/$continent --mapid=53350001 --keep-complete=false > $SPLITTER_OUTPUT_ROOT_DIR/$continent/splitter.log
	
	for polyfile in $DATA_DIR/download.geofabrik.de/$continent/*.poly
	do
		countryname=${polyfile%.*}
		countryname=${countryname##*/}

		echo "Generate $countryname with polyfile $polyfile..."

		SPLITTER_OUTPUT_DIR="$SPLITTER_OUTPUT_ROOT_DIR/$continent"
		MKGMAP_OUTPUT_DIR=$MKGMAP_OUTPUT_ROOT_DIR/$continent/$countryname
		mkdir -p $MKGMAP_OUTPUT_DIR
		
		countrypbfs=`$TILESINPOLY_CMD $polyfile $SPLITTER_OUTPUT_DIR/areas.list`

		mkgmapin=""
		for p in $countrypbfs
		do
			mkgmapin="${mkgmapin}$SPLITTER_OUTPUT_DIR/$p "
		done
		
		# reduce resolution for china due to 4 GB file size limit
		if [[ "$countryname" == *"china"* ]]; then
			REDUCED_DENSITY="--reduce-point-density=10"
		else
			REDUCED_DENSITY=""
		fi
		
		java -Xmx10000m -jar $MKGMAP_JAR --output-dir=$MKGMAP_OUTPUT_DIR --style-file=$MKGMAP_STYLE_FILE --description="OpenTopoMap ${countryname^} contours" --bounds=$BOUNDS_FILE -c $MKGMAP_OPTS $REDUCED_DENSITY $mkgmapin $MKGMAP_TYP_FILE > $MKGMAP_OUTPUT_DIR/mkgmap.log

		rm $MKGMAP_OUTPUT_DIR/53*.img $MKGMAP_OUTPUT_DIR/53*.tdb $MKGMAP_OUTPUT_DIR/ovm*.img $MKGMAP_OUTPUT_DIR/*.typ
		mv $MKGMAP_OUTPUT_DIR/gmapsupp.img $WWW_OUT_ROOT_DIR/$continent/$countryname/otm-$countryname-contours.img

	done
	
	rm -rf $SPLITTER_OUTPUT_ROOT_DIR/$continent
done
