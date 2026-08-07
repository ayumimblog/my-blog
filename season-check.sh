#!/bin/bash
# 下書きの「旬」の状態を一覧表示する
#
# 使い方:
#   ./season-check.sh        … 今月の状態を見る
#   ./season-check.sh 12     … 12月だったらどうなるかを見る
#
# 記事のfrontmatterに season: "6-8" と書いておくと、その月の間だけ公開対象になる。
# 指定がなければ通年ネタ扱いで、いつ公開してもよい。

cd "$(dirname "$0")" || exit 1
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

M=${1:-$(date '+%m')}
M=$((10#$M))

in_season() {
  local spec="$1" range from to
  for range in ${spec//,/ }; do
    from=${range%-*}; to=${range#*-}
    if [ "$from" -le "$to" ]; then
      [ "$M" -ge "$from" ] && [ "$M" -le "$to" ] && return 0
    else
      { [ "$M" -ge "$from" ] || [ "$M" -le "$to" ]; } && return 0
    fi
  done
  return 1
}

NOW=() ALL=() WAIT=()
for f in content/posts/*.md; do
  [ "$(grep -m1 '^draft:' "$f" | awk '{print $2}')" = "true" ] || continue
  title=$(grep -m1 '^title:' "$f" | sed 's/title: //' | tr -d '"')
  spec=$(grep -m1 '^season:' "$f" | sed 's/^season: *//' | sed 's/[^0-9,-]//g')
  if [ -z "$spec" ]; then
    ALL+=("  $title")
  elif in_season "$spec"; then
    NOW+=("  [$spec] $title")
  else
    WAIT+=("  [$spec] $title")
  fi
done

echo "===== ${M}月時点の下書きの状態 ====="
echo
echo "🔥 いま旬（優先して公開される） ${#NOW[@]}本"
printf '%s\n' "${NOW[@]}"
echo
echo "📗 通年ネタ（旬のものが尽きたら古い順に公開） ${#ALL[@]}本"
printf '%s\n' "${ALL[@]}" | head -10
[ "${#ALL[@]}" -gt 10 ] && echo "  …ほか $(( ${#ALL[@]} - 10 ))本"
echo
echo "💤 いまは季節外れ（旬が来るまでお預け） ${#WAIT[@]}本"
printf '%s\n' "${WAIT[@]}"
