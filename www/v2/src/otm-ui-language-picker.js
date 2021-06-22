////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-ui-language-picker.js
//
// Language picker control
//
// V 2.00 - 05.01.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import { ui } from '../src/index.js';
import { otm_set_cookie_context } from '../src/otm-context.js';

require.context('../src-images/', false, /f-.*\.(svg)$/);

// our button factory
// ==================
var lpInited = false;

function otm_init_language_picker_factory() {
  
  // return if factory already created
  if (lpInited) {
    return;
  }
  
  L.Control.LanguagePicker = L.Control.extend({
    
    // initialize: set options
    initialize:
      function(opts) {
        this._languages = (typeof(opts.languages) !== undefined) ? opts.languages : ['en'];
        this._language = (typeof(opts.language) !== undefined) ? opts.language : 'en';
        this._onSelectionChange = (typeof(opts.onSelectionChange) !== undefined) ? opts.onSelectionChange : onSelectionChange;
        L.setOptions(this, opts);
        lpInited = true;
      },
    
    // create DOM elements & add event handlers
    onAdd: 
      function (map) {
        
        // dropped status init
        this._dropped = false;
        
        // create control
        this._control = L.DomUtil.create('div', 'otm-lang-picker leaflet-bar');
        this._button = L.DomUtil.create('div', 'otm-lang-picker-button', this._control);
        this._button.innerHTML = '<img src="' + OTM_ENV_BROWSERPATH + 'i/f-' + this._language + '.svg" />';
        this._dropdown = L.DomUtil.create('div', 'otm-lang-picker-dropdown', this._control);
        
        // main button click handler
        L.DomEvent.on(this._button, "pointerdown", (e) => {
          if (this._dropped) {
            L.DomUtil.removeClass(this._dropdown,'dropped');
            this._dropped = false;
          }
          else {
            L.DomUtil.addClass(this._dropdown,'dropped');
            this._dropped = true;
          }
          L.DomEvent.stop(e);
        });
        
        // canvas click handler
        ui.map.on("mousedown pointerdown", (e) => {
          if (e.originalEvent.target.id == 'map' && this._dropped) {
            L.DomUtil.removeClass(this._dropdown,'dropped');
            this._dropped = false;
          }          
        });
        
        // add the list items with event handling
        this._languages.forEach( (la) => {
          var entry = L.DomUtil.create('div', 'otm-lang-picker-item', this._dropdown)
          entry.innerHTML = '<img src="' + OTM_ENV_BROWSERPATH + 'i/f-' + la + '.svg" />';
          L.DomEvent.on(entry, "mousedown touchstart", (e) => {
            if (la != this._language) {
              this._language = la;
              this._button.innerHTML = '<img src="' + OTM_ENV_BROWSERPATH + 'i/f-' + la + '.svg" />';
              if (this._onSelectionChange) {
                this._onSelectionChange(la);
              }
            }
            L.DomUtil.removeClass(this._dropdown,'dropped');
            this._dropped = false;
            L.DomEvent.stop(e);
          });
        });
          
        // return created element
        return this._control;
      },

    // mandatory remove function that is empty
    onRemove:
      function (map) {
      }    
  });
}

function otm_create_language_picker() {
  
  otm_init_language_picker_factory();

  ui.ctrl.languagePicker = new L.Control.LanguagePicker({
    languages: ui.lang.languages,
    language: ui.ctx.language,
    onSelectionChange: (la) => {
      ui.ctx.language = la;
      otm_set_cookie_context();
      location.reload();
    },
    position: 'topright'
  });

  ui.ctrl.languagePicker.addTo(ui.map);
}

// our exports
// ===========
export { otm_create_language_picker };
