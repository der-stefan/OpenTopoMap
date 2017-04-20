--
-- FUNCTION INTEGER getstationdirection(Point:GEOMETRY in Mercator,Stationlayer in TEXT)
-- -------------------------------------------------------------------------------------
--
-- returns the direction of a station at (Point) in degrees (0deg...179deg) (0:north 90:east 180:south)
--
-- Constants
--    SearchArea:   limit where the next rails must be (in map units, that means "mercator-meter")
--    SearchLimit:  maximum number of examined railways
--    RailLength:   lenght of the rails to estimate the tangent to it (in map units)
--    ErrorReturn:  direction which is returned in case of errors
--
--    -> RailLength should be big enough to select the most important rails, but not longer than the usual straight
--        part along the platforms
--    -> Searcharea should be small enough to get only rails belonging to this station
--    -> SearchLimit should be a typical number of rails near a station (maybe 1..10)
--
-- Algorithm:
--    get "SearchLimit" rails next to the station (in max. "SearchArea" distance) wich are at least "RailLength" long
--    cut out a part of (1..2)*"RailLength" of each rail
--    estimate the direction of the tangent of the rails by connecting startpoint of endpoint of this parts
--    get the direction from the station to this rail
--    estimate from this 2 directions wether it's a terminal or not
--    
-- Installation:
--    psql databasename < path_to_me/stationdirection.sql
--    (as owner of the database where the stations are, eg "gis")
--
--  Test:
--    SELECT name,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=4436626591;
--     --> Baiersdorf | 31
--
--

CREATE OR REPLACE FUNCTION getstationdirection(point IN GEOMETRY,Stationlayer in TEXT) RETURNS INTEGER AS $$

 DECLARE
  SearchArea   CONSTANT INTEGER :=  100;
  SearchLimit  CONSTANT INTEGER :=    8;
  RailLength   CONSTANT INTEGER :=   30;
  ErrorReturn  CONSTANT INTEGER :=    0;

  result          RECORD;
  direction       INTEGER;
  foundnextrail   INTEGER;
  is_a_terminal   INTEGER;
  i               INTEGER;
  d               INTEGER;
  cl              INTEGER;


 BEGIN
  i:=0;
  direction:=ErrorReturn;
--
-- Loop over some rails next to the station
--
  foundnextrail:=0;
  is_a_terminal:=0;
  <<railsloop>>  
  FOR result IN (SELECT osm_id,railway,layer,tunnel,
                        ST_Intersection(way,ST_Expand(ST_ClosestPoint(way,Point),RailLength)) as railpart,
                        ST_ClosestPoint(way,Point) as closestpoint
                        FROM  planet_osm_line AS t1
                        WHERE ST_DWithin(way,Point,SearchArea)
                        AND   railway IN ('funicular','light_rail','monorail','narrow_gauge','rail','disused','abandoned','preserved','subway') 
                        AND   ST_Length(way)>2*RailLength
                        ORDER BY st_distance(way,Point) ASC
                        LIMIT SearchLimit) 
                        LOOP
--
-- get the direction d of "tangent" of the rail and the direction cl of the line from the station to this rail
--
   SELECT CAST(az AS INTEGER) INTO d  FROM (SELECT Degrees(ST_Azimuth(ST_StartPoint(result.railpart),ST_EndPoint(result.railpart)))as az) AS foo;
   SELECT CAST(az AS INTEGER) INTO cl FROM (SELECT Degrees(ST_Azimuth(Point,result.closestpoint))as az) AS foo;
   d:=(360+d)%180;
   cl=(360+cl)%180;
--
-- d is null, if the rail is a loop (way 32517428)
--
   IF ( d IS NOT NULL ) THEN
   i:=i+1;
--
-- a station is a terminal of a rail, if the angle between d and cl is not about 90 degrees 
-- if (cl=NULL) the station is part of the rail and it is not a terminal
--
    is_a_terminal:=0;
--    IF ((cl IS NOT NULL) AND ((abs(d-cl)<45) OR (abs(d-cl)>135))) THEN is_a_terminal:=1; END IF;
    RAISE NOTICE '% osm_id=%  railway=% layer=% degrees=% shortestline=% terminal=%',i,result.osm_id,result.railway,result.layer,d,cl,is_a_terminal;
--
-- the first rail is taken, because we don't know if there will come better rails
-- that's a fall back if we don't get rails with same layer as the station
--
    IF (i=1) THEN
     direction:=d;
     IF (is_a_terminal = 1) THEN direction=(direction+90)%180; END IF;
    END IF;
--
-- the first rail with the same layer as the station is taken 
-- if the station is a terminal it is rotated by 90 degrees
--
    IF ((foundnextrail=0) AND ((result.layer = Stationlayer) OR ((Stationlayer IS NULL AND result.layer IS NULL) AND (result.tunnel IS NULL)))) THEN
     RAISE NOTICE '% take that rail',i;
     foundnextrail:=1;
     direction:=d;
     IF (is_a_terminal = 1) THEN direction=(direction+90)%180; END IF;
    END IF;
   END IF;
  END LOOP railsloop;
  RETURN direction;
 END;
$$ LANGUAGE plpgsql;

-- Tests
-- SELECT name,railway,layer,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=4436626591;
-- SELECT name,railway,layer,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=58822410;
-- SELECT name,railway,layer,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=2499357757;
-- SELECT name,railway,layer,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=286674799;
-- SELECT name,railway,layer,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=3090733718;
-- SELECT name,railway,layer,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=327613695;
-- SELECT name,railway,layer,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=3419908160;
-- SELECT name,railway,layer,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=317954672;
 SELECT name,railway,layer,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=2473297785;
