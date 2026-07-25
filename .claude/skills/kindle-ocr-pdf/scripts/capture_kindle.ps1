# capture_kindle.ps1 — 画面に表示中の電子書籍を、自動でページ送りしながら
# 連続スクリーンショットする（Kindle for PC でも、ブラウザの Kindle クラウド
# リーダーでも、画面に出ていれば何でも可）。
#
# 特長:
#   - 全自動でページ送り＋撮影（手作業ゼロ）
#   - 本の最後に到達すると自動停止（同じ画面が続いたら終端とみなす）
#   - 保存先は既定で「ピクチャ\kindle_pages」。指定不要。
#
# 使い方（どちらでも）:
#   ・付属の「START_capture.cmd」をダブルクリック
#   ・または PowerShell で:
#       powershell -ExecutionPolicy Bypass -File .\capture_kindle.ps1
#
# 事前に:
#   - 読みたい本を「1ページ表示」で先頭ページにし、できれば全画面(ブラウザはF11)に。
#   - 開始後5秒のカウント中に、本の画面をクリックして最前面にすること。
#   - 撮影中はマウス・キーボードを触らない（画面全体を撮るため）。
#   途中で止めるには、このウィンドウで Ctrl+C。

param(
    [string]$Out = "$env:USERPROFILE\Pictures\kindle_pages",
    [int]$Max = 3000,
    [double]$Delay = 1.2,
    [int]$StopAfterSame = 3,
    [string]$Key = "{RIGHT}"     # 次ページのキー。逆綴じ/横書き左送りは "{LEFT}" に
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

New-Item -ItemType Directory -Force -Path $Out | Out-Null

Write-Host ""
Write-Host "=== 電子書籍 自動キャプチャ ==="
Write-Host "保存先: $Out"
Write-Host ""
Write-Host "これから5秒後に開始します。今すぐ:"
Write-Host "  1) 本の画面(ブラウザ or Kindleアプリ)をクリックして最前面にする"
Write-Host "  2) できれば全画面表示(ブラウザはF11)・先頭ページにする"
Write-Host "  3) あとは触らずに待つ"
for ($s = 5; $s -ge 1; $s--) { Write-Host "  開始まで $s ..." ; Start-Sleep -Seconds 1 }

$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$md5 = [System.Security.Cryptography.MD5]::Create()

function Get-ScreenHash {
    param($bmp)
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $h = [System.BitConverter]::ToString($md5.ComputeHash($ms.ToArray()))
    $ms.Dispose()
    return $h
}

$prevHash = ""; $sameCount = 0; $saved = 0

for ($i = 1; $i -le $Max; $i++) {
    $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $hash = Get-ScreenHash $bmp

    if ($hash -eq $prevHash) {
        $sameCount++
        if ($sameCount -ge $StopAfterSame) {
            $gfx.Dispose(); $bmp.Dispose()
            Write-Host ""
            Write-Host "同じ画面が $StopAfterSame 回続いたので、本の終端と判断して停止します。"
            break
        }
    } else {
        $sameCount = 0
        $name = "page_{0:D5}.png" -f $saved
        $bmp.Save((Join-Path $Out $name), [System.Drawing.Imaging.ImageFormat]::Png)
        $saved++
        $prevHash = $hash
    }
    $gfx.Dispose(); $bmp.Dispose()

    [System.Windows.Forms.SendKeys]::SendWait($Key)
    Start-Sleep -Seconds $Delay
    Write-Host -NoNewline ("`r取得: {0} ページ" -f $saved)
}

Write-Host ""
Write-Host ""
Write-Host "完了しました。$Out に $saved 枚を保存しました。"
Write-Host ""
Write-Host "次にやること:"
Write-Host "  1) エクスプローラーで「ピクチャ」→「kindle_pages」フォルダを開く"
Write-Host "  2) フォルダを右クリック →「圧縮」→ ZIPにする"
Write-Host "  3) そのZIPをClaudeのチャットにアップロードする（OCR→PDFはClaude側で仕上げ）"
Start-Sleep -Seconds 1
# エクスプローラーで保存先を自動で開く
try { Invoke-Item $Out } catch {}
