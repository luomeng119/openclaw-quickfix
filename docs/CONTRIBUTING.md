# Contributing Guide

感谢您有兴趣为 OpenClaw QuickFix 做贡献！

## 🤝 如何贡献

### 报告问题

如果您发现了 bug 或有功能建议，请：

1. 在 [Issues](https://github.com/openclaw-community/openclaw-quickfix/issues) 中搜索是否已有相关问题
2. 如果没有，创建新 Issue 并提供：
   - 问题描述
   - 复现步骤
   - 预期行为
   - 实际行为
   - 系统环境信息

### 提交代码

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

### 代码规范

- 使用 `shellcheck` 检查 shell 脚本
- 遵循 [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- 添加必要的注释
- 更新相关文档

### 测试

在提交 PR 前，请确保：

```bash
# 运行 dry-run 测试
./openclaw-quickfix.sh --dry-run

# 检查帮助信息
./openclaw-quickfix.sh --help

# 检查版本
./openclaw-quickfix.sh --version
```

## 📝 许可证

通过贡献代码，您同意您的代码将以 MIT 许可证授权。
