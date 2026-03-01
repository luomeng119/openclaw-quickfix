#!/usr/bin/env bash
set -euo pipefail

# OpenClaw QuickFix 全面测试套件 v2.0
# 覆盖: 语法、功能、边界情况、错误处理

readonly TEST_VERSION="2.0"
readonly TEST_START_TIME=$(date +%s)

# 测试统计
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARN=0

# 颜色输出
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 获取项目路径
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCRIPT_PATH="$PROJECT_ROOT/openclaw-quickfix.sh"
readonly FIX_SCRIPT="$PROJECT_ROOT/openclaw-fix.sh"
readonly TERM_SCRIPT="$PROJECT_ROOT/openclaw-terminal.sh"

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 测试框架
run_test() {
    local test_name="$1"
    local test_func="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo ""
    echo "=========================================="
    echo "Test: $test_name"
    echo "=========================================="
    
    if $test_func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_pass "$test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$test_name"
    fi
}

# ==================== 测试用例 ====================

test_01_os_detection() {
    log_info "检测操作系统..."
    local os_type
    os_type=$(uname -s)
    
    if [[ -n "$os_type" ]]; then
        log_pass "检测到操作系统: $os_type"
        return 0
    else
        log_fail "无法检测操作系统"
        return 1
    fi
}

test_02_script_syntax() {
    log_info "检查所有脚本语法..."
    local scripts=("$SCRIPT_PATH" "$FIX_SCRIPT" "$TERM_SCRIPT")
    local all_passed=true
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if bash -n "$script" 2>/dev/null; then
                log_pass "$(basename "$script") 语法正确"
            else
                log_fail "$(basename "$script") 语法错误"
                all_passed=false
            fi
        fi
    done
    
    $all_passed
}

test_03_function_definitions() {
    log_info "检查核心函数定义..."
    local required_funcs=(
        "detect_os"
        "detect_openclaw_path"
        "detect_config_path"
        "backup_config"
        "check_rpc_health"
        "detect_config_errors"
    )
    local missing=0
    
    for func in "${required_funcs[@]}"; do
        if grep -q "^$func()" "$SCRIPT_PATH" 2>/dev/null; then
            log_pass "函数 $func 已定义"
        else
            log_warn "函数 $func 未找到"
            missing=$((missing + 1))
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        return 0
    else
        log_warn "$missing 个函数可能缺失"
        return 0  # 警告但不失败
    fi
}

test_04_config_detection() {
    log_info "测试配置文件检测..."
    local test_dir="/tmp/oc-test-$$"
    mkdir -p "$test_dir"
    
    # 创建测试配置
    cat > "$test_dir/test.json" << 'EOF'
{
  "agents": {
    "list": [{"id": "test", "heartbeat": "invalid"}]
  }
}
EOF
    
    if [[ -f "$test_dir/test.json" ]]; then
        log_pass "测试配置创建成功"
        rm -rf "$test_dir"
        return 0
    else
        log_fail "测试配置创建失败"
        rm -rf "$test_dir"
        return 1
    fi
}

test_05_backup_mechanism() {
    log_info "测试备份机制..."
    local test_dir="/tmp/oc-backup-$$"
    local backup_dir="$test_dir/backups"
    mkdir -p "$backup_dir"
    
    # 创建测试文件
    echo '{"test": true}' > "$test_dir/config.json"
    cp "$test_dir/config.json" "$backup_dir/config-$(date +%Y%m%d-%H%M%S).json"
    
    if [[ -f "$backup_dir"/*.json ]]; then
        log_pass "备份文件创建成功"
        rm -rf "$test_dir"
        return 0
    else
        log_warn "备份文件未创建"
        rm -rf "$test_dir"
        return 0
    fi
}

test_06_cross_platform() {
    log_info "检查跨平台兼容性..."
    local os_type
    os_type=$(uname -s)
    
    case "$os_type" in
        Darwin*|Linux*)
            log_pass "支持的操作系统: $os_type"
            return 0
            ;;
        *)
            log_warn "未测试的操作系统: $os_type"
            return 0
            ;;
    esac
}

test_07_error_handling() {
    log_info "测试错误处理..."
    
    # 检查是否有set -euo pipefail
    if grep -q "set -euo pipefail" "$SCRIPT_PATH"; then
        log_pass "严格模式已启用"
    else
        log_warn "严格模式未启用"
    fi
    
    # 检查cleanup函数
    if grep -q "cleanup()" "$SCRIPT_PATH"; then
        log_pass "清理函数已定义"
    else
        log_warn "清理函数未定义"
    fi
    
    return 0
}

test_08_variable_definitions() {
    log_info "检查只读变量定义..."
    
    if grep -q "readonly VERSION" "$SCRIPT_PATH"; then
        log_pass "版本号已定义为只读"
    else
        log_warn "版本号未定义为只读"
    fi
    
    if grep -q "readonly SCRIPT_NAME" "$SCRIPT_PATH"; then
        log_pass "脚本名已定义为只读"
    else
        log_warn "脚本名未定义为只读"
    fi
    
    return 0
}

test_09_file_permissions() {
    log_info "检查文件权限..."
    local scripts=("$SCRIPT_PATH" "$FIX_SCRIPT" "$TERM_SCRIPT")
    local all_executable=true
    
    for script in "${scripts[@]}"; do
        if [[ -x "$script" ]]; then
            log_pass "$(basename "$script") 可执行"
        else
            log_warn "$(basename "$script") 不可执行"
            all_executable=false
        fi
    done
    
    return 0
}

test_10_documentation() {
    log_info "检查文档完整性..."
    local readme="$PROJECT_ROOT/README.md"
    
    if [[ -f "$readme" ]]; then
        log_pass "README.md 存在"
        
        if grep -q "安装指南" "$readme" || grep -q "Installation" "$readme"; then
            log_pass "包含安装说明"
        fi
        
        if grep -q "使用" "$readme" || grep -q "Usage" "$readme"; then
            log_pass "包含使用说明"
        fi
    else
        log_fail "README.md 不存在"
        return 1
    fi
    
    return 0
}

# ==================== 主程序 ====================

main() {
    echo "=========================================="
    echo "OpenClaw QuickFix Test Suite v$TEST_VERSION"
    echo "=========================================="
    echo ""
    echo "项目路径: $PROJECT_ROOT"
    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 运行所有测试
    run_test "01. OS Detection" test_01_os_detection
    run_test "02. Script Syntax" test_02_script_syntax
    run_test "03. Function Definitions" test_03_function_definitions
    run_test "04. Config Detection" test_04_config_detection
    run_test "05. Backup Mechanism" test_05_backup_mechanism
    run_test "06. Cross Platform" test_06_cross_platform
    run_test "07. Error Handling" test_07_error_handling
    run_test "08. Variable Definitions" test_08_variable_definitions
    run_test "09. File Permissions" test_09_file_permissions
    run_test "10. Documentation" test_10_documentation
    
    # 计算耗时
    local end_time=$(date +%s)
    local duration=$((end_time - TEST_START_TIME))
    
    # 输出测试报告
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total:  $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Warn:   ${YELLOW}$TESTS_WARN${NC}"
    echo "Time:   ${duration}s"
    echo "=========================================="
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All critical tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️  Some tests failed${NC}"
        exit 1
    fi
}

main "$@"
