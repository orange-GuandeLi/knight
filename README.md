# Knight

2D 平台跳跃游戏（Godot 4.7 / GDScript）。

## 环境

- Godot 4.7.2 stable（macOS：`/Applications/Godot.app`）
- 渲染后端：GL Compatibility
- 主场景：`res://scenes/main/Main.tscn`
- 设计分辨率：1280 × 720，`canvas_items` 拉伸模式
- 纹理滤波：**Nearest**（像素画必须关掉线性插值）

## 目录结构

```
knight/
├── project.godot          # 项目配置
├── assets/
│   ├── icons/             # 图标（含项目图标 icon.png，骑士封面）
│   ├── PALETTE.md         # 全项目色板登记表（配色家族 ↔ hex ↔ 素材）
│   ├── sprites/knight/    # 主角素材 + knight_frames.tres（见其 README）
│   ├── sprites/coin/      # 硬币 + coin_frames.tres（见其 README）
│   ├── sprites/fruit/     # 4 种水果 + fruit_frames.tres（见其 README）
│   ├── sprites/slime/     # 绿/紫史莱姆 + slime_*_frames.tres（见其 README）
│   ├── sprites/mushroom/  # 4 色蘑菇（大蘑菇 / 大+两小）+ mushroom_*_frames.tres（见其 README）
│   ├── sprites/potion/    # 4 色药瓶 + potion_frames.tres（见其 README）
│   ├── tilesets/platforms/ # 平台砖块切图 + 原图集（见其 README）
│   ├── tilesets/world/     # 世界地形集：地形砖（见其 README）
│   ├── audio/             # 音效 / BGM
│   ├── fonts/             # 字体
│   └── ui/                # UI 素材
├── scenes/
│   ├── main/              # 入口场景
│   ├── actors/            # 角色（玩家、敌人等）
│   ├── levels/            # 关卡
│   ├── objects/           # 关卡物件（平台、收集品等）
│   ├── components/        # 可复用组件
│   └── ui/                # UI 场景（HUD、菜单）
├── scripts/               # 对应 scenes/ 的 GDScript
│   ├── autoload/          # 自动加载脚本
│   ├── actors/
│   ├── levels/
│   ├── ui/
│   └── utils/
├── resources/             # 自定义 Resource
│   └── enums/
├── tools/                 # 资源生成 / 切图 / 校验脚本
│   ├── build_frames.gd
│   ├── make_icon.py       # 生成项目图标（骑士封面）
│   ├── make_level.py      # 生成三关的地形数据
│   ├── check_level.py     # 校验关卡从起点到终点走得通
│   ├── slice_platforms.py
│   ├── slice_slimes.py
│   ├── ingest_world.py
│   └── contact_sheet.py
└── addons/                # 插件
```

## 打开项目

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -e
```

命令行跑起来：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## 素材

| 素材 | 目录 | 规格 | SpriteFrames | 动画 |
|---|---|---|---|---|
| 主角骑士 | `assets/sprites/knight/` | 32×32 | `knight_frames.tres` | idle / walk / roll / hurt / death |
| 硬币 | `assets/sprites/coin/` | 16×16 | `coin_frames.tres` | spin（12 帧 360° 旋转） |
| 水果 | `assets/sprites/fruit/` | 16×16 | `fruit_frames.tres` | green / orange / pink / red（同形状换色） |
| 史莱姆 | `assets/sprites/slime/` | 14×15 | `slime_green_frames.tres` / `slime_purple_frames.tres` | melt / idle / hurt（绿紫同形状换色） |
| 蘑菇 | `assets/sprites/mushroom/` | 16×16 | `mushroom_big_frames.tres` / `mushroom_cluster_frames.tres` | red / gold / purple / green（单张大蘑菇 / 大蘑菇+两个小蘑菇，同形状换色） |
| 药瓶 | `assets/sprites/potion/` | 16×16 | `potion_frames.tres` | green / gold / blue / purple（同形状换色） |
| 项目图标 | `assets/icons/` | 128×128 | — | 骑士封面，由 `tools/make_icon.py` 生成 |

| 音频 | 目录 | 内容 |
|---|---|---|---|
| 背景音乐 | `assets/audio/music/` | `time_for_adventure.mp3`（40s，循环） |
| 音效 | `assets/audio/sounds/` | 6 个 8bit 单声道 WAV：`jump` / `coin` / `power_up` / `hurt` / `explosion` / `tap` |

| 字体 | 目录 | 内容 |
|---|---|---|
| 点阵字体 | `assets/fonts/` | Pixel Operator 8 常规 + 粗体（拉丁/数字全齐，无中文） |

| 瓦片集 | 目录 | 内容 |
|---|---|---|
| 平台砖块 | `assets/tilesets/platforms/` | 原图集 `platforms.png` + 切出的 12 张 16×9 砖块（草地 / 泥土 / 黄金 / 冰块 × block / left / right） |
| 世界地形集 | `assets/tilesets/world/` | 98 张 16×16：地形砖 20（地表 7 / 裂纹 8 / 实心 5）+ 桥 9（3 材质 × 开始 / 中间 / 结束）+ 互动块 8（4 材质 × 问号 / 感叹号）+ 木箱 2 + 木提示牌 2 + 木梯 2 + 水 12（4 色 × 水面 / 水面+水体 / 水体）+ 背景渐变 28（4 族 × 4 档纯色 + 3 张过渡块）+ 植物 15（3 棵树 × 顶/身/底 + 2 色 × 3 株草丛） |

配色家族对照表见 [assets/PALETTE.md](assets/PALETTE.md)。

各目录的细节见：
[knight](assets/sprites/knight/README.md) ·
[coin](assets/sprites/coin/README.md) ·
[fruit](assets/sprites/fruit/README.md) ·
[slime](assets/sprites/slime/README.md) ·
[mushroom](assets/sprites/mushroom/README.md) ·
[potion](assets/sprites/potion/README.md) ·
[platforms](assets/tilesets/platforms/README.md) ·
[world](assets/tilesets/world/README.md) ·
[plants](assets/tilesets/world/plants/README.md) ·
[audio](assets/audio/README.md) ·
[fonts](assets/fonts/README.md)

## HUD

只用图标，不写文字标签：

| 显示 | 内容 |
|---|---|
| 金币 | 金币图标 + `12/30` |
| 体力 | 3 颗爱心，掉血变暗色空心爱心 |
| 命数 | 骑士头像（`idle_00` 裁出来的 13×19）+ `x3` |
| 连击 | `x3` 这样的倍率，连击断了就消失 |
| 倒计时 | `1:47` 这样的 `M:SS`，剩不到 10 秒变红 |
| 分数 | 纯数字，放最右 |

图标来源：骑士和金币直接从角色素材裁内容框，不新增美术；
爱心素材里没有，按 `assets/PALETTE.md` 的红族色板画了一个 8×7 的（实心 + 空心两版），
生成脚本 `tools/make_ui_icons.py`。

整条高 26px（占视口高 7%），内容宽约 194px（占视口宽 30%）。
**注意 UI 字还是英文**——点阵字体没有中文字形。

## 怎么玩

打开项目直接 F5（或命令行 `Godot --path .`），主场景就是 `scenes/main/Main.tscn`。

**开场是标题画面**，按 `Space` / `Enter` 开始；游戏中按 `ESC` 暂停，弹出菜单
（`↑` `↓` 选，`Enter` 确认，`ESC` 继续）。菜单里有 `RESUME` / `RESTART LEVEL` / `QUIT`。

| 操作 | 按键 |
|---|---|
| 左右移动 | `A` / `D` 或 `←` / `→` |
| 跳跃 | `Space` / `Z`　**按住越久跳得越高，空中可再跳一次（二段跳）** |
| 地面翻滚冲刺 | 站着按 `↓` / `S`　**速度锁定不能转向，能撞死怪、撞碎木箱** |
| 空中冲刺 | 空中按 `↓` / `S`　**每次滞空只能冲一次，落地恢复，比翻滚更快更远** |
| 翻滚跳 | 按住 `↓` / `S` 再按跳跃 |
| 蹬墙跳 | 半空贴着墙按跳跃　**蹬完锁向 0.14 秒，落地前还剩一次二段跳** |
| 爬梯子 | `↑` / `W` 上行，`↓` / `S` 下行，按左右脱离，按跳跃蹬梯跳 |
| 重开本关 | `R`（输了、或全部通关后，按 R 从第一关开始） |
| 下一关 | 通关后按 `Enter` / `空格` |
| 暂停菜单 | `ESC`　**`↑` `↓` 选，`Enter` 确认，`ESC` 继续** |
| 全屏切换 | `F11` |

**↑ / W 不再触发跳跃**，只负责爬梯；跳跃只用 `Space` / `Z`。
**↓ / S 有两种用法**：站着按是翻滚冲刺，贴着梯子按是往下爬。

手感参数（`scripts/actors/player.gd`）：

| 参数 | 值 | 效果 |
|---|---|---|
| `JUMP_VELOCITY` | -262 | 起跳初速度 |
| `JUMP_CUT` | -130 | 松开跳跃键后上升速度最多保留到这里 |
| `MAX_JUMPS` | 2 | 2 = 二段跳 |
| `ROLL_SPEED` | 175 | 地面翻滚速度（常态速 110） |
| `ROLL_TIME` / `ROLL_COOLDOWN` | 0.34 / 0.55 秒 | 翻滚时长和冷却 |
| `DASH_SPEED` / `DASH_TIME` | 245 / 0.18 秒 | 空中冲刺速度和时长 |
| `SNOW_SPEED` / `SNOW_JUMP_SCALE` | 70 / 0.76 | 雪地上限速和跳跃高度比例 |
| `WALL_JUMP_X` / `WALL_JUMP_Y` | 145 / -235 | 蹬墙跳的横向、纵向速度 |
| `ICE_ACCEL` / `ICE_FRICTION` | 340 / 70 | 冰上的加速度和摩擦（普通地面 800 / 1000） |

实测跳高：轻点一下 **27px（1.7 格）**，按住跳满 **50px（3.1 格）**，二段跳 **90px（5.6 格）**。
所以爬 6 格高的台子还是得靠梯子，二段跳刚好差一点。

规则：

- 金币 +100，蘑菇 +200，水果 +150，药瓶回 1 点血
- **拾取物是真的有用的**：
  - **蘑菇** → 多一段跳跃（地上吃是留给下一次起跳，空中吃立刻能用）
  - **水果** → 8 秒护盾，碰到敌人不掉血；护盾状态撞史莱姆直接撞碎
  - **药瓶** → 回 1 点血
- **连击**：2 秒内连续吃到东西，倍率 x1 → x2 → x3 …… 最高 x9，断开就清零
- **踩怪连踩**：滞空期间接着踩下一只，倍率 x1 → x8，**落地才清零**（和连击是两回事）
- 顶问号块出蘑菇，顶感叹号块出药瓶；块顶过就变成空块
- 史莱姆可以踩死（绿 +200、紫 +300）；被侧面撞到掉 1 点血
- **紫史莱姆**比绿的快（52 vs 30），而且**玩家进 72px 它就跳过来**，侧面撞更危险
- **空中冲刺**能跨过普通跳跨不过的窄缝
- **翻滚冲刺**能直接撞死史莱姆，也能把木箱撞碎（碎箱一半概率掉金币）
- **水是致命的**：掉进去直接淹死，没有游泳。关卡里的悬崖（没地面的列）
  会自动灌上水，所以一眼能看出「那边过不去」
- **水面比路面低一格**（14px）：水面线用的是 `water_ice_surface` 砖，
  浪花画在砖的下缘，所以水看起来是陷在路面下面的一滩。
  这块砖**不带任何碰撞**，触碰面落在下方的水体上（比路面低 16px）——
  站在路边不会莫名其妙淹死，掉进水里才死
- **冰面**（`ice` / `ice_stone` 砖）又滑又刹不住，踩上去容易冲过头
- **雪地**（`snow_ice` / `snow_stone` 砖）不打滑，是**走得慢、跳得矮**（跳高只有 76%）
- **检查点**：路边的木牌，碰到就亮成金色，之后死了从这儿复活
- 血掉光就死，掉一条命、从最近的检查点复活（吃过的金币和顶过的块都保留）；命掉光游戏结束
- **关卡左右是墙**：走出关卡边缘会掉进虚空，所以左右都卡住身体不让出界
- **每关限时**（240 / 280 / 300 秒），HUD 顶上倒计时，归零这局就结束
- **收集目标**：每关要收够金币（关卡里六成）才能通关，HUD 上显示 `12/30`；
  走到出口金币不够会提示还差多少，得回头去捡
- 走到最右边通关，按 `Enter` 进下一关，一共 3 关。**每关重新给 3 条命**，总分累计
- 音效：跳跃 / 金币 / 拾取 / 受伤 / 踩怪 / 顶块 各有对应音效，背景音乐循环播放

## 分辨率

基准视口 **640×360**（40×22.5 格），基准窗口 **1280×720**，整数 **2 倍**放大。

但视口不是写死的——`Main._fit_to_screen()` 每次窗口尺寸变化都会重算：

1. 按窗口宽度和高度分别算能放下的整数倍，取小的那个（保证横竖都是整数倍）
2. 把逻辑视口设成 `ceil(窗口 / 倍数)`

这样 **窗口 ÷ 视口 永远正好等于整数倍**，一个像素都不多不少 → **全屏也没有黑边**，
而且像素始终是整数块、不会糊。代价是宽屏/方屏上能看到的视野会多一些（这是好事）。

| 窗口 | 逻辑视口 | 倍数 | 余量 |
|---|---|---|---|
| 1280×720 | 640×360 | 2 | 0 |
| 1512×982 | 756×491 | 2 | 0 |
| 1920×1080 | 640×360 | 3 | 0 |
| 全屏 2205×1386 | 735×462 | 3 | 0 |

HUD 的深色条用锚点拉满整个视口宽，中央提示按屏幕中心锚定，所以视口尺寸变了排版也不会散。

- `F11` 全屏 / 退出全屏
- 想整体更远或更近：改 `project.godot` 里的 `viewport_width/height` 和 `window_width_override/height_override`，
  再按同比例调 `scenes/ui/HUD.tscn` 的坐标和 `assets/ui/pixel_theme.tres` 的字号

## 代码结构

```
scenes/
  main/Main.tscn        入口：HUD（关卡由 main.gd 按关卡序号动态挂上去）
  levels/Level01.tscn   关卡场景（两个 TileMapLayer + 实体容器 + 玩家）
  levels/Level02.tscn   只有数据文件不一样，其余同 Level01
  levels/Level03.tscn
  actors/Player.tscn    骑士
  actors/Slime.tscn     史莱姆（绿 / 紫由 variant 决定）
  objects/Coin.tscn     金币
  objects/Pickup.tscn   蘑菇 / 药瓶 / 水果
  objects/Checkpoint.tscn 检查点（木牌）
  objects/Debris.tscn    碎块粒子（砸箱子、踩史莱姆的渣）
  objects/ScorePopup.tscn 飘起来的加分提示
  ui/HUD.tscn           状态条：金币图标+数量 / 爱心 / 骑士头像+命数 / 连击 / 倒计时 / 分数
  ui/StartScreen.tscn   开场标题画面（标题 + 骑士 + 操作说明）
  ui/PauseMenu.tscn     暂停菜单（继续 / 重开 / 退出）

scripts/
  main.gd               关卡切换、重开、全屏
  actors/player.gd      移动、跳跃、翻滚、墙跳、游泳、爬梯、冰面、受伤、死亡
  actors/slime.gd       巡逻、踩死、撞到玩家（绿 / 紫两种）
  objects/coin.gd       金币
  objects/pickup.gd     拾取物
  objects/checkpoint.gd 检查点
  objects/debris.gd     碎块粒子
  objects/score_popup.gd 加分飘字
  levels/level.gd       读 json 铺砖、生成实体、撞块、砸木箱、倒计时、通关判定
  ui/hud.gd             状态栏
  ui/start_screen.gd    标题画面（按空格开始）
  ui/pause_menu.gd      暂停菜单（上下键选单）
  autoload/game.gd      全局状态（分数 / 命 / 血 / 金币 / 连击 / 踩怪连踩 / 倒计时 / 关卡序号）+ 顿帧
  autoload/audio.gd     音效池 + 背景音乐
  utils/tile_index.gd   砖名 <-> 图集坐标
  utils/level_bounds.gd 关卡像素边界

assets/tilesets/world/
  world_tileset.tres    TileSet（5 个图集源：地形 / 道具 / 水 / 背景 / 植物）
  plants/               树（顶/身/底，body 可重复）+ 草丛
  atlases/              图集（由 tools/build_atlases.py 生成）

assets/ui/icons/        HUD 图标（骑士、金币从角色素材裁出；爱心按红色色板画的 8x7）
assets/audio/           音乐 + 音效
assets/fonts/           点阵字体
assets/ui/pixel_theme.tres  HUD 主题（默认字体 = Pixel Operator 8）
```

**游戏内文字是英文**：点阵字体 Pixel Operator 8 只有拉丁字形，没有中文。
文档保持中文。

物理层：1 = 地形，2 = 玩家，4 = 敌人，8 = 水 / 木梯感应，16 = 冰面感应，32 = 雪地感应。

> 冰砖（`ice` / `ice_stone`）挂在地形层 + 冰面感应层，雪砖（`snow_ice` / `snow_stone`）
> 挂在地形层 + 雪地感应层：冰是打滑，雪是难走，两种手感分开。
> 感应层是在 `tools/build_tileset.gd` 里加的，改了要重跑生成脚本。

> **桥的碰撞不是整块砖**。绳桥每块砖画的是两段绳，两头是抬高的桥墩，
> 绳面在砖的第 2 行（比地面低 2px）。所以碰撞是一条贴着绳面的窄带：
> 桥墩那端跟地面齐平并带一点斜坡，中间是绳面。
> 形状在 `tools/build_tileset.gd` 的 `_bridge_shape()` 里定义。

## 改关卡

一共 3 关，关卡是 `48` 行高、230~240 格宽（16px 一格，约 3840×768 像素 = **5 屏宽**），
数据在 `scenes/levels/level0N.json`，由 `tools/make_level.py` 生成。

每关按「起承转合」分 10 段（`sections` 字段）：

| 段 | 作用 |
|---|---|
| intro | 开场铺垫，安全，教基础操作 |
| challenge | 单个新机制 |
| reward | 检查点 / 水果，喘息 |
| climax | 多个机制叠加，最难的一段 |
| outro | 收尾冲刺 |

音乐强度也跟着段落切（`climax` 和 `outro` 变调变响）。
改关卡改那个脚本再重跑：

```bash
python3 tools/make_level.py     # 重新生成三关的地形
python3 tools/check_level.py    # 校验三关从起点到终点都走得通
python3 tools/build_atlases.py  # 素材有变动时重打图集
Godot --headless --path . --script res://tools/build_tileset.gd   # 重建成 TileSet
python3 tools/preview_level.py /tmp/lv.png   # 用图集渲染关卡预览图（不用开引擎）
Godot --path . res://tools/Screenshot.tscn --resolution 1280x720   # 截真实游戏画面
```

`tools/make_level.py` 里每关一个 `build_level_0N()` 函数，
开头是这一关的地形，结尾是树和草的摆放。

**跨越规则**（16px 一格）：

| 缺口宽度 | 怎么过 |
|---|---|
| ≤ 4 格 | 二段跳能过（实测能跳 5.6 格） |
| 5~8 格 | 用桥，走过去 |
| ≥ 9 格 | 坐船 |

关卡里还能放的东西：

| 字符 | 东西 |
|---|---|
| `o` | 金币 |
| `e` / `E` | 绿史莱姆 / 紫史莱姆 |
| `k` | 检查点（木牌） |
| `i` / `I` / `s` / `S` | 冰面 / 冰石 / 雪面 / 雪石 |
| `f` | 水果（护盾），直接摆在关卡里 |
| `c` / `C` | 木箱（土 / 紫岩），翻滚能撞碎 |
| `W` / `v` | 水面线 / 水体 |
| — | 没地面的列自动灌水，不用手写 |

`tools/check_level.py` 用可达性搜索（BFS）从出生点算出玩家能踩到哪些位置，
会考虑跳跃距离、梯子、桥和能游过去的水池，
用来确认一关真的能从起点走到终点——比肉眼看预览图靠谱。

它还会查三条摆关卡的规矩：

- **植物不能长在桥上**（桥是悬空的，桥上不该有树和草）
- **水面不能直接怼着桥**（中间得垫一段地面，不然桥看着像浮在水面上）
- **移动平台不能压在地形上**（会连整个行程一起检查，
  平台只允许浮在水面上方或者纯空中）

`tools/make_level.py` 里放了树和草之后也会自己查一遍「脚下是不是桥」，
摆错了当场就会打印冲突。

生成器里的 `put()` 还会**报警覆盖**：往已经有东西的格子里写东西会打印出来。
（之前问号块就被后来的金币弧线盖掉了，靠这个才一眼看出来。）

`tools/Screenshot.tscn` 会截一帧存到 `/tmp/game_shot.png`，加参数还能截别的界面：
`-- clear`（通关提示）、`-- start`（标题画面）、`-- pause`（暂停菜单）。
**必须带窗口跑**，`--headless` 没有渲染输出。

## 自测

```bash
Godot --headless --path . res://tools/SmokeTest.tscn
```

共 51 项检查：开场显示标题画面 / 开场没有音效 / 标题画面按空格开始 / 标题画面按空格开始 / ESC 弹出暂停菜单 / ESC 关掉暂停菜单 /
站立 / 跑动 / 撞问号块 / 短按跳矮 / 长按跳高 / 二段跳 / 上键不起跳 /
踩史莱姆 / 入水 / 爬梯 / 摔死扣命 / 原地复活 / HUD 爱心 / HUD 命数 / HUD 金币 / 通关 /
通关文字 / 地面翻滚冲刺 / 翻滚撞碎木箱 / 识别到冰面 / 冰面打滑不刹车 / 连击累计倍率 /
桥面贴着绳面 / 桥头是斜坡不是直墙 / 走不出关卡左边界 / 碰到检查点就激活 /
从检查点复活 / 关卡有倒计时 / HUD 显示倒计时 / 通关后进下一关 / 第 2 关已载入 /
换关后清掉通关提示 / 雪地走得慢 / 雪地能刹住 / 雪地跳得矮 / 踩怪连踩能累计 /
紫史莱姆会跳扑过来 / 顿帧生效 / 顿帧会自己恢复 / 起跳有拉伸挤压 /
金币没收够不能通关 / 提示还差多少金币 / 金币收够就通关 / 贴墙下滑 / 墙跳蹬出去 /
掉进水里会淹死。

> 用 `--quit-after` 这类硬退出时，退出日志里会多出 2 条 MP3 播放对象的泄漏警告。
> 那是 Godot 硬退出时音频线程来不及回收造成的，不影响运行。
> 正常关窗口走 `Main` 的 `NOTIFICATION_WM_CLOSE_REQUEST`，会先停音乐再退，没有这条警告。

## 当前状态

素材八套已整理，TileSet 已建好，三关可玩的平台跳跃：
跑跳、可变跳跃高度、二段跳、地面翻滚冲刺、蹬墙跳、游泳、爬梯、冰面滑行、
金币与拾取物、互动块、砸木箱、绿/紫史莱姆、检查点、连击倍率、限时挑战、血量命数、通关换关。

配色统一按 `assets/PALETTE.md` 的色板家族命名，同一块色板在不同物件里叫同一个名字。
