# 🚀 OpenClaw QuickFix (v1.1.1)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue.svg)](#)
[![CI](https://github.com/luomeng119/openclaw-quickfix/actions/workflows/ci.yml/badge.svg)](https://github.com/luomeng119/openclaw-quickfix/actions)
[![Version](https://img.shields.io/badge/version-v1.1.1-green.svg)](#)

**OpenClaw QuickFix** 是一款专为 OpenClaw 设计的**智能辅助保护系统**。它作为官方监管程序（Supervisor）之上的"第二道保险"，通过"检测-分析-修复-验证"的闭环流程，专注于解决配置冲突、逻辑死锁及 AI 运行态异常，实现服务的全天候自愈。

---

## 📋 项目简介

### 痛点问题
在 OpenClaw 2.x 生态中，官方提供了强大的进程守护，但以下场景仍需要人工干预：

| 问题类型 | 具体表现 | 传统解决方案 | QuickFix方案 |
|---------|---------|------------|-------------|
| **配置语义错误** | JSON格式正确但参数已弃用 | 人工排查文档 | 自动比对官方文档修复 |
| **静默失效** | 进程存在但RPC无响应 | 手动重启服务 | 自动检测并重启 |
| **复杂死锁** | 需要AI分析日志 | 人工分析日志 | SmartFix智能修复 |

### 解决方案
QuickFix 构建了三层防护体系：
1. **预防层**：配置预检与Schema验证
2. **修复层**：自动修复已知问题
3. **智修层**：AI介入处理复杂场景

---

## 🏗️ 系统架构

### 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                     OpenClaw QuickFix                        │
│                      (智能辅助保护系统)                       │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   检测层      │    │   修复层      │    │   交互层      │
│  Detection   │───▶│    Repair    │───▶│    Visual    │
└──────────────┘    └──────────────┘    └──────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                     核心功能模块                              │
├──────────────┬──────────────┬──────────────┬────────────────┤
│  配置检测     │  自动修复     │  备份恢复     │   SmartFix     │
│ Config Check │  Auto Repair │   Backup     │   AI Repair    │
└──────────────┴──────────────┴──────────────┴────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  OpenClaw Gateway Service                    │
│                    (被保护的目标服务)                         │
└─────────────────────────────────────────────────────────────┘
```

### 模块职责

| 模块 | 职责 | 对应脚本 |
|------|------|---------|
| **检测层** | RPC健康检查、配置错误检测、路径探测 | openclaw-quickfix.sh |
| **修复层** | 自动修复已知问题、备份管理、服务重启 | openclaw-quickfix.sh |
| **智修层** | AI介入分析日志、执行复杂修复 | openclaw-fix.sh |
| **交互层** | 可视化终端、分屏监控、进度展示 | openclaw-terminal.sh |

---

## 🔄 执行流程

### 主流程图

```
                    ┌─────────────────┐
                    │  启动 QuickFix  │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
              失败  │ 检测OpenClaw路径 │  成功
           ┌───────┤                 ├───────┐
           │       └─────────────────┘       │
           ▼                                   ▼
    ┌─────────────┐                   ┌─────────────────┐
    │   报错退出   │                   │  RPC健康检查    │
    └─────────────┘                   └────────┬────────┘
                                               │
                          异常                 │  正常
                             ┌─────────────────┤
                             │                 │
                             ▼                 ▼
                    ┌─────────────────┐ ┌─────────────────┐
                    │  尝试重启服务   │ │  配置错误检测   │
                    └────────┬────────┘ └────────┬────────┘
                             │                   │
                             ▼                   │
                    ┌─────────────────┐          │
              否    │  重启成功?      │  是      │
           ┌───────┤                 ├──────────┘
           │       └─────────────────┘
           ▼
    ┌─────────────────┐          ┌─────────────────┐
    │  调用SmartFix   │◀─────────│  无错误         │
    │  (AI智能修复)   │          │  输出状态正常   │
    └────────┬────────┘          └─────────────────┘
             │
             ▼
    ┌─────────────────┐
    │ 启动可视化终端  │
    │ (iTerm2/tmux)   │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  AI分析日志     │
    │  执行修复建议   │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   修复完成      │
    └─────────────────┘
```

### 修复流程详解

**Phase 1: 检测阶段 (Detection)**
```
1. 环境检测
   ├── 操作系统识别 (macOS/Linux/Windows)
   ├── OpenClaw安装路径探测
   └── 配置文件定位

2. 健康检查
   ├── RPC接口响应测试
   └── 服务状态验证

3. 配置检测
   ├── JSON语法校验
   ├── 弃用字段识别 (heartbeat等)
   └── 参数有效性验证
```

**Phase 2: 修复阶段 (Repair)**
```
1. 备份创建
   └── 自动备份到 ~/.openclaw/backups/

2. 自动修复
   ├── 移除弃用字段
   ├── 修正配置格式
   └── 清理无效配置

3. 服务重启
   ├── macOS: launchctl kickstart
   ├── Linux: systemctl restart
   └── 验证重启结果
```

**Phase 3: 智修阶段 (SmartFix)**
```
1. 启动可视化终端 (iTerm2/tmux)
   ├── 左侧: 主任务窗口
   ├── 右上: 实时日志监控
   └── 右下: 修复结果展示

2. AI介入分析
   ├── 读取OpenClaw日志
   ├── 比对官方文档
   └── 生成修复方案

3. 执行修复
   └── 人工确认后执行修复建议
```

---

## 📁 项目结构

```
openclaw-quickfix/
├── 📄 核心脚本
│   ├── openclaw-quickfix.sh    # 主脚本：检测+自动修复
│   ├── openclaw-fix.sh         # SmartFix：AI智能修复
│   ├── openclaw-terminal.sh    # 终端启动器：可视化分屏
│   ├── install.sh              # 安装脚本
│   ├── uninstall.sh            # 卸载脚本
│   └── setup.sh                # 交互式配置向导
│
├── 📁 工作流 (.github/workflows/)
│   └── ci.yml                  # GitHub Actions CI/CD
│
├── 📁 文档
│   ├── README.md               # 中文文档 (本文件)
│   ├── README_EN.md            # 英文文档
│   ├── CHANGELOG.md            # 变更日志
│   ├── FAQ.md                  # 常见问题
│   └── LICENSE                 # MIT许可证
│
├── 📁 国际化 (locales/)
│   ├── zh_CN.sh                # 简体中文
│   └── en_US.sh                # 英文
│
├── 📁 库文件 (lib/)
│   └── logging.sh              # 增强日志系统
│
├── 📁 测试 (tests/)
│   └── run_tests.sh            # 完整测试套件
│
└── 📁 示例 (examples/)
    └── *.sh                    # 使用示例
```

---

## 🌟 核心特性

### 1. 三层防护体系

```
┌─────────────────────────────────────────┐
│  Layer 3: SmartFix (AI智能修复层)        │
│  - 复杂问题AI分析                        │
│  - 官方文档自动比对                      │
│  - 可视化交互修复                        │
└─────────────────────────────────────────┘
                    ▲
        自动修复失败 │
                    │
┌─────────────────────────────────────────┐
│  Layer 2: Auto Repair (自动修复层)       │
│  - 4类常见问题自动修复                    │
│  - 原子级备份与回滚                       │
│  - 服务自动重启                          │
└─────────────────────────────────────────┘
                    ▲
        发现配置问题 │
                    │
┌─────────────────────────────────────────┐
│  Layer 1: Detection (检测层)             │
│  - RPC健康检查                           │
│  - 配置错误检测                          │
│  - 路径自动探测                          │
└─────────────────────────────────────────┘
```

### 2. 跨平台深度适配

| 平台 | 进程管理 | 终端工具 | 特色功能 |
|------|---------|---------|---------|
| **macOS** | LaunchAgent | iTerm2 | 原生分屏、AppleScript |
| **Linux** | Systemd | tmux | 会话保持、远程支持 |
| **Windows** | NSSM/Service | Git Bash | WSL兼容 |

### 3. 原子级自愈

```
用户调用QuickFix
      │
      ▼
创建备份 ◀──────┐
      │        │
      ▼        │
执行修改       │
      │        │
      ▼        │
修复成功?      │
   是/否       │
    │          │
    ├─ 是 ───▶ 完成
    │
    └─ 否 ───▶ 恢复备份
                  │
                  ▼
               返回错误
```

---

## 🛠️ 安装指南

### 快速安装 (推荐 ⭐)
```bash
curl -fsSL https://raw.githubusercontent.com/ai-gongxueshe/openclaw-quickfix/main/install.sh | bash
```

### 交互式安装 (推荐首次使用)
```bash
bash setup.sh
```
向导会引导您完成：环境检查 → 安装模式选择 → 功能配置 → 自动安装

### 离线/本地安装
```bash
git clone https://github.com/luomeng119/openclaw-quickfix.git
cd openclaw-quickfix
OFFLINE_MODE=true bash install.sh
```

---

## 📖 使用方法

### 标准检测与修复
```bash
openclaw-quickfix
```
完整执行：检测 → 修复 → 重启

### 安全检测模式 (仅报告不修改)
```bash
openclaw-quickfix --dry-run
```
适用于：生产环境预检、问题诊断

### 使用示例

```bash
# 场景1: 日常维护
$ openclaw-quickfix
🔧 OpenClaw 智能修复 v1.1.1
[INFO] RPC接口响应正常
[INFO] 发现配置问题: agents.list[0].heartbeat (已弃用)
[FIX] 已移除弃用字段
[INFO] 重启服务成功
✅ 修复完成!

# 场景2: 安全检测
$ openclaw-quickfix --dry-run
🔧 OpenClaw 智能修复 v1.1.1 (安全模式)
[WARN] 发现1个问题:
  - agents.list[0].heartbeat: 该字段已弃用
[INFO] dry-run模式，未执行修复
```

---

## 🧪 测试

```bash
cd tests
bash run_tests.sh
```

**测试覆盖:**
- ✅ OS检测测试
- ✅ 语法检查测试
- ✅ 函数定义测试
- ✅ 配置检测测试
- ✅ 备份机制测试
- ✅ 跨平台兼容性测试
- ✅ 错误处理测试
- ✅ 文件权限测试
- ✅ 文档完整性测试

---

## ⚠️ 重要说明

### 与官方配置对齐

本工具是**辅助脚本**，在使用前请确保您已参考以下官方文档完成了基础的"24h 守护"配置：

| 平台 | 官方文档 | 关键配置 |
|------|---------|---------|
| **macOS** | docs/zh-CN/gateway/launchd.md | LaunchAgent plist |
| **Linux** | docs/zh-CN/gateway/systemd.md | Systemd service |
| **Windows** | docs/zh-CN/gateway/windows-service.md | Windows Service |

### 使用建议

1. **首次使用**: 建议先使用 `--dry-run` 模式查看问题
2. **生产环境**: 确保备份策略已配置
3. **SmartFix**: 需要安装 Claude Code CLI

---

## 📄 相关文档

- [English Documentation](README_EN.md)
- [变更日志](CHANGELOG.md)
- [常见问题](FAQ.md)
- [贡献指南](CONTRIBUTING.md)

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## 📜 许可证

[MIT License](LICENSE)

---

**"确定性软件工程，让 AI 服务永不宕机。"**

**Made with ❤️ by 档案AI共学社**

---

## 🙏 致谢

本项目灵感来源于 [win4r/openclaw-min-bundle](https://github.com/win4r/openclaw-min-bundle)，感谢原作者的出色工作和对OpenClaw生态的贡献。

特别感谢：
- **win4r** - 原项目作者，提供了核心思路和技术基础
- **OpenClaw社区** - 提供了丰富的文档和最佳实践
- **Claude Code团队** - 提供了强大的AI辅助开发工具

---

**Made with ❤️ by 档案AI共学社**
