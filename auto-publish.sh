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

# 記事の「旬」を判定する。
# frontmatter に season: "6-8" のように書いておくと、その月の間だけ公開対象になる。
#   season: "6-8"       … 6月〜8月（夏のネタ）
#   season: "11-2"      … 11月〜翌2月（年をまたぐ指定もできる）
#   season: "4-7,9-12"  … 学期中だけ（夏休み・冬休みを避けたい学校ネタ）
#   指定なし            … 通年ネタ。いつ公開してもよい
# 返り値: 0=今が旬（最優先） / 1=通年 / 9=今は季節外れ（見送り）
season_priority() {
  local file="$1"
  local spec
  # 値以外（引用符・空白・# 以降のコメント）を落として "6-8" や "4-7,9-12" だけを取り出す
  spec=$(grep -m1 "^season:" "$file" | sed 's/^season: *//' | sed 's/[^0-9,-]//g')
  [ -z "$spec" ] && { echo 1; return; }

  local m
  m=$(date '+%m')
  m=$((10#$m))   # 08 を8進数と誤解されないように10進で扱う

  local range from to
  for range in ${spec//,/ }; do
    from=${range%-*}
    to=${range#*-}
    if [ "$from" -le "$to" ]; then
      # 例 6-8 … 年をまたがない
      if [ "$m" -ge "$from" ] && [ "$m" -le "$to" ]; then echo 0; return; fi
    else
      # 例 11-2 … 年をまたぐ
      if [ "$m" -ge "$from" ] || [ "$m" -le "$to" ]; then echo 0; return; fi
    fi
  done
  echo 9
}

# --- 0. お休みの日かチェック ---
# skip-dates.txt に「2026-08-10」のように日付を書いておくと、その日は自動公開しない。
# （その日に別の記事を個別予約したいときに使う。#で始まる行はメモ扱い）
SKIP_FILE="skip-dates.txt"
TODAY=$(date '+%Y-%m-%d')
if [ -f "$SKIP_FILE" ] && grep -q "^${TODAY}\b" "$SKIP_FILE"; then
  log "お休み指定日（$TODAY）のため自動公開をスキップしました。"
  exit 0
fi

# --- 1. 下書きを作成順（Gitに追加された順）で並べる ---
TMPFILE=$(mktemp)
for f in content/posts/*.md; do
  draft=$(grep -m1 "^draft:" "$f" | awk '{print $2}')
  if [ "$draft" = "true" ]; then
    added=$(git log --diff-filter=A --follow --format=%aI -- "$f" | tail -1)
    if [ -z "$added" ]; then
      added=$(date -r "$f" "+%Y-%m-%dT%H:%M:%S")
    fi
    # 季節ネタの優先度を判定する
    #   0 … 今が旬（season指定があり、今月がその範囲内）→ 最優先
    #   1 … 通年ネタ（season指定なし）
    #   9 … 今は季節外れ（season指定があるが今月は範囲外）→ 今回は見送り
    prio=$(season_priority "$f")
    if [ "$prio" = "9" ]; then
      continue
    fi
    echo "$prio $added $f" >> "$TMPFILE"
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
while read -r prio added f; do
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

# publish.sh は最後に「実際にサイトに記事が出ているか」で成否を判定する。
# 途中でデプロイがエラーを返しても、記事が出ていれば成功として返ってくる。
if ./publish.sh "$TARGET" >> "$LOG" 2>&1; then
  log "公開成功: $TITLE"
  notify "✅ 公開しました：$TITLE"
else
  log "公開失敗: $TITLE （記事がサイトに出ていません。auto-publish.log を確認）"
  notify "❌ 公開に失敗しました。auto-publish.log を確認してください"
  exit 1
fi
