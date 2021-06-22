////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-ui-message.js
//
// Creation and handling of a message control
// that can be positioned
//
// V 2.00 - 04.01.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import { ui } from '../src/index.js';

// our button factory
// ==================
var messageInited = false;

function otm_init_message_factory() {
  
  // return if factory already created
  if (messageInited) {
    return;
  }
  
  L.Control.Message = L.Control.extend({
    
    // initialize: set options
    initialize:
      function(opts) {
        this._html = (typeof(opts.html) !== undefined) ? opts.html : null;
        this._className = (typeof(opts.className) !== undefined) ? opts.className : '';
        L.setOptions(this, opts);
        messageInited = true;
      },
    
    // create DOM elements & add event handlers
    onAdd: 
      function (map) {
        
        // create control
        this._control = L.DomUtil.create('div', 'leaflet-bar');
        L.DomUtil.addClass(this._control,'otm-message-container');
        if (this._html) {
          L.DomUtil.create('a', this._className, this._control).innerHTML = this._html;
        }
          
        // return created element
        return this._control;
      },

    // mandatory remove function that is empty
    onRemove:
      function (map) {
      }    
  });
}

// our exports
// ===========
export { otm_init_message_factory };
