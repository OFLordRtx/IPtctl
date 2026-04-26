#!/usr/bin/env bash
# IPtctl 安全专项审计工具
# 针对“常见安全问题检查清单”进行自动化扫描

TARGET="iptctl.sh"
echo "=== 开始安全审计: $TARGET ==="

# 1. 检查命令注入风险 (寻找未加引号的变量引用或 eval)
echo -e "\n[1. 输入验证] 检查潜在的命令注入 (eval/未加引号的变量)..."
grep -n "eval " "$TARGET"
# 查找在命令执行位置可能存在的未加引号变量 (简化匹配)
grep -n "\${SUDO}.*[^\"]\$[a-zA-Z0-9_]" "$TARGET" | grep -v "\[\["

# 2. 检查临时文件安全
echo -e "\n[2. 权限相关] 检查临时文件创建 (mktemp/tmp)..."
grep -n "mktemp" "$TARGET"
grep -n "/tmp/" "$TARGET"

# 3. 检查敏感信息泄露 (日志/输出)
echo -e "\n[3. 数据安全] 检查敏感信息泄露 (密码/令牌关键字)..."
grep -niE "password|token|secret|key" "$TARGET" | grep -v "PG_"

# 4. 检查危险的权限操作
echo -e "\n[4. 权限相关] 检查危险的 chmod/chown..."
grep -nE "chmod 777|chmod +x" "$TARGET"

# 5. 检查网络操作 (是否存在未验证的下载)
echo -e "\n[5. 网络安全] 检查网络操作 (curl/wget)..."
grep -nE "curl|wget" "$TARGET"

echo -e "\n=== 审计扫描完成 ==="
