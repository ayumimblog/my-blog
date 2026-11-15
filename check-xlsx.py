#!/usr/bin/env python3
"""インスタ用の表（xlsx）のタイトルが、記事のタイトルと合っているか調べる。

表は「記事タイトル」で記事を探している。ブログ側のタイトルを変えたのに表を直し忘れると、
インスタの素材を作るときに画像が見つからなくなる。
2026-11-15に、過去のタイトル変更で5行ずれていたのが見つかった。

使い方: python3 check-xlsx.py      （ずれがあれば一覧を出して終了コード1）
"""
import glob, os, re, sys, unicodedata, warnings
warnings.filterwarnings('ignore')
import openpyxl
BLOG = os.path.dirname(os.path.abspath(__file__))
def norm(s): return re.sub(r'\s+', '', unicodedata.normalize('NFKC', s or ''))
titles = set()
for p in glob.glob(os.path.join(BLOG, 'content/posts/*.md')):
    h = open(p, encoding='utf-8').read().split('---', 2)
    t = re.search(r'^title:\s*"(.*)"', h[1] if len(h) > 1 else '', re.M)
    if t: titles.add(norm(t.group(1)))
ws = openpyxl.load_workbook(os.path.join(BLOG, 'インスタ投稿スケジュール_ドタバタ母さんブログ.xlsx'), read_only=True).active
bad = []
for i, r in enumerate(ws.iter_rows(min_row=2, values_only=True), 2):
    if r[1] and '見送り' not in (r[4] or '') and '投稿済' not in (r[4] or '') and norm(r[1]) not in titles:
        bad.append((i, r[1]))
if bad:
    print('⚠️  インスタ用の表と、記事のタイトルが合っていません（表のB列を記事のタイトルに直してください）')
    for i, t in bad: print(f'   行{i}: {t[:44]}')
    sys.exit(1)
print('✅ インスタ用の表と記事のタイトルは合っています')
