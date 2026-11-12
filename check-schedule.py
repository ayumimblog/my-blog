#!/usr/bin/env python3
"""公開予約と自動公開がぶつかっていないか調べる。

なぜ必要か：
    このブログには2つの公開の仕組みがあります。

      1. 週2回の自動公開（月・水 9:00）… 在庫の下書きから古い順に1本選んで出す
      2. 個別予約（launchd の com.dotabata.publish-MMDD）… 指定した記事を8:55に出す

    個別予約を入れた日が月か水だと、**同じ日に2本出ます。**
    それを防ぐために skip-dates.txt にその日を書いておく必要があります。

    2026-11-11（水）に書き忘れがあり、門限リスト（個別予約）と
    大道芸（自動公開が在庫から選んだもの）が同時に公開されました。
    大道芸は11/13の予定だったので、2日早く出てしまい、
    まだ下書きの記事へのリンクが404になりました。

使い方:
    python3 check-schedule.py
"""
import glob, os, plistlib, re, sys
from datetime import date

BLOG = os.path.dirname(os.path.abspath(__file__))
AGENTS = os.path.expanduser('~/Library/LaunchAgents')
SKIP = os.path.join(BLOG, 'skip-dates.txt')
JIDOU = (0, 2)          # 月曜=0, 水曜=2


def load_skip():
    days = set()
    if os.path.exists(SKIP):
        for line in open(SKIP, encoding='utf-8'):
            m = re.match(r'\s*(\d{4}-\d{2}-\d{2})', line)
            if m:
                days.add(m.group(1))
    return days


def main():
    skip = load_skip()
    today = date.today()
    warn = []
    rows = []

    for f in sorted(glob.glob(os.path.join(AGENTS, 'com.dotabata.publish-*.plist'))):
        try:
            d = plistlib.load(open(f, 'rb'))
        except Exception:
            continue
        cal = d.get('StartCalendarInterval')
        if isinstance(cal, dict):
            cal = [cal]
        if not cal:
            continue
        mo, da = cal[0].get('Month'), cal[0].get('Day')
        if not mo or not da:
            continue
        dt = date(today.year, mo, da)
        if dt < today:
            continue
        art = ''
        for a in d.get('ProgramArguments', []):
            m = re.search(r'content/posts/([a-z0-9-]+)\.md', a)
            if m:
                art = m.group(1)
                break
        s = dt.isoformat()
        ng = dt.weekday() in JIDOU and s not in skip
        rows.append((s, '月火水木金土日'[dt.weekday()], art, ng))
        if ng:
            warn.append((s, art))

    if not rows:
        print('これから公開予定の予約はありません')
        return 0

    print('これからの公開予約')
    for s, w, art, ng in rows:
        mark = '  ★ skip-dates.txt に書いてください' if ng else ''
        print(f'  {s}({w})  {art}{mark}')
    print()

    if warn:
        print('⚠️  自動公開（月・水 9:00）とぶつかります')
        print('   このままだと、その日は2本公開されます。')
        print('   skip-dates.txt に次の行を足してください：')
        for s, art in warn:
            print(f'     {s}  # {art} を個別公開するため')
        return 1

    print('✅ 自動公開とのぶつかりはありません')
    return 0


if __name__ == '__main__':
    sys.exit(main())
