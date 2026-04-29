# IPtctl 更新日志

所有对 IPtctl 项目的显著更改都将记录在此文件中。

项目遵循[语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0.0] - 2026-04-26

### 新增

- 添加完整的测试套件框架
- 集成 GitHub Actions CI/CD 流水线
- 添加贡献指南 (CONTRIBUTING.md)
- 添加版本管理和发布流程

### 变更

- 改进测试环境设置
- 优化项目文档结构

### 修复

- 无

## [1.0.0] - 2026-04-26

### 新增

- 首次稳定版本发布
- 完整的 iptables/ip6tables 交互式管理脚本
- 三种操作模式：新手、标准、专家
- DSL（领域特定语言）支持
- 备份和恢复功能
- 持久化规则管理
- ipset 集成支持
- 多语言 UI 支持（中英文）

### 特性

- **新手模式**：强约束的安全菜单，防止误操作
- **标准模式**：完整的 iptables 功能菜单
- **专家模式**：REPL + 口语化 DSL
- **备份系统**：会话级备份和回滚
- **持久化**：支持 netfilter-persistent、iptables-services、systemd
- **ipset 管理**：创建、管理、应用 ipset 集合
- **UI 自适应**：emoji/text 风格自动切换
- **配置管理**：~/.iptctlrc 配置文件

## 版本格式

版本号格式：`主版本号.次版本号.修订号`

- **主版本号**：不兼容的 API 修改
- **次版本号**：向下兼容的功能性新增
- **修订号**：向下兼容的问题修复

## 发布类型

- **正式版**：`v1.2.3`
- **预发布版**：`v1.2.3-beta.1`
- **开发版**：`v1.2.3-dev`

## 如何更新

### 从 GitHub 发布页下载

```bash
# 下载最新版本
wget https://github.com/OFMeteoriteH/IPtctl/releases/latest/download/iptctl.sh
chmod +x iptctl.sh
sudo ./iptctl.sh
```

### 从源码更新

```bash
cd IPtctl
git fetch --tags
git checkout v1.2.3
```

## 版本历史

### v1.0.0

- 初始稳定版本
- 包含所有核心功能
- 完整的文档和测试套件

## 维护者

- @OFMeteoriteH

## 许可证

MIT © 2026
