#!/usr/bin/perl
#
# parkingisolation.pl table_name file [limit]
#
# Expects a table name and a CSV file id;x;y;metric reads the whole file into an array and
# writes "update table set isolation=_ where osm_id=_ and amenity='parking'..." to stdout 
#

use strict;
use warnings;
use POSIX;

my $table=$ARGV[0] or die "-- no table";
my $file =$ARGV[1] or die "-- Need to get CSV file on the command line\n";
my $limit=5000;
if(exists($ARGV[2])){$limit=$ARGV[2];}

# Read file into list
#

open(my $data, '<', $file) or die "-- Could not open '$file' $!\n";

my @list;
while(my $line=<$data>){
 chomp $line;
 push(@list,$line);
}
print "-- read $#list objects\n";
print "-- start sorting\n";

# Sort list by longitude
#

my @sortedlist=sort by_x @list;

sub by_x{
 my($id1,$x1,$y1,$m1)=split(/;/,$a);
 my($id2,$x2,$y2,$m2)=split(/;/,$b);
 my $r=0;
 if($x1>$x2){$r=1;}
 if($x1<$x2){$r=-1;}
 $r;
}
print "-- sorting end\n-- start comparing\n";

# Compare each point with each point left of it in $limit distance
# set isolation for both points
#

my %isolation=();
for(my $n1=0;$n1<=$#sortedlist;$n1++){
 my($id1,$x1,$y1,$m1)=split(/;/,$sortedlist[$n1]);
 $isolation{$id1}=$limit;
 for(my $n2=$n1+1;$n2<=$#sortedlist;$n2++){
  my($id2,$x2,$y2,$m2)=split(/;/,$sortedlist[$n2]);
  my $d=sqrt(($x1-$x2)*($x1-$x2)+($y1-$y2)*($y1-$y2));
  if($d<$isolation{$id1}){$isolation{$id1}=$d;}
  if(!(exists($isolation{$id2}))){
   $isolation{$id2}=$d;
  }else{
   if($d<$isolation{$id2}){$isolation{$id2}=$d;}
  }
  if(($x2-$x1)>$isolation{$id1}){$n2=$#sortedlist+1;}
 }
}
print "-- comparing end\n"; 
my $k=keys(%isolation);
print "-- got isolation for $k ids\n";

# write sql statement for each osm_id
#

foreach my $e (keys(%isolation)){
 print "UPDATE $table SET otm_isolation='".floor($isolation{$e})."' WHERE osm_id=$e AND amenity='parking' AND hiking IS NOT NULL AND (otm_isolation!='".floor($isolation{$e})."' OR otm_isolation IS NULL);\n"
}

