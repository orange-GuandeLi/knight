#!/usr/bin/env python3
"""切开树和草丛。

树是 16x48 的竖条，语义上分三段（用户要的就是这个）：
    顶部  rows  0-15   圆头的树冠起始
    body  rows 16-31   树冠中间一段，**竖向周期正好 16px，可以重复任意多个**
    底部  rows 32-47   树冠收口 + 树干

因为树叶纹理的竖向周期是 16（第 6-9 行和第 22-25 行逐像素相同），
把 body 摞 N 个上去不会出现接缝，树就高了。

草丛是 16x48 里塞了三株独立的草，按连通区域拆开，各自底对齐到 16x16。

用法:
    python3 tools/slice_plants.py
"""

import os

import numpy as np
from PIL import Image

OUT = "assets/tilesets/world/plants"
T = 16

# 源图 -> (名字, 树干色描述)
TREES = {
    13: "tree_green",   # 草绿叶 + 泥土干
    18: "tree_gold",    # 金叶 + 泥土干
    19: "tree_moss",    # 蘑菇绿叶 + 紫岩干
}

# 源图 -> 草丛名字前缀
GRASS = {
    14: "grass_green",  # 草绿
    29: "grass_moss",   # 蘑菇绿
}


def components(mask):
    """4 连通区域，返回 [(y0,y1,x0,x1)]，按从上到下排序。"""
    h, w = mask.shape
    seen = np.zeros_like(mask, bool)
    out = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            ys, xs = [], []
            while stack:
                cy, cx = stack.pop()
                ys.append(cy)
                xs.append(cx)
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            out.append((min(ys), max(ys), min(xs), max(xs)))
    return sorted(out)


def slice_tree(num, name):
    img = Image.open(f"tile_{num}.png").convert("RGBA")
    w, h = img.size
    if (w, h) != (16, 48):
        raise SystemExit(f"tile_{num}: 期望 16x48，实际 {w}x{h}")
    parts = {"top": (0, 16), "body": (16, 32), "bottom": (32, 48)}
    for part, (y0, y1) in parts.items():
        img.crop((0, y0, 16, y1)).save(os.path.join(OUT, f"{name}_{part}.png"))
    return parts


def slice_grass(num, name):
    img = Image.open(f"tile_{num}.png").convert("RGBA")
    a = np.array(img)
    comps = components(a[..., 3] > 0)
    n = 0
    for (y0, y1, x0, x1) in comps:
        piece = img.crop((0, y0, 16, y1 + 1))        # 保留 16 宽，保持居中
        canvas = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        canvas.paste(piece, (0, 16 - piece.height))  # 底对齐
        n += 1
        canvas.save(os.path.join(OUT, f"{name}_{n}.png"))
    return n


def main():
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for num, name in sorted(TREES.items()):
        parts = slice_tree(num, name)
        print(f"  tile_{num:<3} -> {name}_top/body/bottom  3 段 {parts}")
        made += 3
    for num, name in sorted(GRASS.items()):
        n = slice_grass(num, name)
        print(f"  tile_{num:<3} -> {name}_1..{n}  拆出 {n} 株草丛")
        made += n
    print(f"\n共 {made} 张 -> {OUT}/")


if __name__ == "__main__":
    main()
