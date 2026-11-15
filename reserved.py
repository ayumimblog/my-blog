#!/usr/bin/env python3
"""個別予約（launchd の com.dotabata.publish-MMDD）の中身を調べる。

    python3 reserved.py            # 予約されている記事のスラッグを1行ずつ出す
    python3 reserved.py --today    # 今日の個別予約があれば終了コード0、なければ1

auto-publish.sh が「予約済みの記事を横取りしない」「予約がある日は休む」ために使う。
2026-11-11に、11/13予約の大道芸の記事を自動公開が先に出してしまったのがきっかけ。
"""
import glob, os, plistlib, re, sys
from datetime import date

today = date.today()
slugs, has_today = [], False
for f in glob.glob(os.path.expanduser('~/Library/LaunchAgents/com.dotabata.publish-*.plist')):
    try:
        d = plistlib.load(open(f, 'rb'))
    except Exception:
        continue
    cal = d.get('StartCalendarInterval')
    if isinstance(cal, list):
        cal = cal[0] if cal else None
    if not cal or not cal.get('Month') or not cal.get('Day'):
        continue
    slug = None
    for a in d.get('ProgramArguments', []):
        m = re.search(r'content/posts/([a-z0-9-]+)\.md', a)
        if m:
            slug = m.group(1)
            break
    if not slug:
        continue
    slugs.append(slug)
    if (cal['Month'], cal['Day']) == (today.month, today.day):
        has_today = True

if '--today' in sys.argv:
    sys.exit(0 if has_today else 1)
print('\n'.join(sorted(set(slugs))))
