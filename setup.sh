#!/usr/bin/env bash
# setup.sh - OpenClaw QuickFix 交互式配置向导

set -euo pipefail

readonly VERSION="1.1.1"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "BANNER"
   ____                      ____ _                _
  / __ \                     / ___| | __ ___      __
 | |  | |_ __   ___ _ __   | |   | |/ _` \ \ /\ / /
 | |__| | '_ \ / _ \ '_ \  | |___| | (_| |\ V  V /
  \____/| .__/ \___|_| |_|  \____|_|\__,_| \_/\_/
        |_|
BANNER
    echo -e "${NC}"
    echo -e "${GREEN}OpenClaw QuickFix v$VERSION - 交互式配置向导${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}[步骤 $1/5]${NC} $2"
    echo "----------------------------------------"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# 步骤1: 环境检查
step1_check_environment() {
    print_step 1 "环境检查"
    
    # 检查OS
    local os=$(uname -s)
    print_success "操作系统: $os"
    
    # 检查bash版本
    if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
        print_success "Bash版本: ${BASH_VERSION}"
    else
        print_error "Bash版本过低，需要4.0+"
        exit 1
    fi
    
    # 检查依赖
    if command -v python3 &> /dev/null; then
        print_success "Python3: 已安装"
    else
        print_error "Python3: 未安装"
        exit 1
    fi
    
    if command -v openclaw &> /dev/null; then
        print_success "OpenClaw: 已安装"
    else
        print_warn "OpenClaw: 未安装 (向导将继续，但部分功能受限)"
    fi
    
    read -p "按回车键继续..."
}

# 步骤2: 安装模式选择
step2_install_mode() {
    print_step 2 "安装模式选择"
    
    echo "请选择安装模式:"
    echo "  1) 快速安装 (推荐)"
    echo "  2) 离线安装"
    echo "  3) 仅安装脚本 (不修改环境)"
    echo ""
    
    read -p "请选择 [1-3]: " mode
    
    case $mode in
        1) 
            print_info "选择: 快速安装"
            INSTALL_MODE="online"
            ;;
        2)
            print_info "选择: 离线安装"
            INSTALL_MODE="offline"
            ;;
        3)
            print_info "选择: 仅安装脚本"
            INSTALL_MODE="scripts-only"
            ;;
        *)
            print_error "无效选择，使用默认(快速安装)"
            INSTALL_MODE="online"
            ;;
    esac
    
    read -p "按回车键继续..."
}

# 步骤3: 安装目录
step3_install_directory() {
    print_step 3 "安装目录"
    
    local default_dir="$HOME/.local/bin"
    echo "默认安装目录: $default_dir"
    read -p "是否使用默认目录? [Y/n]: " use_default
    
    if [[ $use_default =~ ^[Nn]$ ]]; then
        read -p "请输入安装目录: " INSTALL_DIR
    else
        INSTALL_DIR="$default_dir"
    fi
    
    # 创建目录
    mkdir -p "$INSTALL_DIR"
    print_success "安装目录: $INSTALL_DIR"
    
    read -p "按回车键继续..."
}

# 步骤4: 功能选择
step4_feature_selection() {
    print_step 4 "功能选择"
    
    echo "请选择要启用的功能:"
    echo ""
    
    read -p "启用自动备份? [Y/n]: " enable_backup
    [[ $enable_backup =~ ^[Nn]$ ]] && ENABLE_BACKUP=false || ENABLE_BACKUP=true
    
    read -p "启用SmartFix (需要Claude Code)? [Y/n]: " enable_smartfix
    [[ $enable_smartfix =~ ^[Nn]$ ]] && ENABLE_SMARTFIX=false || ENABLE_SMARTFIX=true
    
    read -p "启用可视化终端? [Y/n]: " enable_terminal
    [[ $enable_terminal =~ ^[Nn]$ ]] && ENABLE_TERMINAL=false || ENABLE_TERMINAL=true
    
    print_success "配置已保存"
    read -p "按回车键继续..."
}

# 步骤5: 执行安装
step5_execute_install() {
    print_step 5 "执行安装"
    
    echo "安装摘要:"
    echo "  模式: $INSTALL_MODE"
    echo "  目录: $INSTALL_DIR"
    echo "  自动备份: $ENABLE_BACKUP"
    echo "  SmartFix: $ENABLE_SMARTFIX"
    echo "  可视化终端: $ENABLE_TERMINAL"
    echo ""
    
    read -p "确认安装? [Y/n]: " confirm
    
    if [[ $confirm =~ ^[Nn]$ ]]; then
        print_error "安装已取消"
        exit 0
    fi
    
    echo ""
    echo "正在安装..."
    
    # 执行安装
    if [[ "$INSTALL_MODE" == "offline" ]]; then
        OFFLINE_MODE=true bash install.sh
    else
        bash install.sh
    fi
    
    print_success "安装完成!"
}

# 完成
finish() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}🎉 配置完成!${NC}"
    echo "=========================================="
    echo ""
    echo "使用方法:"
    echo "  openclaw-quickfix         # 标准检测修复"
    echo "  openclaw-quickfix --help  # 查看帮助"
    echo "  openclaw-quickfix --dry-run # 安全检测模式"
    echo ""
    echo "卸载方法:"
    echo "  openclaw-quickfix-uninstall"
    echo ""
}

# 主程序
main() {
    print_banner
    step1_check_environment
    step2_install_mode
    step3_install_directory
    step4_feature_selection
    step5_execute_install
    finish
}

main "$@"
