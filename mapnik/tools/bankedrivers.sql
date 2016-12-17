--
-- funktion bankedrivers(id BIGINT)
-- 
-- Inserts new ways in planet_osm_line with 
--    osm_id=id+offset
--    waterway='testriver'
--    brand='isinside' or brand='isoutside'
--    way=riverpart
--
-- returns the number of river parts or 0, if there is no riverbank surrounding this river
--
--
--    riverpart is a geometry with parts of the river lying inside/outside of a riverbank
--    'brand' indicates inside/outside of a riverbank
--    
-- Just for testing, you don't want self made osm_ids inside your planet_osm_line and 
-- you don't want to use a brand for rivers ;)
--
-- Constants: id_offset      a big bigint added to the original osm_id
--
-- ---------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION bankedrivers(riverid BIGINT) RETURNS INTEGER AS $func$

 DECLARE
  geometrybuffer  CONSTANT INTEGER:=1;
  id_offset       CONSTANT BIGINT:=1000000000000000000;

  i               INTEGER;
  newriverid      BIGINT;
  isinside        BOOLEAN;
  isinsidetext    TEXT;
  riverway        GEOMETRY;
  riverpart       GEOMETRY;
  riverbanks      GEOMETRY;
  bufferedbanks   GEOMETRY;

 BEGIN
  i:=0;
--
-- get river and riverbanks (buffered by some cm to avoid cases where the
-- river IS a part of the banks)
--
  SELECT li.way FROM planet_osm_line as li INTO riverway WHERE li.osm_id=riverid;
  SELECT ST_Buffer(ST_Union(po.way),geometrybuffer) FROM planet_osm_polygon as po INTO riverbanks WHERE 
            (po.waterway IN ('riverbank') OR 
             po."natural" IN ('water'))   AND
             ST_Intersects(po.way,riverway);
--
-- clean planet_osm_line
--
  newriverid:=riverid+id_offset;
  DELETE FROM planet_osm_line WHERE osm_id=newriverid;
--
-- if there are any banks
--
  IF (riverbanks IS NOT NULL) THEN
--
-- buffer banks one again to set the cutting pint clearly inside/outside of the bank
--
   SELECT ST_Buffer(riverbanks,geometrybuffer) INTO bufferedbanks;
   <<splitloop>> 
--
-- for every part of the river: get the way, get inside/outside
--
   FOR riverpart IN (SELECT (
      ST_Dump(ST_Split(riverway,riverbanks))).geom as dumpset) LOOP
    i:=i+1;
    SELECT st_contains(bufferedbanks,riverpart) INTO isinside;

    RAISE NOTICE 'ID: % Part % IsIn: %',riverid,i,isinside;
    IF (isinside) THEN isinsidetext:='isinside'; ELSE isinsidetext:='isoutside'; END IF;
    INSERT INTO planet_osm_line (osm_id,way,waterway,brand) VALUES (newriverid,riverpart,'testriver',isinsidetext);
   END LOOP splitloop;
--
-- if there was no riverbank
--
  ELSE
   i:=0;
   RAISE NOTICE 'ID: % not in banks',riverid;
   isinsidetext:='isoutside';
   INSERT INTO planet_osm_line (osm_id,way,waterway,brand) VALUES (newriverid,riverway,'testriver',isinsidetext);
  END IF;
--
-- return number of parts
--
  RETURN i; 
 END;
$func$
LANGUAGE plpgsql;

-- -------------------------------- Testing ---------------------------

-- select osm_id,bankedrivers(osm_id) from planet_osm_line where (waterway='river' or waterway='stream') and name='Wiesent';
