-- FUNCTION getpitchicon(inway IN GEOMETRY,sport IN TEXT) RETURNS otm_pitch
-- 
-- Gets a geometry (a way in EPSG:3857) of a pitch, and a sport=*, calculates the
-- size and the direction of a label and returns a composite type with
--
--  icon            text:  something like 'soccer', 'tennis' derived from sport
--                         if there is a track arround the pitch icon is something
--                         like 'soccer_with_track' or 'multi_with_track'
--  pitch_area      float: area of the pitch im m^2
--  angle           float: rotation of the pitch (0=North) 
--  labelsizefactor float: a factor to strech the icon, depends on the latitude
--
--  derived from https://github.com/giggls/openstreetmap-carto-de, which was
--  derived from https://github.com/cquest/osmfr-cartocss. Thanks.

--
-- a composite type to return the 4 values
--
CREATE TYPE otm_pitch AS (icon TEXT,pitch_area FLOAT,angle FLOAT,labelsizefactor FLOAT);

--
-- the function
--

CREATE OR REPLACE FUNCTION getpitchicon(inway geometry, sport text) RETURNS otm_pitch AS $$

 DECLARE
  myway           GEOMETRY;
  d12             FLOAT;
  d23             FLOAT;
  d13             FLOAT;
  a12             FLOAT;
  a23             FLOAT;
  labelsizefactor FLOAT;
  angle           FLOAT;
  angle_diff      FLOAT;
  pitch_area      FLOAT;
  n1              GEOMETRY;
  n2              GEOMETRY;
  n3              GEOMETRY;
  sportlist       TEXT;
  icon            TEXT;
  ret             otm_pitch;
  trackdist       FLOAT;
  trackid         BIGINT;

 BEGIN
--
-- "trackdist" is the distance in which we are searching a track arround the pitch
--
  trackdist=40;
  ret.icon=NULL;
  sportlist=';'||sport||';';
  trackdist=40;
--
-- first we check, that its a kind of sport, we have a icon for. If not we don't have to calculate
--
  IF((sportlist like '%;tennis;%')            OR (sportlist like '%;soccer;%')      OR (sportlist like '%;basketball;%')    OR
     (sportlist like '%;rugby;%')             OR (sportlist like '%;rugby_union;%') OR (sportlist like '%;rugby_league;%')  OR 
     (sportlist like '%;american_football;%') OR (sportlist like '%;multi;%') ) THEN
--
-- get a simplified rectangle around the way, get the first 3 corners of this rectangle
--
   myway=ST_ExteriorRing(ST_SimplifyPreserveTopology((st_dump(inway)).geom,100)) LIMIT 1;
   n1:=ST_Transform(ST_PointN(myway,1),4326);
   n2:=ST_Transform(ST_PointN(myway,2),4326);
   n3:=ST_Transform(ST_PointN(myway,3),4326);
--
-- calculate length of the first 2 sides (d12,d23), the diagonal (d13),
-- the angle between the sides and one angle to the north direction of d12 or d23
--
   d12:=ST_DistanceSphere(n1,n2);
   d23:=ST_DistanceSphere(n2,n3);
   d13:=ST_DistanceSphere(n1,n3);
   pitch_area:=d12*d23;
   a12:=degrees(ST_Azimuth(ST_PointN(myway,1),ST_PointN(myway,2)));
   a23:=degrees(ST_Azimuth(ST_PointN(myway,2),ST_PointN(myway,3)));
   angle_diff:=cast(abs(a12-a23) as integer)%180;
   angle:=90+(a12+a23+90)/2;
--
-- we need a correction factor, because we calculate all distances with ST_DistanceSphere() in m and have maps and icons in 3857
--
   labelsizefactor:=1/(cos(ST_Y(n2)/180*3.1415927));
   icon:=NULL;
--
-- we need something like a rectangle with corners near 90°
--
   IF ((angle_diff>85) AND (angle_diff<95)) THEN
--
-- check if we got a real tennis pitch:
-- a tennis court is <1100 ^2, and its diagonal ist 20-43m, one side is 20-45m and the other side is 8-30m
-- 
    IF (sportlist like '%;tennis;%') THEN
     IF((pitch_area<1100) AND (d13>20) AND (d13<52) ) THEN 
      IF ((d12>20) AND (d12<45) AND (d23>8) AND (d23<30)) THEN icon:='tennis';                END IF; 
      IF ((d23>20) AND (d23<45) AND (d12>8) AND (d12<30)) THEN icon:='tennis';angle:=angle+90;END IF;
     END IF;
    END IF;
--
-- similar checks for other sports (for soccer pitch_area has to be checked in the style) 
--    
    IF ((icon IS NULL) AND (sportlist like '%;soccer;%')) THEN
     IF ((d12>90) AND (d12<130) AND (d23>45) AND (d23<110) AND (d13>100) AND (d13<170)) THEN icon:='soccer';                END IF;
     IF ((d23>90) AND (d23<130) AND (d12>45) AND (d12<110) AND (d13>100) AND (d13<170)) THEN icon:='soccer';angle:=angle+90;END IF;
    END IF;
--
-- We don't have a icon for sport=multi, but we use a oval for soccer and multi in lower zoom levels (multis may be a little bit larger than soccer)
--
    IF ((icon IS NULL) AND (sportlist like '%;multi;%')) THEN
     IF ((d12>90) AND (d12<140) AND (d23>45) AND (d23<120) AND (d13>100) AND (d13<180)) THEN icon:='multi';                END IF;
     IF ((d23>90) AND (d23<140) AND (d12>45) AND (d12<120) AND (d13>100) AND (d13<180)) THEN icon:='multi';angle:=angle+90;END IF;
    END IF;
    IF ((icon IS NULL) AND (sportlist like '%;basketball;%')) THEN
     IF ((pitch_area<600) AND (d13>20) AND (d13<38) ) THEN
      IF ((d12>20) AND (d12<35) AND (d23>10) AND (d23<35)) THEN icon:='basketball';                END IF;
      IF ((d23>20) AND (d23<35) AND (d12>10) AND (d12<35)) THEN icon:='basketball';angle:=angle+90;END IF;
     END IF;
    END IF;
    IF ((icon IS NULL) AND (sportlist like '%rugby%')) THEN
     IF ((pitch_area>6000) AND (pitch_area<11000) AND (d13>100) AND (d13<170)) THEN
      IF ((d23>50) AND (d23<100) AND (d12>100) AND (d12<170)) THEN icon:='rugby';                END IF;
      IF ((d12>50) AND (d12<100) AND (d23>100) AND (d23<170)) THEN icon:='rugby';angle:=angle+90;END IF;
     END IF;
    END IF;
    IF ((icon IS NULL) AND (sportlist like '%;american_football;%')) THEN
     IF ((pitch_area>3500) AND (pitch_area<8500) AND (d13>80) AND (d13<170)) THEN
      IF ((d23>32) AND (d23<65) AND (d12>80) AND (d12<130)) THEN icon:='football';                END IF; 
      IF ((d12>32) AND (d12<65) AND (d23>80) AND (d23<130)) THEN icon:='football';angle:=angle+90;END IF;
     END IF;
    END IF;
   END IF;

   if (icon='soccer' OR icon='multi') THEN
--
-- Search for surrounding leisure=track
-- at first for closed tracks around the pitch in planet_osm_line
--
    trackid=osm_id FROM planet_osm_line
              WHERE planet_osm_line.way && ST_EXPAND(myway,trackdist/labelsizefactor) 
              AND   leisure='track' 
              AND   CASE WHEN ST_ISCLOSED(planet_osm_line.way)
                          THEN ST_CONTAINS(ST_MakePolygon(ST_ExteriorRing(planet_osm_line.way)),myway) 
                         ELSE FALSE 
                    END
              LIMIT 1;
--
-- then for track areas around the pitch in planet_osm_polygon
--
    IF (trackid IS NULL) THEN
    trackid=osm_id FROM planet_osm_polygon
              WHERE planet_osm_polygon.way && ST_EXPAND(myway,trackdist/labelsizefactor) 
              AND   leisure='track' 
              AND   ST_NumGeometries(planet_osm_polygon.way)=1
              AND   ST_CONTAINS(ST_MakePolygon(ST_ExteriorRing(planet_osm_polygon.way)),myway)
              LIMIT 1;
    END IF;
--
--  if there was a leisure=track append "_with_track" to icon
--
    IF (trackid IS NOT NULL) THEN
     icon=icon||'_with_track';
    END IF;
   END IF;

   if (icon IS NOT NULL) THEN
    ret.icon:=icon;
    ret.angle:=angle;
    ret.pitch_area:=pitch_area;
    ret.labelsizefactor:=labelsizefactor;
   END IF;
  ELSE 
   ret.icon:=NULL;
  END IF;  
  return ret;
 END;
$$ LANGUAGE plpgsql;

