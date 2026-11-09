#!/usr/bin/env python3
"""記事どうしのリンクが切れていないか調べる。

なぜ必要か：
    記事の中で「続きはこちら」と次の記事にリンクを張ったとき、
    その記事がまだ下書き（draft: true）だと、サイト上では404になります。
    Googleがリンクをたどって404を踏み、Search Consoleから
    「インデックスに登録されない（404）」という通知が来ます。
    2026-11-09に、この状態の記事が6件見つかりました。

使い方:
    python3 check-links.py                      # 公開済み記事を全部調べる
    python3 check-links.py content/posts/x.md   # その記事だけ調べる（publish.shから呼ばれる）

終了コード:
    0 … 問題なし、または「そのうち公開される記事へのリンク」だけ
    1 … リンク先の記事が存在しない（本当の切れリンク）
"""
import glob, os, re, sys

BLOG = os.path.dirname(os.path.abspath(__file__))


def load():
    """スラッグ → (下書きかどうか, 公開予定日)"""
    info = {}
    for p in glob.glob(os.path.join(BLOG, 'content/posts/*.md')):
        s = open(p, encoding='utf-8').read()
        head = s.split('---', 2)[1] if s.startswith('---') else ''
        d = re.search(r'^date:\s*(\S+)', head, re.M)
        info[os.path.basename(p)[:-3]] = (
            bool(re.search(r'^draft:\s*true', head, re.M)),
            d.group(1)[:10] if d else '?',
        )
    return info


def check(paths, info):
    machi, kire = [], []          # 公開待ち / 本当の切れリンク
    for p in paths:
        s = open(p, encoding='utf-8').read()
        head = s.split('---', 2)[1] if s.startswith('---') else ''
        if re.search(r'^draft:\s*true', head, re.M):
            continue              # 下書き自体は、まだ誰にも見えないので対象外
        me = os.path.basename(p)[:-3]
        for slug in sorted(set(re.findall(r'/posts/([a-z0-9-]+)/', s))):
            if slug == me:
                continue
            if slug not in info:
                kire.append((me, slug))
            elif info[slug][0]:
                machi.append((me, slug, info[slug][1]))
    return machi, kire


def main():
    info = load()
    args = [a for a in sys.argv[1:] if a.endswith('.md')]
    paths = args or glob.glob(os.path.join(BLOG, 'content/posts/*.md'))
    machi, kire = check(paths, info)

    if kire:
        print('❌ リンク先の記事が存在しません（本当の切れリンクです）')
        for me, slug in kire:
            print(f'   {me}  →  /posts/{slug}/')
        print()

    if machi:
        print('⚠️  まだ下書きの記事にリンクしています（今は404になります）')
        for me, slug, d in machi:
            print(f'   {me}  →  /posts/{slug}/   （公開予定 {d}）')
        print('   その記事が公開されれば直ります。急ぐならリンクを外してください。')
        print()

    if not machi and not kire:
        print(f'✅ リンク切れはありません（{len(paths)}記事を確認）')

    return 1 if kire else 0


if __name__ == '__main__':
    sys.exit(main())
