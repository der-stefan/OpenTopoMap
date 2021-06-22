////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-ui-info-dropdown.js
//
// Info dropdown control
//
// V 2.00 - 16.06.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import { ui } from '../src/index.js';
import { otm_toggle_search } from '../src/otm-search.js';

// our factory
// ===========
var idInited = false;

function otm_init_info_dropdown_factory() {
  
  // return if factory already created
  if (idInited) {
    return;
  }
  
  L.Control.infoDropdown = L.Control.extend({
    
    // initialize: set options
    initialize:
    function(opts) {
      L.setOptions(this, opts);
      idInited = true;
    },
    
    // create DOM elements & add event handlers
    onAdd: 
    function (map) {
      
      // dropdown status init
      this._dropdown = false;
      
      // create control
      this._control = L.DomUtil.create('div', 'otm-info-dropdown leaflet-bar');
      
      // create logo button
      this._logobutton = L.DomUtil.create('div', 'otm-info-logobutton otm-info-logobutton-visible', this._control);
      
      // create drop area
      this._droparea = L.DomUtil.create('div', 'otm-info-droparea otm-info-droparea-hidden', this._control);
      
      // create info header
      this._item_about = L.DomUtil.create('div', 'otm-info-header', this._droparea);
      
      // create info & legend item
      this._item_about = L.DomUtil.create('a', 'otm-info-item', this._droparea);
      this._item_about.innerHTML = ui.loc.info.about;
      this._item_about.href = ui.loc.info.about_url;
      
      // create impress item
      this._item_impress = L.DomUtil.create('a', 'otm-info-item', this._droparea);
      this._item_impress.innerHTML = ui.loc.info.impress;
      this._item_impress.href = ui.loc.info.impress_url;
      
      // create credits item
      this._item_credits = L.DomUtil.create('a', 'otm-info-item', this._droparea);
      this._item_credits.innerHTML = ui.loc.info.credits;
      this._item_credits.href = ui.loc.info.credits_url;
      
      // create garmin item
      this._item_garmin = L.DomUtil.create('a', 'otm-info-item', this._droparea);
      this._item_garmin.innerHTML = ui.loc.info.garmin;
      this._item_garmin.href = ui.loc.info.garmin_url;
      
      // logobutton mouseover handler
      L.DomEvent.on(this._control, "mouseover pointerdown", (e) => {
        if (!this._dropdown) {
          L.DomUtil.removeClass(this._logobutton,'otm-info-logobutton-visible');
          L.DomUtil.addClass(this._logobutton,'otm-info-logobutton-hidden');
          L.DomUtil.removeClass(this._droparea,'otm-info-droparea-hidden');
          L.DomUtil.addClass(this._droparea,'otm-info-droparea-visible');
          // remove search bar because not sufficient space on mobiles
          if (ui.search.active) {
            otm_toggle_search();
          }
          this._dropdown = true;
        }
      });
      
      // droparea mouseleave handler
      L.DomEvent.on(this._control, "mouseleave", (e) => {
        this.undrop();
      });
      
      // canvas click handler
      ui.map.on("mousedown pointerdown", (e) => {
        if (e.originalEvent.target.id == 'map') {
          this.undrop();
        }
      });
      
      
      // undrop function
      this.undrop = function () {
        if (this._dropdown) {
          L.DomUtil.removeClass(this._logobutton,'otm-info-logobutton-hidden');
          L.DomUtil.addClass(this._logobutton,'otm-info-logobutton-visible');
          L.DomUtil.removeClass(this._droparea,'otm-info-droparea-visible');
          L.DomUtil.addClass(this._droparea,'otm-info-droparea-hidden');
          this._dropdown = false;
        }          
      };
      
      // return created element
      return this._control;
    },
    
    // mandatory remove function that is empty
    onRemove:
    function (map) {
    }    
  });
}

function otm_create_info_dropdown() {
  
  otm_init_info_dropdown_factory();
  
  ui.ctrl.infoDropdown = new L.Control.infoDropdown({
    position: 'topright'
  });
  
  ui.ctrl.infoDropdown.addTo(ui.map);
}

// our exports
// ===========
export { otm_create_info_dropdown };
