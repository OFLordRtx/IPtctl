# 贡献指南

感谢您对 IPtctl 项目的关注！我们欢迎各种形式的贡献，包括但不限于：

- 报告 Bug
- 提出新功能建议
- 改进文档
- 提交代码修复或新功能

## 开发环境设置

### 1. 克隆仓库

```bash
git clone https://github.com/OFMeteoriteH/IPtctl.git
cd IPtctl
```

### 2. 环境要求

- Bash 5.0+
- iptables/ip6tables（用于测试）
- 基本的 Linux 环境

### 3. 运行测试

```bash
# 运行所有测试
./test/run_tests.sh

# 只运行单元测试
./test/run_tests.sh unit

# 运行特定测试文件
./test/run_tests.sh test/unit/test_ui_functions.sh
```

## 代码规范

### 1. Bash 代码风格

- 使用 2 个空格缩进
- 函数名使用小写字母和下划线：`function_name()`
- 局部变量使用 `local` 关键字
- 使用双引号引用变量：`"$variable"`
- 使用 `[[ ]]` 进行条件测试

### 2. 注释规范

- 文件头部注释说明文件用途
- 函数注释说明功能、参数和返回值
- 复杂逻辑添加行内注释

示例：

```bash
#!/usr/bin/env bash
# 文件名：example.sh
# 功能：示例脚本

# 函数：say_hello
# 参数：
#   $1 - 姓名
# 返回值：无
say_hello() {
    local name="$1"
    echo "Hello, $name!"
}
```

### 3. 错误处理

- 使用 `set -euo pipefail` 确保严格模式
- 检查命令返回值
- 提供有意义的错误信息

## 提交代码流程

### 1. 创建分支

```bash
git checkout -b feature/your-feature-name
# 或
git checkout -b fix/issue-description
```

### 2. 进行修改

- 编写代码
- 添加或更新测试
- 更新文档（如果需要）

### 3. 运行测试

确保所有测试通过：

```bash
./test/run_tests.sh all
```

### 4. 提交代码

```bash
git add .
git commit -m "类型: 描述信息"
```

提交信息格式：

- `feat: 添加新功能`
- `fix: 修复问题`
- `docs: 更新文档`
- `test: 添加或更新测试`
- `refactor: 代码重构`
- `style: 代码格式调整`
- `chore: 构建过程或辅助工具变动`

### 5. 推送分支

```bash
git push origin feature/your-feature-name
```

### 6. 创建 Pull Request

在 GitHub 上创建 Pull Request，并确保：

- 描述清楚修改内容
- 关联相关 Issue（如果有）
- 通过所有 CI 检查

## 测试指南

### 1. 测试结构

```
test/
├── run_tests.sh          # 测试运行主脚本
├── test_helpers.sh       # 测试辅助函数
├── unit/                 # 单元测试
│   ├── test_ui_functions.sh
│   └── test_backup_functions.sh
└── integration/          # 集成测试（待添加）
```

### 2. 编写新测试

1. 在 `test/unit/` 或 `test/integration/` 目录创建测试文件
2. 文件名以 `test_` 开头，以 `.sh` 结尾
3. 测试函数名以 `test_` 开头
4. 使用测试辅助函数中的断言函数

示例：

```bash
#!/usr/bin/env bash
# test_example.sh

source ../test_helpers.sh

test_example_function() {
    print_info "开始示例测试..."

    setup_test_env

    # 测试代码
    assert_equal "expected" "actual" "描述信息"

    cleanup_test_env

    print_success "示例测试完成"
    return 0
}
```

### 3. 测试覆盖率

我们鼓励为所有新功能编写测试，目标包括：

- 核心功能 100% 测试覆盖
- 边界条件测试
- 错误处理测试

## 文档更新

### 1. README.md

- 更新功能描述
- 添加使用示例
- 更新安装说明

### 2. 测试文档

- 更新 `test/README.md`
- 添加新测试的说明

### 3. 代码注释

- 为新函数添加注释
- 更新现有注释（如果修改了函数）

## 问题报告

### 1. 报告 Bug

在 GitHub Issues 中报告 Bug，请提供：

- 问题描述
- 复现步骤
- 期望行为
- 实际行为
- 环境信息（系统、Bash 版本等）

### 2. 功能建议

在 GitHub Issues 中提出功能建议，请说明：

- 功能需求
- 使用场景
- 可能的实现方案

## 代码审查流程

1. 至少需要一名维护者审查
2. 审查重点：
   - 代码质量
   - 测试覆盖
   - 文档更新
   - 性能影响
3. 可能需要修改后重新提交

## 发布流程

1. 版本号遵循语义化版本（SemVer）
2. 创建版本标签：`v1.2.3`
3. GitHub Actions 自动创建发布
4. 更新 CHANGELOG.md

## 行为准则

请遵守项目的行为准则，保持友好、尊重的交流氛围。

## 联系方式

- GitHub Issues: 问题讨论
- Pull Requests: 代码贡献
- 项目维护者: @OFMeteoriteH

感谢您的贡献！
