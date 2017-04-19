--
-- FUNCTION INTEGER getstationdirection(Point:GEOMETRY in Mercator,Sztationlayer in TEXT)
-- --------------------------------------------------------------------------------------
--
-- returns the direction of a station at (Point) in degrees (0deg...179deg) (0:north 90:east 180:south)
--
-- "Layer" is the layer of the station, but its not used now, because we have a lot of stations at
--  layer=0 with their rails at layer=-1
--
-- Constants
--    SearchArea:   limit where the next rails must be (in map units, that means "mercator-meter")
--    SearchLimit:  maximum number of examined railways
--    RailLength:   lenght of the rails to estimate the tangent to it (in map units)
--    ErrorReturn:  direction which is returned in case of errors
--
--
-- Algorithm:
--    get "SearchLimit" rails next to the station (in max. "SearchArea" distance) wich are at least "RailLength" long
--    cut out a part of (1..2)*"RailLength" of each rail
--    estimate the tangent of the rails by connecting startpoint of endpoint of this parts
--    get this rail which ist "most parallel" to the other rails and take its tangent as "direction" of the station
--    
--    -> RailLength should be big enough to select the most important rails, but not longer than the usual straight
--        part along the platforms
--    -> Searcharea should be small enough to get only rails belonging to this station
--    -> SearchLimit should be a typical number of rails near a station (maybe 1..10)
--
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
  SearchLimit  CONSTANT INTEGER :=    5;
  RailLength   CONSTANT INTEGER :=   30;
  ErrorReturn  CONSTANT INTEGER :=    0;

  result          RECORD;
  direction       INTEGER;
  raildirection   INTEGER [];
  dirdiff         INTEGER [];
  i               INTEGER;
  j               INTEGER;
  k               INTEGER;
  d               INTEGER;
  


 BEGIN
  i:=0;
  direction:=ErrorReturn;
--
-- Loop over some rails next to the station
--
  <<railsloop>>  
  FOR result IN (SELECT osm_id,railway,ST_Intersection(way,ST_Expand(ST_ClosestPoint(way,Point),RailLength)) as railpart
                        FROM  planet_osm_line AS t1
                        WHERE ST_DWithin(way,Point,SearchArea)
                        AND   railway IN ('funicular','light_rail','monorail','narrow_gauge','rail','disused','abandoned','preserved') 
                        AND   ST_Length(way)>2*RailLength
--                        AND   (layer=Stationlayer or (Stationlayer is null and layer is null))
                        ORDER BY st_distance(way,Point) ASC
                        LIMIT SearchLimit) 
                        LOOP
   i:=i+1;d:=0;
--
-- get the tangent of the rail
--
   SELECT CAST(az AS INTEGER) INTO d FROM (SELECT Degrees(ST_Azimuth(ST_StartPoint(result.railpart),ST_EndPoint(result.railpart)))as az) AS foo;
   d:=(360+d)%180;
   raildirection[i]:=d;
--   RAISE NOTICE '% osm_id=%  railway=% degrees=%',i,result.osm_id,result.railway,raildirection[i];
   IF (i=1) THEN 
    direction:=d; 
   END IF;
  END LOOP railsloop;
--
-- get the "best" rail: mybe we should do some clustering ...
--
  IF (i>2) THEN
   j:=1;
   WHILE (j<=i) LOOP
    k:=1;
    dirdiff[j]:=0;
    WHILE (k<=i) LOOP
     dirdiff[j]:=dirdiff[j]+abs(raildirection[j]-raildirection[k])%90;
--     RAISE NOTICE 'dirdiff %-%: %',j,k,dirdiff[j];
     k:=k+1;
    END LOOP;
    j:=j+1;
   END LOOP;
   direction:=raildirection[1];
   j:=1;k:=1;
   WHILE (j<=i) LOOP
    IF (dirdiff[j]<dirdiff[k]) THEN
     direction:=raildirection[j];
--     RAISE NOTICE 'dir % won',j;
     k:=j;
    END IF;
    j:=j+1;
   END LOOP;
  END IF;
  RETURN direction;
 END;
$$ LANGUAGE plpgsql;

SELECT name,railway,getstationdirection(way,layer) as direction from planet_osm_point where osm_id=4436626591;
