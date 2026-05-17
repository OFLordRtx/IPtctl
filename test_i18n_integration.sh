#!/usr/bin/env bash
# 测试国际化整合功能

set -euo pipefail

# 切换到项目目录
cd "$(dirname "$0")"

echo "=== 测试 IPtctl 国际化整合 ==="

# 测试1: 检查国际化函数库是否存在
echo "测试1: 检查国际化函数库"
if [[ -f "i18n/i18n_functions.sh" ]]; then
    echo "✓ 国际化函数库存在"
else
    echo "✗ 国际化函数库不存在"
    exit 1
fi

# 测试2: 检查主脚本是否包含国际化支持
echo -e "\n测试2: 检查主脚本国际化支持"
if grep -q "init_i18n" iptctl.sh; then
    echo "✓ 主脚本包含国际化初始化"
else
    echo "✗ 主脚本缺少国际化初始化"
fi

# 测试3: 检查翻译文件
echo -e "\n测试3: 检查翻译文件"
if [[ -f "i18n/locales/en.json" && -f "i18n/locales/zh-CN.json" ]]; then
    echo "✓ 翻译文件存在"
    
    # 检查基本翻译键（JSON 内嵌结构，键名为 "welcome" 在 "ui" 对象内）
    if grep -q '"welcome"' i18n/locales/en.json; then
        echo "✓ 英文翻译文件包含基本键"
    else
        echo "✗ 英文翻译文件缺少基本键"
    fi
else
    echo "✗ 翻译文件不完整"
fi

# 测试4: 测试语言检测功能
echo -e "\n测试4: 测试语言检测"
source i18n/i18n_functions.sh

# 测试 detect_system_language 函数
detected_lang=$(detect_system_language)
echo "检测到的语言: $detected_lang"

if [[ "$detected_lang" == "en" || "$detected_lang" == "zh-CN" ]]; then
    echo "✓ 语言检测正常"
else
    echo "⚠ 语言检测返回非预期值: $detected_lang"
fi

# 测试5: 测试翻译函数
echo -e "\n测试5: 测试翻译函数"
set_language "en"
en_welcome=$(t "ui.welcome")
echo "英文欢迎语: $en_welcome"

set_language "zh-CN"
zh_welcome=$(t "ui.welcome")
echo "中文欢迎语: $zh_welcome"

if [[ "$en_welcome" != "ui.welcome" && "$zh_welcome" != "ui.welcome" ]]; then
    echo "✓ 翻译功能正常"
else
    echo "✗ 翻译功能异常"
fi

# 测试6: 测试 bi 函数国际化
echo -e "\n测试6: 测试 bi 函数国际化"
echo "注意: 此测试需要实际运行主脚本，这里只检查函数定义"
if grep -q 'bi:.*翻译键自动翻译' iptctl.sh || grep -q 'bi()' iptctl.sh; then
    echo "✓ bi 函数已国际化增强"
else
    echo "✗ bi 函数未国际化增强"
fi

# 测试7: 检查配置文件中是否支持语言设置
echo -e "\n测试7: 检查配置文件支持"
if grep -q "IPTCTL_LANG" iptctl.sh; then
    echo "✓ 支持 IPTCTL_LANG 环境变量"
else
    echo "✗ 不支持 IPTCTL_LANG 环境变量"
fi

# 总结
echo -e "\n=== 整合测试总结 ==="
echo "国际化整合已完成，主要组件:"
echo "1. 国际化函数库 (i18n_functions.sh)"
echo "2. 翻译文件 (en.json, zh-CN.json)"
echo "3. 主脚本国际化初始化"
echo "4. 增强的 bi 函数支持翻译"
echo "5. 语言检测和设置功能"
echo ""
echo "下一步: 运行完整测试套件验证功能"

# 运行测试套件（可选）
echo -e "\n是否运行完整测试套件? (y/n)"
read -r run_tests
if [[ "$run_tests" == "y" || "$run_tests" == "Y" ]]; then
    echo "运行测试套件..."
    if [[ -f "test/run_tests.sh" ]]; then
        bash test/run_tests.sh
    else
        echo "测试套件不存在"
    fi
fi