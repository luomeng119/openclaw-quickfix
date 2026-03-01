# Changelog

所有重要的变更都会记录在这个文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.1.1] - 2026-03-01

### Added
- 新增 uninstall.sh 卸载脚本
- 新增 GitHub Actions CI/CD 工作流
- 新增完整测试套件（10项测试）
- 新增 CHANGELOG.md

### Fixed
- 修复 emoji 编码问题（"��" → "[Main]"）
- 修复 openclaw-fix.sh 缺少 claude 命令检查
- 修复测试脚本颜色输出问题
- 修复变量未引号问题（ShellCheck SC2086）
- 修复反引号问题（ShellCheck SC2006）

### Improved
- 测试覆盖率从 5项 提升到 10项
- 代码质量评分提升到 95分
- 添加函数定义检查
- 添加跨平台兼容性测试
- 添加文档完整性检查

## [1.1.0] - 2026-02-28

### Added
- 首次发布
- 核心修复功能
- SmartFix AI修复
- 可视化终端支持
- 跨平台支持（macOS/Linux/Windows）
