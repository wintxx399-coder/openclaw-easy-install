$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

$ff = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ff) {
  $candidate = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\ffmpeg.exe'
  if (Test-Path $candidate) { $ff = $candidate }
}
if (-not $ff) { Write-Host "ffmpeg not found. Install it first: winget install Gyan.FFmpeg"; Read-Host "Press Enter"; exit 1 }

$wizard = (Resolve-Path (Join-Path $PSScriptRoot '..\windows\Install-OpenClaw.ps1')).Path
$out = Join-Path $PSScriptRoot 'demo-raw.mp4'
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

Write-Host "== OpenClaw demo recorder ==" -ForegroundColor Cyan
Write-Host "1) The wizard will open in a few seconds."
Write-Host "2) Click [Start] (the orange button), let it run a few seconds."
Write-Host "3) Close the wizard to stop recording."
Write-Host ""

$p = Start-Process powershell -ArgumentList '-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$wizard -PassThru
Start-Sleep -Seconds 2

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ff
$psi.Arguments = "-y -f gdigrab -framerate 10 -offset_x $($screen.X) -offset_y $($screen.Y) -video_size $($screen.Width)x$($screen.Height) -i desktop -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p `"$out`""
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardInput = $true
$psi.RedirectStandardError = $true
$rec = [System.Diagnostics.Process]::Start($psi)

Write-Host "Recording... (you can click Start now)" -ForegroundColor Green
[void]$p.WaitForExit(300000)
Start-Sleep -Seconds 1
try { $rec.StandardInput.WriteLine('q'); $rec.StandardInput.Flush() } catch {}
[void]$rec.WaitForExit(20000)
if (-not $rec.HasExited) { $rec.Kill() }

if (Test-Path $out) {
  $mb = [math]::Round((Get-Item $out).Length / 1MB, 2)
  Write-Host "Saved: $out ($mb MB)" -ForegroundColor Green
  Write-Host "Tell the agent it is ready - it will convert this to GIF and add it to the README."
} else {
  Write-Host "Recording failed: no output file." -ForegroundColor Red
}
Read-Host "Press Enter to close"
