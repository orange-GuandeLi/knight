# 骑士素材 (Knight)

2D 平台跳跃主角。原始素材是一张 8 行 × 8 列的图集，导出工具按「整行整段」切出，
所以**盘上有 40 个 PNG，但只有 22 帧是真正唯一的**。

## 规格

- 全部 `32×32` PNG，透明背景，无半透明像素（硬边像素画）
- 7 色调色板：`#0E0D0E` 黑描边 / `#B3AAA1` 浅钢灰 / `#7C776F` 中灰 / `#D2202C` 红 /
  `#EBA724` 金橙 / `#0A7030` 绿 / `#EADFD1` 米白
- 角色构成：红缨盔 + 米白/钢灰栅格面甲 + 绿战袍配金腰带 + 灰靴 + 黑描边
- 脚底基线在 **y = 27**（画布底部留了 4px 空），水平方向角色约占 x = 8~24

## 目录

```
knight/
├── knight_frames.tres      # SpriteFrames，5 个动画，直接拖给 AnimatedSprite2D 用
├── idle/   idle_00..03.png
├── walk/   walk_00..07.png
├── roll/   roll_00..07.png
├── hurt/   hurt_00..03.png
└── death/  death_00..03.png
```

## 动画表

| 动画 | 唯一帧 | 帧率 | 循环 | 说明 |
|---|---|---|---|---|
| `idle` | 3 | 6 | ✅ | 呼吸微动，头盔上下浮动 1px |
| `walk` | 4 | 12 | ✅ | 左右对称的行走循环 |
| `roll` | 8 | 16 | ❌ | 后仰 → 团身 → 前移，一次性播放 |
| `hurt` | 3 | 12 | ❌ | 同一姿势整体染红（受击闪红） |
| `death` | 4 | 8 | ❌ | 前 3 帧=站立姿势，第 4 帧倒地（横躺 16×12） |

## 重复帧（盘上有、但 SpriteFrames 未引用）

原始导出把同一段动画切了两遍，以下文件与被引用的帧**像素完全相同**，属于冗余：

| 冗余文件 | 等价于 |
|---|---|
| `idle/idle_03.png` | `idle/idle_01.png` |
| `walk/walk_04.png` | `walk/walk_00.png` |
| `walk/walk_05.png` | `walk/walk_01.png` |
| `walk/walk_06.png` | `walk/walk_02.png` |
| `walk/walk_07.png` | `walk/walk_03.png` |
| `hurt/hurt_03.png` | `hurt/hurt_01.png` |

留着是为了保留原始素材，需要清理时直接删即可，删完记得重跑一次生成脚本。

## 其它可利用的点

- `idle_00` / `roll_00` / `hurt_00` / `death_00` 四张**像素完全相同**（同一个中性姿势），
  说明这批图是从同一张图集按行切的。
- `hurt` 三个帧其实就是 `idle` 的三帧整体染红 —— 受击闪红用 `modulate` 也能做，
  不一定非要这套贴图。
- 源图集行号跳空（r00 / r02 / r05 / r06 / r07，缺 r01 / r03 / r04），
  原始图集里应该还有没用上的动画行。

## 用法

```gdscript
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
anim.sprite_frames = preload("res://assets/sprites/knight/knight_frames.tres")
anim.play("idle")
```

**Sprite2D 偏移**：想让节点原点落在脚底（推荐做碰撞体锚点），设 `offset = (0, -12)`
（脚底在纹理 y = 28 处，32×32 居中时需上移 12px）。

## 重新生成 SpriteFrames

改了帧数或帧率后重跑：

```bash
godot --headless --path . --script res://tools/build_frames.gd
```
