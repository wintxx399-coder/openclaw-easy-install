# OpenClaw 一键安装包（Windows）

> 双击运行，自动检查环境、装好 Gateway 与桌面版，全过程可视化进度。
> 不用再手动折腾 PowerShell、Node.js、Git、WebView2。

## 为什么做这个

官方安装方式对新手不太友好：

- 要自己开 PowerShell、改执行策略、逐条敲命令
- 装 Node / Git / WebView2 时没有任何进度提示，卡住了也不知道卡在哪
- 下载失败只报一行红字，不知道该换线路还是等一等

这个安装包把上面这些收进一个带界面的向导里：**环境检查 → 组件安装 → 下载校验 → 桌面版安装 → 可选接入 API**，每一步都有状态、百分比、速度，失败会告诉你原因和日志位置。

## 快速开始

1. 下载本仓库（右上角 **Code → Download ZIP**，或只下载 `windows` 文件夹）
2. 解压后双击 **`windows\双击安装.bat`**
3. 等进度条跑完，按提示选择是否接入 API（可跳过，之后在桌面版里配置）

**系统要求**：Windows 10 20H2 及以上 / Windows 11，需要 `winget`（Win11 自带；Win10 可在微软商店更新「应用安装程序」）。

## 安装流程

| 步骤 | 做什么 | 是否必需 |
| --- | --- | --- |
| 系统环境检查 | 判断系统版本、CPU 架构（x64 / arm64） | 必需 |
| Git | 缺失时用 winget 静默安装 | 建议 |
| Node.js (v22+) | 缺失时用 winget 安装 LTS 版 | 建议 |
| WebView2 运行库 | 缺失时用 winget 安装 | 建议 |
| Gateway 网关 | 缺失时运行官方安装脚本 | 可选 |
| OpenClaw 桌面版 | 从官方 Release 下载安装包，校验 SHA256 后安装 | 必需 |
| 接入 API（可选） | 选择 DeepSeek / Anthropic，粘贴 Key 自动写入本机配置 | 可选 |

组件类步骤（Git / Node / WebView2 / Gateway）失败只会标记为「已跳过」，不会中断安装；桌面版是必需步骤，失败会停下并给出原因。

## 安全说明

- 桌面版安装包下载后会用官方 `promotion.json` 校验 **SHA256**，不一致会直接删除文件并停止。
- 官方线路失败时才会切换镜像（`gh-proxy.com`、`ghfast.top`）。镜像是第三方服务，存在被篡改的可能，校验通过才会安装。
- API Key 只在本地内存中使用，写入本机 `~/.openclaw` 配置，不会上传到任何服务器，也不会写进日志。
- 脚本全部开源在本仓库，安装前可以自己读一遍 `windows\Install-OpenClaw.ps1`。

## 技能包：让 AI agent 自己装好能力

`skills/Skill-一键安装器.md` 是一份写给 AI agent 的安装指令。把它发给你的 agent（OpenClaw / Claude Code / Gemini CLI 等），它会：

- 检查 Node / Git / uv 环境
- 按需安装基础包：`windows-mcp`（操作电脑）、`agent-browser`（操作浏览器）、`ego-lite`（macOS）
- 可选进阶包：document-skills（Word/PDF/PPT/Excel）、fetch、filesystem、memory、sequential-thinking
- 下载失败自动切国内镜像，并在改配置前备份

把它当"说明书"看也可以，照着一步步做同样能装好。

## 常见问题

**双击后窗口闪一下就没了？**
右键 `双击安装.bat` → 以管理员身份运行；若仍闪退，打开 PowerShell 执行：
`powershell -NoProfile -ExecutionPolicy Bypass -File .\windows\Install-OpenClaw.ps1`

**提示找不到 winget？**
Windows 10 请到微软商店安装/更新「应用安装程序（App Installer）」，或手动安装 Git / Node / WebView2 后重新运行。

**所有下载线路都失败？**
通常是网络问题，开启代理后重试；也可以在浏览器手动下载桌面版安装包，再把文件放进 `%TEMP%\OpenClawInstaller` 目录。

**提示端口 18789 被占用？**
说明已有 CLI 网关在运行。先执行 `openclaw gateway stop`，再让桌面版接管；安装向导里的「网关信息」按钮会显示当前端口和 Token。

**杀毒软件报警？**
脚本会静默安装软件、写注册表检测项，属于正常行为；不放心可以先阅读源码，或只手动执行需要的步骤。

## 目录结构

```
openclaw-easy-install/
├── README.md
├── LICENSE
├── windows/
│   ├── 双击安装.bat          # 入口：双击这个
│   └── Install-OpenClaw.ps1  # 图形化安装向导
└── skills/
    └── Skill-一键安装器.md    # 发给 AI agent 的技能安装指令
```

## 免责声明

本项目是社区辅助工具，与 OpenClaw 官方无隶属关系。安装的软件版权归各自作者所有，使用前请自行评估风险。

## License

[MIT](LICENSE)
