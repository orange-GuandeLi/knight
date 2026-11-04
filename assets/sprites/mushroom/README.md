# 蘑菇

4 种颜色的蘑菇，**两种不同的物件**：

- `big` —— 一个单独的大蘑菇
- `cluster` —— 一个大蘑菇 + 两个小蘑菇

两者不是同一个物件的两帧，形状、数量都不一样，别当成动画帧用。

## 文件

| 颜色 | 单个大蘑菇 | 大蘑菇 + 两个小蘑菇 |
|---|---|---|
| 红 | `mushroom_big_red.png` | `mushroom_cluster_red.png` |
| 金 | `mushroom_big_gold.png` | `mushroom_cluster_gold.png` |
| 紫 | `mushroom_big_purple.png` | `mushroom_cluster_purple.png` |
| 绿 | `mushroom_big_green.png` | `mushroom_cluster_green.png` |

## SpriteFrames

两个资源，各 4 个动画，每个动画 1 帧 / 8 fps / 循环：

| 资源 | 动画名 |
|---|---|
| `mushroom_big_frames.tres` | `red` / `gold` / `purple` / `green` |
| `mushroom_cluster_frames.tres` | `red` / `gold` / `purple` / `green` |

## 画法

4 种颜色共用同一个造型，只换配色。配色家族见 `assets/PALETTE.md`
（紫色这块板和药瓶 `potion_purple`、史莱姆紫是同一块）：

| 颜色 | 描边 | 菌盖浅色 | 菌盖主色 | 菌盖深色 |
|---|---|---|---|---|
| 红 | `#231C19` | `#F99C0B` | `#DD3013` | `#AF101B` |
| 金 | `#231C19` | `#FFD233` | `#F99C0B` | `#FA5F00` |
| 紫 | `#231C19` | `#E65F69` | `#B73D94` | `#6F2C77` |
| 绿 | `#242B33` | `#51A985` | `#237B59` | `#135C41` |

菌柄统一用 `#997D57` / `#C3AA83` / `#E2CFA4` 三色。

## 两个物件的区别

`big`（`tile_62` 系）：

- 整只占满 16×16，菌盖 rows 0-10，菌柄 rows 11-15。
- 菌柄是一整块，描边 `#231C19` 在两侧，内部是米色 `#C3AA83` / `#997D57`。
- 不透明像素 200 个。

`cluster`（`tile_63` 系）：

- 大蘑菇上移并压扁，菌盖 rows 5-12，菌柄在 x7-10 rows 13-15。
- 左右各挤了一只小蘑菇：左边的帽子在 x2-5 rows 13-14，右边的帽子在 x12-15 rows 12-13，
  两只小蘑菇的菌柄各只有 1px 宽。
- 不透明像素 126 个，底部和右侧都会被 16×16 的边界裁掉一点。

分辨方法：看底边中央是不是一根 4px 宽的粗菌柄——是 `big`；
底部左右两端是**菌盖色**（带花纹）而不是米色，那是 `cluster` 的两只小蘑菇。
