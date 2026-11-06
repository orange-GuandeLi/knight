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


def pool(x0, x1, surface="w", body="v", bottom=32, floor_ch="d"):
    """水池：水面在 SURFACE 行，往下填到池底。"""
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
            put(x, y, "w" if y == SURFACE else "v")


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


def make_data(trees, grass, conflicts, time_limit, spawn=None):
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
    }, conflicts


# ---------------------------------------------------------------- 第 1 关

def build_level_01():
    """草原。基础教学关：跑跳、翻滚、史莱姆、水池。240 格（约 5 屏）。"""
    reset_grid(240, 48)

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
    put(32, 25, "k")          # 检查点：过了桥有个落脚点

    # 5. 史莱姆巡逻区
    ground(34, 44)
    put(38, 25, "e")
    coins(35, 37, 24)

    # 6. 梯子 + 高台 + 问号块
    platform(45, 52, 20, "r")
    ladder(45, 20, 25)      # 梯子穿过平台，人才能爬上去
    put(48, 17, "1")        # 块要够高才顶得到
    coins(46, 50, 19)
    put(51, 19, "f")        # 水果：给一层护盾
    ground(45, 52)

    # 7. 坑 + 浅岩桥
    bridge(53, 58, SURFACE, "pale_rock")

    # 8. 双史莱姆 + 感叹号块 + 检查点
    ground(59, 68)
    put(61, 25, "e")
    put(66, 25, "e")
    put(65, 22, "2")
    put(65, 25, "k")          # 检查点
    coins(62, 64, 24)

    # 9. 水池：水面在 SURFACE 行，往下填到池底
    pool(69, 78)

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
    put(95, 25, "k")          # 检查点
    ground(91, 99)
    bridge(100, 105, SURFACE, "purple_rock")

    # 12. 冰面 + 裂纹地面 + 史莱姆
    ground(106, 109, surface="i", fill="I")     # 冰面：踩上去刹不住
    ground(110, 113, surface="x", fill="d")     # 裂纹地面
    put(108, 25, "E")
    coins(107, 108, 24)

    # ==== 下面是新加的一段，把关卡从 3 屏拉到 5 屏 ====

    # 13. 浅岩桥 + 问号块
    bridge(114, 121, SURFACE, "pale_rock")
    put(118, 22, "3")

    # 14. 梯子 + 高台 + 水果
    ground(122, 133)
    platform(125, 132, 20, "r")
    ladder(125, 20, 25)
    coins(126, 131, 19)
    put(129, 19, "f")

    # 15. 双史莱姆 + 检查点
    ground(134, 147)
    put(137, 25, "e")
    put(141, 25, "E")
    put(144, 25, "k")
    coins(135, 136, 24)

    # 16. 木箱阵 + 紫史莱姆
    ground(148, 161)
    put(150, 25, "c")
    put(153, 25, "C")
    put(156, 25, "E")
    coins(151, 152, 24)

    # 17. 冰面冲刺 + 检查点
    ground(162, 177, surface="i", fill="I")
    put(166, 25, "E")
    put(171, 25, "k")
    coins(167, 170, 24)

    # 18. 雪面 + 问号块 + 紫史莱姆
    ground(178, 191, surface="s", fill="S")
    put(181, 22, "7")
    put(185, 25, "E")
    coins(179, 180, 24)

    # 19. 水池
    pool(192, 201)

    # 20. 高台 + 紫岩 + 感叹号块
    ground(202, 213)
    platform(203, 209, 19, "p")
    ladder(203, 19, 25, "purple_rock")
    coins(204, 208, 18)
    put(206, 16, "6")

    # 21. 裂纹地面 + 木箱 + 紫史莱姆
    ground(214, 225, surface="x", fill="d")
    put(217, 25, "c")
    put(220, 25, "E")
    put(222, 25, "k")
    coins(215, 216, 24)

    # 22. 终点爬坡
    ground(226, 239)
    for (x, y) in [(230, 25), (231, 24), (232, 23), (233, 22), (234, 21),
                   (235, 20), (236, 19), (237, 18), (238, 17), (239, 16)]:
        put(x, y, "G")
        for yy in range(y + 1, HEIGHT):
            put(x, yy, "d")

    trees = [
        (9, 25, "green", 1),
        (11, 25, "green", 0),
        (34, 25, "green", 2),
        (43, 25, "green", 1),
        (86, 25, "green", 0),
        (25, 25, "gold", 1),     # 原来放在 x=30，那儿是桥，植物不长在桥上
        (111, 25, "gold", 1),
        (59, 25, "moss", 2),
        (84, 25, "moss", 1),
        (130, 25, "green", 2),
        (159, 25, "moss", 1),
        (205, 25, "gold", 2),
        (223, 25, "green", 1),
    ]
    grass = [
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
        (124, 25, "green", 1),
        (139, 25, "moss", 2),
        (165, 25, "green", 3),
        (190, 25, "moss", 1),
        (218, 25, "green", 2),
    ]

    fill_pits_with_water()
    conflicts = place_decor(trees, grass)
    data, conflicts = make_data(trees, grass, conflicts, 240)
    return data, conflicts


# ---------------------------------------------------------------- 第 2 关

def build_level_02():
    """冰原。冰面冲刺 + 紫史莱姆 + 木箱阵。230 格（约 5 屏）。"""
    reset_grid(230, 48)

    # 1. 起步区
    ground(0, 10)
    put(3, 25, "n")
    coins(5, 8, 24)

    # 2. 冰面滑行区：一脚踩上去刹不住
    ground(11, 25, surface="i", fill="I")
    put(24, 25, "k")          # 检查点
    coins(14, 21, 24)

    # 3. 断崖（要二段跳）+ 高台
    ground(26, 32)
    platform(34, 39, 20, "r")
    coins(35, 38, 19)
    put(36, 17, "1")

    # 4. 史莱姆 + 紫史莱姆 + 检查点
    ground(34, 47)
    put(41, 25, "e")
    put(44, 25, "E")
    put(46, 25, "k")
    coins(42, 43, 24)

    # 5. 木箱阵：翻滚撞碎
    ground(48, 60)
    put(50, 25, "c")
    put(52, 25, "c")
    put(54, 25, "C")
    put(57, 25, "E")
    coins(58, 59, 24)

    # 6. 坑 + 浅岩桥
    bridge(61, 65, SURFACE, "pale_rock")

    # 7. 桥和水之间垫一段地面：水面不直接怼着桥
    ground(66, 69)

    # 8. 水池
    pool(70, 76)

    # 9. 高台 + 梯子 + 紫岩
    platform(77, 88, 18, "p")
    ladder(78, 18, 25, "purple_rock")
    coins(79, 85, 17)
    put(86, 17, "f")        # 水果
    put(82, 15, "5")
    ground(77, 88)
    put(85, 25, "k")

    # 10. 冰面冲刺 + 紫史莱姆群
    ground(89, 101, surface="i", fill="I")
    put(92, 25, "E")
    put(96, 25, "E")
    coins(93, 95, 24)

    # 11. 雪面收尾
    ground(102, 112, surface="s", fill="S")
    put(105, 25, "E")
    put(110, 25, "k")
    coins(106, 109, 24)

    # ==== 下面是新加的一段 ====

    # 12. 浅岩桥 + 问号块
    bridge(113, 120, SURFACE, "pale_rock")
    put(117, 22, "3")

    # 13. 梯子 + 高台 + 感叹号块
    ground(121, 132)
    platform(124, 131, 20, "r")
    ladder(124, 20, 25)
    coins(125, 130, 19)
    put(127, 17, "4")

    # 14. 双史莱姆 + 紫史莱姆
    ground(133, 146)
    put(136, 25, "e")
    put(140, 25, "E")
    put(143, 25, "k")
    coins(134, 135, 24)

    # 15. 冰面 + 木箱
    ground(147, 160, surface="i", fill="I")
    put(150, 25, "c")
    put(154, 25, "E")
    coins(151, 153, 24)

    # 16. 水池
    pool(161, 170)

    # 17. 高台 + 紫岩 + 水果
    ground(171, 182)
    platform(172, 178, 19, "p")
    ladder(172, 19, 25, "purple_rock")
    coins(173, 177, 18)
    put(175, 17, "f")

    # 18. 雪面 + 问号块
    ground(183, 194, surface="s", fill="S")
    put(186, 22, "7")
    put(190, 25, "E")
    put(192, 25, "k")
    coins(184, 185, 24)

    # 19. 墙跳竖井（可选路线）
    ground(195, 208)
    wall(196, 18, 25, "d")
    wall(200, 20, 25, "d")
    platform(197, 199, 18, "r")
    coins(197, 199, 17)
    put(195, 25, "k")

    # 20. 裂纹地面 + 木箱阵
    ground(209, 218, surface="x", fill="d")
    put(211, 25, "c")
    put(214, 25, "C")
    put(216, 25, "E")

    # 21. 终点爬坡
    ground(219, 229)
    for (x, y) in [(222, 25), (223, 24), (224, 23), (225, 22), (226, 21),
                   (227, 20), (228, 19), (229, 18)]:
        put(x, y, "G")
        for yy in range(y + 1, HEIGHT):
            put(x, yy, "d")

    trees = [
        (9, 25, "green", 0),
        (30, 25, "moss", 1),
        (45, 25, "green", 2),
        (55, 25, "gold", 1),
        (80, 25, "green", 0),
        (90, 25, "moss", 2),
        (104, 25, "green", 1),
        (122, 25, "gold", 2),
        (137, 25, "green", 1),
        (157, 25, "moss", 1),
        (176, 25, "green", 2),
        (205, 25, "gold", 1),
    ]
    grass = [
        (1, 25, "green", 1),
        (6, 25, "green", 2),
        (28, 25, "green", 3),
        (47, 25, "moss", 1),
        (58, 25, "green", 1),
        (79, 25, "green", 2),
        (100, 25, "moss", 3),
        (111, 25, "green", 1),
        (125, 25, "moss", 2),
        (148, 25, "green", 1),
        (185, 25, "moss", 3),
        (212, 25, "green", 2),
    ]

    fill_pits_with_water()
    conflicts = place_decor(trees, grass)
    data, conflicts = make_data(trees, grass, conflicts, 280)
    return data, conflicts


# ---------------------------------------------------------------- 第 3 关

def build_level_03():
    """深塔。墙跳竖井 + 高低错落的平台。230 格（约 5 屏）。"""
    reset_grid(230, 48)

    # 1. 起步
    ground(0, 9)
    put(3, 25, "n")
    coins(5, 7, 24)

    # 2. 坑 + 石头高台
    ground(10, 18)
    platform(20, 26, 22, "r")
    coins(21, 25, 21)
    put(23, 19, "1")

    # 3. 跳跃往上：几层错开的平台
    ground(19, 33)
    platform(29, 33, 20, "p")
    platform(21, 25, 16, "r")
    put(22, 13, "3")
    coins(22, 24, 15)

    # 4. 冰面 + 紫史莱姆
    ground(34, 46, surface="i", fill="I")
    put(37, 25, "E")
    put(42, 25, "k")
    coins(38, 41, 24)

    # 5. 木箱 + 绿史莱姆
    ground(47, 58)
    put(49, 25, "c")
    put(52, 25, "C")
    put(55, 25, "e")
    put(57, 25, "k")
    coins(50, 51, 24)

    # 6. 墙跳竖井：两面墙夹一条 3 格宽的缝，蹬墙往上。
    #    竖井是「可选路线」，走主路不用进去，掉下来也不影响通关。
    ground(59, 74)
    wall(60, 18, 25, "d")
    wall(64, 20, 25, "d")
    platform(61, 63, 18, "r")
    coins(61, 63, 17)
    put(62, 16, "f")        # 水果：蹬墙上来才拿得到的奖励
    put(58, 25, "k")

    # 7. 竖井旁边的常规路线：几级台阶
    platform(66, 72, 22, "p")
    ladder(66, 22, 25, "purple_rock")
    coins(67, 71, 21)
    put(69, 19, "6")

    # 8. 水池 + 雪面
    pool(75, 83)
    ground(84, 96, surface="s", fill="S")
    put(88, 25, "E")
    put(93, 25, "k")
    coins(89, 92, 24)

    # 9. 斜坡高台
    ground(97, 105)
    platform(98, 104, 19, "r")
    coins(99, 103, 18)
    put(101, 16, "7")

    # ==== 下面是新加的一段 ====

    # 10. 浅岩桥 + 问号块
    bridge(106, 113, SURFACE, "pale_rock")
    put(110, 22, "4")

    # 11. 三层错开的平台，全靠二段跳和翻滚
    ground(114, 128)
    platform(116, 121, 21, "r")
    platform(123, 128, 17, "p")
    coins(117, 120, 20)
    coins(124, 127, 16)
    put(119, 18, "2")

    # 12. 冰面 + 紫史莱姆 + 检查点
    ground(129, 142, surface="i", fill="I")
    put(133, 25, "E")
    put(137, 25, "k")
    coins(130, 132, 24)

    # 13. 木箱阵
    ground(143, 156)
    put(145, 25, "c")
    put(148, 25, "c")
    put(151, 25, "C")
    put(154, 25, "E")
    coins(146, 147, 24)

    # 14. 梯子 + 高台 + 水果
    ground(157, 168)
    platform(160, 167, 20, "r")
    ladder(160, 20, 25)
    coins(161, 166, 19)
    put(164, 19, "f")

    # 15. 水池
    pool(169, 178)

    # 16. 雪面 + 感叹号块
    ground(179, 190, surface="s", fill="S")
    put(182, 22, "8")
    put(186, 25, "E")
    put(188, 25, "k")
    coins(180, 181, 24)

    # 17. 墙跳竖井（第二个）
    ground(191, 204)
    wall(192, 18, 25, "d")
    wall(196, 20, 25, "d")
    platform(193, 195, 18, "r")
    coins(193, 195, 17)
    put(191, 25, "k")

    # 18. 裂纹地面 + 紫岩高台
    ground(205, 216, surface="x", fill="d")
    platform(206, 212, 20, "p")
    coins(207, 211, 19)
    put(214, 25, "E")

    # 19. 终点爬坡
    ground(217, 229)
    for (x, y) in [(220, 25), (221, 24), (222, 23), (223, 22), (224, 21),
                   (225, 20), (226, 19), (227, 18), (228, 17), (229, 16)]:
        put(x, y, "G")
        for yy in range(y + 1, HEIGHT):
            put(x, yy, "d")

    trees = [
        (8, 25, "green", 1),
        (16, 25, "gold", 2),
        (44, 25, "moss", 1),
        (56, 25, "green", 2),
        (95, 25, "green", 0),
        (115, 25, "gold", 1),
        (139, 25, "moss", 1),
        (158, 25, "green", 1),
        (184, 25, "gold", 1),
        (209, 25, "moss", 1),
    ]
    grass = [
        (2, 25, "green", 2),
        (20, 25, "green", 1),
        (35, 25, "moss", 2),
        (48, 25, "green", 3),
        (70, 25, "green", 1),
        (86, 25, "moss", 3),
        (104, 25, "green", 2),
        (128, 25, "moss", 1),
        (150, 25, "green", 3),
        (176, 25, "moss", 2),
        (207, 25, "green", 1),
    ]

    fill_pits_with_water()
    conflicts = place_decor(trees, grass)
    data, conflicts = make_data(trees, grass, conflicts, 300)
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
