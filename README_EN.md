# 🚀 OpenClaw QuickFix (v1.1.1)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue.svg)](#)
[![CI](https://github.com/ai-gongxueshe/openclaw-quickfix/actions/workflows/ci.yml/badge.svg)](#)

**OpenClaw QuickFix** is an intelligent auxiliary protection system designed for OpenClaw.

## 🛡️ Core Vision: Dual Protection Mechanism

In the OpenClaw 2.x ecosystem, the official provides powerful process protection, but cannot handle:
1. **Configuration semantic errors**: JSON format is correct but parameters are deprecated
2. **Silent failures**: Process exists but RPC interface is unresponsive
3. **Complex deadlocks**: Requires AI intervention to analyze logs

## 🌟 Core Features

- **Triple Platform Support**: macOS (LaunchAgent), Linux (Systemd), Windows
- **Atomic Self-Healing**: Automatic backup before all modifications
- **AI Collaborative Repair (SmartFix)**: Integrated with Claude Code
- **Visual Terminal**: Multi-pane monitoring via iTerm2/tmux

## 🛠️ Installation

### Quick Install (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/ai-gongxueshe/openclaw-quickfix/main/install.sh | bash
```

### Interactive Setup
```bash
bash setup.sh
```

### Offline Install
```bash
OFFLINE_MODE=true bash install.sh
```

## 📖 Usage

### Standard Detection and Repair
```bash
openclaw-quickfix
```

### Safe Detection Mode (Report only)
```bash
openclaw-quickfix --dry-run
```

### Interactive Wizard
```bash
bash setup.sh
```

## 🧪 Testing

```bash
cd tests
bash run_tests.sh
```

## 📄 Documentation

- [中文文档](README.md)
- [English Documentation](README_EN.md)
- [CHANGELOG](CHANGELOG.md)

## 📜 License

MIT License - see [LICENSE](LICENSE) file
