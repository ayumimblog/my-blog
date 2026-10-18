#!/usr/bin/env python3
"""アイキャッチの下にタイトルを入れた、インスタ用の画像（1080x1350）を作る。
画像の比率は問わない。切らずに収めるので、絵が欠けない。"""
from PIL import Image, ImageDraw, ImageFont

F = '/System/Library/Fonts/Hiragino Sans GB.ttc'
def fnt(sz, bold=True): return ImageFont.truetype(F, sz, index=1 if bold else 0)

W = 1080
HMAX, HMIN = 1350, 760            # インスタが受け付ける範囲（4:5〜）
IMGBOX = 700                      # 画像を収める高さの上限
BG = (250, 248, 245); INK = (44, 44, 44); AC = (192, 90, 46); BAND = (224, 145, 106)

def _wrap(d, text, fo, maxw):
    lines, line = [], ''
    for ch in text:
        if ch == '\n':
            lines.append(line); line = ''; continue
        if d.textlength(line + ch, font=fo) > maxw:
            lines.append(line); line = ch
        else:
            line += ch
    lines.append(line)
    return lines

def make(img_path, title, out):
    src = Image.open(img_path).convert('RGB')
    sc = min(W / src.width, IMGBOX / src.height)      # 切らずに収める
    nw, nh = int(src.width * sc), int(src.height * sc)

    probe = ImageDraw.Draw(Image.new('RGB', (10, 10)))
    size, maxw = 56, W - 130
    lines = _wrap(probe, title, fnt(size), maxw)
    while len(lines) > 5 and size > 38:
        size -= 3
        lines = _wrap(probe, title, fnt(size), maxw)

    # 中身の量に合わせて高さを決める（余白が間延びしないように）
    text_h = int(size * 1.42) * len(lines)
    H = nh + 10 + 72 + text_h + 96
    H = max(HMIN, min(HMAX, H))

    im = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(im)
    im.paste(src.resize((nw, nh), Image.LANCZOS), ((W - nw) // 2, 0))
    d.rectangle([0, nh, W, nh + 10], fill=BAND)

    y = nh + 72
    for ln in lines:
        d.text((65, y), ln, font=fnt(size), fill=INK)
        y += int(size * 1.42)

    t = '3nin-dotabata.com'
    d.text((W - 65 - d.textlength(t, font=fnt(28, False)), H - 70), t, font=fnt(28, False), fill=AC)
    im.save(out)
    return out

if __name__ == '__main__':
    import sys
    make(sys.argv[1], sys.argv[2], sys.argv[3])
