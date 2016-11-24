--
-- FUNCTION INTEGER getdirection(Point:GEOMETRY in EPSG:900913)
-- ------------------------------------------------------------
--
-- returns the direction of a saddle at (Point) in degrees (0deg...179deg) (0:north 90:east 180:south)
--
-- Constants
--    SearchArea:   limit where the next contour line must be (in meters)
--    SearchLimit:  maximum number of examined contour lines
--    MinDescent:   minimum distance to go down the slope and search for the next lower contour line (in units of your contour lines, normally meters)
--
--
-- Algorithm:
--    get all contour lines near the saddle
--    find the next contour line and define its height as "height of this saddle point"
--    find the next contour line which is at least MinDescent lower or higher than the "height of this saddle point", get the closest point on this line
--    get the azimuth between the saddle point and the closest point if the contour line was lower, azimuth+90deg if it was higher
--    if something went wrong, return -1, (-1 could be considered as error flag or as "default orientation" nearly to north direction)
--
-- Requirement:
--    you need a database "contours" with a table "contours" with the columns "height" and "wkb_geometry" (in EPSG:900913)
--    
-- Installation
--    psql databasename < path_to_me/saddledirection.sql
--    (as owner of the database where the saddles are, eg "gis")
--    You also need to install the extension "dblink", but that you have allready done following "HOWTO_Preprocessing"
--
--    For "dblink('dbname=mydb', 'select ...')" you have to be superuser or you have to provide a passwort with your query. Ig you don't like
--    that, you could open the connection to countours with "dblink_connect_u('contours_connection', 'dbname=contours')" and then do your query
--    with "dblink('contours_connection','select ...')". In this case you just the exection right for dblink_connect_u.
--
--    as postgres
--     psql databasename -c "GRANT EXECUTE ON FUNCTION dblink_connect_u(text) to username;"
--     psql databasename -c "GRANT EXECUTE ON FUNCTION dblink_connect_u(text,text) to username;"
--


CREATE OR REPLACE FUNCTION getsaddledirection(GEOMETRY,TEXT) RETURNS INTEGER AS $$

 DECLARE
  SearchArea   CONSTANT INTEGER := 150;
  SearchLimit  CONSTANT INTEGER :=  10;
  MinDescent   CONSTANT INTEGER :=  10;

  saddlepoint     TEXT := $1::TEXT;
  osmdirection    TEXT := $2::TEXT;
  result          RECORD;
  saddleheight    FLOAT;
  direction       INTEGER;
  SearchAreaMerc  INTEGER;
  i               INTEGER;
  querystring     TEXT;

 BEGIN
  i:=0;direction:=-1;
  osmdirection=LOWER(osmdirection);

--
-- -------------------  First try to parse the given direction ----------------------------------------------------------
--
  IF     (osmdirection ~ '^[1-9][0-9]+$')                                                         THEN direction=(osmdirection::INTEGER)%180;
  ELSEIF (osmdirection ~ '^[0-9]+\.[0-9]+$')                                                      THEN direction=ROUND(osmdirection::FLOAT))%180;
  ELSEIF (osmdirection='n'   or osmdirection='north' or osmdirection='s' or osmdirection='south') THEN direction:=0; 
  ELSEIF (osmdirection='ssw' or osmdirection='nne' )                                              THEN direction:=22;
  ELSEIF (osmdirection='sw'  or osmdirection='ne'  )                                              THEN direction:=45;
  ELSEIF (osmdirection='wsw' or osmdirection='ene' )                                              THEN direction:=67;
  ELSEIF (osmdirection='w'   or osmdirection='west'  or osmdirection='e' or osmdirection='east' ) THEN direction:=90;
  ELSEIF (osmdirection='nw'  or osmdirection='se'  )                                              THEN direction:=135;
  ELSEIF (osmdirection='wnw' or osmdirection='ese' )                                              THEN direction:=112;
  ELSEIF (osmdirection='nnw' or osmdirection='sse' )                                              THEN direction:=157;
  ELSE
--
-- -------------------- If there is still no direction, get it from contour lines ----------------------------------------
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
   select round(SearchArea/cos(st_y(st_transform(st_setsrid(saddlepoint::geometry,900913),4326))/180*3.14159)) INTO SearchAreaMerc;
   querystring='SELECT wkb_geometry,height,ST_Distance(st_setsrid(wkb_geometry,900913),''' || saddlepoint || '''::geometry) as dist FROM contours WHERE 
                  st_setsrid(wkb_geometry,900913) && ST_Expand(''' || saddlepoint || '''::geometry,' || SearchAreaMerc || ') 
                  ORDER BY ST_Distance(st_setsrid(wkb_geometry,900913),''' || saddlepoint || '''::geometry) ASC LIMIT ' || SearchLimit;
--
-- Get contour lines and next point to this line from saddle
--
   <<getcontourloop>>  
   FOR result IN ( SELECT  height::FLOAT,ST_ClosestPoint(st_setsrid(way,900913),st_setsrid(saddlepoint::geometry,900913)) AS cp,dist::FLOAT
                          FROM dblink('saddle_contours_connection',querystring) 
                               AS t1(way geometry,height integer,dist float)
                 ) LOOP
    i:=i+1;
--
-- First line found defines the "height" of the saddle
--
    IF (i=1) THEN
     saddleheight:=result.height; 
     saddleheight:=result.height; 
 
     RAISE NOTICE 'Height=%', result.height;
     RAISE NOTICE 'Dist=  %', result.dist;
     RAISE NOTICE 'saddle=%', st_astext(saddlepoint);
     RAISE NOTICE 'cp=    %', st_astext(result.cp);
    ELSE
     RAISE NOTICE 'next Height=%', result.height;
     RAISE NOTICE 'next Dist=%', result.dist;
     RAISE NOTICE 'cp=    %', st_astext(result.cp);
 
--
-- one of the next lines defines the orientation / pointing to the next lower point or 90° to the next higher point
--
     IF (result.height<saddleheight-MinDescent) THEN
      RAISE NOTICE 'SP RCP % %',saddlepoint,result.cp;
      SELECT CAST(d AS INTEGER) INTO direction FROM (SELECT degrees(ST_Azimuth(saddlepoint,result.cp)) AS d) AS foo;
      RAISE NOTICE 'Dir: %',direction;
      direction:=(360+direction)%180;
      RAISE NOTICE 'Found lower contour line %',result.height;
      EXIT getcontourloop;
     END IF;
     IF (result.height>saddleheight+MinDescent) THEN
      RAISE NOTICE 'SP RCP % %',saddlepoint,result.cp;
      SELECT CAST(d AS INTEGER) INTO direction FROM (SELECT degrees(ST_Azimuth(saddlepoint,result.cp)) AS d) AS foo;
      RAISE NOTICE 'Dir: %',direction;
      direction:=(360+direction+90)%180;
      RAISE NOTICE 'Found higher contour line %',result.height;
      EXIT getcontourloop;
     END IF;
     
    END IF;
   END LOOP getcontourloop;
--
-- close dblink-connection
--
   PERFORM dblink_disconnect('saddle_contours_connection');
 
  END IF;
  RETURN direction;
 END;
$$ LANGUAGE plpgsql;
 