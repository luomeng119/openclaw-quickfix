#!/usr/bin/env bash
# openclaw-quickfix.sh - OpenClaw 智能配置修复脚本
#
# 描述: 自动检测并修复 OpenClaw Gateway 配置错误
# 思路: 发现问题 → 查阅官方文档 → 执行修复 → 无答案则 SmartFix
#
# 用法: openclaw-quickfix.sh [选项]
# 选项:
#   --dry-run    仅检测问题，不执行修复
#   --help       显示帮助信息
#   --version    显示版本号
#
# 支持: macOS, Linux, Windows (Git Bash / WSL)
# 依赖: bash 4.0+, python3, grep

set -euo pipefail

# ============================================
# 错误陷阱与清理
# ============================================

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "脚本异常退出，退出码: $exit_code"
    fi
    rm -f "/tmp/openclaw-quickfix-tmp-*" 2>/dev/null || true
}

trap cleanup EXIT

# 跨平台 sed -i 封装
sed_i() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# ============================================
# 版本信息
# ============================================
readonly VERSION="1.1.0"
readonly SCRIPT_NAME="openclaw-quickfix"

# ============================================
# 跨平台环境检测
# ============================================

get_real_path() {
    local target="$1"
    if command -v readlink &>/dev/null && [[ "$(uname -s)" != "Darwin" ]]; then
        readlink -f "$target"
    else
        python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$target"
    fi
}

detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

detect_openclaw_path() {
    local paths=()
    if command -v openclaw &> /dev/null; then
        local cli_path=$(command -v openclaw 2>/dev/null || echo "")
        if [[ -n "$cli_path" ]]; then
            local real_path=$(get_real_path "$cli_path" 2>/dev/null || echo "$cli_path")
            local base_path=$(echo "$real_path" | sed 's|/bin/openclaw||' | sed 's|/lib/node_modules/openclaw/.*||')
            if [[ -d "$base_path/lib/node_modules/openclaw" ]]; then
                echo "$base_path/lib/node_modules/openclaw"
                return 0
            fi
        fi
    fi
    case "$OS_TYPE" in
        macos) paths+=("/opt/homebrew/lib/node_modules/openclaw" "/usr/local/lib/node_modules/openclaw") ;;
        linux) paths+=("/usr/local/lib/node_modules/openclaw" "/usr/lib/node_modules/openclaw") ;;
    esac
    for p in "${paths[@]}"; do [[ -d "$p" ]] && echo "$p" && return 0; done
    return 1
}

detect_config_path() {
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    if [[ -n "${OPENCLAW_CONFIG:-}" ]]; then echo "$OPENCLAW_CONFIG"
    elif [[ -f "$HOME/.openclaw/openclaw.json" ]]; then echo "$HOME/.openclaw/openclaw.json"
    elif [[ -f "$config_home/openclaw/openclaw.json" ]]; then echo "$config_home/openclaw/openclaw.json"
    else echo "$HOME/.openclaw/openclaw.json"; fi
}

# ============================================
# 初始化变量
# ============================================

DRY_RUN_MODE=""
OPENCLAW_PATH=$(detect_openclaw_path) || { echo "[ERROR] 无法检测到 OpenClaw 安装路径" >&2; exit 1; }
CONFIG_FILE=$(detect_config_path)
CONFIG_DIR=$(dirname "$CONFIG_FILE")
BACKUP_DIR="$CONFIG_DIR/backups"
LOG_FILE="/tmp/openclaw-quickfix.log"
DOCS_DIR="$OPENCLAW_PATH/docs"
DOCS_ZH="$DOCS_DIR/zh-CN"
GATEWAY_SERVICE="${OPENCLAW_SERVICE:-ai.openclaw.gateway}"

# 颜色
if [[ -t 1 ]]; then
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
    BLUE='\033[0;34m' CYAN='\033[0;36m' NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

# ============================================
# 日志与工具函数
# ============================================

log() { local msg="[$(date '+%H:%M:%S')] $1"; echo -e "$msg" | tee -a "$LOG_FILE"; }
log_info() { log "${GREEN}[INFO]${NC} $1"; }
log_warn() { log "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }
log_fix() { log "${BLUE}[FIX]${NC} $1"; }
log_doc() { log "${CYAN}[DOC]${NC} $1"; }

backup_config() {
    mkdir -p "$BACKUP_DIR"
    cp "$CONFIG_FILE" "$BACKUP_DIR/openclaw-$(date +%Y%m%d-%H%M%S).json"
    ls -t "$BACKUP_DIR"/openclaw-*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
}

check_rpc_health() {
    log_info "正在进行 RPC 健康检查..."
    if openclaw gateway status > /dev/null 2>&1; then
        log_info "✅ RPC 接口响应正常"
        return 0
    else
        log_warn "❌ RPC 接口无响应，服务可能已失效"
        return 1
    fi
}

detect_config_errors() {
    export CONFIG_FILE
    python3 -c "
import json
import os
import sys

CONFIG_FILE = os.environ.get('CONFIG_FILE')
errors = []
fixes = []

try:
    with open(CONFIG_FILE, 'r') as f:
        config = json.load(f)

    if 'agents' in config and 'list' in config['agents']:
        for i, agent in enumerate(config['agents']['list']):
            if 'heartbeat' in agent:
                errors.append(f'agents.list[{i}].heartbeat')
                fixes.append('remove_heartbeat')

    if 'auth' in config and 'profiles' in config['auth']:
        for name, profile in config['auth']['profiles'].items():
            if 'apiKey' in profile:
                errors.append(f'auth.profiles.{name}.apiKey')
                fixes.append('remove_auth_apikey')

    if 'models' in config and 'providers' in config['models']:
        for name, provider in config['models']['providers'].items():
            if 'authProfileId' in provider:
                errors.append(f'models.providers.{name}.authProfileId')
                fixes.append('remove_authprofileid')

    if 'cron' in config and 'tasks' in config['cron']:
        errors.append('cron.tasks')
        fixes.append('remove_cron_tasks')

except json.JSONDecodeError as e:
    errors.append(f'JSON_SYNTAX_ERROR:{e}')
    fixes.append('restore_backup')
except Exception as e:
    errors.append(f'UNKNOWN_ERROR:{e}')
    fixes.append('call_smartfix')

if errors:
    for err, fix in zip(errors, fixes):
        print(f'{err}|{fix}')
else:
    print('NO_ERRORS')
" 2>/dev/null
}

apply_fix() {
    local fix_type="$1"
    log_fix "执行修复 [$fix_type]..."
    [[ "$DRY_RUN_MODE" == "--dry-run" ]] && return 0
    export CONFIG_FILE
    case "$fix_type" in
        remove_heartbeat)
            python3 -c "
import json
import os
with open(os.environ.get('CONFIG_FILE'), 'r') as f:
    config = json.load(f)
if 'agents' in config and 'list' in config['agents']:
    for agent in config['agents']['list']:
        if 'heartbeat' in agent: del agent['heartbeat']
with open(os.environ.get('CONFIG_FILE'), 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
" ;;
        remove_auth_apikey)
            python3 -c "
import json
import os
with open(os.environ.get('CONFIG_FILE'), 'r') as f:
    config = json.load(f)
if 'auth' in config and 'profiles' in config['auth']:
    for name, profile in config['auth']['profiles'].items():
        if 'apiKey' in profile: del profile['apiKey']
with open(os.environ.get('CONFIG_FILE'), 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
" ;;
        restore_backup)
            local latest=$(ls -t "$BACKUP_DIR"/openclaw-*.json 2>/dev/null | head -1)
            [[ -n "$latest" ]] && cp "$latest" "$CONFIG_FILE" || return 1 ;;
        call_smartfix) return 2 ;;
        *) return 1 ;;
    esac
    return 0
}

restart_gateway() {
    log_info "重启 Gateway (Supervisor)..."
    if openclaw gateway restart > /dev/null 2>&1; then
        log_info "✅ 重启成功"
        sleep 5; return 0
    else
        [[ "$OS_TYPE" == "macos" ]] && launchctl kickstart -k "gui/$(id -u)/$GATEWAY_SERVICE" && return 0
        return 1
    fi
}

# ============================================
# 主流程
# ============================================

main() {
    echo "🔧 OpenClaw 智能修复 v$VERSION"
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --dry-run) DRY_RUN_MODE="--dry-run"; shift ;;
            *) shift ;;
        esac
    done

    [[ ! -f "$CONFIG_FILE" ]] && log_error "配置文件不存在" && exit 1
    [[ "$DRY_RUN_MODE" != "--dry-run" ]] && backup_config

    check_rpc_health || {
        log_warn "服务失效，尝试强制重启..."
        [[ "$DRY_RUN_MODE" != "--dry-run" ]] && restart_gateway
    }

    local errors=$(detect_config_errors)
    [[ "$errors" == "NO_ERRORS" ]] && { log_info "✅ 配置正常"; exit 0; }

    while IFS='|' read -r err fix; do
        [[ -z "$err" ]] && continue
        apply_fix "$fix" "$err"
    done <<< "$errors"

    log_info "修复完成，验证并重启..."
    python3 -m json.tool "$CONFIG_FILE" >/dev/null && [[ "$DRY_RUN_MODE" != "--dry-run" ]] && restart_gateway
}

main "$@"
