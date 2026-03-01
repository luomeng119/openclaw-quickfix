#!/usr/bin/env bash
# uninstall.sh - OpenClaw QuickFix 卸载脚本
#
# 用法: ./uninstall.sh [--yes]

set -euo pipefail

# ============================================
# 配置
# ============================================
readonly VERSION="1.1.0"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
FORCE="${1:-}"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ============================================
# 卸载逻辑
# ============================================

remove_scripts() {
    log_step "移除脚本文件..."
    local scripts=("openclaw-quickfix" "openclaw-fix" "openclaw-terminal")
    local removed_count=0
    
    for script in "${scripts[@]}"; do
        local script_path="$INSTALL_DIR/$script"
        if [[ -f "$script_path" ]]; then
            rm -f "$script_path"
            log_info "已移除: $script_path"
            removed_count=$((removed_count + 1))
        fi
    done
    
    if [[ $removed_count -eq 0 ]]; then
        log_warn "未找到已安装的脚本"
    else
        log_info "共移除 $removed_count 个脚本"
    fi
}

clean_backups() {
    log_step "清理备份文件..."
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local backup_dirs=(
        "$HOME/.openclaw/backups"
        "$config_home/openclaw/backups"
    )
    
    for backup_dir in "${backup_dirs[@]}"; do
        if [[ -d "$backup_dir" ]]; then
            local backup_count=$(find "$backup_dir" -name "openclaw-*.json" 2>/dev/null | wc -l)
            if [[ $backup_count -gt 0 ]]; then
                log_warn "发现 $backup_count 个备份文件: $backup_dir"
                read -p "是否删除这些备份? [y/N]: " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -rf "$backup_dir"
                    log_info "已删除备份目录"
                else
                    log_info "保留备份文件"
                fi
            fi
        fi
    done
}

clean_logs() {
    log_step "清理日志文件..."
    local log_files=(
        "/tmp/openclaw-quickfix.log"
        "/tmp/openclaw-fix-result.json"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            rm -f "$log_file"
            log_info "已移除: $log_file"
        fi
    done
}

remove_from_path() {
    log_step "清理 PATH 配置..."
    local rc_files=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")
    
    for rc_file in "${rc_files[@]}"; do
        if [[ -f "$rc_file" ]]; then
            if grep -q "openclaw-quickfix\|INSTALL_DIR.*local/bin" "$rc_file" 2>/dev/null; then
                log_warn "发现相关配置: $rc_file"
                log_info "请手动检查并移除以下行:"
                grep -n "openclaw-quickfix\|INSTALL_DIR.*local/bin" "$rc_file" || true
            fi
        fi
    done
}

confirm_uninstall() {
    if [[ "$FORCE" == "--yes" ]]; then
        return 0
    fi
    
    echo ""
    echo "=========================================="
    echo "OpenClaw QuickFix 卸载程序"
    echo "=========================================="
    echo ""
    echo "这将卸载以下组件:"
    echo "  - 主脚本: openclaw-quickfix"
    echo "  - 修复脚本: openclaw-fix"
    echo "  - 终端脚本: openclaw-terminal"
    echo "  - 日志文件 (可选)"
    echo "  - 备份文件 (可选)"
    echo ""
    echo "安装目录: $INSTALL_DIR"
    echo ""
    read -p "确认卸载? [y/N]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "卸载已取消"
        exit 0
    fi
}

main() {
    confirm_uninstall
    
    echo ""
    log_info "开始卸载 OpenClaw QuickFix..."
    echo ""
    
    remove_scripts
    clean_logs
    clean_backups
    remove_from_path
    
    echo ""
    log_info "✅ 卸载完成!"
    echo ""
    echo "注意:"
    echo "  1. 请手动从 PATH 中移除 $INSTALL_DIR (如果需要)"
    echo "  2. 重新加载 shell 配置: source ~/.zshrc (或 ~/.bashrc)"
    echo ""
    echo "感谢使用 OpenClaw QuickFix!"
    echo ""
}

main "$@"
