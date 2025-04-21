

DROP   TYPE IF EXISTS otm_al_grid;
CREATE TYPE otm_al_grid AS 
 (x                      DOUBLE PRECISION, 
  y                      DOUBLE PRECISION,
  is_in_area             BOOLEAN,
  is_near_axis           BOOLEAN,
  dist_to_border         DOUBLE PRECISION,
  dist_to_middle         DOUBLE PRECISION,
  dist_to_start          DOUBLE PRECISION,
  way_to_middle          INTEGER,
  way_to_start           INTEGER
);


--
-- Thanks to Gabor Farkas
-- https://gis.stackexchange.com/questions/56835/how-to-perform-sia-or-bezier-line-smoothing-in-postgis
--
CREATE OR REPLACE FUNCTION OTM_CreateCurve(geom geometry, percent int DEFAULT 40) RETURNS geometry AS $$
DECLARE
    result text;
    p0 geometry;
    p1 geometry;
    p2 geometry;
    intp geometry;
    tempp geometry;
    geomtype text := ST_GeometryType(geom);
    factor double precision := percent::double precision / 200;
    i integer;
BEGIN
    IF percent < 0 OR percent > 100 THEN
        RAISE EXCEPTION 'Smoothing factor must be between 0 and 100';
    END IF;
    IF geomtype != 'ST_LineString' OR factor = 0 THEN
        RETURN geom;
    END IF;
    result := 'COMPOUNDCURVE((';
    p0 := ST_PointN(geom, 1);
    IF ST_NPoints(geom) = 2 THEN
        p1:= ST_PointN(geom, 2);
        result := result || ST_X(p0) || ' ' || ST_Y(p0) || ',' || ST_X(p1) || ' ' || ST_Y(p1) || '))';
    ELSE
        FOR i IN 2..(ST_NPoints(geom) - 1) LOOP
            p1 := ST_PointN(geom, i);
            p2 := ST_PointN(geom, i + 1);
            result := result || ST_X(p0) || ' ' || ST_Y(p0) || ',';
            tempp := ST_LineInterpolatePoint(ST_MakeLine(p1, p0), factor);
            p0 := ST_LineInterpolatePoint(ST_MakeLine(p1, p2), factor);
            intp := ST_LineInterpolatePoint(
                ST_MakeLine(
                    ST_LineInterpolatePoint(ST_MakeLine(p0, p1), 0.5),
                    ST_LineInterpolatePoint(ST_MakeLine(tempp, p1), 0.5)
                ), 0.5);
            result := result || ST_X(tempp) || ' ' || ST_Y(tempp) || '),CIRCULARSTRING(' || ST_X(tempp) || ' ' || ST_Y(tempp) || ',' || ST_X(intp) || ' ' ||
            ST_Y(intp) || ',' || ST_X(p0) || ' ' || ST_Y(p0) || '),(';
        END LOOP;
        result := result || ST_X(p0) || ' ' || ST_Y(p0) || ',' || ST_X(p2) || ' ' || ST_Y(p2) || '))';
        result:=ST_CurveToLine(result);
    END IF;
    RETURN ST_SetSRID(result::geometry, ST_SRID(geom));
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION arealabel(myosm_id IN BIGINT,myway IN GEOMETRY) RETURNS GEOMETRY AS $$
--
-- estimates a axis for a label through "myway"
-- used for water polygones
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
  targetpoint     otm_al_grid;
  gridwidth       DOUBLE PRECISION;
  gridheight      DOUBLE PRECISION;
  griddiag        DOUBLE PRECISION;
  maybehorizontal INTEGER:=0;
  lastindex       INTEGER;
  middleindex     INTEGER;
  startindex      INTEGER;
  endindex        INTEGER;
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
-- check for something like circles, sqares and rectangles in W-E-direction. 
-- (= any shape, wider than high or max 1.4x higher than wide and filling ists bbox>50%)
-- 
  IF (((((y/x)<1.4)) AND (ST_Area(myway)/(x*y)>0.5)) OR (x*y<10)) THEN
   maybehorizontal:=1;
   centroid=st_centroid(myway);
--
-- test if a simple horizontal line at the centroid is long enough
--
   IF (ST_Within(centroid,myway)) THEN
    x1:=ST_X(centroid);
    y:=ST_Y(centroid);
    WHILE  (ST_Within(ST_SetSRID(ST_MakePoint(x1+gridwidth/2,y),3857),ST_SetSRID(myway,3857))) LOOP
     x1:=x1+gridwidth/2;
    END LOOP;
    x:=ST_X(centroid);
    WHILE  (ST_Within(ST_SetSRID(ST_MakePoint(x-gridwidth/2,y),3857),ST_SetSRID(myway,3857))) LOOP
     x:=x-gridwidth/2;
    END LOOP;
    IF (((x1-x)/(xmax-xmin)>0.66) OR (x*y<10))  THEN
     areashape:='simple';
     retway=ST_SetSRID(ST_MakeLine(ST_MakePoint(x,y),ST_MakePoint(x1,y)),3857);
    END IF;
   END IF;
  END IF;


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
--
-- for horizontal: find the longest row in that grid, must be in the medium 1/2 of the area and at least 50% of the grid
--  
   i1:=0;j1:=0;m:=gridsize;g:=0;
   IF (maybehorizontal=1) THEN
    FOR j IN gridsize/2..(gridsize-2)*3/4 LOOP
     i:=1;
     WHILE NOT ((grid[i*gridsize+j].is_in_area) OR (i>gridsize-2)) LOOP i:=i+1; END LOOP;
     q=i;
     WHILE ((grid[i*gridsize+j].is_in_area) AND (i<=gridsize-1)) LOOP i:=i+1; END LOOP;
     r:=i-1;
     IF ((r-q>1) AND ((r-q>g) OR ((r-q=g) AND (ABS((j+1-(gridsize::FLOAT/2)))<m)))) THEN 
      g:=r-q;
      m:=ABS(j+1-(gridsize::FLOAT/2));
      startindex:=q*gridsize+j;
      endindex:=r*gridsize+j;
     END IF;
    END LOOP;
   END IF;
   IF (g>0.5*gridsize) THEN
    linestring:='LINESTRING(';
    gridpoint=grid[startindex];
    linestring:=linestring || gridpoint.x || ' ' || gridpoint.y || ',';
    gridpoint=grid[endindex];
    linestring:=linestring || gridpoint.x || ' ' || gridpoint.y || ')';
    retway:=ST_GeomFromText(linestring,3857);
    areashape:='horizontal';
   END IF;
--
-- Horizontal labels are done now
--
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
--
-- test, if a straight line from middle to this point is possible
--
    tmplinestring:='LINESTRING(';
    gridpoint=grid[startindex];
    tmplinestring:=tmplinestring || gridpoint.x || ' ' || gridpoint.y || ',';
    x1:=gridpoint.x;y1:=gridpoint.y;
    gridpoint=grid[middleindex];
    tmplinestring:=tmplinestring || gridpoint.x || ' ' || gridpoint.y || ')';
    x:=gridpoint.x;y:=gridpoint.y;
    x1:=(x1-x)/(gridsize);
    y1:=(y1-y)/(gridsize);
    tmpway:=ST_GeomFromText(tmplinestring,3857);
    tmppoint:=ST_SetSRID(ST_MakePoint(x,y),3857);
    IF (ST_Within(tmpway,ST_SetSRID(myway,3857)) AND ((x1!=0.0) OR (y1!=0.0))) THEN 
     tmppoint:=ST_SetSRID(ST_MakePoint(x-x1,y-y1),3857);
     WHILE (ST_Within(tmppoint,ST_SetSRID(myway,3857))) LOOP
      x:=x-x1;y:=y-y1;
      tmpway:=ST_AddPoint(tmpway,tmppoint);
      tmppoint:=ST_SetSRID(ST_MakePoint(x-x1,y-y1),3857);
     END LOOP;
     x:=ST_X(ST_EndPoint(tmpway))-ST_X(ST_StartPoint(tmpway));
     y:=ST_Y(ST_EndPoint(tmpway))-ST_Y(ST_StartPoint(tmpway));
--
-- test, if this line covers at least 3/4 of the bounding box (in any direction)
--
     p:=ABS(x/(xmax-xmin));
     m:=ABS(y/(ymax-ymin));
     IF (((p>0.75) OR (m>0.75)) AND ST_Within(ST_Buffer(tmpway,(x1+y1)/8,'endcap=flat'),ST_SetSRID(myway,3857))) THEN
      linestring:=ST_astext(tmpway);
      endindex:=middleindex;
      areashape:='diagonal';
      retway:=ST_GeomFromText(linestring,3857);
     END IF; 
    END IF;

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
-- Build linestring endindex to startindex
--
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
-- a modified arealabel(), used for natural polygones (mountain areas, valleys...) because these should not be labeled horizontal. 
-- First joice is a segment of a circle, second joice a path trough the area and at last a horizontal line.
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
-- Try to get a segment of a circle
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
   retway:=ST_SetSRID(ST_LineSubstring(otm_threepointcircle(xs,ys,xc,yc,xn,yn),0.2,0.8),3857);
  ELSE
   retway:=ST_SetSRID(ST_LineSubstring(otm_threepointcircle(xw,yw,xc,yc,xe,ye),0.2,0.8),3857);
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




--
-- Building hierarchy of areas
--

CREATE TYPE otm_natural_area_hierarchy AS (nextregionsize REAL,subregionsize REAL);

CREATE OR REPLACE FUNCTION OTM_Next_Natural_Area_Size(myosm_id IN BIGINT,myway_area REAL,myway IN GEOMETRY) RETURNS otm_natural_area_hierarchy AS $$
--
-- search for largest area inside myway and smallest area containing myway. Returns sizes of these areas
-- subregionsize=0 for "no subarea", nextregionsize=1e18 for "no larger area containing myway"
--
DECLARE
 verybigarea CONSTANT REAL := 1e18;
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
--
-- calculate with expanded and shrinked areas, to avoid problems with small overlaps
--
  IF(way_is_area) THEN
   IF(myway_area>1e9)      THEN shrinkway:=ST_Buffer(myway,-1000); expandway:=ST_Buffer(myway,1000);
    ELSIF (myway_area>1e8) THEN shrinkway:=ST_Buffer(myway,-100);  expandway:=ST_Buffer(myway,100);
    ELSIF (myway_area>1e5) THEN shrinkway:=ST_Buffer(myway,-20);   expandway:=ST_Buffer(myway,20);
   ELSE                         shrinkway:=myway;                  expandway:=ST_Buffer(myway,20);
   END IF;
  ELSE
   shrinkway:=ST_LineSubstring(myway,0.02,0.98);
   myway_area:=ST_Length(myway)*ST_Length(myway)/10;
  END IF;
--
-- get the smallest area which contains myway
--
  SELECT osm_id,name,way_area FROM planet_osm_polygon WHERE
   ST_contains(way,shrinkway) AND
   ("region:type" IN ('natural_area','mountain_area','mountain_range','basin') OR
    "natural" IN ('massif', 'mountain_range','basin','valley','couloir','ridge','arete','gorge','gully','canyon')) AND
   name IS NOT NULL AND way_area> myway_area AND osm_id != myosm_id
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
    ST_contains(expandway,way) AND
    ("region:type" IN ('natural_area','mountain_area','mountain_range','basin') OR
     "natural" IN ('massif', 'mountain_range','basin','valley','couloir','ridge','arete','gorge','gully','canyon')) AND
    name IS NOT NULL AND way_area<myway_area AND osm_id != myosm_id
   ORDER BY way_area DESC LIMIT 1 INTO polyresult;
   sub_size:=polyresult.way_area;
   IF sub_size IS NULL THEN sub_size:=0.0; END IF;
--
-- get the largest line located inside myway (but not lines with are also in osm_polygon)
--
   SELECT osm_id,name,ST_Length(way)*ST_Length(way)/10 as way_area FROM planet_osm_line AS li WHERE
    ST_contains(expandway,way) AND
    "natural" IN ('massif', 'mountain_range','basin','valley','couloir','ridge','arete','gorge','gully','canyon') AND
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



