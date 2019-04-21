#!/usr/bin/python3

# (c) 2018 OpenTopoMap under CC-BY-SA license
# author: Martin Schuetz
# A python script to output which mkgmap splitter tiles intersect a certain polygon

import re
import sys
import shapely.geometry

if len(sys.argv) < 3:

	print("Usage: tiles_in_poly.py country.poly areas.list")
	sys.exit(-1)

def parseAreasList(filename):

	ret = dict()

	with open(filename, 'r') as f:

		for i in range(0, 3):
			f.readline()	

		while 1:

			num = f.readline()

			if len(num) == 0:
				break
			
			num = num.split(":")
			num = int(num[0])

			data = f.readline()
			data = data.split(":")
			data = data[1]
			data = data.split("to")

			point1 = data[0]
			point1 = point1.split(",")
			point2 = data[1]
			point2 = point2.split(",")

			rect = shapely.geometry.box(float(point1[0]), float(point1[1]), float(point2[0]), float(point2[1]))

			ret[num] = rect

			f.readline() # empty line

	return ret


def parsePoly(filename):
	
	with open(filename, 'r') as f:

		f.readline()
		f.readline()

		points = list()

		while 1:

			line = f.readline()

			if len(line) == 0:
				break

			if line.strip() == "END":
				break

			data = re.sub(' +', ' ', line).split(" ")	
	
			x = float(data[2])
			y = float(data[1])

			points.append((x,y)) 

	return shapely.geometry.Polygon(points)

countrypol = sys.argv[1]
areasList = sys.argv[2]

areas = parseAreasList(areasList)
countrypol = parsePoly(countrypol)

for k,v in areas.items():

	if countrypol.disjoint(v) == False:

		print("%d.osm.pbf " % k)


