////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-track.js
//
// Loading and handling of all gpx, kml, geojson
// tracks including elevation profiles 
//
// V 2.00 - 13.05.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import 'leaflet-filelayer';
import 'leaflet-elevation';
import { ui } from '../src/index.js';

// init track load button and geojson layer
// ========================================
function otm_init_trackloading() {
  
  // FileLayer tooltip
  L.Control.FileLayerLoad.TITLE = ui.loc.tracks.title;
  
  // Create elevation control
  ui.elevation.control = L.control.elevation({
    position: "bottomright",
    theme: "otm-theme",
    width: 600,
    height: 160,
    heightFactor: 1,
    margins: {
      top: 24,
      right: 24,
      bottom: 30,
      left: 40
    },
    detached: false,
    distance: true,
    altitude: true,
    slope: false,
    speed: false,
    time: false,
    acceleration: false,
    summary: false,
    legend: false,
    collapsed: true,
		autohide: false,
    responsive: false,
    ruler: false
  });
  ui.elevation.control.addTo(ui.map);
  ui.elevation.control.hide();

  // Add file layer load button
  ui.ctrl.buttonFileLayer = L.Control.fileLayerLoad({

    layerOptions: {

      // line style
      style: {
        color: '#FF1010',
        opacity: 0.95,
        weight: 3,
        clickable: false
      },
      
      // single feature points style
      pointToLayer:
      function(feature, latlng) {
        return L.circleMarker(latlng, {
          color: '#FF1010',
          radius: 8
        });
      },

      // elevation points adder
      onEachFeature: function(d, layer) {
        ui.elevation.control.addData(d, layer);
      },
    },
    
    //addToMap: true,
    fileSizeLimit: 1024 * 10,
    formats: [
      '.geojson',
      '.json',
      '.kml',
      '.gpx'
    ]
  })
  
  // add the load button to the map
  ui.ctrl.buttonFileLayer.addTo(ui.map);

  // loading error event handler
  ui.ctrl.buttonFileLayer.loader.on('data:error', function(e) {
    ui.elevation.control.hide();
    if (ui.elevation.layer) {
      ui.elevation.layer.remove();
    }
    alert(ui.loc.tracks.errmsg + e.error.message);
  });

  // start loading event handler
  ui.ctrl.buttonFileLayer.loader.on('data:loading', function(e) {
    ui.elevation.control.hide();
    ui.elevation.control.clear();
  });
  
  // loaded event handler
  ui.ctrl.buttonFileLayer.loader.on('data:loaded', function (e) {
		if (ui.elevation.layer) {
      ui.elevation.layer.remove()
    }
    ui.elevation.layer = e.layer;
		if (!ui.elevation.control._map) {
      ui.elevation.control.addTo(ui.map);
    }
		else {
      ui.elevation.control.redraw();
      
    }
    ui.elevation.control.show();
    ui.elevation.control._expand();
  });
  
  // replace button content of file layer
  var els = document.getElementsByClassName("leaflet-control-filelayer");
  if (els.length > 1) {
    L.DomUtil.empty(els[1]);
    L.DomUtil.addClass(els[1], 'otm-button-waypoints');
  }
}

// our exports
// ===========
export { otm_init_trackloading };
