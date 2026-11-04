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
│   ├── icons/             # 图标（含项目图标 icon.svg）
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
├── tools/                 # 资源生成 / 切图脚本
│   ├── build_frames.gd
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

## 怎么玩

打开项目直接 F5（或命令行 `Godot --path .`），主场景就是 `scenes/main/Main.tscn`。

| 操作 | 按键 |
|---|---|
| 左右移动 | `A` / `D` 或 `←` / `→` |
| 跳跃 | `Space` / `W` / `↑` / `Z` |
| 下蹲·翻滚跳 | `S` / `↓` 按住再按跳跃 |
| 爬梯子 | 站在梯子上按 `Space` / `W` 上行，`S` 下行，按左右脱手 |
| 游泳 | 掉进水里按住跳跃上浮 |
| 重开 | `R` |

规则：

- 金币 +100，蘑菇 +200，水果 +150，药瓶回 1 点血
- 顶问号块出蘑菇，顶感叹号块出药瓶；块顶过就变成空块
- 史莱姆可以踩死（+200）；被侧面撞到掉 1 点血
- 血掉光就死，掉一条命、原地复活（吃过的金币和顶过的块都保留）；命掉光游戏结束
- 走到最右边通关
- 音效：跳跃 / 金币 / 拾取 / 受伤 / 踩怪 / 顶块 各有对应音效，背景音乐循环播放

## 代码结构

```
scenes/
  main/Main.tscn        入口：关卡 + HUD
  levels/Level01.tscn   关卡（两个 TileMapLayer + 实体容器 + 玩家）
  actors/Player.tscn    骑士
  actors/Slime.tscn     史莱姆
  objects/Coin.tscn     金币
  objects/Pickup.tscn   蘑菇 / 药瓶 / 水果
  ui/HUD.tscn           分数 / 金币 / 血 / 命（点阵字体）

scripts/
  main.gd               重开
  actors/player.gd      移动、跳跃、翻滚跳、游泳、爬梯、受伤、死亡
  actors/slime.gd       巡逻、踩死、撞到玩家
  objects/coin.gd       金币
  objects/pickup.gd     拾取物
  levels/level.gd       读 json 铺砖、生成实体、撞块逻辑、通关判定
  ui/hud.gd             状态栏
  autoload/game.gd      全局状态（分数 / 命 / 血 / 金币）
  autoload/audio.gd     音效池 + 背景音乐
  utils/tile_index.gd   砖名 <-> 图集坐标
  utils/level_bounds.gd 关卡像素边界

assets/tilesets/world/
  world_tileset.tres    TileSet（5 个图集源：地形 / 道具 / 水 / 背景 / 植物）
  plants/               树（顶/身/底，body 可重复）+ 草丛
  atlases/              图集（由 tools/build_atlases.py 生成）

assets/audio/           音乐 + 音效
assets/fonts/           点阵字体
assets/ui/pixel_theme.tres  HUD 主题（默认字体 = Pixel Operator 8）
```

**游戏内文字是英文**：点阵字体 Pixel Operator 8 只有拉丁字形，没有中文。
文档保持中文。

物理层：1 = 地形，2 = 玩家，4 = 敌人，8 = 水 / 木梯感应。

## 改关卡

关卡是 `120×48` 格（16px 一格 = 1920×768 像素），数据在 `scenes/levels/level01.json`，
由 `tools/make_level.py` 生成。改关卡改那个脚本再重跑：

```bash
python3 tools/make_level.py     # 重新生成关卡地形
python3 tools/build_atlases.py  # 素材有变动时重打图集
Godot --headless --path . --script res://tools/build_tileset.gd   # 重建成 TileSet
python3 tools/preview_level.py /tmp/lv.png   # 渲染一张关卡预览图
```

## 自测

```bash
Godot --headless --path . res://tools/SmokeTest.tscn
```

会跑一遍站立 / 跑动 / 撞问号块 / 踩史莱姆 / 入水 / 爬梯 / 摔死扣命 / 原地复活 / 通关 / HUD 共 11 项检查。

> 用 `--quit-after` 这类硬退出时，退出日志里会多出 2 条 MP3 播放对象的泄漏警告。
> 那是 Godot 硬退出时音频线程来不及回收造成的，不影响运行。
> 正常关窗口走 `Main` 的 `NOTIFICATION_WM_CLOSE_REQUEST`，会先停音乐再退，没有这条警告。

## 当前状态

素材八套已整理，TileSet 已建好，已实现一关可玩的平台跳跃：跑跳、翻滚跳、游泳、爬梯、
金币与拾取物、互动块、史莱姆敌人、血量命数、通关判定。

配色统一按 `assets/PALETTE.md` 的色板家族命名，同一块色板在不同物件里叫同一个名字。
