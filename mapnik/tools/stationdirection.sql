-- -------------------------------------------------------------------------------------
-- stationdirection.sql
-- 
-- defines a function to rotate railway stations to the direction of their rails.
-- updates planet_osm_point and sets direction. direction is null, if there are no
-- rails or other errors.
--
-- Installation:
--    psql databasename < path_to_me/stationdirection.sql
--    (with write permissions to planet_osm_point)
--
--
-- -------------------------------------------------------------------------------------
-- FUNCTION INTEGER getstationdirection(Point:GEOMETRY in Mercator,Stationlayer in TEXT)
-- -------------------------------------------------------------------------------------
--
-- returns the direction of a station at (Point,layer) in degrees (0deg...179deg) (0:north 90:east 180:south)
--
-- Constants
--    SearchArea:   limit where the "next" rails are searched (in meter)
--    SearchLimit:  maximum number of examined railways
--    RailLength:   lenght of the rails to estimate the tangent to it (in meter)
--    ErrorReturn:  direction which is returned in case of errors
--
--    -> RailLength should be big enough to select the most important rails, but not longer than the usual straight
--        part along the platforms
--    -> Searcharea should be small enough to get only rails belonging to this station
--    -> SearchLimit should be a typical number of rails near a station (maybe 1..10)
--
-- Algorithm:
--    get "SearchLimit" rails next to the station (in max. "SearchArea" distance) wich are at least "RailLength" long
--    cut out a part of "RailLength" of each rail
--    estimate the direction of the tangent of the rails by connecting startpoint of endpoint of this parts
--    take this tangent's direction as direction of the station
--    
--  Test:
--    SELECT name,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=4436626591;
--     --> Baiersdorf | 31
--
--

CREATE OR REPLACE FUNCTION getstationdirection(Point IN GEOMETRY,Stationlayer in TEXT) RETURNS TEXT AS $$

 DECLARE
  SearchArea   CONSTANT INTEGER :=   80;
  SearchLimit  CONSTANT INTEGER :=    8;
  RailLength   CONSTANT INTEGER :=   50;
  ErrorReturn  CONSTANT INTEGER := NULL;

  result          RECORD;
  SearchArea_m    INTEGER;
  RailLength_m    INTEGER;
  direction       INTEGER;
  foundnextrail   INTEGER;
  i               INTEGER;
  d               INTEGER;
  cc              DOUBLE PRECISION;


 BEGIN
  i:=0;
  direction:=ErrorReturn;
  select cos(st_y(st_transform(st_setsrid(Point::geometry,900913),4326))/180*3.1415927) INTO cc;
  SearchArea_m:=SearchArea/cc;
  RailLength_m:=RailLength/cc;
--
-- Loop over some rails next to the station
--
  foundnextrail:=0;
  <<railsloop>>  
  FOR result IN (SELECT osm_id,railway,layer,tunnel,
                        ST_Intersection(way,ST_Expand(ST_ClosestPoint(way,Point),RailLength_m/2)) as railpart
                        FROM  planet_osm_line AS t1
                        WHERE ST_DWithin(way,Point,SearchArea_m)
                        AND   railway IN ('funicular','light_rail','monorail','narrow_gauge','rail','preserved','subway') 
                        AND   ST_Length(way)>RailLength_m
                        ORDER BY st_distance(way,Point) ASC
                        LIMIT SearchLimit) 
                        LOOP
--
-- get the direction d of "tangent" of the rail
--
   SELECT CAST(az AS INTEGER) INTO d  FROM 
          (SELECT Degrees(ST_Azimuth(ST_StartPoint(result.railpart),ST_EndPoint(result.railpart)))as az) AS foo;
   d:=(360+d)%180;
--
-- d is sometimes null, if the rail is a small loop
--
   IF ( d IS NOT NULL ) THEN
    i:=i+1;
--
--  the first rail is taken, because we don't know if there will come better rails
--  that's a fall back if we don't get rails with same layer as the station
--
    IF (i=1) THEN
     direction:=d;
    END IF;
--
-- the first rail with the same layer as the station is taken 
--
    IF ((foundnextrail=0) AND ((result.layer = Stationlayer) OR ((Stationlayer IS NULL AND result.layer IS NULL) AND (result.tunnel IS NULL)))) THEN
     foundnextrail:=1;
     direction:=d;
    END IF;
   END IF;
  END LOOP railsloop;
  RETURN CAST(direction AS TEXT);
 END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------------------------
-- end of function  getstationdirection()
--
-- Now use this function to update the database
-- --------------------------------------------------------------------------

UPDATE planet_osm_point 
       SET direction=getstationdirection(way,layer)
       WHERE (railway='station' OR railway='halt') 
             AND (station IS NULL OR station!='subway') 
             AND (subway IS NULL OR subway!='yes')
             AND (direction IS NULL or direction NOT SIMILAR TO '[0-9]+');


-- ----------------------------------------------------------------
-- the end
-- ----------------------------------------------------------------

