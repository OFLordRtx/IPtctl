#!/usr/bin/env bash
# IPtctl 测试运行主脚本
# 运行所有测试或指定测试

set -uo pipefail # 移除 -e，允许测试失败后继续运行并打印总结

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# 测试开始时间
START_TIME=$(date +%s)

# ============================================================
# 输出函数
# ============================================================

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_section() {
    echo -e "\n${YELLOW}▶ $1${NC}"
}

print_result() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "PASS")
            echo -e "  ${GREEN}✓${NC} $message"
            ;;
        "FAIL")
            echo -e "  ${RED}✗${NC} $message"
            ;;
        "SKIP")
            echo -e "  ${YELLOW}↷${NC} $message"
            ;;
        "INFO")
            echo -e "  ${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# ============================================================
# 测试运行函数
# ============================================================

run_single_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)
    
    print_section "运行测试: $test_name"
    
    if [[ ! -f "$test_file" ]]; then
        print_result "FAIL" "测试文件不存在: $test_file"
        ((FAILED_TESTS++))
        ((TOTAL_TESTS++))
        return 1
    fi
    
    # 检查文件是否可执行
    if [[ ! -x "$test_file" ]]; then
        chmod +x "$test_file"
    fi
    
    # 运行测试
    local output
    local exit_code=0
    
    # 运行测试脚本，捕获输出和退出码
    output=$(bash "$test_file" 2>&1)
    exit_code=$?
    
    ((TOTAL_TESTS++))
    
    if [[ $exit_code -eq 0 ]]; then
        print_result "PASS" "$test_name 通过"
        ((PASSED_TESTS++))
        return 0
    else
        print_result "FAIL" "$test_name 失败 (退出码: $exit_code)"
        echo -e "${RED}错误输出:${NC}"
        echo "$output" | sed 's/^/    /'
        ((FAILED_TESTS++))
        return 1
    fi
}

run_test_suite() {
    local suite_dir="$1"
    local suite_name="$2"
    
    print_header "运行 $suite_name 测试套件"
    
    if [[ ! -d "$suite_dir" ]]; then
        print_result "SKIP" "测试套件目录不存在: $suite_dir"
        ((SKIPPED_TESTS++))
        return 0
    fi
    
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$suite_dir" -name "*.sh" -type f -print0)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        print_result "INFO" "未找到测试文件"
        return 0
    fi
    
    for test_file in "${test_files[@]}"; do
        run_single_test "$test_file"
    done
}

# ============================================================
# 环境检查函数
# ============================================================

check_environment() {
    print_header "检查测试环境"
    
    # 检查 Bash 版本
    local bash_version=$(bash --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    print_result "INFO" "Bash 版本: $bash_version"
    
    if [[ $(echo "$bash_version" | cut -d. -f1) -lt 4 ]]; then
        print_result "WARN" "建议使用 Bash 4.0+"
    fi
    
    # 检查 iptctl 主脚本
    if [[ -f "$PROJECT_ROOT/iptctl.sh" ]]; then
        print_result "PASS" "找到 iptctl 主脚本"
    else
        print_result "FAIL" "未找到 iptctl 主脚本"
        return 1
    fi
    
    # 检查测试辅助文件
    if [[ -f "$SCRIPT_DIR/test_helpers.sh" ]]; then
        print_result "PASS" "找到测试辅助函数"
    else
        print_result "FAIL" "未找到测试辅助函数"
        return 1
    fi
    
    # 检查必要的命令
    local required_commands=("bash" "date" "find" "grep" "sed")
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            print_result "PASS" "命令可用: $cmd"
        else
            print_result "FAIL" "命令不可用: $cmd"
            return 1
        fi
    done
    
    return 0
}

# ============================================================
# 测试总结函数
# ============================================================

print_test_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    print_header "测试总结"
    
    echo -e "测试套件: IPtctl"
    echo -e "运行时间: $(date -d "@$START_TIME" '+%Y-%m-%d %H:%M:%S')"
    echo -e "持续时间: ${duration}秒"
    echo -e ""
    echo -e "总测试数: $TOTAL_TESTS"
    echo -e "${GREEN}通过: $PASSED_TESTS${NC}"
    echo -e "${RED}失败: $FAILED_TESTS${NC}"
    echo -e "${YELLOW}跳过: $SKIPPED_TESTS${NC}"
    
    if [[ $TOTAL_TESTS -eq 0 ]]; then
        echo -e "\n${YELLOW}警告: 未运行任何测试${NC}"
        return 2
    elif [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}所有测试通过！${NC}"
        return 0
    else
        echo -e "\n${RED}有 $FAILED_TESTS 个测试失败${NC}"
        return 1
    fi
}

# ============================================================
# 主函数
# ============================================================

main() {
    local target="${1:-all}"
    
    print_header "IPtctl 测试运行器"
    echo -e "项目根目录: $PROJECT_ROOT"
    echo -e "测试目录: $SCRIPT_DIR"
    echo -e "目标: $target"
    
    # 检查环境
    if ! check_environment; then
        echo -e "${RED}环境检查失败，停止测试${NC}"
        return 1
    fi
    
    # 根据目标运行测试
    case "$target" in
        "all")
            run_test_suite "$SCRIPT_DIR/unit" "单元测试"
            run_test_suite "$SCRIPT_DIR/integration" "集成测试"
            ;;
        "unit")
            run_test_suite "$SCRIPT_DIR/unit" "单元测试"
            ;;
        "integration")
            run_test_suite "$SCRIPT_DIR/integration" "集成测试"
            ;;
        "help"|"-h"|"--help")
            show_help
            return 0
            ;;
        *)
            # 如果是文件路径，运行单个测试
            if [[ -f "$target" ]]; then
                run_single_test "$target"
            elif [[ -f "$SCRIPT_DIR/$target" ]]; then
                run_single_test "$SCRIPT_DIR/$target"
            elif [[ -f "$SCRIPT_DIR/unit/$target" ]]; then
                run_single_test "$SCRIPT_DIR/unit/$target"
            elif [[ -f "$SCRIPT_DIR/integration/$target" ]]; then
                run_single_test "$SCRIPT_DIR/integration/$target"
            else
                echo -e "${RED}错误: 未知目标 '$target'${NC}"
                show_help
                return 1
            fi
            ;;
    esac
    
    # 打印总结
    print_test_summary
    return $?
}

show_help() {
    cat << EOF
用法: $0 [目标]

目标:
  all             运行所有测试（默认）
  unit            只运行单元测试
  integration     只运行集成测试
  <测试文件>      运行指定的测试文件
  help            显示此帮助信息

示例:
  $0              运行所有测试
  $0 unit         运行单元测试
  $0 test/unit/test_ui_functions.sh  运行特定测试

测试文件位置:
  单元测试: $SCRIPT_DIR/unit/
  集成测试: $SCRIPT_DIR/integration/
EOF
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi