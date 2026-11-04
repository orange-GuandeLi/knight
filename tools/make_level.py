#!/usr/bin/env python3
"""生成关卡数据 scripts/levels/level01_data.gd。

地图是 120x48 的字符网格，每格一个字符。脚本负责把地面、坑、桥、梯子、
互动块、木箱、史莱姆这些摆进去，输出成 GDScript 常量。

改关卡 = 改这个脚本，然后重跑。

用法:
    python3 tools/make_level.py
"""

W, H = 120, 48
SURFACE = 26          # 主地面行
TOP_ROWS = 14         # 上方这 14 行自动留空（天空）

grid = [["."] * W for _ in range(H)]


def put(x, y, ch):
    if 0 <= x < W and 0 <= y < H:
        grid[y][x] = ch


def rect(x, y, w, h, ch):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(xx, yy, ch)


def ground(x0, x1, surface="G", fill="d", top=SURFACE, bottom=H - 1):
    """一段地面：top 行是地表砖，下面全是填充砖。"""
    for x in range(x0, x1 + 1):
        put(x, top, surface)
        for y in range(top + 1, bottom + 1):
            put(x, y, fill)


def platform(x0, x1, y, tile="r", thick=1):
    rect(x0, y, x1 - x0 + 1, thick, tile)


def bridge(x0, x1, y, mat="dirt"):
    start, mid, end = {"dirt": ("[", "=", "]"),
                       "pale_rock": ("{", "+", "}"),
                       "purple_rock": ("(", "*", ")")}[mat]
    for x in range(x0, x1 + 1):
        if x == x0:
            put(x, y, start)
        elif x == x1:
            put(x, y, end)
        else:
            put(x, y, mid)


def ladder(x, y0, y1, mat="dirt"):
    ch = "H" if mat == "dirt" else "h"
    for y in range(y0, y1 + 1):
        put(x, y, ch)


def coins(x0, x1, y, step=1):
    for i, x in enumerate(range(x0, x1 + 1, step)):
        put(x, y, "o")


def arc_coins(x0, y, n, rise=3):
    """拱形金币串。"""
    for i in range(n):
        x = x0 + i
        dy = int(round(rise * (1 - abs((n - 1) / 2 - i) / ((n - 1) / 2))))
        put(x, y - dy, "o")


# ---------------------------------------------------------------- 关卡内容

# 1. 起步区：平地 + 提示牌 + 几枚金币
ground(0, 13)
put(3, 25, "n")
coins(5, 8, 24)

# 2. 第一个坑
# 3. 问号块区
ground(18, 26)
arc_coins(19, 24, 6)
put(21, 22, "1")
put(24, 22, "2")

# 4. 坑 + 泥土桥
bridge(27, 33, SURFACE, "dirt")

# 5. 史莱姆巡逻区
ground(34, 44)
put(38, 25, "e")
coins(35, 37, 24)

# 6. 梯子 + 高台 + 问号块
platform(45, 52, 20, "r")
ladder(45, 20, 25)      # 梯子穿过平台，人才能爬上去
put(48, 17, "1")        # 块要够高才顶得到
coins(46, 51, 19)
ground(45, 52)

# 7. 坑 + 浅岩桥
bridge(53, 58, SURFACE, "pale_rock")

# 8. 双史莱姆 + 感叹号块
ground(59, 68)
put(61, 25, "e")
put(66, 25, "e")
put(65, 22, "2")
coins(62, 64, 24)

# 9. 水池：水面在 SURFACE 行，往下填到池底
for x in range(69, 79):
    put(x, SURFACE, "w")
    for y in range(SURFACE + 1, 32):
        put(x, y, "v")
    put(x, 32, "d")
    for y in range(33, H):
        put(x, y, "d")

# 10. 木箱 + 提示牌
ground(79, 90)
put(81, 25, "c")
put(85, 25, "C")
put(88, 25, "n")
put(83, 25, "o")

# 11. 高空紫岩台 + 紫岩桥
platform(91, 99, 18, "p")
ladder(91, 18, 25, "purple_rock")
coins(92, 97, 17)
put(95, 15, "5")
ground(91, 99)
bridge(100, 105, SURFACE, "purple_rock")

# 12. 裂纹地面 + 史莱姆
ground(106, 113, surface="x", fill="d")
put(109, 25, "e")
coins(107, 108, 24)

# 13. 终点爬坡
ground(114, 119)
for i, (x, y) in enumerate([(115, 25), (116, 24), (117, 23), (118, 22), (119, 21)]):
    put(x, y, "G")
    for yy in range(y + 1, H):
        put(x, yy, "d")

# 顶部那几行是天空
for y in range(TOP_ROWS):
    grid[y] = ["."] * W

# ---------------------------------------------------------------- 植物装饰

# 树：(列, 底部所在行, 颜色, body 段数)。body 可以任意多个，树就任意高。
TREES = [
    (9, 25, "green", 1),
    (11, 25, "green", 0),
    (34, 25, "green", 2),
    (43, 25, "green", 1),
    (86, 25, "green", 0),
    (30, 25, "gold", 1),
    (111, 25, "gold", 1),
    (59, 25, "moss", 2),
    (84, 25, "moss", 1),
]

# 草丛：(列, 行, 颜色, 第几株)
GRASS = [
    (2, 25, "green", 1),
    (5, 25, "green", 2),
    (19, 25, "green", 3),
    (23, 25, "green", 1),
    (36, 25, "green", 2),
    (41, 25, "green", 3),
    (60, 25, "green", 1),
    (80, 25, "moss", 2),
    (82, 25, "moss", 3),
    (107, 25, "moss", 1),
    (117, 22, "green", 2),
]

conflicts = []
for (x, y, kind, bodies) in TREES:
    cells = [(x, y)] + [(x, y - 1 - i) for i in range(bodies)] + [(x, y - 1 - bodies)]
    for (cx, cy) in cells:
        if 0 <= cx < W and 0 <= cy < H:
            if grid[cy][cx] != ".":
                conflicts.append("树 %s@x%d (x%d,y%d) 撞到 '%s'" % (kind, x, cx, cy, grid[cy][cx]))
for (x, y, kind, n) in GRASS:
    if grid[y][x] != ".":
        conflicts.append("草 %s@x%d (x%d,y%d) 撞到 '%s'" % (kind, x, x, y, grid[y][x]))

# 占位，防止植物互相重叠
for (x, y, kind, bodies) in TREES:
    for cy in range(y - bodies, y + 1):
        grid[cy][x] = "P"
for (x, y, kind, n) in GRASS:
    grid[y][x] = "P"

if conflicts:
    print("!! 植物位置冲突 %d 处：" % len(conflicts))
    for c in conflicts:
        print("   " + c)
else:
    print("植物位置无冲突")


# ---------------------------------------------------------------- 输出

TILES = {
    "G": "grass_dirt",
    "d": "dirt",
    "r": "pale_rock",
    "p": "purple_rock",
    "x": "cracked_dirt",
    "n": "sign_dirt",
    "c": "crate_dirt",
    "C": "crate_purple_rock",
    "H": "ladder_dirt",
    "h": "ladder_purple_rock",
    "[": "bridge_dirt_start", "=": "bridge_dirt_middle", "]": "bridge_dirt_end",
    "{": "bridge_pale_rock_start", "+": "bridge_pale_rock_middle", "}": "bridge_pale_rock_end",
    "(": "bridge_purple_rock_start", "*": "bridge_purple_rock_middle", ")": "bridge_purple_rock_end",
    "1": "block_dirt_question", "2": "block_dirt_exclaim",
    "3": "block_pale_rock_question", "4": "block_pale_rock_exclaim",
    "5": "block_purple_rock_question", "6": "block_purple_rock_exclaim",
    "7": "block_stone_question", "8": "block_stone_exclaim",
    "w": "water_ice_surface_body",
    "v": "water_ice_body",
}

import json

lines = []
for y in range(TOP_ROWS, H):
    lines.append("".join(grid[y]))

data = {
    "width": W,
    "height": H,
    "top_rows": TOP_ROWS,
    "spawn": [4, SURFACE],
    "map": lines,
    "tiles": TILES,
    "entities": {"o": "coin", "e": "slime"},
    "decor": {
        "trees": [{"x": x, "y": y, "kind": k, "bodies": b} for (x, y, k, b) in TREES],
        "grass": [{"x": x, "y": y, "kind": k, "n": n} for (x, y, k, n) in GRASS],
    },
}

with open("scenes/levels/level01.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)

n_coin = sum(1 for row in grid for c in row if c == "o")
n_slime = sum(1 for row in grid for c in row if c == "e")
print(f"写出 scenes/levels/level01.json  ({W}x{H}，顶部 {TOP_ROWS} 行留空)")
print(f"金币 {n_coin} 个，史莱姆 {n_slime} 只，树 {len(TREES)} 棵，草丛 {len(GRASS)} 株")
