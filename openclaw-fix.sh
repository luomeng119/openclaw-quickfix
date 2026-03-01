#!/usr/bin/env bash
# openclaw-fix.sh - SmartFix 智能修复脚本
#
# 描述: 当 QuickFix 无法自动修复时，调用 Claude Code CLI 进行 AI 智能修复
#       支持可视化终端窗口（macOS iTerm2 / 其他平台 tmux）

set -euo pipefail

# ============================================
# 版本信息
# ============================================
readonly VERSION="1.1.0"
readonly SCRIPT_NAME="openclaw-fix"

# ============================================
# 环境检测
# ============================================

detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

# 颜色
if [[ -t 1 ]]; then
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
    BLUE='\033[0;34m' NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# AppleScript 物理级转义
escape_for_applescript() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//\$/\\\$}"
    echo "$str"
}

get_iterm_name() {
    if [[ -d "/Applications/iTerm2.app" ]] || [[ -d "$HOME/Applications/iTerm2.app" ]]; then
        echo "iTerm2"
    elif [[ -d "/Applications/iTerm.app" ]] || [[ -d "$HOME/Applications/iTerm.app" ]]; then
        echo "iTerm"
    else
        echo "iTerm2"
    fi
}

# ============================================
# 启动逻辑
# ============================================

launch_visual_iterm() {
    local cmd="$1"
    local iterm_name=$(get_iterm_name)
    local escaped_cmd=$(escape_for_applescript "$cmd")
    local log_file="/tmp/openclaw-quickfix.log"
    local result_file="/tmp/openclaw-fix-result.json"

    log_info "使用 $iterm_name 启动可视化修复..."

    osascript << APPLESCRIPT
tell application "$iterm_name"
    activate
    set newWin to (create window with default profile)
    tell current session of newWin
        set name to "🔧 OpenClaw SmartFix"
        write text "$escaped_cmd"
        
        split vertically with default profile
        tell last session of newWin
            set name to "📋 实时日志"
            write text "tail -f \"$log_file\""
            
            split horizontally with default profile
            tell last session of newWin
                set name to "📊 修复结果"
                write text "while true; do if [[ -f \"$result_file\" ]]; then cat \"$result_file\"; break; fi; sleep 2; done"
            end tell
        end tell
    end tell
end tell
APPLESCRIPT
}

launch_visual_tmux() {
    local cmd="$1"
    local session="openclaw-fix"
    log_info "使用 tmux 启动可视化修复..."
    tmux kill-session -t "$session" 2>/dev/null || true
    tmux new-session -d -s "$session" "$cmd"
    tmux split-window -h -t "$session" "tail -f /tmp/openclaw-quickfix.log"
    tmux split-window -v -t "$session" "cat /tmp/openclaw-fix-result.json 2>/dev/null || echo '等待结果...'"
    tmux attach-session -t "$session"
}

# ============================================
# 主逻辑
# ============================================

main() {
    local error_info="${1:-unknown_error}"
    local claude_cmd="claude -p \"你正在修复 OpenClaw Gateway 服务。错误: $error_info。请分析日志并修复配置。\" --allowedTools 'Read,Write,Edit,Bash'"

    if [[ "$OS_TYPE" == "macos" ]]; then
        launch_visual_iterm "$claude_cmd"
    else
        launch_visual_tmux "$claude_cmd"
    fi
}

main "$@"
