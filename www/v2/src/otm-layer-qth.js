////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-layer-qth.js
//
// QTH Grid overlay layer factory
// based on code of Iván Sánchez Ortega 
// (https://github.com/IvanSanchez)
//
// V 2.00 - 11.01.2021 - Thomas Worbs
//          Created
//          08.07.2021 - Thomas Worbs
//          Extended to 8 letter maidenhead coding
//
////////////////////////////////////////////////////////

// imports & requires
// ==================
import { otm_encode_maidenhead } from '../src/otm-maidenhead.js';

// QTH grid factory
// ================

function otm_init_qth_factory() {
  
  L.QthGrid = L.Layer.extend({
    
    // The default options, customized for QTH
    // =======================================
    options: {
      graticuleLabel: true,             // show the graticule label flag
      opacity: 1,                       // general opacity of all elements (canvas opacity)
      lineWith: 0.5,                    // width of graticule lines
      lineColor: 'rgba(0,0,255,0.65)',   // color of the line
      fontColor: 'rgba(0,0,255,0.9)',   // color of the font
      fontFace: 'Arial, Helvetica, sans-serif', // font face used
      zoomInterval: {                   // our interval control
        longitude: 
        [{ start: 1, end: 4, interval: 20 },
          { start: 5, end: 9, interval: 2 },
          { start: 10, end: 13, interval: 2 / 24 },
          { start: 14, end: 20, interval: 2 / 240 }],
        latitude: 
        [{ start: 1, end: 4, interval: 10 },
            { start: 5, end: 9, interval: 1 },
            { start: 10, end: 13, interval: 1 / 24 },
            { start: 14, end: 20, interval: 1 / 240 }]
          }
        },
        
        // Initialize - handle the options
        // ===============================
        initialize: function (options) {
          
          // get the options
          L.setOptions(this, options);
          
          // prepare zoom intervals
          if (this.options.zoomInterval) {
            if (this.options.zoomInterval.latitude) {
              this.options.latInterval = this.options.zoomInterval.latitude;
              if (!this.options.zoomInterval.longitude) {
                this.options.lngInterval = this.options.zoomInterval.latitude;
              }
            }
            if (this.options.zoomInterval.longitude) {
              this.options.lngInterval = this.options.zoomInterval.longitude;
              if (!this.options.zoomInterval.latitude) {
                this.options.latInterval = this.options.zoomInterval.longitude;
              }
            }
            if (!this.options.latInterval) {
              this.options.latInterval = this.options.zoomInterval;
            }
            if (!this.options.lngInterval) {
              this.options.zoomInterval;
            }
          }
        },
        
        // Add to map public method
        // ========================
        onAdd: function (map) {
          
          // get map instance
          this._map = map;
          
          // create canvas if not done
          if (!this._container) {
            this._createCanvas();
          }
          
          // append our container as pane
          map._panes.overlayPane.appendChild(this._container);
          
          // install event handlers
          map.on('viewreset', this._reRender, this);
          map.on('move', this._reRender, this);
          map.on('moveend', this._reRender, this);
          
          // initial render
          this._reRender();
        },
        
        // Remove from map public method
        // =============================
        onRemove: function (map) {
          
          // remove our container from pane
          map.getPanes().overlayPane.removeChild(this._container);
          
          // uninstall event handlers
          map.off('viewreset', this._reRender, this);
          map.off('move', this._reRender, this);
          map.off('moveend', this._reRender, this);
        },
        
        // add our overlay layer to a map instance
        // =======================================
        addTo: function (map) {
          map.addLayer(this);
          return this;
        },
        
        // set the global opacity of our overlay
        // =====================================
        setOpacity: function (opacity) {
          this.options.opacity = opacity;
          this._updateOpacity();
          return this;
        },
        
        // bring our overlay to the front
        // ==============================
        bringToFront: function () {
          if (this._canvas) {
            this._map._panes.overlayPane.appendChild(this._canvas);
          }
          return this;
        },
        
        // send our overlay to the back
        // ============================
        bringToBack: function () {
          var pane = this._map._panes.overlayPane;
          if (this._canvas) {
            pane.insertBefore(this._canvas, pane.firstChild);
          }
          return this;
        },
        
        // get our attribution
        // ===================
        getAttribution: function () {
          return this.options.attribution;
        },
        
        //////////////////////////////////////
        // private methods start here
        //////////////////////////////////////
        
        // create the basis canvas
        // =======================
        _createCanvas: function () {
          
          // create container with canvas in it
          this._container = L.DomUtil.create('div', 'leaflet-image-layer');
          this._canvas = L.DomUtil.create('canvas', '');
          L.DomUtil.addClass(this._canvas, 'leaflet-zoom-hide');
          this._updateOpacity();
          this._container.appendChild(this._canvas);
          
          // add leaflet specifics
          L.extend(this._canvas, {
            onselectstart: L.Util.falseFn,
            onmousemove: L.Util.falseFn,
            onload: L.bind( () => { this.fire('load'); }, this)
          });
        },
        
        // completely re-render our canvas
        // ===============================
        _reRender: function () {
          
          // set container position to 0 coordinate
          L.DomUtil.setPosition(this._container, this._map.containerPointToLayerPoint([0, 0]));
          
          // set container size
          var size = this._map.getSize();
          this._container.style.width = size.x + 'px';
          this._container.style.height = size.y + 'px';
          
          // set canvas size
          this._canvas.width = size.x;
          this._canvas.height = size.y;
          this._canvas.style.width = size.x + 'px';
          this._canvas.style.height = size.y + 'px';
          
          // calculate graticule interval
          this._fetchInterval();
          
          // render our graticule
          this._render();
        },
        
        // update the global canvas opacity
        // ================================
        _updateOpacity: function () {
          L.DomUtil.setOpacity(this._canvas, this.options.opacity);
        },
        
        // convert latitude to convenient string
        // =====================================
        _latToString: function (lat) {
          
          if (this._currLatInterval > 0.04) {
            lat = Math.round(lat * 100) / 100;
          } else {
            lat = Math.round(lat * 1000) / 1000;
          }
          if (lat < 0) {
            return (lat * -1) + ' S';
          } else if (lat > 0) {
            return lat + ' N';
          }
          return String(lat);
        },
        
        // convert longitude to convenient string
        // ======================================
        _lngToString: function (lng) {
          
          while (lng > 180) {
            lng -= 360;
          }
          while (lng < -180) {
            lng += 360;
          }
          if (this._currLatInterval > 0.04) {
            lng = Math.round(lng * 100) / 100;
          } else {
            lng = Math.round(lng * 1000) / 1000;
          }
          if (lng > 0 && lng < 180) {
            return lng + ' E';
          } else if (lng < 0 && lng > -180) {
            return (lng * -1) + ' W';
          } else if (lng == -180) {
            return String(lng * -1);
          }
          return String(lng);
        },
        
        // fetch graticule interval according to zoom level
        // set to this._currLatInterval + 
        // this._currLngInterval
        // ================================================
        _fetchInterval: function () {
          
          // get map zoom
          var zoom = this._map.getZoom();
          
          // reset intervals on change to force re-calculation
          if (this._currZoom != zoom) {
            this._currLngInterval = 0;
            this._currLatInterval = 0;
            this._currZoom = zoom;
          }
          
          // fetch longitude interval
          if (!this._currLngInterval) {
            try {
              for (var idx in this.options.lngInterval) {
                var dict = this.options.lngInterval[idx];
                if (dict.start <= zoom) {
                  if (dict.end && dict.end >= zoom) {
                    this._currLngInterval = dict.interval;
                    break;
                  }
                }
              }
            } catch (e) {
              this._currLngInterval = 0;
            }
          }
          
          // fetch latitude interval
          if (!this._currLatInterval) {
            try {
              for (var idx in this.options.latInterval) {
                var dict = this.options.latInterval[idx];
                if (dict.start <= zoom) {
                  if (dict.end && dict.end >= zoom) {
                    this._currLatInterval = dict.interval;
                    break;
                  }
                }
              }
            } catch (e) {
              this._currLatInterval = 0;
            }
          }
        },
        
        // our graticule renderer including labels and QTH labels
        // ======================================================
        _render: function () {
          
          var canvas = this._canvas;
          var map = this._map;
          var maidenPrecision;
          
          // fetch graticule intervals when not present
          if (L.Browser.canvas && map) {
            if (!this._currLngInterval || !this._currLatInterval) {
              this._fetchInterval();
            }
            
            // graticule intervals
            var latInterval = this._currLatInterval;
            var lngInterval = this._currLngInterval;

            // maidenhead precision
            if (latInterval >= 9) {
              maidenPrecision = 2;
            } else if (latInterval >= 0.9) {
              maidenPrecision = 4;
            } else if (latInterval >= 0.04) {
              maidenPrecision = 6;
            } else {
              maidenPrecision = 8;
            }
            
            // pixel size of map canvas
            var cv_width_px = canvas.width;
            var cv_height_px = canvas.height;
            
            // get canvas renderer context and invalidate rect
            var ctx = canvas.getContext('2d')
            ctx.clearRect(0, 0, cv_width_px, cv_height_px);
            
            // corner geo coordinates
            var latlon_lt = map.containerPointToLatLng(L.point(0, 0));
            var latlon_rt = map.containerPointToLatLng(L.point(cv_width_px, 0));
            var latlon_rb = map.containerPointToLatLng(L.point(cv_width_px, cv_height_px));
            
            // bottom corner lat
            var _lat_b = latlon_rb.lat;
            
            // top corner lat
            var _lat_t = latlon_lt.lat;
            
            // left corner lng
            var _lon_l = latlon_lt.lng;
            
            // right corner lng
            var _lon_r = latlon_rt.lng;
            
            // adjust lat borders
            if (_lat_b < -90) {
              _lat_b = -90;
            }
            if (_lat_t > 90) {
              _lat_t = 90;
            }
            
            // adjust lon range
            if (_lon_l > 0 && _lon_r < 0) {
              _lon_r += 360;
            }
            
            // render lat with graticule labels
            if (latInterval > 0) {
              for (var i = latInterval; i <= _lat_t; i += latInterval) {
                if (i >= _lat_b) {
                  _render_lat(this, i);
                }
              }
              for (var i = 0; i >= _lat_b; i -= latInterval) {
                if (i <= _lat_t) {
                  _render_lat(this, i);
                }
              }
            }
            
            // render lng with graticule labels and qth labels
            if (lngInterval > 0) {
              for (var i = lngInterval; i <= _lon_r; i += lngInterval) {
                if (i >= _lon_l - lngInterval) {
                  _render_lng(this, i);
                }
              }
              for (var i = 0; i >= _lon_l - lngInterval; i -= lngInterval) {
                if (i <= _lon_r) {
                  _render_lng(this, i);
                }
              }
            }
            
            // render latitude line incl. graticule label
            // ==========================================
            function _render_lat(self, lat_tick) {
              
              // calculate left and right endpoints of the line
              var lineLeft = map.latLngToContainerPoint(L.latLng(lat_tick, _lon_l));
              var lineRight = map.latLngToContainerPoint(L.latLng(lat_tick, _lon_r));
              
              // draw the latitude line
              ctx.lineWidth = self.options.lineWidth;
              ctx.strokeStyle = self.options.lineColor;
              ctx.beginPath();
              ctx.moveTo(lineLeft.x + 1, lineLeft.y);
              ctx.lineTo(lineRight.x - 1, lineRight.y);
              ctx.stroke();
              
              // draw the latitude graticule label
              if (self.options.graticuleLabel) {
                ctx.font = '10px ' + self.options.fontFace;
                var gLabel = self._latToString(lat_tick);
                var labelWidth = ctx.measureText(gLabel).width;
                var labelY = lineLeft.y + 3;
                ctx.fillStyle = self.options.lineColor;
                ctx.fillRect(0, labelY - 9, labelWidth + 4, 12);
                ctx.fillRect(cv_width_px - labelWidth - 4, labelY - 9, labelWidth + 4, 12);
                ctx.textAlign = "left";
                ctx.fillStyle = 'white';
                ctx.fillText(gLabel, 2, labelY);
                ctx.fillText(gLabel, cv_width_px - labelWidth - 2, labelY);
              }
            }
            
            // render qth label
            // ================
            function _render_qth_string(self, lat_tick, lng_tick) {

              // get maidenhead string
              let qths = otm_encode_maidenhead(lat_tick + latInterval / 2, lng_tick + lngInterval / 2, maidenPrecision);

              // calculate graticule rect
              let tl = map.latLngToContainerPoint(L.latLng(lat_tick, lng_tick));
              let br = map.latLngToContainerPoint(L.latLng(lat_tick + latInterval, lng_tick + lngInterval));
              let wi = br.x - tl.x;
              let he = br.y - tl.y;

              // calculate font metrics
              let fontsize;
              if (wi > 400) {
                fontsize = 20;
              } else if (wi > 150) {
                fontsize = 16;
              } else {
                fontsize = 12;
              }
              let tx = tl.x + wi / 2;
              let ty = tl.y + (he + fontsize * 0.75) / 2;

              // draw the string
              ctx.save();
              ctx.font = fontsize + 'px ' + self.options.fontFace; 
              ctx.fontWeight = 800;
              ctx.fillStyle = self.options.fontColor;
              ctx.strokeStyle = 'rgba(255,255,255,0.8)';
              ctx.lineWidth = fontsize / 6;
              ctx.lineJoin = "round";
              ctx.miterLimit = 2;
              ctx.textAlign = "center";
              ctx.strokeText(qths, tx, ty);
              ctx.fillText(qths, tx, ty);
              ctx.restore();
            }
            
            // render longitude line incl. graticule label and qth labels
            // ==========================================================
            function _render_lng(self, lng_tick) {
              
              // calculate top and bottom line endpoints
              var lineBottom = map.latLngToContainerPoint(L.latLng(_lat_b, lng_tick));
              var lineTop = map.latLngToContainerPoint(L.latLng(_lat_t, lng_tick));
              
              // draw the longitude line
              ctx.lineWidth = self.options.lineWidth;
              ctx.strokeStyle = self.options.lineColor;
              ctx.beginPath();
              ctx.moveTo(lineTop.x, 1);
              ctx.lineTo(lineBottom.x, cv_height_px - 1);
              ctx.stroke();
              
              // draw the graticule label
              if (self.options.graticuleLabel) {
                ctx.font = '10px ' + self.options.fontFace;
                var gLabel = self._lngToString(lng_tick);
                var labelWidth = ctx.measureText(gLabel).width;
                ctx.fillStyle = self.options.lineColor;
                ctx.fillRect(lineTop.x - (labelWidth / 2) - 2, 0, labelWidth + 4, 12);
                ctx.fillRect(lineTop.x - (labelWidth / 2) - 2, cv_height_px - 12, labelWidth + 4, 12);
                ctx.fillStyle = 'white';
                ctx.textAlign = "left";
                ctx.fillText(gLabel, lineTop.x - (labelWidth / 2), 9);
                ctx.fillText(gLabel, lineTop.x - (labelWidth / 2), cv_height_px - 3);
              }
              
              // draw the qth labels
              if (latInterval > 0) {
                for (var j = latInterval; j <= _lat_t; j += latInterval) {
                  if (j >= _lat_b - latInterval) {
                    _render_qth_string(self, j, lng_tick);
                  }
                }
                for (var j = 0; j >= _lat_b - latInterval; j -= latInterval) {
                  if (j <= _lat_t) {
                    _render_qth_string(self, j, lng_tick);
                  }
                }
              }
            };
          }
        }      
      }
      );
    }
    
    // our exports
    // ===========
    export { otm_init_qth_factory };
    