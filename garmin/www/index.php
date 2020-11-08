<?php
function human_filesize($bytes, $decimals = 1) {
  $sz = 'BKMGTP';
  $factor = floor((strlen($bytes) - 1) / 3);
  return sprintf("%.{$decimals}f", $bytes / pow(1024, $factor)) . @$sz[$factor];
}

function poly2geojson($pfad) {
	$geojson['type'] = 'FeatureCollection';
	
	$files = glob($pfad."/*.{poly}", GLOB_BRACE);
	$j = 0;
	foreach($files as $file) {
		$poly = explode('END',file_get_contents($file));
		
		$geojson['features'][$j]['type'] = 'Feature';
		$geojson['features'][$j]['properties']['name'] = pathinfo($file, PATHINFO_FILENAME);
		$geojson['features'][$j]['geometry']['type'] = 'Polygon';
		
		$n = 0;
		foreach($poly as $poly_part) {
			$poly_part2 = explode(PHP_EOL,$poly_part);
			
			if(sizeof($poly_part2) > 2) {
				// step through each polygon part				
				$lonlat = array();
				for($i=0; $i<sizeof($poly_part2); $i++) {
					// step through each coordinate entry
					$lonlat_elem = explode('   ',$poly_part2[$i]);
					if(sizeof($lonlat_elem) == 3) {
						array_shift($lonlat_elem);
						$lonlat[] = $lonlat_elem;
					}
				}
				$geojson['features'][$j]['geometry']['coordinates'][$n] = $lonlat;
			}		
			$n++;
		}
		$j++;
	}
	
	return json_encode($geojson);
}
?>

<html>
	<header>
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<title>OpenTopoMap Garmin</title>
		<link rel="stylesheet" href="style.css">
		<link rel="stylesheet" href="leaflet/leaflet.css">
		<script type="text/javascript" src="leaflet/leaflet.js"></script>
	</header>
	<body>
<h2>OpenTopoMap Garmin</h2>
<div id="text">
	<div>Worldwide OpenTopoMap for Garmin devices.</div>
	<div>License: CC-BY-NC-SA 4.0 - NOT FOR RESALE!</div>
	<div>OpenTopoMap stands in no connection with Garmin Ltd. and may not be made responsible for any hard- and software damage that occurs from its use.</div>
</div>
<div class="table-wrapper">
<table>
<?php
$continents=["africa","asia","australia-oceania","central-america","europe","north-america","south-america"];
foreach($continents as $continent) {
	echo "<tr class=\"header\"><td colspan=5><h3>".$continent."</h3></td></tr>";
	echo "<tr><th>Country</th><th>Data status</th><th>Map file</th><th>Contours file</th><th>Generated at</th></tr>";
	$files = glob($continent."/*.{poly}", GLOB_BRACE);
	foreach($files as $file) {
		//echo "<tr><td>".$file."</td><td>".human_filesize(filesize($file))."</td><td>".date ("Y-m-d H:i:s",filemtime($file))."</td></tr>";
		$country = basename($file,".poly");
		$img = $continent."/".$country."/otm-".$country.".img";
		$contours = $continent."/".$country."/otm-".$country."-contours.img";
		echo "<tr><td>".$country."</td><td>".date("Y-m-d",filemtime($img))."</td><td><a href=\"".$img."\">map</a> (".human_filesize(filesize($img)).")</td><td><a href=\"".$contours."\">contours</a> (".human_filesize(filesize($contours)).")</td><td>".date("Y-m-d H:i:s",filectime($img))."</td></tr>";
	}
}
?>
</table>
</div>

<script type="text/javascript">
//var continents=<?php echo poly2geojson("."); ?>;
<?php 
echo "var continents =".poly2geojson('.').";\n";
foreach($continents as $continent) {
	echo "var ".str_replace("-","_",$continent)."=".poly2geojson($continent).";\n\n\n";
}
?>
</script>
<div id="map"></div>

<script type="text/javascript">
	var map = L.map('map',{zoomControl: false}).setView([50, 11], 7);
	map.attributionControl.setPrefix();
	L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
		maxZoom: 17,
		attribution: '&copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, ' +
			'<a href="https://opentopomap.org">OpenTopoMap</a>',
		id: 'osm'
	}).addTo(map);
	
	function add_layer(name) {
		boundaries = L.geoJson(name, {
			onEachFeature: function(feature, featureLayer) {
				featureLayer.bindPopup(feature.properties.name);
			}
		}).addTo(map);

		boundaries.on('click', function(e) {
			update_layer(e.layer.feature.properties.name)
		});
		map.fitBounds(boundaries.getBounds()).zoomIn();
	}
	
	function update_layer(name) {
		name = name.replace("-","_");
		if(this[name] != null) {
			map.removeLayer(boundaries);
			add_layer(this[name]);
			map.fitBounds(boundaries.getBounds());
		}
	}
	
	add_layer(continents);
</script>
</body>
</html>
