#!/usr/bin/env bash
# install.sh - OpenClaw QuickFix 安装脚本
# 用法: curl -fsSL https://raw.githubusercontent.com/openclaw-community/openclaw-quickfix/main/install.sh | bash

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
REPO_URL="https://raw.githubusercontent.com/openclaw-community/openclaw-quickfix/main"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查依赖
check_dependencies() {
    local missing=()

    command -v bash &> /dev/null || missing+=("bash")
    command -v python3 &> /dev/null || missing+=("python3")
    command -v grep &> /dev/null || missing+=("grep")
    command -v curl &> /dev/null || missing+=("curl")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        exit 1
    fi
}

# 安装
install() {
    log_info "安装 OpenClaw QuickFix..."

    # 创建目录
    mkdir -p "$INSTALL_DIR"

    # 下载脚本
    local script_path="$INSTALL_DIR/openclaw-quickfix"

    if command -v curl &> /dev/null; then
        curl -fsSL "$REPO_URL/openclaw-quickfix.sh" -o "$script_path"
    elif command -v wget &> /dev/null; then
        wget -q "$REPO_URL/openclaw-quickfix.sh" -O "$script_path"
    else
        log_error "需要 curl 或 wget"
        exit 1
    fi

    # 添加执行权限
    chmod +x "$script_path"

    log_info "✅ 安装完成: $script_path"
    log_info ""
    log_info "使用方法:"
    echo "  openclaw-quickfix              # 检测并修复"
    echo "  openclaw-quickfix --dry-run    # 仅检测"
    echo "  openclaw-quickfix --help       # 查看帮助"
    log_info ""

    # 检查 PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_info "⚠️  $INSTALL_DIR 不在 PATH 中"
        log_info "   请添加以下内容到 ~/.bashrc 或 ~/.zshrc:"
        echo ""
        echo "    export PATH=\"\$PATH:$INSTALL_DIR\""
        echo ""
    fi
}

# 主流程
main() {
    echo "========================================"
    echo "  OpenClaw QuickFix 安装程序"
    echo "========================================"
    echo ""

    check_dependencies
    install
}

main "$@"
