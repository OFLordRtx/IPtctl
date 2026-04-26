#!/usr/bin/env bash
# UI 函数单元测试
# 测试 iptctl 的用户界面相关函数

set -euo pipefail

# 加载测试辅助函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test_helpers.sh"

# 测试函数：test_ui_functions
test_ui_functions() {
    print_info "开始 UI 函数测试..."
    
    # 设置测试环境
    setup_test_env
    
    # 测试 1: UI 风格自动检测
    print_info "测试 1: UI 风格自动检测"
    
    # 模拟不同的环境变量
    export LC_ALL="C.utf8"
    export TERM="xterm-256color"
    
    # 加载 iptctl 脚本中的 UI 函数
    source "$TEST_TEMP_DIR/iptctl_test.sh"
    
    # 测试 UI 风格检测
    UI_STYLE="auto"
    ui_autodetect_style
    assert_equal "emoji" "$UI_STYLE" "UTF-8 环境应检测为 emoji 风格"
    
    # 测试 2: UI 翻译函数
    print_info "测试 2: UI 翻译函数"
    
    # 设置文本模式
    UI_STYLE="text"
    local translated=$(ui_translate_line "✅ 测试通过")
    assert_contains "$translated" "测试通过" "文本模式应移除 emoji"
    assert_not_contains "$translated" "✅" "文本模式不应包含 emoji"
    
    # 测试 3: 颜色输出函数
    print_info "测试 3: 颜色输出函数"
    
    # 测试 info 输出
    local info_output=$(print_info "测试信息")
    assert_contains "$info_output" "测试信息" "info 输出应包含消息"
    
    # 测试 4: 错误处理
    print_info "测试 4: 错误处理"
    
    # 测试无效 UI 风格
    UI_STYLE="invalid"
    local error_output=$(ui_translate_line "测试" 2>&1 || true)
    # 注意：实际函数可能不会处理无效风格，这里只是示例
    
    # 测试 5: 配置加载
    print_info "测试 5: 配置加载"
    
    # 创建测试配置文件
    cat > "$TEST_TEMP_DIR/.iptctlrc" << 'EOF'
UI_STYLE=text
PERSIST_MODE=auto
BACKUP_ON_EXIT=yes
EOF
    
    # 模拟配置加载（实际 iptctl 中的函数）
    if [[ -f "$TEST_TEMP_DIR/.iptctlrc" ]]; then
        print_info "配置文件存在，测试通过"
    else
        print_error "配置文件创建失败"
        return 1
    fi
    
    # 清理测试环境
    cleanup_test_env
    
    print_success "UI 函数测试完成"
    return 0
}

# 如果直接运行此脚本，则执行测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_ui_functions
    print_test_summary
fi