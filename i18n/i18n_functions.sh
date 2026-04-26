#!/usr/bin/env bash
# IPtctl 国际化函数库
# 提供多语言支持功能

# set -euo pipefail # 移除以避免影响引用它的脚本

# ============================================================
# 全局变量
# ============================================================

# 支持的语言列表
declare -a SUPPORTED_LANGUAGES=("en" "zh-CN")

# 默认语言
DEFAULT_LANGUAGE="en"

# 当前语言
CURRENT_LANGUAGE="$DEFAULT_LANGUAGE"

# 翻译缓存
declare -A TRANSLATION_CACHE

# 语言文件目录
I18N_DIR="$(dirname "${BASH_SOURCE[0]}")"
LOCALES_DIR="$I18N_DIR/locales"

# ============================================================
# 工具函数
# ============================================================

# 获取当前语言
get_current_language() {
    echo "$CURRENT_LANGUAGE"
}

# 设置语言
set_language() {
    local lang="$1"
    
    # 检查是否支持该语言
    if [[ " ${SUPPORTED_LANGUAGES[*]} " != *" $lang "* ]]; then
        echo "警告: 不支持的语言 '$lang'，使用默认语言 '$DEFAULT_LANGUAGE'" >&2
        lang="$DEFAULT_LANGUAGE"
    fi
    
    CURRENT_LANGUAGE="$lang"
    
    # 清空缓存
    TRANSLATION_CACHE=()
    
    # 加载语言文件
    load_language_file "$lang"
}

# 检测系统语言
detect_system_language() {
    local lang=""
    
    # 1. 检查环境变量
    if [[ -n "${IPTCTL_LANG:-}" ]]; then
        lang="$IPTCTL_LANG"
    elif [[ -n "${LANG:-}" ]]; then
        # 从 LANG 环境变量提取语言代码
        lang="${LANG%%.*}"
    elif [[ -n "${LC_ALL:-}" ]]; then
        lang="${LC_ALL%%.*}"
    elif [[ -n "${LC_MESSAGES:-}" ]]; then
        lang="${LC_MESSAGES%%.*}"
    fi
    
    # 标准化语言代码
    case "$lang" in
        "zh_CN"|"zh-CN"|"zh_cn")
            echo "zh-CN"
            ;;
        "zh_TW"|"zh-TW"|"zh_tw")
            echo "zh-TW"
            ;;
        "en"|"en_US"|"en_GB"|"en_US.UTF-8")
            echo "en"
            ;;
        *)
            # 如果不支持，使用默认语言
            echo "$DEFAULT_LANGUAGE"
            ;;
    esac
}

# ============================================================
# 语言文件加载
# ============================================================

# 加载语言文件
load_language_file() {
    local lang="$1"
    local lang_file="$LOCALES_DIR/$lang.json"
    
    # 检查语言文件是否存在
    if [[ ! -f "$lang_file" ]]; then
        echo "警告: 语言文件不存在 '$lang_file'，使用默认语言" >&2
        lang_file="$LOCALES_DIR/$DEFAULT_LANGUAGE.json"
        
        if [[ ! -f "$lang_file" ]]; then
            echo "错误: 默认语言文件不存在 '$lang_file'" >&2
            return 1
        fi
    fi
    
    # 解析 JSON 文件
    if ! parse_json_file "$lang_file"; then
        echo "错误: 无法解析语言文件 '$lang_file'" >&2
        return 1
    fi
    
    return 0
}

# 解析 JSON 文件（支持一层嵌套，将其扁平化为 parent.child 格式）
parse_json_file() {
    local json_file="$1"
    
    # 清空缓存
    TRANSLATION_CACHE=()
    
    local current_parent=""
    local line
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 移除首尾空格
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        
        # 跳过空行和注释
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^// ]] && continue
        
        # 检测对象开始: "parent": {
        if [[ "$line" =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\{ ]]; then
            current_parent="${BASH_REMATCH[1]}"
            continue
        fi
        
        # 检测对象结束: }
        if [[ "$line" == "}," || "$line" == "}" ]]; then
            current_parent=""
            continue
        fi
        
        # 检测键值对: "key": "value"
        if [[ "$line" =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
            local match_key="${BASH_REMATCH[1]}"
            local match_value="${BASH_REMATCH[2]}"
            
            local full_key="$match_key"
            if [[ -n "$current_parent" ]]; then
                full_key="${current_parent}.${match_key}"
            fi
            
            # 存储到缓存
            TRANSLATION_CACHE["$full_key"]="$match_value"
        fi
    done < "$json_file"
    
    return 0
}

# ============================================================
# 翻译函数
# ============================================================

# 获取翻译
t() {
    local key="$1"
    local default_value="${2:-}"
    
    # 检查缓存
    if [[ -n "${TRANSLATION_CACHE[$key]:-}" ]]; then
        echo "${TRANSLATION_CACHE[$key]}"
        return 0
    fi
    
    # 如果缓存中没有，尝试加载默认语言
    if [[ "$CURRENT_LANGUAGE" != "$DEFAULT_LANGUAGE" ]]; then
        # 临时切换到默认语言
        local temp_lang="$CURRENT_LANGUAGE"
        set_language "$DEFAULT_LANGUAGE"
        
        if [[ -n "${TRANSLATION_CACHE[$key]:-}" ]]; then
            local result="${TRANSLATION_CACHE[$key]}"
            # 恢复原语言
            set_language "$temp_lang"
            echo "$result"
            return 0
        fi
        
        # 恢复原语言
        set_language "$temp_lang"
    fi
    
    # 如果还没有找到，使用默认值或键本身
    if [[ -n "$default_value" ]]; then
        echo "$default_value"
    else
        echo "$key"
    fi
    
    return 0
}

# 带格式的翻译
t_printf() {
    local format_key="$1"
    shift
    
    local format_string
    format_string=$(t "$format_key")
    
    # 替换占位符 {0}, {1}, ...
    local i=0
    for arg in "$@"; do
        format_string="${format_string//\{$i\}/$arg}"
        ((i++))
    done
    
    echo "$format_string"
}

# 复数形式翻译（简化版本）
t_plural() {
    local key="$1"
    local count="$2"
    
    # 检查是否有复数形式
    local plural_key="${key}_plural"
    
    if [[ $count -eq 1 ]] || [[ $count -eq -1 ]]; then
        t "$key"
    else
        t "$plural_key" "$(t "$key")s"
    fi
}

# ============================================================
# 初始化函数
# ============================================================

# 初始化国际化
init_i18n() {
    local force_lang="${1:-}"
    
    # 确定使用的语言
    if [[ -n "$force_lang" ]]; then
        set_language "$force_lang"
    else
        local detected_lang
        detected_lang=$(detect_system_language)
        set_language "$detected_lang"
    fi
    
    # 验证语言文件加载成功
    if [[ ${#TRANSLATION_CACHE[@]} -eq 0 ]]; then
        echo "警告: 翻译缓存为空，国际化可能未正确初始化" >&2
        return 1
    fi
    
    return 0
}

# ============================================================
# 测试函数
# ============================================================

# 测试国际化功能
test_i18n() {
    echo "测试国际化功能..."
    echo "当前语言: $(get_current_language)"
    
    # 测试基本翻译
    echo "测试基本翻译:"
    echo "  welcome: $(t "ui.welcome")"
    echo "  success: $(t "messages.success")"
    
    # 测试带格式的翻译
    echo "测试带格式的翻译:"
    echo "  backup: $(t_printf "backup.backup_created" "test_backup.rules")"
    
    # 测试语言切换
    echo "测试语言切换:"
    set_language "en"
    echo "  English welcome: $(t "ui.welcome")"
    
    set_language "zh-CN"
    echo "  中文欢迎: $(t "ui.welcome")"
    
    # 恢复默认语言
    set_language "en"
    
    echo "国际化测试完成"
}

# ============================================================
# 主函数
# ============================================================

# 如果直接运行此脚本，则执行测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 初始化
    if init_i18n; then
        test_i18n
    else
        echo "国际化初始化失败"
        exit 1
    fi
fi