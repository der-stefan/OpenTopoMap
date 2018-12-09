--
-- create a circle through 3 points, returns the shorter segment of this circle containg the first and third point
--
CREATE OR REPLACE FUNCTION otm_threepointcircle(x1 IN DOUBLE PRECISION,y1 IN DOUBLE PRECISION,x2 IN DOUBLE PRECISION,y2 IN DOUBLE PRECISION,x3 IN DOUBLE PRECISION,y3 IN DOUBLE PRECISION) RETURNS GEOMETRY AS $$
 DECLARE
  cx DOUBLE PRECISION;cy DOUBLE PRECISION;r DOUBLE PRECISION;
  d DOUBLE PRECISION;ws DOUBLE PRECISION;we DOUBLE PRECISION;wm DOUBLE PRECISION;w DOUBLE PRECISION;dw DOUBLE PRECISION;
  i INTEGER; tmpline GEOMETRY;retway GEOMETRY;
 BEGIN
  d:=2*(x1*(y2-y3)+x2*(y3-y1)+x3*(y1-y2));
  IF (d!=0.0) THEN
   cx:=((x1*x1+y1*y1)*(y2-y3)+(x2*x2+y2*y2)*(y3-y1)+(x3*x3+y3*y3)*(y1-y2))/d;
   cy:=((x1*x1+y1*y1)*(x3-x2)+(x2*x2+y2*y2)*(x1-x3)+(x3*x3+y3*y3)*(x2-x1))/d;
   r:=SQRT((x1-cx)*(x1-cx)+(y1-cy)*(y1-cy));
   ws:=ST_Azimuth(ST_MakePoint(cx,cy),ST_MakePoint(x1,y1));
   we:=ST_Azimuth(ST_MakePoint(cx,cy),ST_MakePoint(x3,y3));
   IF(ws>we) THEN wm:=ws;ws:=we;we:=wm; END IF;
   wm:=ST_Azimuth(ST_MakePoint(cx,cy),ST_MakePoint(x2,y2));
   IF (we-ws>3.1415927) THEN we:=we-2*3.1415927; END IF;
   dw:=(we-ws)/30;
   tmpline:=ST_MakeLine(ST_MakePoint(cx+r*sin(ws),cy+r*cos(ws)));
   FOR i IN 1..29 LOOP
    tmpline:=ST_AddPoint(tmpline,ST_MakePoint(cx+r*sin(ws+i*dw),cy+r*cos(ws+i*dw)));
   END LOOP;
   tmpline:=ST_AddPoint(tmpline,ST_MakePoint(cx+r*sin(we),cy+r*cos(we)));
   retway:=tmpline;
  ELSE
   tmpline:=ST_MakeLine(ST_MakePoint(x1,y1));
   tmpline:=ST_AddPoint(tmpline,ST_MakePoint(x3,y3));
   retway:=tmpline;
  END IF;
  RETURN retway;
 END;
$$ LANGUAGE plpgsql;


--
-- a modified arealabel(), because natural areas should not be labeled horizontal
--

CREATE OR REPLACE FUNCTION natural_arealabel(myosm_id IN BIGINT,myway IN GEOMETRY) RETURNS GEOMETRY AS $$
--
-- estimates a axis for a label through "myway"
--
 DECLARE
  bbox            GEOMETRY;
  tmpway          GEOMETRY;
  retway          GEOMETRY;
  smoothway       GEOMETRY;
  tmpbox          GEOMETRY;
  tmppoint        GEOMETRY;
  centroid        GEOMETRY;
  tmplinestring   VARCHAR;
  linestring      VARCHAR;
  t               VARCHAR;
  rname           TEXT;
  areashape       VARCHAR:='unknown';
  x               DOUBLE PRECISION;
  y               DOUBLE PRECISION;
  x1              DOUBLE PRECISION;
  y1              DOUBLE PRECISION;
  xmin            DOUBLE PRECISION;
  xmax            DOUBLE PRECISION;
  ymin            DOUBLE PRECISION;
  ymax            DOUBLE PRECISION;
  xe              DOUBLE PRECISION;
  xw              DOUBLE PRECISION;
  xn              DOUBLE PRECISION;
  xs              DOUBLE PRECISION;
  ye              DOUBLE PRECISION;
  yw              DOUBLE PRECISION;
  yn              DOUBLE PRECISION;
  ys              DOUBLE PRECISION;
  xc              DOUBLE PRECISION;
  yc              DOUBLE PRECISION;
  i               INTEGER;
  j               INTEGER;
  q               INTEGER;
  r               INTEGER;
  i1              INTEGER;
  j1              INTEGER;
  imin            INTEGER;
  jmin            INTEGER;
  imax            INTEGER;
  jmax            INTEGER;
  p               DOUBLE PRECISION;
  k               DOUBLE PRECISION;
  f               DOUBLE PRECISION;
  g               DOUBLE PRECISION;
  m               DOUBLE PRECISION;
  n               DOUBLE PRECISION;
  changes         INTEGER;
  done            INTEGER;
  gridsize        CONSTANT INTEGER:=25;
  grid            otm_al_grid[635];
  gridpoint       otm_al_grid;
  middlepoint     otm_al_grid;
  targetpoint     otm_al_grid;
  gridwidth       DOUBLE PRECISION;
  gridheight      DOUBLE PRECISION;
  griddiag        DOUBLE PRECISION;
  maybehorizontal INTEGER:=0;
  lastindex       INTEGER;
  middleindex     INTEGER;
  startindex      INTEGER;
  endindex        INTEGER;
  result          RECORD;
 BEGIN
--
-- get bounding box, adjust grid
--
  done=0;
  bbox:=ST_SetSRID(ST_Envelope(myway),3857);
  xmin:=ST_XMin(bbox);xmax:=ST_XMax(bbox);
  ymin:=ST_YMin(bbox);ymax:=ST_YMax(bbox);
  x=xmax-xmin;y:=ymax-ymin;
  gridwidth:=x/(gridsize-1);
  gridheight:=y/(gridsize-1);
  griddiag:=SQRT(gridwidth*gridwidth+gridheight*gridheight);
  retway:=NULL;
--
-- ZTry to get a segment of a circle
--
  centroid:=ST_Centroid(myway);
  IF (NOT ST_Within(centroid,myway)) THEN centroid:=ST_PointOnSurface(myway); END IF;
  xc:=ST_X(centroid);yc:=ST_Y(centroid);
  xe:=xc;xw:=xc;xn:=xc;xs:=xc;
  ye:=yc;yw:=yc;yn:=yc;ys:=yc;
  FOR result IN (SELECT(ST_DumpPoints(ST_Exteriorring(myway))).geom AS node) LOOP
   x:=ST_X(result.node);y:=ST_Y(result.node);
   IF((x<xc)AND((xc-x)*(xc-x)+(yc-y)*(yc-y)>(xc-xw)*(xc-xw)+(yc-yw)*(yc-yw))) THEN xw:=x;yw:=y; END IF;
   IF((x>xc)AND((xc-x)*(xc-x)+(yc-y)*(yc-y)>(xc-xe)*(xc-xe)+(yc-ye)*(yc-ye))) THEN xe:=x;ye:=y; END IF;
   IF((y>yc)AND((xc-x)*(xc-x)+(yc-y)*(yc-y)>(xc-xn)*(xc-xn)+(yc-yn)*(yc-yn))) THEN xn:=x;yn:=y; END IF;
   IF((y<yc)AND((xc-x)*(xc-x)+(yc-y)*(yc-y)>(xc-xs)*(xc-xs)+(yc-ys)*(yc-ys))) THEN xs:=x;ys:=y; END IF;
  END LOOP;
  IF ((xn-xs)*(xn-xs)+(yn-ys)*(yn-ys)>1.1*(xe-xw)*(xe-xw)+(ye-yw)*(ye-yw)) THEN
   retway:=ST_SetSRID(ST_LineSubstring(otm_threepointcircle(xs,ys,xc,yc,xn,yn),0.15,0.85),3857);
  ELSE
   retway:=ST_SetSRID(ST_LineSubstring(otm_threepointcircle(xw,yw,xc,yc,xe,ye),0.15,0.85),3857);
  END IF;
--
-- Check if at least 80% of the line is inside the area
--
  n:=ST_Length(retway);
  m:=ST_Length(ST_Intersection(retway,myway));
  IF(m/n<0.80)THEN retway:=NULL; END IF;
--
-- initialize grid point with coordinates, check which grid point is in the area
--
  IF ( retway IS NULL ) THEN
   x:=xmin;i:=0;j:=0;
   WHILE (x<=xmax) LOOP
    y:=ymin;j:=0;
    WHILE (y<=ymax) LOOP
     gridpoint.x=x;
     gridpoint.y=y;
     tmpbox:=ST_SetSRID(ST_Envelope(ST_MakeLine(ST_MakePoint(x-gridwidth/2,y-gridheight/2), ST_MakePoint(x+gridwidth/2,y+gridheight/2))),3857);
     gridpoint.is_in_area=ST_Within(tmpbox,ST_SetSRID(myway,3857));
     gridpoint.is_near_axis:=false;
     gridpoint.dist_to_border:=0;
     gridpoint.dist_to_middle:=0;
     gridpoint.way_to_middle:=0;
     gridpoint.dist_to_start:=0;
     gridpoint.way_to_start:=0;
     grid[i*gridsize+j]:=gridpoint;
     y:=y+gridheight;
     j:=j+1;
    END LOOP; 
    x:=x+gridwidth; 
    i:=i+1;
   END LOOP;  
--
-- calc distance to borders
--
   FOR i IN 1..(gridsize-2) LOOP
    FOR j IN 1..(gridsize-2) LOOP
     gridpoint=grid[i*gridsize+j];
     IF (gridpoint.is_in_area) THEN
      gridpoint.dist_to_border=LEAST(grid[(i-1)*gridsize+j].dist_to_border+gridwidth,grid[(i)*gridsize+(j-1)].dist_to_border+gridheight);
     END IF;
     grid[i*gridsize+j]:=gridpoint;
    END LOOP;
   END LOOP;
   FOR i IN REVERSE (gridsize-2)..1 LOOP
    FOR j IN REVERSE (gridsize-2)..1 LOOP
     gridpoint=grid[i*gridsize+j];
     IF (gridpoint.is_in_area) THEN
      gridpoint.dist_to_border=LEAST(gridpoint.dist_to_border,LEAST(grid[(i+1)*gridsize+j].dist_to_border+gridwidth,grid[(i)*gridsize+(j+1)].dist_to_border+gridheight));
     END IF;
     grid[i*gridsize+j]:=gridpoint;
    END LOOP;
   END LOOP;

   IF ( retway IS NULL ) THEN
--
-- mark points at a "slope" in all 4 directions
--
    middleindex:=0;p:=0;imin=gridsize;jmin=gridsize;imax:=-1;jmax:=-1;
    FOR i IN 1..(gridsize-2) LOOP
     FOR j IN 1..(gridsize-2) LOOP
      gridpoint=grid[i*gridsize+j];
      IF (gridpoint.is_in_area) THEN
       m:=1;n:=1;
       IF ((grid[(i-1)*gridsize+j].dist_to_border<=gridpoint.dist_to_border)AND(grid[(i+1)*gridsize+j].dist_to_border>gridpoint.dist_to_border))  THEN m:=0; END IF;
       IF ((grid[(i-1)*gridsize+j].dist_to_border>gridpoint.dist_to_border) AND(grid[(i+1)*gridsize+j].dist_to_border<=gridpoint.dist_to_border)) THEN m:=0; END IF; 
       IF ((grid[(i)*gridsize+j-1].dist_to_border<=gridpoint.dist_to_border)AND(grid[(i)*gridsize+j+1].dist_to_border>gridpoint.dist_to_border))  THEN n:=0; END IF;
       IF ((grid[(i)*gridsize+j-1].dist_to_border>gridpoint.dist_to_border) AND(grid[(i)*gridsize+j+1].dist_to_border<=gridpoint.dist_to_border)) THEN n:=0; END IF; 
       IF ((m=1)OR(n=1)) THEN
        gridpoint.is_near_axis:=true;
        if(imin>i) THEN imin:=i; END IF;
        if(jmin>j) THEN jmin:=j; END IF;
        if(imax<i) THEN imax:=i; END IF;
        if(jmax<j) THEN jmax:=j; END IF;
        grid[i*gridsize+j]:=gridpoint;
        IF (gridpoint.dist_to_border>p) THEN p:=gridpoint.dist_to_border;middleindex:=(i)*gridsize+j; END IF;
       END IF;
      END IF;
     END LOOP;
    END LOOP;
--
-- calc distance to the center point =(one of) the point(s) with the max dist to the border 
-- mark (one of the) node(s) with max. distance
-- the "distance" is not the lenght through the grid, but the straight line distance
--
    gridpoint=grid[middleindex];
    gridpoint.dist_to_middle:=1;
    grid[middleindex]:=gridpoint;
    startindex=middleindex;
    x:=gridpoint.x;y:=gridpoint.y;
    changes:=1;g:=0.0;m:=0.0;
    WHILE (changes>0) LOOP
      changes:=0;m:=m+1;
     FOR i IN imin..imax LOOP
      FOR j IN jmin..jmax LOOP
       gridpoint=grid[i*gridsize+j];
       IF ((gridpoint.is_near_axis) AND (gridpoint.dist_to_middle>0.0)) THEN
        FOR i1 IN (i-1)..(i+1) LOOP
         FOR j1 IN (j-1)..(j+1) LOOP
          IF ((i1!=i)OR(j1!=j)) THEN
           targetpoint:=grid[i1*gridsize+j1];
           IF (targetpoint.is_near_axis) THEN
            IF (j=j1) THEN f:=gridwidth; END IF;
            IF (i=i1) THEN f:=gridheight; END IF;
            IF ((i!=i1) AND (j!=j1)) THEN f:=griddiag ; END IF;
            IF ((targetpoint.dist_to_middle=0.0) OR (targetpoint.dist_to_middle>gridpoint.dist_to_middle+f)) THEN
             targetpoint.dist_to_middle:=gridpoint.dist_to_middle+f;
             targetpoint.way_to_middle:=i*gridsize+j;
             grid[i1*gridsize+j1]:=targetpoint;
             x1:=targetpoint.x; 
             y1:=targetpoint.y;
             p:=(x1-x)*(x1-x)+(y1-y)*(y1-y);
             IF (p>g) THEN g:=p;startindex:=i1*gridsize+j1; END IF;
             changes:=changes+1;
            END IF; 
           END IF;
          END IF;
         END LOOP;
        END LOOP; 
       END IF;
      END LOOP;
     END LOOP;
     FOR i IN REVERSE imax..imin LOOP
      FOR j IN REVERSE jmax..jmin LOOP
       gridpoint=grid[i*gridsize+j];
       IF ((gridpoint.is_near_axis) AND (gridpoint.dist_to_middle>0.0)) THEN
        FOR i1 IN (i-1)..(i+1) LOOP
         FOR j1 IN (j-1)..(j+1) LOOP
          IF ((i1!=i)OR(j1!=j)) THEN
           targetpoint:=grid[i1*gridsize+j1];
           IF (targetpoint.is_near_axis) THEN
            IF (j=j1) THEN f:=gridwidth; END IF;
            IF (i=i1) THEN f:=gridheight; END IF;
            IF ((i!=i1) AND (j!=j1)) THEN f:=griddiag ; END IF;
            IF ((targetpoint.dist_to_middle=0.0) OR (targetpoint.dist_to_middle>gridpoint.dist_to_middle+f)) THEN
             targetpoint.dist_to_middle:=gridpoint.dist_to_middle+f;
             targetpoint.way_to_middle:=i*gridsize+j;
             grid[i1*gridsize+j1]:=targetpoint;
             x1:=targetpoint.x; 
             y1:=targetpoint.y; 
             p:=(x1-x)*(x1-x)+(y1-y)*(y1-y);
             IF (p>g) THEN g:=p;startindex:=i1*gridsize+j1; END IF;
             changes:=changes+1;
            END IF; 
           END IF;
          END IF;
         END LOOP;
        END LOOP; 
       END IF;
      END LOOP;
     END LOOP;
    END LOOP;
    IF (retway IS NULL) THEN
--
-- calc distance to the start point, mark (one of the) node(s) with max. distance
-- the "distance" is not the lenght through the grid, but the straight line distance
--
     gridpoint=grid[startindex];
     gridpoint.dist_to_start:=1;
     grid[startindex]:=gridpoint;
     changes:=1;g:=0.0;m:=0.0;p:=0;x:=gridpoint.x;y:=gridpoint.y;
     WHILE (changes>0) LOOP
      changes:=0;m:=m+1;
      FOR i IN imin..imax LOOP
       FOR j IN jmin..jmax LOOP
        gridpoint=grid[i*gridsize+j];
        IF ((gridpoint.is_near_axis) AND (gridpoint.dist_to_start>0.0)) THEN
         FOR i1 IN (i-1)..(i+1) LOOP
          FOR j1 IN (j-1)..(j+1) LOOP
           IF ((i1!=i)OR(j1!=j)) THEN
            targetpoint:=grid[i1*gridsize+j1];
            IF (targetpoint.is_near_axis) THEN
             IF (j=j1) THEN f:=gridwidth; END IF;
             IF (i=i1) THEN f:=gridheight; END IF;
             IF ((i!=i1) AND (j!=j1)) THEN f:=griddiag ; END IF;
             IF ((targetpoint.dist_to_start=0.0) OR (targetpoint.dist_to_start>gridpoint.dist_to_start+f)) THEN
              targetpoint.dist_to_start:=gridpoint.dist_to_start+f;
              targetpoint.way_to_middle:=i*gridsize+j;
              grid[i1*gridsize+j1]:=targetpoint;
              x1:=targetpoint.x;
              y1:=targetpoint.y;
              p:=(x1-x)*(x1-x)+(y1-y)*(y1-y);
              if(p>g) THEN g:=p;endindex:=i1*gridsize+j1; END IF;
              changes:=changes+1;
             END IF; 
            END IF;
           END IF;
          END LOOP;
         END LOOP; 
        END IF;
       END LOOP;
      END LOOP;
      FOR i IN REVERSE imax..imin LOOP
       FOR j IN REVERSE jmax..jmin LOOP
        gridpoint=grid[i*gridsize+j];
        IF ((gridpoint.is_near_axis) AND (gridpoint.dist_to_start>0.0)) THEN
         FOR i1 IN (i-1)..(i+1) LOOP
          FOR j1 IN (j-1)..(j+1) LOOP
           IF ((i1!=i)OR(j1!=j)) THEN
            targetpoint:=grid[i1*gridsize+j1];
            IF (targetpoint.is_near_axis) THEN
             IF (j=j1) THEN f:=gridwidth; END IF;
             IF (i=i1) THEN f:=gridheight; END IF;
             IF ((i!=i1) AND (j!=j1)) THEN f:=griddiag ; END IF;
             IF ((targetpoint.dist_to_start=0.0) OR (targetpoint.dist_to_start>gridpoint.dist_to_start+f)) THEN
              targetpoint.dist_to_start:=gridpoint.dist_to_start+f;
              targetpoint.way_to_middle:=i*gridsize+j;
              grid[i1*gridsize+j1]:=targetpoint;
              x1:=targetpoint.x;
              y1:=targetpoint.y;
              p:=(x1-x)*(x1-x)+(y1-y)*(y1-y);
              if(p>g) THEN g:=p;endindex:=i1*gridsize+j1; END IF;
              changes:=changes+1;
             END IF; 
            END IF;
           END IF;
          END LOOP;
         END LOOP; 
        END IF;
       END LOOP;
      END LOOP;
     END LOOP;
--
-- Get the minimum bounding circle for start/end/middle point
--
--    retway:=ST_SetSRID(otm_threepointcircle(grid[startindex].x,grid[startindex].y,ST_X(ST_Centroid(myway)),ST_Y(ST_Centroid(myway)),grid[endindex].x,grid[endindex].y),3857);
--    if (NOT ST_Within(retway,myway)) THEN
--     retway:=NULL;    
--    END IF;
--
-- Build linestring endindex to startindex
--
     IF ( retway IS NULL ) THEN
      i:=endindex;
      linestring:='LINESTRING(';
      WHILE (i!=startindex) LOOP
       gridpoint=grid[i];
       linestring:=linestring || gridpoint.x || ' ' || gridpoint.y || ',';
       i:=gridpoint.way_to_middle;
      END LOOP;
      gridpoint=grid[i];
      linestring:=linestring || gridpoint.x || ' ' || gridpoint.y || ')';
--
-- smooth line
-- 
      tmpway:=ST_GeomFromText(linestring,3857);
      IF (ST_NPoints(tmpway)>3) THEN
       tmppoint:=ST_PointN(tmpway,1);
       FOR i in 2..(ST_NPoints(tmpway)-1) LOOP
        x:=(ST_X(ST_PointN(tmpway,i-1))+ST_X(ST_PointN(tmpway,i))+ST_X(ST_PointN(tmpway,i+1)))/3;
        y:=(ST_Y(ST_PointN(tmpway,i-1))+ST_Y(ST_PointN(tmpway,i))+ST_Y(ST_PointN(tmpway,i+1)))/3;
        IF (i=2) THEN 
         smoothway:=ST_MakeLine(tmppoint,ST_SetSRID(ST_Point(x,y),3857));
        ELSE 
         smoothway:=ST_AddPoint(smoothway,ST_SetSRID(ST_Point(x,y),3857));
        END IF;
       END LOOP; 
       x:=ST_X(ST_PointN(tmpway,ST_NPoints(tmpway)));
       y:=ST_Y(ST_PointN(tmpway,ST_NPoints(tmpway)));
       smoothway:=ST_AddPoint(smoothway,ST_SetSRID(ST_Point(x,y),3857));
       smoothway:=OTM_CreateCurve(smoothway,90);
       retway:=smoothway;
       areashape:='curve';
       done:=1;
      END IF;
     END IF;
    END IF;
   END IF;
  END IF;
--
-- If all failed, get ST_PointOnSurface and draw a horizontal line to the borders, overlap 
-- max. 1 gridwidth
--
  IF ( retway IS NULL ) THEN
   tmppoint:=ST_PointOnSurface(ST_SetSRID(myway,3857));
   IF NOT ST_IsEmpty(tmppoint) THEN
    y:=ST_Y(tmppoint);
    x:=ST_X(tmppoint)-gridwidth;
    tmppoint:=ST_SetSRID(ST_MakePoint(x,y),3857);
    WHILE (ST_Within(tmppoint,ST_SetSRID(myway,3857))) LOOP
     x:=x-gridwidth;
     tmppoint:=ST_SetSRID(ST_MakePoint(x,y),3857);
    END LOOP;
    tmpway:=ST_MakeLine(tmppoint);
    tmppoint:=ST_PointOnSurface(ST_SetSRID(myway,3857));
    y:=ST_Y(tmppoint);
    x:=ST_X(tmppoint)+gridwidth;
    tmppoint:=ST_SetSRID(ST_MakePoint(x,y),3857);
    WHILE (ST_Within(tmppoint,ST_SetSRID(myway,3857))) LOOP
     x:=x+gridwidth;
     tmppoint:=ST_SetSRID(ST_MakePoint(x,y),3857);
    END LOOP;
    tmpway:=ST_AddPoint(tmpway,tmppoint);
    retway:=tmpway;
    areashape:='fallback';
   ELSE 
    retway:=NULL;
   END IF;
  END IF;
  RETURN retway;
 END;
$$ LANGUAGE plpgsql;




-- ------------------------------------------------------------------------------------


--
-- Building hierarchy of areas
--


CREATE TYPE otm_natural_area_hierarchy AS (nextregionsize REAL,subregionsize REAL);

CREATE OR REPLACE FUNCTION OTM_Next_Natural_Area_Size(myosm_id IN BIGINT,myway_area REAL,myway IN GEOMETRY) RETURNS otm_natural_area_hierarchy AS $$
DECLARE
 verybigarea CONSTANT REAL := 1e15;
 shrinkway   GEOMETRY;
 expandway   GEOMETRY;
 next_size   REAL;
 sub_size    REAL;
 polyresult  RECORD;
 lineresult  RECORD;
 ret         otm_natural_area_hierarchy;
 way_is_area BOOLEAN := true;
 
 BEGIN
  IF ((ST_GeometryType(myway)='ST_LineString')OR(ST_GeometryType(myway)='ST_MultiLineString')) THEN way_is_area:=false; END IF;
  IF(way_is_area) THEN
   if(way_is_area>100000) THEN shrinkway:=ST_Buffer(myway,-20); 
   ELSE                        shrinkway:=myway;
   expandway:=ST_Buffer(myway,20);
  ELSE
   shrinkway:=ST_LineSubstring(myway,0.02,0.98);
   myway_area:=ST_Length(myway)*ST_Length(myway)/10;
  END IF;
--
-- get the smallest area which contains myway
--
  SELECT osm_id,name,way_area FROM planet_osm_polygon WHERE
   ST_Contains (way,shrinkway) AND
   ("region:type" IN ('natural_area','mountain_area') OR
    "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
   name IS NOT NULL AND
   way_area> myway_area AND
   osm_id != myosm_id
  ORDER BY way_area ASC LIMIT 1 INTO polyresult;
  next_size:=polyresult.way_area;
  IF next_size IS NULL THEN next_size:=verybigarea; END IF;
--
-- If myway is an area also serch for areas and lines inside it (lines do not have subareas)
--
  IF(way_is_area) THEN
--
-- get the largest area located inside myway
--
   SELECT osm_id,name,way_area FROM planet_osm_polygon WHERE
    ST_Contains (expandway,way) AND
    ("region:type" IN ('natural_area','mountain_area') OR
     "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
    name IS NOT NULL AND
    way_area<myway_area AND
    osm_id != myosm_id
   ORDER BY way_area DESC LIMIT 1 INTO polyresult;
   sub_size:=polyresult.way_area;
   IF sub_size IS NULL THEN sub_size:=0.0; END IF;
--
-- get the largest line located inside myway (but not lines with are also in osm_polygon)
--
   SELECT osm_id,name,ST_Length(way)*ST_Length(way)/10 as way_area FROM planet_osm_line AS li WHERE
    ST_Contains (expandway,way) AND
    "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete') AND
    name IS NOT NULL AND
    NOT EXISTS (SELECT osm_id FROM planet_osm_polygon AS po WHERE po.osm_id=li.osm_id )
   ORDER BY way_area DESC LIMIT 1 INTO lineresult;
   IF lineresult.way_area IS NOT NULL AND lineresult.way_area>sub_size THEN
    sub_size:=lineresult.way_area;
   END IF;
  ELSE 
   sub_size:=0.0;   
  END IF;
  ret.nextregionsize:=next_size;
  ret.subregionsize:=sub_size;
  RETURN ret;
 END;
$$ LANGUAGE plpgsql;

  

DROP VIEW lowzoom_natural_areas;
CREATE VIEW lowzoom_natural_areas AS 
 SELECT natural_arealabel(osm_id,way) as way,name,areatype,way_area,(hierarchicregions).nextregionsize AS nextregionsize,(hierarchicregions).subregionsize AS subregionsize FROM
  (SELECT osm_id,way,name,(CASE WHEN "natural" IS NOT NULL THEN "natural" ELSE "region:type" END) AS areatype,
    way_area,
    OTM_Next_Natural_Area_Size(osm_id,way_area,way) AS hierarchicregions FROM planet_osm_polygon WHERE 
     ("region:type" IN ('natural_area','mountain_area') OR
      "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
      name IS NOT NULL) AS natural_areas;

DROP VIEW lowzoom_natural_lines;
CREATE VIEW lowzoom_natural_lines AS
 SELECT way,name,areatype,way_area,(hierarchicregions).nextregionsize AS nextregionsize,(hierarchicregions).subregionsize AS subregionsize FROM
  (SELECT osm_id,way,name,"natural" AS areatype,ST_Length(way)*ST_Length(way)/10 as way_area, 
   OTM_Next_Natural_Area_Size(osm_id,0.0,way) AS hierarchicregions FROM planet_osm_line AS li WHERE
    "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete') AND
    name IS NOT NULL AND NOT EXISTS (SELECT osm_id FROM planet_osm_polygon AS po WHERE po.osm_id=li.osm_id )) AS natural_lines;


  SELECT st_geometrytype(natural_arealabel(osm_id,way)) as waytype,osm_id,name,(CASE WHEN "natural" IS NOT NULL THEN "natural" ELSE "region:type" END) AS areatype,
    way_area,
    OTM_Next_Natural_Area_Size(osm_id,way_area,way) AS hierarchicregions FROM planet_osm_polygon WHERE 
     ("region:type" IN ('natural_area','mountain_area') OR
      "natural" IN ('massif', 'mountain_range', 'valley','couloir','ridge','arete')) AND
      (name='Ortleralpen' OR name='Silvretta' or name='Venedigergruppe' or name='Kaunergrat');

  SELECT st_geometrytype(natural_arealabel(osm_id,way)) as waytype,osm_id,name,(CASE WHEN "natural" IS NOT NULL THEN "natural" ELSE "region:type" END) AS areatype,
    way_area,
    OTM_Next_Natural_Area_Size(osm_id,way_area,way) AS hierarchicregions FROM planet_osm_polygon WHERE 
     osm_id=137200627;



