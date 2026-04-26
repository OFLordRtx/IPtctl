#!/usr/bin/env bash
# IPtctl 基准测试辅助函数库
# 提供性能测量、监控、报告等功能

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 基准测试统计
BENCHMARK_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# 测试开始时间
BENCHMARK_START_TIME=$(date +%s.%N)

# 结果目录
RESULTS_DIR="results/$(date +%Y%m%d_%H%M%S)"
LATEST_DIR="results/latest"

# ============================================================
# 输出函数
# ============================================================

print_benchmark_info() {
    echo -e "${BLUE}[BENCHMARK]${NC} $*"
}

print_benchmark_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

print_benchmark_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

print_benchmark_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

print_benchmark_header() {
    local test_name="$1"
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}基准测试: $test_name${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# ============================================================
# 时间测量函数
# ============================================================

# 测量命令执行时间（毫秒）
measure_time() {
    local command="$1"
    local description="${2:-命令执行}"
    
    local start_time end_time duration_ms
    
    start_time=$(date +%s.%N)
    eval "$command" >/dev/null 2>&1
    end_time=$(date +%s.%N)
    
    duration_ms=$(echo "scale=3; ($end_time - $start_time) * 1000" | bc 2>/dev/null || \
                  echo "scale=3; ($end_time - $start_time) * 1000" | awk '{printf "%.3f", $1}')
    
    echo "$duration_ms"
}

# 测量函数执行时间
measure_function_time() {
    local function_name="$1"
    local args="${2:-}"
    
    local start_time end_time duration_ms
    
    start_time=$(date +%s.%N)
    $function_name $args
    end_time=$(date +%s.%N)
    
    duration_ms=$(echo "scale=3; ($end_time - $start_time) * 1000" | bc 2>/dev/null || \
                  echo "scale=3; ($end_time - $start_time) * 1000" | awk '{printf "%.3f", $1}')
    
    echo "$duration_ms"
}

# 多次测量取平均值
measure_time_average() {
    local command="$1"
    local iterations="${2:-5}"
    local description="${3:-命令执行}"
    
    local total_ms=0
    local min_ms=999999
    local max_ms=0
    
    print_benchmark_info "测量 $description (迭代 $iterations 次)"
    
    for ((i=1; i<=iterations; i++)); do
        local current_ms=$(measure_time "$command" "$description #$i")
        
        total_ms=$(echo "$total_ms + $current_ms" | bc 2>/dev/null || \
                   echo "$total_ms $current_ms" | awk '{print $1 + $2}')
        
        # 更新最小值和最大值
        if (( $(echo "$current_ms < $min_ms" | bc 2>/dev/null || echo "$current_ms < $min_ms" | awk '{print $1 < $2}') )); then
            min_ms=$current_ms
        fi
        
        if (( $(echo "$current_ms > $max_ms" | bc 2>/dev/null || echo "$current_ms > $max_ms" | awk '{print $1 > $2}') )); then
            max_ms=$current_ms
        fi
        
        echo "  迭代 $i: ${current_ms}ms"
    done
    
    local avg_ms=$(echo "scale=3; $total_ms / $iterations" | bc 2>/dev/null || \
                   echo "$total_ms $iterations" | awk '{printf "%.3f", $1 / $2}')
    
    echo "  平均: ${avg_ms}ms, 最小: ${min_ms}ms, 最大: ${max_ms}ms"
    
    echo "$avg_ms"
}

# ============================================================
# 内存测量函数
# ============================================================

# 获取当前进程内存使用（KB）
get_memory_usage() {
    local pid=$$
    
    # 尝试不同的方法获取内存使用
    if command -v ps >/dev/null 2>&1; then
        # 使用 ps 命令
        ps -o rss= -p "$pid" 2>/dev/null | awk '{print $1}'
    elif [[ -f /proc/self/status ]]; then
        # 使用 /proc 文件系统
        grep VmRSS /proc/self/status | awk '{print $2}'
    else
        echo "0"
    fi
}

# 测量命令峰值内存使用
measure_peak_memory() {
    local command="$1"
    local description="${2:-命令执行}"
    
    local start_memory end_memory peak_memory=0
    local pid
    
    # 在子进程中运行命令并监控内存
    (
        eval "$command" >/dev/null 2>&1 &
        pid=$!
        
        # 监控内存使用
        while kill -0 "$pid" 2>/dev/null; do
            local current_memory=$(get_memory_usage "$pid" 2>/dev/null || echo "0")
            
            if [[ "$current_memory" -gt "$peak_memory" ]]; then
                peak_memory=$current_memory
            fi
            
            sleep 0.01
        done
        
        wait "$pid"
        echo "$peak_memory"
    )
}

# ============================================================
# 性能断言函数
# ============================================================

assert_performance() {
    local actual_ms="$1"
    local threshold_ms="$2"
    local metric_name="$3"
    local description="${4:-}"
    
    ((BENCHMARK_COUNT++))
    
    if (( $(echo "$actual_ms <= $threshold_ms" | bc 2>/dev/null || \
            echo "$actual_ms $threshold_ms" | awk '{print $1 <= $2}') )); then
        ((PASS_COUNT++))
        print_benchmark_success "$metric_name: ${actual_ms}ms <= ${threshold_ms}ms $description"
        return 0
    else
        ((FAIL_COUNT++))
        print_benchmark_error "$metric_name: ${actual_ms}ms > ${threshold_ms}ms $description"
        return 1
    fi
}

assert_memory_usage() {
    local actual_kb="$1"
    local threshold_kb="$2"
    local metric_name="$3"
    local description="${4:-}"
    
    ((BENCHMARK_COUNT++))
    
    if [[ "$actual_kb" -le "$threshold_kb" ]]; then
        ((PASS_COUNT++))
        print_benchmark_success "$metric_name: ${actual_kb}KB <= ${threshold_kb}KB $description"
        return 0
    else
        ((FAIL_COUNT++))
        print_benchmark_error "$metric_name: ${actual_kb}KB > ${threshold_kb}KB $description"
        return 1
    fi
}

warn_performance() {
    local actual_ms="$1"
    local warning_ms="$2"
    local metric_name="$3"
    local description="${4:-}"
    
    if (( $(echo "$actual_ms > $warning_ms" | bc 2>/dev/null || \
            echo "$actual_ms $warning_ms" | awk '{print $1 > $2}') )); then
        ((WARN_COUNT++))
        print_benchmark_warning "$metric_name: ${actual_ms}ms > ${warning_ms}ms (警告阈值) $description"
        return 1
    fi
    
    return 0
}

# ============================================================
# 环境信息收集
# ============================================================

collect_environment_info() {
    local info_file="${1:-$RESULTS_DIR/environment.json}"
    
    mkdir -p "$(dirname "$info_file")"
    
    cat > "$info_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "system": {
    "os": "$(uname -s)",
    "kernel": "$(uname -r)",
    "architecture": "$(uname -m)",
    "hostname": "$(hostname)"
  },
  "hardware": {
    "cpu_cores": "$(nproc 2>/dev/null || echo "unknown")",
    "memory_total_gb": "$(free -g 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "unknown")",
    "memory_available_gb": "$(free -g 2>/dev/null | awk '/^Mem:/ {print $7}' || echo "unknown")"
  },
  "software": {
    "bash_version": "$(bash --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")",
    "iptables_version": "$(iptables --version 2>/dev/null | head -n1 || echo "not installed")",
    "ip6tables_version": "$(ip6tables --version 2>/dev/null | head -n1 || echo "not installed")"
  },
  "benchmark": {
    "script_version": "1.0.0",
    "test_count": "$BENCHMARK_COUNT"
  }
}
EOF
    
    print_benchmark_info "环境信息已保存到: $info_file"
}

# ============================================================
# 结果存储函数
# ============================================================

save_benchmark_result() {
    local test_name="$1"
    local metrics="$2"  # JSON 格式的指标数据
    
    mkdir -p "$RESULTS_DIR"
    mkdir -p "$LATEST_DIR"
    
    local result_file="$RESULTS_DIR/${test_name}.json"
    local latest_file="$LATEST_DIR/${test_name}.json"
    
    # 创建完整的结果对象
    cat > "$result_file" << EOF
{
  "test_name": "$test_name",
  "timestamp": "$(date -Iseconds)",
  "environment": {
    "bash_version": "$(bash --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")",
    "system": "$(uname -s) $(uname -r)"
  },
  "metrics": $metrics,
  "status": "$([[ $FAIL_COUNT -eq 0 ]] && echo "PASS" || echo "FAIL")"
}
EOF
    
    # 复制到最新目录
    cp "$result_file" "$latest_file"
    
    print_benchmark_info "测试结果已保存到: $result_file"
}

# ============================================================
# 测试环境函数
# ============================================================

setup_benchmark_env() {
    print_benchmark_info "设置基准测试环境..."
    
    # 创建结果目录
    mkdir -p "$RESULTS_DIR"
    mkdir -p "$LATEST_DIR"
    
    # 收集环境信息
    collect_environment_info
    
    # 创建临时目录
    export BENCHMARK_TEMP_DIR=$(mktemp -d)
    print_benchmark_info "临时目录: $BENCHMARK_TEMP_DIR"
    
    # 备份原始环境
    export BENCHMARK_ORIGINAL_PWD="$PWD"
    
    # 进入临时目录
    cd "$BENCHMARK_TEMP_DIR"
    
    # 创建测试用的 iptctl 副本
    cp "$BENCHMARK_ORIGINAL_PWD/../iptctl.sh" "./iptctl_benchmark.sh"
    chmod +x "./iptctl_benchmark.sh"
    
    print_benchmark_info "基准测试环境设置完成"
}

cleanup_benchmark_env() {
    print_benchmark_info "清理基准测试环境..."
    
    # 返回原始目录
    cd "$BENCHMARK_ORIGINAL_PWD"
    
    # 清理临时目录
    if [[ -d "$BENCHMARK_TEMP_DIR" ]]; then
        rm -rf "$BENCHMARK_TEMP_DIR"
        print_benchmark_info "临时目录已清理: $BENCHMARK_TEMP_DIR"
    fi
    
    print_benchmark_info "基准测试环境清理完成"
}

# ============================================================
# 测试报告函数
# ============================================================

print_benchmark_summary() {
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $BENCHMARK_START_TIME" | bc 2>/dev/null || \
                     echo "$end_time $BENCHMARK_START_TIME" | awk '{print $1 - $2}')
    
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}基准测试总结${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "总测试数: $BENCHMARK_COUNT"
    echo -e "${GREEN}通过: $PASS_COUNT${NC}"
    echo -e "${RED}失败: $FAIL_COUNT${NC}"
    echo -e "${YELLOW}警告: $WARN_COUNT${NC}"
    echo -e "测试时长: ${duration}秒"
    echo -e "结果目录: $RESULTS_DIR"
    echo -e "最新结果: $LATEST_DIR"
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "\n${GREEN}所有性能测试通过！${NC}"
        return 0
    else
        echo -e "\n${RED}有 $FAIL_COUNT 个性能测试失败${NC}"
        return 1
    fi
}

# ============================================================
# 工具函数
# ============================================================

# 检查是否安装了必要的工具
check_benchmark_tools() {
    local missing_tools=()
    
    for tool in "bc" "awk" "ps" "time"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_benchmark_warning "缺少工具: ${missing_tools[*]}"
        print_benchmark_info "部分功能可能受限"
        return 1
    fi
    
    return 0
}

# 生成性能报告摘要
generate_performance_summary() {
    local summary_file="$RESULTS_DIR/summary.md"
    
    cat > "$summary_file" << EOF
# IPtctl 性能基准测试报告

## 测试信息
- 测试时间: $(date)
- 测试数量: $BENCHMARK_COUNT
- 通过数量: $PASS_COUNT
- 失败数量: $FAIL_COUNT
- 警告数量: $WARN_COUNT

## 环境信息
- 系统: $(uname -s) $(uname -r)
- Bash 版本: $(bash --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
- CPU 核心: $(nproc 2>/dev/null || echo "unknown")
- 总内存: $(free -g 2>/dev/null | awk '/^Mem:/ {print $2 "GB"}' || echo "unknown")

## 测试结果
$(if [[ $FAIL_COUNT -eq 0 ]]; then echo "✅ 所有性能测试通过"; else echo "❌ 有 $FAIL_COUNT 个测试失败"; fi)

## 详细结果
详细测试结果请查看:
- $RESULTS_DIR/

## 性能建议
$(if [[ $WARN_COUNT -gt 0 ]]; then echo "⚠️  有 $WARN_COUNT 个性能警告，建议优化"; else echo "✅ 无性能警告"; fi)

## 历史对比
$(if [[ -d "results/historical" ]]; then 
  echo "可与历史测试结果对比"
else
  echo "首次基准测试，无历史数据"
fi)
EOF
    
    print_benchmark_info "性能报告摘要已生成: $summary_file"
}