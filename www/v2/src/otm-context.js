////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-context.js
//
// Get & Set cookie and URL context
//
// V 2.00 - 08.01.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import { ui } from '../src/index.js';
import { otm_decode_maidenhead } from '../src/otm-maidenhead.js';
import Cookies from 'js-cookie';

// get the cookie & url context
// ============================
function otm_get_context() {
  
  // get language from html language attribute
  ui.ctx.language = document.getElementsByTagName("html")[0].getAttribute("lang").toLowerCase().substring(0, 2);
  
  // get the cookie and set context
  var cookieRaw = Cookies.get(OTM_ENV_COOKIE_NAME);
  if (cookieRaw) {
    ui.ctx = JSON.parse(cookieRaw);
  }
  
  // get hash part of url
  var urlhash = location.hash;
  
  // check qth hash
  var r = urlhash.match(/^\#qth=(.*)/i);
  var qth_pos;
  if (r !== null && r.length == 2 && (qth_pos = otm_decode_maidenhead(r[1])) != null) {
    // set to center of qth grid rectangle
    ui.ctx.mapZoom = qth_pos.zoom;
    ui.ctx.mapLatLng.lat = qth_pos.lat;
    ui.ctx.mapLatLng.lng = qth_pos.lng;
    ui.ctx.markerActive = false;
    // show qth grid
    if (ui.ctx.overlayLayers.indexOf(ui.c.OVERLAYLAYER_QTH) < 0) {
      ui.ctx.overlayLayers.push(ui.c.OVERLAYLAYER_QTH);
    }
  }
  else {
    
    // parse normal hash with coords or marker
    var r = urlhash.match(/^\#([a-z]*)=([0-9]{1,2})\/([-+]?[0-9]*\.?[0-9]+)\/([-+]?[0-9]*\.?[0-9]+)/i);
    if (r !== null && r.length == 5) {
      var type = String(r[1]).toLowerCase();
      var zoom = parseInt(r[2]);
      var lat = parseFloat(r[3]);
      var lng = parseFloat(r[4]);
      if (r.length == 5 &&
        ['map','marker'].indexOf(type) > -1 &&
        !isNaN(zoom) &&
        zoom >= ui.bounds.minZoom &&
        zoom <=  ui.bounds.maxZoom &&
        !isNaN(lat) &&
        lat >= -180 &&
        lat <=  180 &&
        !isNaN(lng) &&
        lng >= -90 &&
        lng <=  90) {
          ui.ctx.mapZoom = zoom;
          ui.ctx.mapLatLng.lat = lat;
          ui.ctx.mapLatLng.lng = lng;
          if (type == 'marker') {
            ui.ctx.markerActive = true;
            ui.ctx.markerLatLng.lat = lat;
            ui.ctx.markerLatLng.lng = lng;
          }
        }
      }
    }
  }
  
  // set the cookie context
  // ======================
  function otm_set_cookie_context() {
    Cookies.set(OTM_ENV_COOKIE_NAME, 
      JSON.stringify(ui.ctx), 
      OTM_ENV_DEVELOPMENT ?
      { expires: 14 } :
      { expires: 14, path: '/', domain: OTM_ENV_DOMAIN, samesite: 'none', secure: true });
      // samesite must be none, otherwise ios safari looses the cookie on re-activation of cached page
    }
    
    // set the url + cookie context
    // ============================
    function otm_set_url_context() {
      
      // build url
      var url = OTM_ENV_BROWSERPATH + 
      (ui.ctx.markerActive ? "#marker=" : "#map=") +
      ui.ctx.mapZoom + "/" +
      (ui.ctx.markerActive ? 
        (otm_coord_cut(ui.ctx.markerLatLng.lat) + "/" + otm_coord_cut(ui.ctx.markerLatLng.lng)) : 
        (otm_coord_cut(ui.ctx.mapLatLng.lat) + "/" + otm_coord_cut(ui.ctx.mapLatLng.lng)));     
        
        // replace url
        history.replaceState({},ui.loc.sitehead.title,url);
        
        // set cookie context
        otm_set_cookie_context();
      }
      
      // cut coordinate to recent digits
      // ===============================
      function otm_coord_cut(coord) {
        return coord.toFixed(Math.ceil( 2 * Math.log(ui.ctx.mapZoom) - 1));
      }
      
      // our exports
      // ===========
      export { otm_get_context, otm_set_url_context, otm_set_cookie_context };
      