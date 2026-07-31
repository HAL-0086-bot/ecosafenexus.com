# capture_kindle.ps1 — 画面に表示中の電子書籍を、自動でページ送りしながら
# 連続スクリーンショットする（Kindle for PC / ブラウザのKindleクラウドリーダー対応）。
#
# 特長:
#   - 全自動でページ送り＋撮影（手作業ゼロ）
#   - ★ いつでも ESC キーで即停止（このウィンドウがアクティブでなくてもOK）
#   - マルチモニター対応: カウント終了時に「最前面にした本のウィンドウがある画面」を自動選択
#   - ページ送りは既定で「本の右側をクリック」。-Rtl で左（縦書き・右綴じ日本語書籍）
#   - ★ 終端判定はゆるい類似比較（カーソルやチラつきの差は無視）→ 本の最後で確実に自動停止
#   - 保存先は既定で「ピクチャ\kindle_pages」
#
# 使い方:
#   ・付属ランチャーをダブルクリック（START_capture.cmd / 縦書きは START_capture_JP_tategaki.cmd）
#   ・または PowerShell で:
#       powershell -ExecutionPolicy Bypass -File .\capture_kindle.ps1          # 横書き/左綴じ
#       powershell -ExecutionPolicy Bypass -File .\capture_kindle.ps1 -Rtl     # 縦書き/右綴じ
#
# 事前に: 本を1ページ表示・先頭・できれば全画面(ブラウザF11)。開始カウント中に本の画面をクリック。
# 止め方: ESC キー。または このウィンドウで Ctrl+C。

param(
    [string]$Out = "$env:USERPROFILE\Pictures\kindle_pages",
    [int]$Max = 3000,
    [double]$Delay = 1.4,
    [int]$StopAfterSame = 3,
    [double]$Threshold = 3.0,     # 「同じページ」とみなす平均画素差のしきい値（大きいほど鈍感）
    [ValidateSet("click","key")][string]$Mode = "click",
    [string]$Key = "{RIGHT}",
    [double]$ClickX = 0.94,
    [double]$ClickY = 0.5,
    [switch]$Rtl,                 # 縦書き・右綴じ（次ページが左）
    [int]$Monitor = 0
)

if ($Rtl) { $ClickX = 0.06; $Key = "{LEFT}" }

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
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
    public const uint LEFTDOWN = 0x0002;
    public const uint LEFTUP   = 0x0004;
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(40);
        mouse_event(LEFTDOWN, 0, 0, 0, IntPtr.Zero);
        mouse_event(LEFTUP,   0, 0, 0, IntPtr.Zero);
    }
    public static bool EscPressed() { return (GetAsyncKeyState(0x1B) & 0x8000) != 0; } // VK_ESCAPE
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

$dir = if ($Rtl) { "左クリック=次ページ（縦書き・右綴じ）" } else { "右クリック=次ページ（横書き・左綴じ）" }
Write-Host ""
Write-Host "=== 電子書籍 自動キャプチャ（$Mode / $dir）==="
Write-Host "保存先: $Out"
Write-Host "★ 止めたいときは ESC キー（いつでも即停止）"
Write-Host ""
Write-Host "7秒後に開始します。今すぐ本の画面をクリックして最前面にし、全画面(F11)にしてください。"
for ($s = 7; $s -ge 1; $s--) {
    if ([Win]::EscPressed()) { Write-Host "`nESCで中止しました。"; exit }
    Write-Host "  開始まで $s ..." ; Start-Sleep -Seconds 1
}

$screens = [System.Windows.Forms.Screen]::AllScreens
$bookHwnd = [Win]::GetForegroundWindow()
if ($Monitor -ge 1 -and $Monitor -le $screens.Count) {
    $target = $screens[$Monitor - 1]; Write-Host "画面 #$Monitor を撮影します。"
} else {
    $target = [System.Windows.Forms.Screen]::FromHandle($bookHwnd)
    Write-Host "最前面の本ウィンドウがある画面を自動選択しました。"
}
$bounds = $target.Bounds
$clickPX = [int]($bounds.X + $bounds.Width  * $ClickX)
$clickPY = [int]($bounds.Y + $bounds.Height * $ClickY)
$parkX   = [int]($bounds.X + 3); $parkY = [int]($bounds.Y + 3)
Write-Host ("撮影範囲: X=$($bounds.X) Y=$($bounds.Y) W=$($bounds.Width) H=$($bounds.Height)")
Write-Host ""

# --- 縮小グレースケール署名（32x32）で「ほぼ同じ画面」を判定 ---
$SigSize = 32
function Get-Signature {
    param($srcBmp)
    $small = $null; $g = $null
    try {
        $small = New-Object System.Drawing.Bitmap $SigSize, $SigSize
        $g = [System.Drawing.Graphics]::FromImage($small)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
        $g.DrawImage($srcBmp, 0, 0, $SigSize, $SigSize)
        $sig = New-Object 'byte[]' ($SigSize * $SigSize)
        $k = 0
        for ($y = 0; $y -lt $SigSize; $y++) {
            for ($x = 0; $x -lt $SigSize; $x++) {
                $p = $small.GetPixel($x, $y)
                $sig[$k] = [byte](($p.R * 0.3) + ($p.G * 0.59) + ($p.B * 0.11)); $k++
            }
        }
        return ,$sig
    } catch {
        return $null
    } finally {
        if ($g)     { $g.Dispose() }
        if ($small) { $small.Dispose() }
    }
}
function Sig-Diff {
    # 署名が取れなかったとき（$null）は「別のページ」とみなして撮影を続ける
    param($a, $b)
    if ($null -eq $a -or $null -eq $b -or $a.Length -eq 0 -or $a.Length -ne $b.Length) { return 999 }
    $sum = 0.0
    for ($i = 0; $i -lt $a.Length; $i++) { $sum += [math]::Abs([int]$a[$i] - [int]$b[$i]) }
    return $sum / $a.Length
}
function Turn-Page {
    if ($Mode -eq "click") {
        [Win]::Click($clickPX, $clickPY); Start-Sleep -Milliseconds 120
        [Win]::SetCursorPos($parkX, $parkY) | Out-Null
    } else {
        [Win]::SetForegroundWindow($bookHwnd) | Out-Null; Start-Sleep -Milliseconds 80
        [System.Windows.Forms.SendKeys]::SendWait($Key)
    }
}

$prevSig = $null; $sameCount = 0; $saved = 0; $stopped = ""

for ($i = 1; $i -le $Max; $i++) {
    if ([Win]::EscPressed()) { $stopped = "ESCキーで停止しました。"; break }

    $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $sig = Get-Signature $bmp
    $diff = Sig-Diff $prevSig $sig

    if ($diff -lt $Threshold) {
        $sameCount++
        if ($sameCount -ge $StopAfterSame) {
            $gfx.Dispose(); $bmp.Dispose()
            $stopped = "同じ画面が $StopAfterSame 回続いたので、本の終端と判断して自動停止しました。"
            break
        }
    } else {
        $sameCount = 0
        $name = "page_{0:D5}.png" -f $saved
        $bmp.Save((Join-Path $Out $name), [System.Drawing.Imaging.ImageFormat]::Png)
        $saved++
        if ($null -ne $sig) { $prevSig = $sig }
    }
    $gfx.Dispose(); $bmp.Dispose()

    Turn-Page
    Start-Sleep -Seconds $Delay
    Write-Host -NoNewline ("`r取得: {0} ページ（同一検知 {1}/{2}）  ※止めるにはESC" -f $saved, $sameCount, $StopAfterSame)
}

Write-Host ""
Write-Host ""
if ($stopped) { Write-Host $stopped }
Write-Host "$Out に $saved 枚を保存しました。"
Write-Host ""
if ($saved -le 2) {
    Write-Host "【注意】$saved 枚しか撮れていません。ページがめくれていない可能性があります。"
    Write-Host "  縦書き・右綴じ本: powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Rtl"
    Write-Host ""
}
Write-Host "次にやること: フォルダを右クリック→「ZIPに圧縮」→ ClaudeのチャットにアップロードでOCR→PDF化。"
Start-Sleep -Seconds 1
try { Invoke-Item $Out } catch {}
