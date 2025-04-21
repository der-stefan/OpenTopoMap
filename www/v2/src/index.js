////////////////////////////////////////////////////////
//
// OTM Web Frontend - index.js
//
// Entry point with global static UI object and 
// init functions and map event handlers
//
// V 2.00 - 01.01.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import 'leaflet-filelayer';
import 'leaflet/dist/leaflet.css';
import 'leaflet-geosearch/assets/css/leaflet.css';
import 'leaflet-elevation/dist/leaflet-elevation.css';

import { otm_get_context, otm_set_url_context, otm_set_cookie_context } from '../src/otm-context.js';
import { otm_load_localization } from '../src/otm-load-localization.js';
import { otm_init_layers } from '../src/otm-layers.js';
import { otm_create_language_picker } from '../src/otm-ui-language-picker.js';
import { otm_create_info_dropdown } from '../src/otm-ui-info-dropdown.js';
import { otm_init_button_factory, otm_ui_init_controls, otm_ui_show_scale, otm_ui_hide_scale } from '../src/otm-ui-controls.js';
import { otm_init_locate } from '../src/otm-locate.js';
import { otm_create_marker } from '../src/otm-marker.js';

require('../src-images/favicon.ico');
require('leaflet/dist/images/marker-shadow.png');
require('leaflet/dist/images/marker-icon.png');
require('leaflet/dist/images/marker-icon-2x.png');
require('leaflet/dist/images/layers.png');
require('leaflet/dist/images/layers-2x.png');
require('./index.scss');

// global ui object
// ================

var ui = {
  
  // context, this will be stored in the cookie
  ctx: {
    language: 'en',
    mapLatLng: { lat: 47, lng: 11 },
    mapZoom: 5,
    baseLayer: 0,
    overlayLayers: [],
    markerActive: false,
    markerLatLng: { lat: 47, lng: 11 }
  },

  // constants
  c: {
    BASELAYER_OTM: 0,
    BASELAYER_OSM: 1,
    OVERLAYLAYER_LONVIA_HIKE: 0,
    OVERLAYLAYER_LONVIA_BIKE: 1,
    OVERLAYLAYER_QTH: 2
  },
  
  // bounds
  bounds: {
    minZoom: 3,
    maxZoom: 17
  },
  
  // languages & localization
  lang: null,
  loc: null,
  
  // map instance
  map: null,
  
  // map layers, will be initialized by otm_init_layers()
  layers: {
    base: {},
    overlay: {}
  },

  // ui controls
  ctrl: {
    buttonSearch: null,     // search button object
    buttonLocate: null,     // locate button object
    buttonFileLayer: null,  // file layer button object
    buttonMarker: null,     // marker button object
    infoDropdown: null,     // info dropdown object
    scale: null,            // scale control
    languagePicker: null    // language picker control
  },
  
  // search control
  search: {
    active: false,    // active status
    control: null     // current control
  },
  
  // position locate control
  locate: {
    prepare: false,   // prepare status
    active: false,    // active status
    marker: null,     // marker object
    circle: null,     // accuracy circle object
    message: null     // message control object
  },
  
  // marker control
  marker: {
    e: null           // element
  },

  // elevation control
  elevation: {
    control: null,    // current control
    layer: null       // layer
  }
}

// here is the functional code entry point when js is loaded
// =========================================================

// get url & cookie context
otm_get_context();
  
// load localization json, then init map call or abort with alert on load error
otm_load_localization(otm_init, otm_error);

// error abort when language json load failed
function otm_error() {
  alert("Severe Load Error (Localization)");
}

///////////////////////////////////////////////////////////////////////////////////////

function otm_init() {

  // Replace url to clean
  otm_set_url_context();

  // Create a leaflet map instance
  ui.map = L.map('map', {
    doubleClickZoom: true,
    dragging: true,
  }).setView(ui.ctx.mapLatLng, ui.ctx.mapZoom);

  // Set zoom control tooltip texts
  ui.map.zoomControl._zoomInButton.title = ui.loc.zoom.zoom_in_title;
  ui.map.zoomControl._zoomOutButton.title = ui.loc.zoom.zoom_out_title;

  // Init our button factory
  otm_init_button_factory();
  
  // Create info dropdown
  otm_create_info_dropdown();

  // Init the map layers
  otm_init_layers();
  
  // Create language picker
  otm_create_language_picker();
  
  // Show scale control
  otm_ui_show_scale();
  
  // Init all UI controles (buttons left)
  otm_ui_init_controls();
  
  // Init location handling
  otm_init_locate();
  
  // Initial marker display
  if (ui.ctx.markerActive) {
    otm_create_marker(ui.ctx.markerLatLng,true);
  }

  // Install map event handlers
  // Zoom and move
  ui.map.on('moveend zoomend', (e) => {
    ui.ctx.mapZoom = ui.map.getZoom();
    ui.ctx.mapLatLng = ui.map.getCenter();
    otm_set_url_context();
  });
  // Baselayer change
  ui.map.on('baselayerchange', (e) => {
    ui.ctx.baseLayer = ui.loc.layers_base.indexOf(e.name);
    otm_set_cookie_context();
  });
  // Overlay add
  ui.map.on('overlayadd', (e) => {
    var overlayId = ui.loc.layers_overlay.indexOf(e.name);
    if (ui.ctx.overlayLayers.indexOf(overlayId) < 0) {
      ui.ctx.overlayLayers.push(overlayId);
    }
    otm_set_cookie_context();
  });
  // Overlay remove
  ui.map.on('overlayremove', (e) => {
    var overlayId = ui.loc.layers_overlay.indexOf(e.name);
    var overlayPos = ui.ctx.overlayLayers.indexOf(overlayId);
    if (overlayPos >= 0) {
      for (var i=overlayPos; i<ui.ctx.overlayLayers.length-1; i++) {
        ui.ctx.overlayLayers[i] = ui.ctx.overlayLayers[i+1];
      }
      ui.ctx.overlayLayers.pop();
    }
    otm_set_cookie_context();
  });
  
}

// our exports
// ===========
export { ui };
