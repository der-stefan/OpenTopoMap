////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-ui-controls.js
//
// Creation and handling of all UI controls including 
// scale control but excluding map layers & language
// picker
//
// V 2.00 - 04.01.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import { ui } from '../src/index.js';
import { otm_toggle_search } from '../src/otm-search.js';
import { otm_toggle_locate } from '../src/otm-locate.js';
import { otm_init_trackloading } from '../src/otm-track.js';
import { otm_toggle_marker } from '../src/otm-marker.js';

// our button factory
// ==================
function otm_init_button_factory() {
  
  L.Control.Button = L.Control.extend({
    
    statics: {
      TITLE: '',
      LABEL: ''
    },

    // initialize: set options
    initialize:
    function(opts) {
      this._icon = (typeof(opts.icon) !== undefined) ? opts.icon : null;
      this._title = (typeof(opts.title) !== undefined) ? opts.title : "";
      this._clickhandler = (typeof(opts.clickhandler) !== undefined) ? opts.clickhandler : null;
      L.setOptions(this, opts);
      
      this._button = null;
      this._button_a = null;
      this._toggleState = false;
    },
    
    // create DOM elements & add event handlers
    onAdd: 
    function (map) {
      
      // create button dom
      this._button = L.DomUtil.create('div', 'leaflet-bar');
      if (this._icon) {
        this._button_a = L.DomUtil.create('a', 'otm-button otm-button-' + this._icon, this._button);
        this._button_a.href = '#';
        this._button_a.title = this._title;
      }
      
      // add click handler
      if (this._clickhandler) {
        L.DomEvent.on(this._button, "pointerdown", (e) => {
          this._clickhandler(e);
          L.DomEvent.stop(e);
        });
      }
      
      // add click + doubleclick handler to prevent map zoom
      L.DomEvent.on(this._button, "click dblclick", (e) => {
        L.DomEvent.stop(e);
      });
      
      // return created element
      return this._button;
    },
    
    // mandatory remove function that is empty
    onRemove:
    function (map) {
    },
    
    // our toggle status setter
    setToggleState:
    function (state) {
      this._toggleState = state;
      if (this._button_a) {
        if (state) {
          L.DomUtil.addClass(this._button_a,'otm-button-toggled');
          L.DomUtil.removeClass(this._button_a,'otm-button-' + this._icon);
          L.DomUtil.addClass(this._button_a,'otm-button-' + this._icon + '-w');
        }
        else {
          L.DomUtil.removeClass(this._button_a,'otm-button-toggled');            
          L.DomUtil.removeClass(this._button_a,'otm-button-' + this._icon + '-w');
          L.DomUtil.addClass(this._button_a,'otm-button-' + this._icon);
        }
      }
    },
    
  });
}

// ctrl button instances
// =====================
const otm_button_search = function (opts) {
  opts.icon = 'search';
  opts.title = ui.loc.search.title;
  return new L.Control.Button(opts);
}

const otm_button_target = function (opts) {
  opts.icon = 'target';
  opts.title = ui.loc.locate.title;
  return new L.Control.Button(opts);
}

const otm_button_marker = function (opts) {
  opts.icon = 'marker';
  opts.title = ui.loc.marker.title;
  return new L.Control.Button(opts);
}

// init function for UI controls
// =============================
function otm_ui_init_controls() {

  // Add marker button
  ui.ctrl.buttonMarker = otm_button_marker({ 
    position: 'topleft',
    clickhandler: otm_toggle_marker
  }).addTo(ui.map);

  // Add search button
  ui.ctrl.buttonSearch = otm_button_search({ 
    position: 'topleft',
    clickhandler: otm_toggle_search
  }).addTo(ui.map);
  
  // Add locate (target) button
  ui.ctrl.buttonLocate = otm_button_target({ 
    position: 'topleft',
    clickhandler: otm_toggle_locate
  }).addTo(ui.map);
  
  // Add file layer load button
  otm_init_trackloading();
}

// show scale control
// ==================
function otm_ui_show_scale() {
  ui.ctrl.scale = L.control.scale({ maxWidth: 200, metric: true, imperial: false }).addTo(ui.map);
}

// hide scale control
// ==================
function otm_ui_hide_scale() {
  if (ui.ctrl.scale) {
    ui.ctrl.scale.remove();
    ui.ctrl.scale = null;
  }
}

// our exports
// ===========
export { otm_init_button_factory, otm_ui_init_controls, otm_ui_show_scale, otm_ui_hide_scale };
