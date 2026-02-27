#!/usr/bin/env bash
# openclaw-fix.sh - SmartFix 智能修复脚本
#
# 描述: 当 QuickFix 无法自动修复时，调用 Claude Code CLI 进行 AI 智能修复
#       支持可视化终端窗口（macOS iTerm2 / 其他平台 tmux）
#
# 用法: openclaw-fix.sh [--no-visual] [错误信息]
#       通常由 openclaw-quickfix.sh 自动调用，无需手动执行
#
# 环境变量:
#   OPENCLAW_FIX_VISUAL        - 启用可视化终端 (true/false, 默认 true)
#   OPENCLAW_FIX_MAX_RETRIES   - 最大重试次数 (默认 2)
#   OPENCLAW_FIX_CLAUDE_TIMEOUT_SECS - Claude 超时秒数 (默认 600)
#
# 作者: AI共学社 (AI Gongxueshe)
# 许可: MIT License
# 仓库: https://github.com/ai-gongxueshe/openclaw-quickfix

set -euo pipefail

# ============================================
# 版本信息
# ============================================
readonly VERSION="1.1.0"
readonly SCRIPT_NAME="openclaw-fix"

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

# 跨平台 timeout 命令
if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
elif command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
else
    TIMEOUT_CMD="perl -e 'alarm shift; exec @ARGV' --"
fi

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

log() { echo -e "[$(date '+%H:%M:%S')] $1"; }
log_info() { log "${GREEN}[INFO]${NC} $1"; }
log_warn() { log "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }

# ============================================
# 动态路径检测
# ============================================

detect_openclaw_path() {
    if command -v openclaw &> /dev/null; then
        local cli_path
        cli_path=$(command -v openclaw 2>/dev/null || echo "")
        if [[ -n "$cli_path" ]]; then
            local real_path
            real_path=$(readlink -f "$cli_path" 2>/dev/null || echo "$cli_path")
            local base_path
            base_path=$(echo "$real_path" | sed 's|/bin/openclaw||' | sed 's|/lib/node_modules/openclaw/.*||')
            if [[ -d "$base_path/lib/node_modules/openclaw" ]]; then
                echo "$base_path/lib/node_modules/openclaw"
                return 0
            fi
        fi
    fi

    local paths=()
    case "$OS_TYPE" in
        macos)
            paths+=("/opt/homebrew/lib/node_modules/openclaw" "/usr/local/lib/node_modules/openclaw")
            ;;
        linux)
            paths+=("/usr/local/lib/node_modules/openclaw" "/usr/lib/node_modules/openclaw")
            ;;
    esac

    for p in "${paths[@]}"; do
        [[ -d "$p" ]] && echo "$p" && return 0
    done
    return 1
}

detect_config_path() {
    if [[ -n "${OPENCLAW_CONFIG:-}" ]]; then
        echo "$OPENCLAW_CONFIG"
    elif [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
        echo "$HOME/.openclaw/openclaw.json"
    else
        echo "$HOME/.openclaw/openclaw.json"
    fi
}

# ============================================
# 配置变量
# ============================================

OPENCLAW_PATH="${OPENCLAW_PATH:-$(detect_openclaw_path 2>/dev/null || echo "")}"
OPENCLAW_DOCS_DIR="${OPENCLAW_PATH}/docs"
OPENCLAW_DOCS_ZH="${OPENCLAW_DOCS_DIR}/zh-CN"

SERVICE_NAME="${OPENCLAW_SERVICE:-ai.openclaw.gateway}"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_CONFIG_PATH="$(detect_config_path)"

# 日志
LOG_DIR="${OPENCLAW_LOG_DIR:-/tmp/openclaw}"
LOG_DATE="$(date -u +%Y-%m-%d)"
LOG_FILE="${LOG_DIR}/openclaw-${LOG_DATE}.log"
RESULT_FILE="${XDG_RUNTIME_DIR:-/tmp}/openclaw-fix-result.json"

# SmartFix 配置
MAX_RETRIES="${OPENCLAW_FIX_MAX_RETRIES:-2}"
CLAUDE_TIMEOUT_SECS="${OPENCLAW_FIX_CLAUDE_TIMEOUT_SECS:-600}"

# 可视化终端配置
USE_VISUAL_TERMINAL="${OPENCLAW_FIX_VISUAL:-true}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 可选: Telegram 通知
TELEGRAM_TARGET="${OPENCLAW_FIX_TELEGRAM_TARGET:-}"

# 单实例锁
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/openclaw-fix.lock"
LOCK_DIR="${LOCK_FILE}.d"

# ============================================
# 锁机制
# ============================================

acquire_lock() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo $$ > "$LOCK_DIR/pid"
        return 0
    fi
    return 1
}

cleanup_lock() {
    rm -rf "$LOCK_DIR" 2>/dev/null || true
}

if ! acquire_lock; then
    echo "另一个 openclaw-fix 正在运行，退出。"
    exit 0
fi

trap cleanup_lock EXIT

# ============================================
# 工具函数
# ============================================

notify() {
    local msg="$1"
    [[ -z "$TELEGRAM_TARGET" ]] && return 0
    openclaw message send --channel telegram --target "$TELEGRAM_TARGET" --message "$msg" 2>/dev/null || true
}

write_result() {
    local status="$1" message="$2"
    cat > "$RESULT_FILE" <<EOF
{"status":"$status","message":"$message","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
    log_info "结果已保存: $RESULT_FILE"
}

find_claude() {
    local c
    c="$(command -v claude 2>/dev/null || true)"
    if [[ -n "$c" && -x "$c" ]]; then
        echo "$c"
        return 0
    fi
    for candidate in "$HOME/.local/bin/claude" "$HOME/.claude/local/claude" /usr/local/bin/claude; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    echo ""
}

# ============================================
# 可视化终端
# ============================================

check_iterm2() {
    [[ "$OS_TYPE" == "macos" ]] && [[ -d "/Applications/iTerm.app" || -d "$HOME/Applications/iTerm.app" ]]
}

check_tmux() {
    command -v tmux &>/dev/null
}

launch_iterm2_visual() {
    local claude_cmd="$1"

    log_info "使用 iTerm2 启动可视化终端..."

    osascript << APPLESCRIPT
tell application "iTerm2"
    activate
    set newWindow to (create window with default profile)

    tell current session of newWindow
        set name to "🔧 OpenClaw SmartFix"
        write text "echo '🤖 OpenClaw SmartFix - Claude Code 修复中...'; echo ''; echo '系统: $OS_TYPE'; echo '配置: $OPENCLAW_CONFIG_PATH'; echo ''; $claude_cmd"

        split vertically with default profile

        tell last session of newWindow
            set name to "📋 实时日志"
            write text "echo '📋 实时日志监控'; echo ''; mkdir -p '$(dirname "$LOG_FILE")' 2>/dev/null; tail -f '$LOG_FILE' 2>/dev/null || echo '等待日志...'"

            split horizontally with default profile

            tell last session of newWindow
                set name to "📊 修复状态"
                write text "echo '📊 修复状态监控'; echo ''; echo '等待修复结果...'; while true; do if [[ -f '$RESULT_FILE' ]]; then echo ''; echo '=== 修复结果 ==='; cat '$RESULT_FILE' 2>/dev/null; echo ''; break; fi; sleep 2; done"
            end tell
        end tell
    end tell
end tell
APPLESCRIPT

    return 0
}

launch_tmux_visual() {
    local claude_cmd="$1"
    local session_name="openclaw-smartfix"

    log_info "使用 tmux 启动可视化终端..."

    # 创建日志目录
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

    # 如果会话已存在，先关闭
    tmux kill-session -t "$session_name" 2>/dev/null || true

    # 创建新会话
    tmux new-session -d -s "$session_name" -x 160 -y 40 "echo '🤖 OpenClaw SmartFix'; echo ''; $claude_cmd"

    # 分割窗格
    tmux split-window -h -t "$session_name" "tail -f '$LOG_FILE' 2>/dev/null || echo '等待日志...'"
    tmux split-window -v -t "$session_name" "while true; do if [[ -f '$RESULT_FILE' ]]; then echo '=== 修复结果 ==='; cat '$RESULT_FILE'; break; fi; sleep 2; done"

    # 选择主窗格
    tmux select-pane -t "$session_name:0.0"

    # 附加到会话
    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$session_name"
    else
        # 尝试启动外部终端
        case "$OS_TYPE" in
            linux)
                if command -v gnome-terminal &>/dev/null; then
                    gnome-terminal -- tmux attach -t "$session_name" &
                elif command -v xterm &>/dev/null; then
                    xterm -e "tmux attach -t $session_name" &
                else
                    tmux attach -t "$session_name"
                fi
                ;;
            windows)
                if command -v wt.exe &>/dev/null; then
                    wt.exe -p "Command Prompt" cmd.exe /k "tmux attach -t $session_name" &
                else
                    tmux attach -t "$session_name"
                fi
                ;;
            *)
                tmux attach -t "$session_name"
                ;;
        esac
    fi

    return 0
}

launch_visual_terminal() {
    local claude_cmd="$1"

    # 检查是否禁用可视化
    if [[ "$USE_VISUAL_TERMINAL" != "true" ]]; then
        log_info "可视化终端已禁用"
        return 1
    fi

    case "$OS_TYPE" in
        macos)
            if check_iterm2; then
                launch_iterm2_visual "$claude_cmd"
                return $?
            elif check_tmux; then
                launch_tmux_visual "$claude_cmd"
                return $?
            else
                log_warn "iTerm2 和 tmux 都不可用"
                return 1
            fi
            ;;
        linux|windows)
            if check_tmux; then
                launch_tmux_visual "$claude_cmd"
                return $?
            else
                log_warn "tmux 不可用"
                echo ""
                echo "安装方法:"
                case "$OS_TYPE" in
                    linux) echo "  Ubuntu/Debian: sudo apt install tmux" ;;
                    windows) echo "  通过 Git Bash 或 WSL 安装 tmux" ;;
                esac
                return 1
            fi
            ;;
        *)
            log_warn "未知操作系统: $OS_TYPE"
            return 1
            ;;
    esac
}

# ============================================
# 上下文收集
# ============================================

collect_docs_context() {
    local context=""

    echo "📚 准备修复上下文..."

    if [[ -f "$OPENCLAW_CONFIG_PATH" ]]; then
        echo "   - 加载当前配置..."
        context+="================================================================================
当前配置
文件: $OPENCLAW_CONFIG_PATH
================================================================================
"
        context+="$(cat "$OPENCLAW_CONFIG_PATH")
"
    fi

    echo "   ✓ 上下文准备完成"
    echo "$context"
}

collect_errors() {
    local errors=""
    if [[ -f "$LOG_FILE" ]]; then
        errors+=$(tail -80 "$LOG_FILE" 2>/dev/null | grep -i "error\|fatal\|invalid\|failed\|EADDRINUSE" | tail -20 || true)
    fi

    echo "=== 日志错误 ==="
    echo "$errors"
    echo ""

    case "$OS_TYPE" in
        macos)
            echo "=== macOS 系统日志 (node 进程, 最近 5 分钟) ==="
            log show --predicate 'process == "node"' --last 5m --style syslog 2>/dev/null | tail -40 || echo "无最近日志"
            ;;
        linux)
            echo "=== systemd 日志 ==="
            journalctl --user -u "$SERVICE_NAME" --since "5 minutes ago" 2>/dev/null | tail -40 || echo "无最近日志"
            ;;
    esac
}

validate_config_json() {
    if [[ -f "$OPENCLAW_CONFIG_PATH" ]]; then
        python3 -m json.tool "$OPENCLAW_CONFIG_PATH" >/dev/null 2>&1
    fi
}

# ============================================
# 服务管理
# ============================================

restart_and_check() {
    case "$OS_TYPE" in
        macos)
            launchctl kickstart -k gui/$(id -u)/"$SERVICE_NAME" 2>/dev/null || true
            sleep 8
            launchctl list "$SERVICE_NAME" 2>/dev/null | grep -q '"PID"'
            ;;
        linux)
            if command -v systemctl &>/dev/null; then
                systemctl --user restart "$SERVICE_NAME" 2>/dev/null || \
                sudo systemctl restart "$SERVICE_NAME" 2>/dev/null || true
                sleep 8
            fi
            if command -v openclaw &>/dev/null; then
                openclaw gateway restart 2>/dev/null || true
            fi
            return 0
            ;;
        windows)
            if command -v openclaw &>/dev/null; then
                openclaw gateway restart 2>/dev/null || true
            elif command -v net &>/dev/null; then
                net stop "$SERVICE_NAME" 2>/dev/null || true
                net start "$SERVICE_NAME" 2>/dev/null || true
            fi
            return 0
            ;;
        *)
            if command -v openclaw &>/dev/null; then
                openclaw gateway restart 2>/dev/null || true
            fi
            return 0
            ;;
    esac
}

# ============================================
# 帮助信息
# ============================================

show_help() {
    cat << EOF
$SCRIPT_NAME v$VERSION - SmartFix 智能修复脚本

用法:
    $SCRIPT_NAME [选项]

选项:
    --no-visual     禁用可视化终端，使用普通模式
    --help, -h      显示帮助信息
    --version, -v   显示版本号

环境变量:
    OPENCLAW_FIX_VISUAL         启用可视化终端 (默认: true)
    OPENCLAW_FIX_MAX_RETRIES    最大重试次数 (默认: 2)
    OPENCLAW_FIX_CLAUDE_TIMEOUT_SECS  Claude 超时秒数 (默认: 600)

可视化终端支持:
    - macOS: iTerm2 (优先) 或 tmux
    - Linux/Windows: tmux

更多信息: https://github.com/ai-gongxueshe/openclaw-quickfix
EOF
    exit 0
}

show_version() {
    echo "$SCRIPT_NAME v$VERSION"
    exit 0
}

# ============================================
# 参数解析
# ============================================

NO_VISUAL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-visual)
            NO_VISUAL=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        --version|-v)
            show_version
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "$NO_VISUAL" == "true" ]]; then
    USE_VISUAL_TERMINAL="false"
fi

# ============================================
# 主流程
# ============================================

echo "=========================================="
echo "🔧 OpenClaw SmartFix 智能修复"
echo "=========================================="
echo "版本: $VERSION"
echo "系统: $OS_TYPE"
echo "服务: $SERVICE_NAME"
echo "配置: $OPENCLAW_CONFIG_PATH"
echo "可视化: $USE_VISUAL_TERMINAL"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查 OpenClaw 路径
if [[ -z "$OPENCLAW_PATH" ]]; then
    log_warn "无法检测到 OpenClaw 安装路径"
fi

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# 收集错误上下文
echo "📋 收集错误上下文..."
ERROR_CONTEXT="$(collect_errors)"
echo ""

# 收集文档上下文
echo "📚 收集配置信息..."
DOCS_CONTEXT="$(collect_docs_context)"
echo ""

# 验证配置 JSON
if [[ -f "$OPENCLAW_CONFIG_PATH" ]]; then
    if ! validate_config_json; then
        notify "🔴 Gateway 配置 JSON 无效: $OPENCLAW_CONFIG_PATH"
        write_result "invalid-config" "无效的 JSON: $OPENCLAW_CONFIG_PATH"
        exit 1
    fi
fi

# 查找 Claude Code
CLAUDE_CODE="$(find_claude)"
if [[ -z "$CLAUDE_CODE" ]]; then
    notify "🔴 $SERVICE_NAME 失败。未找到 Claude Code，无法执行 SmartFix。"
    write_result "no-claude" "未找到 Claude Code"
    echo ""
    echo "❌ 未找到 Claude Code CLI"
    echo ""
    echo "安装方法: https://docs.anthropic.com/claude-code"
    exit 1
fi

notify "🔧 $SERVICE_NAME 失败。正在通过 Claude Code 进行 SmartFix..."
echo "🤖 Claude Code 已找到: $CLAUDE_CODE"
echo ""

# 构建修复提示
FIX_PROMPT="你正在修复一个失败的 OpenClaw Gateway 服务。

## 官方文档（必须参考）
请首先阅读以下官方文档目录获取正确的配置知识：
- 中文文档: $OPENCLAW_DOCS_ZH/
- 英文文档: $OPENCLAW_DOCS_DIR/

关键文档：
- $OPENCLAW_DOCS_ZH/gateway/troubleshooting.md
- $OPENCLAW_DOCS_ZH/cli/config.md
- $OPENCLAW_DOCS_ZH/concepts/model-providers.md

## 服务信息
- 服务名: $SERVICE_NAME
- 端口: $GATEWAY_PORT
- 配置文件: $OPENCLAW_CONFIG_PATH

## 错误日志
$ERROR_CONTEXT

## 当前配置
$DOCS_CONTEXT

## 任务
1. 阅读官方文档了解正确配置
2. 分析错误原因
3. 最小化修改修复问题
4. 验证 JSON 语法: python3 -m json.tool $OPENCLAW_CONFIG_PATH
5. 重启服务（根据系统选择命令）

## 规则
- 必须参考官方文档，不要凭猜测修改
- 最小化改动
- 修改后验证 JSON 语法
- 说明修改原因并引用文档"

# 构建 Claude Code 命令
CLAUDE_CMD="$CLAUDE_CODE -p \"$FIX_PROMPT\" --allowedTools 'Read,Write,Edit,Bash' --max-turns 15"

# 尝试使用可视化终端
VISUAL_LAUNCHED=false
if launch_visual_terminal "$CLAUDE_CMD"; then
    VISUAL_LAUNCHED=true
    echo ""
    echo "=========================================="
    echo "🖥️  可视化终端已启动"
    echo "=========================================="
    echo ""
    echo "📍 请在弹出的终端窗口中查看修复过程"
    echo "   - 左侧窗格: Claude Code 修复输出"
    echo "   - 右上窗格: 实时日志"
    echo "   - 右下窗格: 修复状态"
    echo ""
    echo "⏳ 等待修复完成..."

    # 等待结果文件生成
    local wait_time=0
    while [[ $wait_time -lt $CLAUDE_TIMEOUT_SECS ]]; do
        if [[ -f "$RESULT_FILE" ]]; then
            local status=$(grep -o '"status":"[^"]*"' "$RESULT_FILE" 2>/dev/null | cut -d'"' -f4)
            if [[ -n "$status" ]]; then
                break
            fi
        fi
        sleep 5
        ((wait_time += 5))
        printf "."
    done
    echo ""

    if [[ -f "$RESULT_FILE" ]]; then
        local final_status=$(grep -o '"status":"[^"]*"' "$RESULT_FILE" 2>/dev/null | cut -d'"' -f4)
        if [[ "$final_status" == "ok" ]]; then
            echo ""
            echo "✅ 修复成功！（可视化终端）"
            notify "✅ Gateway SmartFix 修复成功"
            exit 0
        fi
    fi

    log_warn "可视化终端超时或用户已关闭窗口"
fi

# 普通模式执行
if [[ "$VISUAL_LAUNCHED" != "true" ]]; then
    echo "📝 使用普通模式执行..."
    echo ""

    for attempt in $(seq 1 "$MAX_RETRIES"); do
        echo "=========================================="
        echo "🔁 修复尝试 #$attempt / $MAX_RETRIES"
        echo "=========================================="
        echo ""

        TEMP_OUTPUT=$(mktemp)

        echo "⏳ 运行 Claude Code (超时: ${CLAUDE_TIMEOUT_SECS}s)..."
        echo ""

        set +e
        eval "$TIMEOUT_CMD $CLAUDE_TIMEOUT_SECS $CLAUDE_CMD" 2>&1 | tee "$TEMP_OUTPUT"
        CLAUDE_EXIT_CODE=$?
        set -e

        echo ""
        echo "📄 Claude Code 输出 (已保存: $TEMP_OUTPUT)"
        echo ""

        # 验证配置
        if [[ -f "$OPENCLAW_CONFIG_PATH" ]]; then
            if ! validate_config_json; then
                echo "❌ 修复尝试 $attempt 生成了无效的 JSON"
                notify "🔴 修复尝试 $attempt 生成了无效的 JSON。不重启。"
                rm -f "$TEMP_OUTPUT"
                continue
            fi
        fi

        # 重启并验证
        echo "🔄 重启服务..."
        if restart_and_check; then
            echo "✅ 服务重启成功"
            notify "✅ Gateway SmartFix 修复成功 (尝试 $attempt)。"
            write_result "ok" "在第 $attempt 次尝试时修复成功。"
            rm -f "$TEMP_OUTPUT"
            exit 0
        else
            echo "❌ 服务重启失败"
        fi

        # 刷新错误上下文
        ERROR_CONTEXT="$(collect_errors)"
        rm -f "$TEMP_OUTPUT"
    done

    echo ""
    echo "=========================================="
    echo "❌ SmartFix 在 $MAX_RETRIES 次尝试后失败"
    echo "=========================================="
    echo ""
    echo "需要手动干预。请检查:"
    echo "  - 错误日志: tail -f ~/.openclaw/logs/gateway.err.log"
    case "$OS_TYPE" in
        macos) echo "  - 服务状态: launchctl list $SERVICE_NAME" ;;
        linux) echo "  - 服务状态: systemctl --user status $SERVICE_NAME" ;;
    esac
    echo ""

    notify "🔴 Gateway SmartFix 在 $MAX_RETRIES 次尝试后失败。需要手动干预。"
    write_result "failed" "在 $MAX_RETRIES 次尝试后失败"
    exit 1
fi
