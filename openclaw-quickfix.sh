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
#
# 作者: AI共学社 (AI Gongxueshe)
# 许可: MIT License
# 仓库: https://github.com/ai-gongxueshe/openclaw-quickfix

set -euo pipefail

# ============================================
# 版本信息
# ============================================
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="openclaw-quickfix"

# ============================================
# 跨平台环境检测
# ============================================

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

# 检测 OpenClaw 安装路径
detect_openclaw_path() {
    local paths=()

    # 1. 通过 openclaw 命令获取
    if command -v openclaw &> /dev/null; then
        local cli_path
        cli_path=$(command -v openclaw 2>/dev/null || echo "")
        if [[ -n "$cli_path" ]]; then
            # 解析真实路径 (可能是 symlink)
            local real_path
            real_path=$(readlink -f "$cli_path" 2>/dev/null || echo "$cli_path")
            # 提取 lib/node_modules/openclaw 部分
            local base_path
            base_path=$(echo "$real_path" | sed 's|/bin/openclaw||' | sed 's|/lib/node_modules/openclaw/.*||')
            if [[ -d "$base_path/lib/node_modules/openclaw" ]]; then
                echo "$base_path/lib/node_modules/openclaw"
                return 0
            fi
        fi
    fi

    # 2. 常见安装路径 (按优先级)
    case "$OS_TYPE" in
        macos)
            paths+=(
                "/opt/homebrew/lib/node_modules/openclaw"
                "/usr/local/lib/node_modules/openclaw"
                "$HOME/.npm-global/lib/node_modules/openclaw"
                "$HOME/.local/lib/node_modules/openclaw"
            )
            ;;
        linux)
            paths+=(
                "/usr/local/lib/node_modules/openclaw"
                "/usr/lib/node_modules/openclaw"
                "$HOME/.npm-global/lib/node_modules/openclaw"
                "$HOME/.local/lib/node_modules/openclaw"
                "/opt/openclaw"
            )
            ;;
        windows)
            paths+=(
                "/c/Program Files/nodejs/node_modules/openclaw"
                "$LOCALAPPDATA/Programs/nodejs/node_modules/openclaw"
                "$APPDATA/npm/node_modules/openclaw"
            )
            ;;
    esac

    # 检查路径是否存在
    for p in "${paths[@]}"; do
        if [[ -d "$p" ]]; then
            echo "$p"
            return 0
        fi
    done

    # 未找到
    return 1
}

# 检测配置文件路径
detect_config_path() {
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

    # 优先级: 环境变量 > ~/.openclaw > XDG
    if [[ -n "${OPENCLAW_CONFIG:-}" ]]; then
        echo "$OPENCLAW_CONFIG"
    elif [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
        echo "$HOME/.openclaw/openclaw.json"
    elif [[ -f "$config_home/openclaw/openclaw.json" ]]; then
        echo "$config_home/openclaw/openclaw.json"
    else
        echo "$HOME/.openclaw/openclaw.json"
    fi
}

# 检测临时目录
detect_temp_dir() {
    case "$OS_TYPE" in
        windows)
            echo "${TEMP:-/tmp}"
            ;;
        *)
            echo "/tmp"
            ;;
    esac
}

# ============================================
# 初始化变量 (动态检测)
# ============================================

OPENCLAW_PATH=$(detect_openclaw_path) || {
    echo "[ERROR] 无法检测到 OpenClaw 安装路径" >&2
    exit 1
}

CONFIG_FILE=$(detect_config_path)
CONFIG_DIR=$(dirname "$CONFIG_FILE")
BACKUP_DIR="$CONFIG_DIR/backups"
TEMP_DIR=$(detect_temp_dir)
LOG_FILE="$TEMP_DIR/openclaw-quickfix.log"

# 文档路径 (动态)
DOCS_DIR="$OPENCLAW_PATH/docs"
DOCS_ZH="$DOCS_DIR/zh-CN"

# Gateway 服务名 (支持环境变量配置)
GATEWAY_SERVICE="${OPENCLAW_SERVICE:-ai.openclaw.gateway}"

# 颜色输出 (检查终端支持)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

# ============================================
# 帮助信息
# ============================================

show_help() {
    cat << EOF
$SCRIPT_NAME v$VERSION - OpenClaw 智能配置修复工具

用法:
    $SCRIPT_NAME [选项]

选项:
    --dry-run        仅检测问题，不执行修复
    --help, -h       显示此帮助信息
    --version, -v    显示版本号

环境变量:
    OPENCLAW_CONFIG      自定义配置文件路径
    OPENCLAW_SERVICE     自定义 Gateway 服务名 (默认: ai.openclaw.gateway)
    DEBUG=1              启用调试日志
    NO_COLOR=1           禁用彩色输出

示例:
    $SCRIPT_NAME              # 检测并修复配置错误
    $SCRIPT_NAME --dry-run    # 仅检测，不修复
    DEBUG=1 $SCRIPT_NAME      # 启用调试模式

支持的平台:
    - macOS (LaunchAgent)
    - Linux (systemd)
    - Windows (Git Bash / WSL)

更多信息: https://github.com/openclaw-community/openclaw-quickfix
EOF
    exit 0
}

show_version() {
    echo "$SCRIPT_NAME v$VERSION"
    exit 0
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        --help|-h)
            show_help
            ;;
        --version|-v)
            show_version
            ;;
        *)
            echo "未知参数: $1" >&2
            echo "使用 --help 查看帮助" >&2
            exit 1
            ;;
    esac
done

# ============================================
# 日志函数
# ============================================

log() {
    local msg="[$(date '+%H:%M:%S')] $1"
    echo -e "$msg" | tee -a "$LOG_FILE"
}

log_info() { log "${GREEN}[INFO]${NC} $1"; }
log_warn() { log "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }
log_fix() { log "${BLUE}[FIX]${NC} $1"; }
log_doc() { log "${CYAN}[DOC]${NC} $1"; }
log_debug() { [[ "${DEBUG:-}" == "1" ]] && log "[DEBUG] $1" || true; }

# ============================================
# 备份功能
# ============================================

backup_config() {
    mkdir -p "$BACKUP_DIR"
    local backup_name="openclaw-$(date +%Y%m%d-%H%M%S).json"
    cp "$CONFIG_FILE" "$BACKUP_DIR/$backup_name"
    log_info "已备份到: $BACKUP_DIR/$backup_name"

    # 只保留最近 10 个备份
    ls -t "$BACKUP_DIR"/openclaw-*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
}

# ============================================
# JSON 验证
# ============================================

validate_json() {
    python3 -m json.tool "$CONFIG_FILE" > /dev/null 2>&1
}

# ============================================
# 步骤 1: 检测配置错误
# 返回格式: ERROR_1|FIX_1 (每行一个，或 NO_ERRORS)
# ============================================

detect_config_errors() {
    python3 -c "
import json
import sys

CONFIG_FILE = '$CONFIG_FILE'

errors = []
fixes = []

try:
    with open(CONFIG_FILE, 'r') as f:
        config = json.load(f)

    # 检查 agents.list 中的 heartbeat
    if 'agents' in config and 'list' in config['agents']:
        for i, agent in enumerate(config['agents']['list']):
            if 'heartbeat' in agent:
                errors.append(f'agents.list[{i}].heartbeat')
                fixes.append('remove_heartbeat')

    # 检查 auth.profiles 中的 apiKey
    if 'auth' in config and 'profiles' in config['auth']:
        for name, profile in config['auth']['profiles'].items():
            if 'apiKey' in profile:
                errors.append(f'auth.profiles.{name}.apiKey')
                fixes.append('remove_auth_apikey')

    # 检查 models.providers 中的 authProfileId
    if 'models' in config and 'providers' in config['models']:
        for name, provider in config['models']['providers'].items():
            if 'authProfileId' in provider:
                errors.append(f'models.providers.{name}.authProfileId')
                fixes.append('remove_authprofileid')

    # 检查 cron.tasks
    if 'cron' in config and 'tasks' in config['cron']:
        errors.append('cron.tasks')
        fixes.append('remove_cron_tasks')

    # 检查 tools.profile
    valid_profiles = {'minimal', 'coding', 'messaging', 'full'}
    if 'tools' in config and 'profile' in config['tools']:
        if config['tools']['profile'] not in valid_profiles:
            errors.append(f\"tools.profile={config['tools']['profile']}\")
            fixes.append('remove_tools_profile')

except json.JSONDecodeError as e:
    errors.append(f'JSON_SYNTAX_ERROR:{e}')
    fixes.append('restore_backup')
except Exception as e:
    errors.append(f'UNKNOWN_ERROR:{e}')
    fixes.append('call_smartfix')

# 输出格式: ERROR_1|FIX_1
if errors:
    for err, fix in zip(errors, fixes):
        print(f'{err}|{fix}')
else:
    print('NO_ERRORS')
" 2>/dev/null
}

# ============================================
# 步骤 2: 查阅官方文档
# ============================================

search_docs_for_error() {
    local error_pattern="$1"
    log_doc "步骤 2: 查阅官方文档搜索 '$error_pattern'..."

    local found=0

    # 搜索中文文档
    if [[ -d "$DOCS_ZH" ]]; then
        local found_files
        found_files=$(grep -rl "$error_pattern" "$DOCS_ZH" 2>/dev/null | head -3)
        if [[ -n "$found_files" ]]; then
            log_doc "在中文文档中找到:"
            echo "$found_files" | while read -r file; do
                [[ -n "$file" ]] && log_doc "  📄 ${file#$DOCS_ZH/}"
            done
            found=1
        fi
    fi

    # 搜索英文文档
    if [[ $found -eq 0 && -d "$DOCS_DIR" ]]; then
        local found_files
        found_files=$(grep -rl "$error_pattern" "$DOCS_DIR" --exclude-dir="zh-CN" 2>/dev/null | head -3)
        if [[ -n "$found_files" ]]; then
            log_doc "在英文文档中找到:"
            echo "$found_files" | while read -r file; do
                [[ -n "$file" ]] && log_doc "  📄 ${file#$DOCS_DIR/}"
            done
            found=1
        fi
    fi

    if [[ $found -eq 0 ]]; then
        log_doc "文档中未找到直接相关内容"
    fi

    return $found
}

# ============================================
# 步骤 3: 执行修复
# ============================================

apply_fix() {
    local fix_type="$1"
    local error_desc="$2"

    log_fix "步骤 3: 执行修复 [$fix_type]..."

    if [[ "$DRY_RUN" == "--dry-run" ]]; then
        log_info "[DRY-RUN] 将执行: $fix_type"
        return 0
    fi

    case "$fix_type" in
        remove_heartbeat)
            python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
if 'agents' in config and 'list' in config['agents']:
    for agent in config['agents']['list']:
        if 'heartbeat' in agent:
            del agent['heartbeat']
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
print('已移除 heartbeat 字段')
"
            ;;

        remove_auth_apikey)
            python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
if 'auth' in config and 'profiles' in config['auth']:
    for name, profile in config['auth']['profiles'].items():
        if 'apiKey' in profile:
            del profile['apiKey']
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
print('已移除 auth.profiles 中的 apiKey')
"
            ;;

        remove_authprofileid)
            python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
if 'models' in config and 'providers' in config['models']:
    for name, provider in config['models']['providers'].items():
        if 'authProfileId' in provider:
            del provider['authProfileId']
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
print('已移除 models.providers 中的 authProfileId')
"
            ;;

        remove_cron_tasks)
            python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
if 'cron' in config and 'tasks' in config['cron']:
    del config['cron']['tasks']
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
print('已移除 cron.tasks')
"
            ;;

        remove_tools_profile)
            python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
if 'tools' in config and 'profile' in config['tools']:
    del config['tools']['profile']
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
print('已移除未知的 tools.profile')
"
            ;;

        restore_backup)
            log_error "JSON 语法错误，尝试恢复备份..."
            local latest_backup=$(ls -t "$BACKUP_DIR"/openclaw-*.json 2>/dev/null | head -1)
            if [[ -n "$latest_backup" ]]; then
                cp "$latest_backup" "$CONFIG_FILE"
                log_info "已从备份恢复: $latest_backup"
            else
                log_error "无可用备份"
                return 1
            fi
            ;;

        call_smartfix)
            log_warn "此错误类型需要 SmartFix..."
            return 2  # 特殊返回码，表示需要调用 SmartFix
            ;;

        *)
            log_error "未知修复类型: $fix_type"
            return 1
            ;;
    esac

    return 0
}

# ============================================
# 步骤 4: 调用 SmartFix (Claude Code)
# ============================================

call_smartfix() {
    local error_info="$1"
    log_warn "步骤 4: 调用 SmartFix 进行智能修复..."

    if [[ "$DRY_RUN" == "--dry-run" ]]; then
        log_info "[DRY-RUN] 将调用 SmartFix: $error_info"
        return 1
    fi

    # 检测 SmartFix 脚本路径
    local smartfix_script=""
    local script_paths=(
        "$CONFIG_DIR/scripts/openclaw-fix.sh"
        "$HOME/.openclaw/scripts/openclaw-fix.sh"
        "$HOME/.local/bin/openclaw-fix.sh"
    )

    for path in "${script_paths[@]}"; do
        if [[ -x "$path" ]]; then
            smartfix_script="$path"
            break
        fi
    done

    if [[ -n "$smartfix_script" ]]; then
        log_info "正在调用 Claude Code..."
        "$smartfix_script" "$error_info"
        return $?
    else
        log_error "SmartFix 脚本不存在"
        return 1
    fi
}

# ============================================
# 跨平台 Gateway 重启
# ============================================

restart_gateway() {
    log_info "重启 Gateway..."

    case "$OS_TYPE" in
        macos)
            # macOS: 使用 launchctl
            launchctl kickstart -k gui/$(id -u)/$GATEWAY_SERVICE 2>/dev/null || true
            sleep 3

            if launchctl list "$GATEWAY_SERVICE" 2>/dev/null | grep -q "PID"; then
                log_info "✅ Gateway 已重启 (macOS LaunchAgent)"
                return 0
            else
                # 尝试备用方案: 通过 openclaw 命令
                if command -v openclaw &> /dev/null; then
                    openclaw gateway restart 2>/dev/null || true
                    sleep 2
                    log_info "✅ Gateway 已重启 (CLI)"
                    return 0
                fi
                log_error "❌ Gateway 启动失败"
                return 1
            fi
            ;;

        linux)
            # Linux: 尝试 systemd, 然后尝试 openclaw 命令
            if command -v systemctl &> /dev/null; then
                systemctl --user restart "$GATEWAY_SERVICE" 2>/dev/null || \
                sudo systemctl restart "$GATEWAY_SERVICE" 2>/dev/null || true
                sleep 3
            fi

            # 备用: 通过 openclaw 命令
            if command -v openclaw &> /dev/null; then
                openclaw gateway restart 2>/dev/null || true
            fi

            log_info "✅ Gateway 重启命令已执行"
            return 0
            ;;

        windows)
            # Windows: 通过 openclaw 命令或 net/sc
            if command -v openclaw &> /dev/null; then
                openclaw gateway restart 2>/dev/null || true
            elif command -v net &> /dev/null; then
                net stop "$GATEWAY_SERVICE" 2>/dev/null || true
                net start "$GATEWAY_SERVICE" 2>/dev/null || true
            fi

            log_info "✅ Gateway 重启命令已执行"
            return 0
            ;;

        *)
            # 未知系统: 尝试通用命令
            if command -v openclaw &> /dev/null; then
                openclaw gateway restart 2>/dev/null || true
            fi
            log_info "✅ Gateway 重启命令已执行"
            return 0
            ;;
    esac
}

# ============================================
# 主流程
# ============================================

main() {
    echo "========================================"
    echo "🔧 OpenClaw 智能修复 (v3 - 跨平台版)"
    echo "========================================"
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "系统: $OS_TYPE"
    echo "OpenClaw: $OPENCLAW_PATH"
    echo "配置: $CONFIG_FILE"
    echo "文档: $DOCS_ZH"
    echo "日志: $LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"

    # 1. 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi

    # 2. 备份
    [[ "$DRY_RUN" != "--dry-run" ]] && backup_config

    # 3. 检测错误
    log_info "步骤 1: 检测配置错误..."
    local errors_output
    errors_output=$(detect_config_errors)

    if [[ "$errors_output" == "NO_ERRORS" ]]; then
        log_info "✅ 未发现配置错误"
        exit 0
    fi

    # 4. 处理每个错误
    log_info "发现以下配置问题:"
    local fixed_count=0
    local smartfix_needed=""

    while IFS='|' read -r error_desc fix_type; do
        [[ -z "$error_desc" ]] && continue
        echo "  ❌ $error_desc"

        # 4.1 查阅文档
        local error_key
        error_key=$(echo "$error_desc" | grep -oE '^[a-zA-Z._]+' | head -1)
        search_docs_for_error "$error_key" || true

        # 4.2 执行修复
        apply_fix "$fix_type" "$error_desc"
        local fix_result=$?

        if [[ $fix_result -eq 0 ]]; then
            ((fixed_count++))
        elif [[ $fix_result -eq 2 ]]; then
            smartfix_needed="$smartfix_needed $error_desc"
        fi

    done <<< "$errors_output"

    echo ""
    echo "========================================"

    # 5. 处理需要 SmartFix 的问题
    if [[ -n "$smartfix_needed" ]]; then
        log_warn "以下问题需要 SmartFix:"
        for err in $smartfix_needed; do
            echo "  🔍 $err"
        done

        if call_smartfix "$smartfix_needed"; then
            ((fixed_count++))
        fi
    fi

    # 6. 汇总
    if [[ $fixed_count -gt 0 ]]; then
        log_info "已修复 $fixed_count 个问题"

        # 验证配置
        if validate_json; then
            log_info "✅ 配置验证通过"
        else
            log_error "❌ 配置验证失败"
            exit 1
        fi

        # 重启 Gateway
        if [[ "$DRY_RUN" != "--dry-run" ]]; then
            restart_gateway
        else
            log_info "[DRY-RUN] 跳过重启"
        fi
    fi

    exit 0
}

main "$@"
