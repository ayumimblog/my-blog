#!/usr/bin/env python3
"""Instagram予約投稿の素材を、Google Driveの「Instagram予約投稿」フォルダに置く。

予約投稿そのものは、ごま（Muse）が担当する。
こちらは **画像とキャプションを置くところまで**。予約はしない。
（2026-11-07に役割を分担）

使い方:
    python3 prep-instagram.py          # 次の4本ぶん
    python3 prep-instagram.py 8        # 次の8本ぶん

出力:
    ~/Library/CloudStorage/GoogleDrive-.../マイドライブ/Instagram予約投稿/
        YYYY-MM-DD_スラッグ/
            image-01.jpg     … 1080x1350（アイキャッチ。文字がなければタイトルを入れる）
            image-02.jpg     … 表などの追加画像があれば 1080x1080
            caption.txt      … キャプション全文（2,200字以内）
            info.txt         … 投稿希望日時／ブログ記事URL／記事タイトル
            READY            … 空ファイル。これがあるフォルダだけ、ごまが予約対象にする

注意:
    既存のサブフォルダは上書き・削除しない（すでにあればスキップする）
"""
import openpyxl, glob, re, os, sys, unicodedata
from datetime import date, datetime
from PIL import Image, ImageDraw, ImageFont

BLOG = os.path.dirname(os.path.abspath(__file__))
XLSX = os.path.join(BLOG, 'インスタ投稿スケジュール_ドタバタ母さんブログ.xlsx')
DRIVE = os.path.expanduser(
    '~/Library/CloudStorage/GoogleDrive-ayumisenteng@gmail.com/マイドライブ/Instagram予約投稿')
EXTRA_DIR = os.path.expanduser('~/Downloads')   # 表の画像などを置いてある場所
SITE = 'https://3nin-dotabata.com'
POST_TIME = '10:00'
MARU = '/System/Library/Fonts/ヒラギノ丸ゴ ProN W4.ttc'

N = int(sys.argv[1]) if len(sys.argv) > 1 else 4


def norm(s):
    """全角/半角や記号ゆれを吸収してタイトルを突き合わせる"""
    s = unicodedata.normalize('NFKC', s or '')
    return re.sub(r'\s+', '', s)


def fit_square(src_path, out_path, size=1080):
    """1080x1080 に収める（切らずに、余白は背景色で埋める）"""
    im = Image.open(src_path).convert('RGB')
    sc = min(size / im.width, size / im.height)
    nw, nh = int(im.width * sc), int(im.height * sc)
    canvas = Image.new('RGB', (size, size), (250, 248, 245))
    canvas.paste(im.resize((nw, nh), Image.LANCZOS), ((size - nw) // 2, (size - nh) // 2))
    canvas.save(out_path, quality=90, optimize=True)


def make_portrait(src_path, title, out_path, with_title=True):
    """1080x1350（4:5）。上にアイキャッチ、下にタイトル。
       with_title=False なら、画像だけを中央に置く（絵に文字が入っている記事用）。"""
    W, H = 1080, 1350
    BG = (250, 248, 245); INK = (44, 44, 44); AC = (192, 90, 46); BAND = (224, 145, 106)
    canvas = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(canvas)
    src = Image.open(src_path).convert('RGB')

    def f(sz):
        return ImageFont.truetype(MARU, sz, index=0)

    if not with_title:
        sc = min(W / src.width, H / src.height)
        nw, nh = int(src.width * sc), int(src.height * sc)
        canvas.paste(src.resize((nw, nh), Image.LANCZOS), ((W - nw) // 2, (H - nh) // 2))
        canvas.save(out_path, quality=90, optimize=True)
        return

    IMGBOX = 700
    sc = min(W / src.width, IMGBOX / src.height)
    nw, nh = int(src.width * sc), int(src.height * sc)
    canvas.paste(src.resize((nw, nh), Image.LANCZOS), ((W - nw) // 2, (IMGBOX - nh) // 2))
    d.rectangle([0, IMGBOX, W, IMGBOX + 10], fill=BAND)

    size, maxw = 58, W - 130
    def wrap(txt, fo):
        lines, line = [], ''
        for ch in txt:
            if d.textlength(line + ch, font=fo) > maxw:
                lines.append(line); line = ch
            else:
                line += ch
        lines.append(line); return lines
    lines = wrap(title, f(size))
    while len(lines) > 6 and size > 36:
        size -= 3
        lines = wrap(title, f(size))

    y = IMGBOX + 70
    for ln in lines:
        d.text((65, y), ln, font=f(size), fill=INK)
        y += int(size * 1.42)
    t = '3nin-dotabata.com'
    d.text((W - 65 - d.textlength(t, font=f(28)), H - 72), t, font=f(28), fill=AC)
    canvas.save(out_path, quality=90, optimize=True)


# 2026-09-01 より前に作られたアイキャッチは、絵の中にタイトルが入っている
# （Blogger時代＋初期のもの）。それ以降は「文字を入れない」指定で生成しているので入っていない。
TEXTLESS_SINCE = datetime(2026, 9, 1).timestamp()

def has_text_in_image(img_path):
    """絵の中にすでにタイトルが入っているか（更新日で判定）"""
    try:
        return os.path.getmtime(img_path) < TEXTLESS_SINCE
    except OSError:
        return False


# --- 記事タイトル → (スラッグ, アイキャッチの実ファイル, 正式タイトル) ---
articles = {}
for path in glob.glob(os.path.join(BLOG, 'content/posts/*.md')):
    src = open(path, encoding='utf-8').read()
    head = src.split('---', 2)[1] if src.startswith('---') else src[:1200]
    t = re.search(r'^title:\s*"(.*)"', head, re.M)
    c = re.search(r'^\s*image:\s*"(.*)"', head, re.M)
    if not t:
        continue
    slug = os.path.basename(path)[:-3]
    img = None
    if c:
        p = os.path.join(BLOG, 'static', c.group(1).lstrip('/'))
        if os.path.exists(p):
            img = p
    articles[norm(t.group(1))] = (slug, img, t.group(1))

ws = openpyxl.load_workbook(XLSX).active
pending = []
for r in range(2, ws.max_row + 1):
    if '予定' not in (ws.cell(r, 5).value or ''):
        continue
    pending.append({
        'date': ws.cell(r, 4).value,
        'title': ws.cell(r, 2).value or '',
        'caption': ws.cell(r, 6).value or '',
    })
pending = pending[:N]

if not pending:
    print('予定の投稿がありません')
    sys.exit()

if not os.path.isdir(DRIVE):
    print('Google Driveの「Instagram予約投稿」フォルダが見つかりません:')
    print(' ', DRIVE)
    sys.exit(1)

made, skipped, warned = [], [], []

for p in pending:
    slug, img, real_title = articles.get(norm(p['title']), (None, None, None))
    ymd = p['date'].replace('/', '-')
    name = f"{ymd}_{slug or 'unknown'}"
    folder = os.path.join(DRIVE, name)

    if os.path.isdir(folder):
        skipped.append(name)          # 既存は触らない
        continue
    os.makedirs(folder)

    # 画像
    if img:
        with_title = not has_text_in_image(img)
        make_portrait(img, real_title or p['title'],
                      os.path.join(folder, 'image-01.jpg'), with_title=with_title)
        n = 2
        for extra in sorted(glob.glob(os.path.join(EXTRA_DIR, 'インスタ_*.png'))):
            if slug and slug in os.path.basename(extra):
                fit_square(extra, os.path.join(folder, f'image-{n:02d}.jpg'))
                n += 1
    else:
        warned.append(f'{name}  アイキャッチが見つかりません')

    # キャプション
    cap = p['caption']
    if len(cap) > 2200:
        warned.append(f'{name}  キャプションが {len(cap)}字（2,200字超）')
    with open(os.path.join(folder, 'caption.txt'), 'w', encoding='utf-8') as f:
        f.write(cap)

    # info.txt
    url = f'{SITE}/posts/{slug}/' if slug else ''
    with open(os.path.join(folder, 'info.txt'), 'w', encoding='utf-8') as f:
        f.write(f'投稿希望日時：{ymd} {POST_TIME}\n')
        f.write(f'ブログ記事URL：{url}\n')
        f.write(f'記事タイトル：{real_title or p["title"]}\n')

    # READY（すべて揃った最後に置く）
    open(os.path.join(folder, 'READY'), 'w').close()
    made.append(name)

print(f'{len(made)}件を用意しました → {DRIVE}')
for m in made:
    print('  +', m)
if skipped:
    print(f'\nすでにあるので触りませんでした（{len(skipped)}件）')
    for s in skipped:
        print('  =', s)
if warned:
    print('\n--- 確認が必要です ---')
    for w in warned:
        print('  !', w)
