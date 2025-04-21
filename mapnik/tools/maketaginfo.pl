#!/usr/bin/perl
#
# maketaginfo.pl
# Reads opentopomap.xml, get all used keys in included style files, 
# checks, from which tables this keys are taken and creates a
# json file for taginfo.openstreetmap.org as described here:
# https://wiki.openstreetmap.org/wiki/Taginfo/Projects
#
# "maketaginfo.pl -t" shows a table of tags and styles and don't write
#                     the json file.
########################################################################################



########### Things to configure ########################################################

# taginfo needs some project infos

$proj_name=          "OpenTopoMap";
$proj_description=   "Topographische Karten aus OpenStreetMap";
$proj_doc_url=       "https://github.com/der-stefan/OpenTopoMap";
$proj_icon_url=      "https://raw.githubusercontent.com/der-stefan/OpenTopoMap/master/mapnik/opentopomap.png";
$proj_project_url=   "https://opentopomap.org";
$proj_contact_name=  "Stefan Erhardt";
$proj_contact_email= "stefan\@opentopomap.org";

# pathes and files:

$xmlfile='opentopomap.xml';                     # mapnik xml file
$path='../';                                    # path to $xmlfile, relative to the location of this script
$osm2pgsqlfile='osm2pgsql/opentopomap.style';   # osm2pgsql style file with path relative to $path
$jsonfile='taginfo.json';                       # json output, path relative to $path

#
# the type of an object may be node, way, area, relation. In most cases we get the type by looking from which table this 
# tag is taken. For some keys that doesn't work because (a) they are only used while preprocessing or (b) they are used 
# in sql queries but not in any style. These tags we have to classify by hand:

%keytype=();
$keytype{'bridge'}                     = "way";
$keytype{'boundary'}                   = "relation";
$keytype{'layer'}                      = "way";
$keytype{'region:type'}                = "area";
$keytype{'region:type=mountain_area'}  = "area";
$keytype{'region:type=natural_area'}   = "area";
$keytype{'region:type=mountain_range'} = "area";
$keytype{'region:type=basin'}          = "area";
$keytype{'natural=basin'}              = "way,area";
$keytype{'natural=valley'}             = "way,area";
$keytype{'natural=gorge'}              = "way,area";
$keytype{'natural=canyon'}             = "way,area";
$keytype{'natural=mountain_range'}     = "way,area";
$keytype{'natural=massif'}             = "way,area";
$keytype{'natural=couloir'}            = "way,area";
$keytype{'natural=gully'}              = "way,area";
$keytype{'natural=ridge'}              = "way,area"; 
$keytype{'natural=arete'}              = "way,area"; 
$keytype{'natural=arete'}              = "way,area";
$keytype{'natural=arete'}              = "way,area";
$keytype{'natural=bay'}                = "way,area";
$keytype{'natural=strait'}             = "way,area";

#
# For some tags we want to give some extra description
#

%description=();
$description{'direction'}                  = "direction of viewpoints and saddles";
$description{'memorial:type=stolperstein'} = "used to exclude this object from rendering";
$description{'hiking'}                     = "used for parking areas";

#
# some styles we dont't want to parse (comma separated list)
#
$stylestoignore="test";

# For the other tags we get the type from the type of the database table:

%dbtabletype=();
$dbtabletype{'planet_osm_line'}   ='way';
$dbtabletype{'planet_osm_point'}  ='node';
$dbtabletype{'planet_osm_polygon'}='area';
$dbtabletype{'railways'}          ='way';
$dbtabletype{'water'}             ='way';
$dbtabletype{'roads'}             ='way';
$dbtabletype{'borders'}           ='way';
$dbtabletype{'naturalarealabels'} ='area';
$dbtabletype{'lakelabels'}        ='area';
$dbtabletype{'cities'}            ='node';
$dbtabletype{'landuse'}           ='area';


################# End of configuration, start of program ##################################
use File::Basename;

$stylenum=0;
$tagnum=0;
$waynum=0;
$pointnum=0;
$areanum=0;
$pgnum=0;
%styletaglist=();
%stylevaluelist=();
$features{'area'}='';
$features{'way'}='';
$features{'node'}='';
$features{'osm2pgsql'}='';
$path=dirname(__FILE__)."/".$path;

#
# ############# First step: open $xmlfile, read all included style files
#
open($f,$path.$xmlfile) or die "Could not open file '$path$xmlfile' $!";
while ($xmlrow = <$f>){
 chomp $xmlrow;
 $xmlrow=~ s/^\s+|\s+$//g;
 @part=split(/[<> \t]+/,$xmlrow);
#
# got a <!ENTITY foo SYSTEM "path/to/bar.xml">
#
 if(($part[1] eq "!ENTITY") && ($part[3] eq "SYSTEM")){
  $stylefile=$part[4];
  $stylefile=~s/"//g;
  $style='none';
#
# open this file and read syle name ("<Style name="xxx">)
#
  open($s,$path.$stylefile) or die "Could not open file '$tylefile' $!";
  while ($styrow = <$s>) {
   chomp $styrow;
   $styrow=~ s/^\s+|\s+$//g;
   @stypart=split(/[<> \t]+/,$styrow);
   if($stypart[1] eq "Style"){
    $style=$stypart[2];
    $style=~s/"//g;
    $style=~s/name=//g;
    $styletaglist{$style}='';
    $stylenum++;
   }
#
# read all filter rules for this style, extract keys ("[key]")
#
   if(($stypart[1] eq "Filter") || ($stypart[1] eq "TextSymbolizer") || ($stypart[1] eq "PointSymbolizer")){
    $filterrow=$styrow;
    $filterrow=~s/[^A-Za-z0-9_.:&;=><\[\]']+/ /g;
    $filterrow=~s/=/ op /g;
    @filterpart=split(/[<> \t+-]+/,$filterrow);
    $i=0;
    foreach $fi (@filterpart) {
     if($fi=~m/\[.+\]/){
      $tagnum++;
      if(index($styletaglist{$style},$fi)==-1){
       $styletaglist{$style}=$styletaglist{$style}.$fi;
      }
      if(($filterpart[$i+1] eq "op")&&($filterpart[$i+2]=~ m/^'.*'$/)){
       $value=$filterpart[$i+2];
       $value=~s/'//g;
       $tagvalue=$fi."=".$value;
       $tagvalue=~s/\]//g;
       $tagvalue=~s/\[//g;
       $tagvalue="[".$tagvalue."]";
       if(index($stylevaluelist{$style},$tagvalue)==-1){
        $stylevaluelist{$style}=$stylevaluelist{$style}.$tagvalue;
       }
      }
     }
     $i++;
    }
   }
  }
  close($s);
 }
}
close($f);

@g= split(/[, ;]/,$stylestoignore);
foreach $m (@g){
 $styletaglist{$m}='';
 $stylevaluelist{$m}='';
}

# ############## Second step: sort points, ways and areas
# Now we have a hash like $styletaglist{'waterway-lines'}="[waterway][intermittent][tunnel][CEMT][motorboat]"
# in the second run we look for the table where these keys come from
# 

open($f,$path.$xmlfile) or die "Could not open file '$xmlfile' $!";

$inlayer=0;
$stylelist='';
while ($xmlrow = <$f>) {
 chomp $xmlrow;
 $xmlrow=~ s/^\s+|\s+$//g;
 @part=split(/[<> \t]+/,$xmlrow);
#
# Got a start of a Layer ... /Layer -Block
#
 if($part[1] eq "Layer"){
  $inlayer=1;
  $stylelist='';
  $tabletype='';
 }
#
# End of a Layer-Block, append found tags to $features{$tabletype}
#
 if(($part[1] eq "/Layer")&&($inlayer==1)){
  @v = split(' ',$stylelist);
  foreach $k (@v) {
   $t=$styletaglist{$k};
   $t=~s/\[/ /g;$t=~s/\]//g;
   @g= split(' ',$t);
   foreach $m (@g){
    if(index($features{$tabletype}," ".$m." ")==-1){
     $features{$tabletype}.=" ".$m." ";
     if($tabletype eq 'area'){$areanum++;}
     if($tabletype eq 'way'){$pointnum++;}
     if($tabletype eq 'point'){$waynum++;}
    }
   }
  }
  foreach $k (@v) {
   $t=$stylevaluelist{$k};
   $t=~s/\[/ /g;$t=~s/\]//g;
   @g= split(' ',$t);
   foreach $m (@g){
    if(index($features{$tabletype}," ".$m." ")==-1){
     $features{$tabletype}.=" ".$m." ";
     if($tabletype eq 'area'){$areanum++;}
     if($tabletype eq 'way'){$pointnum++;}
     if($tabletype eq 'point'){$waynum++;}
    }
   }
  }
  $inlayer=0;
 }
#
# Datasource "Parameter": get the table where these values are coming from
#
 if(($part[1] eq "Parameter") and ($part[2] eq "name=\"table\"")){
  foreach $k (keys %dbtabletype){
   if(index($xmlrow,"FROM ".$k)!=-1){$tabletype=$dbtabletype{$k};}
  }
 }
#
# StyleName: apppend style name to list of staylenames
#
 if($part[1] eq "StyleName"){
  $stylelist.=$part[2]." ";
 }
}
close($f);


# ############## Third step: read opentopomap.style and look which of these tags are used
# 

open($f,$path.$osm2pgsqlfile) or die "Could not open file '$osm2pgsqlfile' $!";

$features{'node'}.=" ";
$features{'way'}.=" ";
$features{'area'}." ";

while ($pgrow = <$f>) {
 chomp $pgrow;
 $pgrow=~ s/#.*//g;
 @part=split(/[<> \t]+/,$pgrow);
#
# keys from osm2pgsql style
#
 if(($part[2] eq 'text') && (($part[3] eq 'linear') || ($part[3] eq 'polygon'))){
  $pgnum++;
  $object_types=$keytype{$part[1]};
  if(index($features{'node'}," ".$part[1]." ")!=-1) {$object_types.=',node';}
  if(index($features{'way'}," ".$part[1]." ")!=-1)  {$object_types.=',way';}
  if(index($features{'area'}," ".$part[1]." ")!=-1) {$object_types.=',area';}
  if($object_types ne ''){
   $object_types=~ s/^,//g;
   $keytype{$part[1]}=$object_types;
  }else{$keytype{$part[1]}='';}
#
# key+value are in $features{...} as "key=value"
# Search "$part[1]=" in all features
#
  @tag=split(/ +/,$features{'node'}." ".$features{'way'}." ".$features{'area'}); 
  %seen = ();
  foreach $item (@tag){$seen{$item}++;}@uniq = keys %seen;
  foreach $m(@uniq){
   if(index($m,$part[1]."=")==0){
    $object_types=$keytype{$m};
    if(index($features{'node'}," ".$m." ")!=-1){$object_types.=',node';}
    if(index($features{'way'}," ".$m." ")!=-1) {$object_types.=',way';}
    if(index($features{'area'}," ".$m." ")!=-1){$object_types.=',area';}
    if($object_types ne ''){
     $object_types=~ s/^,//g;
     $keytype{$m}=$object_types;
    }
   }
  }
 }
}
close($f);

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=gmtime(time);
$datestring=sprintf("%4d%02d%02dT%02d%02d%02dZ",$year+1900,$mon+1,$mday,$hour,$min,$sec);

#
# screen output, option -t
#
if($ARGV[0] eq '-t'){
 print "\n\n";
 print "Taginfo for $xmlfile ".localtime()." ($datestring)\n\n";
 print "key                                           Used as                       Used in this styles\n";
 print "------------------------------------------------------------------------------------------------------\n";
 foreach $k (sort { "\L$a" cmp "\L$b" } keys %keytype){
  $stylesused='';
  foreach $m (sort keys %styletaglist){
   $sstr="\[".$k."]";
   if(index($styletaglist{$m},$sstr)!=-1){$stylesused.=" ".$m;}
  }
  foreach $m (sort keys %stylevaluelist){
   $sstr="\[".$k."]";
   if(index($stylevaluelist{$m},$sstr)!=-1){$stylesused.=" ".$m;}
  }
  $p=$k;$p=~s/=/ = /g;
  if(!($keytype{$k} eq '')&&($stylesused eq '')){$stylesused=' Not used in styles, but in preprocessing or sql query';}
  if(!($keytype{$k} eq '')){printf("%-45s %-28s %s\n",$p,$keytype{$k},$stylesused);}
  else                     {printf("%-45s %-28s\n",$p,"--- not used --");}
 }
 print "-----------------------------------------------------------------------------------------------------\n\n";       
}

if(!($ARGV[0] eq '-t')){
 open($f,'>',$path.$jsonfile) or die "Could not open file '$path$jsonfile' $!";
 $header =<<"END_HEADER";
{
 "data_format": 1, 
 "data_updated": "$datestring", 
  "project": { 
  "name": "$proj_name",
  "description": "$proj_description",
  "project_url": "$proj_project_url",
  "doc_url": "$proj_doc_url",
  "icon_url": "$proj_icon_url",
  "contact_name": "$proj_contact_name",
  "contact_email": "$proj_contact_email"
 },
 "tags": [
END_HEADER

 print $f $header;
 $i=0;
 foreach $k (sort { "\L$a" cmp "\L$b" } keys %keytype){
  if(!($keytype{$k} eq '')){
   if($i>0){print $f ",\n";}
   $p=$k;
   $t=$keytype{$k};
   $t=~s/^/\["/g;$t=~s/$/"\]/g;$t=~s/,/", "/g;
   if(index($p,"=")==-1){
    if(!$description{$k}) {printf $f ("  { \"key\" : \"%s\", \"object_types\" : %s }",$p,$t);}
    else                  {printf $f ("  { \"key\" : \"%s\", \"object_types\" : %s, \"description\" : \"%s\" }",$p,$t,$description{$k});}
   }else{
    ($ke,$va)=split(/=/,$p);
     if(!$description{$k}) {printf $f ("  { \"key\" : \"%s\", \"value\" : \"%s\", \"object_types\" : %s }",$ke,$va,$t);}
     else                  {printf $f ("  { \"key\" : \"%s\", \"value\" : \"%s\", \"object_types\" : %s, \"description\" : \"%s\" }",$ke,$va,$t,$description{$k});}
   }
   $i++;
  }
 }
 print $f "\n ]\n}\n";
 print "wrote $i tags to $path$jsonfile\n";
}

