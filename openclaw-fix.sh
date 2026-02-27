#!/usr/bin/env bash
# openclaw-fix.sh - SmartFix 智能修复脚本
#
# 描述: 当 QuickFix 无法自动修复时，调用 Claude Code CLI 进行 AI 智能修复
# 用法: openclaw-fix.sh [错误信息]
#       通常由 openclaw-quickfix.sh 自动调用，无需手动执行
#
# 作者: AI共学社 (AI Gongxueshe)
# 许可: MIT License
# 仓库: https://github.com/ai-gongxueshe/openclaw-quickfix

set -euo pipefail

# ============================================
# 版本信息
# ============================================
readonly VERSION="1.0.0"
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

# ============================================
# 动态路径检测
# ============================================

detect_openclaw_path() {
    # 1. 通过命令获取
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

    # 2. 常见安装路径
    local paths=()
    case "$OS_TYPE" in
        macos)
            paths+=(
                "/opt/homebrew/lib/node_modules/openclaw"
                "/usr/local/lib/node_modules/openclaw"
            )
            ;;
        linux)
            paths+=(
                "/usr/local/lib/node_modules/openclaw"
                "/usr/lib/node_modules/openclaw"
            )
            ;;
        windows)
            paths+=(
                "/c/Program Files/nodejs/node_modules/openclaw"
            )
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
# 配置变量（支持环境变量覆盖）
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

# SmartFix 配置
MAX_RETRIES="${OPENCLAW_FIX_MAX_RETRIES:-2}"
CLAUDE_TIMEOUT_SECS="${OPENCLAW_FIX_CLAUDE_TIMEOUT_SECS:-600}"

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
    local out="${XDG_RUNTIME_DIR:-/tmp}/openclaw-fix-result.json"
    cat > "$out" <<EOF
{"status":"$status","message":"$message","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
    echo "[openclaw-fix] 结果已保存: $out"
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

    # 系统日志
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
            # 备用: CLI
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
# 主流程
# ============================================

echo "=========================================="
echo "🔧 OpenClaw SmartFix 智能修复"
echo "=========================================="
echo "版本: $VERSION"
echo "系统: $OS_TYPE"
echo "服务: $SERVICE_NAME"
echo "配置: $OPENCLAW_CONFIG_PATH"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查 OpenClaw 路径
if [[ -z "$OPENCLAW_PATH" ]]; then
    echo "⚠️  无法检测到 OpenClaw 安装路径"
    echo "   请设置环境变量: export OPENCLAW_PATH=/path/to/openclaw"
fi

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

# 执行修复尝试
for attempt in $(seq 1 "$MAX_RETRIES"); do
    echo "=========================================="
    echo "🔁 修复尝试 #$attempt / $MAX_RETRIES"
    echo "=========================================="
    echo ""

    TEMP_OUTPUT=$(mktemp)

    echo "⏳ 运行 Claude Code (超时: ${CLAUDE_TIMEOUT_SECS}s)..."
    echo ""

    set +e
    $TIMEOUT_CMD "$CLAUDE_TIMEOUT_SECS" "$CLAUDE_CODE" -p "$FIX_PROMPT" \
        --allowedTools "Read,Write,Edit,Bash" \
        --max-turns 15 \
        2>&1 | tee "$TEMP_OUTPUT"
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
        write_result "ok" "在第 $attempt 次尝试时修复成功。输出: $TEMP_OUTPUT"
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
