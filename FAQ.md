# 常见问题 (FAQ)

## 安装问题

### Q: 安装时提示权限不足？
**A**: 确保安装目录可写：
```bash
mkdir -p ~/.local/bin
export PATH="$PATH:$HOME/.local/bin"
```

### Q: 安装后找不到命令？
**A**: 重新加载shell配置：
```bash
source ~/.zshrc  # 或 ~/.bashrc
```

## 使用问题

### Q: 运行时提示"未找到claude命令"？
**A**: SmartFix功能需要Claude Code CLI：
```bash
npm install -g @anthropic-ai/claude-code
```

### Q: 如何查看日志？
**A**: 
```bash
tail -f /tmp/openclaw-quickfix.log
```

### Q: 如何恢复备份？
**A**: 
```bash
cp ~/.openclaw/backups/openclaw-YYYYMMDD-HHMMSS.json ~/.openclaw/openclaw.json
```

## 故障排除

### Q: RPC检查失败？
**A**: 检查OpenClaw服务状态：
```bash
openclaw gateway status
openclaw gateway restart
```

### Q: 修复后配置仍然有问题？
**A**: 使用dry-run模式查看详细报告：
```bash
openclaw-quickfix --dry-run
```

## 卸载

### Q: 如何完全卸载？
**A**: 
```bash
bash uninstall.sh --yes
```

## 贡献

### Q: 如何贡献代码？
**A**: 请查看 [CONTRIBUTING.md](CONTRIBUTING.md)
