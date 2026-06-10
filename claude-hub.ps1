# Claude Hub -- Claude Code 一键启动 + 历史对话管理
# 用法: powershell -ExecutionPolicy Bypass -File claude-hub.ps1
#       claude-hub.bat --direct  (直接启动，跳过菜单)

$ErrorActionPreference = "Continue"
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8

$CLAUDE_HOME = "$env:USERPROFILE\.claude"
$PROJECTS_DIR = "$CLAUDE_HOME\projects"
$HISTORY_FILE = "$CLAUDE_HOME\history.jsonl"
$EXPORT_DIR = "$env:USERPROFILE\ClaudeExports"

# 获取所有会话 JSONL 文件
function Get-SessionFiles {
    $sessions = @()
    if (-not (Test-Path $PROJECTS_DIR)) { return $sessions }
    $jsonlFiles = Get-ChildItem -Path $PROJECTS_DIR -Recurse -Filter "*.jsonl" -ErrorAction SilentlyContinue
    foreach ($f in $jsonlFiles) {
        $sessions += [PSCustomObject]@{
            Path      = $f.FullName
            UUID      = $f.BaseName
            Project   = Split-Path -Parent $f.FullName | Split-Path -Leaf
            Size      = $f.Length
            Modified  = $f.LastWriteTime
        }
    }
    return ($sessions | Sort-Object Modified -Descending)
}

# 解析会话元数据：首条用户消息 + 时间 + 消息数
function Get-SessionMeta($filePath) {
    $firstPrompt = ""
    $firstTime = ""
    $msgCount = 0
    $userCount = 0
    $reader = $null
    try {
        $reader = [IO.File]::OpenText($filePath)
        while (($line = $reader.ReadLine()) -ne $null) {
            try {
                $obj = $line | ConvertFrom-Json
                if ($obj.type -eq "user" -and $obj.message.content) {
                    $userCount++
                    if (-not $firstPrompt) {
                        $content = $obj.message.content
                        if ($content -is [array]) { $content = $content[0].text }
                        $firstPrompt = $content
                        $firstTime = if ($obj.timestamp) { $obj.timestamp.Substring(0,19) } else { "" }
                    }
                }
                if ($obj.type -eq "user" -or $obj.type -eq "assistant") {
                    $msgCount++
                }
            } catch { }
        }
    } catch { }
    finally {
        if ($reader) { $reader.Close() }
    }
    return [PSCustomObject]@{ FirstPrompt = $firstPrompt; FirstTime = $firstTime; MsgCount = $msgCount; UserCount = $userCount }
}

# 主菜单
function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "          Claude Hub -- 对话管理中心           " -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] 启动 Claude Code" -ForegroundColor Yellow
    Write-Host "  [2] 查看历史会话" -ForegroundColor Green
    Write-Host "  [3] 搜索历史对话" -ForegroundColor Green
    Write-Host "  [4] 导出会话 (Markdown)" -ForegroundColor Green
    Write-Host "  [5] 备份全部对话" -ForegroundColor Green
    Write-Host "  [6] 查看命令历史" -ForegroundColor Green
    Write-Host "  [0] 退出" -ForegroundColor Red
    Write-Host ""
    Write-Host "  请选择 [0-6]: " -NoNewline -ForegroundColor White
}

# 会话操作子菜单
function Show-SessionActions($session) {
    Clear-Host
    $meta = Get-SessionMeta $session.Path
    $timeStr = if ($meta.FirstTime) { $meta.FirstTime } else { $session.Modified.ToString("yyyy-MM-dd HH:mm") }
    $promptPreview = if ($meta.FirstPrompt) { $meta.FirstPrompt } else { "(无内容)" }
    if ($promptPreview.Length -gt 80) { $promptPreview = $promptPreview.Substring(0,80) + "..." }

    Write-Host "`n  ============================================" -ForegroundColor Cyan
    Write-Host "               会话详情" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  UUID:   $($session.UUID)" -ForegroundColor Gray
    Write-Host "  项目:   $($session.Project)" -ForegroundColor Gray
    Write-Host "  时间:   $timeStr" -ForegroundColor Gray
    Write-Host "  消息数: $($meta.MsgCount) | 提问数: $($meta.UserCount)" -ForegroundColor Gray
    Write-Host "  首条:   ${promptPreview}" -ForegroundColor White
    Write-Host ""
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [R] 继续该对话 (Resume)" -ForegroundColor Yellow
    Write-Host "  [E] 导出为 Markdown" -ForegroundColor Green
    Write-Host "  [D] 删除该对话" -ForegroundColor Red
    Write-Host "  [B] 返回列表" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  请选择: " -NoNewline -ForegroundColor White
}

# 1. 启动 Claude Code
function Start-Claude {
    Write-Host "`n  正在启动 Claude Code..." -ForegroundColor Yellow
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claude) {
        Write-Host "  未找到 claude 命令，请确认已安装 Claude Code" -ForegroundColor Red
        Write-Host "  按任意键返回..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    & claude
}

# 继续某个会话
function Resume-Session($session) {
    Write-Host "`n  正在恢复会话..." -ForegroundColor Yellow
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claude) {
        Write-Host "  未找到 claude 命令" -ForegroundColor Red
        Start-Sleep 2
        return
    }
    & claude --resume $session.UUID
}

# 2. 查看历史会话列表
function Show-SessionList {
    while ($true) {
        Clear-Host
        Write-Host "`n  [历史会话列表] (按时间倒序)`n" -ForegroundColor Cyan
        $sessions = Get-SessionFiles
        if ($sessions.Count -eq 0) {
            Write-Host "  暂无历史会话" -ForegroundColor Gray
            Write-Host "`n  按任意键返回..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }

        $index = 1
        $shown = 0
        $maxShow = 20
        foreach ($s in $sessions) {
            $meta = Get-SessionMeta $s.Path
            $timeStr = if ($meta.FirstTime) { $meta.FirstTime } else { $s.Modified.ToString("yyyy-MM-dd HH:mm") }
            $promptPreview = if ($meta.FirstPrompt.Length -gt 45) { $meta.FirstPrompt.Substring(0,45) + "..." } else { $meta.FirstPrompt }
            if (-not $promptPreview) { $promptPreview = "(系统消息)" }

            Write-Host "  [$index] " -NoNewline -ForegroundColor Yellow
            Write-Host "$timeStr" -NoNewline -ForegroundColor Gray
            Write-Host " | ${promptPreview}" -ForegroundColor White
            Write-Host "       项目: $($s.Project) | 消息: $($meta.MsgCount) | 提问: $($meta.UserCount)" -ForegroundColor DarkGray
            Write-Host ""
            $index++
            $shown++
            if ($shown -ge $maxShow) {
                Write-Host "  ... 还有 $($sessions.Count - $maxShow) 个会话，请使用搜索功能查找" -ForegroundColor DarkGray
                break
            }
        }

        Write-Host "  输入编号查看会话，或按 Enter 返回: " -NoNewline -ForegroundColor White
        $choice = Read-Host
        if ($choice -match '^\d+$' -and [int]$choice -le $shown -and [int]$choice -gt 0) {
            $selected = $sessions[[int]$choice - 1]
            Show-SessionActions $selected
            $action = Read-Host
            switch ($action.ToLower()) {
                "r" { Resume-Session $selected; return }
                "e" { Export-Session $selected.Path }
                "d" {
                    Write-Host "`n  确认删除该会话? [y/N]: " -NoNewline -ForegroundColor Red
                    $confirm = Read-Host
                    if ($confirm.ToLower() -eq "y") {
                        Delete-Session $selected
                        # 继续循环，刷新列表
                    }
                }
                "b" { continue }
                default { continue }
            }
        } elseif ($choice -eq "") {
            return
        }
    }
}

# 3. 搜索历史对话
function Search-History {
    Clear-Host
    Write-Host "`n  [搜索历史对话]`n" -ForegroundColor Cyan
    Write-Host "  输入搜索关键词: " -NoNewline -ForegroundColor White
    $keyword = Read-Host
    if (-not $keyword) { return }

    Write-Host "`n  正在搜索..." -ForegroundColor Yellow
    $sessions = Get-SessionFiles
    $matches = @()
    $total = $sessions.Count
    $current = 0

    foreach ($s in $sessions) {
        $current++
        Write-Host "`r  扫描中: $current / $total" -NoNewline -ForegroundColor DarkGray
        try {
            $lines = Get-Content $s.Path -Encoding UTF8 -ErrorAction SilentlyContinue
            $matched = $lines | Select-String -Pattern $keyword -SimpleMatch
            foreach ($m in $matched) {
                try {
                    $obj = $m.Line | ConvertFrom-Json
                    $role = $obj.type
                    $content = ""
                    if ($obj.message.content -is [array]) {
                        foreach ($c in $obj.message.content) {
                            if ($c.text) { $content += $c.text }
                        }
                    } else {
                        $content = $obj.message.content
                    }
                    $ts = if ($obj.timestamp) { $obj.timestamp.Substring(0,19) } else { "" }
                    $matches += [PSCustomObject]@{
                        Time    = $ts
                        Role    = $role
                        Content = $content
                        Session = $s.Name
                        UUID    = $s.UUID
                        Project = $s.Project
                        Path    = $s.Path
                    }
                } catch { }
            }
        } catch { }
    }
    Write-Host "`r                       `r" -NoNewline

    Write-Host "`n  找到 $($matches.Count) 条匹配结果:`n" -ForegroundColor Green
    $idx = 1
    foreach ($m in $matches) {
        $roleColor = if ($m.Role -eq "user") { "Yellow" } else { "Cyan" }
        $roleLabel = if ($m.Role -eq "user") { "[你]" } else { "[Claude]" }
        $preview = $m.Content
        $preview = $preview -replace $keyword, ">>$keyword<<"
        if ($preview.Length -gt 120) {
            $pos = $preview.IndexOf(">>$keyword<<")
            if ($pos -gt 60) {
                $preview = "..." + $preview.Substring([Math]::Max(0, $pos - 60))
            }
            if ($preview.Length -gt 120) {
                $preview = $preview.Substring(0, 120) + "..."
            }
        }

        Write-Host "  [$idx] " -NoNewline -ForegroundColor Yellow
        Write-Host "$roleLabel " -NoNewline -ForegroundColor $roleColor
        Write-Host "$($m.Time) " -NoNewline -ForegroundColor Gray
        Write-Host "| $preview" -ForegroundColor White
        $idx++
        if ($idx -gt 30) {
            Write-Host "  ... 仅显示前 30 条，请缩小搜索范围" -ForegroundColor DarkGray
            break
        }
    }

    if ($matches.Count -gt 0) {
        Write-Host "`n  输入编号操作对应会话，或按 Enter 返回: " -NoNewline -ForegroundColor White
        $choice = Read-Host
        if ($choice -match '^\d+$' -and [int]$choice -le $matches.Count -and [int]$choice -gt 0) {
            $selected = $matches[[int]$choice - 1]
            $sessionObj = [PSCustomObject]@{
                Path    = $selected.Path
                UUID    = $selected.UUID
                Project = $selected.Project
                Size    = 0
                Modified = Get-Date
            }
            Show-SessionActions $sessionObj
            $action = Read-Host
            switch ($action.ToLower()) {
                "r" { Resume-Session $sessionObj; return }
                "e" { Export-Session $selected.Path }
                "d" {
                    Write-Host "`n  确认删除该会话? [y/N]: " -NoNewline -ForegroundColor Red
                    $confirm = Read-Host
                    if ($confirm.ToLower() -eq "y") {
                        Delete-Session $sessionObj
                    }
                }
                "b" { }
            }
        }
    } else {
        Write-Host "`n  按 Enter 返回..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# 删除会话
function Delete-Session($session) {
    try {
        Remove-Item $session.Path -Force -ErrorAction Stop
        Write-Host "`n  已删除会话: $($session.UUID)" -ForegroundColor Green
    } catch {
        Write-Host "`n  删除失败: $_" -ForegroundColor Red
    }
    Start-Sleep 1.5
}

# 4. 导出会话为 Markdown
function Export-Session($sessionPath) {
    Clear-Host
    if (-not $sessionPath -or -not (Test-Path $sessionPath)) {
        Write-Host "`n  会话文件不存在" -ForegroundColor Red
        Start-Sleep 2
        return
    }

    if (-not (Test-Path $EXPORT_DIR)) {
        New-Item -ItemType Directory -Path $EXPORT_DIR -Force | Out-Null
    }

    $sessionName = [IO.Path]::GetFileNameWithoutExtension($sessionPath)
    $meta = Get-SessionMeta $sessionPath
    $dateStr = if ($meta.FirstTime) { $meta.FirstTime.Replace("T","_").Replace(":","-") } else { (Get-Date).ToString("yyyy-MM-dd_HH-mm") }
    $safeTitle = if ($meta.FirstPrompt) {
        ($meta.FirstPrompt.Substring(0, [Math]::Min(30,$meta.FirstPrompt.Length)) -replace '[\\/:*?"<>|]','-').Trim()
    } else { "对话" }
    $exportPath = "$EXPORT_DIR\${dateStr}_${safeTitle}.md"

    Write-Host "`n  正在导出..." -ForegroundColor Yellow

    $writer = $null
    try {
        $writer = [IO.File]::CreateText($exportPath)
        $writer.WriteLine("# $safeTitle`n")
        $writer.WriteLine("> 导出时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $writer.WriteLine("> 会话 ID: $sessionName`n---`n")

        $reader = [IO.File]::OpenText($sessionPath)
        while (($line = $reader.ReadLine()) -ne $null) {
            try {
                $obj = $line | ConvertFrom-Json
                if ($obj.type -eq "user") {
                    $content = $obj.message.content
                    if ($content -is [array]) {
                        $content = ($content | Where-Object { $_.text } | ForEach-Object { $_.text }) -join "`n"
                    }
                    $ts = if ($obj.timestamp) { $obj.timestamp.Substring(0,19).Replace("T"," ") } else { "" }
                    $writer.WriteLine("### 你 -- $ts`n")
                    $writer.WriteLine($content)
                    $writer.WriteLine("")
                }
                elseif ($obj.type -eq "assistant") {
                    $content = ""
                    if ($obj.message.content -is [array]) {
                        foreach ($c in $obj.message.content) {
                            if ($c.type -eq "text" -and $c.text) { $content += $c.text + "`n" }
                            elseif ($c.type -eq "tool_use") {
                                $content += "> [工具调用: $($c.name)]`n> ``$($c.input | ConvertTo-Json -Compress)```n`n"
                            }
                        }
                    } else {
                        $content = $obj.message.content
                    }
                    $ts = if ($obj.timestamp) { $obj.timestamp.Substring(0,19).Replace("T"," ") } else { "" }
                    $writer.WriteLine("### Claude -- $ts`n")
                    $writer.WriteLine($content)
                    $writer.WriteLine("---`n")
                }
            } catch { }
        }
        $reader.Close()
        $writer.Close()

        Write-Host "`n  [完成] 已导出到: $exportPath" -ForegroundColor Green
    } catch {
        Write-Host "`n  [失败] 导出出错: $_" -ForegroundColor Red
    } finally {
        if ($writer) { $writer.Close() }
    }

    Write-Host "`n  按 Enter 继续..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 5. 备份全部历史对话
function Backup-All {
    Clear-Host
    Write-Host "`n  [备份全部历史对话]`n" -ForegroundColor Cyan
    $backupDir = "$env:USERPROFILE\ClaudeBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

    Write-Host "  备份目录: $backupDir" -ForegroundColor Gray
    Write-Host "  正在复制文件..." -ForegroundColor Yellow

    try {
        if (Test-Path $PROJECTS_DIR) {
            Copy-Item -Path $PROJECTS_DIR -Destination "$backupDir\projects" -Recurse -ErrorAction SilentlyContinue
        }
        if (Test-Path $HISTORY_FILE) {
            Copy-Item -Path $HISTORY_FILE -Destination "$backupDir\history.jsonl" -ErrorAction SilentlyContinue
        }
        $fileCount = (Get-ChildItem -Path "$backupDir" -Recurse -File -ErrorAction SilentlyContinue).Count
        $totalSize = [math]::Round((Get-ChildItem -Path "$backupDir" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 2)

        Write-Host "`n  [完成] 备份完毕: $fileCount 个文件, $totalSize MB" -ForegroundColor Green
        Write-Host "  位置: $backupDir" -ForegroundColor Green
    } catch {
        Write-Host "`n  [失败] 备份出错: $_" -ForegroundColor Red
    }

    Write-Host "`n  按 Enter 返回..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 6. 查看命令历史
function Show-CommandHistory {
    Clear-Host
    Write-Host "`n  [最近命令历史]`n" -ForegroundColor Cyan

    if (-not (Test-Path $HISTORY_FILE)) {
        Write-Host "  暂无命令历史" -ForegroundColor Gray
        Write-Host "`n  按 Enter 返回..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    $lines = Get-Content $HISTORY_FILE -Encoding UTF8 -Tail 30
    $idx = 1
    foreach ($line in $lines) {
        try {
            $obj = $line | ConvertFrom-Json
            $ts = if ($obj.timestamp) {
                [DateTimeOffset]::FromUnixTimeMilliseconds($obj.timestamp).LocalDateTime.ToString("yyyy-MM-dd HH:mm")
            } else { "" }
            $display = $obj.display
            if ($display.Length -gt 80) { $display = $display.Substring(0,80) + "..." }
            Write-Host "  ${idx}. " -NoNewline -ForegroundColor DarkGray
            Write-Host "[$ts] " -NoNewline -ForegroundColor Gray
            Write-Host $display -ForegroundColor White
            $idx++
        } catch { }
    }

    Write-Host "`n  按 Enter 返回..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ========== 主入口 ==========
if ($args[0] -eq "--direct") {
    Start-Claude
    exit
}

while ($true) {
    Show-Menu
    $choice = Read-Host
    switch ($choice) {
        "1" { Start-Claude }
        "2" { Show-SessionList }
        "3" { Search-History }
        "4" {
            Clear-Host
            Write-Host "`n  [导出会话]" -ForegroundColor Cyan
            Write-Host "  输入会话 UUID (可从历史列表中获取): " -NoNewline
            $uuid = Read-Host
            if ($uuid) {
                $found = Get-ChildItem -Path $PROJECTS_DIR -Recurse -Filter "${uuid}.jsonl" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    Export-Session $found.FullName
                } else {
                    Write-Host "`n  未找到该会话" -ForegroundColor Red
                    Start-Sleep 2
                }
            }
        }
        "5" { Backup-All }
        "6" { Show-CommandHistory }
        "0" {
            Write-Host "`n  再见!`n" -ForegroundColor Cyan
            exit
        }
        default {
            Write-Host "  无效选项，请重试" -ForegroundColor Red
            Start-Sleep 1
        }
    }
}
