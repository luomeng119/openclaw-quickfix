#!/usr/bin/env bash
# openclaw-terminal.sh - 智能动态分屏终端启动器
#
# 描述: 根据任务复杂度自动决定分屏布局
#       - macOS: iTerm (优先) 或 tmux
#       - Linux/Windows: tmux
#
# 用法: openclaw-terminal.sh [选项] -- <命令>
#
# 作者: AI共学社 (AI Gongxueshe)
# 许可: MIT License

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
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

# 颜色
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
    BLUE='\033[0;34m' CYAN='\033[0;36m' NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

log() { echo -e "[$(date '+%H:%M:%S')] $1"; }
log_info() { log "${GREEN}[INFO]${NC} $1"; }
log_warn() { log "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }

# ============================================
# AppleScript 转义工具
# ============================================

# 转义命令以供 AppleScript 使用
# 处理双引号、反斜杠等特殊字符
escape_for_applescript() {
    local str="$1"
    # 转义反斜杠
    str="${str//\\/\\\\}"
    # 转义双引号
    str="${str//\"/\\\"}"
    echo "$str"
}

# ============================================
# 窗格命令模板
# ============================================

get_pane_command_main() {
    local cmd="$1"
    echo "$cmd"
}

get_pane_command_log() {
    local log_file="${1:-/tmp/openclaw/gateway.log}"
    # 简化命令，避免复杂的 shell 语法
    echo "mkdir -p $(dirname "$log_file") 2>/dev/null; echo 'Log Monitor'; tail -f $log_file 2>/dev/null || echo 'Waiting for log...'"
}

get_pane_command_status() {
    local status_file="${1:-/tmp/openclaw-fix-result.json}"
    # 简化命令
    echo "echo 'Status Monitor'; while true; do test -f $status_file && { clear; echo '=== Result ==='; cat $status_file 2>/dev/null; break; }; sleep 2; done"
}

get_pane_command_config() {
    local config_file="${1:-$HOME/.openclaw/openclaw.json}"
    # 简化命令
    echo "echo 'Config File'; test -f $config_file && cat $config_file || echo 'No config found'"
}

get_pane_command_service() {
    local service="${1:-ai.openclaw.gateway}"
    # 跨平台服务检查
    if [[ "$OS_TYPE" == "macos" ]]; then
        echo "echo 'Service: $service'; launchctl list $service 2>/dev/null || echo 'Service status unknown'"
    else
        echo "echo 'Service: $service'; systemctl --user status $service 2>/dev/null || echo 'Service status unknown'"
    fi
}

get_pane_command_network() {
    local port="${1:-18789}"
    if [[ "$OS_TYPE" == "macos" ]]; then
        echo "echo 'Port: $port'; lsof -i :$port 2>/dev/null || echo 'Port not in use'"
    else
        echo "echo 'Port: $port'; ss -tlnp 2>/dev/null | grep :$port || netstat -tlnp 2>/dev/null | grep :$port || echo 'Port not in use'"
    fi
}

# ============================================
# 任务复杂度分析
# ============================================

analyze_task_complexity() {
    local command="$1"
    local pane_count=2  # 至少 2 个窗格
    local panes=("main")

    # 检测任务类型
    if [[ "$command" =~ (claude|fix|repair|smartfix) ]]; then
        panes+=("status")
        ((pane_count++))
    fi

    if [[ "$command" =~ (gateway|service|daemon|server|start|restart) ]]; then
        panes+=("log")
        panes+=("service")
        pane_count=$((pane_count + 2))
    fi

    if [[ "$command" =~ (debug|verbose|-v|--debug) ]]; then
        panes+=("config")
        panes+=("network")
        pane_count=$((pane_count + 2))
    fi

    # 限制最多 6 个
    [[ $pane_count -gt 6 ]] && pane_count=6
    [[ $pane_count -lt 2 ]] && pane_count=2

    echo "$pane_count ${panes[*]}"
}

# ============================================
# iTerm 布局 (macOS)
# ============================================

check_iterm() {
    [[ "$OS_TYPE" == "macos" ]] && [[ -d "/Applications/iTerm.app" || -d "$HOME/Applications/iTerm.app" ]]
}

get_iterm_name() {
    if [[ -d "/Applications/iTerm2.app" ]] || [[ -d "$HOME/Applications/iTerm2.app" ]]; then
        echo "iTerm2"
    else
        echo "iTerm"
    fi
}

launch_iterm_2panes() {
    local cmd1="$1"
    local cmd2="$2"
    local iterm_name
    iterm_name=$(get_iterm_name)

    # 转义命令中的特殊字符
    local escaped_cmd1 escaped_cmd2
    escaped_cmd1=$(escape_for_applescript "$cmd1")
    escaped_cmd2=$(escape_for_applescript "$cmd2")

    osascript << APPLESCRIPT
tell application "$iterm_name"
    activate
    -- 使用 command 参数直接执行主命令（最可靠的方法）
    set newWindow to (create window with default profile command "bash -l -c \"$escaped_cmd1\"")

    tell current session of newWindow
        set splitPane to (split vertically with default profile)

        tell splitPane
            write text "$escaped_cmd2" with newline
        end tell
    end tell
end tell
APPLESCRIPT
}

launch_iterm_3panes() {
    local cmd1="$1"
    local cmd2="$2"
    local cmd3="$3"
    local iterm_name
    iterm_name=$(get_iterm_name)

    # 转义命令中的特殊字符
    local escaped_cmd1 escaped_cmd2 escaped_cmd3
    escaped_cmd1=$(escape_for_applescript "$cmd1")
    escaped_cmd2=$(escape_for_applescript "$cmd2")
    escaped_cmd3=$(escape_for_applescript "$cmd3")

    osascript << APPLESCRIPT
tell application "$iterm_name"
    activate
    -- 使用 command 参数直接执行主命令
    set newWindow to (create window with default profile command "bash -l -c \"$escaped_cmd1\"")

    tell current session of newWindow
        set rightPane to (split vertically with default profile)

        tell rightPane
            write text "$escaped_cmd2" with newline

            set bottomPane to (split horizontally with default profile)

            tell bottomPane
                write text "$escaped_cmd3" with newline
            end tell
        end tell
    end tell
end tell
APPLESCRIPT
}

launch_iterm_4panes() {
    local cmd1="$1"
    local cmd2="$2"
    local cmd3="$3"
    local cmd4="$4"
    local iterm_name
    iterm_name=$(get_iterm_name)

    # 转义命令中的特殊字符
    local escaped_cmd1 escaped_cmd2 escaped_cmd3 escaped_cmd4
    escaped_cmd1=$(escape_for_applescript "$cmd1")
    escaped_cmd2=$(escape_for_applescript "$cmd2")
    escaped_cmd3=$(escape_for_applescript "$cmd3")
    escaped_cmd4=$(escape_for_applescript "$cmd4")

    osascript << APPLESCRIPT
tell application "$iterm_name"
    activate
    -- 使用 command 参数直接执行主命令
    set newWindow to (create window with default profile command "bash -l -c \"$escaped_cmd1\"")

    tell current session of newWindow
        set rightTop to (split vertically with default profile)

        tell rightTop
            write text "$escaped_cmd2" with newline

            set rightBottom to (split horizontally with default profile)

            tell rightBottom
                write text "$escaped_cmd3" with newline

                set leftBottom to (split horizontally with default profile)

                tell leftBottom
                    write text "$escaped_cmd4" with newline
                end tell
            end tell
        end tell
    end tell
end tell
APPLESCRIPT
}

launch_iterm_6panes() {
    local cmds=("$@")
    local iterm_name
    iterm_name=$(get_iterm_name)

    # 转义所有命令
    local escaped_cmds=()
    for cmd in "${cmds[@]}"; do
        escaped_cmds+=("$(escape_for_applescript "$cmd")")
    done

    osascript << APPLESCRIPT
tell application "$iterm_name"
    activate
    -- 使用 command 参数直接执行主命令
    set newWindow to (create window with default profile command "bash -l -c \"${escaped_cmds[0]:-echo main}\"")

    tell current session of newWindow
        set col2 to (split vertically with default profile)

        tell col2
            write text "${escaped_cmds[1]:-echo log}" with newline

            set col3 to (split vertically with default profile)

            tell col3
                write text "${escaped_cmds[2]:-echo status}" with newline

                set row2 to (split horizontally with default profile)

                tell row2
                    write text "${escaped_cmds[3]:-echo config}" with newline

                    set row3 to (split horizontally with default profile)

                    tell row3
                        write text "${escaped_cmds[4]:-echo service}" with newline

                        set row4 to (split horizontally with default profile)

                        tell row4
                            write text "${escaped_cmds[5]:-echo network}" with newline
                        end tell
                    end tell
                end tell
            end tell
        end tell
    end tell
end tell
APPLESCRIPT
}

# ============================================
# tmux 布局 (Linux/Windows)
# ============================================

check_tmux() {
    command -v tmux &>/dev/null
}

launch_tmux_layout() {
    local pane_count="$1"
    shift
    local pane_commands=("$@")

    local session_name="openclaw-$(date +%s)"

    log_info "使用 tmux 启动 $pane_count 窗格..."

    mkdir -p /tmp/openclaw 2>/dev/null || true

    tmux kill-session -t "$session_name" 2>/dev/null || true

    tmux new-session -d -s "$session_name" -x 180 -y 50 "${pane_commands[0]}"

    case "$pane_count" in
        2)
            tmux split-window -h -t "$session_name" "${pane_commands[1]}"
            ;;
        3)
            tmux split-window -h -t "$session_name" "${pane_commands[1]}"
            tmux split-window -v -t "$session_name" "${pane_commands[2]}"
            ;;
        4)
            tmux split-window -h -t "$session_name" "${pane_commands[1]}"
            tmux split-window -v -t "$session_name:0.0" "${pane_commands[2]}"
            tmux split-window -v -t "$session_name:0.1" "${pane_commands[3]}"
            ;;
        5|6)
            tmux split-window -h -t "$session_name" "${pane_commands[1]}"
            tmux split-window -v -t "$session_name:0.0" "${pane_commands[2]:-echo 'pane3'}"
            tmux split-window -v -t "$session_name:0.1" "${pane_commands[3]:-echo 'pane4'}"
            tmux split-window -v -t "$session_name:0.2" "${pane_commands[4]:-echo 'pane5'}"
            if [[ $pane_count -ge 6 ]]; then
                tmux split-window -v -t "$session_name:0.3" "${pane_commands[5]}"
            fi
            ;;
    esac

    tmux select-pane -t "$session_name:0.0"

    # 附加
    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$session_name"
    else
        case "$OS_TYPE" in
            linux)
                if command -v gnome-terminal &>/dev/null; then
                    gnome-terminal -- tmux attach -t "$session_name" &
                else
                    tmux attach -t "$session_name"
                fi
                ;;
            *)
                tmux attach -t "$session_name"
                ;;
        esac
    fi
}

# ============================================
# 帮助信息
# ============================================

show_help() {
    cat << EOF
$SCRIPT_NAME v$VERSION - 智能动态分屏终端启动器

用法:
    $SCRIPT_NAME [选项] -- <命令>

选项:
    --panes <n>        指定窗格数量 (2-6)
    --layout <type>    布局: auto/simple/standard/complex/debug
    --log <file>       日志文件
    --config <file>    配置文件
    --help, -h         帮助
    --version, -v      版本

布局类型:
    auto     自动选择 (默认)
    simple   2 窗格
    standard 3 窗格
    complex  4 窗格
    debug    6 窗格

示例:
    $SCRIPT_NAME -- "claude -p '修复'"
    $SCRIPT_NAME --panes 4 -- "claude -p '复杂修复'"
    $SCRIPT_NAME --debug -- "openclaw gateway restart"

平台:
    - macOS: iTerm
    - Linux/Windows: tmux
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
    local layout_type="auto"
    local pane_count=0

    local log_file="/tmp/openclaw/gateway.log"
    local config_file="$HOME/.openclaw/openclaw.json"
    local status_file="/tmp/openclaw-fix-result.json"
    local service_name="ai.openclaw.gateway"
    local gateway_port="18789"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --panes) pane_count="$2"; shift 2 ;;
            --layout) layout_type="$2"; shift 2 ;;
            --log) log_file="$2"; shift 2 ;;
            --config) config_file="$2"; shift 2 ;;
            --status) status_file="$2"; shift 2 ;;
            --service) service_name="$2"; shift 2 ;;
            --port) gateway_port="$2"; shift 2 ;;
            --help|-h) show_help ;;
            --version|-v) show_version ;;
            --) shift; main_command="$*"; break ;;
            *) [[ -z "$main_command" ]] && main_command="$1" || main_command="$main_command $1"; shift ;;
        esac
    done

    [[ -z "$main_command" ]] && { log_error "请指定命令"; exit 1; }

    echo "=========================================="
    echo "🖥️  OpenClaw 智能终端启动器"
    echo "=========================================="
    echo "系统: $OS_TYPE"
    echo "命令: $main_command"
    echo ""

    # 分析任务
    if [[ $pane_count -eq 0 && "$layout_type" == "auto" ]]; then
        local analysis
        analysis=$(analyze_task_complexity "$main_command")
        pane_count=$(echo "$analysis" | cut -d' ' -f1)
        log_info "任务分析: 需要 $pane_count 个窗格"
    fi

    # 确定布局
    case "$layout_type" in
        auto) [[ $pane_count -eq 0 ]] && pane_count=3 ;;
        simple) pane_count=2 ;;
        standard) pane_count=3 ;;
        complex) pane_count=4 ;;
        debug) pane_count=6 ;;
    esac

    log_info "布局: $layout_type ($pane_count 窗格)"

    # 构建窗格命令
    local pane_commands=()
    pane_commands+=("$(get_pane_command_main "$main_command")")
    [[ $pane_count -ge 2 ]] && pane_commands+=("$(get_pane_command_log "$log_file")")
    [[ $pane_count -ge 3 ]] && pane_commands+=("$(get_pane_command_status "$status_file")")
    [[ $pane_count -ge 4 ]] && pane_commands+=("$(get_pane_command_config "$config_file")")
    [[ $pane_count -ge 5 ]] && pane_commands+=("$(get_pane_command_service "$service_name")")
    [[ $pane_count -ge 6 ]] && pane_commands+=("$(get_pane_command_network "$gateway_port")")

    # 启动
    case "$OS_TYPE" in
        macos)
            if check_iterm; then
                case "$pane_count" in
                    2) launch_iterm_2panes "${pane_commands[@]}" ;;
                    3) launch_iterm_3panes "${pane_commands[@]}" ;;
                    4) launch_iterm_4panes "${pane_commands[@]}" ;;
                    *) launch_iterm_6panes "${pane_commands[@]}" ;;
                esac
            elif check_tmux; then
                launch_tmux_layout "$pane_count" "${pane_commands[@]}"
            else
                log_error "iTerm 和 tmux 都不可用"
                exit 1
            fi
            ;;
        *)
            if check_tmux; then
                launch_tmux_layout "$pane_count" "${pane_commands[@]}"
            else
                log_error "tmux 不可用"
                exit 1
            fi
            ;;
    esac

    log_info "✅ 终端已启动"
}

main "$@"
