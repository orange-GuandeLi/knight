#!/usr/bin/env python3
"""生成项目图标（封面）：骑士站在草地上。

- 背景：天空渐变 + 一条草皮地面，都直接用游戏自己的色板和地形砖
- 主体：骑士 idle 姿势，裁到内容框后整数倍放大（最近邻，保持硬边像素画）
- 外形：圆角方形，裁成 macOS dock 那种圆角图标的样子

用法:
    python3 tools/make_icon.py
"""

import os

import numpy as np
from PIL import Image

OUT = "assets/icons/icon.png"

SIZE = 128          # 输出尺寸
KNIGHT_SCALE = 5    # 骑士放大倍数（最近邻）
GROUND_SCALE = 3    # 地形砖放大倍数
GROUND_ROWS = 8     # 地面用砖的前 8 行（1 行描边 + 7 行草）
GROUND_COLS = (1, 15)  # 砖的取列范围：去掉左右两列透明边
CORNER = 22         # 圆角半径

KNIGHT_SRC = "assets/sprites/knight/idle/idle_00.png"
GROUND_SRC = "assets/tilesets/world/tiles/grass_dirt.png"

# 颜色取自 assets/PALETTE.md：天空族第 2 / 第 3 档
SKY_TOP = (0x14, 0x98, 0xDC)
SKY_BOTTOM = (0x19, 0x50, 0xC0)
# 地面砖的描边色，透明角落用它补上，免得每块砖之间有缝
OUTLINE = (0x23, 0x1C, 0x19)


def crop_content(img: Image.Image) -> Image.Image:
    """裁到不透明内容的包围盒，不留空白。"""
    a = np.array(img)
    ys, xs = np.nonzero(a[..., 3] > 0)
    return img.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def sky_gradient(w: int, h: int) -> Image.Image:
    """竖直天空渐变。"""
    t = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
    top = np.array(SKY_TOP, dtype=np.float32)
    bottom = np.array(SKY_BOTTOM, dtype=np.float32)
    rgb = top[None, None, :] * (1.0 - t[:, :, None]) + bottom[None, None, :] * t[:, :, None]
    out = np.empty((h, w, 4), dtype=np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = 255
    return Image.fromarray(out)


def ground_strip(w: int) -> Image.Image:
    """用 grass_dirt 砖横向拼一条地面。

    砖的最左最右两列是透明的（地形边缘用的），拼起来会漏出缝，
    所以去掉这两列，并且先把底铺成描边色再贴砖。
    """
    tile = Image.open(GROUND_SRC).convert("RGBA").crop(
        (GROUND_COLS[0], 0, GROUND_COLS[1], GROUND_ROWS)
    )
    tw = tile.size[0] * GROUND_SCALE
    th = GROUND_ROWS * GROUND_SCALE
    strip = Image.new("RGBA", (w, th), OUTLINE + (255,))
    for x in range(0, w, tw):
        strip.alpha_composite(tile.resize((tw, th), Image.NEAREST), (x, 0))
    return strip


def rounded_mask(w: int, h: int, r: int) -> Image.Image:
    mask = Image.new("L", (w, h), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=r, fill=255)
    return mask


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    canvas = sky_gradient(SIZE, SIZE)

    # 地面贴底
    strip = ground_strip(SIZE)
    canvas.alpha_composite(strip, (0, SIZE - strip.size[1]))
    ground_top = SIZE - strip.size[1]

    # 骑士站在草地上：脚底对齐地面顶边
    knight = crop_content(Image.open(KNIGHT_SRC).convert("RGBA"))
    knight = knight.resize(
        (knight.size[0] * KNIGHT_SCALE, knight.size[1] * KNIGHT_SCALE), Image.NEAREST
    )
    kx = (SIZE - knight.size[0]) // 2
    ky = ground_top - knight.size[1]
    canvas.alpha_composite(knight, (kx, ky))

    # 圆角
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(canvas, (0, 0), rounded_mask(SIZE, SIZE, CORNER))

    out.save(OUT)
    print(f"-> {OUT}  {out.size[0]}x{out.size[1]}")
    print(f"   骑士 {knight.size[0]}x{knight.size[1]}（{KNIGHT_SCALE} 倍放大），脚底 y={ky + knight.size[1]}")
    print(f"   地面 {strip.size[0]}x{strip.size[1]}，顶边 y={ground_top}")


if __name__ == "__main__":
    main()
