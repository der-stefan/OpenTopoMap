CREATE TYPE otm_natural_area_hierarchy AS (nextregionsize REAL,subregionsize REAL);


CREATE OR REPLACE FUNCTION OTM_Next_Natural_Area_Size(myosm_id IN BIGINT,myway_area REAL,myway IN GEOMETRY) RETURNS otm_natural_area_hierarchy AS $$
DECLARE
 verybigarea CONSTANT REAL := 1e15;
 shrinkway   GEOMETRY;
 expandway   GEOMETRY;
 next_size   REAL;
 sub_size    REAL;
 polyresult  RECORD;
 lineresult  RECORD;
 ret         otm_natural_area_hierarchy;
 way_is_area BOOLEAN := true;
 
 BEGIN
  IF ((ST_GeometryType(myway)='ST_LineString')OR(ST_GeometryType(myway)='ST_MultiLineString')) THEN way_is_area:=false; END IF;
  IF(way_is_area) THEN
   shrinkway:=ST_Buffer(myway,-20);
   expandway:=ST_Buffer(myway,20);
  ELSE
   shrinkway:=ST_LineSubstring(myway,0.02,0.98);
   myway_area:=ST_Length(myway)*ST_Length(myway)/10;
  END IF;
--
-- get the smallest area which contains myway
--
  SELECT osm_id,name,way_area FROM planet_osm_polygon WHERE
   ST_Contains (way,shrinkway) AND
   ("region:type" IN ('natural_area','mountain_area') OR
    "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
   name IS NOT NULL AND
   way_area> myway_area AND
   osm_id != myosm_id
  ORDER BY way_area ASC LIMIT 1 INTO polyresult;
  next_size:=polyresult.way_area;
--  RAISE NOTICE 'next poly to % is % (%)',myosm_id,polyresult.osm_id,polyresult.name;
  IF next_size IS NULL THEN next_size:=verybigarea; END IF;
--
-- If myway is an area also serch for areas and lines inside it (lines do not have subareas)
--
  IF(way_is_area) THEN
--
-- get the largest area located inside myway
--
   SELECT osm_id,name,way_area FROM planet_osm_polygon WHERE
    ST_Contains (expandway,way) AND
    ("region:type" IN ('natural_area','mountain_area') OR
     "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
    name IS NOT NULL AND
    way_area<myway_area AND
    osm_id != myosm_id
   ORDER BY way_area DESC LIMIT 1 INTO polyresult;
   sub_size:=polyresult.way_area;
--   RAISE NOTICE 'sub poly to % is % (%)',myosm_id,polyresult.osm_id,polyresult.name;
   IF sub_size IS NULL THEN sub_size:=0.0; END IF;
--
-- get the largest line located inside myway (but not lines with are also in osm_polygon)
--
   SELECT osm_id,name,ST_Length(way)*ST_Length(way)/10 as way_area FROM planet_osm_line AS li WHERE
    ST_Contains (expandway,way) AND
    "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete') AND
    name IS NOT NULL AND
    NOT EXISTS (SELECT osm_id FROM planet_osm_polygon AS po WHERE po.osm_id=li.osm_id )
   ORDER BY way_area DESC LIMIT 1 INTO lineresult;
--   RAISE NOTICE 'sub line to % is % (%)',myosm_id,lineresult.osm_id,lineresult.name;
   IF lineresult.way_area IS NOT NULL AND lineresult.way_area>sub_size THEN
    sub_size:=lineresult.way_area;
   END IF;
  ELSE 
   sub_size:=0.0;   
  END IF;
  ret.nextregionsize:=next_size;
  ret.subregionsize:=sub_size;
  RETURN ret;
 END;
$$ LANGUAGE plpgsql;

  

DROP VIEW lowzoom_natural_areas;
CREATE VIEW lowzoom_natural_areas AS 
 SELECT arealabel(osm_id,way) as way,name,areatype,way_area,(hierarchicregions).nextregionsize AS nextregionsize,(hierarchicregions).subregionsize AS subregionsize FROM
  (SELECT osm_id,way,name,(CASE WHEN "natural" IS NOT NULL THEN "natural" ELSE "region:type" END) AS areatype,
    way_area,
    OTM_Next_Natural_Area_Size(osm_id,way_area,way) AS hierarchicregions FROM planet_osm_polygon WHERE 
     ("region:type" IN ('natural_area','mountain_area') OR
      "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
      name IS NOT NULL) AS natural_areas
    ;

DROP VIEW lowzoom_natural_lines;
CREATE VIEW lowzoom_natural_lines AS
 SELECT way,name,areatype,way_area,(hierarchicregions).nextregionsize AS nextregionsize,(hierarchicregions).subregionsize AS subregionsize FROM
  (SELECT osm_id,way,name,"natural" AS areatype,ST_Length(way)*ST_Length(way)/10 as way_area, 
   OTM_Next_Natural_Area_Size(osm_id,0.0,way) AS hierarchicregions FROM planet_osm_line AS li WHERE
    "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete') AND
    name IS NOT NULL AND NOT EXISTS (SELECT osm_id FROM planet_osm_polygon AS po WHERE po.osm_id=li.osm_id )) AS natural_lines;


-- select osm_id,name,areatype,way_area,nextregionsize,subregionsize from lowzoom_natural_areas limit 20;    
-- select osm_id,name,areatype,way_area,nextregionsize,subregionsize from lowzoom_natural_lines limit 20; 
-- select osm_id,name,areatype,way_area,nextregionsize,subregionsize from lowzoom_natural_areas;
-- select osm_id,name,areatype,way_area,nextregionsize,subregionsize from lowzoom_natural_lines;


