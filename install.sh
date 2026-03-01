#!/usr/bin/env bash
# install.sh - OpenClaw QuickFix 一键安装脚本
#
# 用法: curl -fsSL ... | bash

set -euo pipefail

# ============================================
# 配置
# ============================================
readonly VERSION="1.1.0"
readonly REPO_URL="https://raw.githubusercontent.com/ai-gongxueshe/openclaw-quickfix/main"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
OFFLINE_MODE="${OFFLINE_MODE:-false}"
LOCAL_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
BLUE='\033[0;34m' NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ============================================
# 安装逻辑
# ============================================

download_or_copy() {
    local src="$1"
    local dest="$2"
    if [[ "$OFFLINE_MODE" == "true" ]]; then
        cp "$LOCAL_SRC_DIR/$src" "$dest"
    else
        curl -fsSL "$REPO_URL/$src" -o "$dest" || wget -q "$REPO_URL/$src" -O "$dest"
    fi
    chmod +x "$dest"
}

check_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warn "$INSTALL_DIR 不在 PATH 中"
        local rc=""
        [[ -f "$HOME/.zshrc" ]] && rc="$HOME/.zshrc"
        [[ -f "$HOME/.bashrc" ]] && rc="${rc:-$HOME/.bashrc}"
        if [[ -n "$rc" ]]; then
            if ! grep -q "$INSTALL_DIR" "$rc"; then
                echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$rc"
                log_info "已将 $INSTALL_DIR 添加至 $rc"
            fi
        fi
    fi
}

main() {
    echo -e "${BLUE}"
    cat << "BANNER"
  ____                      ____ _                
 / __ \                     / ___| | __ ___      __
| |  | |_ __   ___ _ __   | |   | |/ _` \ \ /\ / /
| |__| | '_ \ / _ \ '_ \  | |___| | (_| |\ V  V / 
 \____/| .__/ \___|_| |_|  \____|_|\__,_| \_/\_/  
       |_|                                        
BANNER
    echo -e "      OpenClaw QuickFix Installer v$VERSION${NC}\n"

    log_step "检查环境..."
    mkdir -p "$INSTALL_DIR"
    command -v python3 &>/dev/null || { log_error "缺少 python3"; exit 1; }

    log_step "安装脚本..."
    download_or_copy "openclaw-quickfix.sh" "$INSTALL_DIR/openclaw-quickfix"
    download_or_copy "openclaw-fix.sh" "$INSTALL_DIR/openclaw-fix"
    download_or_copy "openclaw-terminal.sh" "$INSTALL_DIR/openclaw-terminal"

    check_path
    log_info "🎉 安装成功！输入 'openclaw-quickfix' 启动保护。"
}

main "$@"
