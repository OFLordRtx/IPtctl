#!/usr/bin/env bash
set -u
set -o pipefail

###############################################################################
# iptctl - Universal iptables interactive console (3-mode edition + DSL)
# 目标：只要系统“能用 iptables”，脚本就能用（nft/legacy/IPv4/IPv6/无 sudo）
# 设计原则：
#   - 尽量只依赖 bash + iptables/ip6tables（不依赖 xargs/tr/grep/sed/awk）
#   - 自动补齐 /usr/sbin:/sbin 到 PATH（很多系统普通用户 PATH 没有 sbin）
#   - 检测 sudo：有就用，没有就提示用 root 跑
#
# 三模式：
#   1) Beginner  初次接触：新手安全菜单（强约束/少功能/防误操作 + 小白说明/向导）
#   2) Standard  熟练使用：原始完整工程向控制台（全功能，但不小白化）
#   3) Expert    专家模式：手打 REPL + 自动补充快捷写法 + 历史/Tab + 口语 DSL（无护栏）
###############################################################################

# ---- Make sure sbin is in PATH (common portability pitfall)
export PATH="/usr/sbin:/sbin:${PATH:-/usr/bin:/bin}"

# ---- UI style: auto / emoji / text
UI_STYLE="${UI_STYLE:-auto}"

ui_autodetect_style() {
  # Heuristic only: can't truly detect font emoji support.
  local loc="${LC_ALL:-${LANG:-}}"
  if [[ "$loc" != *UTF-8* && "$loc" != *utf8* && "$loc" != *Utf8* ]]; then
    UI_STYLE="text"
    return 0
  fi
  if [[ "${TERM:-}" == "dumb" ]]; then
    UI_STYLE="text"
    return 0
  fi
  # likely ok
  UI_STYLE="emoji"
  return 0
}

ui_translate_line() {
  local s="${1-}"

  [[ "$UI_STYLE" == "auto" ]] && ui_autodetect_style

  # emoji mode: keep original text as-is
  if [[ "$UI_STYLE" == "emoji" ]]; then
    printf "%s\n" "$s"
    return 0
  fi

  # text mode: replace emoji with bilingual tags
  s="${s//🧊/[固化\/PERSIST]}"
  s="${s//✅/[成功\/OK]}"
  s="${s//❌/[失败\/FAIL]}"
  s="${s//⚠️/[警告\/WARN]}"
  s="${s//⚠/[警告\/WARN]}"
  s="${s//👉/[回车\/ENTER]}"
  s="${s//▶/[执行\/RUN]}"
  s="${s//🌐/[网络\/IP]}"
  s="${s//🧠/[后端\/BACKEND]}"
  s="${s//🗂/[表\/TABLE]}"
  s="${s//🔗/[链\/CHAIN]}"
  s="${s//🧾/[备份\/BACKUP]}"
  s="${s//🧭/[向导\/WIZARD]}"
  s="${s//🔴/[专家\/EXPERT]}"

  printf "%s\n" "$s"
}

###############################################################################
# Config load/save (~/.iptctlrc) - pure bash, no sed/awk/grep required
###############################################################################
config_load() {
  local f="$CONFIG_FILE"
  [[ -f "$f" ]] || return 0

  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue
    case "$line" in
      *=*)
        key="${line%%=*}"
        val="${line#*=}"
        key="$(trim "$key")"
        val="$(trim "$val")"
        case "$key" in
          UI_STYLE) UI_STYLE="$val" ;;
          UI_STYLE_PROMPT) UI_STYLE_PROMPT="$val" ;;
          EXIT_FILE_PROMPT) EXIT_FILE_PROMPT="$val" ;;
          EXIT_FILE_POLICY) EXIT_FILE_POLICY="$val" ;;
        esac
      ;;
    esac
  done < "$f"
}

config_save() {
  local f="$CONFIG_FILE"
  local d="${f%/*}"
  [[ -n "$d" && "$d" != "$f" ]] && mkdir -p "$d" >/dev/null 2>&1 || true

  cat > "$f" <<EOF
# iptctl config
# You can override config path with: IPTCTLRC=/path/to/file
UI_STYLE=${UI_STYLE}
UI_STYLE_PROMPT=${UI_STYLE_PROMPT}
EXIT_FILE_PROMPT=${EXIT_FILE_PROMPT}
EXIT_FILE_POLICY=${EXIT_FILE_POLICY}
EOF
}

###############################################################################
# First-run UI style prompt (auto/emoji/text) + "don't ask again" (confirm once)
###############################################################################
ui_style_maybe_prompt() {
  # If config file doesn't exist AND UI_STYLE_PROMPT is on, prompt once.
  [[ "$UI_STYLE_PROMPT" == "off" ]] && return 0
  [[ -f "$CONFIG_FILE" ]] && return 0

  bi "$LINE"
  bi "[显示/Display] 你的终端可能不支持 emoji（SSH 常见）。要切换显示风格吗？"
  bi "[提示/Tip] 你之后也可以用环境变量强制：UI_STYLE=text 或 UI_STYLE=emoji"
  bi ""
  bi "  1) 自动 (auto)   - 根据 UTF-8/TERM 估计选择"
  bi "  2) Emoji (emoji) - 保留图标"
  bi "  3) 文本 (text)   - 用 [固化/PERSIST] 这类中英标记"
  bi "  0) 跳过（保持默认 auto）"
  bi ""
  local c
  c="$(read_num "选择 / Choose: ")"
  case "$c" in
    1) UI_STYLE="auto" ;;
    2) UI_STYLE="emoji" ;;
    3) UI_STYLE="text" ;;
    0|"") UI_STYLE="${UI_STYLE:-auto}"; return 0 ;;
    *) bi "无效输入 / Invalid，保持默认 auto"; UI_STYLE="auto" ;;
  esac

  bi ""
  bi "是否记住并不再提示？/ Remember and don't ask again?"
  bi "  1) 是 / Yes（写入配置）"
  bi "  2) 否 / No（仅本次生效）"
  bi "  0) 退出 / Exit（不保存）"
  local x
  x="$(read_num "选择 / Choose: ")"
  case "$x" in
    1)
      UI_STYLE_PROMPT="off"
      config_save
      bi "[成功/OK] 已写入：$CONFIG_FILE"
      ;;
    2|0|"")
      bi "[提示/INFO] 未写入配置"
      ;;
    *)
      bi "无效输入 / Invalid，未写入配置"
      ;;
  esac
}

###############################################################################
# Exit retention prompt: keep/cleanup session backups + "don't ask again"
###############################################################################
rm_path() {
  # remove a path using sudo if needed
  local p="$1"
  if [[ "${EUID:-99999}" -eq 0 ]]; then
    rm -f -- "$p" >/dev/null 2>&1 || true
  else
    if [[ -n "$SUDO" ]]; then
      ${SUDO} rm -f -- "$p" >/dev/null 2>&1 || true
    fi
  fi
}

rmdir_if_empty() {
  local d="$1"
  if [[ "${EUID:-99999}" -eq 0 ]]; then
    rmdir -- "$d" >/dev/null 2>&1 || true
  else
    if [[ -n "$SUDO" ]]; then
      ${SUDO} rmdir -- "$d" >/dev/null 2>&1 || true
    fi
  fi
}

cleanup_session_backups() {
  local f
  for f in "${SESSION_BACKUP_FILES[@]}"; do
    rm_path "$f"
  done
  local d
  for d in "${!SESSION_BACKUP_DIRS[@]}"; do
    rmdir_if_empty "$d"
  done
}

exit_retention_apply_policy() {
  case "$EXIT_FILE_POLICY" in
    keep) return 0 ;;
    cleanup) cleanup_session_backups; return 0 ;;
    *) return 0 ;;
  esac
}

exit_retention_prompt() {
  # if no backups created this run, skip
  if (( ${#SESSION_BACKUP_FILES[@]} == 0 )); then
    return 0
  fi

  if [[ "$EXIT_FILE_PROMPT" == "off" ]]; then
    exit_retention_apply_policy
    return 0
  fi

  bi "$LINE"
  bi "[退出/Exit] 本次运行产生了备份文件（用于回滚）。退出时要保留吗？"
  bi "生成数量/Count: ${#SESSION_BACKUP_FILES[@]}"
  bi ""
  bi "  1) 保留 / Keep (推荐)"
  bi "  2) 删除本次备份 / Cleanup (仅删除本次生成的备份文件)"
  bi "  0) 取消退出 / Cancel exit"
  bi ""
  local c
  c="$(read_num "选择 / Choose: ")"
  case "$c" in
    1) EXIT_FILE_POLICY="keep" ;;
    2) EXIT_FILE_POLICY="cleanup" ;;
    0|"") return 1 ;;
    *) bi "无效输入 / Invalid，默认保留"; EXIT_FILE_POLICY="keep" ;;
  esac

  bi ""
  bi "是否记住并不再提示？/ Remember and don't ask again?"
  bi "  1) 是 / Yes（写入配置）"
  bi "  2) 否 / No（仅本次生效）"
  bi "  0) 退出 / Exit（不保存）"
  local x
  x="$(read_num "选择 / Choose: ")"
  case "$x" in
    1)
      EXIT_FILE_PROMPT="off"
      config_save
      bi "[成功/OK] 已写入：$CONFIG_FILE"
      ;;
    2|0|"")
      bi "[提示/INFO] 未写入配置"
      ;;
    *)
      bi "无效输入 / Invalid，未写入配置"
      ;;
  esac

  # apply chosen policy
  exit_retention_apply_policy
  return 0
}

iptctl_exit() {
  local code="${1:-0}"
  # if user cancels exit, return to caller
  exit_retention_prompt || return 1
  exit "$code"
}

bi(){ ui_translate_line "$*"; }
LINE="────────────────────────────────────────────────────────────"

# ---- sudo detection (portable)
SUDO=""
if [[ "${EUID:-99999}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    SUDO=""
  fi
fi

pause() {
  bi ""
  read -r -p "[ENTER] 回车返回 / Press Enter to continue... " _ || true
}

# ---- Pure-bash trim (no xargs/sed)
trim() {
  local s="${1-}"
  # leading
  s="${s#"${s%%[!$' \t\r\n']*}"}"
  # trailing
  s="${s%"${s##*[!$' \t\r\n']}"}"
  printf "%s" "$s"
}

read_line() {
  local v=""
  read -r -p "$1" v || true
  v="$(trim "$v")"
  printf "%s\n" "$v"
}

read_num() {
  local v=""
  read -r -p "$1" v || true
  v="$(trim "$v")"
  if [[ "$v" =~ ^[0-9]+$ ]]; then
    printf "%s\n" "$v"
  else
    printf "\n"
  fi
}

valid_port() {
  local p="$1"
  [[ "$p" =~ ^[0-9]+$ ]] || return 1
  (( p >= 1 && p <= 65535 )) || return 1
  return 0
}

need_root_or_sudo() {
  if [[ "${EUID:-99999}" -eq 0 ]]; then
    return 0
  fi
  if [[ -n "$SUDO" ]]; then
    return 0
  fi
  bi "[FAIL] 需要 root 权限或 sudo / Need root or sudo"
  bi "   当前未检测到 sudo，请用 root 运行："
  bi "   su -"
  bi "   或者以 root 执行该脚本。"
  return 1
}

run_action() {
  local title="$1"; shift
  local rc=0

  bi ""
  bi "$LINE"
  bi "[RUN] ${title}"
  bi "$LINE"

  "$@" || rc=$?

  # 约定：返回码 2/130 视为“用户取消”，不算失败，也不弹 FAIL
  if (( rc == 2 || rc == 130 )); then
    return 0
  fi

  if (( rc != 0 )); then
    bi ""
    bi "[FAIL] 操作失败 / Action failed"
    bi "   标题 / Title : ${title}"
    bi "   返回码 / Exit code : ${rc}"
    pause
    return 1
  fi
  return 0
}

###############################################################################
# Runtime context
###############################################################################
IP_MODE="4"          # 4 / 6 / 46
BACKEND="auto"       # auto / nft / legacy
TABLE="filter"
CHAIN="INPUT"

# 删除确认阈值：>= 这个数量视为“大规模删除”
BULK_CONFIRM_THRESHOLD=5
###############################################################################
# UI/Config + Session artifacts tracking
###############################################################################
# Config file (default: ~/.iptctlrc)
CONFIG_FILE_DEFAULT="${HOME:-/root}/.iptctlrc"
CONFIG_FILE="${IPTCTLRC:-$CONFIG_FILE_DEFAULT}"

# Session-generated backup files (only backups; NOT persistence system files)
declare -a SESSION_BACKUP_FILES=()
declare -A SESSION_BACKUP_DIRS=()

# Prompt controls (can be saved into ~/.iptctlrc)
# UI_STYLE: auto|emoji|text
# UI_STYLE_PROMPT: on|off
UI_STYLE_PROMPT="${UI_STYLE_PROMPT:-on}"

# Exit file retention (only backups produced by this run)
# EXIT_FILE_PROMPT: on|off
# EXIT_FILE_POLICY: keep|cleanup
EXIT_FILE_PROMPT="${EXIT_FILE_PROMPT:-on}"
EXIT_FILE_POLICY="${EXIT_FILE_POLICY:-keep}"


###############################################################################
# Persist (固化/持久化)
###############################################################################
PERSIST_AFTER_CHANGE="off"   # off / prompt / auto
PERSIST_METHOD="auto"        # auto / netfilter-persistent / iptables-services / systemd

###############################################################################
# MODE (三模式)
###############################################################################
MODE=""   # beginner / standard / expert

###############################################################################
# Beginner UX knobs (仅新手模式用)
###############################################################################
# 添加规则前提示：prompt=每次提示；off=不再提示
ADD_PROMPT="prompt"   # prompt / off

###############################################################################
# iptables command selection (portable)
###############################################################################
cmd_exists() { command -v "$1" >/dev/null 2>&1; }

cmd_works() {
  # -V does not require root; keep it non-sudo to avoid password prompts
  cmd_exists "$1" || return 1
  "$1" -V >/dev/null 2>&1 || return 1
}

ipt_cmd_for() {
  local fam="$1" base
  [[ "$fam" == "4" ]] && base="iptables" || base="ip6tables"

  if [[ "$BACKEND" == "legacy" ]]; then
    cmd_works "${base}-legacy" && printf "%s\n" "${base}-legacy" && return 0
  fi
  if [[ "$BACKEND" == "nft" ]]; then
    cmd_works "${base}-nft" && printf "%s\n" "${base}-nft" && return 0
  fi

  # auto: prefer plain binary, then nft, then legacy
  cmd_works "$base" && printf "%s\n" "$base" && return 0
  cmd_works "${base}-nft" && printf "%s\n" "${base}-nft" && return 0
  cmd_works "${base}-legacy" && printf "%s\n" "${base}-legacy" && return 0

  return 1
}

ipt_save_cmd_for() {
  local fam="$1" base
  [[ "$fam" == "4" ]] && base="iptables-save" || base="ip6tables-save"

  if [[ "$BACKEND" == "legacy" ]]; then
    cmd_exists "${base}-legacy" && printf "%s\n" "${base}-legacy" && return 0
  fi
  if [[ "$BACKEND" == "nft" ]]; then
    cmd_exists "${base}-nft" && printf "%s\n" "${base}-nft" && return 0
  fi

  cmd_exists "$base" && printf "%s\n" "$base" && return 0
  cmd_exists "${base}-nft" && printf "%s\n" "${base}-nft" && return 0
  cmd_exists "${base}-legacy" && printf "%s\n" "${base}-legacy" && return 0
  return 1
}

ipt_restore_cmd_for() {
  local fam="$1" base
  [[ "$fam" == "4" ]] && base="iptables-restore" || base="ip6tables-restore"

  if [[ "$BACKEND" == "legacy" ]]; then
    cmd_exists "${base}-legacy" && printf "%s\n" "${base}-legacy" && return 0
  fi
  if [[ "$BACKEND" == "nft" ]]; then
    cmd_exists "${base}-nft" && printf "%s\n" "${base}-nft" && return 0
  fi

  cmd_exists "$base" && printf "%s\n" "$base" && return 0
  cmd_exists "${base}-nft" && printf "%s\n" "${base}-nft" && return 0
  cmd_exists "${base}-legacy" && printf "%s\n" "${base}-legacy" && return 0
  return 1
}
run_ipt() {
  local fam="$1"; shift
  local IPT=""
  IPT="$(ipt_cmd_for "$fam")" || return 2
  need_root_or_sudo || return 3

  # 如果用户已经在参数里指定了 -t/--table，就不要再额外追加默认表
  local has_table=0 a
  for a in "$@"; do
    if [[ "$a" == "-t" || "$a" == "--table" ]]; then
      has_table=1
      break
    fi
  done

  if [[ "$has_table" -eq 1 ]]; then
    ${SUDO} "$IPT" "$@"
  else
    ${SUDO} "$IPT" -t "$TABLE" "$@"
  fi
}


# 幂等添加：若规则已存在则跳过；否则添加
# 用法示例：
#   run_ipt_add_if_missing 4 -A INPUT -p tcp --dport 22 -j ACCEPT
#   run_ipt_add_if_missing 4 -I INPUT 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
run_ipt_add_if_missing() {
  local fam="$1"; shift
  local args=("$@")
  local op="" chain="" start=0
  local check=()

  [[ "${#args[@]}" -lt 2 ]] && return 2
  op="${args[0]}"
  chain="${args[1]}"

  # 构造 -C 检查参数：-C <CHAIN> <rule-spec...>
  case "$op" in
    -A)
      start=2
      ;;
    -I)
      # -I CHAIN [num] rule-spec...
      if [[ "${args[2]-}" =~ ^[0-9]+$ ]]; then
        start=3
      else
        start=2
      fi
      ;;
    *)
      # 非添加操作，不处理
      run_ipt "$fam" "${args[@]}"
      return $?
      ;;
  esac

  check=("-C" "$chain")
  local i
  for (( i=start; i<${#args[@]}; i++ )); do
    check+=("${args[i]}")
  done

  # 先检查是否存在；存在就跳过
  if run_ipt "$fam" "${check[@]}" >/dev/null 2>&1; then
    bi "⏭️ 规则已存在，跳过 / Rule exists, skipped"
    return 0
  fi

  # 不存在（或 -C 不支持）则执行添加
  run_ipt "$fam" "${args[@]}"
}

# 关键修复：严格逐家族执行 + 明确打印每个 family 结果
run_ipt_scope() {
  local args=("$@")
  local have4=0 have6=0
  local rc4=0 rc6=0

  if [[ "$IP_MODE" == "4" || "$IP_MODE" == "46" ]]; then
    have4=1
    run_ipt 4 "${args[@]}" || rc4=$?
    if (( rc4 == 0 )); then bi "[OK] IPv4 OK"; else bi "[FAIL] IPv4 FAIL (rc=${rc4})"; fi
  fi

  if [[ "$IP_MODE" == "6" || "$IP_MODE" == "46" ]]; then
    if ipt_cmd_for 6 >/dev/null 2>&1; then
      have6=1
      run_ipt 6 "${args[@]}" || rc6=$?
      if (( rc6 == 0 )); then bi "[OK] IPv6 OK"; else bi "[FAIL] IPv6 FAIL (rc=${rc6})"; fi
    else
      if [[ "$IP_MODE" == "6" ]]; then
        bi "[FAIL] 未检测到 ip6tables（IPv6 模式下必须存在）"
        return 2
      fi
      bi "[WARN] 未检测到 ip6tables，跳过 IPv6 / ip6tables missing, skip IPv6"
      have6=0
      rc6=0
    fi
  fi

  # 严格语义：请求到的 family 任意失败 -> 失败
  if (( have4 == 1 )) && (( rc4 != 0 )); then return 1; fi
  if (( have6 == 1 )) && (( rc6 != 0 )); then return 1; fi
  return 0
}

###############################################################################
# Backup helpers
###############################################################################
ts_now() {
  # Bash builtin time formatting (no external date)
  printf '%(%Y%m%d-%H%M%S)T' -1
}

backup_pick_dir() {
  # Prefer system backup dir when root/sudo is available; fallback to current dir
  local d=""
  if [[ "${EUID:-99999}" -eq 0 || -n "$SUDO" ]]; then
    d="/var/backups/iptctl"
  else
    d="./iptctl-backups"
  fi
  printf "%s\n" "$d"
}

backup_write_file() {
  # $1: fam (4/6) , $2: out_file
  local fam="$1" out="$2"
  local SAVE=""
  SAVE="$(ipt_save_cmd_for "$fam")" || return 2
  need_root_or_sudo || return 3

  if [[ "${EUID:-99999}" -eq 0 ]]; then
    "$SAVE" > "$out"
  else
    # use tee to write as root (avoid sudo redirection issues)
    "$SAVE" | ${SUDO} tee "$out" >/dev/null
  fi
}

do_backup() {
  # args: families list: "4" "6"
  local fams=("$@")
  local dir ts
  dir="$(backup_pick_dir)"
  ts="$(ts_now)"

  need_root_or_sudo || return 3

  # create dir
  if [[ "${EUID:-99999}" -eq 0 ]]; then
    mkdir -p "$dir" || return 1
    chmod 700 "$dir" >/dev/null 2>&1 || true
  else
    ${SUDO} mkdir -p "$dir" || return 1
    ${SUDO} chmod 700 "$dir" >/dev/null 2>&1 || true
  fi

  bi "[BACKUP] 备份目录 / Backup dir: $dir"
  local ok=1

  for fam in "${fams[@]}"; do
    local f=""
    if [[ "$fam" == "4" ]]; then
      f="${dir}/iptctl-${ts}-v4.rules"
    else
      f="${dir}/iptctl-${ts}-v6.rules"
    fi

    if backup_write_file "$fam" "$f"; then
      bi "[OK] 已备份 / Saved: $f"
      SESSION_BACKUP_FILES+=("$f")
      SESSION_BACKUP_DIRS["$dir"]=1
    else
      bi "[FAIL] 备份失败 / Backup failed: $f"
      ok=0
    fi
  done

  (( ok == 1 )) && return 0
  return 1
}

confirm_phrase() {
  local prompt="$1"
  local phrase="$2"
  local got
  got="$(read_line "$prompt")"
  [[ "$got" == "$phrase" ]]
}

# 新手：添加规则前提示（可选不再提示，且选择后需二次确认）
confirm_add_rule() {
  # $1: desc
  local desc="$1"
  [[ "$ADD_PROMPT" == "off" ]] && return 0

  bi ""
  bi "$LINE"
  bi "[BACKEND] 准备添加规则 / About to add rule"
  bi "   ${desc}"
  bi "   TABLE=${TABLE}  CHAIN=${CHAIN}  IP_MODE=${IP_MODE}  BACKEND=${BACKEND}"
  bi "$LINE"
  bi "  1) 添加 / Add"
  bi "  2) 取消 / Cancel"
  bi "  3) 添加并以后不再提示（需要再确认一次）"
  local c
  c="$(read_num "选择 / Choose: ")"
  case "$c" in
    1) return 0 ;;
    2|"") bi "已取消 / Cancelled"; return 2 ;;
    3)
      if confirm_phrase "输入 YES：以后不再提示并继续 / Type YES to stop prompting and continue: " "YES"; then
        ADD_PROMPT="off"
        return 0
      fi
      bi "已取消 / Cancelled"
      return 2
      ;;
    *)
      bi "无效输入 / Invalid option"
      return 1
      ;;
  esac
}
destructive_guard() {
  # $1: desc, $2: count, then families...
  local desc="$1"; shift
  local count="$1"; shift
  local fams=("$@")

  bi ""
  bi "$LINE"
  bi "⚠️ 即将执行破坏性操作 / Destructive action"
  bi "   ${desc}"
  bi "   TABLE=${TABLE}  CHAIN=${CHAIN}  BACKEND=${BACKEND}"
  bi "   Families: ${fams[*]}"
  if [[ "$count" -gt 0 ]]; then
    bi "   影响规则数(估计) / Count: ${count}"
  fi
  bi "$LINE"
  bi ""

  # Expert: ask only about backup (no YES/DELETE phrase confirmations)
  if [[ "${MODE:-}" == "expert" ]]; then
    bi "[专家/EXPERT] 需要先备份吗？/ Backup before this action?"
    bi "  1) 备份并继续 / Backup + Continue (推荐)"
    bi "  2) 不备份继续 / Continue without backup"
    bi "  0) 取消 / Cancel"
    local c
    c="$(read_num "选择 / Choose: ")"
    case "$c" in
      1)
        do_backup "${fams[@]}" || bi "⚠️ 备份失败（仍继续）/ Backup failed (continue anyway)"
        return 0
        ;;
      2)
        return 0
        ;;
      0|"")
        bi "已取消 / Cancelled"
        return 1
        ;;
      *)
        bi "无效输入 / Invalid"
        return 1
        ;;
    esac
  fi

  # Standard: single-step confirm, auto backup (best-effort)
  if [[ "${MODE:-}" == "standard" ]]; then
    bi "[标准/Standard] 将自动备份（若可用），并仅确认一次。"
    if ! do_backup "${fams[@]}"; then
      bi "⚠️ 备份失败（仍可继续，但不推荐）。"
    fi
    bi "  1) 继续 / Continue"
    bi "  0) 取消 / Cancel"
    local c
    c="$(read_num "选择 / Choose: ")"
    case "$c" in
      1) return 0 ;;
      0|"") bi "已取消 / Cancelled"; return 2 ;;
      *) bi "无效输入 / Invalid"; return 1 ;;
    esac
  fi

  # Beginner (default): keep full guardrails
  bi "删除前备份 / Backup before delete"
  bi "  1) 备份并继续 (推荐)"
  bi "  2) 不备份继续 (需要输入 NO BACKUP)"
  bi "  0) 取消"
  local c
  c="$(read_num "选择 / Choose: ")"
  case "$c" in
    0|"") bi "已取消 / Cancelled"; return 2 ;;
    1)
      if ! do_backup "${fams[@]}"; then
        bi "⚠️ 备份失败。若仍要继续，需要输入 NO BACKUP"
        if ! confirm_phrase "输入 NO BACKUP 继续 / Type NO BACKUP to continue: " "NO BACKUP"; then
          bi "已取消 / Cancelled"
          return 1
        fi
      fi
      ;;
    2)
      if ! confirm_phrase "输入 NO BACKUP 继续 / Type NO BACKUP to continue: " "NO BACKUP"; then
        bi "已取消 / Cancelled"
        return 1
      fi
      ;;
    *)
      bi "无效输入 / Invalid input"
      return 1
      ;;
  esac

  # 第一次确认
  if ! confirm_phrase "输入 YES 确认删除 / Type YES to confirm: " "YES"; then
    bi "已取消 / Cancelled"
    return 1
  fi

  # 大规模删除二次确认（仅新手模式保留）
  if (( count >= BULK_CONFIRM_THRESHOLD )); then
    bi "⚠️ 大规模删除 / Bulk delete detected (>=${BULK_CONFIRM_THRESHOLD})"
    if ! confirm_phrase "再次输入 DELETE 确认 / Type DELETE to confirm again: " "DELETE"; then
      bi "已取消 / Cancelled"
      return 2
    fi
  fi

  return 0
}


###############################################################################
# Persist helpers
###############################################################################
persist_detect_netfilter_persistent() { cmd_exists netfilter-persistent; }

persist_detect_iptables_services() {
  [[ -d /etc/sysconfig ]] && cmd_exists systemctl
}

persist_detect_systemd() {
  cmd_exists systemctl && [[ -d /etc/systemd/system ]]
}

persist_print_status() {
  bi "固化工具检测 / Persistence detection:"
  if persist_detect_netfilter_persistent; then
    bi "  [OK] netfilter-persistent (Debian/Ubuntu)"
  else
    bi "  [FAIL] netfilter-persistent (Debian/Ubuntu)"
  fi

  if persist_detect_iptables_services; then
    bi "  [OK] iptables-services (RHEL 系)"
  else
    bi "  [FAIL] iptables-services (RHEL 系)"
  fi

  if persist_detect_systemd; then
    bi "  [OK] systemd 方案可用 (通用)"
  else
    bi "  [FAIL] systemd 方案不可用"
  fi
}

persist_install_netfilter_persistent() {
  need_root_or_sudo || return 1
  if cmd_exists apt-get; then
    bi "将安装 iptables-persistent（提供 netfilter-persistent）"
    if ! confirm_phrase "输入 YES 安装 / Type YES to install: " "YES"; then
      bi "已取消 / Cancelled"
      return 2
    fi
    ${SUDO} apt-get update
    ${SUDO} apt-get install -y iptables-persistent
    if cmd_exists systemctl; then
      ${SUDO} systemctl enable --now netfilter-persistent >/dev/null 2>&1 || true
    fi
    return 0
  fi
  bi "[FAIL] 未检测到 apt-get，无法自动安装。请手动安装：iptables-persistent / netfilter-persistent"
  return 1
}

persist_install_iptables_services() {
  need_root_or_sudo || return 1
  if cmd_exists dnf; then
    bi "将安装 iptables-services（dnf）"
    if ! confirm_phrase "输入 YES 安装 / Type YES to install: " "YES"; then
      bi "已取消 / Cancelled"
      return 2
    fi
    ${SUDO} dnf install -y iptables-services
    return 0
  fi
  if cmd_exists yum; then
    bi "将安装 iptables-services（yum）"
    if ! confirm_phrase "输入 YES 安装 / Type YES to install: " "YES"; then
      bi "已取消 / Cancelled"
      return 2
    fi
    ${SUDO} yum install -y iptables-services
    return 0
  fi
  bi "[FAIL] 未检测到 dnf/yum，无法自动安装。请手动安装：iptables-services"
  return 1
}

persist_apply_netfilter_persistent() {
  need_root_or_sudo || return 1
  if ! persist_detect_netfilter_persistent; then
    bi "未安装 netfilter-persistent"
    persist_install_netfilter_persistent || return 1
  fi
  bi "[RUN] 执行：netfilter-persistent save"
  ${SUDO} netfilter-persistent save
}

persist_apply_iptables_services() {
  need_root_or_sudo || return 1
  if ! persist_detect_iptables_services; then
    bi "未检测到 iptables-services 环境"
    persist_install_iptables_services || return 1
  fi

  local v4="/etc/sysconfig/iptables"
  local v6="/etc/sysconfig/ip6tables"

  local SAVE4 SAVE6
  SAVE4="$(ipt_save_cmd_for 4)" || { bi "[FAIL] 缺少 iptables-save"; return 1; }
  SAVE6="$(ipt_save_cmd_for 6)" || { bi "[WARN] 缺少 ip6tables-save，将只保存 IPv4"; SAVE6=""; }

  bi "[RUN] 保存 IPv4 到 $v4"
  if [[ "${EUID:-99999}" -eq 0 ]]; then
    "$SAVE4" > "$v4"
  else
    "$SAVE4" | ${SUDO} tee "$v4" >/dev/null
  fi

  if [[ -n "$SAVE6" ]]; then
    bi "[RUN] 保存 IPv6 到 $v6"
    if [[ "${EUID:-99999}" -eq 0 ]]; then
      "$SAVE6" > "$v6"
    else
      "$SAVE6" | ${SUDO} tee "$v6" >/dev/null
    fi
  fi

  if cmd_exists systemctl; then
    bi "[RUN] 尝试启用并启动 iptables/ip6tables 服务（若存在）"
    ${SUDO} systemctl enable --now iptables >/dev/null 2>&1 || true
    ${SUDO} systemctl enable --now ip6tables >/dev/null 2>&1 || true
  fi

  bi "[OK] 已写入固化文件（是否能随开机加载取决于服务是否存在/启用）"
  return 0
}
persist_apply_systemd() {
  need_root_or_sudo || return 1
  if ! persist_detect_systemd; then
    bi "[FAIL] systemd 方案不可用（缺少 systemctl 或 /etc/systemd/system）"
    return 1
  fi

  local dir="/etc/iptctl"
  local v4="${dir}/rules.v4"
  local v6="${dir}/rules.v6"
  local unit="/etc/systemd/system/iptctl-restore.service"

  local SAVE4 SAVE6 REST4 REST6
  SAVE4="$(ipt_save_cmd_for 4)" || { bi "[FAIL] 缺少 iptables-save"; return 1; }
  REST4="$(ipt_restore_cmd_for 4)" || { bi "[FAIL] 缺少 iptables-restore"; return 1; }

  # 把 restore 命令解析成绝对路径，避免 systemd 环境 PATH 不一致
  local REST4_BIN REST6_BIN
  REST4_BIN="$(command -v "$REST4" 2>/dev/null || true)"
  if [[ -z "$REST4_BIN" ]]; then
    bi "[FAIL] 找不到 restore 命令：$REST4"
    return 1
  fi

  SAVE6=""
  REST6=""
  if ipt_save_cmd_for 6 >/dev/null 2>&1 && ipt_restore_cmd_for 6 >/dev/null 2>&1; then
    SAVE6="$(ipt_save_cmd_for 6)" || SAVE6=""
    REST6="$(ipt_restore_cmd_for 6)" || REST6=""
    if [[ -n "$REST6" ]]; then
      REST6_BIN="$(command -v "$REST6" 2>/dev/null || true)"
    fi
  fi

  bi "[RUN] 创建目录：$dir"
  ${SUDO} mkdir -p "$dir"

  bi "[RUN] 保存 IPv4 到 $v4"
  if [[ "${EUID:-99999}" -eq 0 ]]; then
    "$SAVE4" > "$v4"
  else
    "$SAVE4" | ${SUDO} tee "$v4" >/dev/null
  fi

  if [[ -n "$SAVE6" ]]; then
    bi "[RUN] 保存 IPv6 到 $v6"
    if [[ "${EUID:-99999}" -eq 0 ]]; then
      "$SAVE6" > "$v6"
    else
      "$SAVE6" | ${SUDO} tee "$v6" >/dev/null
    fi
  else
    bi "[WARN] 未检测到 IPv6 save/restore，将只固化 IPv4"
  fi

  bi "[RUN] 写入 systemd unit：$unit"
  # 直接让 restore 读取文件参数，避免 /bin/sh -c 与重定向带来的 PATH/引用问题
  ${SUDO} tee "$unit" >/dev/null <<EOF
[Unit]
Description=iptctl restore iptables rules
DefaultDependencies=no
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${REST4_BIN} ${v4}
EOF

  if [[ -n "${REST6_BIN:-}" && -n "$SAVE6" ]]; then
    ${SUDO} tee -a "$unit" >/dev/null <<EOF
ExecStart=${REST6_BIN} ${v6}
EOF
  fi

  ${SUDO} tee -a "$unit" >/dev/null <<'EOF'

[Install]
WantedBy=multi-user.target
EOF

  bi "[RUN] 启用并启动：iptctl-restore"
  ${SUDO} systemctl daemon-reload
  ${SUDO} systemctl enable --now iptctl-restore

  bi "[OK] systemd 固化完成：开机将自动恢复规则"
  return 0
}


persist_apply() {
  local m="$PERSIST_METHOD"

  if [[ "$m" == "auto" ]]; then
    if persist_detect_netfilter_persistent; then
      m="netfilter-persistent"
    elif persist_detect_iptables_services; then
      m="iptables-services"
    else
      m="systemd"
    fi
  fi

  bi "固化方式 / Method: $m"

  case "$m" in
    netfilter-persistent) persist_apply_netfilter_persistent ;;
    iptables-services)    persist_apply_iptables_services ;;
    systemd)              persist_apply_systemd ;;
    *)
      bi "[FAIL] 未知固化方式 / Unknown method: $m"
      return 1
      ;;
  esac
}

maybe_persist_after_change() {
  case "$PERSIST_AFTER_CHANGE" in
    off) return 0 ;;
    auto)
      bi "[PERSIST] 自动固化：正在保存规则..."
      persist_apply
      return $?
      ;;
    prompt)
      bi "[PERSIST] 需要固化吗？"
      if confirm_phrase "输入 YES 立即固化 / Type YES to persist now: " "YES"; then
        persist_apply
        return $?
      fi
      bi "跳过固化 / Skipped"
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}

persist_menu() {
  while true; do
    bi "$LINE"
    bi "[PERSIST] 固化/持久化中心 / Persistence center"
    bi "当前 / Current:"
    bi "  PERSIST_AFTER_CHANGE=${PERSIST_AFTER_CHANGE}"
    bi "  PERSIST_METHOD=${PERSIST_METHOD}"
    bi ""

    persist_print_status
    bi ""
    bi "  1) 设置改动后是否固化 (off / prompt / auto)"
    bi "  2) 选择固化方式 (auto / netfilter-persistent / iptables-services / systemd)"
    bi "  3) 立即固化一次（保存当前规则）"
    bi "  0) 返回"
    bi ""

    local c
    c="$(read_num "选择 / Choose: ")"
    case "$c" in
      0|"") return 0 ;;
      1)
        bi "选择 / Choose:"
        bi "  1) off   (不固化)"
        bi "  2) prompt(每次改动后询问)"
        bi "  3) auto  (每次改动后自动固化)"
        local x
        x="$(read_num "选择 / Choose: ")"
        case "$x" in
          1) PERSIST_AFTER_CHANGE="off" ;;
          2) PERSIST_AFTER_CHANGE="prompt" ;;
          3) PERSIST_AFTER_CHANGE="auto" ;;
          *) bi "无效输入 / Invalid" ;;
        esac
        ;;
      2)
        bi "选择固化方式 / Choose method:"
        bi "  1) auto"
        bi "  2) netfilter-persistent (Debian/Ubuntu)"
        bi "  3) iptables-services (RHEL 系)"
        bi "  4) systemd (通用，无需额外软件)"
        local x
        x="$(read_num "选择 / Choose: ")"
        case "$x" in
          1) PERSIST_METHOD="auto" ;;
          2) PERSIST_METHOD="netfilter-persistent" ;;
          3) PERSIST_METHOD="iptables-services" ;;
          4) PERSIST_METHOD="systemd" ;;
          *) bi "无效输入 / Invalid" ;;
        esac
        ;;
      3)
        run_action "固化一次 / Persist now" persist_apply
        pause
        ;;
      *)
        bi "无效输入 / Invalid option" ;;
    esac
  done
}

# 新手专用：固化方式三选一（含默认 auto），且选择后必须 YES 确认应用
persist_method_quick_pick() {
  bi "$LINE"
  bi "[PERSIST] 选择固化方式（三选一/默认）/ Pick persistence method"
  bi "  1) netfilter-persistent (Debian/Ubuntu)"
  bi "  2) iptables-services (RHEL 系)"
  bi "  3) systemd (通用，无需额外软件)"
  bi "  4) 默认（auto：脚本自动选择最合适）"
  bi "  0) 返回"
  local c
  c="$(read_num "选择 / Choose: ")"
  case "$c" in
    0|"") return 0 ;;
    1) PERSIST_METHOD="netfilter-persistent" ;;
    2) PERSIST_METHOD="iptables-services" ;;
    3) PERSIST_METHOD="systemd" ;;
    4) PERSIST_METHOD="auto" ;;
    *) bi "无效输入 / Invalid"; return 1 ;;
  esac

  if confirm_phrase "输入 YES 确认应用 / Type YES to apply: " "YES"; then
    bi "[OK] 已设置 PERSIST_METHOD=${PERSIST_METHOD}"
    return 0
  fi

  bi "已取消 / Cancelled"
  return 1
}

###############################################################################
# UI selections
###############################################################################
select_ip_mode() {
  bi "$LINE"
  bi "[IP] 选择 IP 管理范围 / Choose IP scope"
  bi "  1) 仅 IPv4"
  bi "  2) 仅 IPv6"
  bi "  3) IPv4 + IPv6"
  bi "  0) 返回"
  local c
  c="$(read_num "选择 / Choose: ")"
  case "$c" in
    1) IP_MODE="4" ;;
    2) IP_MODE="6" ;;
    3) IP_MODE="46" ;;
    0|"") return 0 ;;
    *) bi "无效输入 / Invalid input" ;;
  esac
}

select_backend() {
  bi "$LINE"
  bi "[BACKEND] 选择 backend / Choose backend"
  bi "  1) auto"
  bi "  2) nft"
  bi "  3) legacy"
  bi "  0) 返回"
  local c
  c="$(read_num "选择 / Choose: ")"
  case "$c" in
    1) BACKEND="auto" ;;
    2) BACKEND="nft" ;;
    3) BACKEND="legacy" ;;
    0|"") return 0 ;;
    *) bi "无效输入 / Invalid input" ;;
  esac
}

select_table() {
  bi "$LINE"
  bi "[TABLE] 选择 table / Choose table"
  bi "  1) filter"
  bi "  2) nat"
  bi "  3) mangle"
  bi "  4) raw"
  bi "  5) security (可能不存在)"
  bi "  0) 返回"
  local c
  c="$(read_num "选择 / Choose: ")"
  case "$c" in
    1) TABLE="filter" ;;
    2) TABLE="nat" ;;
    3) TABLE="mangle" ;;
    4) TABLE="raw" ;;
    5) TABLE="security" ;;
    0|"") return 0 ;;
    *) bi "无效输入 / Invalid input" ;;
  esac
}

select_chain() {
  bi "$LINE"
  bi "[CHAIN] 输入 chain 名称 / Enter chain name"
  bi "常见：INPUT / OUTPUT / FORWARD / PREROUTING / POSTROUTING"
  local c
  c="$(read_line "Chain: ")"
  [[ -n "$c" ]] && CHAIN="$c"
}

###############################################################################
# Actions
###############################################################################
env_check() {
  bi "PATH=$PATH"
  bi ""
  bi "IPv4: $(ipt_cmd_for 4 2>/dev/null || echo 'NOT FOUND')"
  bi "IPv6: $(ipt_cmd_for 6 2>/dev/null || echo 'NOT FOUND')"
  bi ""
  bi "Current: IP_MODE=${IP_MODE} BACKEND=${BACKEND} TABLE=${TABLE} CHAIN=${CHAIN}"
  bi ""
  if ! ipt_cmd_for 4 >/dev/null 2>&1; then
    bi "[FAIL] 未检测到 iptables 可执行文件。"
    bi "   请先安装 iptables（发行版方式不同），安装后再运行本脚本。"
    return 1
  fi
  return 0
}

list_rules_L() { run_ipt_scope -L "$CHAIN" -n -v --line-numbers; }
list_rules_S() { run_ipt_scope -S "$CHAIN"; }

search_rules() {
  bi "$LINE"
  bi "[SEARCH] 规则搜索 / Rule search"
  bi "输入关键字（端口号、IP 地址或任意文本）/ Keyword (port / IP / text):"
  local kw=""
  kw="$(read_line "关键字 / Keyword: ")"
  [[ -z "$kw" ]] && { bi "已取消 / Cancelled"; return 0; }

  local fams=()
  if [[ "$IP_MODE" == "4" ]]; then fams=("4")
  elif [[ "$IP_MODE" == "6" ]]; then fams=("6")
  else fams=("4" "6"); fi

  local total=0
  for fam in "${fams[@]}"; do
    local label="IPv4"
    [[ "$fam" == "6" ]] && label="IPv6"
    local IPT=""
    IPT="$(ipt_cmd_for "$fam" 2>/dev/null)" || { bi "[WARN] $label: 未找到命令"; continue; }
    need_root_or_sudo || return 3

    bi ""
    bi "[${label}] TABLE=${TABLE} CHAIN=${CHAIN} 搜索：${kw}"
    bi "$LINE"

    local found=0 linenum=0 line
    while IFS= read -r line; do
      (( linenum++ ))
      if (( linenum <= 2 )); then
        bi "$line"
        continue
      fi
      if [[ "$line" == *"$kw"* ]]; then
        bi "$line"
        (( found++ ))
      fi
    done < <(${SUDO} "$IPT" -t "$TABLE" -L "$CHAIN" -n -v --line-numbers 2>&1)

    bi "$LINE"
    bi "[${label}] 共 $found 条匹配 / $found match(es)"
    (( total += found ))
  done
  bi ""
  bi "合计 / Total: $total 条"
}

# pick_families <fams_varname> <scope_varname> [dual_stack_warn]
# Fills the named array and string based on current IP_MODE.
# Returns 2 if the user cancels (dual-stack interactive prompt only).
pick_families() {
  local -n _pf_fams="$1"
  local -n _pf_scope="$2"
  local warn_msg="${3:-}"

  if [[ "$IP_MODE" == "46" ]]; then
    [[ -n "$warn_msg" ]] && bi "[WARN] ${warn_msg}"
    bi "选择操作范围 / Choose family:"
    bi "  1) 仅 IPv4"
    bi "  2) 仅 IPv6"
    bi "  3) IPv4 + IPv6"
    bi "  0) 取消"
    local _pf_c
    _pf_c="$(read_num "选择 / Choose: ")"
    case "$_pf_c" in
      1) _pf_fams=("4"); _pf_scope="IPv4" ;;
      2) _pf_fams=("6"); _pf_scope="IPv6" ;;
      3) _pf_fams=("4" "6"); _pf_scope="IPv4+IPv6" ;;
      *) bi "已取消 / Cancelled"; return 2 ;;
    esac
  elif [[ "$IP_MODE" == "4" ]]; then
    _pf_fams=("4"); _pf_scope="IPv4"
  else
    _pf_fams=("6"); _pf_scope="IPv6"
  fi
}

delete_rule_by_num() {
  local n=""
  n="$(read_num "输入要删除的规则编号 / Rule number to delete: ")"
  [[ -z "$n" ]] && { bi "无效编号 / Invalid number"; return 1; }

  local fams=()
  local scope_desc=""
  pick_families fams scope_desc "双栈模式：IPv4/IPv6 的编号可能不一致，建议分别查看后删除。" || return $?

  destructive_guard "删除规则编号 #${n} (${scope_desc})" 1 "${fams[@]}" || return $?

  local rc=0
  for fam in "${fams[@]}"; do
    run_ipt "$fam" -D "$CHAIN" "$n" || rc=$?
  done

  if (( rc == 0 )); then
    maybe_persist_after_change
    return 0
  fi
  return 1
}

parse_numbers_desc() {
  local s="$1"
  s="${s//,/ }"
  s="$(trim "$s")"
  [[ -z "$s" ]] && return 1

  declare -A seen=()
  local nums=()
  local tok a b i

  for tok in $s; do
    if [[ "$tok" =~ ^[0-9]+$ ]]; then
      seen["$tok"]=1
    elif [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      a="${BASH_REMATCH[1]}"
      b="${BASH_REMATCH[2]}"
      if (( a <= b )); then
        for (( i=b; i>=a; i-- )); do
          seen["$i"]=1
        done
      else
        for (( i=a; i>=b; i-- )); do
          seen["$i"]=1
        done
      fi
    else
      bi "[FAIL] 无法解析的编号片段 / Bad token: $tok"
      return 1
    fi
  done

  for tok in "${!seen[@]}"; do nums+=("$tok"); done

  local x y tmp
  for (( x=0; x<${#nums[@]}; x++ )); do
    for (( y=x+1; y<${#nums[@]}; y++ )); do
      if (( nums[x] < nums[y] )); then
        tmp="${nums[x]}"; nums[x]="${nums[y]}"; nums[y]="$tmp"
      fi
    done
  done

  for tok in "${nums[@]}"; do printf "%s\n" "$tok"; done
}

delete_rules_bulk() {
  bi "输入要删除的编号列表或范围 / Enter numbers or ranges"
  bi "示例 / Examples:"
  bi "  1 2 3"
  bi "  10,11,12"
  bi "  5-20"
  local s
  s="$(read_line "Numbers/Ranges: ")"
  [[ -z "$s" ]] && return 0

  local fams=()
  local scope_desc=""
  pick_families fams scope_desc "双栈模式：建议分别查看 IPv4/IPv6 编号后再批量删。" || return $?

  local nums=()
  local n
  while IFS= read -r n; do
    [[ -n "$n" ]] && nums+=("$n")
  done < <(parse_numbers_desc "$s") || { bi "[FAIL] 解析失败 / Parse failed"; return 1; }

  local cnt="${#nums[@]}"
  bi "将删除 ${cnt} 条（按降序删除，避免编号漂移）/ Will delete ${cnt} rules (descending)"

  destructive_guard "批量删除 ${cnt} 条规则 (${scope_desc})" "$cnt" "${fams[@]}" || return $?

  local fam rc=0
  for fam in "${fams[@]}"; do
    for n in "${nums[@]}"; do
      run_ipt "$fam" -D "$CHAIN" "$n" || rc=$?
    done
  done

  if (( rc == 0 )); then
    maybe_persist_after_change
    return 0
  fi
  return 1
}

flush_chain() {
  local fams=()
  local scope_desc=""
  pick_families fams scope_desc || return $?

  destructive_guard "清空链 -F ${CHAIN} (${scope_desc})" "${BULK_CONFIRM_THRESHOLD}" "${fams[@]}" || return $?

  local fam rc=0
  for fam in "${fams[@]}"; do
    run_ipt "$fam" -F "$CHAIN" || rc=$?
  done

  if (( rc == 0 )); then
    maybe_persist_after_change
    return 0
  fi
  return 1
}

raw_exec() {
  bi "输入原始参数（不含 iptables / -t），例如： -A INPUT -p tcp --dport 22 -j ACCEPT"
  bi "[WARN] 注意：这里不做完整 shell 引号解析，建议避免带空格的引号参数（如 comment），或改用无空格写法。"
  local args
  args="$(read_line "Args: ")"
  [[ -z "$args" ]] && return 0

  set -f
  # shellcheck disable=SC2206
  local arr=($args)
  set +f

  run_ipt_scope "${arr[@]}"
}

# wizard_run_for_family <fam> <base_array_varname> [rule-spec...]
# Runs iptables for one family using the provided base array (op + chain + pos + src).
wizard_run_for_family() {
  local fam="$1"
  local -n _wrf_base="$2"
  shift 2
  if [[ "$fam" == "4" ]]; then
    run_ipt 4 "${_wrf_base[@]}" "$@" || return 1
    bi "[OK] IPv4 OK"
  else
    if ipt_cmd_for 6 >/dev/null 2>&1; then
      run_ipt 6 "${_wrf_base[@]}" "$@" || return 1
      bi "[OK] IPv6 OK"
    else
      bi "[WARN] 未检测到 ip6tables，跳过 IPv6"
    fi
  fi
  return 0
}

add_rule_wizard() {
  bi "$LINE"
  bi "[WIZARD] 添加规则（模板向导）/ Add rule (wizard)"
  bi "当前：TABLE=${TABLE} CHAIN=${CHAIN} IP_MODE=${IP_MODE} BACKEND=${BACKEND}"
  bi ""
  bi "  1) 允许已建立连接 (ESTABLISHED,RELATED) -> ACCEPT"
  bi "  2) 放行 TCP 端口 -> ACCEPT"
  bi "  3) 放行 UDP 端口 -> ACCEPT"
  bi "  4) 丢弃 TCP 端口 -> DROP"
  bi "  5) 丢弃 UDP 端口 -> DROP"
  bi "  6) 丢弃所有流量 -> DROP（危险：慎用）"
  bi "  0) 返回"
  bi ""

  local t
  t="$(read_num "选择模板 / Choose template: ")"
  [[ -z "$t" || "$t" == "0" ]] && return 0

  bi ""
  bi "规则放置位置 / Placement"
  bi "  1) 插入到链首 (更优先) / Insert at top"
  bi "  2) 追加到链尾 (更后匹配) / Append at end"
  bi "  0) 返回"
  local pos
  pos="$(read_num "选择 / Choose: ")"
  [[ -z "$pos" || "$pos" == "0" ]] && return 0

  local op=""
  if [[ "$pos" == "1" ]]; then
    op="-I"
  else
    op="-A"
  fi

  bi ""
  local src4="" src6=""
  if [[ "$IP_MODE" == "46" ]]; then
    bi "来源地址 / Source（双栈分别输入，留空=任意）"
    bi "IPv4 示例：1.2.3.4 或 1.2.3.0/24"
    src4="$(read_line "IPv4 Source (blank = any): ")"
    bi "IPv6 示例：2001:db8::/64"
    src6="$(read_line "IPv6 Source (blank = any): ")"
  else
    bi "来源地址 / Source (可留空表示任意来源)"
    bi "示例：1.2.3.4  或  1.2.3.0/24  或  2001:db8::/64"
    local src
    src="$(read_line "Source (blank = any): ")"
    if [[ "$IP_MODE" == "4" ]]; then src4="$src"; else src6="$src"; fi
  fi

  local base4=() base6=()
  base4+=("$op" "$CHAIN"); base6+=("$op" "$CHAIN")
  [[ "$op" == "-I" ]] && base4+=("1") && base6+=("1")
  [[ -n "$src4" ]] && base4+=("-s" "$src4")
  [[ -n "$src6" ]] && base6+=("-s" "$src6")

  local rc=0
  case "$t" in
    1)
      if [[ "$IP_MODE" == "4" || "$IP_MODE" == "46" ]]; then
        if ! wizard_run_for_family 4 base4 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; then
          wizard_run_for_family 4 base4 -m state --state ESTABLISHED,RELATED -j ACCEPT || rc=1
        fi
      fi
      if [[ "$IP_MODE" == "6" || "$IP_MODE" == "46" ]]; then
        if ipt_cmd_for 6 >/dev/null 2>&1; then
          if ! wizard_run_for_family 6 base6 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; then
            wizard_run_for_family 6 base6 -m state --state ESTABLISHED,RELATED -j ACCEPT || rc=1
          fi
        else
          [[ "$IP_MODE" == "6" ]] && rc=1
        fi
      fi

      if (( rc == 0 )); then
        bi "[OK] 已添加：ESTABLISHED,RELATED -> ACCEPT"
        maybe_persist_after_change
        return 0
      fi
      bi "[FAIL] conntrack/state 匹配不可用（可能缺少内核模块/扩展）"
      return 1
      ;;

    2|3|4|5)
      local proto="" action=""
      local port=""
      if [[ "$t" == "2" || "$t" == "4" ]]; then proto="tcp"; else proto="udp"; fi
      if [[ "$t" == "2" || "$t" == "3" ]]; then action="ACCEPT"; else action="DROP"; fi

      port="$(read_num "端口 / Port (1-65535): ")"
      valid_port "${port:-0}" || { bi "[FAIL] 端口无效 / Invalid port"; return 1; }

      local wiz_comment=""
      wiz_comment="$(read_line "注释（可选，回车跳过）/ Comment (optional): ")"
      local wiz_comment_args=()
      [[ -n "$wiz_comment" ]] && wiz_comment_args=("-m" "comment" "--comment" "$wiz_comment")

      rc=0
      if [[ "$IP_MODE" == "4" || "$IP_MODE" == "46" ]]; then
        wizard_run_for_family 4 base4 -p "$proto" --dport "$port" "${wiz_comment_args[@]}" -j "$action" || rc=1
      fi
      if [[ "$IP_MODE" == "6" || "$IP_MODE" == "46" ]]; then
        if ipt_cmd_for 6 >/dev/null 2>&1; then
          wizard_run_for_family 6 base6 -p "$proto" --dport "$port" "${wiz_comment_args[@]}" -j "$action" || rc=1
        else
          [[ "$IP_MODE" == "6" ]] && rc=1
        fi
      fi

      (( rc == 0 )) && maybe_persist_after_change
      return $rc
      ;;

    6)
      bi "[WARN] 你选择了：丢弃所有流量 DROP ALL（非常危险）"
      bi "这通常会让你远程断连，除非你确定已有放行规则。"
      local confirm
      confirm="$(read_line "输入 YES 继续 / Type YES to continue: ")"
      [[ "$confirm" != "YES" ]] && { bi "已取消 / Cancelled"; return 0; }

      rc=0
      if [[ "$IP_MODE" == "4" || "$IP_MODE" == "46" ]]; then
        wizard_run_for_family 4 base4 -j DROP || rc=1
      fi
      if [[ "$IP_MODE" == "6" || "$IP_MODE" == "46" ]]; then
        if ipt_cmd_for 6 >/dev/null 2>&1; then
          wizard_run_for_family 6 base6 -j DROP || rc=1
        else
          [[ "$IP_MODE" == "6" ]] && rc=1
        fi
      fi

      (( rc == 0 )) && maybe_persist_after_change
      return $rc
      ;;

    *)
      bi "无效模板 / Invalid template"
      return 1
      ;;
  esac
}

###############################################################################
# ipset support (封禁集合 / 地址集合管理)
###############################################################################
IPSET_CMD=""

ipset_find_cmd() {
  [[ -n "$IPSET_CMD" ]] && return 0
  cmd_exists ipset && { IPSET_CMD="ipset"; return 0; }
  return 1
}

ipset_detect() { ipset_find_cmd; }

ipset_install() {
  need_root_or_sudo || return 1
  local pkg_mgr=""
  if cmd_exists apt-get; then pkg_mgr="apt-get"
  elif cmd_exists dnf; then   pkg_mgr="dnf"
  elif cmd_exists yum; then   pkg_mgr="yum"
  fi
  if [[ -z "$pkg_mgr" ]]; then
    bi "[FAIL] 未找到包管理器，请手动安装 ipset"
    return 1
  fi
  bi "将通过 ${pkg_mgr} 安装 ipset / Installing ipset via ${pkg_mgr}"
  if ! confirm_phrase "输入 YES 安装 / Type YES to install: " "YES"; then
    bi "已取消 / Cancelled"; return 2
  fi
  case "$pkg_mgr" in
    apt-get) ${SUDO} apt-get install -y ipset ;;
    dnf)     ${SUDO} dnf install -y ipset ;;
    yum)     ${SUDO} yum install -y ipset ;;
  esac
  IPSET_CMD=""
  ipset_find_cmd || { bi "[FAIL] 安装后仍未检测到 ipset"; return 1; }
  bi "[OK] ipset 已安装"
}

run_ipset() {
  ipset_find_cmd || { bi "[FAIL] ipset 未安装 / not installed"; return 1; }
  need_root_or_sudo || return 3
  ${SUDO} "$IPSET_CMD" "$@"
}

ipset_ensure() {
  ipset_detect && return 0
  bi "[WARN] 未检测到 ipset / ipset not found"
  bi "  1) 安装 ipset / Install"
  bi "  0) 取消 / Cancel"
  local c; c="$(read_num "选择 / Choose: ")"
  case "$c" in
    1) ipset_install || return 1 ;;
    *) return 1 ;;
  esac
}

ipset_list_sets() {
  run_ipset list -n
}

ipset_show_set() {
  bi "输入 set 名称（留空列出所有）/ Name (blank = list all):"
  local name; name="$(read_line "Set name: ")"
  if [[ -z "$name" ]]; then
    run_ipset list -n
  else
    run_ipset list "$name"
  fi
}

ipset_create() {
  bi "[IPSET] 创建 set / Create set"
  bi "常用类型：hash:ip（单 IP）  hash:net（CIDR 段）  hash:ip,port"
  local name="" settype=""
  name="$(read_line "Set 名称 / Name: ")"
  [[ -z "$name" ]] && { bi "已取消"; return 0; }
  settype="$(read_line "类型（回车默认 hash:ip）/ Type [hash:ip]: ")"
  [[ -z "$settype" ]] && settype="hash:ip"
  run_ipset create "$name" "$settype" && bi "[OK] 已创建：$name ($settype)"
}

ipset_add_ip() {
  local name="" ip=""
  name="$(read_line "Set 名称 / Set name: ")"
  [[ -z "$name" ]] && { bi "已取消"; return 0; }
  ip="$(read_line "IP 地址 / IP: ")"
  [[ -z "$ip" ]] && { bi "已取消"; return 0; }
  run_ipset add "$name" "$ip" && bi "[OK] 已添加：$ip -> $name"
}

ipset_bulk_add() {
  local name=""
  name="$(read_line "Set 名称 / Set name: ")"
  [[ -z "$name" ]] && { bi "已取消"; return 0; }
  bi "逐行输入 IP/CIDR（空行结束）/ Enter IPs one per line, blank to finish:"
  local ip rc=0
  while true; do
    ip="$(read_line "  IP (blank=done): ")"
    [[ -z "$ip" ]] && break
    run_ipset add "$name" "$ip" && bi "  [OK] +$ip" || { bi "  [FAIL] $ip"; rc=1; }
  done
  return $rc
}

ipset_del_ip() {
  local name="" ip=""
  name="$(read_line "Set 名称 / Set name: ")"
  [[ -z "$name" ]] && { bi "已取消"; return 0; }
  ip="$(read_line "IP 地址 / IP: ")"
  [[ -z "$ip" ]] && { bi "已取消"; return 0; }
  run_ipset del "$name" "$ip" && bi "[OK] 已删除：$ip from $name"
}

ipset_flush_set() {
  bi "输入 set 名称（留空=清空所有）/ Name (blank=flush ALL):"
  local name; name="$(read_line "Set name: ")"
  if [[ -z "$name" ]]; then
    bi "[WARN] 将清空所有 set 中的 IP（set 结构保留）"
    confirm_phrase "输入 YES 确认 / Type YES to confirm: " "YES" || { bi "已取消"; return 0; }
    run_ipset flush && bi "[OK] 已清空所有 set"
  else
    run_ipset flush "$name" && bi "[OK] 已清空：$name"
  fi
}

ipset_destroy_set() {
  local name=""
  name="$(read_line "Set 名称 / Set name: ")"
  [[ -z "$name" ]] && { bi "已取消"; return 0; }
  bi "[WARN] 即将删除 set（结构和所有 IP）: $name"
  confirm_phrase "输入 YES 确认删除 / Type YES to destroy: " "YES" || { bi "已取消"; return 0; }
  run_ipset destroy "$name" && bi "[OK] 已删除：$name"
}

ipset_use_in_iptables() {
  bi "[IPSET] 将 set 应用为 iptables 规则 / Use set in iptables"
  local name=""
  name="$(read_line "Set 名称 / Set name: ")"
  [[ -z "$name" ]] && { bi "已取消"; return 0; }

  bi "匹配方向 / Match direction:"
  bi "  1) src（来源 IP 在 set 中）"
  bi "  2) dst（目标 IP 在 set 中）"
  local d; d="$(read_num "选择 / Choose: ")"
  local dir="src"; [[ "$d" == "2" ]] && dir="dst"

  bi "动作 / Action:"
  bi "  1) DROP  （封禁）"
  bi "  2) ACCEPT（放行）"
  bi "  3) REJECT（拒绝并告知）"
  local a; a="$(read_num "选择 / Choose: ")"
  local action="DROP"
  case "$a" in 2) action="ACCEPT" ;; 3) action="REJECT" ;; esac

  local fams=() scope_desc=""
  pick_families fams scope_desc || return $?

  local fam rc=0
  for fam in "${fams[@]}"; do
    run_ipt "$fam" -A "$CHAIN" -m set --match-set "$name" "$dir" -j "$action" || rc=1
  done
  (( rc == 0 )) && bi "[OK] 已应用：$name($dir) -> $action" && maybe_persist_after_change
  return $rc
}

# Simplified ban-list for beginner mode, uses fixed set name "iptctl-ban"
IPSET_BAN_SET="iptctl-ban"
ipset_beginner_ban() {
  ipset_ensure || return 1

  bi "$LINE"
  bi "[IPSET] 快速封禁列表 / Quick ban list"
  bi "使用 set 名称：${IPSET_BAN_SET}  类型：hash:ip"

  if ! run_ipset list "$IPSET_BAN_SET" >/dev/null 2>&1; then
    run_ipset create "$IPSET_BAN_SET" hash:ip || { bi "[FAIL] 无法创建 set"; return 1; }
    bi "[OK] 已创建 set：$IPSET_BAN_SET"
  else
    bi "[INFO] set 已存在：$IPSET_BAN_SET"
  fi

  bi ""
  bi "  1) 添加单个 IP 到封禁列表"
  bi "  2) 批量添加（逐行输入，空行结束）"
  bi "  3) 查看封禁列表"
  bi "  4) 从封禁列表删除 IP"
  bi "  5) 将封禁规则应用到 iptables（-j DROP）"
  bi "  0) 返回"
  bi ""
  local c; c="$(read_num "选择 / Choose: ")"
  case "$c" in
    0|"") return 0 ;;
    1)
      local ip=""; ip="$(read_line "IP 地址: ")"
      [[ -z "$ip" ]] && return 0
      run_ipset add "$IPSET_BAN_SET" "$ip" && bi "[OK] 已封禁：$ip"
      ;;
    2)
      bi "逐行输入 IP（空行结束）:"
      local ip
      while true; do
        ip="$(read_line "  IP (blank=done): ")"
        [[ -z "$ip" ]] && break
        run_ipset add "$IPSET_BAN_SET" "$ip" && bi "  [OK] +$ip" || bi "  [FAIL] $ip"
      done
      ;;
    3) run_ipset list "$IPSET_BAN_SET" ;;
    4)
      local ip=""; ip="$(read_line "要解封的 IP: ")"
      [[ -z "$ip" ]] && return 0
      run_ipset del "$IPSET_BAN_SET" "$ip" && bi "[OK] 已解封：$ip"
      ;;
    5)
      bi "将添加：-A ${CHAIN} -m set --match-set ${IPSET_BAN_SET} src -j DROP"
      local fams=() scope_desc=""
      pick_families fams scope_desc || return $?
      local fam rc=0
      for fam in "${fams[@]}"; do
        run_ipt "$fam" -A "$CHAIN" -m set --match-set "$IPSET_BAN_SET" src -j DROP || rc=1
      done
      (( rc == 0 )) && bi "[OK] 封禁规则已应用" && maybe_persist_after_change
      return $rc
      ;;
    *) bi "无效选项 / Invalid option" ;;
  esac
}

ipset_menu() {
  ipset_ensure || return 1
  while true; do
    bi "$LINE"
    bi "[IPSET] ipset 管理 / ipset management"
    bi ""
    bi "  1) 列出所有 set（名称）"
    bi "  2) 查看 set 详情"
    bi "  3) 创建 set"
    bi "  4) 添加 IP"
    bi "  5) 批量添加 IP"
    bi "  6) 删除 IP"
    bi "  7) 清空 set（只清 IP，保留结构）"
    bi "  8) 删除 set（连结构一起删）"
    bi "  9) 应用 set 到 iptables 规则"
    bi "  0) 返回"
    bi ""
    local c; c="$(read_num "选择 / Choose: ")"
    case "$c" in
      0|"") return 0 ;;
      1) run_action "列出所有 set" ipset_list_sets; pause ;;
      2) run_action "查看 set 详情" ipset_show_set; pause ;;
      3) run_action "创建 set" ipset_create; pause ;;
      4) run_action "添加 IP" ipset_add_ip; pause ;;
      5) run_action "批量添加 IP" ipset_bulk_add; pause ;;
      6) run_action "删除 IP" ipset_del_ip; pause ;;
      7) run_action "清空 set" ipset_flush_set; pause ;;
      8) run_action "删除 set" ipset_destroy_set; pause ;;
      9) run_action "应用 set 到 iptables" ipset_use_in_iptables; pause ;;
      *) bi "无效选项 / Invalid option" ;;
    esac
  done
}

###############################################################################
# MODE selector (三模式入口)
###############################################################################
select_mode() {
  while true; do
    bi ""
    bi "╔════════════════════════════════════════════════════════════╗"
    bi "║                 iptctl · 三模式启动                        ║"
    bi "╚════════════════════════════════════════════════════════════╝"
    bi "请选择使用模式 / Choose mode:"
    bi ""
    bi "  1) 初次接触（新手安全模式）"
    bi "     - 只提供安全常用操作（看规则/放行端口/基础固化）"
    bi "     - 默认锁定 filter/INPUT，隐藏删除/清空/原始执行"
    bi "     - 提供小白说明 + 推荐流程向导"
    bi ""
    bi "  2) 熟练使用（完整控制台）"
    bi "     - 全功能工程向（就是原版）"
    bi ""
    bi "  3) 专家模式（手打 + 自动补充 + DSL）"
    bi "     - REPL 手打参数（支持历史/Tab）"
    bi "     - 快捷：A/I/D/L/S/F"
    bi "     - DSL：22/tcp allow、from 1.2.3.4 80,443/tcp allow 等"
    bi ""
    bi "  0) 退出 / Exit"
    bi ""
    local c
    c="$(read_num "选择 / Choose: ")"
    case "$c" in
      0) iptctl_exit 0 ;;
      1) MODE="beginner"; return 0 ;;
      2) MODE="standard"; return 0 ;;
      3) MODE="expert";   return 0 ;;
      *) bi "无效输入 / Invalid" ;;
    esac
  done
}

###############################################################################
# Beginner mode (新手安全模式)
###############################################################################
beginner_reset_defaults() {
  TABLE="filter"
  CHAIN="INPUT"
}

beginner_help_screen() {
  bi ""
  bi "╔════════════════════════════════════════════════════════════╗"
  bi "║                 iptctl · 新手说明（必读）                 ║"
  bi "╚════════════════════════════════════════════════════════════╝"
  bi "你可以把 iptables 理解成："
  bi "  - 一串“从上到下匹配”的规则"
  bi "  - 匹配到就执行动作（ACCEPT 放行 / DROP 丢弃 / REJECT 拒绝）"
  bi ""
  bi "本脚本新手模式默认锁定："
  bi "  - TABLE=filter  CHAIN=INPUT（只管入站）"
  bi "  - 目的：不让你误删 NAT/转发/奇怪链导致更大事故"
  bi ""
  bi "新手模式里你仍然可以选择："
  bi "  - IP 版本：IPv4 / IPv6 / 双栈（菜单 2）"
  bi "  - 后端：auto / nft / legacy（菜单 3）"
  bi "固定锁定并会自动复位："
  bi "  - TABLE=filter"
  bi "  - CHAIN=INPUT"
  bi "每次执行完添加/删除规则后会回到 filter/INPUT，避免误切到 nat/FORWARD。"
  bi ""
  bi "规则顺序非常重要："
  bi "  - 越靠前越先匹配"
  bi "  - 如果前面有 DROP，后面再加 ACCEPT 可能完全没用"
  bi ""
  bi "最常见的安全组合（推荐）："
  bi "  1) 放行已建立连接（ESTABLISHED,RELATED）——避免已连接会话被误伤"
  bi "  2) 放行你需要的端口（例如 SSH 22/tcp，或你的面板端口）"
  bi "  3) 需要的话再做固化（让规则重启后还在）"
  bi ""
  bi "固化是什么？"
  bi "  - iptables 默认改的是“内存规则”，重启可能丢"
  bi "  - 固化就是保存到系统机制里（netfilter-persistent / systemd 等）"
  bi ""
  bi "小白避坑："
  bi "  - 改防火墙前，建议保留一个已登录的 SSH 会话不要关"
  bi "  - 如果你在云服务器上，优先确保放行 SSH 端口，否则可能断连"
  bi "  - 如果系统跑着 firewalld/nftables.service，可能会覆盖你改的规则"
  pause
}

beginner_allow_established() {
  confirm_add_rule "插入链首：ESTABLISHED,RELATED -> ACCEPT" || return $?

  local rc=0
  if [[ "$IP_MODE" == "4" || "$IP_MODE" == "46" ]]; then
    if ! run_ipt_add_if_missing 4 -I "$CHAIN" 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; then
      run_ipt_add_if_missing 4 -I "$CHAIN" 1 -m state --state ESTABLISHED,RELATED -j ACCEPT || rc=1
    else
      bi "[OK] IPv4 OK"
    fi
  fi
  if [[ "$IP_MODE" == "6" || "$IP_MODE" == "46" ]]; then
    if ipt_cmd_for 6 >/dev/null 2>&1; then
      if ! run_ipt_add_if_missing 6 -I "$CHAIN" 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; then
        run_ipt_add_if_missing 6 -I "$CHAIN" 1 -m state --state ESTABLISHED,RELATED -j ACCEPT || rc=1
      else
        bi "[OK] IPv6 OK"
      fi
    else
      bi "[WARN] 未检测到 ip6tables，跳过 IPv6"
    fi
  fi
  (( rc == 0 )) && maybe_persist_after_change
  return $rc
}

beginner_allow_port() {
  local proto="$1"
  local port=""
  port="$(read_num "端口 / Port (1-65535): ")"
  valid_port "${port:-0}" || { bi "[FAIL] 端口无效 / Invalid port"; return 1; }

  local comment=""
  comment="$(read_line "注释（可选，回车跳过）/ Comment (optional): ")"
  local comment_args=()
  [[ -n "$comment" ]] && comment_args=("-m" "comment" "--comment" "$comment")

  bi "将放行：${proto^^} 端口 ${port}（TABLE=filter CHAIN=INPUT）"
  confirm_add_rule "放行 ${proto^^} 端口 ${port} -> ACCEPT" || return $?

  local rc=0
  if [[ "$IP_MODE" == "4" || "$IP_MODE" == "46" ]]; then
    run_ipt_add_if_missing 4 -A "$CHAIN" -p "$proto" --dport "$port" "${comment_args[@]}" -j ACCEPT || rc=1
    (( rc == 0 )) && bi "[OK] IPv4 OK"
  fi
  if [[ "$IP_MODE" == "6" || "$IP_MODE" == "46" ]]; then
    if ipt_cmd_for 6 >/dev/null 2>&1; then
      run_ipt_add_if_missing 6 -A "$CHAIN" -p "$proto" --dport "$port" "${comment_args[@]}" -j ACCEPT || rc=1
      (( rc == 0 )) && bi "[OK] IPv6 OK"
    else
      bi "[WARN] 未检测到 ip6tables，跳过 IPv6"
    fi
  fi

  (( rc == 0 )) && maybe_persist_after_change
  return $rc
}

beginner_persist_quick() {
  bi "[WARN] 提醒：如果系统启用了 firewalld / nftables.service，可能会覆盖规则。"
  bi "   这不是本脚本的问题，是系统服务优先级/覆盖行为导致。"
  bi ""
  run_action "立即固化（使用 auto 方式）" persist_apply
}

beginner_quickstart_wizard() {
  bi ""
  bi "╔════════════════════════════════════════════════════════════╗"
  bi "║              iptctl · 新手推荐流程向导                    ║"
  bi "╚════════════════════════════════════════════════════════════╝"
  bi "它会按推荐顺序做："
  bi "  1) 环境检测"
  bi "  2) 选择 IPv4/IPv6/双栈"
  bi "  3) 放行已建立连接（插入链首）"
  bi "  4) 放行一个 TCP 端口（默认 22）"
  bi "  5) 询问是否固化"
  bi ""

  run_action "环境检测 / Env check" env_check || { pause; return 1; }
  run_action "选择 IP 模式" select_ip_mode

  run_action "放行已建立连接（推荐）" beginner_allow_established || { pause; return 1; }

  bi ""
  bi "下一步：放行一个 TCP 端口（通常是 SSH=22）"
  local p
  p="$(read_num "端口 / Port (默认 22): ")"
  [[ -z "$p" ]] && p="22"
  valid_port "$p" || { bi "[FAIL] 端口无效 / Invalid port"; pause; return 1; }

  local qwiz_comment=""
  qwiz_comment="$(read_line "注释（可选，回车跳过）/ Comment (optional): ")"
  local qwiz_comment_args=()
  [[ -n "$qwiz_comment" ]] && qwiz_comment_args=("-m" "comment" "--comment" "$qwiz_comment")

  local _rc=0
  confirm_add_rule "放行 TCP 端口 ${p} -> ACCEPT" || { _rc=$?; pause; return $_rc; }

  local rc=0
  if [[ "$IP_MODE" == "4" || "$IP_MODE" == "46" ]]; then
    run_ipt_add_if_missing 4 -A "$CHAIN" -p tcp --dport "$p" "${qwiz_comment_args[@]}" -j ACCEPT || rc=1
  fi
  if [[ "$IP_MODE" == "6" || "$IP_MODE" == "46" ]]; then
    if ipt_cmd_for 6 >/dev/null 2>&1; then
      run_ipt_add_if_missing 6 -A "$CHAIN" -p tcp --dport "$p" "${qwiz_comment_args[@]}" -j ACCEPT || rc=1
    else
      bi "[WARN] 未检测到 ip6tables，跳过 IPv6"
    fi
  fi
  (( rc != 0 )) && { bi "[FAIL] 放行端口失败"; pause; return 1; }

  bi ""
  bi "最后一步：要不要固化（重启后也保留）？"
  if confirm_phrase "输入 YES 立即固化 / Type YES to persist now: " "YES"; then
    run_action "固化一次 / Persist now" persist_apply || { pause; return 1; }
  else
    bi "跳过固化 / Skipped"
  fi

  bi "[OK] 新手向导完成"
  pause
  return 0
}

beginner_menu() {
  bi ""
  bi "╔════════════════════════════════════════════════════════════╗"
  bi "║           iptctl · 初次接触（新手安全模式）                ║"
  bi "╚════════════════════════════════════════════════════════════╝"
  bi "当前状态 / Current:"
  bi "  MODE=${MODE}"
  bi "  IP_MODE=${IP_MODE}   BACKEND=${BACKEND}"
  bi "  TABLE=${TABLE}   CHAIN=${CHAIN}   (新手模式锁定)"
  bi "  ADD_PROMPT=${ADD_PROMPT}  (添加规则前是否提示)"
  bi "  PERSIST_AFTER_CHANGE=${PERSIST_AFTER_CHANGE}  PERSIST_METHOD=${PERSIST_METHOD}"
  bi ""
  bi "  1) 环境检测 / Env check"
  bi "  2) 选择 IPv4 / IPv6 / 双栈"
  bi "  3) 选择后端（auto / nft / legacy）/ Select backend (auto / nft / legacy)"
  bi "  4) 新手说明（必读）"
  bi "  5) [OK] 新手推荐流程向导（一步步带你做）"
  bi ""
  bi "  10) 查看规则 (-L 带编号)"
  bi "  11) 查看规则 (-S 原样)"
  bi ""
  bi "  20) 放行已建立连接 (ESTABLISHED,RELATED) -> ACCEPT"
  bi "  21) 放行 TCP 端口 -> ACCEPT"
  bi "  22) 放行 UDP 端口 -> ACCEPT"
  bi "  23) 搜索规则（按端口/IP/关键字）"
  bi ""
  bi "  50) [PERSIST] 固化/持久化中心（完整）"
  bi "  51) [PERSIST] 一键固化（auto）"
  bi "  52) [PERSIST] 选择固化方式（三选一/默认）"
  bi ""
  bi "  60) [IPSET] 快速封禁列表（ipset）"
  bi ""
  bi "  90) 切换模式"
  bi "  0) 退出"
  bi ""
}

beginner_loop() {
  beginner_reset_defaults
  while true; do
    beginner_menu
    local c
    c="$(read_num "输入选项 / Enter option: ")"
    case "$c" in
      0) iptctl_exit 0 ;;
      1) run_action "环境检测 / Env check" env_check; pause ;;
      2) run_action "选择 IP 模式" select_ip_mode ;;
      3) run_action "选择 backend" select_backend ;;
      4) beginner_help_screen ;;
      5) beginner_quickstart_wizard ;;
      10) run_action "查看规则 (-L)" list_rules_L; pause ;;
      11) run_action "查看规则 (-S)" list_rules_S; pause ;;
      20) run_action "放行已建立连接" beginner_allow_established; pause ;;
      21) run_action "放行 TCP 端口" beginner_allow_port tcp; pause ;;
      22) run_action "放行 UDP 端口" beginner_allow_port udp; pause ;;
      23) run_action "搜索规则" search_rules; pause ;;
      50) run_action "固化/持久化中心" persist_menu ;;
      51) beginner_persist_quick; pause ;;
      52) run_action "选择固化方式（三选一/默认）" persist_method_quick_pick; pause ;;
      60) run_action "快速封禁列表（ipset）" ipset_beginner_ban; pause ;;
      90) return 0 ;;
      *) bi "无效选项 / Invalid option" ;;
    esac
    beginner_reset_defaults
  done
}

###############################################################################
# Expert mode (专家 REPL：手打 + 自动补充 + DSL)
###############################################################################
expert_help() {
  bi ""
  bi "EXPERT 模式帮助："
  bi "  - 原始参数：不含 iptables/-t，脚本自动补 -t ${TABLE}"
  bi "  - 支持历史/Tab（read -e）"
  bi ""
  bi "快捷补全（行首）："
  bi "  A ...   -> -A ...    I ...   -> -I ..."
  bi "  D ...   -> -D ...    F       -> -F ${CHAIN}"
  bi "  L       -> -L ${CHAIN} -n -v --line-numbers"
  bi "  S       -> -S ${CHAIN}"
  bi ""
  bi "口语 DSL（没匹配到则当普通输入）："
  bi "  格式：[insert] [from <src>] [to <dst>] <port>/<proto> <action> [on <iface>] [# comment]"
  bi ""
  bi "  端口/协议/动作："
  bi "    22/tcp allow          -> -A ${CHAIN} -p tcp --dport 22 -j ACCEPT"
  bi "    allow 22/tcp          -> 同上（词序颠倒）"
  bi "    22/tcp drop           -> -j DROP"
  bi "    22/tcp reject         -> -j REJECT"
  bi "    22/tcp log            -> -j LOG --log-prefix iptctl:"
  bi "    80,443/tcp allow      -> -m multiport --dports 80,443 -j ACCEPT"
  bi "    1000-2000/udp allow   -> --dport 1000:2000 -j ACCEPT"
  bi ""
  bi "  修饰前缀/后缀："
  bi "    insert 22/tcp allow          -> -I ${CHAIN} 1 ...（插入链首）"
  bi "    from 1.2.3.4 22/tcp allow    -> -s 1.2.3.4 ..."
  bi "    to 10.0.0.1 22/tcp allow     -> -d 10.0.0.1 ..."
  bi "    from 1.2.3.4 to 10.0.0.1 22/tcp allow  -> -s ... -d ..."
  bi "    22/tcp allow on eth0         -> -i eth0 ..."
  bi "    22/tcp allow # Allow SSH     -> -m comment --comment 'Allow SSH'"
  bi ""
  bi "REPL 内置命令（IP 操作直接作用于当前 CHAIN/TABLE）："
  bi "  block <ip>              封禁 IP（-A ${CHAIN} -s <ip> -j DROP，自动识别 v4/v6）"
  bi "  unblock <ip>            解封 IP（-D ${CHAIN} -s <ip> -j DROP）"
  bi "  policy <ACTION>         设置链默认策略（ACCEPT / DROP）"
  bi "  show                    显示当前上下文"
  bi "  ip 4|6|46               设置 IP_MODE"
  bi "  backend auto|nft|legacy 设置 BACKEND"
  bi "  table <name>            设置 TABLE"
  bi "  chain <name>            设置 CHAIN"
  bi "  persist                 立即固化"
  bi "  backup                  备份当前规则"
  bi "  search                  搜索规则（端口/IP/关键字）"
  bi "  ipset                   进入 ipset 管理菜单"
  bi "  ipset <args>            直通 ipset 命令（如：ipset list / ipset add SET IP）"
  bi "  help                    显示本帮助"
  bi "  exit                    退出专家模式"
  bi ""
}

expert_show() {
  bi "Context:"
  bi "  IP_MODE=${IP_MODE}  BACKEND=${BACKEND}"
  bi "  TABLE=${TABLE}  CHAIN=${CHAIN}"
  bi "  PERSIST_AFTER_CHANGE=${PERSIST_AFTER_CHANGE}  PERSIST_METHOD=${PERSIST_METHOD}"
}

expert_translate_shortcuts() {
  local s="$1"
  s="$(trim "$s")"
  [[ -z "$s" ]] && { printf "\n"; return 0; }

  if [[ "$s" == "L" ]]; then
    printf "%s\n" "-L $CHAIN -n -v --line-numbers"
    return 0
  fi
  if [[ "$s" == "S" ]]; then
    printf "%s\n" "-S $CHAIN"
    return 0
  fi
  if [[ "$s" == "F" ]]; then
    printf "%s\n" "-F $CHAIN"
    return 0
  fi

  if [[ "$s" =~ ^A[[:space:]]+ ]]; then
    printf "%s\n" "-A ${s:2}"
    return 0
  fi
  if [[ "$s" =~ ^I[[:space:]]+ ]]; then
    printf "%s\n" "-I ${s:2}"
    return 0
  fi
  if [[ "$s" =~ ^D[[:space:]]+ ]]; then
    printf "%s\n" "-D ${s:2}"
    return 0
  fi

  printf "%s\n" "$s"
}

expert_parse_dsl() {
  # Parses a colloquial DSL line into an iptables args string.
  # Returns an empty line if the input doesn't match any known pattern.
  #
  # Supported prefixes/suffixes (combinable):
  #   insert <...>                    use -I CHAIN 1 instead of -A CHAIN
  #   from <src-ip> [to <dst-ip>]     source / destination address
  #   to <dst-ip>                     destination address only
  #   <...> on <iface>                bind to interface (-i <iface>)
  #
  # Core patterns (port/proto/action):
  #   <port>/tcp allow                ACCEPT single port
  #   <port>/udp drop                 DROP single port
  #   80,443/tcp allow                multiport (no ranges mixed)
  #   1000-2000/tcp allow             port range
  #   allow <port>/tcp                word order flipped
  #   <port>/tcp log                  LOG target (prefix: iptctl:)
  #   <port>/tcp reject               REJECT target
  #
  # Actions: allow / accept / drop / deny / reject / log

  local s="$(trim "${1-}")"
  [[ -z "$s" ]] && { printf "\n"; return 0; }

  local op_flag="-A" iface="" src="" dst=""
  local rest="" action="" portspec="" proto="" target="" out="" a="" b="" p="" porttmp=""
  local has_comma=0 has_dash=0

  # Step 1: strip "insert" prefix → use -I CHAIN 1
  if [[ "$s" =~ ^insert[[:space:]]+(.+)$ ]]; then
    op_flag="-I"
    s="$(trim "${BASH_REMATCH[1]}")"
  fi

  # Step 2: strip "on <iface>" suffix
  if [[ "$s" =~ ^(.*)[[:space:]]+on[[:space:]]+([^[:space:]]+)$ ]]; then
    iface="${BASH_REMATCH[2]}"
    s="$(trim "${BASH_REMATCH[1]}")"
  fi

  # Step 3: parse "from <src>" and optional "to <dst>", or standalone "to <dst>"
  if [[ "$s" =~ ^from[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
    src="${BASH_REMATCH[1]}"
    s="$(trim "${BASH_REMATCH[2]}")"
    if [[ "$s" =~ ^to[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
      dst="${BASH_REMATCH[1]}"
      s="$(trim "${BASH_REMATCH[2]}")"
    fi
  elif [[ "$s" =~ ^to[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
    dst="${BASH_REMATCH[1]}"
    s="$(trim "${BASH_REMATCH[2]}")"
  fi

  rest="$s"

  # Step 4: match core port/proto/action pattern
  local ACT_PAT="allow|accept|drop|deny|reject|log"
  local PORT_PAT="[0-9][0-9,-]*|[0-9]+-[0-9]+"
  if [[ "$rest" =~ ^(${PORT_PAT})\/(tcp|udp)[[:space:]]+(${ACT_PAT})$ ]]; then
    portspec="${BASH_REMATCH[1]}"
    proto="${BASH_REMATCH[2]}"
    action="${BASH_REMATCH[3]}"
  elif [[ "$rest" =~ ^(${ACT_PAT})[[:space:]]+(${PORT_PAT})\/(tcp|udp)$ ]]; then
    action="${BASH_REMATCH[1]}"
    portspec="${BASH_REMATCH[2]}"
    proto="${BASH_REMATCH[3]}"
  else
    printf "\n"
    return 0
  fi

  case "$action" in
    allow|accept) target="ACCEPT" ;;
    drop|deny)    target="DROP"   ;;
    reject)       target="REJECT" ;;
    log)          target="LOG"    ;;
    *) printf "\n"; return 0 ;;
  esac

  [[ "$portspec" == *","* ]] && has_comma=1
  [[ "$portspec" == *"-"* ]] && has_dash=1

  if (( has_comma == 1 && has_dash == 1 )); then
    bi "[FAIL] DSL：multiport 不支持混合逗号+范围写法（如 80,100-200）" >&2
    printf "\n"; return 0
  fi

  # Build the args string
  if [[ "$op_flag" == "-I" ]]; then
    out="-I ${CHAIN} 1"
  else
    out="-A ${CHAIN}"
  fi
  [[ -n "$iface" ]] && out+=" -i ${iface}"
  [[ -n "$src"   ]] && out+=" -s ${src}"
  [[ -n "$dst"   ]] && out+=" -d ${dst}"
  out+=" -p ${proto}"

  _dsl_append_target() {
    local _t="$1"
    if [[ "$_t" == "LOG" ]]; then
      printf " -j LOG --log-prefix iptctl:"
    else
      printf " -j %s" "$_t"
    fi
  }

  if (( has_comma == 1 )); then
    porttmp="${portspec//,/ }"
    for p in $porttmp; do
      valid_port "$p" || { bi "[FAIL] DSL：端口无效：$p" >&2; printf "\n"; return 0; }
    done
    out+=" -m multiport --dports ${portspec}$(_dsl_append_target "$target")"
    printf "%s\n" "$out"; return 0
  fi

  if (( has_dash == 1 )); then
    a="${portspec%-*}"; b="${portspec#*-}"
    valid_port "$a" || { bi "[FAIL] DSL：端口无效：$a" >&2; printf "\n"; return 0; }
    valid_port "$b" || { bi "[FAIL] DSL：端口无效：$b" >&2; printf "\n"; return 0; }
    out+=" --dport ${a}:${b}$(_dsl_append_target "$target")"
    printf "%s\n" "$out"; return 0
  fi

  valid_port "$portspec" || { bi "[FAIL] DSL：端口无效：$portspec" >&2; printf "\n"; return 0; }
  out+=" --dport ${portspec}$(_dsl_append_target "$target")"
  printf "%s\n" "$out"
  return 0
}

expert_shell() {
  bi ""
  bi "$LINE"
  bi "[EXPERT] 已进入专家模式 / EXPERT"
  bi "   - EXPERT 不做任何确认/备份/护栏：你输入什么，就执行什么"
  bi "   - 自动补充：-t ${TABLE}"
  bi "   - 输入 help 查看说明，exit 退出"
  bi "$LINE"
  expert_help

  local line s arg
  while true; do
    read -r -e -p "iptctl[EXPERT][$TABLE/$CHAIN][$IP_MODE]> " line || break
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    if [[ "$line" == "exit" ]]; then break; fi
    if [[ "$line" == "help" ]]; then expert_help; continue; fi
    if [[ "$line" == "show" ]]; then expert_show; continue; fi
    if [[ "$line" == "persist" ]]; then run_action "固化一次 / Persist now" persist_apply; continue; fi
    if [[ "$line" == "search" ]]; then search_rules; continue; fi
    if [[ "$line" == "backup" ]]; then
      local _bfams=()
      if [[ "$IP_MODE" == "4" ]]; then _bfams=("4")
      elif [[ "$IP_MODE" == "6" ]]; then _bfams=("6")
      else _bfams=("4" "6"); fi
      do_backup "${_bfams[@]}"
      continue
    fi

    # block <ip>  /  block from <ip>
    if [[ "$line" =~ ^block([[:space:]]+from)?[[:space:]]+([^[:space:]]+)$ ]]; then
      local _blk_ip="${BASH_REMATCH[2]}"
      local _blk_fam; [[ "$_blk_ip" == *:* ]] && _blk_fam="6" || _blk_fam="4"
      run_ipt "$_blk_fam" -A "$CHAIN" -s "$_blk_ip" -j DROP \
        && bi "[OK] blocked: $_blk_ip" \
        || bi "[WARN] block failed"
      continue
    fi

    # unblock <ip>  /  unblock from <ip>
    if [[ "$line" =~ ^unblock([[:space:]]+from)?[[:space:]]+([^[:space:]]+)$ ]]; then
      local _ublk_ip="${BASH_REMATCH[2]}"
      local _ublk_fam; [[ "$_ublk_ip" == *:* ]] && _ublk_fam="6" || _ublk_fam="4"
      run_ipt "$_ublk_fam" -D "$CHAIN" -s "$_ublk_ip" -j DROP \
        && bi "[OK] unblocked: $_ublk_ip" \
        || bi "[WARN] unblock failed (rule may not exist)"
      continue
    fi

    # policy <ACTION>
    if [[ "$line" =~ ^policy[[:space:]]+([^[:space:]]+)$ ]]; then
      local _pol="${BASH_REMATCH[1]}"
      _pol="${_pol^^}"
      run_ipt_scope -P "$CHAIN" "$_pol" && bi "[OK] policy ${CHAIN} ${_pol}"
      continue
    fi

    # ipset <args>  /  ipset (menu)
    if [[ "$line" == "ipset" ]]; then
      ipset_menu; continue
    fi
    if [[ "$line" =~ ^ipset[[:space:]]+(.+)$ ]]; then
      local _ipset_args="${BASH_REMATCH[1]}"
      ipset_ensure || continue
      set -f
      # shellcheck disable=SC2206
      local _ipset_arr=($_ipset_args)
      set +f
      run_ipset "${_ipset_arr[@]}" || bi "[WARN] ipset 命令失败"
      continue
    fi

    if [[ "$line" =~ ^ip[[:space:]]+ ]]; then
      arg="$(trim "${line#ip}")"
      case "$arg" in
        4|6|46) IP_MODE="$arg"; expert_show ;;
        *) bi "用法：ip 4|6|46" ;;
      esac
      continue
    fi

    if [[ "$line" =~ ^backend[[:space:]]+ ]]; then
      arg="$(trim "${line#backend}")"
      case "$arg" in
        auto|nft|legacy) BACKEND="$arg"; expert_show ;;
        *) bi "用法：backend auto|nft|legacy" ;;
      esac
      continue
    fi

    if [[ "$line" =~ ^table[[:space:]]+ ]]; then
      arg="$(trim "${line#table}")"
      [[ -n "$arg" ]] && TABLE="$arg"
      expert_show
      continue
    fi

    if [[ "$line" =~ ^chain[[:space:]]+ ]]; then
      arg="$(trim "${line#chain}")"
      [[ -n "$arg" ]] && CHAIN="$arg"
      expert_show
      continue
    fi

    # Strip trailing # comment before DSL/shortcut parsing
    local expert_comment="" line_nc="$line"
    if [[ "$line" =~ ^([^#]*)#(.*)$ ]]; then
      line_nc="$(trim "${BASH_REMATCH[1]}")"
      expert_comment="$(trim "${BASH_REMATCH[2]}")"
    fi
    [[ -z "$line_nc" ]] && continue

    s="$(expert_parse_dsl "$line_nc")"
    s="$(trim "$s")"
    if [[ -z "$s" ]]; then
      s="$(expert_translate_shortcuts "$line_nc")"
    fi
    s="$(trim "$s")"
    [[ -z "$s" ]] && continue

    set -f
    # shellcheck disable=SC2206
    local arr=($s)
    set +f

    local comment_arr=()
    [[ -n "$expert_comment" ]] && comment_arr=("-m" "comment" "--comment" "$expert_comment")

    run_ipt_scope "${arr[@]}" "${comment_arr[@]}" || {
      bi "[WARN] EXPERT：命令执行失败（可能是参数/模块/编号等问题）"
    }
  done
  bi "已退出专家模式 / Exit EXPERT"
}

###############################################################################
# Standard mode (原版完整控制台)
###############################################################################
standard_help_screen() {
  bi ""
  bi "╔════════════════════════════════════════════════════════════╗"
  bi "║               iptctl · Standard 模式说明                  ║"
  bi "╚════════════════════════════════════════════════════════════╝"
  bi "Standard 面向熟练用户："
  bi "  - 可选 table/chain，可添加/删除/批量删/清空/原始执行"
  bi "  - 删除与清空有护栏（备份+二次确认），避免误操作"
  bi "  - 不提供新手解释与逐步向导（保持效率）"
  pause
}

menu_standard() {
  bi ""
  bi "╔════════════════════════════════════════════════════════════╗"
  bi "║                 iptctl · 防火墙控制台                      ║"
  bi "╚════════════════════════════════════════════════════════════╝"
  bi "当前状态 / Current:"
  bi "  MODE=${MODE}"
  bi "  IP_MODE=${IP_MODE}   BACKEND=${BACKEND}"
  bi "  TABLE=${TABLE}   CHAIN=${CHAIN}"
  bi "  PERSIST_AFTER_CHANGE=${PERSIST_AFTER_CHANGE}  PERSIST_METHOD=${PERSIST_METHOD}"
  bi ""
  bi "  1) 环境检测 / Env check"
  bi "  2) 选择 IPv4 / IPv6 / Select IPv4 / IPv6"
  bi "  3) 选择后端（auto / nft / legacy）/ Select backend (auto / nft / legacy)"
  bi "  4) 选择表（table）/ Select table"
  bi "  5) 选择链（chain）/ Select chain"
  bi "  6) 说明与帮助 / Help"
  bi ""
  bi "  10) 查看规则 (-L 带编号)"
  bi "  11) 查看规则 (-S 原样)"
  bi "  12) 搜索规则（按端口/IP/关键字）"
  bi ""
  bi "  30) 添加规则（新手引导）"
  bi "  31) 删除规则（按编号）"
  bi "  32) 批量删除（编号列表/范围）"
  bi "  33) 清空链（-F，危险）"
  bi "  39) [WARN] 高级：原始参数执行"
  bi ""
  bi "  50) [PERSIST] 固化/持久化中心"
  bi ""
  bi "  60) [IPSET] ipset 管理（创建/批量封禁/应用到规则）"
  bi ""
  bi "  90) 切换模式"
  bi "  0) 退出"
  bi ""
}

standard_loop() {
  while true; do
    menu_standard
    local c
    c="$(read_num "输入选项 / Enter option: ")"
    case "$c" in
      0) iptctl_exit 0 ;;
      1) run_action "环境检测 / Env check" env_check; pause ;;
      2) run_action "选择 IP 模式" select_ip_mode ;;
      3) run_action "选择 backend" select_backend ;;
      4) run_action "选择 table" select_table ;;
      5) run_action "选择 chain" select_chain ;;
      6) standard_help_screen ;;
      10) run_action "查看规则 (-L)" list_rules_L; pause ;;
      11) run_action "查看规则 (-S)" list_rules_S; pause ;;
      12) run_action "搜索规则" search_rules; pause ;;
      30) run_action "添加规则（向导）" add_rule_wizard; pause ;;
      31) run_action "删除规则（按编号）" delete_rule_by_num; pause ;;
      32) run_action "批量删除（编号/范围）" delete_rules_bulk; pause ;;
      33) run_action "清空链（-F）" flush_chain; pause ;;
      39) run_action "原始参数执行" raw_exec; pause ;;
      50) run_action "固化/持久化中心" persist_menu ;;
      60) run_action "ipset 管理" ipset_menu ;;
      90) return 0 ;;
      *) bi "无效选项 / Invalid option" ;;
    esac
  done
}

###############################################################################
# Main dispatcher (三模式调度)
###############################################################################
main() {
  config_load
  ui_style_maybe_prompt
  while true; do
    select_mode
    case "$MODE" in
      beginner) beginner_loop ;;
      standard) standard_loop ;;
      expert)   expert_shell ;;
      *) MODE="" ;;
    esac
  done
}

main
