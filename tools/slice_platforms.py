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

SRC = sys.argv[1] if len(sys.argv) > 1 else "platforms.png"
OUT = sys.argv[2] if len(sys.argv) > 2 else "assets/tilesets/platforms"


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    if src.size != (CELL * 4, CELL * ROWS):
        raise SystemExit(f"源图尺寸异常: {src.size}，期望 {(CELL * 4, CELL * ROWS)}")

    tiles_dir = os.path.join(OUT, "tiles")
    for mat, _ in MATERIALS:
        os.makedirs(os.path.join(tiles_dir, mat), exist_ok=True)

    for gy, (mat, _) in enumerate(MATERIALS):
        for gx in range(COLS):
            box = (gx * CELL, gy * CELL, gx * CELL + CELL, gy * CELL + CONTENT_H)
            tile = src.crop(box)
            name = f"{mat}_{SHAPES[gx]}.png"
            path = os.path.join(tiles_dir, mat, name)
            tile.save(path)
            print(f"  [{gy}][{gx}] {mat:5s} {SHAPES[gx]:5s} -> {path}  {tile.size}")

    # 原图一并留在素材目录里（可作为 Godot TileSet 的 atlas 源）
    os.makedirs(OUT, exist_ok=True)
    shutil.copy2(SRC, os.path.join(OUT, "platforms.png"))
    print(f"\n原图已复制到 {os.path.join(OUT, 'platforms.png')}")


if __name__ == "__main__":
    main()
