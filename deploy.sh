#!/bin/bash
# 記事や設定を直したあと、サイトに反映する（新しい記事の公開は publish.sh / yoyaku.sh）
#
# 使い方:
#   ./deploy.sh "何を直したか"
#
# やること: ビルド → コミット → プッシュ → Cloudflareへデプロイ → 反映漏れの確認
#
# なぜ作ったか:
#   2026-11-12に、コミットとデプロイだけしてプッシュを忘れ、
#   「直したのにサイトが古いまま」の状態に20分気づけなかった。
#   そのときの観察では、wrangler deploy だけでは 3nin-dotabata.com は30分以上古いままで、
#   git push の2分後に切り替わった。どちらが効いているか断定はできないので、必ず両方やる。

set -e
cd "$(dirname "$0")"

MSG="$1"
[ -n "$MSG" ] || { echo "使い方: ./deploy.sh \"何を直したか\""; exit 1; }

CF_ENV="$HOME/.config/dotabata/cloudflare.env"
[ -f "$CF_ENV" ] && { set -a; . "$CF_ENV"; set +a; }
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "🔗 リンクを確認しています..."
python3 check-links.py || true

echo "🔨 ビルドしています..."
rm -rf resources/_gen
hugo --minify --gc --cleanDestinationDir >/dev/null

git add -A -- . ':!themes/stack'
if git diff --cached --quiet; then
  echo "ℹ️ 変更はありません（コミットするものがない）"
else
  git commit -q -m "$MSG

Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>"
  echo "✅ コミットしました"
fi

echo "⬆️  プッシュしています..."
git push -q origin main

echo "🚀 Cloudflareへデプロイしています..."
npx --yes wrangler@latest deploy 2>&1 | tail -2

./check-deploy.sh
echo "ℹ️ サイトへの反映には2〜3分かかることがあります"
