# 🚀 OpenClaw QuickFix (v1.1.0)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue.svg)](#)

**OpenClaw QuickFix** 是一款专为 OpenClaw 设计的**智能辅助保护系统**。它作为官方监管程序（Supervisor）之上的“第二道保险”，专注于解决配置冲突、逻辑死锁及 AI 运行态异常。

---

## 🛡️ 核心愿景：双重保护机制

在 OpenClaw 2.x 生态中，官方提供了强大的进程守护，但无法处理以下场景：
1. **配置语义错误**：JSON 格式正确但参数已被弃用（如 `heartbeat` 字段）。
2. **静默失效**：进程存在但 RPC 接口无响应。
3. **复杂死锁**：需要 AI 介入分析日志并执行“微创手术”修复。

**QuickFix 通过“检测 -> 官方文档比对 -> 自动修复 -> AI 智能 SmartFix” 链路实现服务的全天候自愈。**

---

## 🌟 核心特性

- **三平台深度适配**：
  - **macOS**: 原生支持 `LaunchAgent` 重启，自动唤起 `iTerm2` 分屏监控。
  - **Linux**: 深度集成 `Systemd`，利用 `tmux` 实现可视化修复。
  - **Windows**: 适配 `NSSM/Net Service` 管理逻辑。
- **原子级自愈**：所有修改前自动备份，修复失败 100% 物理回滚。
- **AI 协同修复 (SmartFix)**：集成 Claude Code，根据实时日志和官方文档执行智能化修复。

---

## 🛠️ 安装指南

### 快速安装 (推荐)
```bash
curl -fsSL https://raw.githubusercontent.com/ai-gongxueshe/openclaw-quickfix/main/install.sh | bash
```

### 离线/本地安装
```bash
cd openclaw-quickfix
OFFLINE_MODE=true bash install.sh
```

---

## 📖 使用方法

### 标准检测与修复
```bash
openclaw-quickfix
```

### 安全检测模式 (仅报告不修改)
```bash
openclaw-quickfix --dry-run
```

---

## ⚠️ 重要说明：与官方配置对齐

本工具是**辅助脚本**，在使用前请确保您已参考以下官方文档完成了基础的“24h 守护”配置：
- **macOS**: 参考 `docs/zh-CN/gateway/launchd.md`
- **Linux**: 参考 `docs/zh-CN/gateway/systemd.md`
- **Windows**: 参考 `docs/zh-CN/gateway/windows-service.md`

**"确定性软件工程，让 AI 服务永不宕机。"**
