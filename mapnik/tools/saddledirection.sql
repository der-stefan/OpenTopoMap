--
-- FUNCTION INTEGER getdirection(Point:GEOMETRY in EPSG:900913)
-- ------------------------------------------------------------
--
-- returns the direction of a saddle at (Point) in degrees (0deg...179deg) (0:north 90:east 180:south)
--
-- Constants
--    SearchArea:   limit where the next contour line must be. (not very usefull, because bounding boxes of contour lines can be huge...)
--    SearchLimit:  maximum of examined contour lines
--    MinDescent:   minimum distance to go down the slope and search for the next lower contour line
--
--
-- Algorithm:
--    get all contour lines near the saddle
--    find the next contour line and define its height as "height of this saddle point"
--    find the next contour line which is at least MinDescent lower or higher than the "height of this saddle point", get the closest point on this line
--    get the azimuth between the saddle point and the closest point if the contour line was lower, azimuth+90deg if it was higher
--    rotate the azimuth from (N:0deg,E:90deg,S:180deg,W:270deg) to (E:0deg,N:90deg,W:180deg, the way mapserver likes angles), 180-359deg is flipped to 0-179deg
--    if something went wrong, return -1, (-1 could be considered as error flag or as "default orientation" nearly to west-east direction)
--
-- Requirement:
--    you need a database "contours" with a table "contours" with the columns "height" and "wkb_geometry" (in EPSG:900913)
--    
-- Installation
--    psql databasename < path_to_me/saddledirection.sql
--    (as owner of the database where the saddles are, eg "gis")
--    You also need to install the extension "dblink", but that you have allready done following "HOWTO_Preprocessing"

--    For "dblink('dbname=mydb', 'select ...')" you have to be superuser or you have to provide a passwort with your query. Ig you don't like
--    that, you could open the connection to countours with "dblink_connect_u('contours_connection', 'dbname=contours')" and then do your query
--    with "dblink('contours_connection','select ...')". Then you just need the exection right for dblink_connect_u.
--
--    as postgres
--     psql databasename -c "GRANT EXECUTE ON FUNCTION dblink_connect_u(text) to username;"
--     psql databasename -c "GRANT EXECUTE ON FUNCTION dblink_connect_u(text,text) to username;"
--


CREATE OR REPLACE FUNCTION getsaddledirection(GEOMETRY) RETURNS INTEGER AS $$

 DECLARE
  SearchArea   CONSTANT INTEGER := 100;
  SearchLimit  CONSTANT INTEGER :=  10;
  MinDescent   CONSTANT INTEGER :=  20;

  saddlepoint  TEXT := $1::TEXT;
  result       RECORD;
  saddleheight FLOAT;
  direction    INTEGER;
  i            INTEGER;
  querystring  TEXT;

 BEGIN
  i:=0;direction:=-1;
--
-- open dblink-connection
--
  IF ('saddle_contours_connection' = ANY(dblink_get_connections())) THEN
--   RAISE NOTICE 'connection to contours allready exists';
  ELSE
   PERFORM dblink_connect_u('saddle_contours_connection', 'dbname=contours');
  END IF;
--
-- build query string 
--
  querystring='SELECT wkb_geometry,height FROM contours WHERE 
                 st_setsrid(wkb_geometry,900913) && ST_Expand(''' || saddlepoint || '''::geometry,' || SearchArea || ') 
                 ORDER BY ST_Distance(st_setsrid(wkb_geometry,900913),''' || saddlepoint || '''::geometry) ASC LIMIT ' || SearchLimit;

--  RAISE NOTICE 'query: %s',querystring;

--
-- Get contour lines and next point to this line from saddle
--
  <<getcontourloop>>  
  FOR result IN ( SELECT  height::FLOAT,ST_ClosestPoint(st_setsrid(way,900913),st_setsrid(saddlepoint::geometry,900913)) AS cp 
                         FROM dblink('saddle_contours_connection',querystring) 
                              AS t1(way geometry,height integer)
                ) LOOP
   i:=i+1;
--
-- First line found defines the "height" of the saddle
--
   IF (i=1) THEN
    saddleheight:=result.height; 
   ELSE
--
-- one of the next lines defines the orientation / pointing to the next lower point or 90° to the next higher point
--
    IF (result.height<saddleheight-MinDescent) THEN
     SELECT CAST(d AS INTEGER) INTO direction FROM (SELECT degrees(ST_Azimuth(saddlepoint,result.cp)) AS d) AS foo;
     direction:=(720-(direction))%180;
--     RAISE NOTICE 'Found lower contour line';
     EXIT getcontourloop;
    END IF;
    IF (result.height>saddleheight+MinDescent) THEN
     SELECT CAST(d AS INTEGER) INTO direction FROM (SELECT degrees(ST_Azimuth(saddlepoint,result.cp)) AS d) AS foo;
     direction:=(720-(direction-90))%180;
--     RAISE NOTICE 'Found higher contour line';
     EXIT getcontourloop;
    END IF;
    
   END IF;
  END LOOP getcontourloop;
--
-- close dblink-connection
--
  PERFORM dblink_disconnect('saddle_contours_connection');
  RETURN direction;
 END;
$$ LANGUAGE plpgsql;
