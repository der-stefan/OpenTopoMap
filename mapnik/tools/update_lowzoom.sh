#!/bin/bash

dropdb lowzoom
createdb lowzoom
psql -d lowzoom -c "CREATE EXTENSION postgis;"
psql -d lowzoom -c "CREATE EXTENSION dblink;"
psql -d gis -c "CREATE EXTENSION dblink;"

# water
echo "Simplifying water polygons..."
psql -d gis -c "CREATE VIEW lowzoom_water AS SELECT ST_SimplifyPreserveTopology(way,150) AS way,name,\"natural\",waterway,way_area FROM planet_osm_polygon WHERE (\"natural\" = 'water' OR waterway = 'riverbank' OR water='lake' OR landuse IN ('basin','reservoir')) AND way_area > 50000;"
psql -d lowzoom -c "CREATE TABLE water (way geometry(Geometry,3857), name text, \"natural\" text, waterway text, way_area real);"
psql -d lowzoom -c "INSERT INTO water SELECT * FROM dblink('dbname=gis','SELECT * FROM lowzoom_water') AS t(way geometry(Geometry,3857), name text, \"natural\" text, waterway text, way_area real);"

# landuse
echo "Simplifying landuse polygons..."
psql -d gis -c "CREATE VIEW lowzoom_landuse AS SELECT ST_SimplifyPreserveTopology(way,150) AS way,landuse,\"natural\" FROM planet_osm_polygon WHERE landuse = 'forest' OR \"natural\" = 'wood' AND way_area > 50000;"
psql -d lowzoom -c "CREATE TABLE landuse (way geometry(Geometry,3857), landuse text, \"natural\" text);"
psql -d lowzoom -c "INSERT INTO landuse SELECT * FROM dblink('dbname=gis','SELECT * FROM lowzoom_landuse') AS t(way geometry(Geometry,3857), landuse text, \"natural\" text);"
	
	
# roads
echo "Simplifying roads..."
psql -d gis -c "CREATE VIEW lowzoom_roads AS SELECT ST_SimplifyPreserveTopology(way,100) AS way,highway,ref FROM planet_osm_line WHERE highway IN ('motorway','trunk','primary','secondary','tertiary','motorway_link','trunk_link','primary_link','secondary_link','tertiary_link');"
psql -d lowzoom -c "CREATE TABLE roads (way geometry(LineString,3857), highway text, ref text);"
psql -d lowzoom -c "INSERT INTO roads SELECT * FROM dblink('dbname=gis','SELECT * FROM lowzoom_roads') AS t(way geometry(LineString,3857), highway text, ref text);"


# borders
echo "Simplifying borders..."
psql -d gis -c "CREATE VIEW lowzoom_borders AS SELECT ST_SimplifyPreserveTopology(way,150) AS way,boundary,admin_level FROM planet_osm_line WHERE boundary = 'administrative' AND admin_level IN ('2','4','5','6');"
psql -d lowzoom -c "CREATE TABLE borders (way geometry(LineString,3857), boundary text, admin_level text);"
psql -d lowzoom -c "INSERT INTO borders SELECT * FROM dblink('dbname=gis','SELECT * FROM lowzoom_borders') AS t(way geometry(LineString,3857), boundary text, admin_level text);"


# railways
echo "Simplifying railways..."
psql -d gis -c "CREATE VIEW lowzoom_railways AS SELECT ST_SimplifyPreserveTopology(way,50) AS way,railway,\"service\",tunnel FROM planet_osm_line WHERE (\"service\" IS NULL AND railway IN ('rail','light_rail'));"
psql -d lowzoom -c "CREATE TABLE railways (way geometry(LineString,3857), railway text, \"service\" text, tunnel text);"
psql -d lowzoom -c "INSERT INTO railways SELECT * FROM dblink('dbname=gis','SELECT * FROM lowzoom_railways') AS t(way geometry(LineString,3857), railway text, \"service\" text, tunnel text);"
	
	
# cities and towns
echo "Simplifying cities and towns..."
psql -d gis -c "CREATE VIEW lowzoom_cities AS SELECT way,admin_level,name,capital,place,population::integer FROM planet_osm_point WHERE place IN ('city','town') AND (population IS NULL OR population SIMILAR TO '[[:digit:]]+') AND (population IS NULL OR population::integer > 5000);"
psql -d lowzoom -c "CREATE TABLE cities (way geometry(Point,3857), admin_level text, name text, capital text, place text, population integer);"
psql -d lowzoom -c "INSERT INTO cities SELECT * FROM dblink('dbname=gis','SELECT * FROM lowzoom_cities') AS t(way geometry(Point,3857), admin_level text, name text, capital text, place text, population integer);"


