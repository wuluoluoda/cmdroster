# CmdRoster (luo) — command-line & script hub for PowerShell
# Compatible: Windows PowerShell 5.1+  |  PowerShell Core 7+ (Windows / Linux / macOS)
#
# Usage: add to $PROFILE
#   . "$env:LUO_HOME\luo.ps1"    # Windows
#   . "$env:LUO_HOME/luo.ps1"    # Linux / macOS (pwsh)
#
# Registry: $LUO_HOME/registry.tsv — tab-separated, UTF-8
#   name<TAB>description<TAB>kind<TAB>payload
#   kind: shell  → payload is a shell command
#   kind: file   → payload is a relative path under LUO_HOME (e.g. scripts/foo.ps1)

Set-StrictMode -Off

# ── 路径辅助 ─────────────────────────────────────────────────────────────────

function _luo_home {
    if ($env:LUO_HOME) { $env:LUO_HOME } else { Join-Path $HOME '.luo' }
}
function _luo_registry_file { Join-Path (_luo_home) 'registry.tsv' }
function _luo_usage_file    { Join-Path (_luo_home) 'usage.tsv' }
function _luo_alias_file    { Join-Path (_luo_home) 'alias' }
function _luo_scripts_dir   { Join-Path (_luo_home) 'scripts' }

# ── 初始化 ───────────────────────────────────────────────────────────────────

function _luo_init_files {
    $h = _luo_home
    $s = _luo_scripts_dir
    if (-not (Test-Path $h)) { New-Item -ItemType Directory -Path $h | Out-Null }
    if (-not (Test-Path $s)) { New-Item -ItemType Directory -Path $s | Out-Null }

    $reg = _luo_registry_file
    if (-not (Test-Path $reg)) {
        [System.IO.File]::WriteAllText($reg, "name`tdescription`tkind`tpayload`n",
            [System.Text.Encoding]::UTF8)
    }
    $usage = _luo_usage_file
    if (-not (Test-Path $usage)) {
        [System.IO.File]::WriteAllText($usage, "name`tcount`n",
            [System.Text.Encoding]::UTF8)
    }
}

# ── Registry 读写 ─────────────────────────────────────────────────────────────

function _luo_read_registry {
    $reg = _luo_registry_file
    if (-not (Test-Path $reg)) { return }
    Get-Content -LiteralPath $reg -Encoding UTF8 | Select-Object -Skip 1 | ForEach-Object {
        $line = $_.TrimEnd("`r")
        if ($line -eq '' -or $line -match '^name\t') { return }
        $cols = $line -split "`t", 4
        if ($cols.Count -lt 4) { return }
        [PSCustomObject]@{
            Name    = $cols[0].Trim()
            Desc    = $cols[1].Trim()
            Kind    = $cols[2].Trim()
            Payload = $cols[3].Trim()
        }
    }
}

function _luo_write_registry {
    param([object[]]$Entries)
    $reg = _luo_registry_file
    $sb  = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("name`tdescription`tkind`tpayload")
    foreach ($e in $Entries) {
        [void]$sb.AppendLine("$($e.Name)`t$($e.Desc)`t$($e.Kind)`t$($e.Payload)")
    }
    [System.IO.File]::WriteAllText($reg, $sb.ToString(), [System.Text.Encoding]::UTF8)
}

# ── Usage 追踪 ───────────────────────────────────────────────────────────────

function _luo_usage_get {
    param([string]$Name)
    $f = _luo_usage_file
    if (-not (Test-Path $f)) { return 0 }
    $pat = "^$([regex]::Escape($Name))`t"
    $line = Get-Content -LiteralPath $f -Encoding UTF8 |
            Where-Object { $_ -match $pat } |
            Select-Object -Last 1
    if ($line) { [int]($line -split "`t")[1] } else { 0 }
}

function _luo_usage_incr {
    param([string]$Name)
    if (-not $Name) { return }
    _luo_init_files
    $f     = _luo_usage_file
    $count = (_luo_usage_get $Name) + 1
    $pat   = "^$([regex]::Escape($Name))`t"
    $lines = (Get-Content -LiteralPath $f -Encoding UTF8) -notmatch $pat
    $lines += "$Name`t$count"
    [System.IO.File]::WriteAllLines($f, $lines, [System.Text.Encoding]::UTF8)
}

function _luo_usage_remove {
    param([string]$Name)
    $f = _luo_usage_file
    if (-not (Test-Path $f)) { return }
    $pat   = "^$([regex]::Escape($Name))`t"
    $lines = (Get-Content -LiteralPath $f -Encoding UTF8) -notmatch $pat
    [System.IO.File]::WriteAllLines($f, $lines, [System.Text.Encoding]::UTF8)
}

# ── 命令注入（precmd 风格）───────────────────────────────────────────────────
# 与 zsh 版的 _LUO_PENDING_CMD + precmd 钩子思路相同：
# 把命令写入全局变量，然后把 prompt 函数包一层；
# prompt 在 PSReadLine 就绪后被调用，此时 Insert() 能稳定注入缓冲区。

$script:_LuoPendingCmd     = $null
$script:_LuoOriginalPrompt = $null

function _luo_commit_command {
    param([string]$Cmd)
    $script:_LuoPendingCmd     = $Cmd
    $script:_LuoOriginalPrompt = $function:global:prompt

    $function:global:prompt = {
        if ($script:_LuoPendingCmd) {
            $c = $script:_LuoPendingCmd
            $script:_LuoPendingCmd = $null
            $function:global:prompt = $script:_LuoOriginalPrompt
            try {
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($c)
            } catch {
                # Fallback: add to history + clipboard
                try { Add-History $c } catch {}
                try { Set-Clipboard -Value $c } catch {}
                Write-Host "`n  → $c" -ForegroundColor Cyan
                Write-Host "  (已加入历史，按 ↑ 调出；或 Ctrl+V 粘贴)`n" -ForegroundColor DarkGray
            }
        }
        if ($script:_LuoOriginalPrompt) {
            & $script:_LuoOriginalPrompt
        } else {
            "PS $($ExecutionContext.SessionState.Path.CurrentLocation)> "
        }
    }
}

# ── fzf 格式化 ───────────────────────────────────────────────────────────────

function _luo_format_entry {
    param([PSCustomObject]$Entry)
    # 四列 tab 分隔：name<TAB>desc<TAB>kind<TAB>payload
    # fzf 用 --with-nth=1,2,3 只显示前三列（隐藏 payload）
    "$($Entry.Name)`t$($Entry.Desc)`t$($Entry.Kind)`t$($Entry.Payload)"
}

function _luo_entry_from_line {
    param([string]$Line, [PSCustomObject[]]$Entries)
    $parts = $Line -split "`t", 4
    $name  = $parts[0].Trim()
    $Entries | Where-Object { $_.Name -eq $name } | Select-Object -First 1
}

# ── 检查 fzf ─────────────────────────────────────────────────────────────────

function _luo_require_fzf {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            Write-Error 'luo: 需要安装 fzf。Windows: winget install fzf  或  scoop install fzf'
        } else {
            Write-Error 'luo: 需要安装 fzf。Linux: sudo apt-get install fzf  macOS: brew install fzf'
        }
        return $false
    }
    return $true
}

# ── 交互选择（luo help）──────────────────────────────────────────────────────

function _luo_pick {
    param([switch]$DeleteMode)

    if (-not (_luo_require_fzf)) { return }
    _luo_init_files

    $h       = _luo_home
    $delMode = [bool]$DeleteMode

    while ($true) {
        [PSCustomObject[]]$entries = @(_luo_read_registry | Sort-Object Name)
        if ($entries.Count -eq 0) {
            Write-Host 'luo: 还没有登记任何命令，用 luo add 添加。' -ForegroundColor Yellow
            return
        }

        $fzfInput = $entries | ForEach-Object { _luo_format_entry $_ }

        $fzfArgs = @(
            '--ansi'
            '--delimiter', "`t"
            '--with-nth', '1,2,3'
            '--nth',      '1,2,3,4'
            '--no-multi'
            '+s'
            '--expect', 'f2'
            '--bind', 'tab:change-query({1})'
            '--bind', 'ctrl-n:abort'
            '--height', '40%'
            '--layout', 'reverse'
        )

        if ($delMode) {
            $fzfArgs += '--header', "`e[32m[删除模式]`e[0m Enter=删除 | F2=退出删除模式 | Tab=缩小 | Ctrl+N/Esc=退出"
            $fzfArgs += '--prompt', "`e[1;32mDEL>`e[0m "
            $fzfArgs += '--color',  'prompt:#00cc00,pointer:#00ff00,fg+:#ccffcc,border:#00aa00'
        } else {
            $fzfArgs += '--header', "Tab=缩小 | Enter=填入命令行 | `e[33mF2`e[0m=删除模式（绿色）| Ctrl+N/Esc=退出"
            $fzfArgs += '--prompt', '> '
        }

        $rawOut = $fzfInput | fzf @fzfArgs 2>&1

        if ($LASTEXITCODE -ne 0 -or -not $rawOut) { return }

        $outLines    = ($rawOut -split "`n") | Where-Object { $_ -ne '' }
        $key         = if ($outLines.Count -ge 1) { $outLines[0].Trim() } else { '' }
        $selectedLine = if ($outLines.Count -ge 2) { $outLines[1] } else { '' }

        if ($key -eq 'f2') {
            $delMode = -not $delMode
            continue
        }

        if (-not $selectedLine) { return }

        $entry = _luo_entry_from_line $selectedLine $entries
        if (-not $entry) { return }

        if ($delMode) {
            $count = _luo_usage_get $entry.Name
            if ($count -gt 30) {
                Write-Host ''
                $yn = Read-Host "  '$($entry.Name)' 已使用 $count 次（>30），确认删除？[y/N]"
                if ($yn -notmatch '^[Yy]') { continue }
            }
            _luo_remove_by_name $entry.Name
            _luo_usage_remove $entry.Name
            continue
        }

        # 普通模式：把命令填入命令行
        $payload = $entry.Payload
        if ($entry.Kind -eq 'file') {
            $abs = if ([System.IO.Path]::IsPathRooted($payload)) {
                $payload
            } else {
                Join-Path $h $payload
            }
            if (-not (Test-Path $abs)) {
                Write-Error "luo: 文件不存在: $abs"
                return
            }
            $payload = $abs
        }

        _luo_usage_incr $entry.Name
        _luo_commit_command $payload
        return
    }
}

# ── luo add ──────────────────────────────────────────────────────────────────

function _luo_add {
    param([string[]]$CmdArgs)

    _luo_init_files
    $h      = _luo_home
    $name   = ''
    $desc   = ''
    $force  = $false
    $rest   = [System.Collections.Generic.List[string]]::new()

    $i = 0
    while ($i -lt $CmdArgs.Count) {
        switch ($CmdArgs[$i]) {
            '-n' { $i++; $name  = $CmdArgs[$i] }
            '-d' { $i++; $desc  = $CmdArgs[$i] }
            '-f' { $force = $true }
            default { $rest.Add($CmdArgs[$i]) }
        }
        $i++
    }

    if ($rest.Count -eq 0) {
        Write-Error 'luo add: 请提供命令或脚本路径'
        return
    }

    $raw = ($rest -join ' ').Trim()
    # 剥一层外层引号
    if ($raw -match '^"(.*)"$' -or $raw -match "^'(.*)'$") { $raw = $Matches[1] }

    # ── 判断是否为脚本路径 ──
    $isScript = $false
    $srcAbs   = ''
    if ($raw -match '[/\\]' -or $raw -match '^\.[/\\]' -or $raw -match '^\.\.[/\\]') {
        $candidate = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($raw)
        if (Test-Path $candidate -PathType Leaf) {
            $isScript = $true
            $srcAbs   = (Resolve-Path $candidate).ProviderPath
        }
    }

    if ($isScript) {
        if (-not $name) { $name = [System.IO.Path]::GetFileNameWithoutExtension($srcAbs) }
        if (-not $desc) {
            $firstDesc = Get-Content $srcAbs -TotalCount 20 |
                Where-Object { $_ -match '^#\s*luo:desc\s+' } |
                Select-Object -First 1
            if ($firstDesc) { $desc = ($firstDesc -replace '^#\s*luo:desc\s+', '').Trim() }
        }
        if (-not $desc) { $desc = "no description" }

        $destName = $name
        $destPath = Join-Path (_luo_scripts_dir) ([System.IO.Path]::GetFileName($srcAbs))
        $relpath  = "scripts/$([System.IO.Path]::GetFileName($srcAbs))"

        $entries = @(_luo_read_registry)
        if (($entries | Where-Object { $_.Name -eq $destName }) -and -not $force) {
            Write-Error "luo add: '$destName' 已存在，用 -f 强制覆盖"
            return
        }
        $entries = @($entries | Where-Object { $_.Name -ne $destName })

        if (Test-Path $destPath) {
            if ($force) { Remove-Item $destPath -Force }
            else { Write-Error "luo add: 目标已存在: $destPath（用 -f 覆盖）"; return }
        }

        # Windows 尝试符号链接，失败则复制
        try {
            New-Item -ItemType SymbolicLink -Path $destPath -Target $srcAbs -ErrorAction Stop | Out-Null
        } catch {
            Copy-Item $srcAbs $destPath
        }

        $desc = $desc -replace "`t", ' '
        $entries += [PSCustomObject]@{ Name=$destName; Desc=$desc; Kind='file'; Payload=$relpath }
        _luo_write_registry $entries
        Write-Host "luo: 已登记脚本(file): $destName" -ForegroundColor Green
        return
    }

    # ── shell 命令 ──
    $payload = $raw -replace "`t", ' '
    if (-not $payload) { Write-Error 'luo add: 命令为空'; return }
    if (-not $name)    { $name = ($payload -split '\s+')[0] -replace '[^A-Za-z0-9_.-]', '_' }

    $desc = if ($desc) { $desc } elseif ($payload.Length -gt 72) { $payload.Substring(0,72) + '…' } else { $payload }
    $desc = $desc -replace "`t", ' '

    $entries = @(_luo_read_registry)
    if (($entries | Where-Object { $_.Name -eq $name }) -and -not $force) {
        Write-Error "luo add: '$name' 已存在，用 -f 强制覆盖"
        return
    }
    $entries = @($entries | Where-Object { $_.Name -ne $name })
    $entries += [PSCustomObject]@{ Name=$name; Desc=$desc; Kind='shell'; Payload=$payload }
    _luo_write_registry $entries
    Write-Host "luo: 已登记命令(shell): $name" -ForegroundColor Green
}

# ── luo list ─────────────────────────────────────────────────────────────────

function _luo_list {
    _luo_init_files
    $entries = @(_luo_read_registry | Sort-Object Name)
    if ($entries.Count -eq 0) { Write-Host '（空）'; return }
    Write-Host ("{0,-22} {1,-32} {2,-6} {3}" -f 'name','description','kind','payload') -ForegroundColor DarkGray
    foreach ($e in $entries) {
        $d = if ($e.Desc.Length -gt 31) { $e.Desc.Substring(0,30) + '…' } else { $e.Desc }
        Write-Host ("{0,-22} {1,-32} {2,-6} {3}" -f $e.Name, $d, $e.Kind, $e.Payload)
    }
}

# ── luo sync ─────────────────────────────────────────────────────────────────

function _luo_sync {
    param([switch]$Prune)
    _luo_init_files
    $h       = _luo_home
    $scripts = _luo_scripts_dir
    $entries = [System.Collections.Generic.List[PSCustomObject]]@(_luo_read_registry)

    Get-ChildItem $scripts -File | ForEach-Object {
        $f    = $_
        $n    = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        $rel  = "scripts/$($f.Name)"
        if ($entries | Where-Object { $_.Payload -eq $rel }) { return }
        $firstDesc = Get-Content $f.FullName -TotalCount 20 |
            Where-Object { $_ -match '^#\s*luo:desc\s+' } | Select-Object -First 1
        $d = if ($firstDesc) { ($firstDesc -replace '^#\s*luo:desc\s+','').Trim() } else { 'no description' }
        $entries.Add([PSCustomObject]@{ Name=$n; Desc=$d; Kind='file'; Payload=$rel })
        Write-Host "luo sync: 已补全 $rel"
    }

    if ($Prune) {
        $keep = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($e in $entries) {
            if ($e.Kind -eq 'file') {
                $abs = if ([System.IO.Path]::IsPathRooted($e.Payload)) { $e.Payload }
                       else { Join-Path $h $e.Payload }
                if (-not (Test-Path $abs)) {
                    Write-Host "luo sync -p: 已移除失效条目: $($e.Name) ($($e.Payload))" -ForegroundColor Yellow
                    _luo_usage_remove $e.Name
                    continue
                }
            }
            $keep.Add($e)
        }
        $entries = $keep
    }

    _luo_write_registry @($entries)
    Write-Host 'luo sync: 完成'
}

# ── luo remove ───────────────────────────────────────────────────────────────

function _luo_remove_by_name {
    param([string]$Name)
    if (-not $Name) { Write-Error 'luo: 名称不能为空'; return }
    $entries = @(_luo_read_registry)
    $target  = $entries | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $target) { Write-Error "luo: 未找到 '$Name'"; return }

    if ($target.Kind -eq 'file' -and $target.Payload -match '^scripts/') {
        $abs = Join-Path (_luo_home) $target.Payload
        if (Test-Path $abs) { Remove-Item $abs -Force }
    }

    $entries = @($entries | Where-Object { $_.Name -ne $Name })
    _luo_write_registry $entries
    Write-Host "luo: 已从 registry 移除: $Name" -ForegroundColor Green
}

# ── luo alias ────────────────────────────────────────────────────────────────

function _luo_alias_load {
    $f = _luo_alias_file
    if (-not (Test-Path $f)) { return }
    $name = (Get-Content $f -Raw -Encoding UTF8).Trim()
    if (-not $name) { return }

    if ($global:_LUO_CURRENT_ALIAS -and $global:_LUO_CURRENT_ALIAS -ne $name) {
        Remove-Item "Function:global:$($global:_LUO_CURRENT_ALIAS)" -ErrorAction SilentlyContinue
    }
    # 动态定义别名函数
    $fb = [scriptblock]::Create('luo help')
    Set-Item -Path "Function:global:$name" -Value $fb
    $global:_LUO_CURRENT_ALIAS = $name
}

function _luo_alias_cmd {
    param([string[]]$CmdArgs)
    _luo_init_files
    $f = _luo_alias_file

    if ($CmdArgs.Count -eq 0) {
        if ($global:_LUO_CURRENT_ALIAS) {
            Write-Host "当前快捷命令: $($global:_LUO_CURRENT_ALIAS)  （等同于 luo help）"
        } else {
            Write-Host '未设置快捷命令。用法: luo alias <命令名>  例: luo alias pp'
        }
        return
    }

    $name = $CmdArgs[0]

    if ($name -in 'off', '-', '--unset') {
        if ($global:_LUO_CURRENT_ALIAS) {
            $old = $global:_LUO_CURRENT_ALIAS
            Remove-Item "Function:global:$old" -ErrorAction SilentlyContinue
            Remove-Item $f -Force -ErrorAction SilentlyContinue
            $global:_LUO_CURRENT_ALIAS = $null
            Write-Host "luo: 已取消快捷命令 '$old'。"
        } else {
            Remove-Item $f -Force -ErrorAction SilentlyContinue
            Write-Host 'luo: 没有设置过快捷命令。'
        }
        return
    }

    if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_-]*$') {
        Write-Error "luo alias: 命令名只能含字母、数字、下划线、横杠，且不能以数字开头"
        return
    }

    $existing = Get-Command $name -ErrorAction SilentlyContinue
    if ($existing -and $existing.CommandType -ne 'Function') {
        $yn = Read-Host "luo alias: '$name' 与系统命令冲突，仍要覆盖？[y/N]"
        if ($yn -notmatch '^[Yy]') { return }
    }

    Set-Content -Path $f -Value $name -Encoding UTF8 -NoNewline
    _luo_alias_load
    Write-Host "luo: 快捷命令已设为 '$name'（重启终端后自动加载，当前终端已即时生效）。"
}

# ── 主入口 ───────────────────────────────────────────────────────────────────

function global:luo {
    if ($args.Count -eq 0) {
        Write-Host @'
用法:
  luo help          交互选择（fzf，Enter 将命令放到命令行）
                    F2 进入/退出删除模式（绿色）；删除模式下 Enter 直接删除
  luo list          列出所有登记的命令
  luo add [选项] <命令或脚本路径>
                    登记一条命令（shell）或脚本（file）
                      -n <名称>  自定义显示名
                      -d <简介>  自定义描述
                      -f         强制覆盖同名
  luo sync [-p]     扫描 scripts/ 补全缺失；-p 同时删除失效的 file 条目
  luo rm / remove   直接进入 luo help 的删除模式（不接受其它参数）
  luo alias [名字]  设置 luo help 的快捷命令；luo alias off 取消
  luo home          打印 LUO_HOME

快捷键（需 PSReadLine）：
  Ctrl+Shift+L      直接弹出 fzf 选命令，选中后命令出现在命令行（最佳体验）
'@
        return
    }

    switch ($args[0]) {
        { $_ -in 'help','pick' } { _luo_pick }
        'list'                   { _luo_list }
        'add'                    { _luo_add $args[1..($args.Count - 1)] }
        { $_ -in 'rm','remove' } {
            if ($args.Count -gt 1) {
                Write-Error 'luo rm/remove: 不再接受名称参数；请执行 luo help，按 F2 进入删除模式'
                return
            }
            _luo_pick -DeleteMode
        }
        'sync'                   {
            if ($args -contains '-p') { _luo_sync -Prune } else { _luo_sync }
        }
        'alias'                  { _luo_alias_cmd $args[1..($args.Count - 1)] }
        'home'                   { _luo_home }
        default                  { Write-Error "luo: 未知子命令 '$($args[0])'"; luo }
    }
}

# ── PSReadLine 快捷键（Ctrl+Shift+L）────────────────────────────────────────
# 在 PSReadLine 的 ScriptBlock 内调用 Insert()，是最稳定的命令行注入方式。

if (Get-Module PSReadLine -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler `
        -Key 'Ctrl+Shift+L' `
        -BriefDescription 'luo-help' `
        -LongDescription 'CmdRoster: 弹出 fzf 选命令，选中后直接放入命令行' `
        -ScriptBlock {
            $h       = _luo_home
            [PSCustomObject[]]$entries = @(_luo_read_registry | Sort-Object Name)
            if ($entries.Count -eq 0) { return }
            $input_  = $entries | ForEach-Object { _luo_format_entry $_ }
            $rawOut  = $input_ | fzf `
                --ansi `
                --delimiter "`t" `
                --with-nth '1,2,3' `
                --no-multi `
                --header 'Enter=填入命令行 | Esc=退出' `
                --prompt '> ' `
                --height '40%' `
                --layout reverse 2>&1

            if ($LASTEXITCODE -eq 0 -and $rawOut) {
                $entry = _luo_entry_from_line $rawOut $entries
                if ($entry) {
                    $payload = $entry.Payload
                    if ($entry.Kind -eq 'file') {
                        $payload = if ([System.IO.Path]::IsPathRooted($payload)) { $payload }
                                   else { Join-Path $h $payload }
                    }
                    _luo_usage_incr $entry.Name
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($payload)
                }
            }
        }
}

# ── 启动时自动加载 alias ─────────────────────────────────────────────────────
if (-not (Get-Variable _LUO_CURRENT_ALIAS -Scope Global -ErrorAction SilentlyContinue)) {
    $global:_LUO_CURRENT_ALIAS = $null
}
_luo_alias_load
