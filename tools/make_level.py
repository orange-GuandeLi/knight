#!/usr/bin/env python3
"""生成关卡数据 scenes/levels/levelNN.json。

地图是字符网格，每格一个字符。脚本负责把地面、坑、桥、梯子、
互动块、木箱、史莱姆这些摆进去，输出成 JSON（关卡运行时读这个文件铺砖）。

改关卡 = 改这个脚本，然后重跑。

用法:
    python3 tools/make_level.py
"""

import json
import os

W, H = 120, 48
SURFACE = 26          # 主地面行
TOP_ROWS = 14         # 上方这 14 行自动留空（天空）

# 当前正在画的这张图
grid = []
WIDTH = W
HEIGHT = H

# 砖名字符表
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
    "W": "water_ice_surface",          # 水面线：浪花画在砖的下缘
    "w": "water_ice_surface_body",
    "v": "water_ice_body",
    # 冰面：地表用「冰面砖」（上面一层冰壳 + 分隔线），底下填「冰体砖」（通体一块冰）
    "i": "ice_stone",
    "I": "ice",
    # 雪面：同理，地表用「雪面砖」，底下填「雪体砖」
    "s": "snow_stone",
    "S": "snow_ice",
}

# 实体字符表
ENTITIES = {
    "o": "coin",
    "e": "slime",
    "E": "slime_purple",
    "k": "checkpoint",
    "f": "fruit",
}

# 三种桥用到的字符（桥是悬空的，上面不该长植物）
BRIDGE_CHARS = set("[=]{}+}()*")


# ---------------------------------------------------------------- 画图工具

def reset_grid(w=W, h=H):
    """开一张新图。"""
    global grid, WIDTH, HEIGHT
    WIDTH, HEIGHT = w, h
    grid = [["."] * w for _ in range(h)]


def put(x, y, ch):
    """放一个格子。如果覆盖了已有东西就警告——
    之前问号块被后来的金币弧线盖掉，排查了很久。"""
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        old = grid[y][x]
        if old != "." and old != ch:
            print("!! (%d,%d) 被 '%s' 覆盖成 '%s'" % (x, y, old, ch))
        grid[y][x] = ch


def put_force(x, y, ch):
    """有意覆盖已有格子（梯子穿平台、终点斜坡盖地面）。不报警。"""
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        grid[y][x] = ch


def rect(x, y, w, h, ch):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(xx, yy, ch)


def ground(x0, x1, surface="G", fill="d", top=SURFACE, bottom=None):
    """一段地面：top 行是地表砖，下面全是填充砖。"""
    if bottom is None:
        bottom = HEIGHT - 1
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
        # 梯子要穿过平台，人才能爬上去，这里是有意覆盖
        put_force(x, y, ch)


def coins(x0, x1, y, step=1):
    for i, x in enumerate(range(x0, x1 + 1, step)):
        put(x, y, "o")


def arc_coins(x0, y, n, rise=3):
    """拱形金币串。"""
    for i in range(n):
        x = x0 + i
        dy = int(round(rise * (1 - abs((n - 1) / 2 - i) / ((n - 1) / 2))))
        put(x, y - dy, "o")


def pool(x0, x1, surface="W", body="v", bottom=32, floor_ch="d"):
    """水池。水面线放在 SURFACE 这一行（跟路面同一行的位置），
    但浪花画在砖的下缘，所以水面实际比路面低一格。"""
    for x in range(x0, x1 + 1):
        put(x, SURFACE, surface)
        for y in range(SURFACE + 1, bottom):
            put(x, y, body)
        put(x, bottom, floor_ch)
        for y in range(bottom + 1, HEIGHT):
            put(x, y, floor_ch)


def wall(x, y0, y1, ch="d"):
    """竖直的一道墙（给墙跳用）。"""
    for y in range(y0, y1 + 1):
        put(x, y, ch)


def clear_sky():
    """顶部那几行是天空。"""
    for y in range(TOP_ROWS):
        grid[y] = ["."] * WIDTH


# ---------------------------------------------------------------- 植物装饰

def fill_pits_with_water():
    """没地面的列就是悬崖，灌上水：掉下去是淹死，不是掉进虚空。

    判据是 SURFACE 行有没有砖——桥、平台那些行不在这一行，不受影响。
    """
    for x in range(WIDTH):
        if grid[SURFACE][x] != ".":
            continue
        for y in range(SURFACE, HEIGHT):
            put(x, y, "W" if y == SURFACE else "v")


def clear_crumble_cells(crumbles):
    """会塌的地板要占掉那块地形——不然它塌了下面还是实地，玩家掉不下去。"""
    for c in crumbles:
        x0 = int(c["x"])
        y0 = int(c["y"])
        w = int(c.get("tiles", 2))
        for x in range(x0, x0 + w):
            put_force(x, y0, ".")


def place_decor(trees, grass):
    """把树和草画进图里（占位符 P），顺便检查有没有撞到别的东西。"""
    conflicts = []
    for (x, y, kind, bodies) in trees:
        cells = [(x, y)] + [(x, y - 1 - i) for i in range(bodies)] + [(x, y - 1 - bodies)]
        for (cx, cy) in cells:
            if 0 <= cx < WIDTH and 0 <= cy < HEIGHT:
                if grid[cy][cx] != ".":
                    conflicts.append("树 %s@x%d (x%d,y%d) 撞到 '%s'"
                                     % (kind, x, cx, cy, grid[cy][cx]))
        # 脚下是桥的话，植物就悬在桥上了，不对
        if y + 1 < HEIGHT and grid[y + 1][x] in BRIDGE_CHARS:
            conflicts.append("树 %s@x%d 站在桥上（脚下是 '%s'）"
                             % (kind, x, grid[y + 1][x]))
    for (x, y, kind, n) in grass:
        if 0 <= x < WIDTH and 0 <= y < HEIGHT and grid[y][x] != ".":
            conflicts.append("草 %s@x%d (x%d,y%d) 撞到 '%s'" % (kind, x, x, y, grid[y][x]))
        if y + 1 < HEIGHT and grid[y + 1][x] in BRIDGE_CHARS:
            conflicts.append("草 %s@x%d 站在桥上（脚下是 '%s'）"
                             % (kind, x, grid[y + 1][x]))

    # 占位，防止植物互相重叠
    for (x, y, kind, bodies) in trees:
        for cy in range(y - bodies, y + 1):
            put(x, cy, "P")
    for (x, y, kind, n) in grass:
        put(x, y, "P")

    return conflicts


def make_data(trees, grass, conflicts, time_limit, spawn=None, platforms=None,
              crumbles=None, rocks=None, boss=None, sections=None):
    clear_sky()
    lines = []
    for y in range(TOP_ROWS, HEIGHT):
        lines.append("".join(grid[y]))
    # 收集目标：关卡里六成的金币。剩下的当加分，不强求全收集。
    n_coins = sum(1 for row in lines for c in row if c == "o")
    goal = max(1, n_coins * 3 // 5)
    return {
        "width": WIDTH,
        "height": HEIGHT,
        "top_rows": TOP_ROWS,
        "spawn": list(spawn) if spawn else [4, SURFACE],
        "map": lines,
        "tiles": TILES,
        "entities": ENTITIES,
        "decor": {
            "trees": [{"x": x, "y": y, "kind": k, "bodies": b} for (x, y, k, b) in trees],
            "grass": [{"x": x, "y": y, "kind": k, "n": n} for (x, y, k, n) in grass],
        },
        "time_limit": time_limit,
        "coin_goal": goal,
        "platforms": platforms or [],
        "crumbles": crumbles or [],
        "rocks": rocks or [],
        "boss": boss,
        "sections": sections or [],
    }, conflicts


# ---------------------------------------------------------------- 移动平台
#
# x/y = 左上角那一格的坐标，tiles = 几块砖宽，dx/dy = 一趟走多远（像素），
# speed = 速度，phase = 起始相位（错开几块平台的节奏）。

PLATFORMS_1 = [
    # 第一个水坑的「船」：坑 13~16 共 4 格，船 2 格宽、来回 2 格
    {"x": 13, "y": 26, "tiles": 2, "dx": 32, "dy": 0, "speed": 34, "phase": 0.0},
    # 大水池的「船」：池 67~80 共 14 格，船 3 格宽、来回 11 格
    {"x": 67, "y": 26, "tiles": 3, "dx": 176, "dy": 0, "speed": 42, "phase": 0.4},
    # 第二个池子的船：池 137~150 共 14 格
    {"x": 137, "y": 26, "tiles": 3, "dx": 176, "dy": 0, "speed": 44, "phase": 0.15},
    # 第三个池子的船：池 172~181 共 10 格
    {"x": 172, "y": 26, "tiles": 3, "dx": 112, "dy": 0, "speed": 40, "phase": 0.6},
    # 冰面上方悬空的小平台：纯空中，不碰地面
    {"x": 158, "y": 23, "tiles": 2, "dx": 64, "dy": 0, "speed": 38, "phase": 0.2},
]

PLATFORMS_2 = [
    # 冰面上方悬空的小平台：纯空中
    {"x": 16, "y": 23, "tiles": 3, "dx": 72, "dy": 0, "speed": 40, "phase": 0.2},
    # 大池子的船：池 67~80 共 14 格
    {"x": 67, "y": 26, "tiles": 3, "dx": 176, "dy": 0, "speed": 44, "phase": 0.4},
    # 第三个池子的船：池 180~191 共 12 格
    {"x": 180, "y": 26, "tiles": 3, "dx": 144, "dy": 0, "speed": 42, "phase": 0.7},
    # 高低平台区的升降台：整段都在空中
    {"x": 133, "y": 22, "tiles": 2, "dx": 0, "dy": -16, "speed": 22, "phase": 0.0},
]

PLATFORMS_3 = [
    # 大池子的船：池 67~79 共 13 格
    {"x": 67, "y": 26, "tiles": 3, "dx": 160, "dy": 0, "speed": 44, "phase": 0.3},
    # 第三个池子的船：池 140~151 共 12 格
    {"x": 140, "y": 26, "tiles": 3, "dx": 144, "dy": 0, "speed": 42, "phase": 0.6},
    # 竖井上方悬空的小平台：纯空中
    {"x": 96, "y": 22, "tiles": 2, "dx": 48, "dy": 0, "speed": 32, "phase": 0.1},
]


# ---------------------------------------------------------------- 机关
#
# crumbles: 会塌的地板。x/y = 那一块的坐标，tiles = 几块砖宽
# rocks:    落石。x = 落点列，delay = 第几秒开始掉
# boss:     BOSS。x = 出生列

CRUMBLES_1 = [
    # 塌板放在实地上：踩上去就塌，得赶紧跳过去
    {"x": 124, "y": 26, "tiles": 2, "material": "dirt"},
    {"x": 199, "y": 26, "tiles": 2, "material": "dirt"},
]

ROCKS_1 = [
    # 雪地走廊的落石
    {"x": 187, "delay": 1.0},
    {"x": 190, "delay": 2.2},
]

CRUMBLES_2 = [
    {"x": 146, "y": 26, "tiles": 2, "material": "dirt"},
    {"x": 160, "y": 26, "tiles": 2, "material": "gold"},
]

ROCKS_2 = [
    # 木箱阵上方的落石
    {"x": 145, "delay": 1.2},
    {"x": 149, "delay": 2.4},
    {"x": 153, "delay": 3.6},
]

CRUMBLES_3 = [
    {"x": 176, "y": 26, "tiles": 3, "material": "dirt"},
    {"x": 190, "y": 26, "tiles": 2, "material": "gold"},
]

ROCKS_3 = [
    # 池子之后的走廊落石
    {"x": 155, "delay": 1.2},
    {"x": 159, "delay": 2.6},
    {"x": 163, "delay": 4.0},
]

BOSS_3 = {"x": 214}

# 关卡节奏：每一段标一个「角色」，关卡编辑器按顺序读
# intro    = 开场铺垫，安全
# challenge = 小挑战
# reward   = 奖励区（检查点 / 水果）
# climax   = 高潮（密集敌人、机关）
# outro    = 收尾冲刺

SECTIONS_1 = [
    ["intro", 0, 12],
    ["challenge", 13, 30],
    ["reward", 31, 46],
    ["challenge", 47, 64],
    ["climax", 65, 96],
    ["reward", 97, 110],
    ["challenge", 111, 134],
    ["climax", 135, 170],
    ["climax", 171, 205],
    ["outro", 206, 239],
]

SECTIONS_2 = [
    ["intro", 0, 10],
    ["challenge", 11, 30],
    ["reward", 31, 46],
    ["challenge", 47, 64],
    ["climax", 65, 100],
    ["reward", 101, 116],
    ["challenge", 117, 140],
    ["climax", 141, 178],
    ["climax", 179, 206],
    ["outro", 207, 229],
]

SECTIONS_3 = [
    ["intro", 0, 12],
    ["challenge", 13, 32],
    ["reward", 33, 46],
    ["challenge", 47, 62],
    ["climax", 63, 96],
    ["reward", 97, 112],
    ["challenge", 113, 138],
    ["climax", 139, 172],
    ["climax", 173, 206],
    ["climax", 207, 229],
]


# ---------------------------------------------------------------- 第 1 关

def build_level_01():
    """草原。教学关：一关里把每个机制先单独教一遍，再组合起来。

    跨越规则（16px 一格）：
      缺口 <= 4 格  -> 二段跳能过
      缺口 5~8 格   -> 用桥，走过去
      缺口 >= 9 格  -> 坐船
    """
    reset_grid(240, 48)

    # ===== 1. intro (0~12)：平地，教会移动 =====
    ground(0, 12)
    put(3, 25, "n")            # 提示牌
    coins(5, 8, 24)

    # ===== 2. challenge (13~30)：第一个水坑，教跳跃 =====
    # 13~16 是 4 格宽的坑，二段跳刚好能过
    ground(17, 30)
    arc_coins(18, 24, 6)       # 拱形金币串
    put(24, 22, "1")           # 问号块
    put(28, 22, "2")           # 感叹号块

    # ===== 3. reward (31~46)：梯子高台，教爬梯 =====
    ground(31, 46)
    platform(34, 41, 20, "r")
    ladder(34, 20, 25)         # 梯子穿过平台
    coins(35, 39, 19)
    put(40, 19, "f")           # 水果：护盾
    put(44, 25, "k")           # 检查点

    # ===== 4. challenge (47~64)：泥桥跨 6 格水坑 + 第一个史莱姆 =====
    bridge(47, 52, SURFACE, "dirt")
    ground(53, 64)
    put(50, 25, "e")           # 史莱姆在桥这边
    put(57, 22, "2")
    put(61, 25, "e")           # 第二只绿史莱姆
    coins(55, 57, 24)

    # ===== 5. climax (65~96)：大水池，坐船过 =====
    # 67~80 共 14 格宽，必须坐船
    ground(65, 66)
    ground(81, 96)
    platform(84, 92, 18, "p")
    ladder(84, 18, 25, "purple_rock")
    coins(85, 87, 17)
    put(88, 15, "5")
    put(94, 25, "k")           # 检查点

    # ===== 6. reward (97~110)：冰面 + 水果 =====
    ground(97, 110, surface="i", fill="I")
    put(99, 25, "E")           # 紫史莱姆
    put(104, 25, "k")          # 检查点
    coins(100, 103, 24)

    # ===== 7. challenge (111~134)：4 格坑 + 木箱阵 =====
    # 111~114 是 4 格坑
    ground(115, 134)
    put(119, 25, "c")          # 木箱
    put(123, 25, "C")
    put(128, 25, "E")
    put(131, 25, "e")
    coins(116, 118, 24)

    # ===== 8. climax (135~170)：第二个大水池 + 冰面冲刺 =====
    # 137~150 共 14 格宽
    ground(135, 136)
    ground(151, 170, surface="i", fill="I")
    put(155, 25, "E")
    put(160, 25, "E")
    put(166, 25, "k")          # 检查点
    coins(156, 159, 24)

    # ===== 9. climax (171~205)：雪地 + 塌板 + 落石 =====
    # 172~181 共 10 格宽的池子
    ground(171, 171)
    ground(182, 205, surface="s", fill="S")
    put(190, 25, "k")          # 检查点
    put(196, 25, "E")
    put(202, 25, "e")
    coins(183, 185, 24)

    # ===== 10. outro (206~239)：爬坡到终点 =====
    ground(206, 239)
    for (x, y) in [(210, 25), (211, 24), (212, 23), (213, 22), (214, 21),
                   (215, 20), (216, 19), (217, 18), (218, 17), (219, 16),
                   (220, 15), (221, 14), (222, 13), (223, 12), (224, 11),
                   (225, 10), (226, 9), (227, 8), (228, 7), (229, 6),
                   (230, 5), (231, 4), (232, 3), (233, 2), (234, 1),
                   (235, 0), (236, 0), (237, 0), (238, 0), (239, 0)]:
        put_force(x, y, "G")
        for yy in range(y + 1, HEIGHT):
            put_force(x, yy, "d")

    trees = [
        (9, 25, "green", 1),
        (11, 25, "green", 0),
        (36, 25, "green", 2),
        (45, 25, "green", 1),
        (62, 25, "gold", 1),
        (89, 25, "moss", 2),
        (108, 25, "green", 0),
        (148, 25, "gold", 1),
        (187, 25, "moss", 1),
        (208, 25, "green", 2),
    ]
    grass = [
        (2, 25, "green", 1),
        (5, 25, "green", 2),
        (19, 25, "green", 3),
        (24, 25, "green", 1),
        (37, 25, "moss", 2),
        (55, 25, "green", 3),
        (86, 25, "moss", 1),
        (101, 25, "green", 2),
        (117, 25, "green", 1),
        (157, 25, "moss", 3),
        (184, 25, "green", 1),
        (207, 25, "moss", 2),
    ]

    fill_pits_with_water()
    clear_crumble_cells(CRUMBLES_1)
    conflicts = place_decor(trees, grass)
    data, conflicts = make_data(trees, grass, conflicts, 240, platforms=PLATFORMS_1,
        crumbles=CRUMBLES_1, rocks=ROCKS_1, sections=SECTIONS_1)
    return data, conflicts


# ---------------------------------------------------------------- 第 2 关

def build_level_02():
    """冰原。冰面冲刺 + 紫史莱姆 + 木箱阵。230 格（约 5 屏）。

    主题：冰面。冰上刹不住，所以这里到处是「滑到边缘就掉水」的段落。
    """
    reset_grid(230, 48)

    # ===== 1. intro (0~10)：平地 =====
    ground(0, 10)
    put(3, 25, "n")
    coins(5, 8, 24)

    # ===== 2. challenge (11~30)：第一段冰面，滑行 =====
    ground(11, 30, surface="i", fill="I")
    put(24, 25, "k")           # 检查点
    coins(14, 21, 24)

    # ===== 3. reward (31~46)：高台 + 水果，从冰上停下来喘口气 =====
    ground(31, 46)
    platform(34, 41, 20, "r")
    ladder(34, 20, 25)
    coins(35, 37, 19)
    put(38, 19, "f")           # 水果：护盾
    put(43, 25, "k")

    # ===== 4. challenge (47~64)：泥桥跨 6 格 + 史莱姆 =====
    bridge(47, 52, SURFACE, "dirt")
    ground(53, 64)
    put(56, 25, "e")
    put(60, 25, "E")
    put(62, 25, "e")
    coins(57, 59, 24)

    # ===== 5. climax (65~100)：大池子坐船 + 冰上冲刺 =====
    # 67~80 共 14 格宽
    ground(65, 66)
    ground(81, 100, surface="i", fill="I")
    put(85, 25, "E")
    put(90, 25, "E")
    put(94, 25, "k")           # 检查点
    coins(86, 89, 24)

    # ===== 6. reward (101~116)：雪地 + 检查点 =====
    ground(101, 116, surface="s", fill="S")
    put(104, 25, "E")
    put(112, 25, "k")
    coins(105, 108, 24)

    # ===== 7. challenge (117~140)：4 格坑 + 高低平台 =====
    # 117~120 是 4 格坑
    ground(121, 140)
    platform(123, 130, 20, "r")
    coins(124, 129, 19)
    put(127, 17, "1")
    put(134, 25, "c")          # 木箱

    # ===== 8. climax (141~178)：木箱阵 + 落石 + 紫史莱姆 =====
    ground(141, 178)
    put(144, 25, "c")
    put(148, 25, "c")
    put(152, 25, "C")
    put(157, 25, "E")
    put(162, 25, "E")
    put(165, 25, "e")
    put(168, 25, "k")          # 检查点
    coins(145, 147, 24)

    # ===== 9. climax (179~206)：第三个池子 + 冰面 =====
    # 180~191 共 12 格宽
    ground(179, 179)
    ground(192, 206, surface="i", fill="I")
    put(197, 25, "E")
    put(202, 25, "e")
    coins(193, 196, 24)

    # ===== 10. outro (207~229)：爬坡到终点 =====
    ground(207, 229)
    for (x, y) in [(211, 25), (212, 24), (213, 23), (214, 22), (215, 21),
                   (216, 20), (217, 19), (218, 18), (219, 17), (220, 16),
                   (221, 15), (222, 14), (223, 13), (224, 12), (225, 11),
                   (226, 10), (227, 9), (228, 8), (229, 7)]:
        put_force(x, y, "G")
        for yy in range(y + 1, HEIGHT):
            put_force(x, yy, "d")

    trees = [
        (10, 25, "green", 1),
        (35, 25, "green", 2),
        (61, 25, "moss", 1),
        (91, 25, "green", 0),
        (111, 25, "gold", 1),
        (126, 25, "moss", 2),
        (150, 25, "green", 1),
        (170, 25, "gold", 2),
        (199, 25, "moss", 1),
        (210, 25, "green", 0),
    ]
    grass = [
        (1, 25, "green", 1),
        (6, 25, "green", 2),
        (28, 25, "moss", 3),
        (44, 25, "green", 1),
        (64, 25, "green", 2),
        (86, 25, "moss", 1),
        (106, 25, "green", 3),
        (122, 25, "moss", 2),
        (145, 25, "green", 1),
        (163, 25, "moss", 3),
        (194, 25, "green", 2),
        (208, 25, "moss", 1),
    ]

    fill_pits_with_water()
    clear_crumble_cells(CRUMBLES_2)
    conflicts = place_decor(trees, grass)
    data, conflicts = make_data(trees, grass, conflicts, 280, platforms=PLATFORMS_2,
        crumbles=CRUMBLES_2, rocks=ROCKS_2, sections=SECTIONS_2)
    return data, conflicts


# ---------------------------------------------------------------- 第 3 关

def build_level_03():
    """深塔。墙跳竖井 + 高低错落的平台 + BOSS。230 格（约 5 屏）。

    主题：垂直。前面教墙跳，最后在 BOSS 场地决战。
    """
    reset_grid(230, 48)

    # ===== 1. intro (0~12)：平地 =====
    ground(0, 12)
    put(3, 25, "n")
    coins(5, 8, 24)

    # ===== 2. challenge (13~32)：两层错开的平台 =====
    ground(13, 32)
    platform(15, 21, 22, "r")
    coins(16, 20, 21)
    put(22, 19, "1")
    put(28, 25, "e")
    platform(24, 31, 18, "p")
    coins(25, 30, 17)

    # ===== 3. reward (33~46)：梯子高台 + 水果 + 检查点 =====
    ground(33, 46)
    platform(36, 43, 20, "r")
    ladder(36, 20, 25)
    coins(37, 41, 19)
    put(42, 19, "f")
    put(44, 25, "k")

    # ===== 4. challenge (47~62)：墙跳竖井（可选的捷径）=====
    # 竖井在主线右边，是「想走捷径就得会墙跳」的设计，不是必经之路
    ground(47, 62)
    wall(48, 18, 25, "d")
    wall(52, 20, 25, "d")
    platform(49, 51, 18, "r")
    coins(49, 51, 17)
    put(50, 16, "f")           # 蹬墙上来才拿得到的奖励
    put(46, 25, "k")

    # ===== 5. climax (63~96)：冰面 + 紫史莱姆 + 大池子 =====
    ground(63, 66)
    ground(67, 66)
    ground(80, 96, surface="i", fill="I")
    put(84, 25, "E")
    put(89, 25, "E")
    put(91, 25, "e")
    put(93, 25, "k")          # 检查点
    coins(81, 83, 24)

    # ===== 6. reward (97~112)：雪地 + 检查点 =====
    ground(97, 112, surface="s", fill="S")
    put(101, 25, "E")
    put(108, 25, "k")
    coins(98, 100, 24)

    # ===== 7. challenge (113~138)：木箱阵 + 高低平台 =====
    ground(113, 138)
    put(116, 25, "c")
    put(120, 25, "C")
    platform(125, 133, 20, "p")
    ladder(125, 20, 25, "purple_rock")
    coins(126, 131, 19)
    put(132, 17, "6")
    put(136, 25, "k")

    # ===== 8. climax (139~172)：第三个池子 + 落石 =====
    # 140~151 共 12 格宽
    ground(139, 139)
    ground(152, 172)
    put(158, 25, "E")
    put(162, 25, "e")
    put(166, 25, "k")         # 检查点
    coins(153, 155, 24)

    # ===== 9. climax (173~206)：第二个墙跳竖井 + 塌板 =====
    ground(173, 206)
    wall(180, 18, 25, "d")
    wall(184, 20, 25, "d")
    platform(181, 183, 18, "r")
    coins(181, 183, 17)
    put(196, 25, "c")         # 木箱
    put(200, 25, "E")
    put(202, 25, "e")
    put(204, 25, "k")         # 检查点（BOSS 前）

    # ===== 10. outro (207~229)：BOSS 场地 =====
    # 一块 16 格宽的空地，决战用
    ground(207, 229)

    trees = [
        (11, 25, "green", 1),
        (26, 25, "gold", 2),
        (42, 25, "moss", 1),
        (58, 25, "green", 2),
        (86, 25, "green", 0),
        (104, 25, "gold", 1),
        (122, 25, "moss", 2),
        (160, 25, "green", 1),
        (190, 25, "gold", 1),
        (212, 25, "moss", 1),
    ]
    grass = [
        (2, 25, "green", 2),
        (30, 25, "green", 1),
        (37, 25, "moss", 3),
        (55, 25, "green", 1),
        (87, 25, "moss", 2),
        (98, 25, "green", 3),
        (118, 25, "moss", 1),
        (145, 25, "green", 2),
        (174, 25, "moss", 3),
        (209, 25, "green", 1),
    ]

    fill_pits_with_water()
    clear_crumble_cells(CRUMBLES_3)
    conflicts = place_decor(trees, grass)
    data, conflicts = make_data(trees, grass, conflicts, 300, platforms=PLATFORMS_3,
        crumbles=CRUMBLES_3, rocks=ROCKS_3, boss=BOSS_3, sections=SECTIONS_3)
    return data, conflicts


# ---------------------------------------------------------------- 输出

LEVELS = [
    ("level01.json", build_level_01),
    ("level02.json", build_level_02),
    ("level03.json", build_level_03),
]


def main():
    os.makedirs("scenes/levels", exist_ok=True)
    for filename, builder in LEVELS:
        data, conflicts = builder()
        if conflicts:
            print("!! %s 植物位置冲突 %d 处：" % (filename, len(conflicts)))
            for c in conflicts:
                print("   " + c)
        path = os.path.join("scenes/levels", filename)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)

        n_coin = sum(1 for row in data["map"] for c in row if c == "o")
        n_slime = sum(1 for row in data["map"] for c in row if c == "e")
        n_purple = sum(1 for row in data["map"] for c in row if c == "E")
        n_cp = sum(1 for row in data["map"] for c in row if c == "k")
        deco = data["decor"]
        print("写出 %s  (%dx%d，限时 %ds)"
              % (path, data["width"], data["height"], data["time_limit"]))
        print("   金币 %d，史莱姆 %d（紫 %d），检查点 %d，树 %d，草 %d"
              % (n_coin, n_slime, n_purple, n_cp,
                 len(deco["trees"]), len(deco["grass"])))


if __name__ == "__main__":
    main()
