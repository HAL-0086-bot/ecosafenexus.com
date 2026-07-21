#!/usr/bin/env bash
#
# capture_kindle_mac.sh — macOS の Kindle デスクトップアプリで、
# 各ページを自動でスクリーンショットしながらページ送りする。
#
# 前提:
#   - Kindle for Mac を開き、読みたい本を「見開き1ページ」で表示しておく
#   - システム設定 > プライバシーとセキュリティ > 画面収録 / アクセシビリティ で
#     ターミナル(またはお使いのシェル)に許可を与えておく
#
# 使い方:
#   ./capture_kindle_mac.sh <出力フォルダ> <ページ数> [1ページの待ち秒数]
# 例:
#   ./capture_kindle_mac.sh ~/kindle_pages 320 1.2
#
# 実行後、開始まで5秒あるので Kindle をアクティブにして最初のページを表示すること。
# 途中で止めるには Ctrl-C。
set -euo pipefail

OUT="${1:?出力フォルダを指定してください}"
PAGES="${2:?ページ数を指定してください}"
DELAY="${3:-1.0}"

mkdir -p "$OUT"

echo "5秒後に開始します。Kindleを前面に出し、最初のページを表示してください..."
sleep 5

osascript -e 'tell application "Kindle" to activate' || {
  echo "警告: 'Kindle' アプリを起動できません。アプリ名が異なる場合は手動で前面にしてください。"
}
sleep 1

for i in $(seq 1 "$PAGES"); do
  n=$(printf "%05d" "$i")
  # -x: 効果音なし  -o: 影なし  -m: メインディスプレイのみ（全画面キャプチャ）
  screencapture -x -o -m "$OUT/page_$n.png"
  # 次ページへ（右矢印キー = 次ページ送り）
  osascript -e 'tell application "System Events" to key code 124' >/dev/null
  sleep "$DELAY"
  printf "\r取得: %d / %d ページ" "$i" "$PAGES"
done

echo ""
echo "完了: $OUT に $PAGES 枚を保存しました。"
echo "ヒント: 余白やUIバーが写る場合は、後段のOCR前に画像をトリミングすると精度が上がります。"
