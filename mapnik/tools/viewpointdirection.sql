-- FUNCTION viewpointdirection(intext IN TEXT) RETURNS otm_vp_twoviewranges 
--
-- Get a string as parameter and returns a composite type with
--    s1,e1,a1 integer: start and end angle of the first viewing range, angle between them
--    s2,e2,a2 integer: start, end, angle of the second viewing range
--    If there is only one viewing range, (s1,e1,a1) is filled, (s2,e2,a2) is (NULL,NULL,NULL)

--
-- intext may be any string with
--  * a number (0..360) is interpreted as a segment around this angle
--  * a cardinal (NW or SSW or South) is interpreted as a segment around this direction
--  * a range of numbers or cardinals (56-N or 30-90) is a clockwise segment between this two directions
--  * a list of two numbers, cardinals or ranges separated by a semicolon (40-90;180-270) is interpreted
--    as two segments.
--
--  The angles will be rounded to some values we have icons for. If the gap between two segments is too
--  small, this gap will be filled (e.g. "10-30;40-100" will be converted to 10-100).
--  Some unusefull characters are deleted but not all ("°" is deleted, commas or spaces are not). 
--  If something goes wrong (e.g. "10 60", "N,S", "sometext", empty intext) intext is interpreted as "0-360".
--  "360" is not interpreted as "all direction" but as "North" 
--
-- -----------------------------------------------------------------------------------------------------


-- two helper functions --------------------------------------------------------------------------------

--
-- data type for a direction with start,end and angle
-- and the same for two directions
CREATE TYPE otm_vp_viewrange     AS (s INTEGER, e INTEGER,a INTEGER);
CREATE TYPE otm_vp_twoviewranges AS (s1 INTEGER, e1 INTEGER,a1 INTEGER,s2 INTEGER, e2 INTEGER,a2 INTEGER);



CREATE OR REPLACE FUNCTION otm_vp_parseangle(intext IN TEXT) RETURNS INTEGER AS $$
-- interprets intext as angle, intext may be a number (-360..360) or a cardinal direction
-- returns NULL or the angle as positive integer (0..359)

 DECLARE
  angle    INTEGER;
  inangle  TEXT;

 BEGIN
  inangle:=btrim(intext);
  IF     (inangle ~ E'^-*[0-9]+$'              )   THEN angle:=(inangle::INTEGER+360)%360;
  ELSEIF (inangle ~ E'^-*[0-9]+\\.[0-9]+$'     )   THEN angle:=((ROUND(inangle::FLOAT)::INTEGER)+360)%360; 
  ELSEIF (inangle='n'   OR inangle='north'     )   THEN angle:=0;
  ELSEIF (inangle='nne'                        )   THEN angle:=22;
  ELSEIF (inangle='ne'  OR inangle='northeast' )   THEN angle:=45;
  ELSEIF (inangle='ene'                        )   THEN angle:=67;
  ELSEIF (inangle='e'   OR inangle='east'      )   THEN angle:=90;
  ELSEIF (inangle='ese'                        )   THEN angle:=112;
  ELSEIF (inangle='se'  OR inangle='southeast' )   THEN angle:=135;
  ELSEIF (inangle='sse'                        )   THEN angle:=157;
  ELSEIF (inangle='s'   OR inangle='south'     )   THEN angle:=180;
  ELSEIF (inangle='ssw'                        )   THEN angle:=202;
  ELSEIF (inangle='sw'  OR inangle='southwest' )   THEN angle:=225;
  ELSEIF (inangle='wsw'                        )   THEN angle:=247;
  ELSEIF (inangle='w'   OR inangle='west'      )   THEN angle:=270;
  ELSEIF (inangle='wnw'                        )   THEN angle:=292;
  ELSEIF (inangle='nw'  OR inangle='northwest' )   THEN angle:=315;
  ELSEIF (inangle='nnw'                        )   THEN angle:=337;
  ELSE                                                  angle:=NULL;
  END IF;
  RETURN angle;
 END;
$$ LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION otm_vp_parserange(intext IN TEXT,defaultangle IN INTEGER) RETURNS otm_vp_viewrange AS $$
-- parse a string like "N-E", "45-S", "270-90". Returns a otm_vp_viewrange with start, end and angle of this range.
-- In a simple case a "range" is a singe value ("W", "270"). Thats interpreted as a viewing angle of defaultangle degrees
-- around this direction

 DECLARE
  ret otm_vp_viewrange;
  d   INTEGER;
  d1  INTEGER;
  d2  INTEGER;
  a   INTEGER;

 BEGIN
  ret.s:=NULL;ret.e:=NULL;ret.a:=NULL;d1:=NULL;d2:=NULL;
--
-- simple case: "range" is a single number or cardinal direction -> viewing angle is defaultangle in this direction
--
  d:=otm_vp_parseangle(intext);
  IF (d IS NOT NULL) THEN
   a:=defaultangle;
   d1:=(d-a/2+360)%360; 
   d2:=d1+a;
  ELSE
--
-- "range" are two numbers or cardinal direction separated by "-" -> viewing angle is calculated from left to right value
-- and rounded down or up to the next angle for wich we have an icon.
--
   d1:=otm_vp_parseangle(split_part(intext,'-',1));
   d2:=otm_vp_parseangle(split_part(intext,'-',2));   
   IF ((d1 IS NOT NULL) AND (d2 IS NOT NULL)) THEN
    a:=d2-d1;
    IF (a=0) THEN a:=360;   END IF;
    IF (a<0) THEN a:=a+360; END IF;
    IF     (a<=75  ) THEN d1:=d1-( 60-a)/2;a:=60;
    ELSEIF (a<=112 ) THEN d1:=d1-( 90-a)/2;a:=90;
    ELSEIF (a<=177 ) THEN d1:=d1-(135-a)/2;a:=135;
    ELSEIF (a<=202 ) THEN d1:=d1-(180-a)/2;a:=180;
    ELSEIF (a<=247 ) THEN d1:=d1-(225-a)/2;a:=225;
    ELSEIF (a<=315 ) THEN d1:=d1-(270-a)/2;a:=270;
    ELSE                  d1:=0;           a:=360;
    END IF;
   END IF;
  END IF;
  d1:=(d1+360)%360;
  d2:=d1+a;
  IF (d2>=360) THEN d2:=d2-360; END IF;
  IF (a=360)   THEN d1:=0;d2:=359; END IF;
  ret.s=d1;ret.e=d2;ret.a=a;
  RETURN ret;   
 END;
$$ LANGUAGE plpgsql;


-- main function --------------------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION viewpointdirection(intext IN TEXT) RETURNS otm_vp_twoviewranges AS $$
-- interprets osmdirection as number, cardinal direction or range of two numbers
-- returns otm_vp_twoviewranges with filled s1,e1,a1 and maybe also filled s2,e2,a2

 DECLARE
  ret          otm_vp_twoviewranges;
  range1       otm_vp_viewrange; 
  range2       otm_vp_viewrange;
  g1           INTEGER;
  g2           INTEGER;
  osmdirection TEXT;
  

 BEGIN
--
-- clean input, but leave some common invalid delimiters (" ",/). They will lead to errors later,
-- but we shoult avoid to get a valid result because "0 90"="090" or "N/E"="NE"
--
  osmdirection:=intext;
  ret.s1:=NULL;ret.s2:=NULL;ret.e1:=NULL;ret.e2:=NULL;ret.a1:=NULL;ret.a2:=NULL;
  osmdirection:=regexp_replace(LOWER(osmdirection),'[^a-z0-9;.,+/ -]','','g');
--
-- simple cases: direction is NULL or empty: return a full circle from north to north
--
  IF     (osmdirection IS NULL) THEN ret.s1=0;ret.e1:=0;ret.a1:=360;
  ELSEIF (osmdirection='')      THEN ret.s1=0;ret.e1:=0;ret.a1:=360;
  ELSEIF (osmdirection='0-360') THEN ret.s1=0;ret.e1:=0;ret.a1:=360;
  ELSEIF (osmdirection='0-359') THEN ret.s1=0;ret.e1:=0;ret.a1:=360;
--
-- One number, cardinal direction or a range of them, but not two ranges 
--
  ELSEIF (osmdirection NOT LIKE '%_;_%') THEN 
   range1=otm_vp_parserange(osmdirection,135);
   IF (range1.s IS NOT NULL) THEN
    ret.s1=range1.s;ret.e1:=range1.e;ret.a1:=range1.a;
   END IF;
  ELSE
--
-- Two ranges, separated by ";"
--
   range1=otm_vp_parserange(split_part(osmdirection,';',1),90);
   range2=otm_vp_parserange(split_part(osmdirection,';',2),90);
--
-- be sure that at least one segment got all values
--
   IF ((range1.e IS NULL) OR (range1.a IS NULL)) THEN range1.s:=NULL;range1.e:=NULL;range1.a:=NULL; END IF;
   IF ((range2.e IS NULL) OR (range2.a IS NULL)) THEN range2.s:=NULL;range2.e:=NULL;range2.a:=NULL; END IF;
   IF (range1.s IS NOT NULL) THEN
    ret.s1=range1.s;ret.e1:=range1.e;ret.a1:=range1.a;
   END IF;
   IF (range2.s IS NOT NULL) THEN
    ret.s2=range2.s;ret.e2:=range2.e;ret.a2:=range2.a;
   END IF;
--
-- Do these two ranges overlap or the gap is smaller than 45°?
-- (maybe, because of mapping, maybe because we expand the ranges to the next available icon range) 
--
   IF((range1.s IS NOT NULL) AND (range2.s IS NOT NULL)) THEN
    g1:=range1.s-range2.e;IF(range1.s<180 AND range2.e>=180) THEN g1:=-360-g1; END IF;
    g2:=range2.s-range1.e;IF(range2.s<180 AND range1.e>=180) THEN g2:=-360-g2; END IF;
    IF(abs(g1)<45 OR abs(g2)<45) THEN
     IF (abs(g1)<45 AND abs(g2)<45) THEN
      ret.s1=0;ret.e1:=0;ret.a1:=360;ret.s2:=NULL;ret.e2:=NULL;ret.a2:=NULL;
     ELSE
      IF (abs(g1)>abs(g2)) THEN range1=otm_vp_parserange(range1.s||'-'||range2.e,135);
      ELSE                      range1=otm_vp_parserange(range2.s||'-'||range1.e,135);
      END IF;
      ret.s1=range1.s;ret.e1:=range1.e;ret.a1:=range1.a;
      ret.s2:=NULL;ret.e2:=NULL;ret.a2:=NULL;
     END IF;
    END IF;
   END IF;
  END IF;
--
-- No parseable text or buggy parser
--
  IF ((ret.s1 IS NULL) OR (ret.e1 IS NULL) OR (ret.a1 IS NULL))  THEN
   ret.s1=0;ret.e1:=360;ret.a1:=360;
  END IF;
  RETURN ret;
 END;
$$ LANGUAGE plpgsql;

