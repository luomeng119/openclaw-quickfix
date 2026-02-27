<div align="center">

# OpenClaw QuickFix

**增强型智能配置修复工具**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/luomeng119/openclaw-quickfix)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey.svg)](#支持平台)

*在 OpenClaw 官方自愈机制基础上，提供额外的配置错误检测和智能修复能力*

[English](#english) | [中文](#中文)

</div>

---

## 中文

### 🎯 一句话简介

OpenClaw QuickFix 是 OpenClaw Gateway 的**增强型智能配置修复工具**，在官方自愈机制基础上提供额外的配置错误检测和 AI 智能修复能力，确保服务 24/7 稳定运行。

---

### 🛡️ 多重保护架构

#### 为什么要双重保护？

OpenClaw 官方已经提供了基础的自愈机制（进程崩溃时自动重启），但这**无法处理配置错误**导致的问题。QuickFix 在此基础上增加了**配置层面的智能修复**：

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           多重保护架构                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   第一层：OpenClaw 官方自愈 (内置)                                       │
│   ────────────────────────────────────                                  │
│   • 功能：进程崩溃时自动重启                                             │
│   • 限制：无法修复配置错误                                               │
│   • 配置：参考 openclaw-min-bundle                                      │
│                                                                         │
│                           ↓ 进程正常但配置错误                           │
│                                                                         │
│   第二层：QuickFix 智能修复 ← 本项目                                     │
│   ────────────────────────────────────                                  │
│   • 功能：检测配置错误 → 查阅官方文档 → 自动修复                         │
│   • 优势：处理配置层面的问题                                             │
│   • 触发：手动运行 / 定时任务 / 监控触发                                 │
│                                                                         │
│                           ↓ 遇到未知错误                                 │
│                                                                         │
│   第三层：SmartFix (Claude Code AI)                                     │
│   ────────────────────────────────────                                  │
│   • 功能：AI 智能分析 → 联网搜索 → 生成修复代码                          │
│   • 优势：处理未知的复杂问题                                             │
│   • 要求：需要安装 Claude Code CLI                                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### 😫 它解决什么问题？

#### 常见痛点对比

| 问题场景 | 官方自愈能解决？ | QuickFix 能解决？ |
|----------|:---------------:|:----------------:|
| 进程崩溃 | ✅ 自动重启 | - |
| 配置 JSON 语法错误 | ❌ 持续崩溃 | ✅ 自动恢复备份 |
| 配置字段写错位置 | ❌ 持续崩溃 | ✅ 自动修正 |
| 使用了无效字段 | ❌ 持续崩溃 | ✅ 自动移除 |
| 未知的复杂错误 | ❌ 无能为力 | ✅ SmartFix AI 修复 |

#### 真实案例

```bash
# 错误：在 agents.list 中配置了 heartbeat（应该在 defaults 中）
[ERROR] agents.list[0].heartbeat: Unrecognized key

# 官方自愈：无法修复，Gateway 持续崩溃重启
# QuickFix：自动检测 → 查阅文档 → 移除错误字段 → 重启成功 ✅
```

---

### ✨ 核心功能

| 功能 | 说明 |
|------|------|
| 🔍 **智能检测** | 自动扫描配置文件中的常见错误 |
| 📚 **文档驱动** | 优先查阅官方文档获取解决方案 |
| 🤖 **SmartFix** | 文档无答案时调用 Claude Code 进行 AI 智能修复 |
| 🌍 **跨平台** | 支持 macOS、Linux、Windows (Git Bash/WSL) |
| 🔄 **自动备份** | 修复前自动备份配置文件，保留最近 10 个 |
| 🛡️ **安全模式** | 支持 `--dry-run` 仅检测不修复 |

---

### 🚀 安装指南

#### 前置要求

1. **已安装 OpenClaw** - 确保官方版本正常运行
2. **已配置官方自愈** - 参考 [openclaw-min-bundle](https://github.com/win4r/openclaw-min-bundle)
3. **Python 3** - 用于 JSON 解析
4. **(可选) Claude Code CLI** - 用于 SmartFix AI 修复

#### 安装步骤

```bash
# 步骤 1: 确认 OpenClaw 已安装
openclaw --version

# 步骤 2: 确认官方自愈已配置
# macOS:
launchctl list ai.openclaw.gateway

# Linux:
systemctl --user status openclaw-gateway

# 步骤 3: 一键安装 QuickFix
curl -fsSL https://raw.githubusercontent.com/luomeng119/openclaw-quickfix/main/install.sh | bash

# 步骤 4: 验证安装
openclaw-quickfix --version
```

---

### 📖 使用方法

#### 脚本说明

本项目包含以下脚本：

| 脚本 | 说明 | 用法 |
|------|------|------|
| `openclaw-quickfix.sh` | **主脚本**：检测并修复配置错误 | `openclaw-quickfix [选项]` |
| `openclaw-fix.sh` | **SmartFix**：AI 智能修复（被主脚本自动调用） | 无需手动执行 |
| `install.sh` | **安装脚本**：一键安装所有组件 | `curl ... \| bash` |

#### 基本用法

```bash
# 检测并修复配置错误
openclaw-quickfix

# 仅检测问题，不执行修复（推荐首次使用）
openclaw-quickfix --dry-run

# 查看帮助信息
openclaw-quickfix --help

# 查看版本号
openclaw-quickfix --version

# 启用调试模式
DEBUG=1 openclaw-quickfix

# 禁用彩色输出
NO_COLOR=1 openclaw-quickfix
```

---

### 🔄 执行流程

```
开始
  │
  ▼
┌─────────────────────────────────┐
│ 0. 环境检测                      │
│    • 检测操作系统                │
│    • 动态查找 OpenClaw 路径      │
│    • 动态查找配置文件            │
└───────────────┬─────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│ 1. 备份配置文件                  │
│    • 保存到 ~/.openclaw/backups/ │
│    • 保留最近 10 个备份          │
└───────────────┬─────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│ 2. 检测配置错误                  │
│    • Python 扫描常见问题         │
└───────────────┬─────────────────┘
                │
                ▼
          ┌──────────┐
          │ 有错误？  │
          └────┬─────┘
               │
        ┌──────┴──────┐
        │             │
       否            是
        │             │
        ▼             ▼
   ┌─────────┐  ┌───────────────────────────────────┐
   │ 退出    │  │ 3. 对每个错误:                     │
   │ (成功)  │  │    3.1 查阅官方文档                │
   └─────────┘  │    3.2 文档有答案 → 执行修复       │
                │    3.3 文档无答案 → 调用 SmartFix  │
                └───────────────┬───────────────────┘
                                │
                                ▼
                    ┌───────────────────────────────┐
                    │ 4. 启动可视化终端（可选）      │
                    │    macOS → iTerm2 / tmux     │
                    │    Linux → tmux              │
                    │    Windows → tmux            │
                    │                               │
                    │   ┌─────────┬───────────────┐ │
                    │   │ Claude  │ 日志          │ │
                    │   │ Code    │               │ │
                    │   │         ├───────────────┤ │
                    │   │         │ 状态          │ │
                    │   └─────────┴───────────────┘ │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                ┌─────────────────────────────────┐
                │ 5. 验证 JSON 语法               │
                └───────────────┬─────────────────┘
                                │
                                ▼
                ┌─────────────────────────────────┐
                │ 6. 重启 Gateway                 │
                │    macOS  → launchctl           │
                │    Linux  → systemctl           │
                │    Windows→ net / CLI           │
                └───────────────┬─────────────────┘
                                │
                                ▼
                              结束
```

---

### 🤖 SmartFix 配置指南

#### 什么是 SmartFix？

SmartFix 是 QuickFix 的**第三层保护**，当遇到无法自动修复的未知错误时，会调用 **Claude Code CLI** 进行 AI 智能修复。

#### 可视化终端支持

SmartFix 支持在可视化终端中显示修复过程：

| 平台 | 终端工具 | 分屏效果 |
|------|----------|----------|
| **macOS** | iTerm2 (优先) / tmux | 三窗格：修复/日志/状态 |
| **Linux** | tmux | 三窗格：修复/日志/状态 |
| **Windows** | tmux (Git Bash/WSL) | 三窗格：修复/日志/状态 |

```
┌──────────────────────┬──────────────────────────────────┐
│                      │                                  │
│  🤖 Claude Code      │  📋 实时日志                     │
│  修复输出            │  tail -f gateway.log             │
│                      │                                  │
│                      ├──────────────────────────────────┤
│                      │                                  │
│                      │  📊 修复状态                     │
│                      │                                  │
└──────────────────────┴──────────────────────────────────┘
```

#### 如何启用 SmartFix？

```bash
# 步骤 1: 安装 Claude Code CLI
# 参考: https://docs.anthropic.com/claude-code

# macOS/Linux:
curl -fsSL https://claude.ai/install.sh | bash

# 步骤 2: 验证安装
claude --version

# 步骤 3: 配置 API Key（按提示操作）
claude login

# 步骤 4: SmartFix 会在需要时自动调用
# 无需额外配置！
```

#### SmartFix 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `OPENCLAW_FIX_VISUAL` | 启用可视化终端 | `true` |
| `OPENCLAW_FIX_MAX_RETRIES` | 最大重试次数 | `2` |
| `OPENCLAW_FIX_CLAUDE_TIMEOUT_SECS` | 超时时间（秒） | `600` |

```bash
# 禁用可视化终端
export OPENCLAW_FIX_VISUAL=false

# 增加重试次数
export OPENCLAW_FIX_MAX_RETRIES=3
```

---

### 📁 项目结构

```
openclaw-quickfix/
├── openclaw-quickfix.sh      # 主脚本 - 配置错误检测与修复
├── openclaw-fix.sh           # SmartFix 脚本 - Claude Code 智能修复
├── openclaw-terminal.sh      # 终端启动器 - 可视化终端支持
├── install.sh                # 一键安装脚本
├── README.md                 # 项目文档（本文件）
├── LICENSE                   # MIT 许可证
├── .gitignore                # Git 忽略规则
└── docs/
    └── CONTRIBUTING.md       # 贡献指南
```

### 📜 脚本清单与执行顺序

| 顺序 | 脚本 | 作用 | 触发方式 |
|:----:|------|------|----------|
| 1 | `openclaw-quickfix.sh` | 主脚本：检测配置错误 → 查阅文档 → 执行修复 | 手动运行 / 定时任务 |
| 2 | `openclaw-fix.sh` | SmartFix：调用 Claude Code 进行 AI 智能修复 | 由 quickfix 自动调用 |
| 3 | `openclaw-terminal.sh` | 终端启动器：提供可视化终端界面 | 由 fix 脚本自动调用 |
| 0 | `install.sh` | 安装脚本：一键安装所有组件 | 用户手动执行 |

---

### 🔧 支持的修复类型

| 错误类型 | 问题描述 | 修复操作 |
|----------|----------|----------|
| `agents.list.*.heartbeat` | heartbeat 应在 defaults 中配置 | 移除该字段 |
| `auth.profiles.*.apiKey` | apiKey 不应在 profiles 中 | 移除该字段 |
| `models.providers.*.authProfileId` | authProfileId 是无效字段 | 移除该字段 |
| `cron.tasks` | tasks 不是 cron 的有效字段 | 移除该字段 |
| `tools.profile` (无效值) | profile 值不在允许列表中 | 移除该字段 |
| JSON 语法错误 | 配置文件 JSON 格式不正确 | 从备份恢复 |

---

### ⚙️ 环境变量配置

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `OPENCLAW_CONFIG` | 自定义配置文件路径 | `~/.openclaw/openclaw.json` |
| `OPENCLAW_SERVICE` | Gateway 服务名 | `ai.openclaw.gateway` |
| `OPENCLAW_PATH` | OpenClaw 安装路径 | 自动检测 |
| `OPENCLAW_GATEWAY_PORT` | Gateway 端口 | `18789` |
| `DEBUG` | 启用调试日志 (`1`) | - |
| `NO_COLOR` | 禁用彩色输出 (`1`) | - |

---

### 🖥️ 支持平台

| 平台 | 服务管理 | 状态 |
|------|----------|:----:|
| macOS | LaunchAgent | ✅ 完全支持 |
| Linux | systemd | ✅ 完全支持 |
| Windows | Git Bash / WSL | ✅ 支持 |

---

### ❓ 常见问题 FAQ

#### 基础问题

**Q1: 修复会丢失我的配置吗？**
> 不会！每次修复前都会自动备份到 `~/.openclaw/backups/`，最多保留 10 个备份。如果修复后有问题，可以从备份恢复。

**Q2: 我必须先安装官方自愈吗？**
> 建议安装。QuickFix 是**增强层**，与官方自愈配合使用效果最佳。官方自愈处理进程崩溃，QuickFix 处理配置错误。它们是互补关系，不是替代关系。

**Q3: 支持 Windows 吗？**
> 支持！可以在 Git Bash 或 WSL 中运行。Windows 服务管理通过 `net stop/start` 命令或 OpenClaw CLI 实现。

**Q4: `--dry-run` 是什么？**
> 安全模式，只检测问题不执行修复。**强烈建议**第一次使用时先用这个参数看看会修复什么，确认无误后再正式运行。

#### SmartFix 相关

**Q5: 必须安装 Claude Code 吗？**
> 不是必须的。没有 Claude Code 时，QuickFix 仍可自动修复**已知的配置错误**（如上表所列）。SmartFix 只在遇到**未知错误**时才需要。

**Q6: SmartFix 会自动修改我的配置吗？**
> 会的，但修改前会备份。SmartFix 会根据官方文档和 AI 分析结果进行**最小化修改**，修改后会验证 JSON 语法并重启服务验证。

**Q7: SmartFix 调用失败怎么办？**
> 检查以下几点：
> - Claude Code CLI 是否正确安装：`claude --version`
> - API Key 是否配置：`claude login`
> - 网络是否正常
> - 查看日志：`cat /tmp/openclaw-quickfix.log`

**Q8: SmartFix 会消耗多少 API 额度？**
> 每次修复调用通常消耗 0.01-0.05 USD（取决于复杂度）。建议仅在遇到无法自动修复的问题时使用。

#### 错误排查

**Q9: 提示"无法检测到 OpenClaw 安装路径"？**
> 确保 `openclaw` 命令可用：
> ```bash
> which openclaw
> # 或手动设置环境变量
> export OPENCLAW_PATH=/path/to/openclaw
> ```

**Q10: 修复后 Gateway 仍然无法启动？**
> 按以下步骤排查：
> 1. 检查日志：`tail -f ~/.openclaw/logs/gateway.err.log`
> 2. 手动验证配置：`python3 -m json.tool ~/.openclaw/openclaw.json`
> 3. 从备份恢复：`cp ~/.openclaw/backups/openclaw-最新的备份.json ~/.openclaw/openclaw.json`
> 4. 尝试 SmartFix：确保 Claude Code 已安装

**Q11: 如何查看修复历史？**
> - 备份文件：`ls -la ~/.openclaw/backups/`
> - 日志文件：`cat /tmp/openclaw-quickfix.log`

#### 与官方自愈的关系

**Q12: QuickFix 会和官方自愈冲突吗？**
> 不会。它们工作在不同层面：
> - 官方自愈：监控**进程**，崩溃时重启
> - QuickFix：检测**配置错误**并修复
>
> 两者可以同时运行，互不干扰。

**Q13: 应该先配置哪个？**
> 推荐顺序：
> 1. 先安装 OpenClaw
> 2. 配置官方自愈（参考 [openclaw-min-bundle](https://github.com/win4r/openclaw-min-bundle)）
> 3. 安装 QuickFix
> 4. (可选) 安装 Claude Code 启用 SmartFix

---

### 📄 许可证

本项目采用 [MIT License](LICENSE) 许可证。

---

### 🙏 致谢

本项目的灵感来源于 [openclaw-min-bundle](https://github.com/win4r/openclaw-min-bundle) 中的 **systemd user service（网关自愈）** 功能，在此基础上进行了以下优化和提升：

- 🔄 从 systemd 专用扩展为**跨平台支持**（macOS/Linux/Windows）
- 📚 引入**文档驱动**的智能修复机制
- 🤖 集成 **SmartFix (Claude Code)** 处理未知错误
- 🛡️ 增加安全模式 (`--dry-run`) 和自动备份
- ⚙️ 支持环境变量配置

感谢原作者的创意和贡献！

---

### 👥 作者

**AI共学社 (AI Gongxueshe)**

专注 AI 技术分享与实践的开源社区

- GitHub: [https://github.com/ai-gongxueshe](https://github.com/ai-gongxueshe)
- 项目仓库: [https://github.com/ai-gongxueshe/openclaw-quickfix](https://github.com/ai-gongxueshe/openclaw-quickfix)

---

<div align="center">

Made with ❤️ by [AI共学社](https://github.com/ai-gongxueshe)

> **AI共学社** - 专注 AI 技术分享与实践的开源社区

**[⬆ 返回顶部](#openclaw-quickfix)**

</div>

---

## English

### 🎯 One-liner

OpenClaw QuickFix is an **enhanced intelligent configuration repair tool** for OpenClaw Gateway, providing additional configuration error detection and AI-powered repair capabilities on top of the official self-healing mechanism.

### 🛡️ Multi-layer Protection

| Layer | Component | Function |
|-------|-----------|----------|
| 1st | Official Self-healing | Auto-restart on process crash |
| 2nd | QuickFix | Detect & fix config errors |
| 3rd | SmartFix (Claude Code) | AI-powered repair for unknown issues |

### 🚀 Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/luomeng119/openclaw-quickfix/main/install.sh | bash

# Run
openclaw-quickfix

# Dry-run (detect only)
openclaw-quickfix --dry-run
```

### 📄 License

This project is licensed under the [MIT License](LICENSE).

---

<div align="center">

Made with ❤️ by OpenClaw Community

</div>
