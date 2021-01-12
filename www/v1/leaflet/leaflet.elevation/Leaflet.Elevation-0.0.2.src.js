L.Control.Elevation = L.Control.extend({
    options: {
        position: "topright",
        theme: "lime-theme",
        width: 600,
        height: 175,
        margins: {
            top: 10,
            right: 20,
            bottom: 30,
            left: 60
        },
        useHeightIndicator: true,
        interpolation: "linear",
        hoverNumber: {
            decimalsX: 3,
            decimalsY: 0,
            formatter: undefined
        },
        xTicks: undefined,
        yTicks: undefined,
        collapsed: false,
        yAxisMin: undefined,
        yAxisMax: undefined,
        forceAxisBounds: false
    },

    onRemove: function(map) {
        this._container = null;
    },

    onAdd: function(map) {
        this._map = map;

        var opts = this.options;
        var margin = opts.margins;
        opts.xTicks = opts.xTicks || Math.round(this._width() / 75);
        opts.yTicks = opts.yTicks || Math.round(this._height() / 30);
        opts.hoverNumber.formatter = opts.hoverNumber.formatter || this._formatter;

        //append theme name on body
        d3.select("body").classed(opts.theme, true);

        var x = this._x = d3.scale.linear()
            .range([0, this._width()]);

        var y = this._y = d3.scale.linear()
            .range([this._height(), 0]);

        var area = this._area = d3.svg.area()
            .interpolate(opts.interpolation)
            .x(function(d) {
                return x(d.dist);
            })
            .y0(this._height())
            .y1(function(d) {
                return y(d.altitude);
            });

        var container = this._container = L.DomUtil.create("div", "elevation");

        this._initToggle();

        var cont = d3.select(container);
        cont.attr("width", opts.width);
        var svg = cont.append("svg");
        svg.attr("width", opts.width)
            .attr("class", "background")
            .attr("height", opts.height)
            .append("g")
            .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

        var line = d3.svg.line();
        line = line
            .x(function(d) {
                return d3.mouse(svg.select("g"))[0];
            })
            .y(function(d) {
                return this._height();
            });

        var g = d3.select(this._container).select("svg").select("g");

        this._areapath = g.append("path")
            .attr("class", "area");

        var background = this._background = g.append("rect")
            .attr("width", this._width())
            .attr("height", this._height())
            .style("fill", "none")
            .style("stroke", "none")
            .style("pointer-events", "all");

        if (L.Browser.touch) {

            background.on("touchmove.drag", this._dragHandler.bind(this)).
            on("touchstart.drag", this._dragStartHandler.bind(this)).
            on("touchstart.focus", this._mousemoveHandler.bind(this));
            L.DomEvent.on(this._container, 'touchend', this._dragEndHandler, this);

        } else {

            background.on("mousemove.focus", this._mousemoveHandler.bind(this)).
            on("mouseout.focus", this._mouseoutHandler.bind(this)).
            on("mousedown.drag", this._dragStartHandler.bind(this)).
            on("mousemove.drag", this._dragHandler.bind(this));
            L.DomEvent.on(this._container, 'mouseup', this._dragEndHandler, this);

        }

        this._xaxisgraphicnode = g.append("g");
        this._yaxisgraphicnode = g.append("g");
        this._appendXaxis(this._xaxisgraphicnode);
        this._appendYaxis(this._yaxisgraphicnode);

        var focusG = this._focusG = g.append("g");
        this._mousefocus = focusG.append('svg:line')
            .attr('class', 'mouse-focus-line')
            .attr('x2', '0')
            .attr('y2', '0')
            .attr('x1', '0')
            .attr('y1', '0');
        this._focuslabelX = focusG.append("svg:text")
            .style("pointer-events", "none")
            .attr("class", "mouse-focus-label-x");
        this._focuslabelY = focusG.append("svg:text")
            .style("pointer-events", "none")
            .attr("class", "mouse-focus-label-y");

        if (this._data) {
            this._applyData();
        }

        return container;
    },

    _dragHandler: function() {

        //we don´t want map events to occur here
        d3.event.preventDefault();
        d3.event.stopPropagation();

        this._gotDragged = true;

        this._drawDragRectangle();

    },

    /*
     * Draws the currently dragged rectabgle over the chart.
     */
    _drawDragRectangle: function() {

        if (!this._dragStartCoords) {
            return;
        }

        var dragEndCoords = this._dragCurrentCoords = d3.mouse(this._background.node());

        var x1 = Math.min(this._dragStartCoords[0], dragEndCoords[0]),
            x2 = Math.max(this._dragStartCoords[0], dragEndCoords[0]);

        if (!this._dragRectangle && !this._dragRectangleG) {
            var g = d3.select(this._container).select("svg").select("g");

            this._dragRectangleG = g.append("g");

            this._dragRectangle = this._dragRectangleG.append("rect")
                .attr("width", x2 - x1)
                .attr("height", this._height())
                .attr("x", x1)
                .attr('class', 'mouse-drag')
                .style("pointer-events", "none");
        } else {
            this._dragRectangle.attr("width", x2 - x1)
                .attr("x", x1);
        }

    },

    /*
     * Removes the drag rectangle and zoms back to the total extent of the data.
     */
    _resetDrag: function() {

        if (this._dragRectangleG) {

            this._dragRectangleG.remove();
            this._dragRectangleG = null;
            this._dragRectangle = null;

            this._hidePositionMarker();

            this._map.fitBounds(this._fullExtent);

        }

    },

    /*
     * Handles end of dragg operations. Zooms the map to the selected items extent.
     */
    _dragEndHandler: function() {

        if (!this._dragStartCoords || !this._gotDragged) {
            this._dragStartCoords = null;
            this._gotDragged = false;
            this._resetDrag();
            return;
        }

        this._hidePositionMarker();

        var item1 = this._findItemForX(this._dragStartCoords[0]),
            item2 = this._findItemForX(this._dragCurrentCoords[0]);

        this._fitSection(item1, item2);

        this._dragStartCoords = null;
        this._gotDragged = false;

    },

    _dragStartHandler: function() {

        d3.event.preventDefault();
        d3.event.stopPropagation();

        this._gotDragged = false;

        this._dragStartCoords = d3.mouse(this._background.node());

    },

    /*
     * Finds a data entry for a given x-coordinate of the diagram
     */
    _findItemForX: function(x) {
        var bisect = d3.bisector(function(d) {
            return d.dist;
        }).left;
        var xinvert = this._x.invert(x);
        return bisect(this._data, xinvert);
    },

    /** Make the map fit the route section between given indexes. */
    _fitSection: function(index1, index2) {

        var start = Math.min(index1, index2),
            end = Math.max(index1, index2);

        var ext = this._calculateFullExtent(this._data.slice(start, end));

        this._map.fitBounds(ext);

    },

    _initToggle: function() {

        /* inspired by L.Control.Layers */

        var container = this._container;

        //Makes this work on IE10 Touch devices by stopping it from firing a mouseout event when the touch is released
        container.setAttribute('aria-haspopup', true);

        if (!L.Browser.touch) {
            L.DomEvent
                .disableClickPropagation(container);
            //.disableScrollPropagation(container);
        } else {
            L.DomEvent.on(container, 'click', L.DomEvent.stopPropagation);
        }

        if (this.options.collapsed) {
            this._collapse();

            if (!L.Browser.android) {
                L.DomEvent
                    .on(container, 'mouseover', this._expand, this)
                    .on(container, 'mouseout', this._collapse, this);
            }
            var link = this._button = L.DomUtil.create('a', 'elevation-toggle', container);
            link.href = '#';
            link.title = 'Elevation';

            if (L.Browser.touch) {
                L.DomEvent
                    .on(link, 'click', L.DomEvent.stop)
                    .on(link, 'click', this._expand, this);
            } else {
                L.DomEvent.on(link, 'focus', this._expand, this);
            }

            this._map.on('click', this._collapse, this);
            // TODO keyboard accessibility
        }
    },

    _expand: function() {
        this._container.className = this._container.className.replace(' elevation-collapsed', '');
    },

    _collapse: function() {
        L.DomUtil.addClass(this._container, 'elevation-collapsed');
    },

    _width: function() {
        var opts = this.options;
        return opts.width - opts.margins.left - opts.margins.right;
    },

    _height: function() {
        var opts = this.options;
        return opts.height - opts.margins.top - opts.margins.bottom;
    },

    /*
     * Fromatting funciton using the given decimals and seperator
     */
    _formatter: function(num, dec, sep) {
        var res;
        if (dec === 0) {
            res = Math.round(num) + "";
        } else {
            res = L.Util.formatNum(num, dec) + "";
        }
        var numbers = res.split(".");
        if (numbers[1]) {
            var d = dec - numbers[1].length;
            for (; d > 0; d--) {
                numbers[1] += "0";
            }
            res = numbers.join(sep || ".");
        }
        return res;
    },

    _appendYaxis: function(y) {
        y.attr("class", "y axis")
            .call(d3.svg.axis()
                .scale(this._y)
                .ticks(this.options.yTicks)
                .orient("left"))
            .append("text")
            .attr("x", -35)
            .attr("y", 3)
            .style("text-anchor", "end")
            .text("m");
    },

    _appendXaxis: function(x) {
        x.attr("class", "x axis")
            .attr("transform", "translate(0," + this._height() + ")")
            .call(d3.svg.axis()
                .scale(this._x)
                .ticks(this.options.xTicks)
                .orient("bottom"))
            .append("text")
            .attr("x", this._width() + 20)
            .attr("y", 15)
            .style("text-anchor", "end")
            .text("km");
    },

    _updateAxis: function() {
        this._xaxisgraphicnode.selectAll("g").remove();
        this._xaxisgraphicnode.selectAll("path").remove();
        this._xaxisgraphicnode.selectAll("text").remove();
        this._yaxisgraphicnode.selectAll("g").remove();
        this._yaxisgraphicnode.selectAll("path").remove();
        this._yaxisgraphicnode.selectAll("text").remove();
        this._appendXaxis(this._xaxisgraphicnode);
        this._appendYaxis(this._yaxisgraphicnode);
    },

    _mouseoutHandler: function() {

        this._hidePositionMarker();

    },

    /*
     * Hides the position-/heigth indication marker drawn onto the map
     */
    _hidePositionMarker: function() {

        if (this._marker) {
            this._map.removeLayer(this._marker);
            this._marker = null;
        }
        if (this._mouseHeightFocus) {
            this._mouseHeightFocus.style("visibility", "hidden");
            this._mouseHeightFocusLabel.style("visibility", "hidden");
        }
        if (this._pointG) {
            this._pointG.style("visibility", "hidden");
        }
        this._focusG.style("visibility", "hidden");

    },

    /*
     * Handles the moueseover the chart and displays distance and altitude level
     */
    _mousemoveHandler: function(d, i, ctx) {
        if (!this._data || this._data.length === 0) {
            return;
        }
        var coords = d3.mouse(this._background.node());
        var opts = this.options;
        this._focusG.style("visibility", "visible");
        this._mousefocus.attr('x1', coords[0])
            .attr('y1', 0)
            .attr('x2', coords[0])
            .attr('y2', this._height())
            .classed('hidden', false);
        var bisect = d3.bisector(function(d) {
            return d.dist;
        }).left;

        var item = this._data[this._findItemForX(coords[0])],
            alt = item.altitude,
            dist = item.dist,
            ll = item.latlng,
            numY = opts.hoverNumber.formatter(alt, opts.hoverNumber.decimalsY),
            numX = opts.hoverNumber.formatter(dist, opts.hoverNumber.decimalsX);

        this._focuslabelX.attr("x", coords[0])
            .text(numY + " m");
        this._focuslabelY.attr("y", this._height() - 5)
            .attr("x", coords[0])
            .text(numX + " km");

        var layerpoint = this._map.latLngToLayerPoint(ll);

        //if we use a height indicator we create one with SVG
        //otherwise we show a marker
        if (opts.useHeightIndicator) {

            if (!this._mouseHeightFocus) {

                var heightG = d3.select(".leaflet-overlay-pane svg")
                    .append("g");
                this._mouseHeightFocus = heightG.append('svg:line')
                    .attr('class', 'height-focus line')
                    .attr('x2', '0')
                    .attr('y2', '0')
                    .attr('x1', '0')
                    .attr('y1', '0');

                var pointG = this._pointG = heightG.append("g");
                pointG.append("svg:circle")
                    .attr("r", 6)
                    .attr("cx", 0)
                    .attr("cy", 0)
                    .attr("class", "height-focus circle-lower");

                this._mouseHeightFocusLabel = heightG.append("svg:text")
                    .attr("class", "height-focus-label")
                    .style("pointer-events", "none");

            }

            var normalizedAlt = this._height() / this._maxElevation * alt;
            var normalizedY = layerpoint.y - normalizedAlt;
            this._mouseHeightFocus.attr("x1", layerpoint.x)
                .attr("x2", layerpoint.x)
                .attr("y1", layerpoint.y)
                .attr("y2", normalizedY)
                .style("visibility", "visible");

            this._pointG.attr("transform", "translate(" + layerpoint.x + "," + layerpoint.y + ")")
                .style("visibility", "visible");

            this._mouseHeightFocusLabel.attr("x", layerpoint.x)
                .attr("y", normalizedY)
                .text(alt + " m")
                .style("visibility", "visible");

        } else {

            if (!this._marker) {

                this._marker = new L.Marker(ll).addTo(this._map);

            } else {

                this._marker.setLatLng(ll);

            }

        }

    },

    /*
     * Parsing of GeoJSON data lines and their elevation in z-coordinate
     */
    _addGeoJSONData: function(coords) {
        if (coords) {
            var data = this._data || [];
            var dist = this._dist || 0;
            var ele = this._maxElevation || 0;
            for (var i = 0; i < coords.length; i++) {
                var s = new L.LatLng(coords[i][1], coords[i][0]);
                var e = new L.LatLng(coords[i ? i - 1 : 0][1], coords[i ? i - 1 : 0][0]);
                var newdist = s.distanceTo(e);
                dist = dist + Math.round(newdist / 1000 * 100000) / 100000;
                ele = ele < coords[i][2] ? coords[i][2] : ele;
                data.push({
                    dist: dist,
                    altitude: coords[i][2],
                    x: coords[i][0],
                    y: coords[i][1],
                    latlng: s
                });
            }
            this._dist = dist;
            this._data = data;
            this._maxElevation = ele;
        }
    },

    /*
     * Parsing function for GPX data as used by https://github.com/mpetazzoni/leaflet-gpx
     */
    _addGPXdata: function(coords) {
        if (coords) {
            var data = this._data || [];
            var dist = this._dist || 0;
            var ele = this._maxElevation || 0;
            for (var i = 0; i < coords.length; i++) {
                var s = coords[i];
                var e = coords[i ? i - 1 : 0];
                var newdist = s.distanceTo(e);
                dist = dist + Math.round(newdist / 1000 * 100000) / 100000;
                ele = ele < s.meta.ele ? s.meta.ele : ele;
                data.push({
                    dist: dist,
                    altitude: s.meta.ele,
                    x: s.lng,
                    y: s.lat,
                    latlng: s
                });
            }
            this._dist = dist;
            this._data = data;
            this._maxElevation = ele;
        }
    },

    _addData: function(d) {
        var geom = d && d.geometry && d.geometry;
        var i;

        if (geom) {
            switch (geom.type) {
                case 'LineString':
                    this._addGeoJSONData(geom.coordinates);
                    break;

                case 'MultiLineString':
                    for (i = 0; i < geom.coordinates.length; i++) {
                        this._addGeoJSONData(geom.coordinates[i]);
                    }
                    break;
                case 'Point':break;
                default:
                    throw new Error('Invalid GeoJSON object.');
            }
        }

        var feat = d && d.type === "FeatureCollection";
        if (feat) {
            for (i = 0; i < d.features.length; i++) {
                this._addData(d.features[i]);
            }
        }

        if (d && d._latlngs) {
            this._addGPXdata(d._latlngs);
        }
    },

    /*
     * Calculates the full extent of the data array
     */
    _calculateFullExtent: function(data) {

        if (!data || data.length < 1) {
            throw new Error("no data in parameters");
        }

        var ext = new L.latLngBounds(data[0].latlng, data[0].latlng);

        data.forEach(function(item) {
            ext.extend(item.latlng);
        });

        return ext;

    },

    /*
     * Add data to the diagram either from GPX or GeoJSON and
     * update the axis domain and data
     */
    addData: function(d) {
        this._addData(d);
        if (this._container) {
            this._applyData();
        }
    },

    _applyData: function() {
        var xdomain = d3.extent(this._data, function(d) {
            return d.dist;
        });
        var ydomain = d3.extent(this._data, function(d) {
            return d.altitude;
        });
        var opts = this.options;

        if (opts.yAxisMin !== undefined && (opts.yAxisMin < ydomain[0] || opts.forceAxisBounds)) {
            ydomain[0] = opts.yAxisMin;
        }
        if (opts.yAxisMax !== undefined && (opts.yAxisMax > ydomain[1] || opts.forceAxisBounds)) {
            ydomain[1] = opts.yAxisMax;
        }

        this._x.domain(xdomain);
        this._y.domain(ydomain);
        this._areapath.datum(this._data)
            .attr("d", this._area);
        this._updateAxis();

        this._fullExtent = this._calculateFullExtent(this._data);
    },

    /*
     * Reset data
     */
    _clearData: function() {
        this._data = null;
        this._dist = null;
        this._maxElevation = null;
    },

    /*
     * Reset data and display
     */
    clear: function() {

        this._clearData();

        if (!this._areapath) {
            return;
        }

        // workaround for 'Error: Problem parsing d=""' in Webkit when empty data
        // https://groups.google.com/d/msg/d3-js/7rFxpXKXFhI/HzIO_NPeDuMJ
        //this._areapath.datum(this._data).attr("d", this._area);
        this._areapath.attr("d", "M0 0");

        this._x.domain([0, 1]);
        this._y.domain([0, 1]);
        this._updateAxis();
    }

});

L.control.elevation = function(options) {
    return new L.Control.Elevation(options);
};
