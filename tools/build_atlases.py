#!/usr/bin/env python3
"""把 world 目录里的小砖打成图集，并给互动块生成"已用"版本。

产出：
  assets/tilesets/world/atlases/{terrain,props,water,bg}.png
  assets/tilesets/world/blocks/used/block_<材质>_<类型>_used.png
  tools/atlas_index.json     —— 砖名 -> [图集名, 列, 行]

"已用"块的做法：互动块上的 ? / ! 是用最亮的那个颜色画的，
把它整块换成主色，字形就没了，剩下一个空块。

用法:
    python3 tools/build_atlases.py
"""

import json
import os

import numpy as np
from PIL import Image
from collections import Counter

WORLD = "assets/tilesets/world"
ATLAS_DIR = os.path.join(WORLD, "atlases")
COLS = 16


def luminance(c):
    r, g, b = int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def hexs(p):
    return "%02X%02X%02X" % tuple(int(v) for v in p[:3])


def list_pngs(sub):
    d = os.path.join(WORLD, sub)
    if not os.path.isdir(d):
        return []
    return sorted(f for f in os.listdir(d) if f.endswith(".png"))


def make_used_block(src, dst):
    """把 ? / ! 字形涂掉，剩下空块。

    做法：脸面（块面）整块填平，只留最外两圈边框原样。
    字形颜色和边框颜色有重叠（都是描边色），所以按区域切最稳。
    """
    a = np.array(Image.open(src).convert("RGBA"))
    px = a[a[..., 3] > 0].reshape(-1, 4)
    cols = {}
    for p in px:
        cols[hexs(p)] = cols.get(hexs(p), 0) + 1
    # 脸面 = 中间区域里出现最多的颜色
    inner = a[4:13, 3:12].reshape(-1, 4)
    inner = inner[inner[:, 3] > 0]
    face = Counter(hexs(p) for p in inner).most_common(1)[0][0]

    used = a.copy()
    face_rgb = [int(face[0:2], 16), int(face[2:4], 16), int(face[4:6], 16), 255]
    used[2:14, 2:14] = face_rgb
    Image.fromarray(used).save(dst)
    return face


def pack(group, tiles):
    """tiles: [(key, path)] -> 写图集，返回 {key: [col,row]}"""
    rows = (len(tiles) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * 16, rows * 16), (0, 0, 0, 0))
    index = {}
    for i, (key, path) in enumerate(tiles):
        cx, cy = i % COLS, i // COLS
        sheet.paste(Image.open(path).convert("RGBA"), (cx * 16, cy * 16))
        index[key] = [cx, cy]
    sheet.save(os.path.join(ATLAS_DIR, f"{group}.png"))
    return index


def main():
    os.makedirs(ATLAS_DIR, exist_ok=True)
    os.makedirs(os.path.join(WORLD, "blocks", "used"), exist_ok=True)

    index = {}

    # 地形
    terrain = [(f[:-4], os.path.join(WORLD, "tiles", f)) for f in list_pngs("tiles")]
    index["terrain"] = pack("terrain", terrain)

    # 道具：桥 / 互动块 / 空块 / 木箱 / 提示牌 / 木梯
    props = []
    for sub, prefix in [("bridges", ""), ("blocks", ""), ("crates", ""),
                        ("signs", ""), ("ladders", "")]:
        for f in list_pngs(sub):
            name = f[:-4]
            props.append((name, os.path.join(WORLD, sub, f)))
            if sub == "blocks":
                used = os.path.join(WORLD, "blocks", "used", name + "_used.png")
                face = make_used_block(os.path.join(WORLD, sub, f), used)
                props.append((name + "_used", used))
                print(f"  已用块 {name}_used  脸面 #{face}")
    index["props"] = pack("props", props)

    # 水
    water = [(f[:-4], os.path.join(WORLD, "water", f)) for f in list_pngs("water")]
    index["water"] = pack("water", water)

    # 背景渐变
    bg = [(f[:-4], os.path.join(WORLD, "background", f)) for f in list_pngs("background")]
    index["bg"] = pack("bg", bg)

    # 植物：树（顶/身/底三段）+ 草丛
    plants = [(f[:-4], os.path.join(WORLD, "plants", f)) for f in list_pngs("plants")]
    index["plants"] = pack("plants", plants)

    with open("tools/atlas_index.json", "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1, sort_keys=True)

    print("\n图集:")
    for g, idx in index.items():
        rows = (len(idx) + COLS - 1) // COLS
        print(f"  {g:8s} {len(idx):3d} 块 -> atlases/{g}.png  {COLS * 16}x{rows * 16}")
    print("  索引 -> tools/atlas_index.json")


if __name__ == "__main__":
    main()
