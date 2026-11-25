Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ================= 可修改配置 =================
$StoreId        = ''     # 微软商店产品 ID,留空=直接官方下载/镜像
$Base           = 'https://github.com/openclaw/openclaw-windows-node/releases/latest/download'
$Mirrors        = @('https://gh-proxy.com/', 'https://ghfast.top/')
$MinNode        = 22
$InstallGateway = $true
# ==============================================

$Arch    = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$AppFile = "OpenClawCompanion-Setup-$Arch.exe"
$SumFile = 'promotion.json'
$Work    = Join-Path $env:TEMP 'OpenClawInstaller'
$LogPath = Join-Path $Work 'install.log'
New-Item -ItemType Directory -Force $Work | Out-Null
$script:Tasks = @(
  @{ n = '系统环境检查'; s = 'wait'; p = 0; t = '等待中' }, @{ n = 'Git'; s = 'wait'; p = 0; t = '等待中' },
  @{ n = 'Node.js'; s = 'wait'; p = 0; t = '等待中' }, @{ n = 'WebView2 运行库'; s = 'wait'; p = 0; t = '等待中' },
  @{ n = 'Gateway 网关'; s = 'wait'; p = 0; t = '等待中' }, @{ n = 'OpenClaw 桌面版'; s = 'wait'; p = 0; t = '等待中' },
  @{ n = '接入 API(可选)'; s = 'wait'; p = 0; t = '等待中' })
$script:cur = -1; $script:ph = 0; $script:overall = 0; $script:warn = 0
$script:warnList = New-Object System.Collections.Generic.List[string]

# ---------- 配色 / 字体 ----------
function C($r, $g, $b) { [Drawing.Color]::FromArgb($r, $g, $b) }
$cBg = C 22 24 31; $cCard = C 32 35 45; $cTrack = C 52 56 70; $cAcc = C 255 107 74; $cOk = C 74 200 140
$cBad = C 235 80 90; $cDim = C 130 136 155; $cTxt = C 235 238 245; $cWarn = C 250 200 90
$fTitle = New-Object Drawing.Font('Segoe UI', 15, [Drawing.FontStyle]::Bold)
$fBold = New-Object Drawing.Font('Segoe UI Semibold', 10.5); $fSmall = New-Object Drawing.Font('Segoe UI', 9)
$fHuge = New-Object Drawing.Font('Segoe UI', 24, [Drawing.FontStyle]::Bold)
function DB($c) { $c.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($c, $true, $null) }
function Lb($txt, $x, $y, $w, $h, $font, $col) {
  $l = New-Object Windows.Forms.Label; $l.Text = $txt; $l.Location = "$x,$y"; $l.Size = "$w,$h"; $l.Font = $font; $l.ForeColor = $col; $l.BackColor = $cBg; $f.Controls.Add($l); $l
}
function Btn($txt, $x) {
  $b = New-Object Windows.Forms.Button; $b.Text = $txt; $b.Location = "$x,620"; $b.Size = '120,36'; $b.FlatStyle = 'Flat'
  $b.FlatAppearance.BorderColor = $cTrack; $b.BackColor = $cCard; $b.ForeColor = $cTxt; $b.Font = $fSmall; $f.Controls.Add($b); $b
}

# ---------- 窗口 ----------
$f = New-Object Windows.Forms.Form; $f.Text = 'OpenClaw 桌面版安装向导'; $f.ClientSize = '664,672'; $f.BackColor = $cBg
$f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedSingle'; $f.MaximizeBox = $false; DB $f
[void](Lb 'OpenClaw 桌面版' 24 14 400 34 $fTitle $cTxt)
[void](Lb '自动检查环境 · 安装组件 · 实时显示进度' 26 46 500 20 $fSmall $cDim)
$ring = New-Object Windows.Forms.Panel; $ring.Location = '24,78'; $ring.Size = '160,160'; $ring.BackColor = $cBg; DB $ring; $f.Controls.Add($ring)
$head = Lb '准备就绪' 204 100 440 34 $fTitle $cTxt
$sub = Lb '正在准备…' 206 142 440 70 $fSmall $cDim
$list = New-Object Windows.Forms.Panel; $list.Location = '24,254'; $list.Size = '616,336'; $list.BackColor = $cCard; DB $list; $f.Controls.Add($list)
$go = Btn '开始安装' 24; $lg = Btn '打开日志' 156; $giBtn = Btn '网关信息' 288; $cl = Btn '关闭' 520
$go.BackColor = $cAcc; $go.FlatAppearance.BorderColor = $cAcc; $go.ForeColor = 'White'
$cl.Add_Click({ $f.Close() }); $lg.Add_Click({ if (Test-Path $LogPath) { Start-Process notepad.exe $LogPath } })
$giBtn.Add_Click({ Show-GatewayInfo })

$ring.Add_Paint({ param($s, $e)
  $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
  $r = New-Object Drawing.Rectangle 14, 14, 132, 132
  $p1 = New-Object Drawing.Pen $cTrack, 14; $g.DrawEllipse($p1, $r)
  if ($script:overall -gt 0) {
    $p2 = New-Object Drawing.Pen $cAcc, 14; $p2.StartCap = 'Round'; $p2.EndCap = 'Round'
    $g.DrawArc($p2, $r, -90, [single]([math]::Min(359.9, 3.6 * $script:overall)))
  }
  $fmt = New-Object Drawing.StringFormat; $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
  $g.DrawString(("{0}%" -f [int]$script:overall), $fHuge, (New-Object Drawing.SolidBrush $cTxt), (New-Object Drawing.RectangleF 0, 0, 160, 160), $fmt)
})
$list.Add_Paint({ param($s, $e)
  $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
  $paneW = 616; $bw = $paneW - 56 - 70
  for ($i = 0; $i -lt $script:Tasks.Count; $i++) {
    $x = $script:Tasks[$i]; $y = 8 + $i * 46
    $col = switch ($x.s) { 'ok' { $cOk } 'skip' { $cOk } 'warn' { $cWarn } 'bad' { $cBad } 'run' { $cAcc } default { $cDim } }
    $gl = switch ($x.s) { 'ok' { '✔' } 'skip' { '✔' } 'warn' { '!' } 'bad' { '✘' } 'run' { '●' } default { '○' } }
    $g.DrawString($gl, $fBold, (New-Object Drawing.SolidBrush $col), 14, $y)
    $g.DrawString($x.n, $fBold, (New-Object Drawing.SolidBrush $cTxt), 40, $y)
    $fmt = New-Object Drawing.StringFormat; $fmt.Alignment = 'Far'
    $g.DrawString($x.t, $fSmall, (New-Object Drawing.SolidBrush $col), (New-Object Drawing.RectangleF 200, ($y + 2), ($paneW - 214), 20), $fmt)
    $g.FillRectangle((New-Object Drawing.SolidBrush $cTrack), 40, ($y + 26), $bw, 7)
    if ($x.p -ge 0) {
      $g.FillRectangle((New-Object Drawing.SolidBrush $col), 40, ($y + 26), [int]($bw * $x.p / 100), 7)
      $g.DrawString("$([int]$x.p)%", $fSmall, (New-Object Drawing.SolidBrush $cDim), ($paneW - 62), ($y + 20))
    } else {
      $x0 = [int](($script:ph / 100) * ($bw + 110)) - 110; $a = [math]::Max(0, $x0); $b = [math]::Min($bw, $x0 + 110)
      if ($b -gt $a) { $g.FillRectangle((New-Object Drawing.SolidBrush $col), (40 + $a), ($y + 26), ($b - $a), 7) }
    }
  }
})
$tm = New-Object Windows.Forms.Timer; $tm.Interval = 60
$tm.Add_Tick({ $script:ph = ($script:ph + 3) % 100; if ($script:cur -ge 0 -and $script:Tasks[$script:cur].s -eq 'run' -and $script:Tasks[$script:cur].p -lt 0) { $list.Invalidate() } })
$tm.Start()

# ---------- 工具函数 ----------
function Pump { [Windows.Forms.Application]::DoEvents() }
function Log($m) { Add-Content -Path $LogPath -Value "[$(Get-Date -f HH:mm:ss)] $m" -Encoding UTF8; $sub.Text = $m; Pump }
function T($i, $state, $pct, $txt) {
  $x = $script:Tasks[$i]; $x.s = $state
  if ($null -ne $pct) { $x.p = $pct }
  if ($txt) { $x.t = $txt }
  if ($state -eq 'run') { $script:cur = $i; $head.Text = "正在处理:$($x.n)" }
  $sum = 0; foreach ($k in $script:Tasks) { $sum += $(if ($k.s -in 'ok', 'skip', 'warn') { 100 } else { [math]::Max(0, $k.p) }) }
  $script:overall = $sum / $script:Tasks.Count
  $list.Invalidate(); $ring.Invalidate(); Pump
}
function Refresh-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }
function Has-Git { [bool](Get-Command git -ErrorAction SilentlyContinue) }
function Has-Node {
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) { return $false }
  try { [int](((node -v) -replace 'v', '').Split('.')[0]) -ge $MinNode } catch { $false }
}
function Has-WebView2 {
  foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}') {
    $v = (Get-ItemProperty $k -ErrorAction SilentlyContinue).pv; if ($v -and $v -ne '0.0.0.0') { return $true }
  }
  $false
}
function Run-Proc($exe, $arg, $i, $label) {
  $o = Join-Path $Work "out$i.txt"; Remove-Item $o -ErrorAction SilentlyContinue
  $p = Start-Process $exe -ArgumentList $arg -PassThru -WindowStyle Hidden -RedirectStandardOutput $o
  $n = 0
  while (-not $p.HasExited) {
    Start-Sleep -Milliseconds 80; $n++
    if ($n % 4 -eq 0) {
      $pct = -1
      try { $last = Get-Content $o -Tail 1 -ErrorAction Stop; if ($last -match '(\d{1,3})\s*%') { $pct = [math]::Min(99, [int]$Matches[1]) } } catch {}
      T $i 'run' $pct $(if ($pct -ge 0) { "$label $pct%" } else { "$label ..." })
    } else { Pump }
  }
  $p.ExitCode
}
function Winget-Install($id, $i, $name) {
  $code = Run-Proc 'winget' "install -e --id $id --silent --accept-package-agreements --accept-source-agreements" $i "正在下载安装 $name"
  if ($code -eq -1978335189) { Refresh-Path; return }
  if ($code -ne 0) {
    Log "[$name] winget 退出码 $code,尝试更新 winget 源后重试"
    [void](Run-Proc 'winget' 'source update' $i "更新 winget 源")
    $code = Run-Proc 'winget' "install -e --id $id --silent --accept-package-agreements --accept-source-agreements" $i "重试安装 $name"
    if ($code -eq -1978335189) { Refresh-Path; return }
    if ($code -ne 0) { throw "winget 退出码 $code" }
  }
  Refresh-Path
}
function Get-File($url, $out, $i, $label, $lo, $hi) {
  $req = [Net.HttpWebRequest]::Create($url); $req.Timeout = 15000; $req.UserAgent = 'OpenClawInstaller'
  $res = $req.GetResponse(); $len = $res.ContentLength; $in = $res.GetResponseStream(); $in.ReadTimeout = 15000
  $fst = [IO.File]::Create($out); $buf = New-Object byte[] 81920; $got = 0; $last = -1; $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
      $fst.Write($buf, 0, $n); $got += $n
      if ($len -gt 0) {
        $pc = [int](100 * $got / $len)
        if ($pc -ne $last) {
          $last = $pc; $spd = $got / 1MB / [math]::Max(0.1, $sw.Elapsed.TotalSeconds)
          T $i 'run' ($lo + ($hi - $lo) * $pc / 100) ('{0} {1}% · {2:N1}/{3:N1} MB · {4:N1} MB/s' -f $label, $pc, ($got / 1MB), ($len / 1MB), $spd)
        }
      } else { Pump }
    }
  } finally { $fst.Close(); $in.Close(); $res.Close() }
}
function Fail($msg) {
  $name = if ($script:cur -ge 0) { $script:Tasks[$script:cur].n } else { '启动' }
  if ($script:cur -ge 0) { $x = $script:Tasks[$script:cur]; $x.s = 'bad'; $x.t = '失败'; if ($x.p -lt 0) { $x.p = 0 } }
  Log "失败 @ [$name]: $msg"; $head.Text = "已停止:$name"; $head.ForeColor = $cBad; $list.Invalidate()
  [Windows.Forms.MessageBox]::Show("安装停在:$name`r`n`r`n原因:$msg`r`n`r`n日志:$LogPath", '安装失败', 'OK', 'Error') | Out-Null
  $go.Text = '重试'; $go.Enabled = $true
}
function Warn-Item($i, $name, $why) {
  $script:warn++
  $script:warnList.Add("$name : $why")
  Log "[跳过] $name -> $why"
  T $i 'warn' 100 '已跳过(不影响使用)'
}

# ---------- API 接入(可选) ----------
function Ask-Api {
  $d = New-Object Windows.Forms.Form; $d.Text = '接入 API'; $d.ClientSize = '440,310'; $d.StartPosition = 'CenterParent'
  $d.FormBorderStyle = 'FixedDialog'; $d.MaximizeBox = $false; $d.MinimizeBox = $false; $d.BackColor = $cBg
  function L($t, $y, $h) { $l = New-Object Windows.Forms.Label; $l.Text = $t; $l.Location = "20,$y"; $l.Size = "400,$h"; $l.ForeColor = $cTxt; $l.Font = $fSmall; $d.Controls.Add($l) }
  L '选择要接入的模型服务:' 16 20
  $cb = New-Object Windows.Forms.ComboBox; $cb.DropDownStyle = 'DropDownList'; $cb.Location = '20,40'; $cb.Size = '400,26'
  [void]$cb.Items.AddRange(@('DeepSeek', 'Anthropic (Claude)', '跳过,稍后手动配置')); $cb.SelectedIndex = 0; $d.Controls.Add($cb)
  L '粘贴 API Key(输入时不显示明文):' 82 20
  $tb = New-Object Windows.Forms.TextBox; $tb.UseSystemPasswordChar = $true; $tb.Location = '20,106'; $tb.Size = '400,26'; $d.Controls.Add($tb)
  $ck = New-Object Windows.Forms.CheckBox; $ck.Text = '我了解 OpenClaw 可在本机执行操作,并同意继续'; $ck.Location = '20,150'; $ck.Size = '400,24'
  $ck.ForeColor = $cTxt; $ck.Font = $fSmall; $d.Controls.Add($ck)
  L 'Key 会保存在本机的 OpenClaw 配置里,请勿发给别人。' 186 40
  $ok = New-Object Windows.Forms.Button; $ok.Text = '确定'; $ok.Location = '20,250'; $ok.Size = '120,36'; $d.Controls.Add($ok)
  $no = New-Object Windows.Forms.Button; $no.Text = '稍后再说'; $no.Location = '300,250'; $no.Size = '120,36'; $no.DialogResult = 'Cancel'; $d.Controls.Add($no)
  $ok.Add_Click({
    if ($cb.SelectedIndex -eq 2) { $d.DialogResult = 'OK'; return }
    if (-not $tb.Text.Trim()) { [void][Windows.Forms.MessageBox]::Show('请粘贴 API Key'); return }
    if (-not $ck.Checked) { [void][Windows.Forms.MessageBox]::Show('请先勾选确认'); return }
    $d.DialogResult = 'OK' })
  if ($d.ShowDialog($f) -ne 'OK' -or $cb.SelectedIndex -eq 2) { return $null }
  @{ id = $(if ($cb.SelectedIndex -eq 0) { 'deepseek' } else { 'anthropic' }); key = $tb.Text.Trim() }
}
function Setup-Api {
  $script:cur = 6; T 6 'run' -1 '等待选择'
  $r = Ask-Api
  if (-not $r) { T 6 'skip' 100 '已跳过,可稍后运行 openclaw onboard'; return }
  try {
    $env:OC_KEY = $r.key; Refresh-Path
    if (-not (Get-Command openclaw -ErrorAction SilentlyContinue)) { throw '未找到 openclaw 命令,请先在桌面版里完成本地设置' }
    if ($r.id -eq 'deepseek') {
      [void](Run-Proc 'powershell' '-NoProfile -Command "openclaw plugins install @openclaw/deepseek-provider"' 6 '安装 DeepSeek 插件')
      $flag = '--auth-choice deepseek-api-key --deepseek-api-key $env:OC_KEY'
    } else { $flag = '--auth-choice apiKey --anthropic-api-key $env:OC_KEY' }
    $c = Run-Proc 'powershell' ('-NoProfile -Command "openclaw onboard --non-interactive --mode local ' + $flag + ' --skip-health --accept-risk"') 6 '正在写入配置'
    if ($c -ne 0) { throw "onboard 退出码 $c" }
    $c = Run-Proc 'powershell' ('-NoProfile -Command "openclaw models list --provider ' + $r.id + '"') 6 '正在验证模型'
    if ($c -ne 0) { throw "验证退出码 $c" }
    T 6 'ok' 100 '已接入'
  } catch {
    Log "API 接入未完成: $($_.Exception.Message)"
    Warn-Item 6 '接入 API' '可在桌面版或命令行稍后配置'
    [void][Windows.Forms.MessageBox]::Show("API 接入未完成:$($_.Exception.Message)`r`n`r`n可稍后运行:openclaw onboard", 'API 接入', 'OK', 'Warning')
  } finally { Remove-Item Env:\OC_KEY -ErrorAction SilentlyContinue }
}

# ---------- 网关信息 / 连接教程 ----------
function Get-GatewayInfo {
  $cfg = Join-Path (Join-Path $env:USERPROFILE '.openclaw') 'openclaw.json'
  $port = 18789; $bind = 'lan'; $mode = 'local'; $authMode = ''; $token = ''
  if (Test-Path $cfg) {
    try {
      $j = Get-Content $cfg -Raw -ErrorAction Stop | ConvertFrom-Json
      if ($j.gateway.port) { $port = [int]$j.gateway.port }
      if ($j.gateway.bind) { $bind = [string]$j.gateway.bind }
      if ($j.gateway.mode) { $mode = [string]$j.gateway.mode }
      if ($j.gateway.auth) { $authMode = [string]$j.gateway.auth.mode; $token = [string]$j.gateway.auth.token }
    } catch {}
  }
  $listening = $false
  try { $listening = ((Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop | Measure-Object).Count -gt 0) } catch {}
  $lanIp = ''
  try { $lanIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.AddressState -eq 'Preferred' } | Sort-Object InterfaceMetric | Select-Object -First 1).IPAddress } catch {}
  $localUrl = 'http://127.0.0.1:' + $port
  $lanUrl = ''
  if ($lanIp -and $bind -eq 'lan') { $lanUrl = 'http://' + $lanIp + ':' + $port }
  @{ port = $port; bind = $bind; mode = $mode; authMode = $authMode; token = $token; listening = $listening; localUrl = $localUrl; lanUrl = $lanUrl; lanIp = $lanIp }
}
function Show-GatewayInfo {
  $info = Get-GatewayInfo
  $gv = New-Object Windows.Forms.Form
  $gv.Text = 'OpenClaw 网关信息 · 连接教程'
  $gv.ClientSize = '600,660'
  $gv.StartPosition = 'CenterParent'
  $gv.FormBorderStyle = 'FixedDialog'
  $gv.MaximizeBox = $false; $gv.MinimizeBox = $false
  $gv.BackColor = $cBg
  function GL($t,$x,$y,$w,$h,$font,$col){ $l=New-Object Windows.Forms.Label; $l.Text=$t; $l.Location="$x,$y"; $l.Size="$w,$h"; $l.Font=$font; $l.ForeColor=$col; $l.BackColor=$cBg; $gv.Controls.Add($l); $l }
  [void](GL 'OpenClaw 网关信息' 20 16 560 30 $fTitle $cTxt)
  $statusText = if ($info.listening) { '网关正在运行 (端口 ' + $info.port + ' 已监听)' } else { '未检测到网关监听 (端口 ' + $info.port + ')' }
  $scol = if ($info.listening) { $cOk } else { $cBad }
  $stLabel = GL ('状态: ' + $statusText) 20 40 560 20 $fBold $scol
  [void](GL '网关地址 (本机)' 20 78 260 18 $fBold $cTxt)
  $tbAddr = New-Object Windows.Forms.TextBox; $tbAddr.Text = $info.localUrl; $tbAddr.ReadOnly = $true; $tbAddr.Location = '20,98'; $tbAddr.Size = '440,26'; $tbAddr.BackColor = $cCard; $tbAddr.ForeColor = $cTxt; $gv.Controls.Add($tbAddr)
  $bca = New-Object Windows.Forms.Button; $bca.Text = '复制'; $bca.Location = '468,98'; $bca.Size = '110,26'; $bca.FlatStyle = 'Flat'; $bca.BackColor = $cCard; $bca.ForeColor = $cTxt; $gv.Controls.Add($bca)
  $bca.Add_Click({ [Windows.Forms.Clipboard]::SetText($tbAddr.Text); $stLabel.Text = '状态: 已复制本机地址' })
  if ($info.lanUrl) {
    [void](GL '网关地址 (局域网, 手机或其它设备用)' 20 134 340 18 $fBold $cTxt)
    $tbLan = New-Object Windows.Forms.TextBox; $tbLan.Text = $info.lanUrl; $tbLan.ReadOnly = $true; $tbLan.Location = '20,154'; $tbLan.Size = '440,26'; $tbLan.BackColor = $cCard; $tbLan.ForeColor = $cTxt; $gv.Controls.Add($tbLan)
    $bcl = New-Object Windows.Forms.Button; $bcl.Text = '复制'; $bcl.Location = '468,154'; $bcl.Size = '110,26'; $bcl.FlatStyle = 'Flat'; $bcl.BackColor = $cCard; $bcl.ForeColor = $cTxt; $gv.Controls.Add($bcl)
    $bcl.Add_Click({ [Windows.Forms.Clipboard]::SetText($tbLan.Text); $stLabel.Text = '状态: 已复制局域网地址' })
  }
  [void](GL ('共享 Token (认证方式: ' + $info.authMode + ')') 20 190 400 18 $fBold $cTxt)
  $tbTok = New-Object Windows.Forms.TextBox; $tbTok.Text = $info.token; $tbTok.UseSystemPasswordChar = $true; $tbTok.ReadOnly = $true; $tbTok.Location = '20,210'; $tbTok.Size = '440,26'; $tbTok.BackColor = $cCard; $tbTok.ForeColor = $cTxt; $gv.Controls.Add($tbTok)
  $bct = New-Object Windows.Forms.Button; $bct.Text = '复制'; $bct.Location = '468,210'; $bct.Size = '110,26'; $bct.FlatStyle = 'Flat'; $bct.BackColor = $cCard; $bct.ForeColor = $cTxt; $gv.Controls.Add($bct)
  $bct.Add_Click({ [Windows.Forms.Clipboard]::SetText($tbTok.Text); $stLabel.Text = '状态: 已复制 Token' })
  $cbShow = New-Object Windows.Forms.CheckBox; $cbShow.Text = '显示 Token'; $cbShow.Location = '20,242'; $cbShow.Size = '120,20'; $cbShow.ForeColor = $cDim; $cbShow.Font = $fSmall; $gv.Controls.Add($cbShow)
  $cbShow.Add_Click({ $tbTok.UseSystemPasswordChar = -not $cbShow.Checked })
  $tut = '连接教程:' + [Environment]::NewLine +
    '1. 打开 OpenClaw Companion, 进入「连接网关 / Connect Gateway」。' + [Environment]::NewLine +
    '2. 网关地址填上面「网关地址 (本机)」那一栏。' + [Environment]::NewLine +
    '3. 共享 Token 填上面的值 (勾选「显示 Token」查看, 或点「复制」)。' + [Environment]::NewLine +
    '4. 若提示端口被占用: 桌面版与已装的 CLI 网关都使用端口 ' + $info.port + ',' + [Environment]::NewLine +
    '   需要先停止旧网关 (在 PowerShell 运行 openclaw gateway stop), 再让桌面版接管。' + [Environment]::NewLine +
    '5. 手机或其它设备连接时填「局域网地址」, 并确保同一网络且防火墙放行 ' + $info.port + ' 端口。'
  $tbTut = New-Object Windows.Forms.TextBox; $tbTut.Multiline = $true; $tbTut.ReadOnly = $true; $tbTut.WordWrap = $true; $tbTut.ScrollBars = 'Vertical'; $tbTut.Location = '20,276'; $tbTut.Size = '560,320'; $tbTut.Text = $tut; $tbTut.BackColor = $cCard; $tbTut.ForeColor = $cTxt; $tbTut.Font = $fSmall; $gv.Controls.Add($tbTut)
  $bclose = New-Object Windows.Forms.Button; $bclose.Text = '关闭'; $bclose.Location = '20,612'; $bclose.Size = '120,36'; $bclose.FlatStyle = 'Flat'; $bclose.BackColor = $cAcc; $bclose.ForeColor = 'White'; $gv.Controls.Add($bclose)
  $bclose.Add_Click({ $gv.Close() })
  [void]$gv.ShowDialog($f)
}

# ---------- 主流程 ----------
function Run-Install {
  $go.Enabled = $false; $head.ForeColor = $cTxt; $script:cur = -1; $script:warn = 0; $script:warnList.Clear()
  foreach ($k in $script:Tasks) { $k.s = 'wait'; $k.p = 0; $k.t = '等待中' }
  try {
    T 0 'run' -1 '正在检查'
    $build = [Environment]::OSVersion.Version.Build; Log "系统 build $build / $Arch"
    if ($build -lt 19042) { throw '需要 Windows 10 20H2 或更高版本' }
    $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    $items = @(@{ i = 1; n = 'Git'; id = 'Git.Git'; has = { Has-Git } }, @{ i = 2; n = "Node.js (v$MinNode+)"; id = 'OpenJS.NodeJS.LTS'; has = { Has-Node } },
      @{ i = 3; n = 'WebView2'; id = 'Microsoft.EdgeWebView2Runtime'; has = { Has-WebView2 } })
    $missing = @()
    foreach ($it in $items) { if (& $it.has) { T $it.i 'skip' 100 '已安装,跳过' } else { $missing += $it } }
    T 0 'ok' 100 ('缺少 ' + $missing.Count + ' 项组件')

    # 组件安装: 全部非致命, 失败只跳过
    foreach ($it in $missing) {
      $script:cur = $it.i
      if (-not $hasWinget) { Warn-Item $it.i $it.n '系统没有 winget,可手动安装'; continue }
      try {
        T $it.i 'run' -1 '准备安装'; Winget-Install $it.id $it.i $it.n
        if (-not (& $it.has)) { throw '安装后仍未检测到' }
        T $it.i 'ok' 100 '安装完成'
      } catch {
        Warn-Item $it.i $it.n $_.Exception.Message
      }
    }

    # Gateway: 非致命
    $script:cur = 4
    if (-not $InstallGateway) { T 4 'skip' 100 '由桌面版首次启动时安装' }
    elseif (Get-Command openclaw -ErrorAction SilentlyContinue) { T 4 'skip' 100 '已安装,跳过' }
    else {
      T 4 'run' -1 '准备下载 Gateway'
      $code = Run-Proc 'powershell' '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "iwr -useb https://openclaw.ai/install.ps1 | iex"' 4 '正在下载安装 Gateway'
      Refresh-Path
      if ($code -ne 0 -or -not (Get-Command openclaw -ErrorAction SilentlyContinue)) { Warn-Item 4 'Gateway 网关' "安装失败(退出码 $code),可由桌面版首次启动时补装" }
      else { T 4 'ok' 100 '安装完成' }
    }

    # 桌面版: 必需步骤
    $script:cur = 5; T 5 'run' 0 '准备下载'
    $dest = Join-Path $Work $AppFile; $viaStore = $false
    if ($StoreId -and $hasWinget) {
      try { Log '尝试微软商店 ...'; $c = Run-Proc 'winget' "install --id $StoreId --source msstore --silent --accept-package-agreements --accept-source-agreements" 5 '微软商店安装中'
        if ($c -ne 0) { throw "退出码 $c" }; $viaStore = $true }
      catch { Log "商店不可用,切换镜像:$($_.Exception.Message)"; T 5 'run' 0 '切换镜像下载' }
    }
    if (-not $viaStore) {
      $prefixes = @('') + $Mirrors; $ok = $false
      foreach ($p in $prefixes) {
        try { $tag = if ($p) { '镜像' } else { '官方' }; Log "下载($tag):$p$Base/$AppFile"; Get-File "$p$Base/$AppFile" $dest 5 "正在下载($tag)" 0 80; $ok = $true; break }
        catch { Log "线路失败:$($_.Exception.Message)" }
      }
      if (-not $ok) { throw '所有下载线路(官方 + 镜像)都失败,请检查网络/代理后重试' }
      T 5 'run' 82 '正在校验 SHA256'
      $exp = $null
      foreach ($p in $prefixes) {
        try { $fmtP = Join-Path $Work $SumFile; Get-File "$p$Base/$SumFile" $fmtP 5 '获取校验清单' 82 82
          $manifest = Get-Content $fmtP -Raw -ErrorAction Stop | ConvertFrom-Json
          $entry = $manifest.files | Where-Object { $_.name -eq $AppFile } | Select-Object -First 1
          if ($entry -and $entry.sha256) { $exp = $entry.sha256.ToLower(); break } } catch { Log "校验清单线路失败:$($_.Exception.Message)" }
      }
      if (-not $exp) { throw '无法获取官方校验文件,为安全起见已停止' }
      if ((Get-FileHash $dest -Algorithm SHA256).Hash.ToLower() -ne $exp) { Remove-Item $dest -Force; throw 'SHA256 校验不一致,文件可能被篡改或损坏,已删除' }
      Log 'SHA256 校验通过'; T 5 'run' 90 '请在弹出的安装窗口中完成安装'
      $pr = Start-Process $dest -PassThru
      while (-not $pr.HasExited) { Start-Sleep -Milliseconds 200; Pump }
      if ($pr.ExitCode -ne 0) { throw "安装程序退出码 $($pr.ExitCode)" }
    }
    T 5 'ok' 100 '安装完成'
    Setup-Api
    if ($script:warn -gt 0) {
      $head.Text = '安装完成 (有 ' + $script:warn + ' 项跳过)'; $head.ForeColor = $cWarn
      $sub.Text = '桌面版已就绪; 跳过项可稍后手动补:' + [Environment]::NewLine + ($script:warnList -join [Environment]::NewLine)
      Log ('全部完成, 跳过 ' + $script:warn + ' 项: ' + ($script:warnList -join ' | '))
    } else {
      $head.Text = '安装完成 ✔'; $head.ForeColor = $cOk; $sub.Text = '请从开始菜单打开 OpenClaw Companion'; Log '全部完成'
    }
    $go.Text = '完成'
    Show-GatewayInfo
  } catch { Fail $_.Exception.Message }
}
$go.Add_Click({ Run-Install })
$autoTimer = New-Object Windows.Forms.Timer; $autoTimer.Interval = 400
$autoTimer.Add_Tick({ $autoTimer.Stop(); if ($go.Enabled) { Run-Install } })
$f.Add_Shown({ $autoTimer.Start() })
[void]$f.ShowDialog()
