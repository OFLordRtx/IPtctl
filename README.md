# IPtctl — Interactive iptables helper

> 状态：个人自用脚本，持续完善中（欢迎 issue / PR）。

一个给自己用着舒服的 iptables/ip6tables 交互脚本：少敲命令、少踩坑、该备份的能备份、该恢复的能恢复。  
代码主要由 AI 协助完成（包括部分文案），我负责“真实需求 + 反复折腾 + 挨打修正”。

> 适用场景：Debian/Ubuntu 等常见 Linux 服务器上，配合 1Panel / Docker 环境做基础防火墙管理。  
> 不适用场景：需要复杂策略/集中管理/企业级审计的环境（那就上更专业的方案）。

**依赖**：bash、iptables/ip6tables（建议 Debian 12 / Ubuntu 系列）。  

## Features
- ✅ 交互式菜单：减少手搓命令出错
- ✅ IPv4 / IPv6 切换
- ✅ backend 选择：auto / nft / legacy
- ✅ table / chain 选择（新手模式会锁定安全范围）
- ✅ 常用规则快速添加（放行已建立连接、放行端口等）
- ✅ 导出 / 恢复规则
- ✅ 可生成 systemd 开机恢复服务（可选）

## Quick Start

需要改规则时会用到 sudo（确保你的用户有 sudo 权限）。

### 方式 1：克隆仓库运行
```bash
git clone https://github.com/OFLordRtx/IPtctl.git
cd IPtctl
chmod +x iptctl.sh
./iptctl.sh
```

### 方式 2：只下载脚本再运行（推荐）
```bash
curl -L -o iptctl.sh https://raw.githubusercontent.com/OFLordRtx/IPtctl/HEAD/iptctl.sh
chmod +x iptctl.sh
./iptctl.sh
```

### 方式 3：一行命令直接跑（可选，不太推荐）
```bash
bash <(curl -Ls https://raw.githubusercontent.com/OFLordRtx/IPtctl/HEAD/iptctl.sh)
```

## Modes

### Beginner（新手模式）
给“我不想把自己锁门外”的情况准备的：
- 仍可选择：IPv4/IPv6、backend
- 固定锁定：`TABLE=filter`、`CHAIN=INPUT`
- 每次操作后自动回到 `filter/INPUT`（避免误切 `nat` / `FORWARD`）

### Standard（普通模式）
日常使用模式，菜单完整：
- 可自由选择 IPv4/IPv6、backend、table、chain
- 适合做常规维护/规则调整

### Expert（专家模式）
接近 REPL 的直通模式：
- 输入参数直通执行
- 护栏最少，适合熟练用户快速操作

## Persist
脚本支持导出/恢复规则，并提供生成 systemd 启动恢复的选项。  
如果你不确定是否需要持久化：先导出备份，确认规则稳定后再考虑 systemd 自动恢复。

## Safety Notes
- 远程服务器上改防火墙：建议至少开两路 SSH 会话
- 修改前先备份导出，出事能回滚
- 云厂商安全组 / 面板防火墙可能会和 iptables 叠加生效，注意规则冲突
- 如果你在跑 Docker / 1Panel：留意它们自己会插入规则

## Contributing
我代码不算熟，欢迎大家帮忙：
- 🐛 有 bug：提 issue（最好带系统版本、iptables 版本、复现步骤/截图）
- ✨ 想加功能：提 issue 讨论，或者直接提 PR（Pull Request）
- 我会尽量自己测试后再合并
