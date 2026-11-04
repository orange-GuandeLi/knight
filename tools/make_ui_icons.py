#!/usr/bin/env python3
"""生成 HUD 图标。

- 骑士 / 金币：直接从现有素材裁出内容区域，不新增美术
- 爱心：素材里没有，按游戏的红色色板画一个 8x7 的，实心/空心两版

用法:
    python3 tools/make_ui_icons.py
"""

import os

import numpy as np
from PIL import Image

OUT = "assets/ui/icons"

# 颜色取自 assets/PALETTE.md
OUTLINE = (0x23, 0x1C, 0x19)
HEART_LIGHT = (0xE6, 0x5F, 0x69)   # 紫族的高光色
HEART_MAIN = (0xDD, 0x30, 0x13)    # 红族主色
EMPTY_LIGHT = (0x4A, 0x52, 0x62)
EMPTY_MAIN = (0x3D, 0x48, 0x57)    # 石族暗色

# 8x7 爱心： # 描边 / L 高光 / R 主体
HEART = [
    ".##..##.",
    "#LL##RR#",
    "#LRRRRR#",
    "#RRRRRR#",
    ".#RRRR#.",
    "..#RR#..",
    "...##...",
]


def crop_icon(src, dst):
    """裁到不透明内容的包围盒，不留空白。"""
    img = Image.open(src).convert("RGBA")
    a = np.array(img)
    ys, xs = np.nonzero(a[..., 3] > 0)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    img.crop(box).save(dst)
    return img.crop(box).size


def draw_heart(dst, light, main):
    rows = len(HEART)
    cols = len(HEART[0])
    for r in HEART:
        assert len(r) == cols, f"爱心每行长度不一致: {r}"
    img = Image.new("RGBA", (cols, rows), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(HEART):
        for x, ch in enumerate(row):
            if ch == "#":
                px[x, y] = OUTLINE + (255,)
            elif ch == "L":
                px[x, y] = light + (255,)
            elif ch == "R":
                px[x, y] = main + (255,)
    img.save(dst)
    return (cols, rows)


def main():
    os.makedirs(OUT, exist_ok=True)
    k = crop_icon("assets/sprites/knight/idle/idle_00.png", os.path.join(OUT, "icon_knight.png"))
    print(f"  骑士图标 {k[0]}x{k[1]}  <- knight/idle/idle_00.png 裁内容框")
    c = crop_icon("assets/sprites/coin/coin_00.png", os.path.join(OUT, "icon_coin.png"))
    print(f"  金币图标 {c[0]}x{c[1]}  <- coin/coin_00.png 裁内容框")
    h = draw_heart(os.path.join(OUT, "icon_heart_full.png"), HEART_LIGHT, HEART_MAIN)
    print(f"  实心爱心 {h[0]}x{h[1]}  红族色板 (新画的)")
    e = draw_heart(os.path.join(OUT, "icon_heart_empty.png"), EMPTY_LIGHT, EMPTY_MAIN)
    print(f"  空心爱心 {e[0]}x{e[1]}  石族暗色 (新画的)")
    print(f"\n-> {OUT}/")


if __name__ == "__main__":
    main()
