/* QTH Locator by DK3ML
* http://dk3ml.de/static/hamgrid.html
*/

var d1 = "ABCDEFGHIJKLMNOPQR".split("");
var d2 = "ABCDEFGHIJKLMNOPQRSTUVWX".split("");

function updateLocator() {
	gridLayer.clearLayers();
	drawGrid(map.getBounds(),map.getZoom());
}

function getLocatorPosition(locator) {
	var len = locator.length;

	if((len % 2 != 0) || (len > 6)) {
		alert("Invalid locator format!");
		return;
	}
	
	var x1 = (locator.toUpperCase().charCodeAt(0)-65)*20 - 180;
	var x2 = x1 + 20;
	var	y1 = (locator.toUpperCase().charCodeAt(1)-65)*10 - 90;
	var	y2 = y1 + 10;
	
	if(len>= 4) {
		x1 = x1 + (locator.charCodeAt(2)-48)*2;
		x2 = x1 + 2;
		y1 = y1 + locator.charCodeAt(3)-48;
		y2 = y1 + 1;
	}
	if(len == 6) {		
		x1 = x1 + (locator.toUpperCase().charCodeAt(4)-65)*2/24;
		x2 = x1 + 2/24;
		y1 = y1 + (locator.toUpperCase().charCodeAt(5)-65)*1/24;
		y2 = y1 + 1/24;
	}
	
	return L.latLngBounds(L.latLng(y1, x1), L.latLng(y2, x2));
}

function getLocator(lon,lat, precision) {
	var locator = "";
	var x = lon;
	var y = lat;
      
	while (x < -180) {x += 360;}
	while (x > 180) {x -=360;}
      
	x = x + 180;
	y = y + 90;
      
	locator = locator + d1[Math.floor(x/20)] + d1[Math.floor(y/10)];
      
	if (precision > 1) {
		rlon = x%20;
		rlat = y%10;
		locator += Math.floor(rlon/2) +""+ Math.floor(rlat/1);
	}
         
	if (precision > 2) {
		rlon = rlon%2;
		rlat = rlat%1;
		locator += d2[Math.floor(rlon/(2/24))] + "" + d2[Math.floor(rlat/(1/24))];
	}
	return locator;
}

function getLabel(lon,lat,precision) {
	var myIcon = L.divIcon({className: 'locator_label', html: getLocator(lon,lat,precision)});
	var marker = L.marker([lat,lon], {icon: myIcon}, clickable=false);
	return marker;
}

function drawGrid(bounds, zoom) {
	var w = bounds.getWest();
	var e = bounds.getEast();
	var n = bounds.getNorth();
	var s = bounds.getSouth();
	if (n > 85) n = 85;
	if (s < -85) s = -85;

	if (zoom < 5) {
		var left = Math.floor(w/20.)*20;
		var right = Math.ceil(e/20.)*20;
		var top = Math.ceil(n/10.)*10;
		var bottom = Math.floor(s/10.)*10;
		for (var lon = left; lon < right; lon += 20) {
			for (var lat = bottom; lat < top; lat += 10) {
				var bounds = [[lat,lon],[lat+10,lon+20]];
				gridLayer.addLayer(L.rectangle(bounds, {color: "#0000ff", weight: 1, fill:false}));
				gridLayer.addLayer(getLabel(lon+10,lat+5,1));
			}
		}
	} else if (zoom < 10){
		var left = Math.floor(w/2.)*2;
		var right = Math.ceil(e/2.)*2;
		var top = Math.ceil(n);
		var bottom = Math.floor(s);
		for (var lon = left; lon < right; lon += 2) {
			for (var lat = bottom; lat < top; lat += 1) {
				var bounds = [[lat,lon],[lat+1,lon+2]];
				gridLayer.addLayer(L.rectangle(bounds, {color: "#0000ff", weight: 1, fill: false}));
				gridLayer.addLayer(getLabel(lon+1,lat+0.5,2));
			}
		}
    
	} else {
		var left = Math.floor(w/2.)*2;
		var right = Math.ceil(e/2.)*2;
		var top = Math.ceil(n);
		var bottom = Math.floor(s);
		for (var lon = left; lon < right; lon += 2) {
			for (var lat = bottom; lat < top; lat += 1) {
				for (slon = lon; slon < lon+2; slon += 2/24.) {
					for (slat = lat; slat < lat + 1; slat += 1/24.) {
						var bounds = [[slat,slon],[slat+1/24.,slon+2/24.]];
						gridLayer.addLayer(L.rectangle(bounds, {color: "#0000ff", weight: 1, fill:false}));
						gridLayer.addLayer(getLabel(slon+(2./48),slat+(1/48.),3));
					}
				}
			}
		}
	}
}
