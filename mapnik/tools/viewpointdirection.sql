

CREATE OR REPLACE FUNCTION parseangle(intext IN TEXT) RETURNS INTEGER AS $$
-- interprets intext as angle, intext may be a number or a cardinal direction
-- returns NULL or the angle as positive integer (0..359)

 DECLARE
  angle INTEGER;

 BEGIN
  IF     (intext ~ '^-*[0-9]+$'              )   THEN angle:=(intext::INTEGER+360)%360;
  ELSEIF (intext ~ '^-*[0-9]+\.[0-9]+$'      )   THEN angle:=(ROUND(intext::FLOAT)::INTEGER+360)%360;
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
  direction       INTEGER;
  result          TEXT;
  d               INTEGER;

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
-- not so simple cases ;)
--
  RETURN 'its complicated';
 END;
$$ LANGUAGE plpgsql;
