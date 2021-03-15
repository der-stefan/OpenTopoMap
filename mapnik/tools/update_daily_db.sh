#!/bin/bash
#
# Downloads alle changesets from $lastupdate to now, imports them to the database
# and does preprocessing ("normal" preprocessing as default additional lowzoom database if 
# the parameter -withlowzoom is set.
# if -onlypreprocessing is set, do only preprocessing, but no import
#
# needs a working dir for download and to store the last import time in a file "latest_osc"
#
# Tirex must me stopped while this is running.
#

LOGDIR="/home/otmuser/logs/"
WORKDIR="/home/otmuser/data/updates/"

cd $WORKDIR
cp latest_osc latest_osc.bak

m=`ps -ef | grep -v grep | grep osmupdate    | wc -l`
o=`ps -ef | grep -v grep | grep osm2pgsql    | wc -l`

let i=$n+$m

if [ $i = 0 ]; then
 d=`date +"%Y-%m-%d %H:%M:%S"`
 echo "$d --otmuser----------------------------------------------------------------"
 echo "$d starting daily update"
 if [ "$1" != "-onlypreprocessing" ] ; then
  rm -f cumulated_changefile.osc
  lastupdate=`cat latest_osc`
  d=`date +"%Y-%m-%d %H:%M:%S"`
  echo "$d osmupdate fetching changes from $lastupdate till now"

#
# get files and build cumulated_changefile.osc 
#
  gotosc=0
  /usr/local/bin/osmupdate $lastupdate cumulated_changefile.osc
  if ( find ~/data/updates -name cumulated_changefile.osc -mmin -600 -size +10k | grep cumulated_changefile.osc >/dev/null 2>/dev/null) ; then
   gotosc=1
   /usr/local/bin/osmconvert  cumulated_changefile.osc --out-timestamp > latest_osc.running
   /usr/local/bin/osmconvert  cumulated_changefile.osc --out-statistics > cumulated_changefile.statistic
   nodes=`cat cumulated_changefile.statistic | grep nodes: | cut -d " " -f2`
   ways=`cat cumulated_changefile.statistic | grep ways: | cut -d " " -f2`
   rels=`cat cumulated_changefile.statistic | grep relations: | cut -d " " -f2`
   tmin=`cat cumulated_changefile.statistic | grep "timestamp min:" | cut -d " " -f3`
   tmax=`cat cumulated_changefile.statistic | grep "timestamp max:" | cut -d " " -f3`
   dmin=`date +"%s" --date "$tmin"`  
   dmax=`date +"%s" --date "$tmax"`
   dh=`echo $dmin $dmax | awk '{printf("%0.1f\n",($2-$1)/60/60);};'`
   newupdate=`cat latest_osc.running`
   d=`date +"%Y-%m-%d %H:%M:%S"`
   echo "$d osmupdate got changes from $tmin to $tmax ($dh hours) with $nodes nodes $ways ways $rels relations"
  fi
 else
  gotosc=1
  d=`date +"%Y-%m-%d %H:%M:%S"`
  echo "$d no download because $1 was set"
  cp latest_osc.bak latest_osc
 fi
 
#
# Import into Database
#
 if [ $gotosc = 1 ] ; then
  if [ "$1" = "-onlypreprocessing" ] ; then
   osm2pgsqlret=0
  else
   find $WORKDIR -name "expire.list*" -mtime +42 -exec rm {} \;
   d=`date +"%Y-%m-%d %H:%M:%S"`
   echo "$d starting osm2pgsql; see logs in osm2pgsql.log and osm2pgsql.err"
   /usr/local/bin/osm2pgsql --append --slim -d gis -C 16000 \
     --tablespace-slim-data hdd --tablespace-slim-index hdd --number-processes 5 \
     --flat-nodes /mnt/database/flat-nodes/gis-flat-nodes.bin \
     --style ~/OpenTopoMap/mapnik/osm2pgsql/opentopomap.style \
     $WORKDIR/cumulated_changefile.osc -e 13-17 -o $WORKDIR/expire.tmp \
     > $LOGDIR/osm2pgsql.log 2>$LOGDIR/osm2pgsql.err 
   osm2pgsqlret=$?
   d=`date +"%Y-%m-%d"`
   touch $WORKDIR/expire.tmp
   mv $WORKDIR/expire.tmp $WORKDIR/expire.list-$d
   chmod 0666 $WORKDIR/expire.list-*
   if [ $osm2pgsqlret != 0 ] ; then
    d=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$d osm2pgsql exited with error, see osm2pgsql.log and osm2pgsql.err"
    cp latest_osc.bak latest_osc
    newupdate=`cat latest_osc`
   else
    d=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$d osm2pgsql done"
   fi
  fi
  if [ $osm2pgsqlret = 0 ] ; then
   cd /home/otmuser/OpenTopoMap/mapnik/tools/

#
# Preprocessing lowzoom if -withlowzoom or -onlypreprocessing was set
#

   if [ "$1" = "-withlowzoom" -o "$1" = "-onlypreprocessing" ] ; then
    d=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$d option $1 was set..."
    echo "$d arealabel.sql; see logs in arealabel.log and arealabel.err"
    psql gis < arealabel.sql >$LOGDIR/arealabel.log 2> $LOGDIR/arealabel.err
    d=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$d update_lowzoom.sh; see logs in lowzoom.log and lowzoom.err"
    ./update_lowzoom.sh >$LOGDIR/lowzoom.log 2>$LOGDIR/lowzoom.err
    d=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$d clean isolations and directions"
    psql gis -c "UPDATE planet_osm_point SET otm_isolation=NULL WHERE \"natural\" IN ('peak','volcano');"  >/dev/null 2>/dev/null
    psql gis -c "UPDATE planet_osm_point SET direction=NULL     WHERE (railway IN ('station','halt'));"    >/dev/null 2>/dev/null
    psql gis < pitchicon.sql > /dev/null 2>/dev/null
    d=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$d update_parking.sh; see logs in parking.log and parking.err"
    ./update_parking.sh >$LOGDIR/parking.log 2>$LOGDIR/parking.err
    d=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$d grants to tirex" 
    psql -d gis -c 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO tirex;' > /dev/null 2>/dev/null
    psql -d lowzoom -c 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO tirex;' > /dev/null 2>/dev/null
    psql -d gis -c 'GRANT CONNECT ON DATABASE gis TO tirex;' > /dev/null 2>/dev/null
#
# get coeastlines
#    
    cd /home/otmuser/OpenTopoMap/mapnik/data/
    d=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$d getting coastlines"
    mv water-polygons-split-3857.zip water-polygons-split-3857.zip.old
    wget https://osmdata.openstreetmap.de/download/water-polygons-split-3857.zip > /dev/null 2>/dev/null
    if ( find ./ -name "water-polygons-split-3857.zip" -size +100M | grep water-polygons-split-3857 >/dev/null ) ; then 
     unzip -u -o water-polygons-split-3857.zip
     d=`date +"%Y-%m-%d %H:%M:%S"`
     echo "$d got and unzipped coastlines"
    else
     mv water-polygons-split-3857.zip.old water-polygons-split-3857.zip
     d=`date +"%Y-%m-%d %H:%M:%S"`
     echo "$d no new coastlines, did not unzip them"
    fi
    mv simplified-water-polygons-split-3857.zip simplified-water-polygons-split-3857.zip.old
    wget https://osmdata.openstreetmap.de/download/simplified-water-polygons-split-3857.zip > /dev/null 2>/dev/null
    if ( find ./ -name "simplified-water-polygons-split-3857.zip" -size +10M | grep simplified-water-polygons-split-3857 >/dev/null ) ; then 
     unzip -u -o simplified-water-polygons-split-3857.zip
     d=`date +"%Y-%m-%d %H:%M:%S"`
     echo "$d got and unzipped simplified coastlines"
    else
     mv simplified-water-polygons-split-3857.zip.old simplified-water-polygons-split-3857.zip
     d=`date +"%Y-%m-%d %H:%M:%S"`
     echo "$d no new simplified coastlines, did not unzip them"
    fi
    
    cd $WORKDIR
    cp latest_osc latest_lowzoom
   fi

#
# After each import update peaks, saddles and stations
#
   cd /home/otmuser/OpenTopoMap/mapnik/tools/
   d=`date +"%Y-%m-%d %H:%M:%S"`
   echo "$d update_saddles.sh; see logs in saddles.log and saddles.err"
   ./update_saddles.sh > $LOGDIR/saddles.log 2>$LOGDIR/saddles.err
   d=`date +"%Y-%m-%d %H:%M:%S"`
   echo "$d update_isolations.sh; see logs in isolations.log and isolations.err"
   ./update_isolations.sh >> $LOGDIR/isolations.log 2>>$LOGDIR/isolations.err
   d=`date +"%Y-%m-%d %H:%M:%S"`
   echo "$d stationdirection.sql viewpointdirection.sql; see logs in directions.log and directions.err"
   psql gis < stationdirection.sql   > $LOGDIR/directions.log 2>$LOGDIR/directions.err
   psql gis < viewpointdirection.sql >> $LOGDIR/directions.log 2>>$LOGDIR/directions.err
   d=`date +"%Y-%m-%d %H:%M:%S"`
   echo "$d used space on fs"
   df -h | grep "database\|tiles"
   cd $WORKDIR
   if [ -e latest_osc.running ] ; then
    cp latest_osc.running latest_osc
    rm latest_osc.running
   fi
   d=`date +"%Y-%m-%d %H:%M:%S"`
   newupdate=`cat latest_osc`
   lowzoomdate=`cat latest_lowzoom`
   coastdate=`stat /home/otmuser/OpenTopoMap/mapnik/data/water-polygons-split-3857/water_polygons.shp | grep Modify | cut -d" " -f2`
   lzcoastdate=`stat /home/otmuser/OpenTopoMap/mapnik/data/simplified-water-polygons-split-3857/simplified_water_polygons.shp | grep Modify | cut -d" " -f2`
   echo "$d database updated to highzoom: $newupdate / lowzoom: $lowzoomdate / coastlines highzoom: $coastdate lowzoom: $lzcoastdate"
  fi 
 else
   d=`date +"%Y-%m-%d %H:%M:%S"`
   cd $WORKDIR
   cp latest_osc.bak latest_osc
   newupdate=`cat latest_osc`
   echo "$d no differential update file found"
   echo "$d daily update ended with errors, last successfull update $newupdate"
   echo "$d --/otmuser---------------------------------------------------------------"
 fi
fi 
 
 
