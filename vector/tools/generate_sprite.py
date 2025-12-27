#!/usr/bin/env python3
"""
Usage:
  python generate_sprite_tight_auto_cols.py input_folder output_sprite.png --padding 0 --json atlas.json

Automatically determines column count to make the sheet roughly square.
Uses ImageMagick (convert, montage, identify).
JSON atlas format:
{
  "name_without_ext": {"x":0,"y":0,"width":W,"height":H,"pixelRatio":1},
  ...
}
"""
import os, sys, json, shutil, subprocess
from pathlib import Path
import argparse
from math import ceil

def run(cmd):
    subprocess.check_call(cmd, shell=True)

def list_pngs(folder):
    p = Path(folder)
    files = sorted([x for x in p.iterdir() if x.suffix.lower()=='.png'])
    if not files:
        raise SystemExit("No PNGs found")
    return files

def get_size(path):
    out = subprocess.check_output(f'identify -format "%w %h" "{path}"', shell=True).decode().strip()
    w,h = out.split()
    return int(w), int(h)

def choose_columns(sizes, padding):
    n = len(sizes)
    best = None
    for cols in range(1, n+1):
        rows = ceil(n/cols)
        col_widths = [0]*cols
        row_heights = [0]*rows
        for idx,(w,h) in enumerate(sizes):
            c = idx % cols
            r = idx // cols
            if w > col_widths[c]: col_widths[c]=w
            if h > row_heights[r]: row_heights[r]=h
        total_w = sum(col_widths) + padding*(cols+1)
        total_h = sum(row_heights) + padding*(rows+1)
        area = total_w * total_h
        score = area + abs(total_w - total_h)
        if best is None or score < best[0]:
            best = (score, cols, col_widths, row_heights)
    return best[1], best[2], best[3]

def build(input_folder, output_file, cols=None, padding=0, json_out=None):
    files = list_pngs(input_folder)
    tmp = Path(input_folder)/"_tmp_trim"
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir()
    originals = []
    trimmed = []
    orig_sizes = []
    for i,f in enumerate(files):
        dest = tmp / f"f{i:04d}.png"
        run(f'convert "{f}" -trim +repage "{dest}"')
        originals.append(f.name)
        trimmed.append(dest)
        orig_sizes.append(get_size(str(f)))
    sizes = [get_size(str(p)) for p in trimmed]
    n = len(trimmed)
    if cols is None:
        cols, col_widths, row_heights = choose_columns(sizes, padding)
    else:
        rows = ceil(n/cols)
        col_widths = [0]*cols
        row_heights = [0]*rows
        for idx,(w,h) in enumerate(sizes):
            c = idx % cols; r = idx // cols
            col_widths[c]=max(col_widths[c], w)
            row_heights[r]=max(row_heights[r], h)
    rows = ceil(n/cols)
    file_list = " ".join(f'"{str(p)}"' for p in trimmed)
    geom = f"+{padding}+{padding}"
    cmd = f'montage {file_list} -background none -gravity northwest -geometry {geom} -tile {cols}x{rows} "{output_file}"'
    run(cmd)
    atlas = None
    if json_out:
        W,H = get_size(output_file)
        col_x = []
        x = 0
        for cw in col_widths:
            col_x.append(x + padding)
            x += cw + padding
        row_y = []
        y = 0
        for rh in row_heights:
            row_y.append(y + padding)
            y += rh + padding
        atlas = {}
        for idx,trim_path in enumerate(trimmed):
            r = idx//cols; c = idx%cols
            x = col_x[c]; y = row_y[r]
            w,h = sizes[idx]
            name = Path(originals[idx]).stem
            atlas[name] = {"x": x, "y": y, "width": w, "height": h, "pixelRatio": 1}
        with open(json_out,"w") as jf:
            json.dump(atlas, jf, indent=2)
    shutil.rmtree(tmp)
    return atlas

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input_folder"); ap.add_argument("output_sprite")
    ap.add_argument("--cols", type=int, default=None)
    ap.add_argument("--padding", type=int, default=0)
    ap.add_argument("--json", dest="json_out", default=None)
    args = ap.parse_args()
    atlas = build(args.input_folder, args.output_sprite, cols=args.cols, padding=args.padding, json_out=args.json_out)
    print("Wrote", args.output_sprite, args.json_out or "")

if __name__=="__main__":
    main()
