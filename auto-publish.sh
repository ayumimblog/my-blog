#!/bin/bash
# 次に公開すべき下書きを自動で選んで公開するスクリプト
#
# 使い方:
#   ./auto-publish.sh          … 実際に公開する
#   ./auto-publish.sh --dry-run … どの記事が選ばれるか確認だけする（公開しない）
#
# やること:
#   1. draft: true の記事を「Gitに追加された順（作成順）」で並べ、先頭の1本を選ぶ
#   2. 整形が終わっていない記事（Blogger形式のHTMLが残っている等）はスキップして次へ
#   3. publish.sh を呼び出して公開（ビルド→push→Cloudflareデプロイ）
#   4. 結果をログ（auto-publish.log）に残し、Macに通知を出す
#
# launchd（com.dotabata.autopublish）から毎週月・木の朝に自動実行される

cd "$(dirname "$0")" || exit 1

# launchdから実行されるとPATHが最小限なので、hugo/node/gitの場所を追加
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
  DRY_RUN=true
fi

LOG="auto-publish.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

notify() {
  # Macの画面右上に通知を出す
  osascript -e "display notification \"$1\" with title \"ブログ自動公開\"" 2>/dev/null || true
}

# --- 1. 下書きを作成順（Gitに追加された順）で並べる ---
TMPFILE=$(mktemp)
for f in content/posts/*.md; do
  draft=$(grep -m1 "^draft:" "$f" | awk '{print $2}')
  if [ "$draft" = "true" ]; then
    added=$(git log --diff-filter=A --follow --format=%aI -- "$f" | tail -1)
    if [ -z "$added" ]; then
      added=$(date -r "$f" "+%Y-%m-%dT%H:%M:%S")
    fi
    echo "$added $f" >> "$TMPFILE"
  fi
done

if [ ! -s "$TMPFILE" ]; then
  log "下書きがありません。公開をスキップしました。"
  notify "公開できる下書きがありません"
  rm -f "$TMPFILE"
  exit 0
fi

# --- 2. 先頭から順に、公開できる状態かチェック ---
TARGET=""
while read -r added f; do
  # Blogger形式のHTMLが残っている記事は未整形なのでスキップ
  if grep -q "blogger.googleusercontent.com" "$f" || grep -q "data-path-to-node" "$f"; then
    log "スキップ（未整形・Blogger形式）: $f"
    continue
  fi
  # カバー画像が未設定・仮置きの記事はスキップ
  if grep -q "PLACEHOLDER" "$f"; then
    log "スキップ（カバー画像が仮置き）: $f"
    continue
  fi
  TARGET="$f"
  break
done < <(sort "$TMPFILE")
rm -f "$TMPFILE"

if [ -z "$TARGET" ]; then
  log "公開できる状態の下書きがありません（全て未整形のためスキップ）。"
  notify "⚠️ 公開できる記事がありません。下書きの整形が必要です"
  exit 0
fi

TITLE=$(grep -m1 '^title:' "$TARGET" | sed 's/title: //' | tr -d '"')

if [ "$DRY_RUN" = true ]; then
  echo "【ドライラン】次に公開される記事:"
  echo "  $TARGET"
  echo "  $TITLE"
  exit 0
fi

# --- 3. 公開実行 ---
log "公開開始: $TARGET ($TITLE)"

if ./publish.sh "$TARGET" >> "$LOG" 2>&1; then
  log "公開成功: $TITLE"
  notify "✅ 公開しました：$TITLE"
else
  log "公開失敗: $TITLE （詳細は auto-publish.log を確認）"
  notify "❌ 公開に失敗しました。auto-publish.log を確認してください"
  exit 1
fi
