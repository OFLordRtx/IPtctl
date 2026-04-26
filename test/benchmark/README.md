# IPtctl 性能基准测试

本目录包含 IPtctl 的性能基准测试套件，用于测量和监控脚本的性能表现。

## 测试目标

1. **响应时间**：测量不同操作的执行时间
2. **内存使用**：监控脚本的内存消耗
3. **可扩展性**：测试不同规模规则集的性能
4. **并发性能**：测试多用户/多会话场景

## 测试环境要求

- Bash 5.0+
- `time` 命令
- `ps` 命令（用于内存监控）
- `bc` 或 `awk`（用于计算）
- iptables/ip6tables（用于实际测试）

## 测试结构

```
benchmark/
├── README.md
├── run_benchmarks.sh          # 基准测试运行主脚本
├── benchmark_helpers.sh       # 基准测试辅助函数
├── response_time/             # 响应时间测试
│   ├── test_ui_response.sh
│   ├── test_rule_operations.sh
│   └── test_backup_restore.sh
├── memory_usage/              # 内存使用测试
│   ├── test_memory_baseline.sh
│   └── test_memory_scaling.sh
├── scalability/               # 可扩展性测试
│   ├── test_rule_scaling.sh
│   └── test_session_scaling.sh
└── results/                   # 测试结果存储
    ├── latest/
    └── historical/
```

## 测试指标

### 1. 响应时间指标

- **启动时间**：脚本初始化时间
- **菜单加载时间**：各模式菜单加载时间
- **规则操作时间**：添加/删除/查询规则的时间
- **备份/恢复时间**：备份和恢复操作的时间

### 2. 内存指标

- **峰值内存**：脚本运行期间的最大内存使用
- **平均内存**：运行期间的平均内存使用
- **内存泄漏**：长时间运行的内存增长

### 3. 可扩展性指标

- **规则数量影响**：不同规则数量下的性能变化
- **会话数量影响**：多会话并发性能
- **文件大小影响**：备份文件大小对性能的影响

## 运行基准测试

```bash
# 运行所有基准测试
./test/benchmark/run_benchmarks.sh

# 运行特定测试类别
./test/benchmark/run_benchmarks.sh response_time
./test/benchmark/run_benchmarks.sh memory_usage
./test/benchmark/run_benchmarks.sh scalability

# 运行单个测试
./test/benchmark/run_benchmarks.sh test/benchmark/response_time/test_ui_response.sh
```

## 测试结果格式

测试结果以 JSON 格式存储，包含：

```json
{
  "test_name": "ui_response_test",
  "timestamp": "2026-04-26T03:18:04Z",
  "environment": {
    "bash_version": "5.3.9",
    "system": "Linux 6.19",
    "cpu_cores": 4,
    "memory_gb": 8
  },
  "metrics": {
    "startup_time_ms": 120,
    "menu_load_time_ms": 45,
    "peak_memory_kb": 5120,
    "average_memory_kb": 3200
  },
  "thresholds": {
    "startup_time_max_ms": 200,
    "menu_load_time_max_ms": 100,
    "peak_memory_max_kb": 10240
  },
  "status": "PASS"
}
```

## 性能阈值

### 响应时间阈值

- 启动时间：< 200ms
- 菜单加载时间：< 100ms
- 规则添加时间：< 50ms/规则
- 备份时间：< 100ms/MB

### 内存阈值

- 峰值内存：< 10MB
- 平均内存：< 5MB
- 内存泄漏：< 1MB/小时

## 基准测试报告

每次运行基准测试后，会生成以下报告：

1. **控制台摘要**：关键指标的通过/失败状态
2. **详细报告**：JSON 格式的详细数据
3. **趋势图表**：与历史数据的对比（如果配置了）
4. **建议报告**：性能优化建议

## 持续集成集成

基准测试已集成到 GitHub Actions，在以下情况下自动运行：

- 每次发布前
- 每周一次（监控性能回归）
- 主要功能变更后

## 性能优化建议

基于基准测试结果，可能会提出以下优化建议：

1. **代码优化**：识别性能瓶颈函数
2. **缓存策略**：添加结果缓存
3. **异步操作**：将耗时操作异步化
4. **内存管理**：优化内存使用模式
5. **算法改进**：使用更高效的算法

## 历史数据跟踪

基准测试结果会存储在 `results/historical/` 目录中，用于：

- 性能趋势分析
- 回归检测
- 版本间性能对比

## 自定义测试

要添加自定义基准测试，请参考现有测试模板，并确保：

1. 使用基准测试辅助函数
2. 遵循测试结果格式
3. 包含适当的清理代码
4. 添加性能阈值检查
