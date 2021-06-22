////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-search.js
//
// All geocoder (OTM Nominatim) search functions
//
// V 2.00 - 03.05.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import { GeoSearchControl, OpenStreetMapProvider } from 'leaflet-geosearch';
import { ui } from '../src/index.js';
import { otm_set_markerpos } from '../src/otm-marker.js';

// toggle search function (called by the control on click)
// =======================================================
function otm_toggle_search() {
  
  if (ui.search.active) {
    remove_serach_control();
    ui.search.active = false;
  }
  else {
    add_serach_control();
    ui.ctrl.infoDropdown.undrop();
    ui.search.active = true;
  }
  ui.ctrl.buttonSearch.setToggleState(ui.search.active);
}

// add search control
function add_serach_control() {
  ui.search.control = new GeoSearchControl({
    provider: new OpenStreetMapProvider(),
    style: 'bar',
    showMarker: false,
    showPopup: false,
    autoClose: false,
    updateMap: false,
    searchLabel: ui.loc.search.label
  });
  ui.map.addControl(ui.search.control);
  ui.map.on('geosearch/showlocation', e => {
    otm_set_markerpos( {lat: e.location.y, lng: e.location.x } );
  });
  document.getElementsByClassName('glass')[0].focus();
}

// remove search control
function remove_serach_control() {
  ui.map.off('geosearch/showlocation');
  ui.map.removeControl(ui.search.control);
  ui.search.control = null;
}

// our exports
// ===========
export { otm_toggle_search };
