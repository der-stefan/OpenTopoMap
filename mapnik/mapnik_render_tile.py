# This is a simple script that you can modify and use to verify your database has been setup correctlyself.
# This python script uses the mapnik api to generate a sample png tile

# input: osm database and mapnik stylesheet
# output: png sample image

from mapnik import *

input_mapnik_style = 'opentopomap.xml'
output_png = 'opentopomap_output.png'

def tile2prjbounds(settings, x, y, z):
    """

    :param settings: geometry settings from build_geom_settings()
    :param x: tile x
    :param y: tile y
    :param z: tile zoom
    :return: tuple of x0, y0, x1, y1 in projection coordinates
    """
    render_size_tx = min(8, settings['aspect_x'] * (1 << z))
    render_size_ty = min(8, settings['aspect_y'] * (1 << z))

    prj_width = settings['bound_x1'] - settings['bound_x0']
    prj_height = settings['bound_y1'] - settings['bound_y0']
    p0x = settings['bound_x0'] + prj_width * (float(x) / (settings['aspect_x'] * (1 << z)))
    p0y = settings['bound_y1'] - prj_height * ((float(y) + render_size_ty) / (settings['aspect_y'] * (1 << z)))
    p1x = settings['bound_x0'] + prj_width * ((float(x) + render_size_tx) / (settings['aspect_x'] * (1 << z)))
    p1y = settings['bound_y1'] - prj_height * (float(y) / (settings['aspect_y'] * (1 << z)))

    return p0x, p0y, p1x, p1y



engine = FontEngine.instance()

font_dir = "/usr/share/fonts"

for dirpath, dirnames, filenames in os.walk(font_dir, followlinks=True):
	for filename in filenames:
		if filename.endswith(".ttf") or filename.endswith(".otf"):
			fullpath = os.path.join(dirpath, filename)
			print "loading font %s", fullpath
			engine.register_font(fullpath)

m = Map(2*1024,2*1024)
load_map(m, input_mapnik_style)

geom_settings = {
	'bound_x0': -20037508.3428,
	'bound_x1': 20037508.3428,
	'bound_y0': -20037508.3428,
	'bound_y1': 20037508.3428,
	'aspect_x': 1.0,
	'aspect_y': 1.0
}

p0x, p0y, p1x, p1y = tile2prjbounds(geom_settings, 1320, 2860, 13)

bbox=(Box2d(p0x, p0y, p1x, p1y))
m.zoom_to_box(bbox)
#m.zoom_all()
print "env ", m.envelope()
print "Scale = " , m.scale()
render_to_file(m, output_png)
