#!/bin/bash

# (c) 2018-2021 OpenTopoMap under CC-BY-SA license
# authors: Stefan Erhardt, Martin Schuetz
# A script for generating worldwide Garmin files with OpenTopoMap style
#
# Usage ...for all continents:           bash ./generate_garmin.sh
#       ...for Europe:                   bash ./generate_garmin.sh 4
#       ...for daily changing continent: bash ./generate_garmin.sh "$(date +%w)"
#

GIT_DIR=/home/garminotm/OpenTopoMap/garmin
DATA_DIR=/home/garminotm/garmin_world

# Programs
SPLITTER_JAR=/home/garminotm/src/splitter-r602/splitter.jar
MKGMAP_JAR=/home/garminotm/src/mkgmap-r4745/mkgmap.jar
TILESINPOLY_CMD=$GIT_DIR/tools/tiles_in_poly.py

# Temp dirs
SPLITTER_OUTPUT_ROOT_DIR=$DATA_DIR/out/splitter_out
MKGMAP_OUTPUT_ROOT_DIR=$DATA_DIR/out/mkgmap_out

# Log files
SPLITTER_LOG=$DATA_DIR/splitter.log
MKGMAP_LOG=$DATA_DIR/mkgmap.log

# Option files
MKGMAP_OPTS=$GIT_DIR/opentopomap_options
MKGMAP_STYLE_FILE=$GIT_DIR/style/opentopomap
MKGMAP_TYP_FILE=$GIT_DIR/style/typ/opentopomap.txt

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
declare -A id
id=([africa]=0 [asia]=1 [australia-oceania]=2 [central-america]=3 [europe]=4 [north-america]=5 [south-america]=6)

# if script is called with number, select this continent. Else go through all continents by default.
case "$1" in
    (*[0-9]*)
        continent_selection=${continents[$1]}
        continents=("${continent_selection[@]}")
esac

for continent in $continents
do
	FAMILY_ID=$(( 53000+${id[$continent]}*100 ))
	MAPID=$(( $FAMILY_ID*1000+1 ))
	
	echo "Download continent $continent..."
	wget -N http://download.geofabrik.de/$continent-latest.osm.pbf -P $DATA_DIR
	continentdate=`stat -c=%y $DATA_DIR/$continent-latest.osm.pbf | cut -c2-11`
	
	echo "Split $continent..."
	rm -rf $SPLITTER_OUTPUT_ROOT_DIR/$continent
	mkdir -p $SPLITTER_OUTPUT_ROOT_DIR/$continent
    java -Xmx10000m -jar $SPLITTER_JAR $DATA_DIR/$continent-latest.osm.pbf --output-dir=$SPLITTER_OUTPUT_ROOT_DIR/$continent --max-threads=32 --geonames-file=$DATA_DIR/cities15000.txt --mapid=$MAPID &> $SPLITTER_OUTPUT_ROOT_DIR/splitter-$continent.log
	
	for polyfile in $DATA_DIR/download.geofabrik.de/$continent/*.poly
	do
		FAMILY_ID=$((FAMILY_ID+1))

		countryname=${polyfile%.*}
		countryname=${countryname##*/}
		countryname_short=${countryname:0:25}

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
		
		# reduce DEM resolution for russia due to 4 GB file size limit
		if [[ "$countryname" == *"russia-asian-part"* ]]; then
			REDUCED_DENSITY="--dem-dists=9942,19884,39768,39768,53024,53024"
		else
			REDUCED_DENSITY=""
		fi
		
		# Basecamp maps for Europe
		if [[ "$continent" == *"europe"* ]]; then
			GMAPI="--gmapi"
		else
			GMAPI=""
		fi

		java -Xmx10000m -jar $MKGMAP_JAR --output-dir=$MKGMAP_OUTPUT_DIR --style-file=$MKGMAP_STYLE_FILE --description="OpenTopoMap ${countryname_short^} ${continentdate}" --area-name="OpenTopoMap ${countryname_short^} ${continentdate}" --overview-mapname="OpenTopoMap_${countryname_short^}" --family-name="OpenTopoMap ${countryname_short^} ${continentdate}" --family-id=$FAMILY_ID --series-name="OpenTopoMap ${countryname_short^} ${continentdate}" --bounds=$BOUNDS_FILE --precomp-sea=$SEA_FILE --dem=$DEM_FILE -c $MKGMAP_OPTS $REDUCED_DENSITY $GMAPI $mkgmapin $MKGMAP_TYP_FILE &> $MKGMAP_OUTPUT_DIR/mkgmap.log
		cd $MKGMAP_OUTPUT_DIR
		mv OpenTopoMap\ ${countryname^}\ ${continentdate}.gmap OpenTopoMap_${countryname^}.gmap
		rm $WWW_OUT_ROOT_DIR/$continent/$countryname/otm-$countryname.zip
		zip -r $WWW_OUT_ROOT_DIR/$continent/$countryname/otm-$countryname.zip OpenTopoMap_${countryname^}.gmap
		rm -rf $MKGMAP_OUTPUT_DIR/OpenTopoMap_${countryname^}.gmap
		rm $MKGMAP_OUTPUT_DIR/53*.img $MKGMAP_OUTPUT_DIR/53*.tdb $MKGMAP_OUTPUT_DIR/ovm*.img $MKGMAP_OUTPUT_DIR/*.typ $MKGMAP_OUTPUT_DIR/OpenTopoMap_${countryname^}.img $MKGMAP_OUTPUT_DIR/OpenTopoMap_${countryname^}_mdr.img $MKGMAP_OUTPUT_DIR/OpenTopoMap_${countryname^}.mdx $MKGMAP_OUTPUT_DIR/OpenTopoMap_${countryname^}.tdb
		mv $MKGMAP_OUTPUT_DIR/gmapsupp.img $WWW_OUT_ROOT_DIR/$continent/$countryname/otm-$countryname.img
		touch -m --date="$continentdate" $WWW_OUT_ROOT_DIR/$continent/$countryname/otm-$countryname.img
		touch $WWW_OUT_ROOT_DIR/$continent
	done
	
	rm -rf $SPLITTER_OUTPUT_ROOT_DIR/$continent
done
