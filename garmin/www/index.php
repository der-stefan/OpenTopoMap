<?php
$continents=["africa","asia","australia-oceania","central-america","europe","north-america","south-america"];
//$continents=["australia-oceania"];

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
foreach($continents as $continent) {
	echo "<tr class='continent' id='".str_replace('-','_',$continent)."' continent='".str_replace('-','_',$continent)."' onclick='toggle_continent(\"".$continent."\")'><td colspan=5><h3>".$continent."</h3></td></tr>";
	echo "<tr class='header'><th>Country</th><th>Data status</th><th>Map file</th><th>Contours file</th><th>Generated at</th></tr>";

	$files = glob($continent."/*.{poly}", GLOB_BRACE);
	foreach($files as $file) {
		$country = basename($file,".poly");
		$img = $continent."/".$country."/otm-".$country.".img";
		$contours = $continent."/".$country."/otm-".$country."-contours.img";
		echo "<tr class='country' id='".str_replace('-','_',$country)."' continent='".str_replace('-','_',$continent)."' onclick='update_layer(\"".$country."\")'><td>".$country."</td><td>".date("Y-m-d",filemtime($img))."</td><td><a href=\"".$img."\">map</a> (".human_filesize(filesize($img)).")</td><td><a href=\"".$contours."\">contours</a> (".human_filesize(filesize($contours)).")</td><td>".date("Y-m-d H:i:s",filectime($img))."</td></tr>";
	}
}
?>
</table>
</div>
<div id="map"></div>
<div id="extraspace"></div>

<script type="text/javascript">
	// polygon outlines
	<?php 
	echo "var obj_continents =".poly2geojson('.').";\n";
	foreach($continents as $continent) {
		echo "var obj_".str_replace("-","_",$continent)."=".poly2geojson($continent).";\n\n\n";
	}
	?>

	// load map
	var map = L.map('map',{zoomControl: false}).setView([50, 11], 7);
	map.attributionControl.setPrefix();
	L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
		maxZoom: 17,
		attribution: '&copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, ' +
			'<a href="https://opentopomap.org">OpenTopoMap</a>',
		id: 'osm'
	}).addTo(map);
	
	add_layer("obj_continents");
	
	// show map only with enabled javascript on mobile devices.
	if(window.innerWidth < 768) {
		document.getElementById("map").style.display = 'block';
		document.getElementById("extraspace").style.margin = '35vh';
	}
	
	collapse_continent();

	var active_continent = null;
		
	if((name = location.hash.split('#')[1]) != undefined) {
		update_layer(document.getElementById(name).getAttribute("continent"));
		update_layer(name);
		active_continent = name;
	}
	
	function collapse_continent() {
		var rows = document.querySelectorAll('.header, .country');
		for(var i=0; i<rows.length; i++) {
			rows[i].style.display = 'none';
		}
	}
	
	function toggle_continent(name) {
		if(active_continent == null) {
			update_layer(name);
			active_continent = name;
		} else {
			collapse_continent();
			active_continent = null;
			document.getElementById(active_row).classList.remove("active_row");
		}
	}
	
	var active_row;
	function add_layer(name) {
		boundaries = L.geoJson(this[name], {
			style: function(feature) {
				return {
					color: '#AAC'
				};
			},
			onEachFeature: function(feature, featureLayer) {
				featureLayer.bindPopup(feature.properties.name);
				featureLayer.on('mouseover', function() {
					this.setStyle({
						'fillColor': '#88A'
					});
				});
				featureLayer.on('mouseout', function() {
					this.setStyle({
						'fillColor': '#AAC'
					});
				});
				featureLayer.on('click', function(event) {
					update_layer(feature.properties.name);
				});
			}
		}).addTo(map);
    
		map.fitBounds(boundaries.getBounds());
	}
	
	var boundary;
	function update_layer(name) {
		if(boundary != null) {
			boundary.setStyle({
				'fillColor': '#AAC',
				'color': '#AAC'
			});
		}
		boundary = boundaries.getLayers().find(feat => feat.feature.properties.name === name);
		if(boundary != null) {
			boundary.openPopup();
			boundary.setStyle({
				'fillColor': 'red',
				'color': 'red'
			});
			boundary.bringToFront();
			map.fitBounds(boundary.getBounds(),{'animate': true});
		}
		
		name = name.replaceAll("-","_");
		if(this["obj_"+name] != null) {
			map.removeLayer(boundaries);
			add_layer("obj_"+name);
			
			var rows = document.querySelectorAll('.header, .country');
			for(var i=0; i<rows.length; i++) {
				rows[i].style.display = 'none';
			}
			
			rows = document.querySelectorAll("[continent='"+name+"']");
			for(var i=0; i<rows.length; i++) {
				rows[i].style.display = '';
			}
			
		}	
		// highlight and jump to selected row
		if(document.getElementById(active_row) != null){
			document.getElementById(active_row).classList.remove("active_row");
		}
		active_row = name;
		if(document.getElementById(active_row) != null){
			document.getElementById(active_row).classList.add("active_row");
			location.hash = active_row;
		}
	}
</script>
</body>
</html>
