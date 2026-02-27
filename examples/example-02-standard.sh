#!/usr/bin/env bash
# 示例2: 标准用法 - 3窗格布局
#
# 此示例展示3窗格布局：主命令 + 日志 + 状态监控
# 适用于需要同时查看命令输出、日志和系统状态的场景

echo "启动示例2: 3窗格标准布局"
./openclaw-terminal.sh \
    --layout standard \
    --log "/tmp/example.log" \
    -- "echo 'Running standard 3-pane layout'"
