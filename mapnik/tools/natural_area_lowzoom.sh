#!/bin/bash

# natural area labels


echo "Create lines for labels of natural areas..."
psql -d gis < /home/gis/otm/mapnik/tools/natural_area.sql
psql -d lowzoom -c "DROP TABLE naturalarealabels;"
psql -d lowzoom -c "CREATE TABLE naturalarealabels (way geometry(LineString,3857), name text, areatype text, way_area real,nextregionsize real,subregionsize real);"
psql -d lowzoom -c "INSERT INTO naturalarealabels SELECT * FROM dblink('dbname=gis','SELECT * FROM lowzoom_natural_areas') AS t(way geometry(LineString,3857), name text, areatype text, way_area real,nextregionsize real,subregionsize real);"
psql -d lowzoom -c "INSERT INTO naturalarealabels SELECT * FROM dblink('dbname=gis','SELECT * FROM lowzoom_natural_lines') AS t(way geometry(LineString,3857), name text, areatype text, way_area real,nextregionsize real,subregionsize real);"
psql -d lowzoom -c "CREATE INDEX naturalarealabels_way_idx ON naturalarealabels USING GIST (way);"
psql -d lowzoom -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO gis;"

