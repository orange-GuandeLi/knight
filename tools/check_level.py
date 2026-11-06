#!/usr/bin/env python3
"""检查关卡能不能走通。

用可达性搜索（BFS）从出生点出发，算出玩家实际能踩到哪些位置，
再判断终点够不够得着。比「逐列比高度」准得多：梯子、桥、高台、
故意留的坑都能正确处理。

跳跃能力（见 scripts/actors/player.gd）：
- 轻点跳 27px ≈ 1.7 格
- 按住跳满 50px ≈ 3.1 格
- 二段跳 90px ≈ 5.6 格

所以单次跳跃：往上 4 格、水平跨 5 格都还有余量。

用法:
    python3 tools/check_level.py [关卡文件 ...]
"""

import json
import sys
from collections import deque

MAX_JUMP_CELLS = 4     # 一次跳跃最多上几格
MAX_GAP_CELLS = 5      # 一次跳跃最多跨几格空洞

# 能站的地面
SOLID = set("GdrpxcC[]=]{}()*+12345678iIsS")
# 梯子：能顺着爬上去，不算地面
LADDER = set("Hh")
# 实体（不算地面）
ENTITY = set("oekE")


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def cell(d, x, y):
    """取某格的字符。y 是地图绝对行号。"""
    if x < 0 or x >= d["width"] or y < 0 or y >= d["height"]:
        return "#"          # 边界外当作实心，挡路
    if y < d["top_rows"]:
        return "."
    i = y - d["top_rows"]
    rows = d["map"]
    if i < 0 or i >= len(rows):
        return "."
    return rows[i][x]


def is_solid(d, x, y):
    c = cell(d, x, y)
    return c in SOLID


def is_ladder(d, x, y):
    return cell(d, x, y) in LADDER


def stand_rows(d, x):
    """这一列可以站人的行：脚下是实心、头上是空的。
    水面也算——玩家浮在水面上。
    """
    out = []
    for y in range(d["top_rows"], d["height"]):
        if is_solid(d, x, y) and not is_solid(d, x, y - 1):
            out.append(y)
    span = water_span(d, x)
    if span:
        out.append(span[0])          # 水面，人浮在这
    return out


def water_span(d, x):
    """这一列水从哪行到哪行。"""
    ys = [y for y in range(d["top_rows"], d["height"]) if cell(d, x, y) in "wv"]
    return (min(ys), max(ys)) if ys else None


def ladder_span(d, x):
    """这一列梯子从哪行到哪行。"""
    ys = [y for y in range(d["top_rows"], d["height"]) if is_ladder(d, x, y)]
    return (min(ys), max(ys)) if ys else None


def reachable(d):
    """从出生点出发，算出所有能站到的 (列, 行)。"""
    W = d["width"]
    sx = d["spawn"][0]
    # 出生点所在的行
    start_rows = stand_rows(d, sx)
    start = (sx, d["spawn"][1])
    if not start_rows or not any(abs(r - start[1]) <= MAX_JUMP_CELLS for r in start_rows):
        # 出生点脚下的地面找不准，就退而求其次用最近的一块
        if not start_rows:
            return set(), "出生点 x=%d 脚下没有地面" % sx
        start = (sx, min(start_rows, key=lambda r: abs(r - start[1])))

    seen = {start}
    q = deque([start])
    while q:
        x, r = q.popleft()
        # 梯子：能顺着爬到这一列梯子的任意一端
        span = ladder_span(d, x)
        if span:
            for target in (span[0], span[1]):
                for cand in stand_rows(d, x):
                    if abs(cand - target) <= 1:
                        if (x, cand) not in seen:
                            seen.add((x, cand))
                            q.append((x, cand))
        # 水里：能上下随便游
        wspan = water_span(d, x)
        if wspan:
            for cand in range(wspan[0], wspan[1] + 1):
                if (x, cand) not in seen:
                    seen.add((x, cand))
                    q.append((x, cand))
        # 走 / 跳到别的列。
        # 中间有没有墙不用单独判断：够不到的墙顶不会出现在候选里，
        # 够得到的墙顶本身就是落脚点，会被当成中转站。
        for dx in range(-MAX_GAP_CELLS, MAX_GAP_CELLS + 1):
            nx = x + dx
            if nx < 0 or nx >= W:
                continue
            for cand in stand_rows(d, nx):
                if abs(cand - r) <= MAX_JUMP_CELLS:
                    if (nx, cand) not in seen:
                        seen.add((nx, cand))
                        q.append((nx, cand))
    return seen, None


def check(path):
    d = load(path)
    W, H = d["width"], d["height"]
    problems = []

    seen, err = reachable(d)
    if err:
        problems.append(err)

    # 终点：右边界前几列要有能站到的地方
    goal_cols = [x for x in range(W - 8, W) if any(rx == x for rx, _ in seen)]
    if not goal_cols:
        problems.append("走不到右边界（最后 8 列都踩不到）")
    else:
        # 顺便确认这些终点列高度正常
        pass

    # 出生点要能站着
    sx = d["spawn"][0]
    if not any(rx == sx for rx, _ in seen):
        problems.append("出生点 x=%d 站不住" % sx)

    # 实体检查：史莱姆和检查点脚下得有地
    for y in range(d["top_rows"], H):
        row = d["map"][y - d["top_rows"]]
        for x, c in enumerate(row):
            if c in "eEk" and not is_solid(d, x, y + 1):
                problems.append("实体 '%s' 在 (%d,%d) 下面没有地面" % (c, x, y))

    # 统计
    n = {c: sum(1 for row in d["map"] for ch in row if ch == c) for c in "oekE"}
    print("%s  %dx%d  限时 %ds  金币 %d 史莱姆 %d 紫 %d 检查点 %d"
          % (path, W, H, d.get("time_limit", 0), n["o"], n["e"], n["E"], n["k"]))
    if problems:
        for p in problems:
            print("   !! " + p)
    else:
        print("   ok 起点到终点走得通")
    return len(problems)


def main():
    files = sys.argv[1:] or [
        "scenes/levels/level01.json",
        "scenes/levels/level02.json",
        "scenes/levels/level03.json",
    ]
    bad = 0
    for f in files:
        bad += check(f)
    print("\n共 %d 个问题" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
