#!/usr/bin/env bash
# IPtctl 测试辅助函数库
# 提供断言、模拟、环境设置等测试工具

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试统计
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# 测试开始时间
TEST_START_TIME=$(date +%s)

# ============================================================
# 输出函数
# ============================================================

print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

print_test_header() {
    local test_name="$1"
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}测试: $test_name${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# ============================================================
# 断言函数
# ============================================================

assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    ((TEST_COUNT++))

    if [[ "$expected" == "$actual" ]]; then
        ((PASS_COUNT++))
        print_success "assert_equal: $message"
        return 0
    else
        ((FAIL_COUNT++))
        print_error "assert_equal: $message"
        echo "  期望: '$expected'"
        echo "  实际: '$actual'"
        return 1
    fi
}

assert_not_equal() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-}"

    ((TEST_COUNT++))

    if [[ "$unexpected" != "$actual" ]]; then
        ((PASS_COUNT++))
        print_success "assert_not_equal: $message"
        return 0
    else
        ((FAIL_COUNT++))
        print_error "assert_not_equal: $message"
        echo "  不应等于: '$unexpected'"
        echo "  实际: '$actual'"
        return 1
    fi
}

assert_contains() {
    local container="$1"
    local content="$2"
    local message="${3:-}"

    ((TEST_COUNT++))

    if [[ "$container" == *"$content"* ]]; then
        ((PASS_COUNT++))
        print_success "assert_contains: $message"
        return 0
    else
        ((FAIL_COUNT++))
        print_error "assert_contains: $message"
        echo "  容器: '$container'"
        echo "  应包含: '$content'"
        return 1
    fi
}

assert_not_contains() {
    local container="$1"
    local content="$2"
    local message="${3:-}"

    ((TEST_COUNT++))

    if [[ "$container" != *"$content"* ]]; then
        ((PASS_COUNT++))
        print_success "assert_not_contains: $message"
        return 0
    else
        ((FAIL_COUNT++))
        print_error "assert_not_contains: $message"
        echo "  容器: '$container'"
        echo "  不应包含: '$content'"
        return 1
    fi
}

assert_exit_success() {
    local command="$1"
    local message="${2:-命令应成功执行}"

    ((TEST_COUNT++))

    if eval "$command" >/dev/null 2>&1; then
        ((PASS_COUNT++))
        print_success "assert_exit_success: $message"
        return 0
    else
        ((FAIL_COUNT++))
        print_error "assert_exit_success: $message"
        echo "  命令: $command"
        return 1
    fi
}

assert_exit_failure() {
    local command="$1"
    local message="${2:-命令应失败}"

    ((TEST_COUNT++))

    if ! eval "$command" >/dev/null 2>&1; then
        ((PASS_COUNT++))
        print_success "assert_exit_failure: $message"
        return 0
    else
        ((FAIL_COUNT++))
        print_error "assert_exit_failure: $message"
        echo "  命令: $command"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-文件应存在}"

    ((TEST_COUNT++))

    if [[ -f "$file" ]]; then
        ((PASS_COUNT++))
        print_success "assert_file_exists: $message"
        return 0
    else
        ((FAIL_COUNT++))
        print_error "assert_file_exists: $message"
        echo "  文件: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-文件不应存在}"

    ((TEST_COUNT++))

    if [[ ! -f "$file" ]]; then
        ((PASS_COUNT++))
        print_success "assert_file_not_exists: $message"
        return 0
    else
        ((FAIL_COUNT++))
        print_error "assert_file_not_exists: $message"
        echo "  文件: $file"
        return 1
    fi
}

# ============================================================
# 测试环境函数
# ============================================================

setup_test_env() {
    print_info "设置测试环境..."
    
    # 创建临时目录
    export TEST_TEMP_DIR=$(mktemp -d)
    print_info "临时目录: $TEST_TEMP_DIR"
    
    # 备份原始环境
    export TEST_ORIGINAL_PWD="$PWD"
    export TEST_ORIGINAL_UMASK=$(umask)
    
    # 设置安全环境
    umask 077
    
    # 获取项目根目录
    local helpers_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(cd "$helpers_dir/.." && pwd)"

    # 创建测试用的 iptctl 副本
    cp "$project_root/iptctl.sh" "$TEST_TEMP_DIR/iptctl_test.sh"
    chmod +x "$TEST_TEMP_DIR/iptctl_test.sh"
    
    # 复制国际化文件
    cp -r "$project_root/i18n" "$TEST_TEMP_DIR/"
    
    # 进入临时目录
    cd "$TEST_TEMP_DIR"
    
    print_info "测试环境设置完成"
}

cleanup_test_env() {
    print_info "清理测试环境..."
    
    # 返回原始目录
    cd "$TEST_ORIGINAL_PWD"
    
    # 恢复原始 umask
    umask "$TEST_ORIGINAL_UMASK"
    
    # 清理临时目录
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
        print_info "临时目录已清理: $TEST_TEMP_DIR"
    fi
    
    print_info "测试环境清理完成"
}

# ============================================================
# 模拟函数
# ============================================================

mock_iptables() {
    # 创建模拟的 iptables 命令
    cat > "$TEST_TEMP_DIR/iptables" << 'EOF'
#!/usr/bin/env bash
# 模拟 iptables 命令
echo "模拟 iptables: $*" >&2
if [[ "$*" == *"--version"* ]]; then
    echo "iptables v1.8.9 (legacy)"
elif [[ "$*" == *"-L"* ]]; then
    cat << 'EOL'
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     all  --  anywhere             anywhere
2    DROP       tcp  --  anywhere             anywhere            tcp dpt:22

Chain FORWARD (policy ACCEPT)
num  target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination
EOL
else
    echo "OK"
fi
EOF
    
    chmod +x "$TEST_TEMP_DIR/iptables"
    export PATH="$TEST_TEMP_DIR:$PATH"
}

# ============================================================
# 测试报告函数
# ============================================================

print_test_summary() {
    local test_end_time=$(date +%s)
    local test_duration=$((test_end_time - TEST_START_TIME))
    
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}测试总结${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "总测试数: $TEST_COUNT"
    echo -e "${GREEN}通过: $PASS_COUNT${NC}"
    echo -e "${RED}失败: $FAIL_COUNT${NC}"
    echo -e "${YELLOW}跳过: $SKIP_COUNT${NC}"
    echo -e "测试时长: ${test_duration}秒"
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "\n${GREEN}所有测试通过！${NC}"
        return 0
    else
        echo -e "\n${RED}有 $FAIL_COUNT 个测试失败${NC}"
        return 1
    fi
}

skip_test() {
    local reason="$1"
    ((SKIP_COUNT++))
    print_warning "跳过测试: $reason"
}

# ============================================================
# 测试运行器
# ============================================================

run_test_suite() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)
    
    print_test_header "$test_name"
    
    # 加载测试文件
    if [[ -f "$test_file" ]]; then
        source "$test_file"
        print_info "测试文件加载完成: $test_file"
    else
        print_error "测试文件不存在: $test_file"
        return 1
    fi
    
    # 运行测试
    if declare -f "test_$test_name" >/dev/null; then
        if "test_$test_name"; then
            print_success "测试执行完成: $test_name"
            return 0
        else
            print_error "测试执行失败: $test_name"
            return 1
        fi
    else
        print_warning "未找到测试函数: test_$test_name"
        return 0
    fi
}