/***********************************************************************************************************
* saddledirection -f /path/demfile [-r 100] [-d 0] [-n 24]                                                 *
*                                                                                                          *
* Calculates directions of saddles based on elevation data                                                 *
*                                                                                                          *
* For installation you need the GDAL-libraries (debian: package libgdal-dev)                               *
* Compiling with "cc -Wall -o saddledirection saddledirection.c -lgdal -lm"                                *
* Doku: https://wiki.openstreetmap.org/wiki/User:Maxbe/Satteldrehung_nach_H%C3%B6hendaten                  *
*                                                                                                          *
************************************************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include "gdal/gdal.h"
#include "gdal/cpl_conv.h"
#include "gdal/gdal_frmts.h"

/* the integer value which is returned if something goes wrong. Valid results are [0..179], so something
   negative seems to be good */

#define ERRORDIRECTION -135
#define PI             3.1415927

int debuglevel=0;


void printhelp(){
 printf("Usage:   saddledirection -f demfile [options]\n");
 printf("Options: -n steps (default=60, should be a divisor of 360 a multiple of 4)\n         -r radius (1-1000, default=100, unit=m)\n");
 printf("         -f demfile\n         -d debuglevel (0-4, default=0)\n         -o output format csv or sql (default csv)\n");
 printf("demfile ist a geotiff (1 band int16, SRS=EPSG 4326)\n");
 printf("stdin   is a csv with \"id;lon;lat;direction\" where direction is text (e.g. \"west\"), integer (e.g. 45 or -90) or empty\n");
 printf("stdout  is a csv with \"id;lon;lat;direction\" where direction is integer [0..179]\n");
 printf("If the direction can not be parsed, it is etimated with elevation data in radius r in \"steps\" steps.\nElevation data are taken from demfile.\n");
 printf("If it was not possible to estimate it, direction=%d will be returned\n",ERRORDIRECTION);
 printf("More documentation you will find in the OSM-Wiki: https://wiki.openstreetmap.org/wiki/User:Maxbe/Satteldrehung_nach_H%%C3%%B6hendaten\n\n");
}




double interpolate_height(int16_t ul,int16_t ur,int16_t ll,int16_t lr,double x,double y,double dx,double dy){
/* Interpolates height between (ul,ur,ll,lr) with distance righ-left=x and upper-lower=y. The point to be
   interpolatet is dx right to ul and ll and dy under ul and ur.
   Returns height or -32768, if one of the corners has void data                                           */
 
 double h;
 
 if((ul<-32000)||(ur<-32000)||(ll<-32000)||(lr<-32000)){
  h=-32786.0;
  if(debuglevel>1){printf("  Interpolation failed due to void data\n");}
 }else{
  h=1/(x*y)*( ll*(x-dx)*dy + lr*dx*dy + ul*(x-dx)*(y-dy) + ur*dx*(y-dy) );
  if(debuglevel>8){
   printf("  Interpolation   %4d   %4d\n",ul,ur);
   printf("                  %4d   %4d   dx/x=%lf dy/y=%lf -> h=%lf\n",ll,lr,dx/x,dy/y,h);
  }
 } 
 return h;
}


int interpolate_direction(double lon,double lat,double radius, int steps,double *adfGeoTransform,GDALRasterBandH hBand,long int xsize,long int ysize){
/* interpolates direction at lon/lat with elevation data from hBand (parameters in adfGeoTransform) using N steps in radius r */
/* returns direction oder ERRORDIRECTION, if something went wrong                                                             */

 long int   xpx,ypx,xpx_a=-1,ypx_a=-1;
 double     x,y,dx,dy,*h,*dh,dhmin;
 int16_t    area2x2[4];
 int        i,minstep,direction,goterror;

 direction=ERRORDIRECTION;
 goterror=0;
 h=malloc(steps*sizeof(double));
 dh=malloc(steps*sizeof(double));

/* creating a circle around lon/lat with radius r, inperpolate hight there */ 
 
 for(i=0;i<steps;i++){
  x=lon+radius*sin(i*(360/steps)*PI/180)*1/cos(lat*PI/180)*360/40000000;
  y=lat+radius*cos(i*(360/steps)*PI/180)*360/40000000;

 /* calculate upper left pixel next to x/y, get distance from this pixel as dx,dy  */

  xpx=(long int)floor((x-adfGeoTransform[0])/adfGeoTransform[1]);
  ypx=(long int)floor((y-adfGeoTransform[3])/adfGeoTransform[5]);
  dx= x-(adfGeoTransform[0]+xpx*adfGeoTransform[1]);
  dy=-y+(adfGeoTransform[3]+ypx*adfGeoTransform[5]);
    
/* read a 2x2 area from demfile at this pixel, so getting all 4 pixel next to lon/lat. interpolate hight there */
    
  if((!goterror)&&(xpx>0)&&(xpx<xsize-1)&&(ypx>0)&&(ypx<ysize-1)){
   if((i==0)||(xpx_a!=xpx)||(ypx_a!=ypx)){ 
    GDALRasterIO(hBand,GF_Read,xpx,ypx,2,2,area2x2,2,2,GDT_Int16,0,0);
    xpx_a=xpx;ypx_a=ypx;
    if(debuglevel>2){printf("  Getting x/y:%ld %ld at %lf %lf h=%d %d %d %d\n",xpx,ypx,adfGeoTransform[0]+xpx*adfGeoTransform[1],adfGeoTransform[3]+ypx*adfGeoTransform[5],area2x2[0],area2x2[1],area2x2[2],area2x2[3]);}
   }else{
    if(debuglevel>2){printf("  Still working with %ld %ld\n",xpx,ypx);}
   }
   h[i]=interpolate_height(area2x2[0],area2x2[1],area2x2[2],area2x2[3],adfGeoTransform[1],-adfGeoTransform[5],dx,dy);
   if(h[i]<-32000){goterror=1;}
   if(debuglevel>2){printf("   Step %d, x=%lf y=%lf h=%lf\n",i,x,y,h[i]);}
  }else{
   goterror=1;
   if(debuglevel>1){printf("  Got an error at %ld %ld\n",xpx,ypx);}
  }
 }

/* doing half of the circle once again and calculate +front+back-left-right. where this term is minimum there is the direction 
   If there are more than 24 steps, we do some smoothing                                                                       */

 if(!goterror){
  minstep=0;dhmin=100000000;
  for(i=0;i<steps/2;i++){
   if(i<steps/4){
    if(steps<=24){
     dh[i]= h[i] + h[(i+steps/2)%steps] - h[(i+steps/4)%steps] - h[(i+steps*3/4)%steps];
    }else{
     dh[i]=        (h[i] + h[(i+steps/2)%steps]      - h[(i+steps/4)%steps] - h[(i+steps*3/4)%steps]) 
            + 0.33*(h[i+1] + h[(i+1+steps/2)%steps]  - h[(i+1+steps/4)%steps] - h[(i+1+steps*3/4)%steps])
            + 0.14*(h[i+1] + h[(i+2+steps/2)%steps]  - h[(i+2+steps/4)%steps] - h[(i+2+steps*3/4)%steps]);
    }
    dh[i+steps/4]=-dh[i];
   } 
   if(debuglevel>4){printf("     at i=%d: dh=%lf dhmin=%lf min at %d\n",i,dh[i],dhmin,minstep);}
   if(dh[i]<dhmin){dhmin=dh[i];minstep=i;
    if(debuglevel>2){printf("   found min at i=%d\n",i);}
   }
  }
  direction=(minstep*360/steps+360)%180;
 }
 free(h);
 free(dh);
 if(goterror){direction=ERRORDIRECTION;}
 if(debuglevel>1){printf("       after trying estimation: dir=%d\n",direction);}
 return direction;
}


int parse_text(char *directionstring){
/* Interpretes directionstring as text, returns direction (0..179) or ERRORDIRECTION, if directionstring is not parseable */

int i,direction;

 direction=ERRORDIRECTION;
 for(i=0;directionstring[i];i++){directionstring[i]=tolower(directionstring[i]);}
 if      ((strcmp(directionstring,"north")==0)||(strcmp(directionstring,"south")==0)){direction=   0;}
 else if ((strcmp(directionstring,"west") ==0)||(strcmp(directionstring,"east") ==0)){direction=  90;}
 else if ((strcmp(directionstring,"nnw")  ==0)||(strcmp(directionstring,"sse")  ==0)){direction= 157;}
 else if ((strcmp(directionstring,"wnw")  ==0)||(strcmp(directionstring,"ese")  ==0)){direction= 112;}
 else if ((strcmp(directionstring,"wsw")  ==0)||(strcmp(directionstring,"ene")  ==0)){direction=  67;}
 else if ((strcmp(directionstring,"ssw")  ==0)||(strcmp(directionstring,"nne")  ==0)){direction=  22;}
 else if ((strcmp(directionstring,"nw")   ==0)||(strcmp(directionstring,"se")   ==0)){direction= 135;}
 else if ((strcmp(directionstring,"sw")   ==0)||(strcmp(directionstring,"ne")   ==0)){direction=  45;}
 else if ((strcmp(directionstring,"n")    ==0)||(strcmp(directionstring,"s")    ==0)){direction=   0;}
 else if ((strcmp(directionstring,"w")    ==0)||(strcmp(directionstring,"e")    ==0)){direction=  90;}
 if(debuglevel>1){printf("       after trying north/west/nnw/n: dir=%d\n",direction);}
 return direction;
}


int parse_number(char *directionstring){
/* Interpretes directionstring as number, returns direction (0..179) or ERRORDIRECTION, if directionstring is not parseable */

int i,direction;

 direction=ERRORDIRECTION;
 if(direction==ERRORDIRECTION){
 i=atoi(directionstring);
 if((i==0)&&(directionstring[0]!='0')){if(debuglevel>2){printf("       not a number\n");}}
 else {direction=(i+360)%180;}
 }
 if(debuglevel>1){printf("       after testing for numbers: dir=%d\n",direction);}
 return direction;
}




int main(int argc, char *argv[]){

 GDALDatasetH    hDataset;
 GDALRasterBandH hBand;
 double          adfGeoTransform[6];
 char            *demfile=NULL;
 char            *outputformat=NULL;
 char            *textrest;
 double          radius=100.0;
 int             steps=60;
 char            line[100],directionstring[100],returndirection[20];
 int             i,direction;
 long long int   id;
 double          lon,lat;

/* Parse command line parameters */

 if(argc<3){printhelp();exit(1);}
 for(i=1;i<=argc-2;i+=2){
  if     (strcmp(argv[i],"-d")==0){debuglevel=atoi(argv[i+1]);}
  else if(strcmp(argv[i],"-f")==0){demfile=argv[i+1];}          
  else if(strcmp(argv[i],"-n")==0){steps=atoi(argv[i+1]);while((steps%4)||(360%steps)){steps++;}}
  else if(strcmp(argv[i],"-r")==0){radius=strtod(argv[i+1],&textrest);}          
  else if(strcmp(argv[i],"-o")==0){outputformat=argv[i+1];}          
  else if(strcmp(argv[i],"-h")==0){printhelp();exit(0);}          
  else if(strcmp(argv[i],"-?")==0){printhelp();exit(0);}
 }   
 if(!demfile){printhelp();exit(1);}

/* open demfile, get srs, origin, pixel size and pointrer to the band 1 */

 GDALRegister_GTiff();
 hDataset = GDALOpen(demfile,GA_ReadOnly);
 if( hDataset == NULL ){
  fprintf(stderr,"Cannot open File %s\n",demfile);
  exit(1);
 }
 if( GDALGetGeoTransform( hDataset, adfGeoTransform ) == CE_None ){
  if(debuglevel>0){
   printf( "Reading %s %dpx x %dpx x %d band\n",demfile,GDALGetRasterXSize(hDataset),GDALGetRasterYSize(hDataset),GDALGetRasterCount(hDataset));
   printf( "Origin =(%.6f,%.6f) ",adfGeoTransform[0],adfGeoTransform[3]);
   printf( "Pixel Size=(%.6f,%.6f)\n",adfGeoTransform[1],adfGeoTransform[5]);
  }
  hBand=GDALGetRasterBand(hDataset,1);
 }else{
  fprintf(stderr,"Could not fetch transformation parameters from %s\n",demfile);
  exit(1);
 }

/* Read stdin, split each line in id,lon,lat,direction */

 while(fgets(line,100,stdin)){
  if(debuglevel>1){printf("\nInput: %s",line);}
  i=sscanf(line,"%lld;%lf;%lf;%s",&id,&lon,&lat,directionstring);
  if(i==3){directionstring[0]='\0';}
  strtok(directionstring,";\n");
  if(i<3){id=0;}
  if(debuglevel>1){printf("       id=%lld lon=%f lat=%f dir=%s\n",id,lon,lat,directionstring);}
  if(id){
 
/* Try to parse text as number / as string like "west, nnw, sw" / from elevation data */ 
 
   direction=parse_number(directionstring);
   if(direction==ERRORDIRECTION){direction=parse_text(directionstring);}
   if(direction==ERRORDIRECTION){direction=interpolate_direction(lon,lat,radius,steps,adfGeoTransform,hBand,GDALGetRasterXSize(hDataset),GDALGetRasterYSize(hDataset));}

   sprintf(returndirection,"%d",direction);
   if((!outputformat)||(strcmp(outputformat,"csv")==0)){printf("%lld;%.7lf;%.7lf;%s\n",id,lon,lat,returndirection);}
   else if(strcmp(outputformat,"sql")==0){
    printf("update planet_osm_point set direction='%s' where osm_id=%lld;\n",returndirection,id);
   }
  }
 }
 exit(0);
}

