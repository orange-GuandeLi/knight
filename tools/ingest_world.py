#!/usr/bin/env python3
"""自动归档 world 图集的切图。

能认两种切法：

    16x16  ->  复合砖：地表层 (y1~y7) + 分隔行 (y8) + 主体层 (y9~y14)
                命名 <地表>_<主体>.png      例：grass_dirt.png
    16x8   ->  单层砖：只有一层
                命名 <材质>.png             例：grass.png / dirt.png

材质按像素配色自动判定，不用手工登记编号。
每张砖的描边色可以从第 0 行取到，材质用特征色 + 优先级判定。

用法:
    python3 tools/ingest_world.py                    # 处理项目根目录下的 tile_*.png
    python3 tools/ingest_world.py --source <目录>     # 处理指定目录
"""
import argparse
import os


from PIL import Image
import numpy as np

OUT = "assets/tilesets/world/tiles"

# 特征色 -> 材质。按优先级从上往下匹配（先命中先算）。
# 每种材质列了它的全部 3 色，因为每块砖不一定三种都用到
# （例：浅岩体有的是 E2CFA4+C3AA83+997D57，有的是只有后两个）。
# 沙和泥共用 D89E58/B66B3A，靠 F3CF95（沙专属）vs 67332D（泥专属）区分。
SIGNATURE = [
    ("snow",        ("FFFFFF",)),                        # 雪
    ("grass",       ("95D836", "4DBD27", "0A7030")),      # 草
    ("gold",        ("FFFC32", "FFD233", "F99C0B")),      # 金矿
    ("sand",        ("F3CF95",)),                        # 暖沙
    ("pale_rock",   ("E2CFA4", "C3AA83", "997D57")),      # 浅岩
    ("purple_rock", ("E7B09C", "B56B5F", "864646")),      # 深紫岩
    ("stone",       ("AEB4CE", "636B85", "3D4857")),      # 灰石
    ("dirt",        ("67332D", "D89E58", "B66B3A")),      # 泥土
    ("ice",         ("A0FCD8", "10D3C3", "1498DC")),      # 冰
]

# 源编号 -> (文件名, 说明)。留空则完全自动判定。
OVERRIDE = {
    2:  ("cracked_dirt",         "泥土裂纹块"),
    4:  ("cracked_pale_rock",    "浅岩裂纹块"),
    6:  ("cracked_purple_rock",  "紫岩裂纹块"),
    9:  ("cracked_stone",        "灰石裂纹块"),
    14: ("cracked_dirt_2",       "泥土裂纹块（变体 2）"),
    16: ("cracked_pale_rock_2",  "浅岩裂纹块（变体 2）"),
    18: ("cracked_purple_rock_2", "紫岩裂纹块（变体 2）"),
    21: ("cracked_stone_2",      "灰石裂纹块（变体 2）"),
}

# 桥梁：源编号 -> (材质, 段位)。存到 bridges/ 而不是 tiles/。
# 每张 16x16 里有两块 8 宽的桥板，形状相同，只有垂直位置不同：
#   start  左板在第 0 行、右板在第 1 行（左高右低）
#   middle 两块都在第 2 行（平）
#   end    左板在第 1 行、右板在第 0 行（左低右高）
BRIDGES = {
    10: ("dirt", "start"), 11: ("dirt", "middle"), 12: ("dirt", "end"),
    22: ("pale_rock", "start"), 23: ("pale_rock", "middle"), 24: ("pale_rock", "end"),
    34: ("purple_rock", "start"), 35: ("purple_rock", "middle"), 36: ("purple_rock", "end"),
}

BRIDGE_OUT = "assets/tilesets/world/bridges"

# 互动块（头顶撞击出奖励的那种）：源编号 -> (材质, 问号/感叹号)
# 存到 blocks/。字形是「描边色 + 填充色」两层画出来的：
#   问号     顶部 5px 宽弧 -> 钩子收向中间 -> 断开 -> 底部点
#   感叹号   2px 竖条 -> 断开 -> 底部点
BLOCKS = {
    25: ("dirt", "question"),
    26: ("dirt", "exclaim"),
    28: ("pale_rock", "question"),
    39: ("pale_rock", "exclaim"),
    29: ("purple_rock", "question"),
    30: ("purple_rock", "exclaim"),
    32: ("stone", "question"),
    33: ("stone", "exclaim"),
}

BLOCK_OUT = "assets/tilesets/world/blocks"

# 木箱子：源编号 -> (材质色)。存到 crates/。
# 两张结构完全一样（外框 + 竖框 + 横档 + 中心板），只有配色不同：
#   dirt        泥土棕（231C19 / D89E58 / B66B3A / 67332D）
#   purple_rock 紫岩粉（231C19 / E7B09C / B56B5F / 864646）
CRATES = {
    42: "dirt",
    52: "purple_rock",
}

CRATE_OUT = "assets/tilesets/world/crates"

# 木提示牌：源编号 -> (材质色)。存到 signs/。结构是斜放的牌面 + 下方立柱。
SIGNS = {
    43: "dirt",
    53: "purple_rock",
}

SIGN_OUT = "assets/tilesets/world/signs"

# 水：源编号 -> (颜色, 类型)。存到 water/。
#   surface_body  水面 + 水体：顶部 4 行波浪（有两处透明缺口）+ 下面 12 行实心水体
#   surface       只有水面：那条波浪，贴在砖底部 rows 11-15，上面全透明
#   body          只有水体：整块纯色，无描边无高光
WATER = {
    92: ("ice", "surface_body"),
    93: ("ice", "surface"),
    100: ("ice", "body"),
    94: ("deep_blue", "surface_body"),
    95: ("deep_blue", "surface"),
    101: ("deep_blue", "body"),
    106: ("purple", "surface_body"),
    107: ("purple", "surface"),
    112: ("purple", "body"),
    117: ("gold", "surface_body"),
    118: ("gold", "surface"),
    123: ("gold", "body"),
}

WATER_OUT = "assets/tilesets/world/water"

# 背景渐变块：源编号 -> (族, 档)。存到 background/。
# 每族 4 档纯色（1-4）+ 3 张竖向抖动过渡块（1_2 / 2_3 / 3_4）。
# 过渡块的抖动网点 12 张完全一样，只是上下换色，竖着摞起来就是一条平滑渐变。
#   sky     FFFFFF -> 1498DC -> 1950C0 -> 032659
#   warm    FAD3B3 -> F49990 -> FFD233 -> F99C0B
#   purple  F49990 -> E65F69 -> B73D94 -> 6F2C77
#   stone   D7DEE8 -> AEB4CE -> 838BA9 -> 636B85
BACKGROUND = {
    88: ("sky", "1"), 102: ("sky", "2"), 113: ("sky", "3"), 124: ("sky", "4"),
    96: ("sky", "1_2"), 108: ("sky", "2_3"), 119: ("sky", "3_4"),
    89: ("warm", "1"), 103: ("warm", "2"), 114: ("warm", "3"), 125: ("warm", "4"),
    97: ("warm", "1_2"), 109: ("warm", "2_3"), 120: ("warm", "3_4"),
    90: ("purple", "1"), 104: ("purple", "2"), 115: ("purple", "3"), 126: ("purple", "4"),
    98: ("purple", "1_2"), 110: ("purple", "2_3"), 121: ("purple", "3_4"),
    91: ("stone", "1"), 105: ("stone", "2"), 116: ("stone", "3"), 127: ("stone", "4"),
    99: ("stone", "1_2"), 111: ("stone", "2_3"), 122: ("stone", "3_4"),
}

BACKGROUND_OUT = "assets/tilesets/world/background"

# 木梯：源编号 -> (材质色)。存到 ladders/。两条竖杆 + 横向档。
LADDERS = {
    44: "dirt",
    54: "purple_rock",
}

LADDER_OUT = "assets/tilesets/world/ladders"


def hexs(p):
    return "%02X%02X%02X" % tuple(p[:3])


def material_of(color_set):
    """给一组颜色，返回判定出的材质名。"""
    for name, sigs in SIGNATURE:
        if any(s in color_set for s in sigs):
            return name
    return None


def analyze(path):
    """返回 (尺寸, 是否复合砖, 地表材质, 主体材质)。

    判定方式（不依赖描边行，因为材质之间的过渡行会混色）：
      16x16  顶部 4 行 = 地表层特征色，底部 7 行 = 主体层特征色
      16x8   整块（去掉第一行）= 单层特征色
    """
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    h, w = a.shape[:2]
    if w != 16:
        return (w, h), False, None, None

    alpha = a[..., 3] > 0

    def band(r0, r1):
        return {hexs(a[y, x]) for y in range(max(0, r0), min(h, r1))
                for x in range(w) if alpha[y, x]}

    if h >= 16:
        return (w, h), True, material_of(band(1, 5)), material_of(band(h - 7, h - 1))
    return (w, h), False, material_of(band(1, h)), None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default=".", help="切图所在目录")
    args = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    count = 0

    for name in sorted(os.listdir(args.source)):
        if not name.startswith("tile_") or not name.endswith(".png"):
            continue
        try:
            num = int(name[5:-4])
        except ValueError:
            continue

        src = os.path.join(args.source, name)
        png = Image.open(src).convert("RGBA")

        # 桥梁走单独分支：存到 bridges/，命名 bridge_<材质>_<段位>
        if num in BRIDGES:
            mat, part = BRIDGES[num]
            os.makedirs(BRIDGE_OUT, exist_ok=True)
            fname = f"bridge_{mat}_{part}"
            dst = os.path.join(BRIDGE_OUT, fname + ".png")
            png.save(dst)
            print(f"  {name:12s} -> bridges/{fname + '.png':24s} {size_str(png)}  桥·{mat}·{part}")
            count += 1
            remove_source(src)
            continue

        # 互动块走单独分支：存到 blocks/，命名 <材质>_<问号/感叹号>
        if num in BLOCKS:
            mat, kind = BLOCKS[num]
            os.makedirs(BLOCK_OUT, exist_ok=True)
            fname = f"block_{mat}_{kind}"
            dst = os.path.join(BLOCK_OUT, fname + ".png")
            png.save(dst)
            print(f"  {name:12s} -> blocks/{fname + '.png':28s} {size_str(png)}  互动块·{mat}·{kind}")
            count += 1
            remove_source(src)
            continue

        # 木箱子走单独分支：存到 crates/
        if num in CRATES:
            mat = CRATES[num]
            os.makedirs(CRATE_OUT, exist_ok=True)
            fname = f"crate_{mat}"
            dst = os.path.join(CRATE_OUT, fname + ".png")
            png.save(dst)
            print(f"  {name:12s} -> crates/{fname + '.png':26s} {size_str(png)}  木箱·{mat}")
            count += 1
            remove_source(src)
            continue

        # 木提示牌走单独分支：存到 signs/
        if num in SIGNS:
            mat = SIGNS[num]
            os.makedirs(SIGN_OUT, exist_ok=True)
            fname = f"sign_{mat}"
            dst = os.path.join(SIGN_OUT, fname + ".png")
            png.save(dst)
            print(f"  {name:12s} -> signs/{fname + '.png':25s} {size_str(png)}  提示牌·{mat}")
            count += 1
            remove_source(src)
            continue

        # 木梯走单独分支：存到 ladders/
        if num in LADDERS:
            mat = LADDERS[num]
            os.makedirs(LADDER_OUT, exist_ok=True)
            fname = f"ladder_{mat}"
            dst = os.path.join(LADDER_OUT, fname + ".png")
            png.save(dst)
            print(f"  {name:12s} -> ladders/{fname + '.png':24s} {size_str(png)}  木梯·{mat}")
            count += 1
            remove_source(src)
            continue

        # 水走单独分支：存到 water/
        if num in WATER:
            color, kind = WATER[num]
            os.makedirs(WATER_OUT, exist_ok=True)
            fname = f"water_{color}_{kind}"
            dst = os.path.join(WATER_OUT, fname + ".png")
            png.save(dst)
            print(f"  {name:12s} -> water/{fname + '.png':32s} {size_str(png)}  水·{color}·{kind}")
            count += 1
            remove_source(src)
            continue

        # 背景渐变块走单独分支：存到 background/
        if num in BACKGROUND:
            fam, step = BACKGROUND[num]
            os.makedirs(BACKGROUND_OUT, exist_ok=True)
            fname = f"bg_{fam}_{step}"
            dst = os.path.join(BACKGROUND_OUT, fname + ".png")
            png.save(dst)
            print(f"  {name:12s} -> background/{fname + '.png':22s} {size_str(png)}  背景·{fam}·{step}")
            count += 1
            remove_source(src)
            continue

        size, composite, surf, body = analyze(src)
        if surf is None:
            print(f"  跳过 {name}：认不出材质 {size}")
            continue

        if composite:
            if body and surf == body:
                # 上下同材质 = 实心块
                base = surf
                desc = f"实心 {surf}"
            else:
                base = f"{surf}_{body}" if body else surf
                desc = f"地表={surf}  主体={body}"
        else:
            base = surf
            desc = f"单层={surf}"
        if num in OVERRIDE:
            base = OVERRIDE[num][0]
            desc = OVERRIDE[num][1]

        # 同材质可能有多个纹理变体，重名就加 _2 / _3 ...
        fname = base
        n = 1
        while True:
            dst = os.path.join(OUT, fname + ".png")
            if not os.path.exists(dst):
                break
            old = Image.open(dst).convert("RGBA")
            if old.size == png.size and old.tobytes() == png.tobytes():
                print(f"  跳过 {name}：和 {fname}.png 完全重复")
                fname = None
                break
            n += 1
            fname = f"{base}_{n}"

        if fname is None:
            remove_source(src)
            continue

        png.save(dst)
        print(f"  {name:12s} -> {fname + '.png':22s} {size[0]}x{size[1]}  {desc}")
        count += 1

        # 源图搬走（不留副本在项目里），顺带清掉它的 .import
        remove_source(src)

    cleanup_orphans(args.source)
    print(f"\n共处理 {count} 张 -> {OUT}/")


def remove_source(src):
    """删掉源图和它的 .import。"""
    os.remove(src)
    imp = src + ".import"
    if os.path.exists(imp):
        os.remove(imp)


def size_str(png):
    return f"{png.size[0]}x{png.size[1]}"


def cleanup_orphans(source):
    """删掉 .png 已经不在、但 .import 还留着的孤儿文件。

    Godot 导入 PNG 时会在旁边写一个 X.png.import，PNG 被删后它不会自动跟着删。
    """
    removed = 0
    for name in sorted(os.listdir(source)):
        if not name.endswith(".import"):
            continue
        if not os.path.exists(os.path.join(source, name[:-7])):
            os.remove(os.path.join(source, name))
            print(f"  清理孤儿 {name}")
            removed += 1
    if removed:
        print(f"  共清理 {removed} 个孤儿 .import")


if __name__ == "__main__":
    main()
