#!/bin/bash

#FIXME sly 20-01-2020 : Since I moved every thing in the same DB for ease of xml style factoring, and even management, VIEWS are now useless, we should be able to replace them by :
# psql -d gis -c "INSERT INTO water SELECT ST_SimplifyPreserveTopology(way,150) AS way,name,\"natural\",waterway,way_area FROM planet_osm_polygon WHERE (\"natural\" = 'water' OR waterway = 'riverbank' OR water='lake' OR landuse IN ('basin','reservoir')) AND way_area > 50000;" 
# We can even replace the create table+insert into by one only line :
# psql -d gis -c "CREATE TABLE water AS SELECT ST_SimplifyPreserveTopology(way,150) AS way,name,\"natural\",waterway,way_area FROM planet_osm_polygon WHERE (\"natural\" = 'water' OR waterway = 'riverbank' OR water='lake' OR landuse IN ('basin','reservoir')) AND way_area > 50000;" 
# Even more, but I'm unsure about its performances : Only add a simplified_way column to planet_osm_polygon and populate it with :
# UPDATE planet_osm_polygon SET simplified_way=ST_SimplifyPreserveTopology(way,150) WHERE (\"natural\" = 'water' OR waterway = 'riverbank' OR water='lake' OR landuse IN ('basin','reservoir')) AND way_area > 50000;
# FIXME sly 2023-07-15 all of this as to be tried first !

db=gis

# water
echo "Simplifying water polygons..."
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_water AS SELECT ST_SimplifyPreserveTopology(way,150) AS way,name,\"natural\",waterway,way_area FROM planet_osm_polygon WHERE (\"natural\" = 'water' OR waterway = 'riverbank' OR water='lake' OR landuse IN ('basin','reservoir')) AND way_area > 50000;"
psql -d $db -c "DROP DATABASE water;"
psql -d $db -c "CREATE TABLE IF NOT EXISTS water (way geometry(Geometry,3857), name text, \"natural\" text, waterway text, way_area real);"
psql -d $db -c "INSERT INTO water SELECT * FROM  lowzoom_water;"
psql -d $db -c "CREATE INDEX IF NOT EXISTS water_way_idx ON water USING GIST (way);"


# landuse
echo "Simplifying landuse polygons..."
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_landuse AS SELECT ST_SimplifyPreserveTopology(way,150) AS way,landuse,\"natural\" FROM planet_osm_polygon WHERE landuse = 'forest' OR \"natural\" = 'wood' AND way_area > 50000;"
psql -d $db -c "DROP DATABASE landuse;"
psql -d $db -c "CREATE TABLE IF NOT EXISTS landuse (way geometry(Geometry,3857), landuse text, \"natural\" text);"
psql -d $db -c "INSERT INTO landuse SELECT * FROM  lowzoom_landuse;"
psql -d $db -c "CREATE INDEX IF NOT EXISTS landuse_way_idx ON landuse USING GIST (way);"
sleep 15	
	
# roads
echo "Simplifying roads..."
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_roads AS SELECT ST_SimplifyPreserveTopology(way,100) AS way,highway,ref FROM planet_osm_line WHERE highway IN ('motorway','trunk','primary','secondary','tertiary','motorway_link','trunk_link','primary_link','secondary_link','tertiary_link');"
psql -d $db -c "DROP DATABASE roads;"
psql -d $db -c "CREATE TABLE IF NOT EXISTS roads (way geometry(LineString,3857), highway text, ref text);"
psql -d $db -c "INSERT INTO roads SELECT * FROM  lowzoom_roads;"
psql -d $db -c "CREATE INDEX IF NOT EXISTS roads_way_idx ON roads USING GIST (way);"


# borders
echo "Simplifying borders..."
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_borders AS SELECT ST_SimplifyPreserveTopology(way,150) AS way,boundary,admin_level FROM planet_osm_line WHERE boundary = 'administrative' AND admin_level IN ('2','4','5','6');"
psql -d $db -c "DROP DATABASE borders;"
psql -d $db -c "CREATE TABLE IF NOT EXISTS borders (way geometry(LineString,3857), boundary text, admin_level text);"
psql -d $db -c "INSERT INTO borders SELECT * FROM lowzoom_borders"
psql -d $db -c "CREATE INDEX IF NOT EXISTS borders_way_idx ON borders USING GIST (way);"


# railways
echo "Simplifying railways..."
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_railways AS SELECT ST_SimplifyPreserveTopology(way,50) AS way,railway,\"service\",tunnel FROM planet_osm_line WHERE (\"service\" IS NULL AND railway IN ('rail','light_rail'));"
psql -d $db -c "DROP DATABASE railways;"
psql -d $db -c "CREATE TABLE IF NOT EXISTS railways (way geometry(LineString,3857), railway text, \"service\" text, tunnel text);"
psql -d $db -c "INSERT INTO railways SELECT * FROM  lowzoom_railways;"
psql -d $db -c "CREATE INDEX IF NOT EXISTS railways_way_idx ON railways USING GIST (way);"
	
	
# cities and towns
echo "Simplifying cities and towns..."
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_cities AS SELECT way,admin_level,name,capital,place,population::integer FROM planet_osm_point WHERE place IN ('city','town') AND (population IS NULL OR population SIMILAR TO '[[:digit:]]+') AND (population IS NULL OR population::integer > 5000);"
psql -d $db -c "DROP DATABASE cities;"
psql -d $db -c "CREATE TABLE IF NOT EXISTS cities (way geometry(Point,3857), admin_level text, name text, capital text, place text, population integer);"
psql -d $db -c "INSERT INTO cities SELECT * FROM  lowzoom_cities;"
psql -d $db -c "CREATE INDEX IF NOT EXISTS cities_way_idx ON cities USING GIST (way);"


# water polygon labels
echo "Create lines for labels of water polygons..."
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_lakelabel    AS SELECT arealabel(osm_id,way) AS way,name,'lakeaxis'::text    AS label,way_area FROM planet_osm_polygon WHERE (\"natural\" = 'water' OR water='lake' OR landuse IN ('basin','reservoir')) AND name IS NOT NULL;"
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_baylabel     AS SELECT arealabel(osm_id,way) AS way,name,'bayaxis'::text     AS label,way_area FROM planet_osm_polygon WHERE  \"natural\" = 'bay' AND name IS NOT NULL;"
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_straitplabel AS SELECT arealabel(osm_id,way) AS way,name,'straitaxis'::text  AS label,way_area FROM planet_osm_polygon WHERE  \"natural\" = 'strait' AND name IS NOT NULL;"
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_straitllabel AS SELECT ST_LineMerge(longway) AS way,name,'straitaxis'::text AS label,len*len/10 as way_area FROM (SELECT ST_Collect(way) AS longway,SUM(ST_Length(way)) AS len,MAX(name) AS name FROM planet_osm_line WHERE \"natural\"='strait' AND name is NOT NULL GROUP BY osm_id) AS t;"
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_glacierlabel AS SELECT arealabel(osm_id,way) AS way,name,'glacieraxis'::text AS label,way_area FROM planet_osm_polygon WHERE  \"natural\" = 'glacier' AND name IS NOT NULL;"
psql -d $db -c "DROP DATABASE lakelabels;"
psql -d $db -c "CREATE TABLE IF NOT EXISTS lakelabels (way geometry(LineString,3857), name text, label text, lake_area real);"
echo "lowzoom_lakelabel..."
psql -d $db -c "INSERT INTO lakelabels SELECT * FROM  lowzoom_lakelabel;"
echo "lowzoom_baylabel..."
psql -d $db -c "INSERT INTO lakelabels SELECT * FROM  lowzoom_baylabel;"
echo "lowzoom_straitplabel..."
psql -d $db -c "INSERT INTO lakelabels SELECT * FROM  lowzoom_straitplabel;"
echo "lowzoom_straitllabel..."
psql -d $db -c "INSERT INTO lakelabels SELECT * FROM  lowzoom_straitllabel;"
echo "lowzoom_glacierlabel..."
psql -d $db -c "INSERT INTO lakelabels SELECT * FROM  lowzoom_glacierlabel;"
echo "create index..."
psql -d $db -c "CREATE INDEX IF NOT EXISTS lakelabels_way_idx ON lakelabels USING GIST (way);"


# natural area labels
echo "Create lines for labels of natural areas..."
psql -d $db -c "DROP VIEW IF EXISTS lowzoom_natural_lines;"
psql -d $db -c "DROP VIEW IF EXISTS lowzoom_natural_areas;"
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_natural_areas AS SELECT natural_arealabel(osm_id,way) as way,name,areatype,way_area,(hierarchicregions).nextregionsize AS nextregionsize,(hierarchicregions).subregionsize AS subregionsize FROM (SELECT osm_id,way,name,(CASE WHEN \"natural\" IS NOT NULL THEN \"natural\" ELSE \"region:type\" END) AS areatype, way_area, OTM_Next_Natural_Area_Size(osm_id,way_area,way) AS hierarchicregions FROM planet_osm_polygon WHERE (\"region:type\" IN ('natural_area','mountain_area') OR \"natural\" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete','gorge','canyon')) AND name IS NOT NULL) AS natural_areas;"
psql -d $db -c "CREATE OR REPLACE VIEW lowzoom_natural_lines AS SELECT way,name,areatype,way_area,(hierarchicregions).nextregionsize AS nextregionsize,(hierarchicregions).subregionsize AS subregionsize FROM (SELECT osm_id,way,name,\"natural\" AS areatype,ST_Length(way)*ST_Length(way)/10 as way_area, OTM_Next_Natural_Area_Size(osm_id,0.0,way) AS hierarchicregions FROM planet_osm_line AS li WHERE \"natural\" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete','gorge','canyon') AND name IS NOT NULL AND NOT EXISTS (SELECT osm_id FROM planet_osm_polygon AS po WHERE po.osm_id=li.osm_id )) AS natural_lines;"
psql -d $db -c "DROP DATABASE naturalarealabels;"
psql -d $db -c "CREATE TABLE IF NOT EXISTS naturalarealabels (way geometry(LineString,3857), name text, areatype text, way_area real,nextregionsize real,subregionsize real);"
psql -d $db -c "INSERT INTO naturalarealabels SELECT * FROM  lowzoom_natural_areas;"
psql -d $db -c "INSERT INTO naturalarealabels SELECT * FROM  lowzoom_natural_lines;"
psql -d $db -c "CREATE INDEX IF NOT EXISTS naturalarealabels_way_idx ON naturalarealabels USING GIST (way);"

