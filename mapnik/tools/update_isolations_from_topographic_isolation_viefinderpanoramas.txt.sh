#Alternatively, is the isolations calculation is too long, you can download the computed dominance from :
# https://geo.dianacht.de/topo/topographic_isolation_viefinderpanoramas.txt

db="gis"

echo "creating the otm_isolation column to hold isolation information of peaks..."
echo "ALTER TABLE planet_osm_point ADD COLUMN otm_isolation text;" | psql $db
echo "done"
echo "creating an index on osm_id because osm2pgsql newer versions does no create it anymore, and we need it to update peak isolation..."
echo "create index planet_osm_point_osm_id on planet_osm_point (osm_id);" | psql $db
echo "done"
wget -q https://geo.dianacht.de/topo/topographic_isolation_viefinderpanoramas.txt -O - | egrep -v '^#' | sed s/"\([0-9]*;\).*;.*;\([0-9]*\)"/"update planet_osm_point set otm_isolation=\2 where osm_id=\1"/g | psql -q $db

