#!/bin/bash
# 記事の公開を予約する（1コマンドで全部やる）
#
# 使い方:
#   ./yoyaku.sh content/posts/記事名.md 11/30
#
# やること:
#   1. 記事が下書きで、アイキャッチ画像が置いてあるか確かめる
#   2. その日の朝8:55に公開する予約（launchd）を作って登録する
#   3. 記事の date をその日に合わせる
#   4. 月・水なら skip-dates.txt に書く（自動公開とぶつからないように）
#   5. 予約のぶつかり・リンク切れを確認する
#
# なぜ作ったか:
#   予約は手作業で設定ファイルを作っていて、2026年11月に3回ミスがあった。
#   ・11/11 予約そのものを入れ忘れた（門限リスト）
#   ・11/11 skip-dates.txt に書き忘れて、同じ日に2本公開された
#   ・11/25と11/30 も同じ書き忘れ（事前に発見）
#   手順を覚えておく方式をやめて、1コマンドにまとめた。

cd "$(dirname "$0")" || exit 1

FILE="$1"; WHEN="$2"
if [ -z "$FILE" ] || [ -z "$WHEN" ]; then
  echo "使い方: ./yoyaku.sh content/posts/記事名.md 11/30"; exit 1
fi
[ -f "$FILE" ] || { echo "❌ 記事が見つかりません: $FILE"; exit 1; }
grep -q "^draft: true" "$FILE" || { echo "❌ この記事はもう公開済みです"; exit 1; }

MM=$(echo "$WHEN" | cut -d/ -f1 | sed 's/^0*//'); DD=$(echo "$WHEN" | cut -d/ -f2 | sed 's/^0*//')
case "$MM$DD" in (*[!0-9]*|"") echo "❌ 日付は 11/30 のように書いてください"; exit 1;; esac
MMDD=$(printf "%02d%02d" "$MM" "$DD")
YEAR=$(date +%Y)
# 今日より前の日付なら来年の予約とみなす
if [ "$(printf "%04d%s" "$YEAR" "$MMDD")" -lt "$(date +%Y%m%d)" ]; then YEAR=$((YEAR + 1)); fi
YMD=$(printf "%04d-%02d-%02d" "$YEAR" "$MM" "$DD")
date -j -f "%Y-%m-%d" "$YMD" "+%Y-%m-%d" >/dev/null 2>&1 || { echo "❌ 存在しない日付です: $YMD"; exit 1; }
DOW=$(date -j -f "%Y-%m-%d" "$YMD" "+%u")      # 1=月 … 7=日
case "$DOW" in 1) YOUBI=月;; 2) YOUBI=火;; 3) YOUBI=水;; 4) YOUBI=木;; 5) YOUBI=金;; 6) YOUBI=土;; *) YOUBI=日;; esac

SLUG=$(basename "$FILE" .md)
TITLE=$(grep -m1 '^title:' "$FILE" | sed 's/^title: *//' | tr -d '"')
PLIST="$HOME/Library/LaunchAgents/com.dotabata.publish-$MMDD.plist"

# --- 確認 ---
if [ -f "$PLIST" ]; then
  echo "❌ $WHEN にはすでに予約があります: $(grep -o 'posts/[a-z0-9-]*\.md' "$PLIST" | head -1)"
  echo "   別の日にするか、先にその予約を外してください"; exit 1
fi
OTHER=$(grep -l "content/posts/$SLUG.md" "$HOME"/Library/LaunchAgents/com.dotabata.publish-*.plist 2>/dev/null | head -1)
if [ -n "$OTHER" ]; then
  echo "❌ この記事はすでに予約されています: $(basename "$OTHER")"; exit 1
fi
IMG=$(grep -m1 '^ *image:' "$FILE" | sed 's/.*image: *//' | tr -d '"')
if [ -z "$IMG" ] || [ ! -f "static$IMG" ]; then
  echo "❌ アイキャッチ画像がまだ置かれていません: static$IMG"
  echo "   画像を置いてから、もう一度実行してください"; exit 1
fi

# --- 予約を作る ---
MSG=$(python3 -c "import sys; t=sys.argv[1][:24]; print(t.replace(chr(39),'').replace('&','＆').replace('<','＜').replace('>','＞').replace(chr(34),''))" "$TITLE")
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.dotabata.publish-$MMDD</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH; cd \$HOME/my-blog &amp;&amp; if grep -q "draft: true" content/posts/$SLUG.md; then ./publish.sh content/posts/$SLUG.md &gt;&gt; auto-publish.log 2&gt;&amp;1 &amp;&amp; osascript -e 'display notification "公開しました：$MSG" with title "ブログ自動公開"'; fi</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Month</key><integer>$MM</integer><key>Day</key><integer>$DD</integer><key>Hour</key><integer>8</integer><key>Minute</key><integer>55</integer></dict>
</dict>
</plist>
PLISTEOF
plutil -lint "$PLIST" >/dev/null || { echo "❌ 予約ファイルが壊れています"; rm -f "$PLIST"; exit 1; }
launchctl bootstrap "gui/$(id -u)" "$PLIST" || { echo "❌ 予約の登録に失敗しました"; rm -f "$PLIST"; exit 1; }

# 記事の日付を公開予定日に合わせる（公開時に publish.sh が実際の日時へ書き直す）
sed -i '' "s|^date: .*|date: $YMD|" "$FILE"

# 月・水は自動公開の日。記録としても skip-dates.txt に残す
if [ "$DOW" = "1" ] || [ "$DOW" = "3" ]; then
  grep -q "^$YMD" skip-dates.txt || echo "$YMD  # $SLUG を08:55に個別公開するため" >> skip-dates.txt
fi

echo "✅ 予約しました: $YMD（$YOUBI）8:55"
echo "   $TITLE"

# Macが自動で起きるのは月・水・金・土の8:50
case "$DOW" in
  2|4|7) echo "⚠️  ${YOUBI}曜はMacが自動で起きません。開いておくか、月・水・金・土にしてください"
         echo "   （閉じたままだと、次にMacを開いたときに公開されます）";;
esac

echo
python3 check-schedule.py | tail -2
python3 check-links.py | head -12
