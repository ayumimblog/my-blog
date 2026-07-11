#!/bin/bash
# ブログ記事を公開するスクリプト
#
# 使い方:
#   ./publish.sh content/posts/post-XXXXXXXX-XX.md
#
# やること:
#   1. 指定した記事を draft: false にして、公開日を今日の日付に変更
#   2. Hugoでサイトをビルド（キャッシュクリアあり）
#   3. git add / commit / push
#   4. Cloudflareへデプロイ

set -e

if [ -z "$1" ]; then
  echo "❌ 公開する記事のパスを指定してください"
  echo "例: ./publish.sh content/posts/post-20260421-35.md"
  exit 1
fi

FILE="$1"
TODAY=$(date +%Y-%m-%d)

if [ ! -f "$FILE" ]; then
  echo "❌ ファイルが見つかりません: $FILE"
  exit 1
fi

TITLE=$(grep -m1 '^title:' "$FILE" | sed 's/title: //')

echo "📝 公開する記事: $TITLE"
echo "📅 公開日を $TODAY に設定します"

# draft: true → false、date を今日の日付に更新
sed -i '' "s/^draft: true/draft: false/" "$FILE"
sed -i '' "s/^date: .*/date: $TODAY/" "$FILE"

echo "✅ フロントマターを更新しました"

# Hugoでビルド（キャッシュクリア）
echo "🔨 サイトをビルドしています..."
rm -rf resources/_gen
hugo --minify --gc --cleanDestinationDir

echo "✅ ビルド完了"

# ネットワークが一時的に切れても3回まで再試行する（間隔は60秒）
retry() {
  local n=1
  until "$@"; do
    if [ $n -ge 3 ]; then
      echo "❌ 3回試しても失敗しました: $*"
      return 1
    fi
    echo "⚠️ 失敗しました（$n回目）。60秒待って再試行します: $*"
    sleep 60
    n=$((n + 1))
  done
}

# git add / commit / push
git add "$FILE" public/
git commit -m "記事を公開: $TITLE"
retry git push origin main

echo "✅ git push 完了"

# Cloudflareへデプロイ
echo "🚀 Cloudflareへデプロイしています..."
retry npx --yes wrangler@latest deploy

echo ""
echo "🎉 公開作業がすべて完了しました！"
echo "数分後に https://3nin-dotabata.com で確認してみてください。"
