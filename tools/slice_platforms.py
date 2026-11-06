#!/usr/bin/env python3
"""把 platforms.png 图集切成独立瓦片素材。

源图集是 64x64，按 16x16 网格排成 4 行 x 4 列；
第 4 列全空，每格实际只有顶部 9 行有内容。

用法:
    python3 tools/slice_platforms.py [源图] [输出目录]
"""
import os
import shutil
import sys

from PIL import Image

CELL = 16          # 网格间距
CONTENT_H = 9      # 每格实际有内容的行数
COLS = 3           # 实际使用的列数（第 4 列全空）
ROWS = 4

# 行号 -> (材质名, 形状名)
MATERIALS = [
    ("grass", "block"),   # 第 0 行：草地
    ("dirt", "block"),    # 第 1 行：泥土
    ("gold", "block"),    # 第 2 行：黄金
    ("ice", "block"),     # 第 3 行：冰块
]

# 列号 -> 形状后缀（三种形状在 4 行里完全一致）
SHAPES = ["block", "left", "right"]

SRC = sys.argv[1] if len(sys.argv) > 1 else "assets/tilesets/platforms/platforms.png"
OUT = sys.argv[2] if len(sys.argv) > 2 else "assets/tilesets/platforms"


def make_mid(left: Image.Image, right: Image.Image) -> Image.Image:
    """拼出「两端都是平边」的中段砖。

    源图集只有 block / left / right 三种，两块以上拼接时中间会露出缺口。
    中段砖 = 左半边取 right 的平边（它左边是平的），右半边取 left 的平边。
    颜色全部来自原图，不新增任何像素色。
    """
    w, h = left.size
    mid = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            # 左边 2 列用 right 的（平边），其余用 left 的（右边也是平的）
            src = right if x < 2 else left
            mid.putpixel((x, y), src.getpixel((x, y)))
    return mid


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    if src.size != (CELL * 4, CELL * ROWS):
        raise SystemExit(f"源图尺寸异常: {src.size}，期望 {(CELL * 4, CELL * ROWS)}")

    tiles_dir = os.path.join(OUT, "tiles")
    for mat, _ in MATERIALS:
        os.makedirs(os.path.join(tiles_dir, mat), exist_ok=True)

    for gy, (mat, _) in enumerate(MATERIALS):
        tiles = {}
        for gx in range(COLS):
            box = (gx * CELL, gy * CELL, gx * CELL + CELL, gy * CELL + CONTENT_H)
            tile = src.crop(box)
            name = f"{mat}_{SHAPES[gx]}.png"
            path = os.path.join(tiles_dir, mat, name)
            tile.save(path)
            tiles[SHAPES[gx]] = tile
            print(f"  [{gy}][{gx}] {mat:5s} {SHAPES[gx]:5s} -> {path}  {tile.size}")

        # 中段砖：源图没有，用 left/right 拼出来
        mid = make_mid(tiles["left"], tiles["right"])
        mid_path = os.path.join(tiles_dir, mat, f"{mat}_mid.png")
        mid.save(mid_path)
        print(f"  [{gy}]-    {mat:5s} mid    -> {mid_path}  {mid.size}  (拼出来的)")

    # 原图一并留在素材目录里（可作为 Godot TileSet 的 atlas 源）
    os.makedirs(OUT, exist_ok=True)
    dst = os.path.join(OUT, "platforms.png")
    if os.path.abspath(SRC) != os.path.abspath(dst):
        shutil.copy2(SRC, dst)
    print(f"\n原图在 {dst}")


if __name__ == "__main__":
    main()
