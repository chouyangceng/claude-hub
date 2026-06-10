# Claude Hub

Claude Code 一键启动 + 历史对话管理工具。Windows 桌面快捷方式，双击即用。

## 功能

- **一键启动** — 双击桌面图标直接进入 Claude Code
- **历史会话** — 浏览、搜索所有历史对话
- **继续对话** — 从任意历史会话继续（`claude --resume`）
- **导出对话** — 导出为 Markdown 文件
- **删除会话** — 清理不需要的历史记录
- **备份全部** — 一键备份所有对话数据
- **命令历史** — 查看最近使用过的命令

## 安装

### 方式一：一键安装（推荐）

1. 下载本项目到任意目录
2. 双击 `install.bat`
3. 桌面上出现 "Claude Hub" 图标，双击即可使用

### 方式二：手动安装

1. 将 `claude-hub.bat`、`claude-hub.ps1`、`claude-hub.ico` 复制到 `%USERPROFILE%\claude-hub\`
2. 右键桌面 → 新建 → 快捷方式
3. 目标：`cmd.exe /c "%USERPROFILE%\claude-hub\claude-hub.bat"`
4. 图标：选择 `%USERPROFILE%\claude-hub\claude-hub.ico`

### 方式三：直接运行

不需要安装。直接双击 `claude-hub.bat` 即可使用（无桌面图标）。

## 依赖

- **Windows 10/11**
- **Claude Code** — 请先安装 [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- PowerShell 5.1+（Windows 自带）

## 目录结构

```
claude-hub/
├── claude-hub.bat       # 启动入口
├── claude-hub.ps1       # 主程序
├── claude-hub.ico       # 桌面图标
├── install.bat          # 一键安装脚本
├── tools/
│   └── gen-ico.ps1      # 图标生成工具
└── README.md
```

## 常见问题

**Q: 双击快捷方式后闪退？**
A: 请确认已安装 Claude Code。打开终端输入 `claude` 测试。

**Q: Claude Code 未找到？**
A: 请将 Claude Code 的安装路径加入系统 PATH，或通过 npm 全局安装：
```
npm install -g @anthropic-ai/claude-code
```

**Q: 图标显示为空白？**
A: Windows 图标缓存问题。运行 `install.bat` 会自动刷新缓存，或手动重启资源管理器。

**Q: 历史会话在哪里？**
A: `%USERPROFILE%\.claude\projects\` 目录下，每个会话是一个 `.jsonl` 文件。

## 许可证

MIT License
