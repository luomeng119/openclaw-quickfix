#!/usr/bin/env bash
# 示例4: 配合 SmartFix 使用
#
# 此示例展示如何在 SmartFix 中使用可视化终端
# 模拟一个 OpenClaw 配置修复场景

# 首先创建一个模拟的配置错误
mkdir -p /tmp/openclaw
echo '{"error": "模拟配置错误"}' > /tmp/openclaw/mock-config.json

echo "启动示例4: SmartFix 可视化修复"
echo "此示例将启动 iTerm 并显示修复过程"

# 使用 openclaw-terminal 启动修复流程
./openclaw-terminal.sh \
    --layout standard \
    --log "/tmp/openclaw/mock.log" \
    --config "/tmp/openclaw/mock-config.json" \
    -- "echo 'Mock SmartFix Process' && echo 'Analyzing config...' && sleep 2 && echo 'Fixing...' && sleep 1 && echo 'Done!'"
