<?php
$continents=["africa","asia","australia-oceania","central-america","europe","north-america","south-america"];

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


$lang = substr($_SERVER['HTTP_ACCEPT_LANGUAGE'], 0, 2);
$acceptLang = ['en', 'de']; 
$lang = in_array($lang, $acceptLang) ? $lang : 'en';
$lang_file = file_get_contents($lang . ".json");
$str = json_decode($lang_file, true);

?>

<html>
	<header>
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<title><?php echo $str["title"]; ?></title>
		<link rel="stylesheet" href="style.css">
		<link rel="stylesheet" href="leaflet/leaflet.css">
		<script type="text/javascript" src="leaflet/leaflet.js"></script>
	</header>
	<body>
		
<div id="links">
	<a href="https://opentopomap.org"><?php echo $str["webmap"]; ?></a>
	|
	<span class="highlight"><?php echo $str["garminmaps"]; ?></span>
	|
	<a href="https://opentopomap.org/about"><?php echo $str["about"]; ?></a>
	|
	<a href="https://opentopomap.org/credits"><?php echo $str["credits"]; ?></a>
</div>
<h2><?php echo $str["title"]; ?></h2>
<div id="text">
	<div><?php echo $str["subtitle"]; ?></div>
	<h3><?php echo $str["description_caption"]; ?></h3>
	<?php echo $str["description"]; ?>
	<br/>
	<?php echo $str["features"]; ?>
	
	<h3><?php echo $str["installation_caption"]; ?></h3>
	<h4>Garmin</h4>
	<?php echo $str["installation_garmin"]; ?>
	<h4>Basecamp</h4>
	<?php echo $str["installation_basecamp"]; ?>
	
	<h3><?php echo $str["screenshots_caption"]; ?></h3>
	<?php
	$files = glob("screenshots/*.{png}", GLOB_BRACE);
	foreach($files as $file) {
		echo "<img class='screenshot' src='".$file."' title='".basename($file)."'>";
	}?>
	<h3><?php echo $str["license_caption"]; ?></h3>
	<div><?php echo $str["license"]; ?></div>
	<h3><?php echo $str["download_caption"]; ?></h3>
</div>
<div class="table-wrapper">
<table>
<?php
      
foreach($continents as $continent) {
	// all continents as active for javascript disabled standard view
	echo "<tr class='continent active_continent' id='".str_replace('-','_',$continent)."' continent='".str_replace('-','_',$continent)."' onclick='toggle_continent(\"".str_replace('-','_',$continent)."\")'><td colspan=6><h3>".ucwords($continent,' -')."</h3></td></tr>\n";
	echo "<tr class='header'><th>Country</th><th>Garmin file</th><th>Garmin Contours file</th><Basecamp file</th><th>Generated at</th></tr>\n";

	$files = glob($continent."/*.{poly}", GLOB_BRACE);
	foreach($files as $file) {
		$country = basename($file,".poly");
		$gmap_file = $continent."/".$country."/otm-".$country.".zip";
		$gmap_size = human_filesize(filesize($gmap_file));
		$gmap_link = ($gmap_size > 0)?("<a href=\"".$gmap_file."\">Basecamp</a> (".$gmap_size.")"):("");
		$img_file = $continent."/".$country."/otm-".$country.".img";
		$contours_file = $continent."/".$country."/otm-".$country."-contours.img";
		echo "<tr class='country' id='".str_replace('-','_',$country)."' continent='".str_replace('-','_',$continent)."' onclick='update_layer(\"".str_replace('-','_',$country)."\")'><td>". preg_replace_callback('/((Us\-)|(Dach))/', function ($word) {return strtoupper($word[1]);}, ucwords($country,' -') )."</td><td><a href=\"".$img_file."\">Garmin</a> (".human_filesize(filesize($img_file)).")</td><td><a href=\"".$contours_file."\">Garmin contours</a> (".human_filesize(filesize($contours_file)).")</td><td>".$gmap_link."</td><td>".date("Y-m-d H:i:s",filectime($img_file))."</td></tr>\n";
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

	// show map only with enabled javascript on mobile devices.
	if(window.innerWidth < 768) {
		document.getElementById("map").style.display = 'block';
		document.getElementById("extraspace").style.margin = '35vh';
	}
	
	// collapse all continents for interactive list
	collapse_continent();
	
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
	
	var active_continent, active_row, boundary;
	
	// parse hash of permalinks
	if((name = location.hash.split('#')[1]) != undefined) {
		var continent = document.getElementById(name).getAttribute("continent");
		update_layer(continent);
		update_layer(name);
	}
	
	// collapse all continents
	function collapse_continent() {
		var continent_rows = document.querySelectorAll('.continent');
		for(var i=0; i<continent_rows.length; i++) {
			continent_rows[i].classList.remove("active_continent");
		}
		
		var rows = document.querySelectorAll('.header, .country');
		for(var i=0; i<rows.length; i++) {
			rows[i].style.display = 'none';
		}	
	}
	
	// toggle continent
	function toggle_continent(name) {
		if(active_continent == null) {
			update_layer(name);
			active_continent = name;
			document.getElementById(name).classList.add("active_continent");
		} else if(active_continent == name) {
			collapse_continent();
			document.getElementById(active_row).classList.remove("active_row");
			document.getElementById(active_continent).classList.remove("active_continent");
			active_continent = null;
			location.hash = "";
			update_layer("continents");
		} else {
			collapse_continent();
			document.getElementById(active_row).classList.remove("active_row");
			document.getElementById(active_continent).classList.remove("active_continent");
			active_continent = name;
			update_layer(name);
			document.getElementById(name).classList.add("active_continent");
		}
	}
	
	// add layer
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
					update_layer(feature.properties.name.replaceAll("-","_"));
				});
			}
		}).addTo(map);
    
		map.fitBounds(boundaries.getBounds());
	}
	
	// update layer depending on input: continents or countries
	function update_layer(name) {
		if(boundary != null) {
			boundary.setStyle({
				'fillColor': '#AAC',
				'color': '#AAC'
			});
		}
		boundary = boundaries.getLayers().find(feat => feat.feature.properties.name.replaceAll("-","_") === name);
		if(boundary != null) {
			boundary.openPopup();
			boundary.setStyle({
				'fillColor': 'red',
				'color': 'red'
			});
			boundary.bringToFront();
			map.fitBounds(boundary.getBounds(),{'animate': true});
		}
		
		if(this["obj_"+name] != null) {
			map.removeLayer(boundaries);
			add_layer("obj_"+name);
			
			var rows = document.querySelectorAll('.header, .country');
			for(var i=0; i<rows.length; i++) {
				rows[i].style.display = 'none';
			}
			
			if(name != "continents") {
				active_continent = name;
				document.getElementById(name).classList.add("active_continent");
				rows = document.querySelectorAll("[continent='"+name+"']");
				for(var i=0; i<rows.length; i++) {
					rows[i].style.display = '';
				}
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
