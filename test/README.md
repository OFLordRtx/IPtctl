# IPtctl 测试套件

## 测试框架选择

由于系统可能没有安装 bats-core，我们选择使用 **纯 Bash 测试框架**，具有以下特点：

- 零依赖，仅需 Bash
- 支持断言函数
- 支持测试套件组织
- 支持测试报告

## 测试结构

```
test/
├── README.md
├── run_tests.sh          # 测试运行主脚本
├── test_helpers.sh       # 测试辅助函数
├── unit/                 # 单元测试
│   ├── test_ui_functions.bats
│   ├── test_dsl_parser.bats
│   └── test_backup_functions.bats
├── integration/          # 集成测试
│   ├── test_beginner_mode.bats
│   ├── test_standard_mode.bats
│   └── test_expert_mode.bats
└── fixtures/             # 测试夹具
    ├── mock_iptables.sh
    └── test_configs/
```

## 测试类型

### 1. 单元测试

- UI 函数测试
- DSL 解析器测试
- 备份/恢复功能测试
- 配置管理测试

### 2. 集成测试

- 各模式功能测试
- 命令行参数测试
- 错误处理测试
- 权限测试

### 3. 系统测试

- 完整流程测试
- 性能基准测试
- 兼容性测试

## 运行测试

```bash
# 运行所有测试
./test/run_tests.sh

# 运行特定测试类别
./test/run_tests.sh unit
./test/run_tests.sh integration

# 运行单个测试文件
./test/run_tests.sh test/unit/test_ui_functions.bats
```

## 测试环境要求

- Bash 5.0+
- iptables/ip6tables（或模拟环境）
- 适当的权限（部分测试需要 root）

## 持续集成

测试已集成到 GitHub Actions，每次推送都会自动运行测试套件。
