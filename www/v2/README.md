# OTM-Web-Frontend V2

The new Web Frontend for opentopomap.org

## Installation of the Development Environment

This web frontend is based on the node.js environment and uses Webpack 5 as packing engine.

For development and build, an actual version of node.js has to be installed. In order to set up the development environment clone this repo, navigate to the repo folder and install the dependencies using the npm command

```bash
$ npm install
```

## Starting the Development Mode

Start the development environment using the npm command

```bash
$ npm start
```

This launches the Webpack server with file watch and live view in the default Browser.

## Building the Distribution Version

For building the distribution version (that will be created in the folder *./dist*) first edit the destination URL flag of the productive environment in the *webpack.config.js* file. Set *EnvTestThomasWorbs* to false. This causes the root URL tp be set to *https://opentopomap.org/*.

```javascript
// our environment
EnvTestThomasWorbs = false;
```

Then enter the npm command

```bash
$ npm run build
```

## The Files and Directories in the Ditribution Folder *./dist*

#### *index.php*

The main entrypoint php file.

#### *`<hash>`.js*

Single packed and compressed JavaScript source including all JS and CSS code including 3rd party packages.

#### *`<hash>`.js.LICENSE.txt*

License information of some 3rd party packages.

#### *favicon.ico*

The website's icon file.

#### Folder *./i*

Contains all images required by the webapp (svg and png).

#### Folder *./l*

The localization language JSON files from the repo folder *./localization* (explained later in this documentation).

## Third Party Packages used

Package | Github URL | License
------------ | ------------- | -------------
Leaflet |  https://github.com/Leaflet/Leaflet | see Github URL
Leaflet Filelayer | https://github.com/makinacorpus/Leaflet.FileLayer | MIT
Leaflet Geosearch | https://github.com/smeijer/leaflet-geosearch | MIT
Leaflet Elevation | https://github.com/Raruto/leaflet-elevation | GNU GPL V3
Axios | https://github.com/axios/axios | see Github URL
js-cookie | https://github.com/js-cookie/js-cookie | MIT
togeojson | https://github.com/placemark/togeojson | see Github URL

## Localization

The OTM Frontend provides full language localization support. The supported languages as well as the UI strings for each languages are loaded dynamically from JSON files. These JSON files are located in the repo folder *./localization*.

The file *lang.json* just contains a list of supported languages represented by the 2 letter ISO codes as well as the default language as a fallback for unsupported languages.

```json
{
  "languages": ["en","de","fr","it","es"],
  "defaultLanguage": "en"
}
```

The configuration for a specific language is stored in a JSON file specific for the language named *`<2-letter-ISO-code>`.json*. The version for English is shown below.

```json
{
  "sitehead": {
    "title": "OpenTopoMap - Topographic Maps from OpenStreetMap data",
    "description": "... directly to the map"
  },
  "c": {
    "map_data": "map data",
    "map_imagery": "map imagery",
    "contributors": "contributors",
    "hikeroutes": "hiking routes",
    "bikeroutes": "cycling routes"
  },
  "info": {
    "about": "Legend & Info",
    "about_url": "https://opentopomap.org/about",
    "impress": "Impress & Terms",
    "impress_short": "Impress",
    "impress_url": "https://opentopomap.org/credits",
    "credits": "Credits",
    "credits_short": "Credits",
    "credits_url": "https://opentopomap.org/credits",
    "garmin": "Garmin Maps",
    "garmin_url": "https://garmin.opentopomap.org/"
  },
  "zoom": {
    "zoom_in_title": "Zoom in",
    "zoom_out_title": "Zoom out"
  },
  "layers_base": [
    "OpenTopoMap",
    "OpenStreetMap"
  ],
  "layers_overlay": [
    "Lonvia Hiking Routes",
    "Lonvia Cycling Routes",
    "QTH Graticule"
  ],
  "marker": {
    "title": "Set marker"
  },
  "search": {
    "title": "Search location",
    "label": "Enter location name ..."
  },
  "locate": {
    "title": "Show own geolocation",
    "message_locating": "Detecting geolocation",
    "errors": [
      "Ok",
      "Geolocation detection blocked by browser settings",
      "Geolocation detection failed"
    ]
  },
  "tracks": {
    "title": "Show track from GPX, KML or GeoJSON file",
    "errmsg": "Unfortunately track cannot be shown.\nMaybe the selected file does not contain a valid GPX, KML or GeoJSON format.\n\n"
  }
}
```

Beside the UI strings the language configuration also contains the URLs for four linked pages (Impress etc.) as these pages are also language specific. For details see next section.

When adding a new language, do not forget to add the flag image file in the repo folder *./src-images* named *f-`<2-letter-ISO-code>`.svg*.

## Language specific Link URLs

Each language configuration JSON file contains four link URLs within the JSON tag *info*:
* `about_url`: link to the localized map Legend and Information page
* `impress_url`: link to the localized Impress and Terms of use page
* `credits_url`: link to the localized page containing all credits to autors and license information of 3rd party packages and materials used
* `garmin_url`: link to the localized page giving all information about the Garmin version of OTM

The links can be reached within the UI through the topright button in the map. In addition, `impress_url` and `credits_url` are also represented as link within the map footer to ensure 1-click-accessability.
