/*
 * shows a button for creating markers
 * Stefan Erhardt, 2014
 * stefan@opentopomap.org
 *
 * inspired by L.Control.Locate
 */
L.Control.Marker = L.Control.extend({
    options: {
        position: 'topleft',
        titleAdd: "Add marker to map",
		titleRemove: "Remove marker from map"
    },

    onAdd: function (map) {
        var className = 'leaflet-control-marker',
            classNames = className + ' leaflet-control-zoom leaflet-bar leaflet-control',
            container = L.DomUtil.create('div', classNames);

        var self = this;

        var link = L.DomUtil.create('a', 'leaflet-bar-part leaflet-bar-part-single', container);
        link.href = '#';
        link.title = this.options.titleAdd;

        var _log = function(data) {
            if (self.options.debug) {
                console.log(data);
            }
        };
	
		var _markerset = false;

		if(marker) {
			_markerset = true;
			container.className = classNames + ' active';
			link.title = this.options.titleRemove;
		}
		
        L.DomEvent
            .on(link, 'click', L.DomEvent.stopPropagation)
            .on(link, 'click', L.DomEvent.preventDefault)
            .on(link, 'click', function() {
				if(!_markerset) {
            		map._container.style.cursor = 'crosshair';
					link.title = self.options.titleRemove;
                	map.once('click', function (e) {
                		addMarker(e);                	
                	});
				} else {
					link.title = self.options.titleAdd;
					removeMarker();
				}
            });
            
		var addMarker = function (e) {
			//L.marker([e.latlng.lat, e.latlng.lng],{draggable:true}).addTo(map);
			map._container.style.cursor = '';
			var digits=Math.ceil(2*Math.log(map.getZoom())-1);
			window.location.hash="marker="+map.getZoom()+"/"+e.latlng.lat.toFixed(digits)+"/"+e.latlng.lng.toFixed(digits);
			container.className = classNames + ' active';
			_markerset=true
		};

		var removeMarker = function () {
			var digits=Math.ceil(2*Math.log(map.getZoom())-1);
			window.location.hash="map="+map.getZoom()+"/"+map.getCenter().lat.toFixed(digits)+"/"+map.getCenter().lng.toFixed(digits);
			if(marker!=null) {
				map.removeLayer(marker);
				marker=null;
			}
			container.className = classNames;
			_markerset=false;
		};

        return container;
    }
});

L.control.marker = function (options) {
    return new L.Control.Marker(options);
};
