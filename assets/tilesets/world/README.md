# World Tileset

从 `world_tileset.png` 切出的地形砖。

## 三类砖

| 类别 | 数量 | 结构 | 例子 |
|---|---|---|---|
| **地表砖** | 7 | 上层材质 ≠ 下层材质，上面盖一层别的材质 | `grass_dirt` = 草皮 + 泥土 |
| **裂纹石块** | 8 | 上下同材质，中间有深色斜纹裂纹 | `cracked_dirt` = 整块泥土 + 裂纹 |
| **实心石块** | 5 | 上下同材质，没有裂纹 | `dirt` = 整块泥土 |

另外有 **9 块桥**（`bridges/`）、**8 块互动块**（`blocks/`）、**2 个木箱**（`crates/`）、**2 个木提示牌**（`signs/`）、**2 个木梯**（`ladders/`）、**12 张水**（`water/`）、**28 张背景渐变块**（`background/`）。

## 背景渐变块

纯装饰，没有玩法含义。4 族，每族 **4 档纯色 + 3 张过渡块**，放 `background/`：

| 族 | 第 1 档 | 第 2 档 | 第 3 档 | 第 4 档 |
|---|---|---|---|---|
| `sky` | `#FFFFFF` | `#1498DC` | `#1950C0` | `#032659` |
| `warm` | `#FAD3B3` | `#F49990` | `#FFD233` | `#F99C0B` |
| `purple` | `#F49990` | `#E65F69` | `#B73D94` | `#6F2C77` |
| `stone` | `#D7DEE8` | `#AEB4CE` | `#838BA9` | `#636B85` |

命名 `bg_<族>_<档>.png`，纯色档是 `1`~`4`，过渡块是 `1_2` / `2_3` / `3_4`：

```
bg_sky_1.png  bg_sky_1_2.png  bg_sky_2.png  bg_sky_2_3.png  bg_sky_3.png  bg_sky_3_4.png  bg_sky_4.png
bg_warm_1.png ...
```

过渡块是**竖向抖动渐变**：上半是上一档的颜色，下半是下一档，中间用网点抖动过渡。

```
BBBBBBBBBBBBBBBB     ← 上档颜色
BBBBBBABBBBBABBB
BBBBBBAABBBAABBB
BBBBBBAAAAAAABBB
BBBBBABBAAAAAABB
BBBBAABBAABBBAAA
AAAAAAAAABBBBBAA
AABBBBAABBBBBBBA
ABBBBBBABBBBBBBA
ABBBBBBABBBBBBBA
ABBBBBBAABBBBBAA
ABBBBBBAAABBBABA
AABBBBAABAAAAAAA
AAAAAAAAAAAAAAAA   ← 下档颜色
```

**12 张过渡块的网点图案完全一致**，只是上下颜色不同，所以竖着摞起来就是一条没有接缝的渐变。

> `bg_warm_2.png` 和 `bg_purple_1.png` 是同一张图（都是 `#F49990`），图集里本来就是两格。留着是为了两族的档位编号不断档。

## 水

4 种颜色 × 3 种形态，都放在 `water/`：

| 颜色 | 水面 + 水体 | 水面 | 水体 |
|---|---|---|---|
| 冰蓝 | `water/water_ice_surface_body.png` | `water/water_ice_surface.png` | `water/water_ice_body.png` |
| 深蓝 | `water/water_deep_blue_surface_body.png` | `water/water_deep_blue_surface.png` | `water/water_deep_blue_body.png` |
| 紫 | `water/water_purple_surface_body.png` | `water/water_purple_surface.png` | `water/water_purple_body.png` |
| 金 | `water/water_gold_surface_body.png` | `water/water_gold_surface.png` | `water/water_gold_body.png` |

三种形态的结构：

| 形态 | 内容 | 透明像素 |
|---|---|---|
| `surface_body` | 顶部 4 行波浪 + 下面 12 行实心水体 | 16（波浪中间两处缺口） |
| `surface` | 只有那条波浪，贴在砖**底部** rows 11-15，上面全透明 | 192 |
| `body` | 整块纯色，无描边无高光 | 0 |

波浪的形状（4 组颜色完全一样）：

```
   LLL     LLL
  LHHdL   LHHdL
LLH###dLLLH###dL
HH#####HHH#####H
```

`L` = 描边，`H` = 高光，`d` = 暗部，`#` = 水体主色。

**注意**：水面和水面+水体的波浪都有透明缺口，做 TileSet 时别把波浪下面填实，
否则缺口就看不出来了。水体本身是纯色砖，适合大面积平铺。

## 木梯

| 文件 | 配色 | 对应地形材质 |
|---|---|---|
| `ladders/ladder_dirt.png` | `#231C19` `#D89E58` `#B66B3A` `#67332D` | 泥土 |
| `ladders/ladder_purple_rock.png` | `#231C19` `#E7B09C` `#B56B5F` `#864646` | 深紫岩 |

两条竖杆（左右各 3px 宽）+ 横向档，竖杆从砖顶贯穿到砖底。竖直摆放，可攀爬。

## 木提示牌

| 文件 | 配色 | 对应地形材质 |
|---|---|---|
| `signs/sign_dirt.png` | `#120C0A` `#F3CF95` `#B66B3A` `#67332D` | 泥土 |
| `signs/sign_purple_rock.png` | `#231C19` `#E7B09C` `#B56B5F` `#864646` | 深紫岩 |

斜放的牌面 + 下方立柱（立柱一直落到砖底）。两张结构完全一样，只有配色不同。

## 木箱

| 文件 | 配色 | 对应地形材质 |
|---|---|---|
| `crates/crate_dirt.png` | `#231C19` `#D89E58` `#B66B3A` `#67332D` | 泥土 |
| `crates/crate_purple_rock.png` | `#231C19` `#E7B09C` `#B56B5F` `#864646` | 深紫岩 |

两张结构完全一样（外框 + 两侧竖框 + 上下横档 + 中心板），只有配色不同。
配色跟地形材质一一对应，可以和同主题的地形砖搭配用。

## 互动块

头顶撞击出奖励的方块，4 种材质 × 问号/感叹号：

| 材质 | 问号 | 感叹号 |
|---|---|---|
| 泥土 | `blocks/block_dirt_question.png` | `blocks/block_dirt_exclaim.png` |
| 浅岩 | `blocks/block_pale_rock_question.png` | `blocks/block_pale_rock_exclaim.png` |
| 深紫岩 | `blocks/block_purple_rock_question.png` | `blocks/block_purple_rock_exclaim.png` |
| 灰石 | `blocks/block_stone_question.png` | `blocks/block_stone_exclaim.png` |

字形用「描边色 + 填充色」两层画，所以要连描边一起看：

```
问号     顶部 5px 宽弧 -> 钩子收向中间 -> 断开 -> 底部点
感叹号   2px 竖条    -> 断开 -> 底部点
```

同一套字形有两种配色：
`dirt` / `pale_rock` 是**深字浅面**，`purple_rock` / `stone` 是**浅字深面**。

## 桥

3 种材质 × 3 个段位：

| 材质 | 开始 | 中间 | 结束 |
|---|---|---|---|
| 泥土 | `bridges/bridge_dirt_start.png` | `bridges/bridge_dirt_middle.png` | `bridges/bridge_dirt_end.png` |
| 浅岩 | `bridges/bridge_pale_rock_start.png` | `bridges/bridge_pale_rock_middle.png` | `bridges/bridge_pale_rock_end.png` |
| 深紫岩 | `bridges/bridge_purple_rock_start.png` | `bridges/bridge_purple_rock_middle.png` | `bridges/bridge_purple_rock_end.png` |

每张 16×16 里有**两块 8 宽的桥板**，形状完全一样（8×7 的圆角块），区别只在**垂直位置**：

| 段位 | 左板起始行 | 右板起始行 | 效果 |
|---|---|---|---|
| 开始 `start` | 0 | 1 | 左高右低，降 1px |
| 中间 `middle` | 2 | 2 | 平 |
| 结束 `end` | 1 | 0 | 左低右高，升 1px |

所以整条桥是「开始端接在高处 → 中间平段 → 结束端回到高处」。
桥板只占每张图的上 8 行，下 8 行透明（每张 88 个不透明像素 / 256）。

## 文件

### 地表砖

| 文件 | 地表层 | 主体层 |
|---|---|---|
| `tiles/grass_dirt.png` | 草 | 泥土 |
| `tiles/sand_pale_rock.png` | 暖沙 | 浅岩 |
| `tiles/sand_pale_rock_2.png` | 暖沙 | 浅岩 |
| `tiles/ore_gold.png` | 金矿 | 深紫岩 |
| `tiles/ice_stone.png` | 冰 | 灰石 |
| `tiles/snow_ice.png` | 雪 | 冰 |
| `tiles/snow_stone.png` | 雪 | 灰石 |

### 裂纹石块（4 种材质各 2 个变体）

| 文件 | 材质 |
|---|---|
| `tiles/cracked_dirt.png` | 泥土 |
| `tiles/cracked_dirt_2.png` | 泥土 |
| `tiles/cracked_pale_rock.png` | 浅岩 |
| `tiles/cracked_pale_rock_2.png` | 浅岩 |
| `tiles/cracked_purple_rock.png` | 深紫岩 |
| `tiles/cracked_purple_rock_2.png` | 深紫岩 |
| `tiles/cracked_stone.png` | 灰石 |
| `tiles/cracked_stone_2.png` | 灰石 |

### 实心石块

| 文件 | 材质 |
|---|---|
| `tiles/dirt.png` | 泥土 |
| `tiles/pale_rock.png` | 浅岩 |
| `tiles/purple_rock.png` | 深紫岩 |
| `tiles/stone.png` | 灰石 |
| `tiles/ice.png` | 冰 |

全部 16×16 RGBA，圆角矩形轮廓（上下左右各缩进 1~2px）。
`cracked_*` 前 4 个是不对称轮廓（转角只缩进 1px），带 `_2` 的和实心块是对称轮廓（转角缩进 2px）。

## 每行的构成

```
y0        描边色
y1        高光色
y2-y3     高光色 + 主色
y4        高光色 + 主色 + 阴影色
y5-y6     主色 + 阴影色
y7        阴影色
y8        描边色
y9        主色 + 暗色
y10       高光色 + 主色
y11-y12   高光色 + 主色 + 暗色
y13       主色 + 暗色
y14       暗色
y15       描边色
```

y1~y7 是上层，y9~y14 是下层。

## 调色板

| 用途 | 颜色 |
|---|---|
| 描边 | `#231C19`（泥系） `#352B26`（岩系） `#351424`（矿系） `#242B33`（冰/石系） |
| 草 | `#95D836` `#4DBD27` `#0A7030` |
| 泥土 | `#D89E58` `#B66B3A` `#67332D` |
| 暖沙 | `#F3CF95` `#D89E58` `#B66B3A` |
| 浅岩 | `#E2CFA4` `#C3AA83` `#997D57` |
| 金矿 | `#FFFC32` `#FFD233` `#F99C0B` |
| 深紫岩 | `#E7B09C` `#B56B5F` `#864646` |
| 冰 | `#A0FCD8` `#10D3C3` `#1498DC` |
| 雪 | `#FFFFFF` |
| 灰石 | `#AEB4CE` `#636B85` `#3D4857` |

## 重建

```bash
python3 tools/ingest_world.py                   # 处理根目录的 tile_*.png
python3 tools/ingest_world.py --source <目录>     # 处理指定目录
```

归档脚本按像素配色自动判定材质并命名：

| 尺寸 | 判定 | 命名 |
|---|---|---|
| 16×16 | 顶部 4 行 = 上层，底部 7 行 = 下层 | 上层≠下层 → `<上层>_<下层>.png`<br>上层=下层 → `<材质>.png` |
| 16×8 | 整块 = 单层 | `<材质>.png` |

同材质多个变体自动加 `_2` `_3`；完全重复的跳过。
裂纹石块这种「同材质但有裂纹」的砖，靠配色分不出来，用 `tools/ingest_world.py` 里的
`OVERRIDE` 表按源编号指定名字。
桥走 `BRIDGES` 表，存到 `bridges/`，命名 `<材质>_<段位>.png`。
互动块走 `BLOCKS` 表，存到 `blocks/`，命名 `block_<材质>_<问号/感叹号>.png`。
木箱走 `CRATES` 表，存到 `crates/`，命名 `crate_<材质色>.png`。
提示牌走 `SIGNS` 表，存到 `signs/`，命名 `sign_<材质色>.png`。
木梯走 `LADDERS` 表，存到 `ladders/`，命名 `ladder_<材质色>.png`。
水走 `WATER` 表，存到 `water/`，命名 `water_<颜色>_<形态>.png`。
背景渐变走 `BACKGROUND` 表，存到 `background/`，命名 `bg_<族>_<档>.png`。

归档时会搬走源图、删掉源图的 `.import`，并清理根目录里所有孤儿 `.import`。
