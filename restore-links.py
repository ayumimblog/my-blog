#!/usr/bin/env python3
"""公開を待って外しておいたリンクを、公開後に自動で戻す。

なぜ必要か：
    まだ下書きの記事にリンクを張ると、サイト上では404になります。
    かといってリンクを外したままだと、記事が公開されても戻し忘れます。

    そこで、外すときに「リンク復活待ち.json」へ記録しておき、
    publish.sh が記事を公開したあとに、このスクリプトが戻します。

    2026-11-12に、大道芸の記事から2本ぶん（3か所）のリンクを外したのが最初です。

使い方:
    python3 restore-links.py <公開したスラッグ>   # publish.sh から呼ばれる
    python3 restore-links.py --list              # 復活待ちの一覧を見る
    python3 restore-links.py --all               # 公開済みのものを全部戻す

終了コード:
    0 … 戻したものがない、または正常に戻した
"""
import json, os, re, sys, glob

BLOG = os.path.dirname(os.path.abspath(__file__))
WAIT = os.path.join(BLOG, 'リンク復活待ち.json')


def load():
    if not os.path.exists(WAIT):
        return []
    return json.load(open(WAIT, encoding='utf-8'))


def save(data):
    if data:
        json.dump(data, open(WAIT, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    elif os.path.exists(WAIT):
        os.remove(WAIT)        # 空になったらファイルごと消す


def is_published(slug):
    p = os.path.join(BLOG, f'content/posts/{slug}.md')
    if not os.path.exists(p):
        return False
    s = open(p, encoding='utf-8').read()
    head = s.split('---', 2)[1] if s.startswith('---') else ''
    return not re.search(r'^draft:\s*true', head, re.M)


def main():
    data = load()
    if not data:
        print('復活待ちのリンクはありません')
        return 0

    if '--list' in sys.argv:
        print('復活待ちのリンク')
        for d in data:
            state = '公開済み（戻せます）' if is_published(d['公開を待つ記事']) else 'まだ下書き'
            print(f"  {d['公開を待つ記事']:<28} {state}")
            print(f"    {os.path.basename(d['ファイル'])}: {d['今の文'][:46].strip()}...")
        return 0

    if '--all' in sys.argv:
        targets = {d['公開を待つ記事'] for d in data if is_published(d['公開を待つ記事'])}
    else:
        args = [a for a in sys.argv[1:] if not a.startswith('-')]
        if not args:
            print('公開したスラッグを指定してください（または --list / --all）')
            return 0
        slug = os.path.basename(args[0]).replace('.md', '')
        targets = {slug} if is_published(slug) else set()

    if not targets:
        return 0

    nokori, modosita = [], 0
    for d in data:
        if d['公開を待つ記事'] not in targets:
            nokori.append(d)
            continue
        p = os.path.join(BLOG, d['ファイル']) if not os.path.isabs(d['ファイル']) else d['ファイル']
        s = open(p, encoding='utf-8').read()
        if d['今の文'] not in s:
            print(f"⚠️  戻せませんでした（文が見つかりません）: {os.path.basename(p)}")
            print(f"    探した文: {d['今の文'][:46].strip()}")
            nokori.append(d)
            continue
        open(p, 'w', encoding='utf-8').write(s.replace(d['今の文'], d['復活後の文'], 1))
        modosita += 1
        print(f"🔗 リンクを戻しました: {os.path.basename(p)} → /posts/{d['公開を待つ記事']}/")

    save(nokori)
    if modosita:
        print(f'   {modosita}か所を戻しました。このあとのビルドで反映されます。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
