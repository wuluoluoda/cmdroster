# CmdRoster (luo) — PowerShell 安装脚本
# Windows  : irm https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | iex
# Linux/mac: curl -fsSL .../pwsh/install.ps1 | pwsh
# 克隆后   : ./pwsh/install.ps1
#Requires -Version 5.1

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

$GITHUB_RAW = 'https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh'
$DEST       = if ($env:LUO_HOME) { $env:LUO_HOME } else { Join-Path $HOME '.luo' }
$MARK_BEGIN = '# >>> luo script hub (pwsh)'
$MARK_END   = '# <<< luo script hub (pwsh)'

# ── 平台检测 ─────────────────────────────────────────────────────────────────
$IS_WIN   = $IsWindows -or ($env:OS -eq 'Windows_NT')
$IS_LINUX = $IsLinux
$IS_MAC   = $IsMacOS
$IS_WSL   = $IS_LINUX -and (Test-Path /proc/version) -and
            ((Get-Content /proc/version -Raw 2>$null) -match 'microsoft')

if     ($IS_WSL)   { Write-Host "✔  检测到 WSL 环境。" }
elseif ($IS_WIN)   { Write-Host "✔  检测到 Windows 环境。" }
elseif ($IS_MAC)   { Write-Host "✔  检测到 macOS 环境。" }
elseif ($IS_LINUX) { Write-Host "✔  检测到 Linux 环境。" }
else               { Write-Host "⚠  未知操作系统，继续安装…" }

# ── fzf 检测与安装 ────────────────────────────────────────────────────────────
function Install-Fzf {
    if ($IS_WIN) {
        # 按优先级尝试：winget → scoop → choco
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "→  通过 winget 安装 fzf …"
            winget install --id=junegunn.fzf -e --source winget --accept-source-agreements --accept-package-agreements
        } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
            Write-Host "→  通过 scoop 安装 fzf …"
            scoop install fzf
        } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Host "→  通过 Chocolatey 安装 fzf …"
            choco install fzf -y
        } else {
            Write-Error @'
未找到包管理器（winget / scoop / choco），请手动安装 fzf：
  https://github.com/junegunn/fzf/releases
  或先安装 winget（Windows 应用安装程序）/ scoop / Chocolatey
'@
            exit 1
        }
    } elseif ($IS_MAC) {
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            Write-Host "→  通过 Homebrew 安装 fzf …"
            brew install fzf
        } else {
            Write-Error "未找到 Homebrew，请先安装：https://brew.sh  然后: brew install fzf"
            exit 1
        }
    } elseif ($IS_LINUX) {
        if (Get-Command apt-get -ErrorAction SilentlyContinue) {
            Write-Host "→  通过 apt-get 安装 fzf …"
            sudo apt-get update -qq; sudo apt-get install -y fzf
        } elseif (Get-Command apt -ErrorAction SilentlyContinue) {
            Write-Host "→  通过 apt 安装 fzf …"
            sudo apt update -qq; sudo apt install -y fzf
        } elseif (Get-Command pacman -ErrorAction SilentlyContinue) {
            Write-Host "→  通过 pacman 安装 fzf …"
            sudo pacman -Sy --noconfirm fzf
        } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
            Write-Host "→  通过 dnf 安装 fzf …"
            sudo dnf install -y fzf
        } else {
            Write-Error "请手动安装 fzf：https://github.com/junegunn/fzf#installation"
            exit 1
        }
    }
}

if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Host "`nCmdRoster 依赖 fzf，当前环境未安装。"
    $interactive = [Environment]::UserInteractive -and [System.Console]::IsInputRedirected -eq $false
    if ($interactive) {
        $yn = Read-Host "是否自动安装 fzf？[Y/n]"
        if ($yn -eq '' -or $yn -match '^[Yy]') { Install-Fzf }
        else { Write-Error "请先安装 fzf 后再运行本脚本。"; exit 1 }
    } else {
        Write-Host "非交互模式，自动安装 fzf …"
        Install-Fzf
    }
}

# ── 建目录 & 复制/下载文件 ───────────────────────────────────────────────────
New-Item -ItemType Directory -Path $DEST                        -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DEST 'scripts')  -Force | Out-Null

# 判断是否为远程执行（iex / piped pwsh）
$isRemote = $MyInvocation.MyCommand.CommandType -eq 'Script' -and
            $MyInvocation.ScriptName -eq ''

if ($isRemote -or -not $PSScriptRoot) {
    if (-not (Get-Command curl -ErrorAction SilentlyContinue) -and
        -not (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue)) {
        Write-Error "需要 curl 或 Invoke-WebRequest，未找到。"
        exit 1
    }
    Write-Host "正在从 GitHub 下载 luo.ps1 …"
    $luoPs1   = "$GITHUB_RAW/luo.ps1"
    $exampleF = "$GITHUB_RAW/registry.tsv.example"
    try {
        Invoke-WebRequest $luoPs1   -OutFile (Join-Path $DEST 'luo.ps1')              -UseBasicParsing
        Invoke-WebRequest $exampleF -OutFile (Join-Path $DEST 'registry.tsv.example') -UseBasicParsing
    } catch {
        # Fallback to curl
        curl -fsSL $luoPs1   -o (Join-Path $DEST 'luo.ps1')
        curl -fsSL $exampleF -o (Join-Path $DEST 'registry.tsv.example')
    }
} else {
    $root = $PSScriptRoot
    Copy-Item (Join-Path $root 'luo.ps1')              (Join-Path $DEST 'luo.ps1')              -Force
    Copy-Item (Join-Path $root 'registry.tsv.example') (Join-Path $DEST 'registry.tsv.example') -Force
}

$regFile = Join-Path $DEST 'registry.tsv'
if (-not (Test-Path $regFile)) {
    Copy-Item (Join-Path $DEST 'registry.tsv.example') $regFile
}

# ── 写入 $PROFILE ─────────────────────────────────────────────────────────────
# PowerShell 在 Windows/Linux/macOS 上 $PROFILE 路径不同，但 $PROFILE 变量总是正确的。
$profilePath = $PROFILE.CurrentUserCurrentHost
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($profileContent -and $profileContent.Contains($MARK_BEGIN)) {
    Write-Host "已检测到 `$PROFILE 中的 luo 配置块，跳过写入。"
} else {
    $luoLine = ". '$DEST/luo.ps1'"
    if ($IS_WIN) { $luoLine = ". '$DEST\luo.ps1'" }
    $block = @"

$MARK_BEGIN
$( if ($DEST -ne (Join-Path $HOME '.luo')) { "`$env:LUO_HOME = '$DEST'" } )
if (Test-Path '$($luoLine.Split("'")[1])') { $luoLine }
$MARK_END
"@
    Add-Content $profilePath $block -Encoding UTF8
    Write-Host "已写入: $profilePath（重启终端自动生效）"
}

# ── 完成提示 ─────────────────────────────────────────────────────────────────
$luoDest = Join-Path $DEST 'luo.ps1'
Write-Host @"

✅  luo 已安装到 $DEST

▶  在当前终端立刻激活（或新开一个终端）：
     . '$luoDest'

▶  快速上手：
     luo add "ping google.com"   # 登记一条命令
     luo help                    # fzf 选命令，回车后命令出现在命令行
     luo alias ql                # 把 ql 设为 luo help 的快捷方式

▶  最佳体验：用 Ctrl+Shift+L 直接弹出 fzf（命令直接注入命令行）

"@

if ($IS_WIN) {
    Write-Host @'
💡  Windows 提示：
    · 若 fzf 界面出现乱码，请在 Windows Terminal 设置中确认编码为 UTF-8：
        [终端] → 首选项 → 配置文件 → 外观 → 字体
    · 建议使用 Windows Terminal（支持 ANSI 颜色）而非旧版 conhost.exe。
    · 若 Ctrl+Shift+L 不起作用，可以直接运行 luo help。

'@
}
