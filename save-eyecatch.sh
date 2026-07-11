#!/bin/bash
# ダウンロードフォルダの最新画像をブログの static/images に保存する
# 使い方:
#   ./save-eyecatch.sh 新しい名前        → 新しい名前.png で保存
#   ./save-eyecatch.sh                  → 元のファイル名のまま保存
set -e

DOWNLOADS="$HOME/Downloads"
DEST="$HOME/my-blog/static/images"

# ダウンロード直下の最新の画像ファイル(png/jpg/jpeg/webp)を探す
LATEST=$(find "$DOWNLOADS" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) -print0 |
  xargs -0 stat -f "%m %N" | sort -rn | head -1 | cut -d' ' -f2-)

if [ -z "$LATEST" ]; then
  echo "ダウンロードフォルダに画像が見つかりませんでした"
  exit 1
fi

EXT="${LATEST##*.}"
if [ -n "$1" ]; then
  NAME="$1.$EXT"
else
  NAME="$(basename "$LATEST")"
fi

mv "$LATEST" "$DEST/$NAME"
echo "保存しました: static/images/$NAME"
echo "記事では images/$NAME で参照できます"
