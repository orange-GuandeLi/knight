# 字体

点阵像素字体 **Pixel Operator 8**。

| 文件 | 全名 | 字形数 |
|---|---|---|
| `PixelOperator8.ttf` | Pixel Operator 8 | 238 |
| `PixelOperator8-Bold.ttf` | Pixel Operator 8 Bold | 238 |

## 覆盖范围

- 拉丁字母 A-Z / a-z 共 62 个字符**全有**
- 数字、常用标点齐全
- **没有中文字形**（0/14）

所以游戏内显示的文字全部用英文，中文只出现在文档里。
要换成中文界面的话，得另配一个带 CJK 的字体，或者打开 `allow_system_fallback`
让缺字回退到系统字体（能显示，但就不是点阵风格了）。

## 导入设置

点阵字体必须关掉抗锯齿，否则放大后字形会发糊。已写进 `.import`：

```
antialiasing=0        # 关抗锯齿
hinting=0
subpixel_positioning=0
```

## 用法

主题资源 `assets/ui/pixel_theme.tres` 已经把它设成默认字体（`default_font_size = 32`），
HUD 的两个节点都挂了这个主题：

```gdscript
# 想单独给某个 Label 换字号
label.add_theme_font_size_override("font_size", 48)
```

字号建议用 **8 的倍数**（8 / 16 / 24 / 32 / 48 / 56），这样字形落在整数像素上不会糊。
