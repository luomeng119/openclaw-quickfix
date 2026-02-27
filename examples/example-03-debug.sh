#!/usr/bin/env bash
# 示例3: 调试模式 - 6窗格完整布局
#
# 此示例展示完整的6窗格调试布局：
# - 主命令窗格
# - 日志监控
# - 状态监控
# - 配置文件查看
# - 服务状态
# - 网络端口监控

echo "启动示例3: 6窗格调试布局"
./openclaw-terminal.sh \
    --layout debug \
    --log "/tmp/debug.log" \
    --config "$HOME/.openclaw/openclaw.json" \
    -- "echo 'Debug mode with 6 panes'"
