#!/usr/bin/env python3
"""把史莱姆图集切成独立帧素材。

源图 96x72 = 4 列 x 3 行，每格 24x24。
每格内容固定占 x=5..18（宽 14），底边固定在格子的第 23 行，
只有高度会变（9~15），所以统一裁成 14x15 底部对齐，所有帧的脚底都在同一条线上。

原图会一并复制到输出目录保留（assets/sprites/slime/slime_<color>_sheet.png）。

用法:
    python3 tools/slice_slimes.py
"""
import os
import shutil
import sys

from PIL import Image

CELL = 24          # 网格间距
CROP_X = (5, 19)   # 内容水平范围（左闭右开）
CROP_Y = (9, 24)   # 统一裁 15 行，保证底部对齐
COLS = 4

# 行号 -> 动画名
ROWS = ["melt", "idle", "hurt"]

# 源图 -> 颜色名
SHEETS = [
    ("slime_green.png", "green"),
    ("slime_purple.png", "purple"),
]

OUT = "assets/sprites/slime"


def main() -> None:
    for src_name, color in SHEETS:
        src = Image.open(src_name).convert("RGBA")
        if src.size != (CELL * COLS, CELL * 3):
            raise SystemExit(f"{src_name} 尺寸异常: {src.size}")

        out_dir = os.path.join(OUT, color)
        os.makedirs(out_dir, exist_ok=True)

        for gy, anim in enumerate(ROWS):
            for gx in range(COLS):
                box = (gx * CELL + CROP_X[0], gy * CELL + CROP_Y[0],
                       gx * CELL + CROP_X[1], gy * CELL + CROP_Y[1])
                tile = src.crop(box)
                path = os.path.join(out_dir, f"{color}_{anim}_{gx:02d}.png")
                tile.save(path)
                print(f"  {color:6s} {anim:5s} [{gy}][{gx}] -> {path}  {tile.size}")

        # 保留原图
        kept = os.path.join(OUT, f"slime_{color}_sheet.png")
        shutil.copy2(src_name, kept)
        print(f"  原图已保留 -> {kept}")

    print("\n完成")


if __name__ == "__main__":
    main()
