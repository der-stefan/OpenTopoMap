#Alternatively, is the isolations calculation is too long, you can download the computed dominance from :
# https://geo.dianacht.de/topo/topographic_isolation_viefinderpanoramas.txt

db="gis"

wget https://geo.dianacht.de/topo/topographic_isolation_viefinderpanoramas.txt

for x in `cat topographic_isolation_viefinderpanoramas.txt` ; do 
  id=`echo $x | cut -f1 -d\;` 
  dominance=`echo $x | cut -f4 -d\;` ; 
  echo "update planet_osm_point set otm_isolation='$dominance' where osm_id=$id;" >> update-dominance.sql 
done 

cat update-dominance.sql | psql $db
rm update-dominance.sql
rm topographic_isolation_viefinderpanoramas.txt

