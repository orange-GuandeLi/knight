#!/usr/bin/env python3
"""用图集把关卡渲染成一张预览图，方便肉眼检查。

用法: python3 tools/preview_level.py [输出路径] [起始行] [结束行] [关卡文件]
"""
import json, sys
from PIL import Image

out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/level01_preview.png"
y0 = int(sys.argv[2]) if len(sys.argv) > 2 else 13
y1 = int(sys.argv[3]) if len(sys.argv) > 3 else 34
level_file = sys.argv[4] if len(sys.argv) > 4 else "scenes/levels/level01.json"

d = json.load(open(level_file, encoding="utf-8"))
idx = json.load(open("tools/atlas_index.json", encoding="utf-8"))
atlas = {g: Image.open(f"assets/tilesets/world/atlases/{g}.png").convert("RGBA") for g in idx}

W, H, TOP = d["width"], d["height"], d["top_rows"]
T = 16


def ch(x, y):
    if y < TOP:
        return "."
    i = y - TOP
    if i < 0 or i >= len(d["map"]):
        return "."
    return d["map"][i][x]


def tile(key):
    for g, entries in idx.items():
        if key in entries:
            cx, cy = entries[key]
            return atlas[g].crop((cx * T, cy * T, cx * T + T, cy * T + T))
    return None


# 背景渐变，和 level.gd 里 _bg_key 保持一致
def bg_key(y):
    t = y / H
    if t < 0.14: return "bg_sky_1"
    if t < 0.26: return "bg_sky_1_2"
    if t < 0.38: return "bg_sky_2"
    if t < 0.50: return "bg_sky_2_3"
    if t < 0.62: return "bg_sky_3"
    if t < 0.74: return "bg_sky_3_4"
    return "bg_sky_4"


rows = y1 - y0
img = Image.new("RGB", (W * T, rows * T))
for y in range(y0, y1):
    bgt = tile(bg_key(y))
    for x in range(W):
        img.paste(bgt.convert("RGB"), (x * T, (y - y0) * T))

for y in range(y0, y1):
    for x in range(W):
        c = ch(x, y)
        if c in (".",):
            continue
        if c in d["entities"]:
            continue
        key = d["tiles"].get(c)
        if not key:
            continue
        t = tile(key)
        if t:
            img.paste(t, (x * T, (y - y0) * T), t)

# 植物层（画在地形之前，和游戏里 Decor 的 z_index=-5 一致）
deco = d.get("decor", {})
deco_img = Image.new("RGBA", (W * T, rows * T), (0, 0, 0, 0))
for g in deco.get("grass", []):
    t = tile("grass_%s_%d" % (g["kind"], int(g["n"])))
    if t:
        deco_img.paste(t, (int(g["x"]) * T, (int(g["y"]) - y0) * T), t)
for tr in deco.get("trees", []):
    x, y, kind, bodies = int(tr["x"]), int(tr["y"]), tr["kind"], int(tr["bodies"])
    for (row, part) in [(y, "bottom")] + [(y - 1 - i, "body") for i in range(bodies)] + [(y - 1 - bodies, "top")]:
        t = tile("tree_%s_%s" % (kind, part))
        if t and y0 <= row < y1:
            deco_img.paste(t, (x * T, (row - y0) * T), t)
img.paste(deco_img.convert("RGB"), (0, 0), deco_img)

# 实体标记
from PIL import ImageDraw
dr = ImageDraw.Draw(img)
for y in range(y0, y1):
    for x in range(W):
        c = ch(x, y)
        if c == "o":
            dr.ellipse([x * T + 4, (y - y0) * T + 4, x * T + 12, (y - y0) * T + 12], fill=(255, 242, 27))
        elif c == "e":
            dr.ellipse([x * T + 1, (y - y0) * T + 4, x * T + 15, (y - y0) * T + 15], fill=(186, 210, 0), outline=(22, 19, 32))
        elif c == "E":
            dr.ellipse([x * T + 1, (y - y0) * T + 4, x * T + 15, (y - y0) * T + 15], fill=(183, 61, 148), outline=(35, 20, 36))
        elif c == "k":
            dr.rectangle([x * T + 2, (y - y0) * T + 2, x * T + 14, (y - y0) * T + 11], fill=(182, 107, 58), outline=(35, 28, 25))

img = img.resize((img.width, img.height), Image.NEAREST)
img.save(out)
print(f"{out}  {img.size}  行 {y0}~{y1}  <- {level_file}")
