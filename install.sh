#!/usr/bin/env bash
# install.sh - OpenClaw QuickFix 一键安装脚本
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/luomeng119/openclaw-quickfix/main/install.sh | bash
#
# 环境变量:
#   INSTALL_DIR - 安装目录 (默认: ~/.local/bin)

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
REPO_URL="https://raw.githubusercontent.com/luomeng119/openclaw-quickfix/main"

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

# 检查依赖
check_dependencies() {
    local missing=()

    command -v bash &> /dev/null || missing+=("bash")
    command -v python3 &> /dev/null || missing+=("python3")
    command -v grep &> /dev/null || missing+=("grep")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        log_info "请安装缺少的依赖后重试"
        exit 1
    fi

    log_info "依赖检查通过 ✓"
}

# 检查 OpenClaw
check_openclaw() {
    if ! command -v openclaw &> /dev/null; then
        log_warn "未检测到 OpenClaw"
        log_info "请先安装 OpenClaw: https://openclaw.ai"
        echo ""
        read -p "是否继续安装 QuickFix? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        local version
        version=$(openclaw --version 2>/dev/null || echo "unknown")
        log_info "检测到 OpenClaw: $version ✓"
    fi
}

# 安装脚本
install_scripts() {
    log_step "安装 QuickFix 脚本..."

    # 创建目录
    mkdir -p "$INSTALL_DIR"

    # 下载主脚本
    local main_script="$INSTALL_DIR/openclaw-quickfix"
    log_info "下载 openclaw-quickfix.sh ..."
    if command -v curl &> /dev/null; then
        curl -fsSL "$REPO_URL/openclaw-quickfix.sh" -o "$main_script"
    elif command -v wget &> /dev/null; then
        wget -q "$REPO_URL/openclaw-quickfix.sh" -O "$main_script"
    else
        log_error "需要 curl 或 wget"
        exit 1
    fi
    chmod +x "$main_script"

    # 下载 SmartFix 脚本
    local fix_script="$INSTALL_DIR/openclaw-fix"
    log_info "下载 openclaw-fix.sh (SmartFix)..."
    if command -v curl &> /dev/null; then
        curl -fsSL "$REPO_URL/openclaw-fix.sh" -o "$fix_script"
    elif command -v wget &> /dev/null; then
        wget -q "$REPO_URL/openclaw-fix.sh" -O "$fix_script"
    fi
    chmod +x "$fix_script"

    # 下载终端启动器
    local terminal_script="$INSTALL_DIR/openclaw-terminal"
    log_info "下载 openclaw-terminal.sh (可视化终端)..."
    if command -v curl &> /dev/null; then
        curl -fsSL "$REPO_URL/openclaw-terminal.sh" -o "$terminal_script"
    elif command -v wget &> /dev/null; then
        wget -q "$REPO_URL/openclaw-terminal.sh" -O "$terminal_script"
    fi
    chmod +x "$terminal_script"

    log_info "安装完成 ✓"
    echo ""
    log_info "已安装:"
    echo "  • $main_script (主脚本)"
    echo "  • $fix_script (SmartFix)"
    echo "  • $terminal_script (可视化终端)"
}

# 检查 PATH
check_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warn "$INSTALL_DIR 不在 PATH 中"
        echo ""
        log_info "请将以下内容添加到 ~/.bashrc 或 ~/.zshrc:"
        echo ""
        echo "    export PATH=\"\$PATH:$INSTALL_DIR\""
        echo ""
        log_info "然后运行: source ~/.bashrc  或  source ~/.zshrc"
    fi
}

# 显示使用说明
show_usage() {
    echo ""
    echo "=========================================="
    echo "🎉 OpenClaw QuickFix 安装成功!"
    echo "=========================================="
    echo ""
    echo "📖 使用方法:"
    echo ""
    echo "  # 检测并修复配置错误"
    echo "  openclaw-quickfix"
    echo ""
    echo "  # 仅检测问题（安全模式）"
    echo "  openclaw-quickfix --dry-run"
    echo ""
    echo "  # 查看帮助"
    echo "  openclaw-quickfix --help"
    echo ""
    echo "🤖 SmartFix (可选):"
    echo "  安装 Claude Code CLI 以启用 AI 智能修复"
    echo "  https://docs.anthropic.com/claude-code"
    echo ""
    echo "📚 文档:"
    echo "  https://github.com/ai-gongxueshe/openclaw-quickfix"
    echo ""
    echo "🏢 作者: AI共学社"
    echo ""
}

# 主流程
main() {
    echo ""
    echo "=========================================="
    echo "  OpenClaw QuickFix 安装程序"
    echo "  版本: 1.0.0"
    echo "=========================================="
    echo ""

    check_dependencies
    echo ""
    check_openclaw
    echo ""
    install_scripts
    echo ""
    check_path
    show_usage
}

main "$@"
