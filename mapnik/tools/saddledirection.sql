--
-- FUNCTION INTEGER getdirection(Point:GEOMETRY in Mercator, Destination: Text)
--          INTEGER getdirection(Point:GEOMETRY in Mercator, Destination: Text, ID BIGINT, updateflag TEXT)
-- --------------------------------------------------------------------------------------------------------
--
-- returns the direction of a saddle at (Point) in degrees (0deg...179deg) (0:north 90:east 180:south)
-- if ID!=0 and updateflag='update' this funktion updates the column "direction" in planet_osm_node if this column is NULL
--
--
--
-- Constants
--    SearchArea:   limit where the next contour line must be (in meters)
--    SearchLimit:  maximum number of examined contour lines
--    MinDescent:   minimum distance to go down the slope and search for the next lower contour line (in units of your contour lines, normally meters)
--
--
-- Algorithm:
--    get the mappers oppinion about the direction, try to parse the value as number
--    if that doesn't work:
--     get a sample of contour lines near the saddle
--     find the next contour line and define its height as "height of this saddle point"
--     find the next contour line which is at least MinDescent lower or higher than the "height of this saddle point", get the closest point on this line
--     get the azimuth between the saddle point and the closest point if the contour line was lower, azimuth+90deg if it was higher
--     for all other contour lines in sample: (get the next contour line, calculate the azimuth and correct the first choice with a weight depending on the distance)
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
--    For "dblink('dbname=mydb', 'select ...')" you have to be superuser or you have to provide a passwort with your query. If you don't like
--    that, you could open the connection to countours with "dblink_connect_u('contours_connection', 'dbname=contours')" and then do your query
--    with "dblink('contours_connection','select ...')". In this case you just the exection right for dblink_connect_u.
--
--    as postgres
--     psql databasename -c "GRANT EXECUTE ON FUNCTION dblink_connect_u(text) to username;"
--     psql databasename -c "GRANT EXECUTE ON FUNCTION dblink_connect_u(text,text) to username;"
--

DROP FUNCTION getsaddledirection(geometry,text);

CREATE OR REPLACE FUNCTION getsaddledirection(point IN GEOMETRY,osmdirection IN TEXT,osm_id IN BIGINT DEFAULT 0,updateflag IN TEXT DEFAULT 'noupdate') RETURNS INTEGER AS $$

 DECLARE
  SearchArea   CONSTANT INTEGER := 200;
  SearchLimit  CONSTANT INTEGER :=  10;
  MinDescent   CONSTANT INTEGER :=   5;

  saddlepoint     TEXT := point::TEXT;
  result          RECORD;
  saddleheight    FLOAT;
  direction       INTEGER;
  thisdirection   INTEGER;
  diffdirection   FLOAT;
  firstdistance   INTEGER;
  SearchAreaMerc  INTEGER;
  querystring     TEXT;
  i               INTEGER;

 BEGIN
  i:=0;direction:=-1;firstdistance:=-1;
  osmdirection=LOWER(osmdirection);

--
-- -------------------  First try to parse the given direction ----------------------------------------------------------
--
  IF     (osmdirection ~ '^[0-9]+$')                                                                                    THEN direction=(osmdirection::INTEGER)%180;
  ELSEIF (osmdirection ~ '^[0-9]+\.[0-9]+$')                                                                            THEN direction=(ROUND(osmdirection::FLOAT)::INTEGER)%180;
  ELSEIF (osmdirection='s'   OR osmdirection='south'           OR osmdirection='n'   OR osmdirection='north')           THEN direction:=0; 
  ELSEIF (osmdirection='ssw' OR osmdirection='south-southwest' OR osmdirection='nne' OR osmdirection='north-northeast') THEN direction:=22;
  ELSEIF (osmdirection='sw'  OR osmdirection='southwest'       OR osmdirection='ne'  OR osmdirection='northeast')       THEN direction:=45;
  ELSEIF (osmdirection='wsw' OR osmdirection='west-southwest'  OR osmdirection='ene' OR osmdirection='east-northeast')  THEN direction:=67;
  ELSEIF (osmdirection='w'   OR osmdirection='west'            OR osmdirection='e'   OR osmdirection='east' )           THEN direction:=90;
  ELSEIF (osmdirection='nw'  OR osmdirection='northwest'       OR osmdirection='se'  OR osmdirection='southeast' )      THEN direction:=135;
  ELSEIF (osmdirection='wnw' OR osmdirection='west-northwest'  OR osmdirection='ese' OR osmdirection='east-southeast')  THEN direction:=112;
  ELSEIF (osmdirection='nnw' OR osmdirection='north-northwest' OR osmdirection='sse' OR osmdirection='south-southeast') THEN direction:=157;
  ELSE
--
-- -------------------  No given direction: estmate it ----------------------------------------------------------
--
--
-- Open connection to database contours, if its not open
--
   IF ((dblink_get_connections() IS NULL) OR ('saddle_contours_connection' != ANY(dblink_get_connections()))) THEN
    PERFORM dblink_connect_u('saddle_contours_connection', 'dbname=contours');
   END IF;
   select round(SearchArea/cos(st_y(st_transform(st_setsrid(saddlepoint::geometry,900913),4326))/180*3.14159)) INTO SearchAreaMerc;
--
-- build query string, we need something like
--  "select geom,height,ST_Distance(geom,saddle) FROM contours where st_intersects((saddle,search area),geom) order by distance limit searchlimit;"
--
   querystring='SELECT wkb_geometry,height,ST_Distance(st_setsrid(wkb_geometry,900913),''' || saddlepoint || '''::geometry) as dist FROM contours WHERE 
                  ST_Intersects(ST_Expand(''' || saddlepoint || '''::geometry,' || SearchAreaMerc || '),st_setsrid(wkb_geometry,900913)) ORDER BY dist ASC LIMIT ' || SearchLimit;
--
-- Loop over this sample
--
   <<getcontourloop>>  
   FOR result IN ( SELECT height::FLOAT,ST_ClosestPoint(st_setsrid(way,900913),st_setsrid(saddlepoint::geometry,900913)) AS cp,dist::FLOAT
                          FROM dblink('saddle_contours_connection',querystring) 
                               AS t1(way geometry,height integer,dist float)
                 ) LOOP
    i:=i+1;
--
-- first contour line defines the "height" of the saddle point
--
    IF (i=1) THEN
     saddleheight:=result.height; 
     saddleheight:=result.height; 
--   RAISE NOTICE 'Setting hight to %',saddleheight;
    ELSE
     IF (ABS(saddleheight-result.height)>MinDescent) THEN
      SELECT CAST(d AS INTEGER) INTO thisdirection FROM (SELECT degrees(ST_Azimuth(saddlepoint,result.cp)) AS d) AS foo;
--
-- decreasing slope: the saddle directs to the closest point on contour line
-- increasing slope: it directs 90° to this point
--
      IF (result.height<saddleheight) THEN thisdirection:=(360+thisdirection)%180;    END IF;
      IF (result.height>saddleheight) THEN thisdirection:=(360+thisdirection+90)%180; END IF;
--    RAISE NOTICE 'New direction in step % height: % dir: % dist: %',i,result.height,thisdirection,result.dist;
--
-- First choice is made by the first contour line
--
      IF(firstdistance<0) THEN
       direction:=thisdirection;
       firstdistance:=result.dist;
--     RAISE NOTICE 'First direction: %',direction;
      ELSE
--
-- all other contour lines may do corrections to the first choice weighted with (distane of the first point/distance of this point)
--
       diffdirection=thisdirection-direction;
--     RAISE NOTICE 'difference %',diffdirection;
--
-- Instead of correcting clockwise by 170° do it 10° anti-clockwise
--
       IF(diffdirection> 90) THEN diffdirection=180-diffdirection; END IF;
       IF(diffdirection<-90) THEN diffdirection=diffdirection+180; END IF;
--     RAISE NOTICE 'Correcting direction by %*%=%',diffdirection,firstdistance/result.dist,diffdirection*(firstdistance/result.dist);
       direction:=(round(direction+diffdirection*(firstdistance/result.dist))::INTEGER)%180;
       IF (direction<0) THEN direction:=direction+180; END IF;
      END IF;
--    RAISE NOTICE 'Corrected direction: %',direction;     
     END IF;
    END IF;
   END LOOP getcontourloop;
--
-- update planet_osm_point with the estimated direction
--
   IF((updateflag='update') AND (osm_id!=0) AND (direction>0))THEN
    querystring:='UPDATE planet_osm_point SET direction=' || direction || ' WHERE osm_id=' || osm_id || ' AND direction IS NULL;';
    EXECUTE querystring;
   END IF;
-- don't close dblink-connection, we will need it again soon
-- PERFORM dblink_disconnect('saddle_contours_connection');
  END IF;
  RETURN direction;
 END;
$$ LANGUAGE plpgsql;
