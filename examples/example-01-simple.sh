#!/usr/bin/env bash
# 示例1: 基本用法 - 2窗格简单布局
#
# 此示例展示如何使用 openclaw-terminal 启动一个简单的2窗格终端
# 主窗格运行命令，右侧窗格显示日志

echo "启动示例1: 2窗格简单布局"
./openclaw-terminal.sh --layout simple -- "echo 'Hello from main pane'"
