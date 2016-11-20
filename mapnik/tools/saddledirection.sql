--
-- FUNCTION INTEGER getdirection(Point:GEOMETRY in EPSG:900913)
-- ------------------------------------------------------------
--
-- returns the direction of a saddle at (Point) in degrees (0deg...179deg) (3 o'clock: 0deg, 12: 90deg, 9:180deg)
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
--    you need a table "contours" with "height" and "way" (in EPSG:900913)
--    
--

CREATE OR REPLACE FUNCTION getsaddledirection(GEOMETRY) RETURNS INTEGER AS $$

 DECLARE
  SearchArea   CONSTANT INTEGER := 100;
  SearchLimit  CONSTANT INTEGER :=  20;
  MinDescent   CONSTANT INTEGER :=  30;

  saddlepoint  GEOMETRY := $1;
  result       RECORD;
  saddleheight FLOAT;
  direction    INTEGER;
  i            INTEGER;

 BEGIN
  i:=0;direction:=-1;
  <<getcontourloop>>  
  FOR result IN ( SELECT height::FLOAT,ST_ClosestPoint(way,saddlepoint) AS cp 
                         FROM contours 
                         WHERE way && ST_Expand(saddlepoint,SearchArea) 
                         ORDER BY ST_Distance(way,saddlepoint) ASC 
                         LIMIT SearchLimit                                     ) LOOP
   i:=i+1;
   IF (i=1) THEN
    saddleheight:=result.height; 
   ELSE
    IF (result.height<saddleheight-MinDescent) THEN
     SELECT CAST(d AS INTEGER) INTO direction FROM (SELECT degrees(ST_Azimuth(saddlepoint,result.cp)) AS d) AS foo;
     direction:=(720-(direction-90))%180;
     EXIT getcontourloop;
    END IF;
    IF (result.height>saddleheight+MinDescent) THEN
     SELECT CAST(d AS INTEGER) INTO direction FROM (SELECT degrees(ST_Azimuth(saddlepoint,result.cp)) AS d) AS foo;
     direction:=(720-(direction))%180;
     EXIT getcontourloop;
    END IF;
    
   END IF;
  END LOOP getcontourloop;
  RETURN direction;
 END;
$$ LANGUAGE plpgsql;
