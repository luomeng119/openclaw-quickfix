#!/usr/bin/env bash
# openclaw-terminal.sh - 智能动态分屏终端启动器
#
# 描述: 根据任务复杂度自动决定分屏布局
#       - macOS: iTerm (优先) 或 tmux
#       - Linux/Windows: tmux

set -euo pipefail

# ============================================
# 版本信息
# ============================================
readonly VERSION="1.1.0"
readonly SCRIPT_NAME="openclaw-terminal"

# ============================================
# 环境检测
# ============================================

detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
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
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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
# 布局模板
# ============================================

launch_iterm_layout() {
    local cmd1=$(escape_for_applescript "$1")
    local cmd2=$(escape_for_applescript "$2")
    local cmd3=$(escape_for_applescript "$3")
    local iterm_name=$(get_iterm_name)

    log_info "使用 $iterm_name 启动 3-窗格 布局..."

    osascript << APPLESCRIPT
tell application "$iterm_name"
    activate
    set newWin to (create window with default profile)
    tell current session of newWin
        set name to "�� Main Task"
        write text "$cmd1"
        
        split vertically with default profile
        tell last session of newWin
            set name to "📋 Monitor"
            write text "$cmd2"
            
            split horizontally with default profile
            tell last session of newWin
                set name to "📊 Status"
                write text "$cmd3"
            end tell
        end tell
    end tell
end tell
APPLESCRIPT
}

launch_tmux_layout() {
    local cmd1="$1"
    local cmd2="$2"
    local cmd3="$3"
    local session="openclaw-$(date +%s)"

    log_info "使用 tmux 启动 3-窗格 布局..."
    tmux new-session -d -s "$session" "$cmd1"
    tmux split-window -h -t "$session" "$cmd2"
    tmux split-window -v -t "$session" "$cmd3"
    tmux attach-session -t "$session"
}

# ============================================
# 主逻辑
# ============================================

main() {
    local main_cmd="${1:-echo 'No command'}"
    local log_cmd="tail -f /tmp/openclaw-quickfix.log 2>/dev/null || echo 'Waiting for logs...'"
    local status_cmd="watch -n 1 'openclaw gateway status 2>/dev/null || echo \"Gateway Offline\"'"

    if [[ "$OS_TYPE" == "macos" ]]; then
        launch_iterm_layout "$main_cmd" "$log_cmd" "$status_cmd"
    else
        launch_tmux_layout "$main_cmd" "$log_cmd" "$status_cmd"
    fi
}

main "$@"
