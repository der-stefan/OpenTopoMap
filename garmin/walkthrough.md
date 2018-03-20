# Building a custom Garmin map

Based on the [HOWTO](HOWTO) this describes how to create a custom garmin map
using OpenTopoMap styles.

## Required tools & OpenTopoMap repository

```bash
git clone https://github.com/der-stefan/OpenTopoMap.git
cd OpenTopoMap/garmin
```

Download [mkgmap](http://www.mkgmap.org.uk/download/mkgmap.html),
[splitter](http://www.mkgmap.org.uk/download/splitter.html) & bounds

```bash
MKGMAP="mkgmap-r4136" # adjust to latest version (see www.mkgmap.org.uk)
SPLITTER="splitter-r591"

mkdir tools
pushd tools > /dev/null

wget "http://www.mkgmap.org.uk/download/${MKGMAP}.zip"
unzip "${MKGMAP}.zip"
MKGMAPJAR="$(pwd)/${MKGMAP}/mkgmap.jar"

wget "http://www.mkgmap.org.uk/download/${SPLITTER}.zip"
unzip "${SPLITTER}.zip"
SPLITTERJAR="$(pwd)/${SPLITTER}/splitter.jar"

popd > /dev/null
pushd bounds > /dev/null

if stat --printf='' bounds_*.bnd 2> /dev/null; then
    echo "bounds already downloaded"
else
    echo "downloading bounds"
    wget "http://osm2.pleiades.uni-wuppertal.de/bounds/latest/bounds.zip"
    unzip "bounds.zip"
fi
BOUNDS="$(pwd)"

popd > /dev/null
```

## Fetch map data, split & build garmin map

```bash
mkdir data
pushd data > /dev/null

wget "https://download.geofabrik.de/africa/morocco-latest.osm.pbf"

rm -f 6324*.pbf
java -jar $SPLITTERJAR "$(pwd)/morocco-latest.osm.pbf"
DATA="$(pwd)/6324*.pbf"

popd > /dev/null

OPTIONS="$(pwd)/opentopomap_options"
STYLEFILE="$(pwd)/style/opentopomap"

pushd style/typ > /dev/null

java -jar $MKGMAPJAR --family-id=35 OpenTopoMap.txt
TYPFILE="$(pwd)/OpenTopoMap.typ"

popd > /dev/null

java -jar $MKGMAPJAR -c $OPTIONS --style-file=$STYLEFILE \
    --output-dir=output --bounds=$BOUNDS $DATA $TYPFILE

# optional: give map a useful name:
mv output/gmapsupp.img morocco.img

```
