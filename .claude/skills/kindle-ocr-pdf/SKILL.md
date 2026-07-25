---
name: kindle-ocr-pdf
description: |
  Kindle（キンドル）で購入・保有している本のページをOCRで読み取り、検索可能なPDFに変換するスキル。ページ画像（スクリーンショット）の束を受け取り、tesseractまたはClaudeのビジョンでテキスト化し、元の見た目を保ったまま文字検索・コピーができるPDFを生成する。「Kindleの本をPDFにして」「Kindleの本をOCRで読んでPDF化して」「電子書籍をOCRして検索可能PDFに」「スクショした本のページをPDFにまとめて」「縦書きの本をOCRして」といった依頼で必ずこのスキルを使うこと。ページ画像がまだ手元に無い場合は、キャプチャ用ヘルパースクリプトの使い方も案内する。
---

# kindle-ocr-pdf：KindleページのOCR→検索可能PDF化

Kindleの本のページ画像を、**元の見た目を保ったまま文字検索・コピーができる
検索可能PDF**に変換する。

## ⚠️ 利用範囲の確認（最初に必ず）

- このスキルは **利用者自身が正規に購入・保有している本** を、**私的利用
  （個人の閲覧・検索・アクセシビリティ・バックアップ）** の目的で扱うための
  ものです。
- 生成したPDFの再配布・共有・アップロード・販売は著作権侵害になり得ます。
  出力は利用者個人の手元にとどめること。
- 依頼内容が明らかに再配布・共有を目的としている場合は、その旨を指摘し、
  私的利用の範囲にとどめるよう案内すること。

上記が前提として満たされている想定で進めてよい。判断に迷う共有目的が示された
ときのみ確認する。

## 全体の流れ

```
① ページ画像を用意（キャプチャ）  →  ② OCR＋PDF化  →  ③ 受け渡し
```

まず「①のページ画像がもう手元にあるか」をユーザーに確認し、状況に応じて分岐する。

---

## ① ページ画像を用意する

Kindle本文には直接アクセスできないため、**利用者のPC上でKindleデスクトップ
アプリのページをスクリーンショット**して画像化する。連番のPNG（`page_00001.png`…）
にしておくと後段がスムーズ。

### 手元にすでに画像がある場合
- ユーザーがアップロードした画像、または Google Drive 等のフォルダにある画像を
  作業ディレクトリに集める（Google Drive MCP が使える場合はそこから取得可）。
- ファイル名は自然順ソートされるので、ページ順の連番になっていることを確認する。

### これからキャプチャする場合
`scripts/` のヘルパーで、ページ送りしながら自動スクショできる。ユーザーの
**ローカルPCで実行**してもらう（クラウド実行環境からはユーザーのKindleを
操作できない）。**Kindleアプリでも、ブラウザのKindleクラウドリーダー
（read.amazon.co.jp）でも、画面に本が表示されていれば撮れる。**

**★ 最小手間ルート（推奨）— Windows・ダブルクリックで全自動**
1. ユーザーに次の2ファイルを渡す（`SendUserFile`）。同じフォルダ（例：デスクトップ）に保存してもらう:
   - `scripts/capture_kindle.ps1`（UTF-8 BOM付き。既定で「ピクチャ\kindle_pages」に保存、終端で自動停止）
   - `scripts/START_capture.cmd`（ダブルクリック起動用ランチャー）
2. ユーザー操作は「本を全画面・先頭ページで開く → `START_capture.cmd` をダブルクリック →
   5秒カウント中に本の画面をクリックして最前面 → 放置」だけ。
3. 撮り終わると保存先フォルダが自動で開くので、ZIPにして**このチャットにアップロード**してもらう。
4. **OCR→PDFはこのスキル側（クラウド環境）で仕上げる**（tesseract日本語OCRは検証済み）。
   → ユーザーはClaude Codeもtesseractも入れる必要なし。

**その他のヘルパー**
- macOS: `scripts/capture_kindle_mac.sh <出力フォルダ> <ページ数> [待ち秒]`
- Windows(引数指定版): `scripts/capture_kindle_windows.ps1 -Out <フォルダ>`

いずれも「1ページ表示・全画面・フォント大きめ・高解像度のまま」が精度のコツ
（詳細は `references/SETUP.md`）。ダブルクリックがSmartScreen等で止まる場合は、
PowerShellで `powershell -ExecutionPolicy Bypass -File "$HOME\Desktop\capture_kindle.ps1"`
を実行してもらう。

---

## ② OCRして検索可能PDFにする

方式は2つ。**既定は方式A（tesseract）**。日本語の縦書きや手書き・特殊
レイアウトで精度が出ないときは方式B（Claudeビジョン）に切り替える。

### 方式A：tesseract で検索可能PDF（既定・推奨）

元画像の上に透明なテキスト層を重ねる。**見た目は元のまま**で検索・コピー可能。

1. ツール確認・導入（未導入なら `references/SETUP.md` の手順）:
   ```bash
   tesseract --version || sudo apt-get install -y tesseract-ocr tesseract-ocr-jpn tesseract-ocr-jpn-vert tesseract-ocr-eng
   ```
2. 変換:
   ```bash
   # 横書きの日本語書籍
   python3 scripts/ocr_to_pdf.py <画像フォルダ> -o book.pdf --lang jpn+eng

   # 縦書きの書籍
   python3 scripts/ocr_to_pdf.py <画像フォルダ> -o book.pdf --vertical

   # 精度が出ないとき（二値化前処理＋テキストも出力）
   python3 scripts/ocr_to_pdf.py <画像フォルダ> -o book.pdf --preprocess --also-text
   ```
3. 生成された `book.pdf` を確認（ページ数・ファイルサイズ・数ページの検索テスト）。

**⚠️ ページサイズは必ず統一すること**
ページごとに画像サイズが違うと（内容に合わせた自動トリミングをした場合など）、
PDFビューアがページ単位でズーム率を変えてしまい、表示がガタガタになる。
トリミング後は**全ページ共通の白キャンバス（最大ページが収まるサイズ）に中央配置**
してからOCRにかける：
```python
canvas = Image.new("RGB", (CW, CH), "white")
canvas.paste(im, ((CW - im.width)//2, (CH - im.height)//2))
```

### 方式B：Claudeビジョンで読む（高精度・縦書き/難読向け）

`apt-get` が使えないクラウド環境や、tesseractで崩れる縦書き・ルビ・図表混在の
ページに有効。手順:

1. ページ画像を Read ツールで数枚ずつ読み込み、本文テキストを忠実に書き起こす
   （改行・章見出し・段落を保つ。ルビや注記は必要に応じて括弧補記）。
2. 全ページ分を積み上げてMarkdown/テキストにまとめる。
3. PDF化は `pdf` スキルを使う:
   - 読みやすい**テキスト整形PDF**にするなら reportlab で本文を流し込む
     （日本語フォント埋め込みに注意。CID フォント HeiseiMin/HeiseiKakuGo か、
     IPAex等のTTFを登録する）。
   - **元画像＋テキスト層**を保ちたい場合は、方式Aと同様に画像PDFへテキストを
     重ねる構成にする。
4. 大量ページはバッチで進め、途中経過を保存しながら進める。

> 使い分け: 「見た目そのまま・検索できればよい」→ 方式A。
> 「テキストを正確に抜き出したい・縦書きで方式Aが崩れる」→ 方式B。

---

## ③ 受け渡し

- 完成した `book.pdf` は `SendUserFile` でユーザーに渡す。
- 希望があれば Google Drive MCP でユーザーのドライブへアップロードする。
- 生成物は個人利用の範囲にとどめる旨を一言添える。

---

## トラブルシューティング

| 症状 | 対処 |
|------|------|
| `tesseract が見つかりません` | `references/SETUP.md` で導入。クラウドで導入不可なら方式Bへ |
| 縦書きが文字化け・順序崩れ | `--vertical`（`jpn_vert`＋`--psm 5`）。ダメなら方式B |
| UIバー・時計・章帯を誤認識 | 本文領域だけにトリミングしてから再OCR。`--preprocess` も併用 |
| ページ順がバラバラ | ファイル名を連番ゼロ埋め（`page_00001.png`）に統一 |
| 精度が全体的に低い | キャプチャ時のフォントを大きく・高解像度に。縮小したスクショは不利 |
| 見開き2ページが1枚に | Kindleを1ページ表示にして取り直す |

## このスキルのファイル

- `scripts/ocr_to_pdf.py` — 画像フォルダ→検索可能PDF（方式Aの中核）
- `scripts/capture_kindle.ps1` — Windows用 自動キャプチャ（最小手間ルート・BOM付き）
- `scripts/START_capture.cmd` — 上記をダブルクリック起動するランチャー
- `scripts/capture_kindle_mac.sh` — macOS用 自動キャプチャ
- `scripts/capture_kindle_windows.ps1` — Windows用 自動キャプチャ（引数指定版）
- `references/SETUP.md` — OCRツール導入と精度のコツ
