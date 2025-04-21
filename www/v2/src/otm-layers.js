////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-layers.js
//
// Definition and initialization of all map base and 
// overlay layers, creation of layer control
//
// V 2.00 - 04.01.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import { ui } from '../src/index.js';
import { otm_init_qth_factory } from '../src/otm-layer-qth.js';

// init function installing handlers
// =================================
function otm_init_layers() {

  // layer DEFINITIONS
  // credits prefix
  const credits_pre = '<a href="' + ui.loc.info.impress_url + '">' + ui.loc.info.impress_short + '</a> | <a href="' +
                      ui.loc.info.credits_url + '">' + ui.loc.info.credits_short + '</a> | ';

  // OTM base layer object
  ui.layers.base[ui.loc.layers_base[ui.c.BASELAYER_OTM]] = new L.TileLayer(
    'https://opentopomap.org/{z}/{x}/{y}.png', {
      minZoom: ui.bounds.minZoom,
      maxZoom: ui.bounds.maxZoom,
      attribution: credits_pre + ui.loc.c.map_data + 
                   ': <a href="https://openstreetmap.org">OpenStreetMap</a>, <a href="http://viewfinderpanoramas.org">SRTM</a> | ' + 
                   ui.loc.c.map_imagery + 
                   ': <a href="https://opentopomap.org">OpenTopoMap</a>, &copy; <a href="https://creativecommons.org/licenses/by-sa/3.0/">CC-BY-SA</a>'
    });

  // OSM layer object
  ui.layers.base[ui.loc.layers_base[ui.c.BASELAYER_OSM]] = new L.TileLayer(
    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      minZoom: ui.bounds.minZoom,
      maxZoom: ui.bounds.maxZoom,
      attribution: credits_pre + '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> ' + ui.loc.c.contributors
    });

  // Lonvia hiking
  ui.layers.overlay[ui.loc.layers_overlay[ui.c.OVERLAYLAYER_LONVIA_HIKE]] = new L.TileLayer(
    'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png', {
      maxZoom: ui.bounds.maxZoom,
      attribution: ui.loc.c.hikeroutes + ' &copy; Lonvia',
      opacity: 0.7
    });

  // Lonvia cycling
  ui.layers.overlay[ui.loc.layers_overlay[ui.c.OVERLAYLAYER_LONVIA_BIKE]] = new L.TileLayer(
    'http://tile.waymarkedtrails.org/cycling/{z}/{x}/{y}.png', {
      maxZoom: ui.bounds.maxZoom,
      attribution: ui.loc.c.bikeroutes + ' &copy; Lonvia',
      opacity: 0.7
    });

  // QTH Grid
  otm_init_qth_factory();
  ui.layers.overlay[ui.loc.layers_overlay[ui.c.OVERLAYLAYER_QTH]] = new L.QthGrid(
  {
    showLabel: true
  });
  
  // Add active baselayer
  ui.layers.base[ui.loc.layers_base[ui.ctx.baseLayer]].addTo(ui.map);
  
  // Add active overlays
  ui.ctx.overlayLayers.forEach( oid => {
    ui.layers.overlay[ui.loc.layers_overlay[oid]].addTo(ui.map);
  });

  // Add the layer control
  L.control.layers(ui.layers.base, ui.layers.overlay).addTo(ui.map);
}

// our exports
// ===========
export { otm_init_layers };
