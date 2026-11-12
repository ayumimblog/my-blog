#!/bin/bash
# サイトに反映されていない変更が残っていないか調べる。
#
# なぜ必要か：
#   3nin-dotabata.com は GitHub へのプッシュで更新されます。
#   wrangler deploy が更新するのは workers.dev のほうだけです。
#
#   2026-11-12に、コミットだけしてプッシュを忘れ、
#   「直したのにサイトが古いまま」という状態に20分気づけませんでした。
#
# 使い方: ./check-deploy.sh

cd "$(dirname "$0")" || exit 1
rc=0

echo "🔍 サイトへの反映を確認しています..."

# 1. コミットしていない変更
# themes/stack は元からある未追跡フォルダなので除く
CHANGES=$(git status --porcelain | grep -v 'themes/stack')
if [ -n "$CHANGES" ]; then
  echo "⚠️  コミットしていない変更があります"
  echo "$CHANGES" | head -10
  rc=1
fi

# 2. プッシュしていないコミット
git fetch -q origin main 2>/dev/null
ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null)
if [ "${ahead:-0}" -gt 0 ]; then
  echo "⚠️  プッシュしていないコミットが ${ahead} 件あります"
  git log --oneline origin/main..HEAD | sed 's/^/     /'
  echo "     → git push origin main が必要です（サイトはプッシュで更新されます）"
  rc=1
fi

[ $rc -eq 0 ] && echo "✅ 未反映の変更はありません"
exit $rc
