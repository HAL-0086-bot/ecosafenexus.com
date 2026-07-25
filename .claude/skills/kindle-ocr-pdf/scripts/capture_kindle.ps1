# capture_kindle.ps1 — 画面に表示中の電子書籍を、自動でページ送りしながら
# 連続スクリーンショットする（Kindle for PC / ブラウザのKindleクラウドリーダー対応）。
#
# 特長:
#   - 全自動でページ送り＋撮影（手作業ゼロ）
#   - マルチモニター対応: カウント終了時に「最前面にした本のウィンドウがある画面」を
#     自動で選んで撮る（拡張モニターに本を置いてもOK）
#   - ページ送りは既定で「本の右側をクリック」方式（クラウドリーダーで確実）
#     → キー送信でめくりたい場合は -Mode key（既定キーは→）
#   - 本の最後に到達すると自動停止（同じ画面が続いたら終端とみなす）
#   - 保存先は既定で「ピクチャ\kindle_pages」。
#
# 使い方:
#   ・付属の「START_capture.cmd」をダブルクリック
#   ・または PowerShell で:
#       powershell -ExecutionPolicy Bypass -File .\capture_kindle.ps1
#       powershell -ExecutionPolicy Bypass -File .\capture_kindle.ps1 -Mode key   # →キーでめくる
#
# 事前に:
#   - 本を「1ページ表示」で先頭ページにし、できれば全画面(ブラウザはF11)に。
#   - 開始後のカウント中に、本の画面をクリックして最前面にすること（超重要）。
#   - 撮影中はマウス・キーボードを触らない。
#   途中で止めるには、このウィンドウで Ctrl+C。

param(
    [string]$Out = "$env:USERPROFILE\Pictures\kindle_pages",
    [int]$Max = 3000,
    [double]$Delay = 1.4,
    [int]$StopAfterSame = 3,
    [ValidateSet("click","key")][string]$Mode = "click",
    [string]$Key = "{RIGHT}",     # -Mode key のときの次ページキー（左送りは "{LEFT}"）
    [double]$ClickX = 0.94,       # クリック位置（画面幅に対する割合）。右側=次ページ
    [double]$ClickY = 0.5,
    [int]$Monitor = 0             # 0=最前面ウィンドウの画面を自動選択 / 1,2,..=画面番号を明示
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
    public const uint LEFTDOWN = 0x0002;
    public const uint LEFTUP   = 0x0004;
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(40);
        mouse_event(LEFTDOWN, 0, 0, 0, IntPtr.Zero);
        mouse_event(LEFTUP,   0, 0, 0, IntPtr.Zero);
    }
}
"@

New-Item -ItemType Directory -Force -Path $Out | Out-Null

$existing = @(Get-ChildItem -Path $Out -Filter "page_*.png" -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0) {
    Write-Host ""
    Write-Host ("注意: 保存先に既存の画像が {0} 枚あります: $Out" -f $existing.Count)
    $ans = Read-Host "前回分を削除して撮り直すなら y を入力（それ以外はそのまま追記）"
    if ($ans -eq "y") {
        Remove-Item -Path (Join-Path $Out "page_*.png") -Force -ErrorAction SilentlyContinue
        Write-Host "既存画像を削除しました。"
    }
}

Write-Host ""
Write-Host "=== 電子書籍 自動キャプチャ（めくり方式: $Mode）==="
Write-Host "保存先: $Out"
Write-Host ""
Write-Host "これから7秒後に開始します。今すぐ:"
Write-Host "  1) 本の画面をクリックして最前面にする（拡張モニターの本でもOK）"
Write-Host "  2) できれば全画面表示(ブラウザはF11)・先頭ページにする"
Write-Host "  3) あとは触らずに待つ"
for ($s = 7; $s -ge 1; $s--) { Write-Host "  開始まで $s ..." ; Start-Sleep -Seconds 1 }

# --- 撮影対象の画面を決定 ---
$screens = [System.Windows.Forms.Screen]::AllScreens
$bookHwnd = [Win]::GetForegroundWindow()
if ($Monitor -ge 1 -and $Monitor -le $screens.Count) {
    $target = $screens[$Monitor - 1]
    Write-Host "画面 #$Monitor を撮影します。"
} else {
    $target = [System.Windows.Forms.Screen]::FromHandle($bookHwnd)
    Write-Host "最前面の本ウィンドウがある画面を自動選択しました。"
}
$bounds = $target.Bounds
$clickPX = [int]($bounds.X + $bounds.Width  * $ClickX)
$clickPY = [int]($bounds.Y + $bounds.Height * $ClickY)
$parkX   = [int]($bounds.X + 3)
$parkY   = [int]($bounds.Y + 3)
Write-Host ("撮影範囲: X=$($bounds.X) Y=$($bounds.Y) W=$($bounds.Width) H=$($bounds.Height)")
if ($Mode -eq "click") { Write-Host ("めくりクリック位置: ($clickPX, $clickPY)") }
Write-Host ""

$md5 = [System.Security.Cryptography.MD5]::Create()
function Get-ScreenHash {
    param($bmp)
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $h = [System.BitConverter]::ToString($md5.ComputeHash($ms.ToArray()))
    $ms.Dispose(); return $h
}
function Turn-Page {
    if ($Mode -eq "click") {
        [Win]::Click($clickPX, $clickPY)
        Start-Sleep -Milliseconds 120
        [Win]::SetCursorPos($parkX, $parkY) | Out-Null   # カーソルを隅に退避
    } else {
        [Win]::SetForegroundWindow($bookHwnd) | Out-Null
        Start-Sleep -Milliseconds 80
        [System.Windows.Forms.SendKeys]::SendWait($Key)
    }
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

    Turn-Page
    Start-Sleep -Seconds $Delay
    Write-Host -NoNewline ("`r取得: {0} ページ（同一検知 {1}/{2}）" -f $saved, $sameCount, $StopAfterSame)
}

Write-Host ""
Write-Host ""
Write-Host "完了しました。$Out に $saved 枚を保存しました。"
Write-Host ""
if ($saved -le 2) {
    Write-Host "【注意】保存が $saved 枚しかありません。ページがめくれていない可能性があります。"
    Write-Host "  対処: 本の画面を最前面にしてから、めくり方式を切り替えて再実行してください。"
    Write-Host "  例(→キーでめくる): powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode key"
    Write-Host ""
}
Write-Host "次にやること:"
Write-Host "  1) 開いたフォルダの中身が『本のページ』になっているか確認"
Write-Host "  2) フォルダを右クリック →「ZIPに圧縮」"
Write-Host "  3) そのZIPをClaudeのチャットにアップロード（OCR→PDFはClaude側で仕上げ）"
Start-Sleep -Seconds 1
try { Invoke-Item $Out } catch {}
