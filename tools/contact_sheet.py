#!/usr/bin/env python3
"""把切好的素材拼成带名称标注的联系表，方便肉眼核对。

用法:
    python3 tools/contact_sheet.py <目录> <输出.png> [每行数量] [放大倍率]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

CELL = 96      # 单格画布
PAD = 10
LABEL_H = 26
COLS_DEFAULT = 8


def load_font(size):
    for p in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf",
              "/System/Library/Fonts/Supplemental/Arial.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    src_dir = sys.argv[1]
    out_path = sys.argv[2]
    cols = int(sys.argv[3]) if len(sys.argv) > 3 else COLS_DEFAULT
    scale = int(sys.argv[4]) if len(sys.argv) > 4 else 1

    names = sorted(n for n in os.listdir(src_dir) if n.lower().endswith(".png"))
    if not names:
        print(f"{src_dir} 里没有 png")
        sys.exit(1)

    rows = (len(names) + cols - 1) // cols
    W = cols * (CELL + PAD) + PAD
    H = rows * (CELL + LABEL_H + PAD) + PAD + 30

    sheet = Image.new("RGBA", (W, H), (22, 24, 30, 255))
    d = ImageDraw.Draw(sheet)
    f = load_font(11)
    ft = load_font(17)

    d.text((PAD, 8), f"{src_dir}   ({len(names)} files)", fill=(235, 238, 245, 255), font=ft)

    for i, name in enumerate(names):
        r, c = divmod(i, cols)
        x = PAD + c * (CELL + PAD)
        y = 30 + PAD + r * (CELL + LABEL_H + PAD)

        d.rectangle([x - 1, y - 1, x + CELL, y + CELL],
                    fill=(36, 39, 48, 255), outline=(72, 78, 94, 255))
        # 棋盘底，检查透明区域
        for cy in range(0, CELL, 16):
            for cx in range(0, CELL, 16):
                if (cx // 16 + cy // 16) % 2 == 0:
                    d.rectangle([x + cx, y + cy, x + cx + 15, y + cy + 15],
                                fill=(45, 49, 60, 255))

        im = Image.open(os.path.join(src_dir, name)).convert("RGBA")
        w, h = im.size
        s = min(scale, max(1, (CELL - 4) // max(w, h)))
        im = im.resize((w * s, h * s), Image.NEAREST)
        sheet.alpha_composite(im, (x + (CELL - w * s) // 2, y + (CELL - h * s) // 2))

        d.text((x + 1, y + CELL + 2), name[:20], fill=(190, 198, 214, 255), font=f)
        d.text((x + 1, y + CELL + 13), f"{w}x{h}", fill=(120, 128, 146, 255), font=f)

    sheet.convert("RGB").save(out_path, quality=95)
    print(f"{out_path}  {sheet.size}  ({len(names)} 个)")


if __name__ == "__main__":
    main()
