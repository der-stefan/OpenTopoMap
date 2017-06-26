--
-- data type for a direction with start,end and angle
-- and the same for two directions
CREATE TYPE otm_vp_viewrange     AS (s INTEGER, e INTEGER,a INTEGER);
CREATE TYPE otm_vp_twoviewranges AS (s1 INTEGER, e1 INTEGER,a1 INTEGER,s2 INTEGER, e2 INTEGER,a2 INTEGER);



CREATE OR REPLACE FUNCTION otm_vp_parseangle(intext IN TEXT) RETURNS INTEGER AS $$
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




CREATE OR REPLACE FUNCTION otm_vp_parserange(intext IN TEXT) RETURNS otm_vp_viewrange AS $$
-- parse a string like "N-E", "45-S", "270-90". Returns a otm_vp_viewrange with start, end and angle of this range.
-- In a simple case a "range" is a singe value ("W", "270"). Thats interpreted as a viewing angle of 135° around this direction

 DECLARE
  ret otm_vp_viewrange;
  d   INTEGER;
  d1  INTEGER;
  d2  INTEGER;
  a   INTEGER;

 BEGIN
  ret.s:=NULL;ret.e:=NULL;ret.a:=NULL;d1:=NULL;d2:=NULL;
--
-- simple case: "range" is a single number or cardinal direction -> viewing angle is 135° in this direction
--
  d:=otm_vp_parseangle(intext);
  IF (d IS NOT NULL) THEN
   d1:=(d-67+360)%360; 
   a:=135;
   d2:=d1+a;
  ELSE
--
-- "range" are two numbers or cardinal direction separated by "-" -> viewing angle is calculated from left to right value
-- and rounded up to the next angle for wich we have an icon.
--
   d1:=otm_vp_parseangle(split_part(intext,'-',1));
   d2:=otm_vp_parseangle(split_part(intext,'-',2));
   IF ((d1 IS NOT NULL) AND (d2 IS NOT NULL)) THEN
    a:=d2-d1;
    IF (a=0) THEN a:=360;   END IF;
    IF (a<0) THEN a:=a+360; END IF;
    IF     (a<=60  ) THEN d1:=d1-( 60-a)/2;a:=60;
    ELSEIF (a<=90  ) THEN d1:=d1-( 90-a)/2;a:=90;
    ELSEIF (a<=135 ) THEN d1:=d1-(135-a)/2;a:=135;
    ELSEIF (a<=180 ) THEN d1:=d1-(180-a)/2;a:=180;
    ELSEIF (a<=225 ) THEN d1:=d1-(225-a)/2;a:=225;
    ELSEIF (a<=270 ) THEN d1:=d1-(270-a)/2;a:=270;
    ELSEIF (a<=360 ) THEN d1:=0;           a:=360;
    END IF;
   END IF;
  END IF;
  IF (d1<0)    THEN d1:=d1+360; END IF;
  d2:=d1+a;
  IF (d2>=360) THEN d2:=d2-360; END IF;
  ret.s=d1;ret.e=d2;ret.a=a;
  RETURN ret;   
 END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION viewpointdirection(osmdirection IN TEXT) RETURNS otm_vp_twoviewranges AS $$
-- interprets osmdirection as number, cardinal direction or range of two numbers
-- returns otm_vp_twoviewranges with filled s1,e1,a1 and maybe also filled s2,e2,a2

 DECLARE
  ret    otm_vp_twoviewranges;
  range1 otm_vp_viewrange; 
  range2 otm_vp_viewrange;
  

 BEGIN
  ret.s1:=NULL;ret.s2:=NULL;ret.e1:=NULL;ret.e2:=NULL;ret.a1:=NULL;ret.a2:=NULL;
  osmdirection:=regexp_replace(LOWER(osmdirection),'[^a-z0-9;.,-]','','g');
--
-- simple cases: direction is NULL or empty: return a full circle from north to north
--               direction=360 is also interpreted as full circle
--
  IF     (osmdirection IS NULL) THEN ret.s1=0;ret.e1:=0;ret.a1:=360;
  ELSEIF (osmdirection='')      THEN ret.s1=0;ret.e1:=0;ret.a1:=360;
  ELSEIF (osmdirection='360')   THEN ret.s1=0;ret.e1:=0;ret.a1:=360;
--
-- One number, cardinal direction or a range of them, but not two ranges 
--
  ELSEIF (osmdirection NOT LIKE '%;%') THEN 
   range1=otm_vp_parserange(osmdirection);
   IF (range1.s IS NOT NULL) THEN
    ret.s1=range1.s;ret.e1:=range1.e;ret.a1:=range1.a;
   END IF;
  ELSE
--
-- Two ranges, separated by ";"
--
   range1=otm_vp_parserange(split_part(osmdirection,';',1));
   range2=otm_vp_parserange(split_part(osmdirection,';',2));
   IF (range1.s IS NOT NULL) THEN
    ret.s1=range1.s;ret.e1:=range1.e;ret.a1:=range1.a;
   END IF;
   IF (range2.s IS NOT NULL) THEN
    ret.s2=range2.s;ret.e2:=range2.e;ret.a2:=range2.a;
   END IF;
--
-- Do these two ranges overlap or the gap is smaller than 30°?
-- (maybe, because of mapping, maybe because we expand the ranges to the next available icon range) 
--
   IF((range1.s IS NOT NULL) AND (range2.s IS NOT NULL)) THEN
   END IF;
  END IF;
--
-- No parseable text
--
  IF (ret.s1 IS NULL)  THEN
   ret.s1=0;ret.e1:=360;ret.a1:=360;
  END IF;
  RETURN ret;
 END;
$$ LANGUAGE plpgsql;


select '90',     viewpointdirection('90');
select '270-85', viewpointdirection('270-85');
select 'NNW-S',  viewpointdirection('NNW-S');
select 'N;S', viewpointdirection('N;S');
select 'N;E', viewpointdirection('N;E');
select 'clockwise', viewpointdirection('clockwise');
select '0-100;ddd', viewpointdirection('0-100;ddd');
select '0-30;170-360',viewpointdirection('0-30;170-360');
select '0-30;180-w',viewpointdirection('0-30;170-0');


