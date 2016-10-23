<!--Settings for Mapnik Fonts
Uncomment the unifont entries if you have that font installed
in your mapnik fonts dir, and want to use it as a fallback font.
Mapnik includes this font by default since r1328.
To see the fonts you have installed with Mapnik do:
python -c "from mapnik import FontEngine as e;print '\n'.join(e.instance().face_names())"
-->

<FontSet name="serif-book">
  <Font face-name="DejaVu Serif Book" />
  <Font face-name="Unifont Medium" />
</FontSet>
<FontSet name="sans-book">
  <Font face-name="DejaVu Sans Book" />
  <Font face-name="Unifont Medium" />
</FontSet>
<FontSet name="sans-condensed">
  <Font face-name="DejaVu Sans Condensed" />
  <Font face-name="Unifont Medium" />
</FontSet>
<FontSet name="sans-condensed-oblique">
  <Font face-name="DejaVu Sans Condensed Oblique" />
  <Font face-name="Unifont Medium" />
</FontSet>
<FontSet name="sans-extralight">
  <Font face-name="DejaVu Sans ExtraLight" />
  <Font face-name="Unifont Medium" />
</FontSet>
<FontSet name="sans-condensed-bold">
  <Font face-name="DejaVu Sans Condensed Bold" />
  <Font face-name="Unifont Medium" />
</FontSet>
<FontSet name="sans-oblique">
  <Font face-name="DejaVu Sans Oblique" />
  <Font face-name="Unifont Medium" />
</FontSet>

