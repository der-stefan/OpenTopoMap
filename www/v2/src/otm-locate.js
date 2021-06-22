////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-locate.js
//
// All position location functions
//
// V 2.00 - 04.01.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import { ui } from '../src/index.js';
import { otm_init_message_factory } from '../src/otm-ui-message.js';
import { otm_ui_show_scale, otm_ui_hide_scale } from '../src/otm-ui-controls.js';


// init function installing handlers
// =================================
function otm_init_locate() {
  ui.map.on('locationfound', onLocationFound);
  ui.map.on('locationerror', onLocationError);
}

// toggle locate function (called by the control on click)
// =======================================================
function otm_toggle_locate() {
  
  if (!ui.locate.prepare) {
    if (ui.locate.active) {
      cancelLocate();
    }
    else {
      otm_init_message_factory();
      showLocateMessage();
      ui.map.locate({watch: true, setView: false, timeout: 20000, maxZoom: 17, enableHighAccuracy: true});
      ui.locate.prepare = true;
    }
  }
  ui.ctrl.buttonLocate.setToggleState(ui.locate.prepare || ui.locate.active);
}

// location found event handler
// ============================
function onLocationFound(e) {

  // we are out of preparation phase
  ui.locate.prepare = false;
  
  // remove message
  hideLocateMessage();
  
  if (ui.locate.active) {
    
    // update only
    ui.locate.marker.setLatLng(e.latlng);
    ui.locate.circle.setLatLng(e.latlng);
    ui.locate.circle.setRadius(e.accuracy);
  }
  else {
    
    // here we go to set up the things
    // create div icon
    var lIcon = L.divIcon({className: 'otm-marker-location'});
    
    // zoom to location
    var zoom = ui.map.getZoom();
    if (zoom < 13) {
      zoom = 13;
    }
    ui.map.setView(e.latlng, zoom);
    
    // create location marker
    ui.locate.marker = L.marker(e.latlng, {
      icon: lIcon,
      interactive: false
    }).addTo(ui.map);
    
    // create accuracy circle
    ui.locate.circle = L.circle(e.latlng, e.accuracy, {
      interactive: false,
      className: 'otm-marker-circle'
    }).addTo(ui.map);
    
    // set active flag
    ui.locate.active = true;
  }
}

// location error event handler
// ============================
function onLocationError(e) {
  
  // remove message
  hideLocateMessage();

  // alert & cancel locate
  var eCode = e.code;
  if (eCode > 2) {
    eCode = 2;
  }
  alert(ui.loc.locate.errors[eCode] + ' (' + e.code + ')');
  cancelLocate();
}

// location tracking cancellation procedure
// ========================================
function cancelLocate() {
  
  // stop location by leaflet
  ui.map.stopLocate();
  
  // remove marker and circle
  if (ui.locate.marker) {
    ui.locate.marker.remove();
  }
  if (ui.locate.circle) {
    ui.locate.circle.remove();
  }
  
  // reset status
  ui.locate.prepare = false;
  ui.locate.active = false;
  ui.locate.marker = null;
  ui.locate.circle = null;
  
  // untoggle button
  ui.ctrl.buttonLocate.setToggleState(false);
}

// show locate message
// ===================
function showLocateMessage() {
  otm_ui_hide_scale();
  otm_init_message_factory();
  ui.locate.message = new L.Control.Message({
    html: ui.loc.locate.message_locating + '<div class="otm-message-spinner"></div>', 
    className: 'otm-message-location', 
    position: 'bottomleft'});
  ui.locate.message.addTo(ui.map);
}

// hide locate message
// ===================
function hideLocateMessage() {
  if (ui.locate.message) {
    ui.locate.message.remove();
    ui.locate.message = null;
    otm_ui_show_scale();
  }
}

// our exports
// ===========
export { otm_init_locate, otm_toggle_locate };
