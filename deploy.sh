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
#
#   3nin-dotabata.com は **git push で更新される**（Cloudflare側がプッシュを受けてビルドする）。
#   根拠：2026-11-14の公開では wrangler deploy が壊れて失敗していたが、
#   プッシュだけで記事は 3nin-dotabata.com にも workers.dev にも出た。
#   wrangler deploy は念のための二重化として残している。

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

# サイトは git push だけで更新される（Cloudflare側がプッシュを受けて自分でビルドする）。
# wrangler deploy は念のための二重化。失敗しても止めないが、隠さずに知らせる。
# （2026-11-14〜15、wranglerのキャッシュが壊れて失敗していたのに、出力の末尾だけ
#   見ていて気づかなかった。直し方: rm -rf ~/.npm/_npx して実行し直す）
echo "🚀 Cloudflareへデプロイしています..."
WR_LOG=$(mktemp)
if npx --yes wrangler@latest deploy > "$WR_LOG" 2>&1; then
  grep -E "Deployed|Current Version" "$WR_LOG" || tail -2 "$WR_LOG"
else
  echo "⚠️  wrangler deploy が失敗しました（サイトはプッシュで更新されるので、反映はされます）"
  grep -m3 -E "Error|error" "$WR_LOG" | sed 's/^/     /'
  echo "     直し方: rm -rf ~/.npm/_npx のあと、もう一度 ./deploy.sh"
fi
rm -f "$WR_LOG"

./check-deploy.sh
echo "ℹ️ サイトへの反映には2〜3分かかることがあります"
