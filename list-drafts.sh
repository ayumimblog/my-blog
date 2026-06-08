#!/bin/bash
# 下書き記事の一覧と、月・木ペースでの公開予定日を表示するスクリプト
#
# 使い方:
#   ./list-drafts.sh
#
# やること:
#   - draft: true の記事を、記事内の date（作成順）でソート
#   - 次の月曜・木曜から順番に公開予定日を自動で割り当てて一覧表示

cd "$(dirname "$0")" || exit 1

# 今日の曜日番号を取得（1=月, 4=木 ... 0=日, 6=土）
TODAY=$(date +%Y-%m-%d)
TODAY_WDAY=$(date -j -f "%Y-%m-%d" "$TODAY" +%u)  # 1(月)〜7(日)

# 次の月曜 or 木曜の日付を求める関数
# $1: 起点日(YYYY-MM-DD)  $2: 起点日を含めるかどうか(include/exclude)
next_pub_date() {
  local from="$1"
  local mode="$2"
  local d="$from"
  local first=true
  while true; do
    local wday=$(date -j -f "%Y-%m-%d" "$d" +%u)
    if { [ "$wday" = "1" ] || [ "$wday" = "4" ]; } && { [ "$mode" = "include" ] || [ "$first" = false ]; }; then
      echo "$d"
      return
    fi
    d=$(date -j -v+1d -f "%Y-%m-%d" "$d" +%Y-%m-%d)
    first=false
  done
}

echo "=================================================="
echo " 下書き記事 一覧 ＆ 公開予定日（月・木ペース）"
echo "=================================================="
echo ""

# draft:true の記事を、Gitに追加された順（＝作成順）でリストアップ
# ※記事内の date は公開予定日として手動で書き換えることがあるため、
#   並び順の基準には使わない
TMPFILE=$(mktemp)
for f in content/posts/*.md; do
  draft=$(grep -m1 "^draft:" "$f" | awk '{print $2}')
  if [ "$draft" = "true" ]; then
    # その記事が最初にコミットされた日時を取得（作成順の基準）
    added=$(git log --diff-filter=A --follow --format=%aI -- "$f" | tail -1)
    if [ -z "$added" ]; then
      added=$(date -r "$f" "+%Y-%m-%dT%H:%M:%S")
    fi
    title=$(grep -m1 "^title:" "$f" | sed 's/title: //')
    scheduled=$(grep -m1 "^date:" "$f" | awk '{print $2}')
    echo "$added|$f|$title|$scheduled" >> "$TMPFILE"
  fi
done

sort "$TMPFILE" -o "$TMPFILE"

# 公開予定日の起点（今日が月・木ならそこから、それ以外は次の月・木から）
NEXT_DATE=$(next_pub_date "$TODAY" "include")

NUM=1
while IFS='|' read -r created file title scheduled; do
  WDAY=$(date -j -f "%Y-%m-%d" "$NEXT_DATE" +%u)
  if [ "$WDAY" = "1" ]; then
    YOUBI="月"
  else
    YOUBI="木"
  fi

  # すでに記事内の date が「今日より先の日付」になっている場合は
  # 手動で予定日が設定されている可能性があるので、両方を表示する
  if [[ "$scheduled" > "$TODAY" ]]; then
    SCHED_WDAY=$(date -j -f "%Y-%m-%d" "$scheduled" +%u 2>/dev/null)
    case "$SCHED_WDAY" in
      1) SCHED_YOUBI="月" ;;
      4) SCHED_YOUBI="木" ;;
      *) SCHED_YOUBI="?" ;;
    esac
    printf "%2d. 【手動設定済み】%s（%s）※自動順では %s（%s）\n" "$NUM" "$scheduled" "$SCHED_YOUBI" "$NEXT_DATE" "$YOUBI"
  else
    printf "%2d. 【公開予定】%s（%s）\n" "$NUM" "$NEXT_DATE" "$YOUBI"
  fi
  printf "    %s\n" "$title"
  printf "    %s\n\n" "$file"

  NEXT_DATE=$(next_pub_date "$NEXT_DATE" "exclude")
  NUM=$((NUM + 1))
done < "$TMPFILE"

rm -f "$TMPFILE"

echo "=================================================="
echo "公開する記事ができたら、次のコマンドで公開できます："
echo "  ./publish.sh content/posts/ファイル名.md"
echo "=================================================="
