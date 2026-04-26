# IPtctl 国际化 (i18n) 支持

本目录包含 IPtctl 的国际化支持文件，支持多语言用户界面。

## 支持的语言

- **英语 (en)**：默认语言
- **简体中文 (zh-CN)**：中文支持
- **更多语言**：可根据需要添加

## 文件结构

```
i18n/
├── README.md
├── locales/                    # 语言文件目录
│   ├── en.json               # 英语翻译
│   ├── zh-CN.json            # 简体中文翻译
│   └── zh-TW.json            # 繁体中文翻译（预留）
├── i18n_functions.sh         # 国际化函数库
├── language_selector.sh      # 语言选择器
└── tools/                    # 国际化工具
    ├── extract_strings.sh    # 提取待翻译字符串
    ├── validate_translations.sh # 验证翻译完整性
    └── update_translations.sh   # 更新翻译文件
```

## 使用方法

### 1. 设置语言

```bash
# 方法1：环境变量
export IPTCTL_LANG=zh-CN
./iptctl.sh

# 方法2：配置文件
echo "LANGUAGE=zh-CN" >> ~/.iptctlrc
./iptctl.sh

# 方法3：命令行参数
./iptctl.sh --lang zh-CN
```

### 2. 语言检测顺序

1. 命令行参数 `--lang`
2. 环境变量 `IPTCTL_LANG`
3. 配置文件 `~/.iptctlrc` 中的 `LANGUAGE` 设置
4. 系统环境变量 `LANG` 或 `LC_ALL`
5. 默认英语 (en)

### 3. 语言代码

使用标准的语言代码：

- `en`：英语
- `zh-CN`：简体中文
- `zh-TW`：繁体中文
- `ja`：日语
- `ko`：韩语
- `fr`：法语
- `de`：德语
- `es`：西班牙语
- `ru`：俄语

## 语言文件格式

语言文件使用 JSON 格式，结构如下：

```json
{
  "meta": {
    "language": "zh-CN",
    "language_name": "简体中文",
    "version": "1.0.0",
    "author": "维护者",
    "last_updated": "2026-04-26"
  },
  "ui": {
    "welcome": "欢迎使用 iptctl",
    "select_mode": "请选择模式",
    "beginner_mode": "新手模式",
    "standard_mode": "标准模式",
    "expert_mode": "专家模式",
    "exit": "退出"
  },
  "messages": {
    "success": "操作成功",
    "error": "操作失败",
    "warning": "警告",
    "info": "信息"
  },
  "help": {
    "description": "iptables/ip6tables 交互式管理脚本"
  }
}
```

## 添加新语言

### 1. 创建语言文件

```bash
cd i18n/locales
cp en.json new-lang.json
# 编辑 new-lang.json 文件，翻译所有字符串
```

### 2. 注册新语言

编辑 `i18n_functions.sh` 中的 `SUPPORTED_LANGUAGES` 数组，添加新语言代码。

### 3. 测试新语言

```bash
export IPTCTL_LANG=new-lang
./iptctl.sh
```

## 开发指南

### 1. 在代码中使用国际化

```bash
# 加载国际化函数
source i18n/i18n_functions.sh

# 使用翻译函数
echo "$(t "ui.welcome")"
echo "$(t "messages.success")"
echo "$(t_printf "操作 %s 完成" "备份")"
```

### 2. 翻译函数

- `t(key)`：获取翻译字符串
- `t_printf(format, args...)`：带格式的翻译
- `t_plural(key, count)`：复数形式翻译
- `get_current_language()`：获取当前语言
- `set_language(lang)`：设置语言

### 3. 占位符处理

翻译字符串中的占位符使用 `{0}`, `{1}` 格式：

```json
{
  "messages": {
    "backup_created": "备份已创建: {0}",
    "rule_added": "规则已添加到 {0} 链"
  }
}
```

使用方式：

```bash
echo "$(t_printf "messages.backup_created" "backup_20240426.rules")"
```

## 工具使用

### 1. 提取待翻译字符串

```bash
./i18n/tools/extract_strings.sh
# 生成 i18n/strings_to_translate.txt
```

### 2. 验证翻译完整性

```bash
./i18n/tools/validate_translations.sh
# 检查所有语言文件的完整性
```

### 3. 更新翻译文件

```bash
./i18n/tools/update_translations.sh zh-CN
# 更新中文翻译文件
```

## 最佳实践

### 1. 翻译质量

- 保持术语一致性
- 考虑文化差异
- 测试不同长度的字符串
- 验证特殊字符显示

### 2. 代码维护

- 为所有用户可见的字符串添加翻译
- 使用有意义的键名
- 定期更新翻译
- 保持向后兼容性

### 3. 性能考虑

- 语言文件在启动时加载一次
- 使用缓存提高性能
- 避免在循环中频繁调用翻译函数

## 贡献翻译

### 1. 翻译流程

1. Fork 项目仓库
2. 创建新的语言文件或更新现有文件
3. 提交 Pull Request
4. 通过翻译验证测试

### 2. 翻译指南

- 保持技术术语准确
- 使用简洁明了的语言
- 遵循项目风格指南
- 测试实际显示效果

### 3. 质量保证

- 至少两人审核翻译
- 测试所有界面显示
- 验证命令行输出格式

## 常见问题

### 1. 翻译缺失

如果某个键没有翻译，会显示英语版本并记录警告。

### 2. 语言文件错误

如果语言文件格式错误，会回退到英语并显示错误信息。

### 3. 性能问题

如果语言文件过大，可能会影响启动速度。建议：

- 压缩不必要的空格
- 合并相似的字符串
- 使用懒加载策略

## 相关资源

- [Unicode CLDR](http://cldr.unicode.org/)：通用语言环境数据仓库
- [GNU gettext](https://www.gnu.org/software/gettext/)：国际化工具
- [ICU](http://site.icu-project.org/)：国际化组件

## 许可证

翻译文件遵循与主项目相同的 MIT 许可证。
