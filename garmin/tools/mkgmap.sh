#!/bin/bash

java -jar /usr/src/mkgmap-r4104/mkgmap.jar splitter-out/*.pbf --output-dir=mkgmap-out/ --gmapsupp --dem=/home/otmuser/garmintest/hgt/ --dem-dists=3312,13248,26512,53024 --verbose --dem-poly=mittelfranken.poly  --show-profiles=1 --overview-dem-dist=55000

# -c git/OpenTopoMap/garmin/opentopomap_options  --style-file=./git/OpenTopoMap/garmin/style/opentopomap git/OpenTopoMap/garmin/style/typ/OpenTopoMap.typ
