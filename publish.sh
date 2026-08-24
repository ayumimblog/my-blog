#!/bin/bash
# ブログ記事を公開するスクリプト
#
# 使い方:
#   ./publish.sh content/posts/post-XXXXXXXX-XX.md
#
# やること:
#   1. 指定した記事を draft: false にして、公開日を今日の日付に変更
#   2. Hugoでサイトをビルド（キャッシュクリアあり）
#   3. ネットワークがつながるのを待つ（Mac自動起動の直後対策）
#   4. インスタ投稿スケジュールの「ブログ投稿日」を実際の公開日に合わせる
#   5. git add / commit / push
#   6. Cloudflareへデプロイ
#   7. 実際にサイトに記事が出ているかを確認して成否を判定する

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

# Macが自動起動した直後はWi-Fiがまだつながっていないことがある。
# ネットが使えるようになるまで最大5分待つ（15秒おきに確認）。
wait_for_network() {
  local n=1
  while [ $n -le 20 ]; do
    if curl -sS -m 10 -o /dev/null https://api.github.com; then
      [ $n -gt 1 ] && echo "✅ ネットワークにつながりました"
      return 0
    fi
    [ $n -eq 1 ] && echo "⏳ ネットワークの準備を待っています..."
    sleep 15
    n=$((n + 1))
  done
  echo "⚠️ 5分待ってもネットワークにつながりませんでした。このまま続行します"
  return 0
}

# 記事が本当にサイトに出ているかを確認する（最大2分）
verify_published() {
  local url="$1" n=1
  while [ $n -le 12 ]; do
    if [ "$(curl -sS -m 10 -o /dev/null -w '%{http_code}' "$url")" = "200" ]; then
      return 0
    fi
    sleep 10
    n=$((n + 1))
  done
  return 1
}

wait_for_network

# インスタ投稿スケジュールの「ブログ投稿日」を実際の公開日に合わせる
echo "🔄 インスタ投稿スケジュールの公開日を更新しています..."
python3 sync-schedule.py || echo "⚠️ スケジュールの更新に失敗しました（公開自体は続行します）"

# git add / commit / push
git add "$FILE" public/ static/images/ "インスタ投稿スケジュール_ドタバタ母さんブログ.xlsx"
git commit -m "記事を公開: $TITLE"
retry git push origin main

echo "✅ git push 完了"

# Cloudflareへデプロイ
echo "🚀 Cloudflareへデプロイしています..."
DEPLOY_OK=1
retry npx --yes wrangler@latest deploy || DEPLOY_OK=0

# デプロイがエラーを返しても、実際にはアップロードが通っていることがある。
# 最後は「サイトに記事が出ているか」で判定する。
SLUG=$(basename "$FILE" .md)
URL="https://3nin-dotabata.com/posts/$SLUG/"

echo ""
echo "🔎 サイトに反映されたか確認しています: $URL"

if verify_published "$URL"; then
  if [ "$DEPLOY_OK" = "0" ]; then
    echo "ℹ️ デプロイ処理はエラーを返しましたが、記事はサイトに出ています（実害なし）"
  fi
  echo ""
  echo "🎉 公開作業がすべて完了しました！"
  echo "$URL で確認できます。"
else
  echo ""
  echo "❌ 記事がサイトに出ていません。手動での確認が必要です"
  echo "   もう一度試すには: cd ~/my-blog && npx --yes wrangler@latest deploy"
  exit 1
fi
