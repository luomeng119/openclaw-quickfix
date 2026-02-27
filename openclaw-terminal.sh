#!/usr/bin/env bash
# openclaw-terminal.sh - 跨平台终端启动器
#
# 描述: 为 SmartFix 提供可视化终端窗口
#       - macOS: 使用 iTerm2 (AppleScript)
#       - Linux/Windows: 使用 tmux
#
# 用法: openclaw-terminal.sh <命令> [选项]
#
# 作者: AI共学社 (AI Gongxueshe)
# 许可: MIT License
# 仓库: https://github.com/ai-gongxueshe/openclaw-quickfix

set -euo pipefail

# ============================================
# 版本信息
# ============================================
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="openclaw-terminal"

# ============================================
# 跨平台环境检测
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

# 颜色输出
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================
# iTerm2 支持 (macOS)
# ============================================

check_iterm2() {
    [[ "$OS_TYPE" != "macos" ]] && return 1
    [[ -d "/Applications/iTerm.app" ]] || [[ -d "$HOME/Applications/iTerm.app" ]]
}

launch_iterm2() {
    local main_command="$1"
    local log_file="${2:-/tmp/openclaw-fix.log}"
    local status_file="${3:-/tmp/openclaw-fix-result.json}"

    log_info "使用 iTerm2 启动可视化终端..."

    # AppleScript 创建分屏窗口
    osascript << APPLESCRIPT
tell application "iTerm2"
    activate

    -- 创建新窗口
    set newWindow to (create window with default profile)

    tell current session of newWindow
        -- 设置窗口标题
        set name to "🔧 OpenClaw SmartFix"

        -- 左侧窗格：运行主命令 (Claude Code)
        write text "echo '🤖 Claude Code 修复中...'; echo ''; $main_command"

        -- 垂直分割，创建右侧窗格
        split vertically with default profile

        -- 右侧窗格：显示日志
        tell last session of newWindow
            set name to "📋 实时日志"
            write text "echo '📋 实时日志监控'; echo ''; tail -f '$log_file' 2>/dev/null || echo '等待日志...'"

            -- 水平分割，创建右下窗格
            split horizontally with default profile

            -- 右下窗格：显示状态
            tell last session of newWindow
                set name to "📊 修复状态"
                write text "echo '📊 修复状态监控'; echo ''; echo '等待修复结果...'; while true; do if [[ -f '$status_file' ]]; then echo ''; echo '=== 修复结果 ==='; cat '$status_file' 2>/dev/null | python3 -m json.tool 2>/dev/null || cat '$status_file'; break; fi; sleep 2; done"
            end tell
        end tell
    end tell
end tell
APPLESCRIPT

    log_info "✅ iTerm2 终端已启动"
}

# ============================================
# tmux 支持 (Linux/Windows/通用)
# ============================================

check_tmux() {
    command -v tmux &>/dev/null
}

install_tmux_hint() {
    log_warn "未检测到 tmux"
    echo ""
    echo "安装方法:"
    case "$OS_TYPE" in
        macos)
            echo "  brew install tmux"
            ;;
        linux)
            echo "  Ubuntu/Debian: sudo apt install tmux"
            echo "  CentOS/RHEL:   sudo yum install tmux"
            echo "  Arch Linux:    sudo pacman -S tmux"
            ;;
        windows)
            echo "  Git Bash: 通过 MinGW 或 WSL 安装"
            echo "  WSL: sudo apt install tmux"
            ;;
    esac
    echo ""
}

launch_tmux() {
    local main_command="$1"
    local log_file="${2:-/tmp/openclaw-fix.log}"
    local status_file="${3:-/tmp/openclaw-fix-result.json}"

    log_info "使用 tmux 启动可视化终端..."

    local session_name="openclaw-smartfix"

    # 如果会话已存在，先关闭
    tmux kill-session -t "$session_name" 2>/dev/null || true

    # 创建新会话，运行主命令
    tmux new-session -d -s "$session_name" -x 160 -y 40 "$main_command"

    # 分割窗格
    # 右侧：日志监控
    tmux split-window -h -t "$session_name" "tail -f '$log_file' 2>/dev/null || echo '等待日志...'"

    # 右下：状态监控
    tmux split-window -v -t "$session_name" "echo '📊 修复状态监控'; while true; do if [[ -f '$status_file' ]]; then echo ''; echo '=== 修复结果 ==='; cat '$status_file' 2>/dev/null; break; fi; sleep 2; done"

    # 设置窗格标题（如果终端支持）
    tmux select-pane -t "$session_name:0.0" -T "🤖 Claude Code"
    tmux select-pane -t "$session_name:0.1" -T "📋 日志"
    tmux select-pane -t "$session_name:0.2" -T "📊 状态"

    # 选择主窗格
    tmux select-pane -t "$session_name:0.0"

    # 附加到会话
    if [[ -n "${TMUX:-}" ]]; then
        # 已经在 tmux 中，切换到新会话
        tmux switch-client -t "$session_name"
    else
        # 不在 tmux 中，需要在外部终端启动
        # 检测可用终端并启动
        launch_terminal_with_tmux "$session_name"
    fi

    log_info "✅ tmux 会话已启动: $session_name"
}

launch_terminal_with_tmux() {
    local session_name="$1"

    case "$OS_TYPE" in
        linux)
            # 尝试常见的终端模拟器
            local terminals=(
                "gnome-terminal -- tmux attach -t $session_name"
                "konsole -e tmux attach -t $session_name"
                "xterm -e tmux attach -t $session_name"
                "alacritty -e tmux attach -t $session_name"
            )

            for term_cmd in "${terminals[@]}"; do
                local term_name=$(echo "$term_cmd" | cut -d' ' -f1)
                if command -v "$term_name" &>/dev/null; then
                    $term_cmd &
                    return 0
                fi
            done

            log_warn "未检测到图形终端，请手动运行: tmux attach -t $session_name"
            tmux attach -t "$session_name"
            ;;

        windows)
            # Windows: 尝试 Windows Terminal 或 ConEmu
            if command -v wt.exe &>/dev/null; then
                wt.exe -p "Command Prompt" cmd.exe /k "tmux attach -t $session_name" &
            elif command -v ConEmu64.exe &>/dev/null; then
                ConEmu64.exe /cmd "tmux attach -t $session_name" &
            else
                log_warn "请手动运行: tmux attach -t $session_name"
                tmux attach -t "$session_name"
            fi
            ;;

        *)
            # 其他：直接附加
            tmux attach -t "$session_name"
            ;;
    esac
}

# ============================================
# 通用终端检测和启动
# ============================================

detect_and_launch() {
    local main_command="$1"
    local log_file="${2:-}"
    local status_file="${3:-}"

    log_info "检测可用终端..."

    case "$OS_TYPE" in
        macos)
            if check_iterm2; then
                log_info "✓ 检测到 iTerm2"
                launch_iterm2 "$main_command" "$log_file" "$status_file"
                return 0
            elif check_tmux; then
                log_info "✓ iTerm2 不可用，使用 tmux"
                launch_tmux "$main_command" "$log_file" "$status_file"
                return 0
            else
                log_warn "iTerm2 和 tmux 都不可用"
                install_tmux_hint
                return 1
            fi
            ;;

        linux)
            if check_tmux; then
                log_info "✓ 检测到 tmux"
                launch_tmux "$main_command" "$log_file" "$status_file"
                return 0
            else
                log_warn "tmux 不可用"
                install_tmux_hint
                return 1
            fi
            ;;

        windows)
            if check_tmux; then
                log_info "✓ 检测到 tmux"
                launch_tmux "$main_command" "$log_file" "$status_file"
                return 0
            else
                log_warn "tmux 不可用 (需要 Git Bash 或 WSL)"
                install_tmux_hint
                return 1
            fi
            ;;

        *)
            log_error "未知操作系统: $OS_TYPE"
            return 1
            ;;
    esac
}

# ============================================
# 帮助信息
# ============================================

show_help() {
    cat << EOF
$SCRIPT_NAME v$VERSION - 跨平台终端启动器

用法:
    $SCRIPT_NAME <命令> [选项]

选项:
    --log <file>      日志文件路径 (默认: /tmp/openclaw-fix.log)
    --status <file>   状态文件路径 (默认: /tmp/openclaw-fix-result.json)
    --help, -h        显示帮助信息
    --version, -v     显示版本号

示例:
    # 启动 Claude Code 修复
    $SCRIPT_NAME "claude -p '修复配置'"

    # 指定日志文件
    $SCRIPT_NAME "claude -p '修复'" --log /tmp/my.log

平台支持:
    - macOS: iTerm2 (优先) 或 tmux
    - Linux: tmux
    - Windows: tmux (需要 Git Bash 或 WSL)

分屏布局:
    ┌──────────────────────┬──────────────────────────────────┐
    │                      │                                  │
    │  主命令 (Claude Code)│  实时日志                        │
    │                      │  tail -f log                     │
    │                      │                                  │
    │                      ├──────────────────────────────────┤
    │                      │                                  │
    │                      │  修复状态                        │
    │                      │                                  │
    └──────────────────────┴──────────────────────────────────┘

更多信息: https://github.com/ai-gongxueshe/openclaw-quickfix
EOF
    exit 0
}

show_version() {
    echo "$SCRIPT_NAME v$VERSION"
    exit 0
}

# ============================================
# 主流程
# ============================================

main() {
    local main_command=""
    local log_file="/tmp/openclaw-fix.log"
    local status_file="/tmp/openclaw-fix-result.json"

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --log)
                log_file="$2"
                shift 2
                ;;
            --status)
                status_file="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                ;;
            --version|-v)
                show_version
                ;;
            -*)
                log_error "未知参数: $1"
                echo "使用 --help 查看帮助"
                exit 1
                ;;
            *)
                if [[ -z "$main_command" ]]; then
                    main_command="$1"
                else
                    main_command="$main_command $1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$main_command" ]]; then
        log_error "请指定要执行的命令"
        echo ""
        echo "用法: $SCRIPT_NAME <命令>"
        echo "示例: $SCRIPT_NAME \"claude -p '修复配置'\""
        echo ""
        echo "使用 --help 查看完整帮助"
        exit 1
    fi

    echo "=========================================="
    echo "🖥️  OpenClaw Terminal Launcher"
    echo "=========================================="
    echo "系统: $OS_TYPE"
    echo "命令: $main_command"
    echo "日志: $log_file"
    echo "状态: $status_file"
    echo ""

    detect_and_launch "$main_command" "$log_file" "$status_file"
}

main "$@"
