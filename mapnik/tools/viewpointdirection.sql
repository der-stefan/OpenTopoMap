

CREATE OR REPLACE FUNCTION parseangle(intext IN TEXT) RETURNS INTEGER AS $$
-- interprets intext as angle, intext may be a number (-360..360) or a cardinal direction
-- returns NULL or the angle as positive integer (0..359)

 DECLARE
  angle INTEGER;

 BEGIN
  IF     (intext ~ '^-*[0-9]+$'              )   THEN angle:=(intext::INTEGER+360)%360;
  ELSEIF (intext ~ '^-*[0-9]+\.[0-9]+$'      )   THEN angle:=((ROUND(intext::FLOAT)::INTEGER)+360)%360; 
  ELSEIF (intext='n'   OR intext='north'     )   THEN angle:=0;
  ELSEIF (intext='nne'                       )   THEN angle:=22;
  ELSEIF (intext='ne'  OR intext='northeast' )   THEN angle:=45;
  ELSEIF (intext='ene'                       )   THEN angle:=67;
  ELSEIF (intext='e'   OR intext='east'      )   THEN angle:=90;
  ELSEIF (intext='ese'                       )   THEN angle:=112;
  ELSEIF (intext='se'  OR intext='southeast' )   THEN angle:=135;
  ELSEIF (intext='sse'                       )   THEN angle:=157;
  ELSEIF (intext='s'   OR intext='south'     )   THEN angle:=180;
  ELSEIF (intext='ssw'                       )   THEN angle:=102;
  ELSEIF (intext='sw'  OR intext='southwest' )   THEN angle:=225;
  ELSEIF (intext='wsw'                       )   THEN angle:=247;
  ELSEIF (intext='w'   OR intext='west'      )   THEN angle:=270;
  ELSEIF (intext='wnw'                       )   THEN angle:=292;
  ELSEIF (intext='nw'  OR intext='northwest' )   THEN angle:=315;
  ELSEIF (intext='nnw'                       )   THEN angle:=337;
  ELSE                                                angle:=NULL;
  END IF;
  RETURN angle;
 END;
$$ LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION viewpointdirection(osmdirection IN TEXT) RETURNS TEXT AS $$
-- interprets osmdirection as number, cardinal direction or range of two numbers
-- returns <some strucure with angle/with >

 DECLARE
  direction INTEGER;
  d         INTEGER;
  d1        INTEGER;
  d2        INTEGER;
  d3        INTEGER;
  d4        INTEGER;
  a         INTEGER;
  a1        INTEGER;
  a2        INTEGER;

 BEGIN
  direction:=NULL;
--
-- simple cases: direction is NULL or empty: return a full circle from north to north
--
  IF     (osmdirection IS NULL) THEN RETURN '0 360';
  ELSEIF (osmdirection='')      THEN RETURN '0 360';
  END IF;
--
-- next simple case: direction is a single value: return a half circle from direction-90 to direction+90
--
  osmdirection:=regexp_replace(LOWER(osmdirection),'[^a-z0-9;.,-]','','g');
  direction:=parseangle(osmdirection);
  IF (direction IS NOT NULL) THEN
   d:=(direction-90+360)%360; 
   RETURN d||' 180';
  END IF;
--
-- a range with two angles ("10-20" or "W-E": get the difference between these two angles round it to the
-- next available icon (60,90,135,180...) and rotate the icon to the middle of these angles
--
  d1:=parseangle(split_part(osmdirection,'-',1));
  d2:=parseangle(split_part(osmdirection,'-',2));
  IF ((d1 IS NOT NULL) AND (d2 IS NOT NULL)) THEN
   a:=d2-d1;
   IF (a<0) THEN a:=a+360; END IF;
   IF     (a<=60  ) THEN d1:=d1-( 60-a)/2;a:=60;
   ELSEIF (a<=90  ) THEN d1:=d1-( 90-a)/2;a:=90;
   ELSEIF (a<=135 ) THEN d1:=d1-(135-a)/2;a:=135;
   ELSEIF (a<=180 ) THEN d1:=d1-(180-a)/2;a:=180;
   ELSEIF (a<=225 ) THEN d1:=d1-(225-a)/2;a:=225;
   ELSEIF (a<=270 ) THEN d1:=d1-(270-a)/2;a:=270;
   ELSEIF (a<=360 ) THEN d1:=0;           a:=360;
   END IF;
   IF (d1<0) THEN d1:=d1+360; END IF;
   RETURN d1||' '||a;   
  END IF; 
--
-- two ranges separated by semicolon ("N-E;S-W"): get two angles, test if the gaps between them
-- are more than 30°
--
  d1:=parseangle(split_part(split_part(osmdirection,';',1),'-',1));
  d2:=parseangle(split_part(split_part(osmdirection,';',1),'-',2));
  d3:=parseangle(split_part(split_part(osmdirection,';',2),'-',1));
  d4:=parseangle(split_part(split_part(osmdirection,';',2),'-',2));
  IF ((d1 IS NOT NULL) AND (d2 IS NOT NULL) AND (d3 IS NOT NULL) AND (d4 IS NOT NULL)) THEN
   a1:=d2-d1;
   IF (a1<0) THEN a1:=a1+360; END IF;
   a2:=d4-d3;
   IF (a2<0) THEN a2:=a2+360; END IF;
   IF     (a1<=60  ) THEN d1:=d1-( 60-a1)/2;d2:=d2+( 60-a1)/2;a1:=60;
   ELSEIF (a1<=90  ) THEN d1:=d1-( 90-a1)/2;d2:=d2+( 90-a1)/2;a1:=90;
   ELSEIF (a1<=135 ) THEN d1:=d1-(135-a1)/2;d2:=d2+(135-a1)/2;a1:=135;
   ELSEIF (a1<=180 ) THEN d1:=d1-(180-a1)/2;d2:=d2+(180-a1)/2;a1:=180;
   ELSEIF (a1<=225 ) THEN d1:=d1-(225-a1)/2;d2:=d2+(225-a1)/2;a1:=225;
   ELSEIF (a1<=270 ) THEN d1:=d1-(270-a1)/2;d2:=d2+(270-a1)/2;a1:=270;
   ELSEIF (a1<=360 ) THEN d1:=0            ;d2:=0            ;a1:=360;
   END IF;
   IF     (a2<=60  ) THEN d3:=d3-( 60-a2)/2;d4:=d4+( 60-a2)/2;a2:=60;
   ELSEIF (a2<=90  ) THEN d3:=d3-( 90-a2)/2;d4:=d4+( 90-a2)/2;a2:=90;
   ELSEIF (a2<=135 ) THEN d3:=d3-(135-a2)/2;d4:=d4+(135-a2)/2;a2:=135;
   ELSEIF (a2<=180 ) THEN d3:=d3-(180-a2)/2;d4:=d4+(180-a2)/2;a2:=180;
   ELSEIF (a2<=225 ) THEN d3:=d3-(225-a2)/2;d4:=d4+(225-a2)/2;a2:=225;
   ELSEIF (a2<=270 ) THEN d3:=d3-(270-a2)/2;d4:=d4+(270-a2)/2;a2:=270;
   ELSEIF (a2<=360 ) THEN d3:=0            ;d4:=0            ;a2:=360;
   END IF;
   IF (d1<0)    THEN d1:=d1+360; END IF;
   IF (d3<0)    THEN d3:=d3+360; END IF;
   IF (d2>=360) THEN d2:=d2-360; END IF;
   IF (d4>=360) THEN d4:=d4-360; END IF;
   IF ((abs((d2-d3)%360)>30) AND (abs((d1-d4)%360)>30) AND (abs((d2-d3)%360)<330) AND (abs((d1-d4)%360)<330)) THEN
    RETURN d1||' '||a1||' '||d3||' '||a2;   
   END IF;
  END IF; 
--
-- No parseable test (or the gap between two ranges too small)
--
  RETURN 'its complicated';
 END;
$$ LANGUAGE plpgsql;
