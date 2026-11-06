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

| 操作 | 按键 |
|---|---|
| 左右移动 | `A` / `D` 或 `←` / `→` |
| 跳跃 | `Space` / `Z`　**按住越久跳得越高，空中可再跳一次（二段跳）** |
| 地面翻滚冲刺 | 站着按 `↓` / `S`　**速度锁定不能转向，能撞死怪、撞碎木箱** |
| 翻滚跳 | 按住 `↓` / `S` 再按跳跃 |
| 蹬墙跳 | 半空贴着墙按跳跃　**蹬完锁向 0.14 秒，落地前还剩一次二段跳** |
| 爬梯子 | `↑` / `W` 上行，`↓` / `S` 下行，按左右脱离，按跳跃蹬梯跳 |
| 游泳 | 掉进水里按住跳跃上浮 |
| 重开本关 | `R`（输了、或全部通关后，按 R 从第一关开始） |
| 下一关 | 通关后按 `Enter` / `空格` |
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
| `WALL_JUMP_X` / `WALL_JUMP_Y` | 145 / -235 | 蹬墙跳的横向、纵向速度 |
| `ICE_ACCEL` / `ICE_FRICTION` | 340 / 70 | 冰上的加速度和摩擦（普通地面 800 / 1000） |

实测跳高：轻点一下 **27px（1.7 格）**，按住跳满 **50px（3.1 格）**，二段跳 **90px（5.6 格）**。
所以爬 6 格高的台子还是得靠梯子，二段跳刚好差一点。

规则：

- 金币 +100，蘑菇 +200，水果 +150，药瓶回 1 点血
- **连击**：2 秒内连续吃到东西，倍率 x1 → x2 → x3 …… 最高 x9，断开就清零
- 顶问号块出蘑菇，顶感叹号块出药瓶；块顶过就变成空块
- 史莱姆可以踩死（绿 +200、紫 +300）；被侧面撞到掉 1 点血
- **紫史莱姆**比绿的快（52 vs 30），侧面撞更危险
- **翻滚冲刺**能直接撞死史莱姆，也能把木箱撞碎（碎箱一半概率掉金币）
- **冰面**（`ice` / `snow` 砖）又滑又刹不住，踩上去容易冲过头
- **检查点**：路边的木牌，碰到就亮成金色，之后死了从这儿复活
- 血掉光就死，掉一条命、从最近的检查点复活（吃过的金币和顶过的块都保留）；命掉光游戏结束
- **每关限时**（120 / 150 / 180 秒），HUD 顶上倒计时，归零这局就结束
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
  ui/HUD.tscn           状态条：金币图标+数量 / 爱心 / 骑士头像+命数 / 连击 / 倒计时 / 分数

scripts/
  main.gd               关卡切换、重开、全屏
  actors/player.gd      移动、跳跃、翻滚、墙跳、游泳、爬梯、冰面、受伤、死亡
  actors/slime.gd       巡逻、踩死、撞到玩家（绿 / 紫两种）
  objects/coin.gd       金币
  objects/pickup.gd     拾取物
  objects/checkpoint.gd 检查点
  levels/level.gd       读 json 铺砖、生成实体、撞块、砸木箱、倒计时、通关判定
  ui/hud.gd             状态栏
  autoload/game.gd      全局状态（分数 / 命 / 血 / 金币 / 连击 / 倒计时 / 关卡序号）
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

物理层：1 = 地形，2 = 玩家，4 = 敌人，8 = 水 / 木梯感应，16 = 冰面感应。

> 冰砖（`ice` / `ice_stone` / `snow_ice` / `snow_stone`）同时挂在地形层和冰面感应层上，
> 所以既是实心地面，又能让角色判断出「脚下是冰」。
> 感应层是在 `tools/build_tileset.gd` 里加的，改了要重跑生成脚本。

## 改关卡

一共 3 关，关卡是 `120×48` 格（16px 一格 = 1920×768 像素），
数据在 `scenes/levels/level0N.json`，由 `tools/make_level.py` 生成。
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
开头是这一关的地形，结尾是树和草的摆放。关卡里还能放的东西：

| 字符 | 东西 |
|---|---|
| `o` | 金币 |
| `e` / `E` | 绿史莱姆 / 紫史莱姆 |
| `k` | 检查点（木牌） |
| `i` / `I` / `s` / `S` | 冰面 / 冰石 / 雪面 / 雪石 |
| `c` / `C` | 木箱（土 / 紫岩），翻滚能撞碎 |

`tools/check_level.py` 用可达性搜索（BFS）从出生点算出玩家能踩到哪些位置，
会考虑跳跃距离、梯子、桥和能游过去的水池，
用来确认一关真的能从起点走到终点——比肉眼看预览图靠谱。

`tools/Screenshot.tscn` 会截一帧存到 `/tmp/game_shot.png`，加 `-- clear` 还能截通关提示那张。
**必须带窗口跑**，`--headless` 没有渲染输出。

## 自测

```bash
Godot --headless --path . res://tools/SmokeTest.tscn
```

共 31 项检查：站立 / 跑动 / 撞问号块 / 短按跳矮 / 长按跳高 / 二段跳 / 上键不起跳 /
踩史莱姆 / 入水 / 爬梯 / 摔死扣命 / 原地复活 / HUD 爱心 / HUD 命数 / HUD 金币 / 通关 /
通关文字 / 地面翻滚冲刺 / 翻滚撞碎木箱 / 识别到冰面 / 冰面打滑不刹车 / 连击累计倍率 /
碰到检查点就激活 / 从检查点复活 / 关卡有倒计时 / HUD 显示倒计时 / 通关后进下一关 /
第 2 关已载入 / 贴墙下滑 / 墙跳蹬出去。

> 用 `--quit-after` 这类硬退出时，退出日志里会多出 2 条 MP3 播放对象的泄漏警告。
> 那是 Godot 硬退出时音频线程来不及回收造成的，不影响运行。
> 正常关窗口走 `Main` 的 `NOTIFICATION_WM_CLOSE_REQUEST`，会先停音乐再退，没有这条警告。

## 当前状态

素材八套已整理，TileSet 已建好，三关可玩的平台跳跃：
跑跳、可变跳跃高度、二段跳、地面翻滚冲刺、蹬墙跳、游泳、爬梯、冰面滑行、
金币与拾取物、互动块、砸木箱、绿/紫史莱姆、检查点、连击倍率、限时挑战、血量命数、通关换关。

配色统一按 `assets/PALETTE.md` 的色板家族命名，同一块色板在不同物件里叫同一个名字。
