# iptctl

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash%205%2B-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&logoColor=black)](https://kernel.org)
[![Status: Active](https://img.shields.io/badge/Status-Active-brightgreen)](https://github.com/OFLordRtx/IPtctl/commits/main)

---

## 简介

`iptctl` 是一个运行在终端里的 iptables/ip6tables 交互式管理脚本。
核心目标只有一个：**让你少犯错、少锁死自己、该备份的能备份、出了事能回滚**。

三种模式覆盖从"第一次碰防火墙"到"手速熟练的运维"的不同场景：新手向导严格约束操作范围；标准模式提供完整菜单；专家模式是一个带 DSL 的 REPL，输什么跑什么。

**适合的场景：** Debian/Ubuntu/RHEL 系服务器日常防火墙管理、1Panel / Docker 宿主机规则维护、快速封禁 IP 段。

**不适合的场景：** 需要集中策略下发、企业级审计、复杂多跳 NAT 的生产环境——那种规模上更专业的方案。

---

## Introduction

`iptctl` is an interactive Bash script for managing iptables/ip6tables rules from the terminal.
It wraps raw iptables commands behind three distinct operating modes, adds backup/restore safeguards, persistent-rule helpers, an ipset integration, and a colloquial DSL that lets power users express rules in plain English.

**Good fit:** Debian/Ubuntu/RHEL servers, 1Panel/Docker hosts, quick IP banning via ipset.

**Not a fit:** Centralized policy management, enterprise auditing, complex multi-hop NAT at scale.

---

## 架构 / Architecture

```
iptctl
│
├── [新手 / Beginner]  ── 锁定 filter/INPUT，向导操作，强护栏
│     安全菜单 · 放行端口 · 已建立连接 · 固化 · ipset 封禁
│
├── [标准 / Standard]  ── 完整菜单，可切 table/chain，带备份确认
│     查看/添加/删除/批量删/清空/搜索/固化/ipset 管理
│
└── [专家 / Expert]    ── REPL 直通，DSL + 快捷补全，无护栏
      raw args · DSL shortcuts · block/unblock/policy · ipset · backup
```

三种模式共享同一套底层函数：`run_ipt` / `run_ipt_scope` / `do_backup` / `persist_apply` / `ipset_*`，切换模式不需要重启脚本。

---

## 功能列表 / Features

### 核心规则操作

- IPv4 / IPv6 / 双栈（同时操作 iptables + ip6tables）
- backend 选择：auto / nft / legacy（自动探测，也可手动锁定）
- 任意 table / chain（新手模式锁定 filter/INPUT）
- 查看规则：`-L`（带编号）/ `-S`（原始格式）
- 添加规则：向导模板（ESTABLISHED、TCP/UDP 端口、DROP ALL）+ 可选注释
- 规则注释：`-m comment --comment`，向导可选填，专家 DSL 用 `# 语法`
- 删除规则：按编号、批量编号/范围（降序执行，避免编号漂移）
- 清空链：`-F`，带多级确认
- 搜索规则：按端口号/IP 地址/任意关键字过滤 `-L` 输出
- 原始参数执行（Standard/Expert）
- **国际化支持 (i18n)**：支持中英文切换，自动检测系统语言

### 质量与安全

- **自动化测试**：完整的单元测试套件，确保核心逻辑稳定性
- **性能基准测试**：提供规则处理速度和内存占用指标
- **安全审计**：完善的 SECURITY.md 和 CVE 跟踪机制
- **版本管理**：遵循语义化版本，记录详细的 CHANGELOG.md

### 固化 / 持久化

- 三种方式：`netfilter-persistent`（Debian/Ubuntu）/ `iptables-services`（RHEL）/ systemd unit
- 自动检测并按优先级选择；也可手动指定方式
- 自动安装缺失的持久化工具（apt-get / dnf / yum）
- 改动后策略：off / prompt（每次询问）/ auto（静默保存）

### 备份与回滚

- 会话级备份：每次破坏性操作前可选备份，记录当次会话生成的文件
- 退出时可选保留或清理本次备份
- 备份目录：root → `/var/backups/iptctl`；普通用户 → `./iptctl-backups`

### ipset 集合管理

- 检测 / 一键安装 ipset（apt-get / dnf / yum）
- 创建 set（hash:ip / hash:net / hash:ip,port 等）
- 添加 / 删除单个 IP 或 CIDR
- 批量添加（逐行输入）
- 查看 / 清空 / 销毁 set
- 将 set 应用为 iptables 规则（src/dst × DROP/ACCEPT/REJECT）
- 新手模式：一键封禁列表（固定 set `iptctl-ban`，简化操作）

### 专家 DSL

- 口语化规则表达式，自动翻译为 iptables 参数
- `from` / `to` / `insert` / `on <iface>` 修饰符任意组合
- 动作：allow / accept / drop / deny / reject / log
- 多端口、端口范围
- `block` / `unblock`（自动识别 IPv4/v6）
- `policy` 设置链默认策略
- 行尾 `# 注释` 自动转为 `-m comment`

### 其他

- 纯 Bash 实现，**不依赖** grep/sed/awk/xargs/tr（仅依赖 bash + iptables）
- UI 风格自适应：emoji / text（SSH 无 UTF-8 时降级）
- 配置文件持久化（`~/.iptctlrc`）：UI 风格、退出策略等

---

## 三种模式详细说明 / Mode Reference

### 新手模式（Beginner）

适合刚接触 iptables、不确定自己在做什么的场景。

**锁定项：** `TABLE=filter`、`CHAIN=INPUT`，每次操作后自动复位，不会误切到 nat/FORWARD。

**可用操作：**
| 选项 | 功能 |
|------|------|
| 1 | 环境检测（iptables 是否可用） |
| 2 | 选择 IP 版本（IPv4 / IPv6 / 双栈） |
| 3 | 选择 backend（auto / nft / legacy） |
| 4 | 新手说明（必读） |
| 5 | 推荐流程向导（一步步带你做） |
| 10/11 | 查看规则（-L / -S） |
| 20 | 放行已建立连接（ESTABLISHED,RELATED） |
| 21/22 | 放行 TCP / UDP 端口（含可选注释） |
| 23 | 搜索规则 |
| 50-52 | 固化/持久化 |
| 60 | ipset 快速封禁列表 |

向导（选项 5）按推荐顺序：环境检测 → 选 IP 版本 → 放行已建立连接 → 放行一个端口 → 固化。

---

### 标准模式（Standard）

适合日常维护，操作完整，删除/清空有备份护栏。

**可用操作：**
| 选项 | 功能 |
|------|------|
| 1-5 | 环境检测、IP 版本、backend、table、chain 选择 |
| 10/11/12 | 查看规则（-L / -S）、搜索规则 |
| 30 | 添加规则（向导，含可选注释） |
| 31 | 按编号删除规则 |
| 32 | 批量删除（编号列表 / 范围，如 `1 2 3` 或 `5-20`） |
| 33 | 清空链（-F，危险） |
| 39 | 原始参数执行 |
| 50 | 固化/持久化中心 |
| 60 | ipset 完整管理菜单 |

---

### 专家模式（Expert）

REPL 直通，无确认护栏。输入就执行，适合熟练用户。

**支持三类输入：**

1. **Raw iptables 参数**（脚本自动补 `-t TABLE`）
2. **快捷补全**（行首单字母展开）
3. **口语 DSL**（见下节完整语法表）

---

## 专家 DSL 完整语法 / Expert DSL Reference

DSL 匹配优先于快捷补全，未匹配则作为原始参数传入。

### 核心格式

```
[insert] [from <src-ip>] [to <dst-ip>] <port>/<proto> <action> [on <iface>] [# comment]
```

所有修饰词均可选，可自由组合。

### 端口 / 协议 / 动作

| 输入示例              | 等价 iptables 参数                                       |
| --------------------- | -------------------------------------------------------- |
| `22/tcp allow`        | `-A CHAIN -p tcp --dport 22 -j ACCEPT`                   |
| `allow 22/tcp`        | 同上（词序颠倒）                                         |
| `53/udp drop`         | `-A CHAIN -p udp --dport 53 -j DROP`                     |
| `443/tcp reject`      | `-A CHAIN -p tcp --dport 443 -j REJECT`                  |
| `22/tcp log`          | `-A CHAIN -p tcp --dport 22 -j LOG --log-prefix iptctl:` |
| `80,443/tcp allow`    | `-A CHAIN -p tcp -m multiport --dports 80,443 -j ACCEPT` |
| `1000-2000/udp allow` | `-A CHAIN -p udp --dport 1000:2000 -j ACCEPT`            |

> 动作关键字：`allow` = `accept`，`drop` = `deny`

### 修饰前缀/后缀

| 修饰词              | 效果                                 | 示例                                    |
| ------------------- | ------------------------------------ | --------------------------------------- |
| `insert <...>`      | 用 `-I CHAIN 1`（插入链首）          | `insert 22/tcp allow`                   |
| `from <ip/cidr>`    | 添加 `-s` 源地址过滤                 | `from 1.2.3.4 22/tcp allow`             |
| `to <ip/cidr>`      | 添加 `-d` 目标地址过滤               | `to 10.0.0.1 80/tcp allow`              |
| `from <ip> to <ip>` | 同时过滤源和目标                     | `from 1.2.3.4 to 10.0.0.1 22/tcp allow` |
| `<...> on <iface>`  | 添加 `-i <iface>` 接口绑定           | `22/tcp allow on eth0`                  |
| `<...> # <text>`    | 添加 `-m comment --comment "<text>"` | `22/tcp allow # Allow SSH`              |

### 组合示例

```
# 从特定 IP 的 443，插入链首，绑定网卡，加注释
insert from 1.2.3.4 443/tcp allow on eth0 # office HTTPS

# 目标 IP 限制
to 192.168.1.100 3306/tcp drop

# 多端口 + 来源 + 注释
from 10.0.0.0/8 80,443/tcp allow # internal web
```

### REPL 内置命令

| 命令                              | 功能                                       |
| --------------------------------- | ------------------------------------------ |
| `block <ip>` / `block from <ip>`  | 封禁 IP（自动识别 v4/v6，追加 DROP 规则）  |
| `unblock <ip>`                    | 解封 IP（删除对应 DROP 规则）              |
| `policy ACCEPT\|DROP`             | 设置当前链默认策略                         |
| `show`                            | 显示当前 IP_MODE / TABLE / CHAIN 等上下文  |
| `ip 4\|6\|46`                     | 切换 IP_MODE                               |
| `backend auto\|nft\|legacy`       | 切换 backend                               |
| `table <name>`                    | 切换 TABLE                                 |
| `chain <name>`                    | 切换 CHAIN                                 |
| `persist`                         | 立即固化当前规则                           |
| `backup`                          | 备份当前规则到文件                         |
| `search`                          | 搜索规则（交互输入关键字）                 |
| `ipset`                           | 进入 ipset 完整管理菜单                    |
| `ipset <args>`                    | 直通 ipset 子命令（如 `ipset list myban`） |
| `L`                               | `-L CHAIN -n -v --line-numbers`            |
| `S`                               | `-S CHAIN`                                 |
| `F`                               | `-F CHAIN`                                 |
| `A <...>` / `I <...>` / `D <...>` | 展开为 `-A` / `-I` / `-D`                  |
| `help`                            | 显示帮助                                   |
| `exit`                            | 退出专家模式                               |

---

## 固化 / 持久化说明 / Persistence

iptables 规则默认只存在于内存，重启后丢失。脚本支持三种固化方式，按以下优先级自动选择（或手动指定）：

### 方式一：netfilter-persistent（推荐 Debian/Ubuntu）

```bash
# 脚本会自动执行：
netfilter-persistent save
# 规则存储在 /etc/iptables/rules.v4 和 rules.v6
# 开机由 netfilter-persistent.service 自动加载
```

如未安装，脚本会提示并尝试通过 `apt-get install iptables-persistent` 自动安装。

### 方式二：iptables-services（RHEL/CentOS/Rocky）

```bash
# 保存到 /etc/sysconfig/iptables 和 ip6tables
# 开机由 iptables.service / ip6tables.service 加载
```

### 方式三：systemd unit（通用，无需额外软件）

脚本在 `/etc/iptctl/rules.v4`（及 v6）保存规则，并写入 `/etc/systemd/system/iptctl-restore.service`：

```ini
[Unit]
Description=iptctl restore iptables rules
Before=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptctl/rules.v4

[Install]
WantedBy=multi-user.target
```

### 改动后自动固化

通过"固化/持久化中心"（菜单 50）可设置 `PERSIST_AFTER_CHANGE`：

| 值            | 行为               |
| ------------- | ------------------ |
| `off`（默认） | 不自动固化         |
| `prompt`      | 每次规则变更后询问 |
| `auto`        | 静默自动固化       |

---

## 配置 / Configuration

### 配置文件

脚本使用 `~/.iptctlrc`（或 `$IPTCTLRC` 环境变量指向的路径）持久化以下设置：

```ini
# ~/.iptctlrc
UI_STYLE=auto            # auto | emoji | text
UI_STYLE_PROMPT=off      # on | off（是否显示风格选择提示）
EXIT_FILE_PROMPT=off     # on | off（退出时是否询问保留备份）
EXIT_FILE_POLICY=keep    # keep | cleanup（退出备份策略）
```

### 环境变量

| 变量          | 说明                                | 默认值        |
| ------------- | ----------------------------------- | ------------- |
| `IPTCTLRC`    | 配置文件路径                        | `~/.iptctlrc` |
| `UI_STYLE`    | 显示风格：`auto` / `emoji` / `text` | `auto`        |
| `IPTCTL_LANG` | 语言设置：`en` / `zh-CN`            | 自动检测      |

`UI_STYLE=text` 会将 emoji 替换为 `[OK]` / `[FAIL]` / `[WARN]` 等 ASCII 标签，适合无 UTF-8 的 SSH 终端。

---

## Quick Start

### 方式一：克隆仓库

```bash
git clone https://github.com/OFLordRtx/IPtctl.git
cd IPtctl
chmod +x iptctl.sh
./iptctl.sh
```

### 方式二：下载单文件（推荐）

```bash
curl -L -o iptctl.sh \
  https://raw.githubusercontent.com/OFLordRtx/IPtctl/main/iptctl.sh
chmod +x iptctl.sh
sudo ./iptctl.sh
```

### 方式三：直接管道执行（不落盘）

```bash
bash <(curl -Ls https://raw.githubusercontent.com/OFLordRtx/IPtctl/main/iptctl.sh)
```

### 依赖

| 依赖                     | 必需           | 说明                             |
| ------------------------ | -------------- | -------------------------------- |
| `bash` 5+                | ✅             | 使用了 nameref / `%(%T)T` 等特性 |
| `iptables` / `ip6tables` | ✅             | nft 或 legacy 均可               |
| `sudo`                   | 非 root 时需要 | 普通用户须有 sudo 权限           |
| `ipset`                  | 可选           | ipset 功能需要；脚本可自动安装   |

---

## Troubleshooting

### `sudo: iptables: command not found`

`/usr/sbin` 或 `/sbin` 不在当前用户的 `PATH` 里（常见于 su 切换的 shell）。
脚本启动时会自动 `export PATH="/usr/sbin:/sbin:$PATH"`，通常能自动解决。
若仍报错，直接以 root 运行：

```bash
sudo -i
./iptctl.sh
```

### ip6tables 不可用 / 报 `FAIL IPv6`

- 部分精简系统（容器 / VPS 最小镜像）没有 ip6tables
- 解决方案：选择 `IP_MODE=4`（仅 IPv4），或安装 ip6tables：
  ```bash
  apt-get install iptables  # 通常包含 ip6tables
  ```

### 规则添加成功但重启后丢失

iptables 规则默认在内存，需要固化才能持久化。选择菜单 50 → 方式三（systemd）通常最通用：

```bash
# 手动验证：
systemctl status iptctl-restore
systemctl is-enabled iptctl-restore
```

### ipset 命令失败 / `Module ip_set not found`

需要内核支持 ip_set 模块：

```bash
modprobe ip_set
# 如果失败，说明内核不支持（常见于 OpenVZ 容器）
# 建议改用纯 iptables 规则，不用 ipset
```

### 改了规则但 Docker / 1Panel 覆盖了

Docker 和一些管理面板会在启动时写入自己的 iptables 规则，可能覆盖你的配置。
常见处理方式：

1. 将你的规则插入 `DOCKER-USER` 链（Docker 不会动这条链）
2. 或在面板/Docker 启动后再执行 `netfilter-persistent reload`

---

## Contributing

欢迎各种形式的贡献：

- **Bug 报告**：提 Issue，附上系统版本（`uname -a`）、iptables 版本（`iptables -V`）、复现步骤
- **功能建议**：先开 Issue 讨论再写代码，避免白费力气
- **PR**：尽量保持一个 PR 做一件事；脚本内部维持"纯 bash，少外部依赖"的风格

**提 PR 前：**

```bash
bash -n iptctl.sh    # 语法检查
shellcheck iptctl.sh # 建议无 warning（SC2206 除外，word-split 是有意为之）
```

---

## License

MIT © OFLordRtx — 详见 [LICENSE](LICENSE)
