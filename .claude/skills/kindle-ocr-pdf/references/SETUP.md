# セットアップ（OCRツールの導入）

`ocr_to_pdf.py` は **tesseract-ocr** と日本語言語データを使います。実行環境に
無い場合は下記を導入してください。

## Claude Code の実行環境（Linux / Debian・Ubuntu）

```bash
sudo apt-get update
sudo apt-get install -y \
  tesseract-ocr \
  tesseract-ocr-jpn \
  tesseract-ocr-jpn-vert \
  tesseract-ocr-eng \
  poppler-utils
# 前処理を使う場合
pip install --quiet pillow
```

インストール確認:

```bash
tesseract --version
tesseract --list-langs   # jpn, jpn_vert, eng が出ればOK
```

> 注意: クラウド実行環境ではネットワークポリシーや権限により `apt-get` が
> 使えないことがあります。その場合は「Claudeのビジョンで読む」代替経路
> （SKILL.md 参照）を使ってください。

## macOS（キャプチャ〜ローカル変換も自分で行う場合）

```bash
brew install tesseract tesseract-lang poppler
```

## Windows

- Tesseract: <https://github.com/UB-Mannheim/tesseract/wiki> のインストーラ
  （インストール時に Japanese / Japanese (vertical) の言語データを選択）
- インストール後、`tesseract` に PATH を通す

## 言語データのファイル名対応

| 用途 | tesseract 言語コード |
|------|----------------------|
| 日本語（横書き） | `jpn` |
| 日本語（縦書き） | `jpn_vert` |
| 英数字 | `eng` |
| 併用（推奨） | `jpn+eng` / 縦書きは `jpn_vert+eng` |

## 精度を上げるコツ

- **解像度**: Kindle のフォントを大きめにして、1ページの文字を鮮明に。
  スクショはRetina/高DPIのまま（縮小しない）。
- **トリミング**: ページ送りバー・章タイトル帯・時計などUIが写ると誤認識の
  原因。`--preprocess` に加え、可能なら本文領域だけに切り出す。
- **縦書き**: `--vertical`（内部で `jpn_vert` + `--psm 5`）。それでも崩れる
  場合は Claude ビジョン経路が有利。
- **見開き2ページ表示**: 左右で1枚に写ると精度が落ちる。1ページ表示推奨。
