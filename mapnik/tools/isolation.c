/************************************************************************************************************
* isolation -f /path/demfile [-d 0] [-r 100000]                                                             *
*                                                                                                           *
* Calculates topographic isolation of peaks based on elevation data                                         *
* Doc: https://wiki.openstreetmap.org/wiki/User:Maxbe/Dominanz_von_Gipfeln                                  *
*                                                                                                           *
* For installation you need the GDAL-libraries (debian: package libgdal-dev)                                *
* Compiling with "cc -Wall -o isolation isolation.c -lgdal -lm -O2"                                         *
*                                                                                                           *
************************************************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <math.h>
#include "gdal/gdal.h"
#include "gdal/cpl_conv.h"
#include "gdal/gdal_frmts.h"

struct list_peak{
 long long int    id;
 long long int    heigherpeak_id;
 double           heigherpoint_lon,heigherpoint_lat;
 double           lon,lat,ele,isolation;
};    
  
   

#define PI             3.1415927
/* min isolation of a peak */
#define MINISO         100
/* difference between the heigts of DEM and peak to define a isolation */
#define MINDIFF         20


int    debuglevel=0;
time_t starttime;


void printhelp(){
 printf("Usage:   isolation -f demfile [options]\n");
 printf("         -f demfile\n         -d debuglevel (0-4, default=0)\n");
 printf("         -n maximal number of peaks (default 2000000)\n");
 printf("         -r maximal search radius (100..500000,default 100000)\n");
 printf("         -o output format csv or sql (default csv)\n");
 printf("demfile is a geotiff (1 band int16, SRS=EPSG 4326)\n");
 printf("stdin   is a csv with \"id;lon;lat;ele\" where \n");
 printf("         ele is integer, float or empty (not mixed like \"1234m\")\n");
 printf("stdout  is a csv with \"id;lon;lat;isolation\", where\n");
 printf("         isolation is integer [0..radius]\n");
 printf("More documentation you will find in the OSM-Wiki:\n\n");
}

int compare_function(const void *a,const void *b) {
/* helper function for sorting peaks by latitude */
 struct list_peak *x = (struct list_peak *) a;
 struct list_peak *y = (struct list_peak *) b;
 if(y->lat < x->lat) return 1;
 if(y->lat > x->lat) return -1;
 return 0;
}

double checkele(char *elestring){
/* sanitize ele: substitute "," by ".", ignore "m", convert "ft" to meter, check if ele >> Mount Everest */
/* returns ele or -32000                                                                                 */
 char   *textrest;
 double ele;
 int    i,eleok;

 ele=-32000.0;eleok=1;
 if(elestring[0]!='\0'){
  i=0;while(elestring[i]){if(elestring[i]==','){elestring[i]='.';}i++;}
  ele=strtod(elestring,&textrest);
  if(textrest[0]!='\0'){
   eleok=0;
   if((strcmp(textrest,"m") ==0)||(strcmp(textrest," m") ==0)){eleok=1;}
   if((strcmp(textrest,"ft")==0)||(strcmp(textrest," ft")==0)){ele=ele*0.3048;eleok=1;}
  }
  if((!eleok)||(ele>9000.0)||(ele<-12000.0)){ele=-32000.0;}
 }else{ele=-32000.0;}
 return ele;
}



double get_height(double lon,double lat,double *adfGeoTransform,GDALRasterBandH hBand,long int xsize,long int ysize){
/* get height at lon/lat with elevation data from hBand (parameters in adfGeoTransform) */

 long int   xpx,ypx;
 double     h;
 int16_t    *area2x2;

 /* calculate upper left pixel next to lon/lat  */

 xpx=(long int)floor((lon-adfGeoTransform[0])/adfGeoTransform[1]);
 ypx=(long int)floor((lat-adfGeoTransform[3])/adfGeoTransform[5]);
    
/* read a 2x2 area from demfile at this pixel, so getting all 4 pixel next to lon/lat  */
/* take the max. height from these 4 values                                            */
 
 area2x2=malloc(4*sizeof(int16_t));
 GDALRasterIO(hBand,GF_Read,xpx,ypx,2,2,area2x2,2,2,GDT_Int16,0,0);
 if(debuglevel>3){printf("  Getting x/y:%ld %ld at %lf %lf h=%d %d %d %d\n",xpx,ypx,adfGeoTransform[0]+xpx*adfGeoTransform[1],adfGeoTransform[3]+ypx*adfGeoTransform[5],area2x2[0],area2x2[1],area2x2[2],area2x2[3]);}
 h=area2x2[0];
 if(area2x2[1]>h){h=area2x2[1];}
 if(area2x2[2]>h){h=area2x2[2];}
 if(area2x2[3]>h){h=area2x2[3];}
 free(area2x2);
 if(h<-32000){h=0.0;}
 return h;
}


void get_isolation_by_ele(struct list_peak *peak,long int numpeaks,double radius){
/* gets a list of peaks, calculate distance of each peak to each other in area of radius, returns nothing */

 long int i,j;
 double   ccos,d,dx,dy;
    
 
 for(i=0;i<numpeaks;i++){
  ccos=cos(peak[i].lat*PI/180);
  if(debuglevel>2){printf("calc dist for peak %lld\n",peak[i].id);}
  for(j=i+1;j<numpeaks;j++){
   dy=(peak[j].lat-peak[i].lat)*40000000/360;
   if(debuglevel>3){printf("   compare with other peak %lld\n",peak[j].id);}
   if(dy<radius){
    dx=(peak[j].lon-peak[i].lon)*ccos*40000000/360;
    d=sqrt(dx*dx+dy*dy);
    if(d>radius){d=radius;}
    if(debuglevel>3){printf("   compare with other peak %lld, d=%f\n",peak[j].id,d);}
    if((d < peak[j].isolation)&&(peak[i].ele > peak[j].ele)){
     peak[j].isolation=d;
     peak[j].heigherpeak_id=peak[i].id;
     peak[j].heigherpoint_lon=peak[i].lon;
     peak[j].heigherpoint_lat=peak[i].lat;
     if(debuglevel>3){printf("   assign isolation to other peak %lld, d=%f\n",peak[j].id,d);}
    }
    if((d < peak[i].isolation)     &&(peak[i].ele < peak[j].ele)){
     peak[i].isolation=d;
     peak[i].heigherpeak_id=peak[j].id;
     peak[i].heigherpoint_lon=peak[j].lon;
     peak[i].heigherpoint_lat=peak[j].lat;
     if(debuglevel>3){printf("   found higher peak %lld for peak %lld, d=%f\n",peak[j].id,peak[i].id,d);}
    }
   }else{
    j=numpeaks+1;
   }
  }
 }
}


void get_isolation_by_DEM(struct list_peak *peak,long int numpeaks,double radius,double *adfGeoTransform,GDALDatasetH hDataset,GDALRasterBandH hBand,long int xsize,long int ysize){
/* gets a list of peaks, calculate isolation of each peak, returns nothing */

 long int  i,up,le,ri,dw,w,h,maxw,maxh,x,y;
 double    d,r,rx,ry;
 double    ccos;
 int16_t   *DEMarea;
 
 
 maxw=GDALGetRasterXSize(hDataset);
 maxh=GDALGetRasterYSize(hDataset);
 
 for(i=0;i<numpeaks;i++){
  r=peak[i].isolation;
  if(r<MINISO){r=MINISO;}
  ccos=cos(peak[i].lat*PI/180);
 
/* calc up/le and dw/ri corner of an rectangular area with diameter 2r around each peak */ 
  
  le=(long int)floor((peak[i].lon-r*(1/ccos)*360/40000000-adfGeoTransform[0])/adfGeoTransform[1]);
  ri=(long int) ceil((peak[i].lon+r*(1/ccos)*360/40000000-adfGeoTransform[0])/adfGeoTransform[1]);
  up=(long int)floor((peak[i].lat+r*360/40000000-adfGeoTransform[3])/adfGeoTransform[5]);
  dw=(long int) ceil((peak[i].lat-r*360/40000000-adfGeoTransform[3])/adfGeoTransform[5]); 
  if(le<0){le=0;}
  if(up<0){up=0;}
  if(ri>=maxw){ri=maxw-1;}
  if(dw>=maxh){dw=maxh-1;} 
  w=ri-le;h=dw-up;
  
/* get all DEM values in this area */  
  
  DEMarea=malloc((w)*(h)*sizeof(int16_t));
  GDALRasterIO(hBand,GF_Read,le,up,w,h,DEMarea,w,h,GDT_Int16,0,0); 
  if(debuglevel>2){printf("calc isolation for peak %lld iso=%.7lf (%ld %ld points) le=%ld ri=%ld  dw=%ld up=%ld\n",peak[i].id,r,w,h,le,ri,dw,up);}

/* search for DEM values higher than that peak */

  for(y=up;y<dw;y++){
   for(x=le;x<ri;x++){
    if(DEMarea[(x-le)+(y-up)*w]>peak[i].ele+MINDIFF){ 
     rx=(peak[i].lon-(adfGeoTransform[0]+adfGeoTransform[1]*x))*40000000/360*ccos;
     ry=(peak[i].lat-(adfGeoTransform[3]+adfGeoTransform[5]*y))*40000000/360;
     d=sqrt(rx*rx+ry*ry);
     if(debuglevel>3){printf(" testing DEM at %ld %ld h=%d d=%f lat=%f lon=%f\n",x-le,y-up,DEMarea[(x-le)+(y-up)*w],d,adfGeoTransform[3]+adfGeoTransform[5]*y,adfGeoTransform[0]+adfGeoTransform[1]*x);}
     if((d>MINISO)&&(d<peak[i].isolation)){
      peak[i].isolation=d;
      peak[i].heigherpoint_lon=adfGeoTransform[0]+adfGeoTransform[1]*x;
      peak[i].heigherpoint_lat=adfGeoTransform[3]+adfGeoTransform[5]*y;
      if(debuglevel>3){printf(" found higher DEM at %ld %ld h=%d d=%f lat=%f lon=%f\n",x-le,y-up,DEMarea[(x-le)+(y-up)*w],d,peak[i].heigherpoint_lat,peak[i].heigherpoint_lon);}
     }
    }
   }
  }
  free(DEMarea);
 }
}





int main(int argc, char *argv[]){

 GDALDatasetH     hDataset;
 GDALRasterBandH  hBand;
 double           adfGeoTransform[6];
 char             *demfile=NULL;
 char             *outputformat=NULL;
 char             *textrest=NULL;
 double           radius=100000.0;
 char             line[100],elestring[100];
 long long int    id;
 long int         n=0,i=0,st_s=0,st_g=0,maxnumpeaks=2000000,numpeaks=0;
 double           lon,lat,ele;
 struct list_peak *peak;

/* Parse command line parameters */

 starttime=time(NULL);
 if(argc<3){printhelp();exit(1);}
 for(i=1;i<=argc-2;i+=2){
  if     (strcmp(argv[i],"-d")==0){debuglevel=atoi(argv[i+1]);}
  else if(strcmp(argv[i],"-f")==0){demfile=argv[i+1];}          
  else if(strcmp(argv[i],"-r")==0){radius=strtod(argv[i+1],&textrest);}
  else if(strcmp(argv[i],"-n")==0){maxnumpeaks=strtod(argv[i+1],&textrest);}
  else if(strcmp(argv[i],"-o")==0){outputformat=argv[i+1];}          
  else if(strcmp(argv[i],"-h")==0){printhelp();exit(0);}          
  else if(strcmp(argv[i],"-?")==0){printhelp();exit(0);}
 }   
 if(!demfile){printhelp();exit(1);}
 if(radius<100){radius=100;}
 if(radius>500000){radius=500000;}

 peak=malloc(sizeof(struct list_peak)*maxnumpeaks); 
 if(!peak){
  fprintf(stderr,"Not enough memory for %ld peaks\n",maxnumpeaks);
  exit(1);
 }

/* open demfile, get srs, origin, pixel size and pointer to the band 1 */

 GDALRegister_GTiff();
 hDataset = GDALOpen(demfile,GA_ReadOnly);
 if( hDataset == NULL ){
  fprintf(stderr,"Cannot open File %s\n",demfile);
  exit(1);
 }
 if( GDALGetGeoTransform( hDataset, adfGeoTransform ) == CE_None ){
  if(debuglevel>0){
   printf( "%ld Reading %s %dpx x %dpx x %d band\n",time(NULL)-starttime,demfile,GDALGetRasterXSize(hDataset),GDALGetRasterYSize(hDataset),GDALGetRasterCount(hDataset));
   printf( "Origin =(%.6f,%.6f) ",adfGeoTransform[0],adfGeoTransform[3]);
   printf( "Pixel Size=(%.6f,%.6f)\n",adfGeoTransform[1],adfGeoTransform[5]);
  }
  hBand=GDALGetRasterBand(hDataset,1);
 }else{
  fprintf(stderr,"Could not fetch transformation parameters from %s\n",demfile);
  exit(1);
 }

/* Read stdin, split each line in id,lon,lat,ele */

 while(fgets(line,100,stdin)){
  i=sscanf(line,"%lld;%lf;%lf;%[^\n]",&id,&lon,&lat,elestring);
  if(i==3){elestring[0]='\0';}
  strtok(elestring,";\n");
  ele=checkele(elestring);

/* If ele is not parseable, get it from DEMfile... */

  if((ele<=-32000.0)){
   ele=get_height(lon,lat,adfGeoTransform,hBand,GDALGetRasterXSize(hDataset),GDALGetRasterYSize(hDataset));
   elestring[0]='\0';
   st_s++;
   if(debuglevel>2){
    printf("\nInput: %s",line);
    printf(" -> ele: id=%lld lon=%f lat=%f ele=%f\n",id,lon,lat,ele);
   }
  }
  if(i<3){id=0;}
 
/* Append peak to array of peaks */  
  
  if(id){
   if(n>maxnumpeaks){
    fprintf(stderr,"Too many peaks: %ld\n",n);
    exit(1);
   }else{
    if(debuglevel>2){printf(" insert: n=%ld id=%lld lon=%f lat=%f ele=%f\n",n,id,lon,lat,ele);}
    peak[n].id=id;peak[n].lon=lon;peak[n].lat=lat;peak[n].ele=ele;peak[n].isolation=radius;peak[n].heigherpoint_lon=peak[n].heigherpoint_lat=0.0;
    n++;numpeaks++;
   }
  }
  st_g++;
 }
 if(debuglevel>0){printf("%ld Got %ld peaks, %ld without parseable ele\n",time(NULL)-starttime,st_g,st_s);}
 
/* sorting them by latitude */

 qsort(peak,numpeaks,sizeof(struct list_peak),compare_function);
 if(debuglevel>0){printf("%ld Sorted peaks\n",time(NULL)-starttime);}
 
/* Get "isolation" as distance to the next peak */
 
 get_isolation_by_ele(peak,numpeaks,radius);
 if(debuglevel>0){printf("%ld Got isolation step 1 (peak to peak distance)\n",time(NULL)-starttime);}

/* Get isolation as distance to the next higher point in DEM */

 get_isolation_by_DEM(peak,numpeaks,radius,adfGeoTransform,hDataset,hBand,GDALGetRasterXSize(hDataset),GDALGetRasterYSize(hDataset));
 if(debuglevel>0){printf("%ld Got isolation step 2 (peak to DEM)\n",time(NULL)-starttime);}


 for(n=0;n<numpeaks;n++){
  if((!outputformat)||(strcmp(outputformat,"csv")==0)){
   if(debuglevel>0){printf("%lld;%.7lf;%.7lf;%.0lf;%.0lf;%lld;%.7lf;%.7lf\n",peak[n].id,peak[n].lon,peak[n].lat,peak[n].ele,peak[n].isolation,peak[n].heigherpeak_id,peak[n].heigherpoint_lon,peak[n].heigherpoint_lat);}
   else            {printf("%lld;%.7lf;%.7lf;%.0f\n",peak[n].id,peak[n].lon,peak[n].lat,peak[n].isolation);}
  }
  else              if(strcmp(outputformat,"sql")==0) {printf("update planet_osm_point set otm_isolation='%.0lf' where osm_id=%lld;\n",peak[n].isolation,peak[n].id);}
 } 
 exit(0);
}

