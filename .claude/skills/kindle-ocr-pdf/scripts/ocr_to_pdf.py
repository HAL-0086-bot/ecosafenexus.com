#!/usr/bin/env python3
"""
ocr_to_pdf.py — Kindleページ画像の束を「検索可能PDF」に変換する。

各ページ画像（スクリーンショット）の上に、透明なOCRテキスト層を重ねた
searchable PDF を生成する。見た目は元画像のまま、テキスト検索・コピーが可能。

前提ツール:
  - tesseract-ocr（+ 言語データ jpn / jpn_vert / eng）
  日本語データが無い場合は references/SETUP.md を参照。

使い方:
  python3 ocr_to_pdf.py <画像フォルダ> -o book.pdf
  python3 ocr_to_pdf.py <画像フォルダ> -o book.pdf --lang jpn+eng
  python3 ocr_to_pdf.py <画像フォルダ> -o book.pdf --vertical      # 縦書き
  python3 ocr_to_pdf.py <画像フォルダ> -o book.pdf --preprocess    # 二値化で精度改善
  python3 ocr_to_pdf.py <画像フォルダ> -o book.pdf --also-text     # book.txt も出力

画像は連番ファイル名で自然順ソートされる（page_1, page_2, ..., page_10）。
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".bmp", ".webp"}


def natural_key(path):
    name = os.path.basename(path)
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", name)]


def collect_images(folder):
    files = []
    for entry in os.listdir(folder):
        full = os.path.join(folder, entry)
        if os.path.isfile(full) and os.path.splitext(entry)[1].lower() in IMAGE_EXTS:
            files.append(full)
    files.sort(key=natural_key)
    return files


def check_tesseract():
    exe = shutil.which("tesseract")
    if not exe:
        sys.exit(
            "エラー: tesseract が見つかりません。\n"
            "  Debian/Ubuntu: sudo apt-get install -y tesseract-ocr "
            "tesseract-ocr-jpn tesseract-ocr-jpn-vert tesseract-ocr-eng\n"
            "  macOS: brew install tesseract tesseract-lang\n"
            "詳細は references/SETUP.md を参照。"
        )
    langs = subprocess.run(
        [exe, "--list-langs"], capture_output=True, text=True
    ).stdout.splitlines()
    return exe, set(l.strip() for l in langs[1:] if l.strip())


def verify_langs(requested, available):
    missing = [l for l in requested.split("+") if l not in available]
    if missing:
        sys.exit(
            f"エラー: 言語データが未インストール: {', '.join(missing)}\n"
            f"  利用可能: {', '.join(sorted(available)) or '(なし)'}\n"
            "  日本語なら: sudo apt-get install -y tesseract-ocr-jpn tesseract-ocr-jpn-vert"
        )


def preprocess_images(images, workdir):
    """二値化＋グレースケールで軽く前処理。Pillow が無ければ元画像をそのまま使う。"""
    try:
        from PIL import Image, ImageOps
    except ImportError:
        print("注意: Pillow 未導入のため前処理をスキップ（pip install pillow で有効化）",
              file=sys.stderr)
        return images
    out = []
    for i, img in enumerate(images):
        im = Image.open(img).convert("L")
        im = ImageOps.autocontrast(im)
        dst = os.path.join(workdir, f"pp_{i:05d}.png")
        im.save(dst)
        out.append(dst)
    return out


def main():
    ap = argparse.ArgumentParser(description="Kindleページ画像→検索可能PDF")
    ap.add_argument("folder", help="ページ画像が入ったフォルダ")
    ap.add_argument("-o", "--output", default="book.pdf", help="出力PDF (既定: book.pdf)")
    ap.add_argument("--lang", default="jpn+eng", help="OCR言語 (既定: jpn+eng)")
    ap.add_argument("--vertical", action="store_true",
                    help="縦書き用に jpn_vert を使う")
    ap.add_argument("--psm", default=None,
                    help="tesseract page segmentation mode (縦書きは 5 が有効なことがある)")
    ap.add_argument("--preprocess", action="store_true",
                    help="二値化などの前処理で精度改善")
    ap.add_argument("--also-text", action="store_true",
                    help="プレーンテキスト(.txt)も同時に出力")
    args = ap.parse_args()

    if not os.path.isdir(args.folder):
        sys.exit(f"エラー: フォルダが見つかりません: {args.folder}")

    images = collect_images(args.folder)
    if not images:
        sys.exit(f"エラー: 画像が見つかりません: {args.folder}")
    print(f"ページ数: {len(images)}")

    lang = args.lang
    if args.vertical:
        # 縦書きは jpn_vert を先頭に。英数字も拾えるよう eng を残す。
        parts = [p for p in lang.split("+") if p not in ("jpn", "jpn_vert")]
        lang = "+".join(["jpn_vert"] + parts) if parts else "jpn_vert"

    exe, available = check_tesseract()
    verify_langs(lang, available)

    with tempfile.TemporaryDirectory() as workdir:
        if args.preprocess:
            print("前処理中...")
            images = preprocess_images(images, workdir)

        # tesseract に画像リストを渡すと多ページの searchable PDF を生成する
        list_file = os.path.join(workdir, "images.txt")
        with open(list_file, "w") as f:
            f.write("\n".join(images))

        out_base = os.path.splitext(os.path.abspath(args.output))[0]
        configs = ["pdf"]
        if args.also_text:
            configs.append("txt")

        cmd = [exe, list_file, out_base, "-l", lang]
        if args.psm:
            cmd += ["--psm", args.psm]
        elif args.vertical:
            cmd += ["--psm", "5"]  # 縦書きブロックの既定
        cmd += configs

        print("OCR実行中: " + " ".join(cmd))
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            sys.stderr.write(proc.stderr)
            sys.exit(f"tesseract がエラー終了 (code {proc.returncode})")

    pdf_path = out_base + ".pdf"
    if not os.path.exists(pdf_path):
        sys.exit("エラー: PDFが生成されませんでした。")
    size = os.path.getsize(pdf_path) / 1024
    print(f"完了: {pdf_path} ({size:.0f} KB)")
    if args.also_text and os.path.exists(out_base + ".txt"):
        print(f"テキスト: {out_base}.txt")


if __name__ == "__main__":
    main()
