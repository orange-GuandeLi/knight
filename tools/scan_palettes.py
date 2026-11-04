#!/usr/bin/env python3
"""扫描 assets/ 下所有 PNG，按「配色家族」归类。

判定方法：
  1. 描边色 = 图片四边上出现最多的颜色
  2. 主色   = 除描边外像素最多的颜色
  3. 家族   = 主色的色相（绿 / 蓝 / 紫 / 金 / 红 / ...）

同一家族 = 同一套配色，只是换了物件。用来保证命名统一。

用法:
    python3 tools/scan_palettes.py
"""

import os
import colorsys
from collections import Counter, defaultdict

import numpy as np
from PIL import Image

ROOT = "assets"


def hexs(p):
    return "%02X%02X%02X" % tuple(int(v) for v in p[:3])


def hue_name(h):
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    hh, ll, ss = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if ss < 0.12:
        return "灰"
    deg = hh * 360
    for lim, name in [(15, "红"), (40, "橙"), (70, "黄"), (160, "绿"),
                      (200, "青"), (255, "蓝"), (290, "紫")]:
        if deg < lim:
            return name
    return "粉"


def analyze(path):
    a = np.array(Image.open(path).convert("RGBA"))
    px = a[a[..., 3] > 0]
    if len(px) == 0:
        return None

    counts = Counter(hexs(p) for p in px)

    # 描边色：四边像素里出现最多的
    border = []
    border += [hexs(a[0, x]) for x in range(a.shape[1]) if a[0, x, 3] > 0]
    border += [hexs(a[a.shape[0] - 1, x]) for x in range(a.shape[1]) if a[a.shape[0] - 1, x, 3] > 0]
    border += [hexs(a[y, 0]) for y in range(a.shape[0]) if a[y, 0, 3] > 0]
    border += [hexs(a[y, a.shape[1] - 1]) for y in range(a.shape[0]) if a[y, a.shape[1] - 1, 3] > 0]
    outline = Counter(border).most_common(1)[0][0] if border else None

    body = None
    for c, n in counts.most_common():
        if c != outline:
            body = c
            break
    if body is None:
        body = counts.most_common(1)[0][0]

    return {
        "family": hue_name(body),
        "body": body,
        "outline": outline,
        "colors": counts.most_common(),
        "n": len(px),
    }


def main():
    files = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d != ".godot"]
        for fn in sorted(filenames):
            if fn.endswith(".png"):
                files.append(os.path.join(dirpath, fn))

    groups = defaultdict(list)
    for f in files:
        info = analyze(f)
        if info is None:
            continue
        groups[info["family"]].append((f, info))

    print("共 %d 张图，%d 个配色家族\n" % (len(files), len(groups)))
    order = sorted(groups.items(), key=lambda kv: -len(kv[1]))
    for fam, items in order:
        print("== %s  %d 张" % (fam, len(items)))
        seen = set()
        for f, info in items:
            key = (info["outline"], info["body"], tuple(c for c, _ in info["colors"][:6]))
            if key in seen:
                continue
            seen.add(key)
            cols = " ".join("#%s(%d)" % (c, n) for c, n in info["colors"][:6])
            print("     色板 %s" % cols)
        for f, _ in items:
            print("       - %s" % f)
        print()


if __name__ == "__main__":
    main()
