# capture_kindle_windows.ps1 — Windows の Kindle デスクトップアプリで、
# 各ページを自動でスクリーンショットしながらページ送りする。
#
# 前提:
#   - Kindle for PC を開き、読みたい本を表示しておく
#
# 使い方 (PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\capture_kindle_windows.ps1 -Out "$HOME\kindle_pages" -Pages 320 -Delay 1.2
#
# 実行後5秒で開始。その間に Kindle を前面に出し、最初のページを表示すること。
# 途中で止めるには Ctrl-C。

param(
    [Parameter(Mandatory=$true)][string]$Out,
    [Parameter(Mandatory=$true)][int]$Pages,
    [double]$Delay = 1.0
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

New-Item -ItemType Directory -Force -Path $Out | Out-Null

Write-Host "5秒後に開始します。Kindleを前面に出し、最初のページを表示してください..."
Start-Sleep -Seconds 5

$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

for ($i = 1; $i -le $Pages; $i++) {
    $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $name = "page_{0:D5}.png" -f $i
    $bmp.Save((Join-Path $Out $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $gfx.Dispose(); $bmp.Dispose()

    # 次ページへ（右矢印キー送出）
    [System.Windows.Forms.SendKeys]::SendWait("{RIGHT}")
    Start-Sleep -Seconds $Delay
    Write-Host -NoNewline ("`r取得: {0} / {1} ページ" -f $i, $Pages)
}

Write-Host ""
Write-Host "完了: $Out に $Pages 枚を保存しました。"
Write-Host "ヒント: 余白やUIバーが写る場合は、OCR前に画像をトリミングすると精度が上がります。"
