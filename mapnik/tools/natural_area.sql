
CREATE TYPE otm_natural_area_family AS (smallestparent REAL,largestchild REAL);


CREATE OR REPLACE FUNCTION OTM_Parent_Natural_Area_Size(myosm_id IN BIGINT,myway IN GEOMETRY) RETURNS otm_natural_area_family AS $$
DECLARE
 verybigarea CONSTANT REAL := 1e15;
 shrinkway   GEOMETRY;
 expandway   GEOMETRY;
 parent_size REAL;
 child_size  REAL;
 polyresult  RECORD;
 lineresult  RECORD;
 ret         otm_natural_area_family;
 
 BEGIN
  shrinkway:=ST_Buffer(myway,-20);
  expandway:=ST_Buffer(myway,20);
--
-- get the smallest area which contains myway
--
  SELECT osm_id,name,way_area FROM planet_osm_polygon WHERE
   ST_Contains (way,shrinkway) AND
   ("region:type" IN ('natural_area','mountain_area') OR
    "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
   name IS NOT NULL AND
   osm_id != myosm_id
   ORDER BY way_area ASC LIMIT 1 INTO polyresult;
   parent_size:=polyresult.way_area;
   RAISE NOTICE 'parent poly to % is % (%)',myosm_id,polyresult.osm_id,polyresult.name;
   IF parent_size IS NULL THEN parent_size:=verybigarea; END IF;
--
-- get the largest area located inside myway
--
  SELECT osm_id,name,way_area FROM planet_osm_polygon WHERE
   ST_Contains (expandway,way) AND
   ("region:type" IN ('natural_area','mountain_area') OR
    "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
   name IS NOT NULL AND
   osm_id != myosm_id
   ORDER BY way_area DESC LIMIT 1 INTO polyresult;
   child_size:=polyresult.way_area;
   RAISE NOTICE 'child poly to % is % (%)',myosm_id,polyresult.osm_id,polyresult.name;
   IF child_size IS NULL THEN child_size:=0.0; END IF;
--
-- get the largest line located inside myway (no relations, because these are strange polygones (R8425324 for example)
--
  SELECT osm_id,name,ST_Length(way)*ST_Length(way)/10 as way_area FROM planet_osm_line WHERE
   ST_Contains (expandway,way) AND
   "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete') AND
   name IS NOT NULL AND
   osm_id>0
   ORDER BY way_area DESC LIMIT 1 INTO lineresult;
   RAISE NOTICE 'child line to % is % (%)',myosm_id,lineresult.osm_id,lineresult.name;
   IF lineresult.way_area IS NOT NULL AND lineresult.way_area>child_size THEN
    child_size:=lineresult.way_area;
   END IF;
   ret.smallestparent:=parent_size;
   ret.largestchild:=child_size;
   RETURN ret;
 END;
$$ LANGUAGE plpgsql;

  

DROP VIEW lowzoom_natural_areas;
CREATE VIEW lowzoom_natural_areas AS 
 SELECT osm_id,name,areatype,way_area,(family).smallestparent AS parentsize,(family).largestchild AS childsize FROM
  (SELECT osm_id,name,(CASE WHEN "natural" IS NOT NULL THEN "natural" ELSE "region:type" END) AS areatype,
    way_area,
    OTM_Parent_Natural_Area_Size(osm_id,way) AS family FROM planet_osm_polygon WHERE 
     ("region:type" IN ('natural_area','mountain_area') OR
      "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
      name IS NOT NULL) AS natural_areas
    ;

select * from lowzoom_natural_areas LIMIT 20;    

-- same with ...
-- SELECT osm_id,name,"natural" AS areatype FROM planet_osm_line WHERE 
--  ("natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
--   name IS NOT NULL;
  

