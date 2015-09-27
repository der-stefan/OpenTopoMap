<?php 
	$db=pg_connect('dbname=gis') or die("Keine DB, sonst alles in Ordnung");
	$query="SELECT name,\"natural\",waterway,way_area FROM planet_osm_polygon WHERE (\"natural\" = 'water' OR waterway = 'riverbank') AND way_area > 1000000000;";
	$result=pg_query($db,$query);
	
	while ($row = pg_fetch_array($result)) {
		if($row["name"] == "Bodensee") {
			echo "$row[0] $row[1] $row[2] $row[3] \n";
		}
	}

	pg_close($db); 
?>
