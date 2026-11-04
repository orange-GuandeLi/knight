# 水果 (Fruit)

4 种颜色的水果，16×16 像素画。**形状完全相同，只有果肉颜色不同**（叶子和梗是共用的绿色）。

## 规格

- 全部 `16×16` PNG，透明背景，硬边像素画
- 公共部分：`#231C19` 描边、叶子/梗 `#03991F` / `#0A7030` / `#14462D`
- 果肉配色：

| 动画名 | 文件前缀 | 主色 | 参考色 | 看上去像 |
|---|---|---|---|---|
| `green` | `fruit_green_` | `#4DBD27` | `#95D836` 亮 / `#03991F` 深 | 青苹果 |
| `orange` | `fruit_orange_` | `#FA5F00` | `#FFD233` 亮 / `#F99C0B` | 橙子 |
| `pink` | `fruit_pink_` | `#E65F69` | `#F49990` 亮 / `#B73D94` | 桃子 |
| `red` | `fruit_red_` | `#DD3013` | `#FA5F00` 亮 / `#AF101B` | 红苹果 |

> 命名按**颜色**而不是品种，因为 4 张图形状完全一致，无法从像素判断真实品种。

## 动画表

3 帧，4 种颜色共用同一套动画（只是换色）：

| 帧 | 画面 | bbox |
|---|---|---|
| F0 | 完整的果子，梗和叶子在左上 | `(2,2)-(12,14)` = 11×13 |
| F1 | 果子**下落拉伸**（叶子顶到画布顶部，果身拉长到底部） | `(4,0)-(12,15)` = 9×16 |
| F2 | 果子**落地摊开**成一片汁液，底下挂两股往下淌 | `(2,1)-(12,15)` = 11×15 |

| 动画 | 帧数 | 帧率 | 循环 |
|---|---|---|---|
| `green` / `orange` / `pink` / `red` | 3 | 12 | ❌ |

这是**一次性动画**（落下 → 摊开），不是循环待机。想让它循环播放就把它接回 `idle` 帧，
或者在游戏里用 `animation_finished` 信号重新 `play()`。

## 目录

```
fruit/
├── fruit_green_00..02.png
├── fruit_orange_00..02.png
├── fruit_pink_00..02.png
├── fruit_red_00..02.png
└── fruit_frames.tres      # SpriteFrames，4 个动画：green / orange / pink / red
```

## 用法

```gdscript
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
anim.sprite_frames = preload("res://assets/sprites/fruit/fruit_frames.tres")
anim.play("red")
```

**Sprite2D 偏移**：水果不像骑士那样脚底对齐——它是个自由漂浮的收集物，
用默认 `centered = true` / `offset = (0, 0)` 让节点落在画布中心即可。

**注意 F1 会溢出画布**：拉伸帧的内容是 `y = 0~15` 顶满 16px，
如果用 `clip_children` 或遮罩要注意别把顶部切掉。
