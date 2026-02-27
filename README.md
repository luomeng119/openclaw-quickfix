# OpenClaw QuickFix

<div align="center">

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/openclaw-community/openclaw-quickfix)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey.svg)](#支持平台)

**智能配置修复工具 - 自动检测并修复 OpenClaw Gateway 配置错误**

[English](#english) | [中文](#中文)

</div>

---

## 中文

### 📖 简介

OpenClaw QuickFix 是一个跨平台的智能配置修复工具，用于自动检测和修复 OpenClaw Gateway 的配置错误。

与传统的"打补丁"式修复不同，QuickFix 采用**智能诊断 + 文档驱动**的架构：

```
发现问题 → 查阅官方文档 → 执行修复 → 无答案则 SmartFix
```

### ✨ 特性

- 🔍 **智能检测** - 自动扫描配置文件中的常见错误
- 📚 **文档驱动** - 优先查阅官方文档获取解决方案
- 🤖 **SmartFix** - 文档无答案时调用 Claude Code 进行智能修复
- 🌍 **跨平台** - 支持 macOS、Linux、Windows
- 🔄 **自动备份** - 修复前自动备份配置文件
- 🛡️ **安全模式** - 支持 `--dry-run` 仅检测不修复

### 📊 执行流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    QuickFix 执行流程                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  开始                                                                       │
│    │                                                                        │
│    ▼                                                                        │
│  ┌───────────────────────────────────────────┐                              │
│  │ 0. 环境自动检测                            │                              │
│  │    - 检测 OS (macOS/Linux/Windows)        │                              │
│  │    - 动态查找 OpenClaw 安装路径           │                              │
│  │    - 动态查找配置文件路径                 │                              │
│  └─────────────────┬─────────────────────────┘                              │
│                    │                                                        │
│                    ▼                                                        │
│  ┌───────────────────────────────────────────┐                              │
│  │ 1. 初始化                                  │                              │
│  │    - 检查配置文件存在                      │                              │
│  │    - 创建备份                              │                              │
│  └─────────────────┬─────────────────────────┘                              │
│                    │                                                        │
│                    ▼                                                        │
│  ┌───────────────────────────────────────────┐                              │
│  │ 2. 检测配置错误 (Python 扫描)              │                              │
│  └─────────────────┬─────────────────────────┘                              │
│                    │                                                        │
│                    ▼                                                        │
│              ┌───────────┐                                                  │
│              │  有错误？  │                                                  │
│              └─────┬─────┘                                                  │
│                    │                                                        │
│           ┌────────┴────────┐                                               │
│           │                 │                                               │
│          否                是                                               │
│           │                 │                                               │
│           ▼                 ▼                                               │
│      ┌─────────┐   ┌─────────────────────────────────────┐                  │
│      │ 退出    │   │ 3. 对每个错误循环处理:               │                  │
│      │ (成功)  │   │                                      │                  │
│      └─────────┘   │    3.1 查阅官方文档 (动态路径)       │                  │
│                    │         ↓                              │                  │
│                    │    ┌────────────┐                      │                  │
│                    │    │ 文档有答案?│                      │                  │
│                    │    └─────┬──────┘                      │                  │
│                    │          │                             │                  │
│                    │     ┌────┴────┐                        │                  │
│                    │     │         │                        │                  │
│                    │    是        否                        │                  │
│                    │     │         │                        │                  │
│                    │     ▼         ▼                        │                  │
│                    │  3.2 执行   3.4 调用                   │                  │
│                    │  修复       SmartFix                    │                  │
│                    │     │         (Claude Code)            │                  │
│                    └─────┴─────────┴────────────────────────┘                  │
│                              │                                              │
│                              ▼                                              │
│              ┌───────────────────────────────────────┐                        │
│              │ 4. 验证配置 JSON                      │                        │
│              └─────────────────┬─────────────────────┘                        │
│                                │                                            │
│                                ▼                                            │
│              ┌───────────────────────────────────────┐                        │
│              │ 5. 重启 Gateway (跨平台)              │                        │
│              │   ┌─────────────────────────────────┐│                        │
│              │   │ macOS  → launchctl              ││                        │
│              │   │ Linux  → systemctl / CLI        ││                        │
│              │   │ Windows→ net / CLI              ││                        │
│              │   └─────────────────────────────────┘│                        │
│              └─────────────────┬─────────────────────┘                        │
│                                │                                            │
│                                ▼                                            │
│                              结束                                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 🚀 快速开始

#### 安装

```bash
# 方式 1: 使用 curl 下载
curl -fsSL https://raw.githubusercontent.com/openclaw-community/openclaw-quickfix/main/openclaw-quickfix.sh -o openclaw-quickfix.sh
chmod +x openclaw-quickfix.sh

# 方式 2: 克隆仓库
git clone https://github.com/openclaw-community/openclaw-quickfix.git
cd openclaw-quickfix
chmod +x openclaw-quickfix.sh
```

#### 使用

```bash
# 检测并修复配置错误
./openclaw-quickfix.sh

# 仅检测问题，不执行修复
./openclaw-quickfix.sh --dry-run

# 查看帮助
./openclaw-quickfix.sh --help
```

### ⚙️ 配置

#### 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `OPENCLAW_CONFIG` | 自定义配置文件路径 | `~/.openclaw/openclaw.json` |
| `OPENCLAW_SERVICE` | 自定义 Gateway 服务名 | `ai.openclaw.gateway` |
| `DEBUG` | 启用调试日志 (`1`) | - |
| `NO_COLOR` | 禁用彩色输出 (`1`) | - |

#### 示例

```bash
# 使用自定义配置路径
OPENCLAW_CONFIG=/path/to/config.json ./openclaw-quickfix.sh

# 启用调试模式
DEBUG=1 ./openclaw-quickfix.sh

# 禁用彩色输出
NO_COLOR=1 ./openclaw-quickfix.sh
```

### 🔧 支持的配置错误修复

| 错误类型 | 修复操作 |
|----------|----------|
| `agents.list.*.heartbeat` | 移除 heartbeat 字段 |
| `auth.profiles.*.apiKey` | 移除 apiKey 字段 |
| `models.providers.*.authProfileId` | 移除 authProfileId 字段 |
| `cron.tasks` | 移除无效的 tasks 字段 |
| `tools.profile` (无效值) | 移除未知的 profile |

### 🖥️ 支持平台

| 平台 | 服务管理 | 状态 |
|------|----------|------|
| macOS | LaunchAgent | ✅ 完全支持 |
| Linux | systemd | ✅ 完全支持 |
| Windows | Git Bash / WSL | ✅ 支持 |

### 📋 依赖

- **bash** 4.0+
- **python3**
- **grep**

### 📝 日志

日志文件位置：
- macOS/Linux: `/tmp/openclaw-quickfix.log`
- Windows: `%TEMP%\openclaw-quickfix.log`

### 🤝 贡献

欢迎贡献代码！请查看 [CONTRIBUTING.md](docs/CONTRIBUTING.md) 了解详情。

### 📄 许可证

本项目采用 [MIT License](LICENSE) 许可证。

---

## English

### 📖 Introduction

OpenClaw QuickFix is a cross-platform intelligent configuration repair tool that automatically detects and fixes OpenClaw Gateway configuration errors.

Unlike traditional "patching" approaches, QuickFix uses an **intelligent diagnosis + documentation-driven** architecture:

```
Detect Problem → Check Official Docs → Apply Fix → SmartFix if No Answer
```

### ✨ Features

- 🔍 **Smart Detection** - Automatically scans for common configuration errors
- 📚 **Documentation-Driven** - Prioritizes official documentation for solutions
- 🤖 **SmartFix** - Calls Claude Code for intelligent repair when docs don't have answers
- 🌍 **Cross-Platform** - Supports macOS, Linux, Windows
- 🔄 **Auto Backup** - Automatically backs up config before repair
- 🛡️ **Safe Mode** - Supports `--dry-run` for detection only

### 🚀 Quick Start

```bash
# Download
curl -fsSL https://raw.githubusercontent.com/openclaw-community/openclaw-quickfix/main/openclaw-quickfix.sh -o openclaw-quickfix.sh
chmod +x openclaw-quickfix.sh

# Run
./openclaw-quickfix.sh

# Dry run (detect only)
./openclaw-quickfix.sh --dry-run
```

### 📄 License

This project is licensed under the [MIT License](LICENSE).

---

<div align="center">

Made with ❤️ by OpenClaw Community

</div>

---

## 🙏 致谢

本项目的灵感来源于 [openclaw-min-bundle](https://github.com/win4r/openclaw-min-bundle) 中的 **systemd user service（网关自愈）** 功能，在此基础上进行了以下优化和提升：

- 🔄 从 systemd 专用扩展为跨平台支持（macOS/Linux/Windows）
- 📚 引入文档驱动的智能修复机制
- 🤖 集成 SmartFix (Claude Code) 处理未知错误
- 🛡️ 增加安全模式 (`--dry-run`) 和自动备份
- ⚙️ 支持环境变量配置

感谢原作者的创意和贡献！
