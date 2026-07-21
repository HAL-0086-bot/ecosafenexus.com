# capture_kindle_windows.ps1 — Windows の Kindle デスクトップアプリで、
# 各ページを自動でスクリーンショットしながらページ送りする。
#
# 特長:
#   - 全自動でページ送り＋スクショ（手作業ゼロ）
#   - 本の最後に到達すると自動停止（同じ画面が続いたら終端とみなす）
#     → ページ数を数える必要なし
#
# 前提:
#   - Kindle for PC を開き、読みたい本を「1ページ表示」で先頭ページにしておく
#
# 使い方 (PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\capture_kindle_windows.ps1 -Out "$HOME\Pictures\kindle_pages"
#
# オプション:
#   -Out     出力フォルダ（必須）
#   -Max     安全上限ページ数（既定 2000）。これに達したら止まる
#   -Delay   1ページの待ち秒数（既定 1.2）。描画が遅い環境は増やす
#   -StopAfterSame  同一画面が何回連続したら終端とみなすか（既定 3）
#
# 実行後5秒で開始。その間に Kindle を前面に出し、先頭ページを表示すること。
# 途中で止めるには Ctrl-C。

param(
    [Parameter(Mandatory=$true)][string]$Out,
    [int]$Max = 2000,
    [double]$Delay = 1.2,
    [int]$StopAfterSame = 3
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

New-Item -ItemType Directory -Force -Path $Out | Out-Null

Write-Host "5秒後に開始します。Kindleを前面に出し、先頭ページを表示してください..."
Start-Sleep -Seconds 5

$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$md5 = [System.Security.Cryptography.MD5]::Create()

function Get-ScreenHash {
    param($bmp)
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($ms.ToArray()))
    $ms.Dispose()
    return $hash
}

$prevHash = ""
$sameCount = 0
$saved = 0

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
            Write-Host "同じ画面が $StopAfterSame 回続いたため、本の終端と判断して停止します。"
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

    # 次ページへ（右矢印キー送出）
    [System.Windows.Forms.SendKeys]::SendWait("{RIGHT}")
    Start-Sleep -Seconds $Delay
    Write-Host -NoNewline ("`r取得: {0} ページ（送り {1} 回目）" -f $saved, $i)
}

Write-Host ""
Write-Host "完了: $Out に $saved 枚を保存しました。"
Write-Host "次にこのフォルダをチャットにアップロード（またはGoogle Driveに入れて共有）してください。"
Write-Host "ヒント: 余白やUIバーが写る場合でも、OCR前にこちらでトリミングできます。"
