# luo — personal script hub for zsh
# Usage: add to ~/.zshrc
#   source "${LUO_HOME:-$HOME/.luo}/luo.zsh"
#
# Registry: $LUO_HOME/registry.tsv — tab-separated, UTF-8:
#   name	description	kind	payload
# kind: file → payload 为相对 LUO_HOME 的路径（如 scripts/foo.sh）
# kind: shell → payload 为填入命令行的整段 shell 命令（勿含 Tab）

_luo_home() {
  print -r -- "${LUO_HOME:-$HOME/.luo}"
}

_luo_registry() {
  print -r -- "$(_luo_home)/registry.tsv"
}

_luo_header_new() {
  print -r $'name\tdescription\tkind\tpayload'
}

# 将正文行规范为四列；支持旧三列（视为 kind=file, payload=原第三列）
_luo_normalize_body_line() {
  local line=$1
  local -a parts
  line=${line%%$'\r'}
  while [[ $line == [[:space:]]* ]]; do
    line=${line#[[:space:]]}
  done
  while [[ $line == *[[:space:]] ]]; do
    line=${line%[[:space:]]}
  done
  [[ -n $line ]] || return 1
  IFS=$'\t' read -rA parts <<<"$line"
  [[ $parts[1] == name ]] && return 1
  if (( ${#parts[@]} < 3 )); then
    print -u2 "luo: 跳过列数不足的 registry 行（${#parts[@]} 段）: ${(V)line}"
    return 1
  fi
  if (( ${#parts[@]} == 3 )); then
    print -r -- "$parts[1]"$'\t'"$parts[2]"$'\t'"file"$'\t'"$parts[3]"
  elif (( ${#parts[@]} == 4 )); then
    print -r -- "$parts[1]"$'\t'"$parts[2]"$'\t'"$parts[3]"$'\t'"$parts[4]"
  elif (( ${#parts[@]} > 4 )); then
    print -r -- "$parts[1]"$'\t'"$parts[2]"$'\t'"$parts[3]"$'\t'"${(pj:\t:)parts[4,-1]}"
  else
    print -u2 "luo: 跳过列数异常的 registry 行（期望 >=3 列，实际 ${#parts[@]} 段）: ${line[1,60]}…"
    return 1
  fi
}

# 若仍为旧表头（含 rel_path、无 kind），整表迁移为四列
_luo_migrate_registry_if_needed() {
  local r first tmp line norm
  r=$(_luo_registry)
  [[ -f $r ]] || return 0
  IFS= read -r first <"$r"
  [[ $first == *rel_path* ]] || return 0
  [[ $first == *$'\t'kind$'\t'* ]] && return 0
  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-migrate.XXXXXX")
  _luo_header_new >"$tmp"
  tail -n +2 "$r" | while IFS= read -r line; do
    [[ -z $line ]] && continue
    [[ $line == name$'\t'* ]] && continue
    norm=$(_luo_normalize_body_line "$line") || continue
    print -r -- "$norm"
  done >>"$tmp"
  command mv -f "$tmp" "$r"
  print -u2 "luo: 已将 registry.tsv 迁移为四列格式（name/description/kind/payload）"
}

_luo_init_files() {
  local h r u
  h=$(_luo_home)
  r="$h/registry.tsv"
  u="$h/usage.tsv"
  mkdir -p "$h/scripts"
  if [[ ! -f $r ]]; then
    _luo_header_new >"$r"
  else
    _luo_migrate_registry_if_needed
  fi
  if [[ ! -f $u ]]; then
    print -r $'name\tcount' >"$u"
  fi
}

_luo_usage_file() {
  print -r -- "$(_luo_home)/usage.tsv"
}

# 返回整数次（无记录为 0）
_luo_usage_get() {
  local name=$1 f r
  f=$(_luo_usage_file)
  [[ -f $f ]] || { print -r 0; return 0 }
  r=$(command awk -F '\t' -v n="$name" 'NR>1 && $1==n { print $2; exit }' "$f")
  [[ -n $r && $r == <-> ]] || r=0
  print -r -- "$r"
}

_luo_usage_incr() {
  local name=$1 f tmp
  [[ -n $name ]] || return 0
  f=$(_luo_usage_file)
  _luo_init_files
  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-usage.XXXXXX")
  command awk -F '\t' -v OFS='\t' -v n="$name" '
    NR==1 { print; next }
    $1 == n {
      c = $2 + 0
      if (c < 0) c = 0
      c++
      print $1, c
      found = 1
      next
    }
    { print }
    END {
      if (!found) print n "\t" 1
    }
  ' "$f" >"$tmp" || return 1
  command mv -f "$tmp" "$f"
}

_luo_usage_remove_name() {
  local name=$1 f tmp
  f=$(_luo_usage_file)
  [[ -f $f ]] || return 0
  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-usage.XXXXXX")
  command awk -F '\t' -v n="$name" 'NR==1{print;next} $1!=n{print}' "$f" >"$tmp" || return 1
  command mv -f "$tmp" "$f"
}

_luo_require_fzf() {
  if ! command -v fzf >/dev/null 2>&1; then
    print -u2 "luo: 需要安装 fzf（例如: brew install fzf）"
    return 127
  fi
}

_luo_usage() {
  print -r -- "用法:
  luo help          交互选择（名称字母序；Tab 用当前项名称填搜索框缩小范围）
                    按 Fn+F2（笔记本常见：须 Fn 才发出 F2）进入/退出「删除模式」（界面为绿色）；删除模式下 Enter 直接删当前项。
                    每次在普通模式下用 Enter 填入命令行会为该登记名累计使用次数（见 usage.tsv）；
                    删除前若次数 >30 会交互确认（非交互终端则拒绝删除）。
  luo list          按名字母序列出（同样会先补全）
  luo add [选项] <一段文本…>  导入一条入口（见下方判定规则）
  luo sync [-p]     扫描 scripts/ 补全缺失；-p 删除失效 file 表项
  luo rm / remove   直接进入 luo help 且初始为删除模式（不接受其它参数）
  luo home          打印 LUO_HOME

命令行补全（zsh）：子命令名等（补全函数 _luo_cmd_complete）。~/.zshrc 须先 compinit 再 source 本文件；见文件末尾 precmd 兜底注册。

luo add 判定（剩余参数会拼成一段字符串，外层引号会剥掉一层）:
  · 若看起来像「脚本路径」且磁盘上存在该普通文件 → kind=file：在 scripts/ 建符号链接并登记
    条件：路径含 \"/\"，或以 \"./\" \"../\" 开头，且 [[ -f 解析后路径 ]]
  · 否则 → kind=shell：整段字符串作为命令（填入命令行），不建链接

  无 \"/\" 的相对脚本请写成 ./foo.sh 再 luo add。

选项:
  -n <名称>   列表里显示的名字（脚本默认 basename；命令默认取首词）
  -d <简介>   列表简介；file 且省略时读 \"# luo:desc ...\"
  -f          覆盖同名；shell 时若已有相同命令也会直接删掉旧条目再登记"
}

_luo_registry_sorted_fourcol_lines() {
  local r line norm
  r=$(_luo_registry)
  tail -n +2 "$r" 2>/dev/null | command grep -v '^[[:space:]]*$' | while IFS= read -r line; do
    [[ -z $line ]] && continue
    [[ $line == name$'\t'* ]] && continue
    norm=$(_luo_normalize_body_line "$line") || continue
    print -r -- "$norm"
  done | LC_ALL=C sort -f -t $'\t' -k1,1
}

_luo_list() {
  _luo_init_files
  _luo_sync_merge ""
  _luo_header_new
  _luo_registry_sorted_fourcol_lines
}

# 按首列名字判断是否存在
_luo_name_in_registry() {
  local want=$1 r line norm n d k p
  r=$(_luo_registry)
  [[ -f $r ]] || return 1
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    norm=$(_luo_normalize_body_line "$line") || continue
    IFS=$'\t' read -r n d k p <<<"$norm"
    [[ $n == "$want" ]] && return 0
  done < <(tail -n +2 "$r" 2>/dev/null)
  return 1
}

_luo_desc_from_script() {
  local src=$1 line raw
  [[ -f $src ]] || return 1
  while IFS= read -r line; do
    [[ $line == '# luo:desc'* ]] || continue
    raw=${line#\# luo:desc}
    while [[ $raw == [[:space:]]* ]]; do
      raw=${raw#[[:space:]]}
    done
    raw=${raw%%$'\r'}
    [[ -n $raw ]] || return 1
    print -r -- "$raw"
    return 0
  done <"$src"
  return 1
}

_luo_remove_registry_row_by_name() {
  local name=$1 r tmp
  r=$(_luo_registry)
  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-registry.XXXXXX")
  command awk -F '\t' -v n="$name" "NR==1{print;next}\$1!=n{print}" "$r" >"$tmp" || return 1
  command mv -f "$tmp" "$r"
}

# 打印一行 kind<TAB>payload，供按名称删除使用
_luo_row_kind_payload_for_name() {
  local want=$1 r line norm n d k p
  r=$(_luo_registry)
  [[ -f $r ]] || return 1
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    norm=$(_luo_normalize_body_line "$line") || continue
    IFS=$'\t' read -r n d k p <<<"$norm"
    [[ $n == "$want" ]] || continue
    print -r -- "$k"$'\t'"$p"
    return 0
  done < <(tail -n +2 "$r" 2>/dev/null)
  return 1
}

_luo_remove_by_name() {
  local name=$1 h kind payload kp
  [[ -n $name ]] || { print -u2 "luo: 名称不能为空"; return 1 }
  [[ $name == */* ]] && { print -u2 "luo: 名称不得包含路径分隔符"; return 1 }

  h=$(_luo_home)
  _luo_init_files
  if ! _luo_name_in_registry "$name"; then
    print -u2 "luo: 未找到名称: $name"
    return 1
  fi

  kp=$(_luo_row_kind_payload_for_name "$name") || {
    print -u2 "luo: 无法解析条目: $name"
    return 1
  }
  IFS=$'\t' read -r kind payload <<<"$kp"

  if [[ $kind == file ]]; then
    if [[ $payload == scripts/* ]]; then
      if [[ -L "$h/$payload" || -e "$h/$payload" ]]; then
        command rm -f "$h/$payload"
        print -r -- "已删除 scripts 链接: $h/$payload"
      fi
    fi
  elif [[ $kind != shell ]]; then
    print -u2 "luo: 未知 kind: $kind"
    return 1
  fi

  _luo_remove_registry_row_by_name "$name" || return 1
  print -r -- "已从 registry 移除: $name"
}

# file 且 payload 为给定路径（如 scripts/foo）
_luo_registry_has_file_payload() {
  local want=$1 r line norm n d k p
  r=$(_luo_registry)
  [[ -f $r ]] || return 1
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    norm=$(_luo_normalize_body_line "$line") || continue
    IFS=$'\t' read -r n d k p <<<"$norm"
    [[ $k == file && $p == "$want" ]] && return 0
  done < <(tail -n +2 "$r" 2>/dev/null)
  return 1
}

_luo_sync_merge() {
  local verbose=$1 h scr r f rel desc added
  h=$(_luo_home)
  scr="$h/scripts"
  r=$(_luo_registry)
  _luo_init_files
  added=0
  for f in "$scr"/*(N); do
    [[ -e $f ]] || continue
    [[ -L $f ]] && [[ ! -e ${f:A} ]] && continue
    [[ -d ${f:A} ]] && continue
    rel="scripts/${f:t}"
    if _luo_registry_has_file_payload "$rel"; then
      continue
    fi
    desc=$(_luo_desc_from_script "${f:A}")
    [[ -z $desc ]] && desc="no description"
    desc=${desc//$'\t'/ }
    print -r -- "${f:t}"$'\t'"$desc"$'\t'"file"$'\t'"$rel" >>"$r"
    [[ -n $verbose ]] && print -r -- "sync: 已登记 $rel"
    added=$((added + 1))
  done
  [[ -n $verbose && $added -eq 0 ]] && print -r -- "sync: 无新条目（scripts/ 均已在 registry 中）"
  return 0
}

_luo_sync_prune() {
  local h r tmp line norm n d k p
  h=$(_luo_home)
  r=$(_luo_registry)
  [[ -f $r ]] || return 1
  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-prune.XXXXXX")
  _luo_header_new >"$tmp"
  tail -n +2 "$r" | while IFS= read -r line; do
    [[ -z $line ]] && continue
    norm=$(_luo_normalize_body_line "$line") || continue
    IFS=$'\t' read -r n d k p <<<"$norm"
    if [[ $k == file && $p == scripts/* && ! -e "$h/$p" ]]; then
      print -u2 "sync -p: 已移除失效条目: $n ($p)"
      continue
    fi
    print -r -- "$norm" >>"$tmp"
  done
  command mv -f "$tmp" "$r"
}

_luo_sync() {
  local prune=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p) prune=1; shift ;;
      -*)
        print -u2 "luo sync: 未知选项: $1"
        return 1
        ;;
      *) break ;;
    esac
  done
  [[ $# -gt 0 ]] && { print -u2 "luo sync: 不需要额外参数"; return 1 }
  _luo_init_files
  _luo_sync_merge 1
  [[ $prune -eq 1 ]] && _luo_sync_prune
}

# 从 shell 命令取默认 registry 名（首词，仅保留安全字符）
_luo_default_name_from_shell() {
  local c=$1 w
  local -a z
  c=${c## #}
  c=${c%% #}
  z=(${(z)c})
  w=$z[1]
  [[ -z $w ]] && w="cmd"
  w=${w//[^A-Za-z0-9_.-]/_}
  [[ -z $w ]] && w="cmd"
  print -r -- "$w"
}

# 用于判断「是否为同一条 shell 命令」（去首尾空白、Tab，按 shell 词法压成空格序列）
_luo_shell_payload_key() {
  local s=$1
  s=${s//$'\t'/ }
  while [[ $s == [[:space:]]* ]]; do
    s=${s#[[:space:]]}
  done
  while [[ $s == *[[:space:]] ]]; do
    s=${s%[[:space:]]}
  done
  [[ -n $s ]] || return 1
  print -r -- "${(j: :)${(z)s}}"
}

# 打印所有与 payload 等价的 shell 登记名（每行一个，已排序去重）
_luo_matching_shell_names_for_payload_key() {
  local payload=$1 r line norm n d k p want key
  want=$(_luo_shell_payload_key "$payload") || return 1
  r=$(_luo_registry)
  [[ -f $r ]] || return 1
  {
    while IFS= read -r line; do
      [[ -z $line ]] && continue
      norm=$(_luo_normalize_body_line "$line") || continue
      IFS=$'\t' read -r n d k p <<<"$norm"
      [[ $k == shell ]] || continue
      key=$(_luo_shell_payload_key "$p") || continue
      [[ $key == "$want" ]] || continue
      print -r -- "$n"
    done < <(tail -n +2 "$r" 2>/dev/null)
  } | LC_ALL=C sort -u
}

# 是否为「脚本路径」：含 / 或以 ./ ../ 开头，且解析后为普通文件
_luo_arg_is_script_path() {
  local raw=$1 p
  p=$raw
  [[ $p == \~/* ]] && p="${HOME}/${p#\~/}"
  [[ $p == \~ ]] && p=$HOME
  [[ $p == */* || $p == ./* || $p == ../* ]] || return 1
  [[ -f ${p:A} ]] || return 1
  return 0
}

_luo_add() {
  local force=0 dest_name= desc= raw p src_abs h dest relpath r name kind payload
  while [[ $# -gt 0 ]]; do
    case $1 in
      -f) force=1; shift ;;
      -n)
        [[ $# -ge 2 ]] || { print -u2 "luo add: -n 需要参数"; return 1 }
        dest_name=$2
        shift 2
        ;;
      -d)
        [[ $# -ge 2 ]] || { print -u2 "luo add: -d 需要参数"; return 1 }
        desc=$2
        shift 2
        ;;
      -*)
        print -u2 "luo add: 未知选项: $1"
        return 1
        ;;
      *) break ;;
    esac
  done

  [[ $# -gt 0 ]] || { print -u2 "luo add: 请提供命令或脚本路径"; return 1 }
  raw="${(j: :)@}"
  raw=${raw## #}
  raw=${raw%% #}
  if [[ $raw == \"*\" ]]; then
    raw=${raw#\"}
    raw=${raw%\"}
  elif [[ $raw == \'*\' ]]; then
    raw=${raw#\'}
    raw=${raw%\'}
  fi

  h=$(_luo_home)
  _luo_init_files
  r=$(_luo_registry)

  if _luo_arg_is_script_path "$raw"; then
    kind=file
    p=$raw
    [[ $p == \~/* ]] && p="${HOME}/${p#\~/}"
    [[ $p == \~ ]] && p=$HOME
    src_abs=${p:A}
    [[ -n $dest_name ]] || dest_name=${src_abs:t}
    [[ $dest_name == */* ]] && { print -u2 "luo add: -n 不得包含路径分隔符"; return 1 }

    dest="$h/scripts/$dest_name"
    relpath="scripts/$dest_name"

    if [[ -e $dest || -L $dest ]]; then
      if [[ $force -eq 1 ]]; then
        command rm -f "$dest"
      else
        print -u2 "luo add: 目标已存在: $dest （使用 -f 覆盖）"
        return 1
      fi
    fi

    if _luo_name_in_registry "$dest_name"; then
      if [[ $force -eq 1 ]]; then
        _luo_remove_registry_row_by_name "$dest_name"
      else
        print -u2 "luo add: 注册表中已有同名条目: $dest_name （使用 -f 覆盖）"
        return 1
      fi
    fi

    if [[ -z $desc ]]; then
      desc=$(_luo_desc_from_script "$src_abs")
      [[ -z $desc ]] && desc="no description"
    fi
    desc=${desc//$'\t'/ }

    command ln -sf "$src_abs" "$dest" || return 1
    if [[ ! -x $src_abs ]]; then
      command chmod +x "$src_abs" 2>/dev/null || true
    fi

    print -r -- "$dest_name"$'\t'"$desc"$'\t'"file"$'\t'"$relpath" >>"$r"
    print -r -- "已登记脚本(file): $dest_name -> $dest"
    return 0
  fi

  kind=shell
  payload=$raw
  payload=${payload//$'\t'/ }
  [[ -n $payload ]] || { print -u2 "luo add: 命令为空"; return 1 }

  [[ -n $dest_name ]] || dest_name=$(_luo_default_name_from_shell "$payload")
  [[ $dest_name == */* ]] && { print -u2 "luo add: -n 不得包含路径分隔符"; return 1 }

  local -a shell_dups
  if _luo_shell_payload_key "$payload" &>/dev/null; then
    shell_dups=(${(f)$(_luo_matching_shell_names_for_payload_key "$payload")})
  else
    shell_dups=()
  fi

  if (( ${#shell_dups[@]} > 0 )); then
    if [[ $force -eq 1 ]]; then
      local n
      for n in $shell_dups; do
        _luo_remove_registry_row_by_name "$n"
      done
    elif (( ${#shell_dups[@]} == 1 )) && [[ $shell_dups[1] == "$dest_name" ]]; then
      print -r -- "luo add: 已存在相同登记（名称与命令均一致），跳过"
      return 0
    elif [[ -t 0 ]]; then
      print -u2 "luo add: 已存在相同命令，当前登记名: ${(j:，)shell_dups}"
      print -u2 "luo add: 命令: $payload"
      read -q '?是否删除上述条目并改为当前这一条？[y/N] ' || { print -u2 ""; return 1 }
      print -u2 ""
      local n
      for n in $shell_dups; do
        _luo_remove_registry_row_by_name "$n"
      done
    else
      print -u2 "luo add: 已存在相同命令（登记名: ${(j:，)shell_dups}），非交互终端请使用 -f"
      return 1
    fi
  fi

  if _luo_name_in_registry "$dest_name"; then
    if [[ $force -eq 1 ]]; then
      _luo_remove_registry_row_by_name "$dest_name"
    else
      print -u2 "luo add: 注册表中已有同名条目: $dest_name （使用 -f 覆盖）"
      return 1
    fi
  fi

  if [[ -z $desc ]]; then
    if (( ${#payload} > 72 )); then
      desc="${payload[1,72]}…"
    else
      desc=$payload
    fi
  fi
  desc=${desc//$'\t'/ }

  print -r -- "$dest_name"$'\t'"$desc"$'\t'"shell"$'\t'"$payload" >>"$r"
  print -r -- "已登记命令(shell): $dest_name"
}

_luo_pick() {
  local h line name desc kind payload fullpath cmd
  local -a fl
  local out hdr pr color cnt
  integer del_mode=${LUO_DELETE_START:-0}
  unset LUO_DELETE_START

  _luo_require_fzf || return
  _luo_init_files
  _luo_sync_merge ""
  h=$(_luo_home)

  while true; do
    if (( del_mode )); then
      hdr=$'\e[32m[删除模式]\e[0m Enter 删除 | Fn+F2 退出删除模式 | Tab 缩小 | Ctrl+N / Esc 退出'
      pr=$'\e[1;32mDEL>\e[0m '
      color='prompt:#00cc00,pointer:#00ff00,fg+:#ccffcc,border:#00aa00'
    else
      hdr=$'Tab 缩小 | Enter 填入命令行 | \e[33mFn+F2\e[0m 删除模式（绿色）| Ctrl+N / Esc 退出'
      pr='> '
      color=
    fi

    out=$(
      _luo_registry_sorted_fourcol_lines |
        command fzf \
        --delimiter=$'\t' \
        --with-nth=1,2,3 \
        --nth=1,2,3,4 \
        --no-multi \
        +s \
        ${color:+--color="$color"} \
        --prompt="$pr" \
        --header="$hdr" \
        --expect=f2 \
        --bind='tab:change-query({1})' \
        --bind='ctrl-n:abort'
    ) || return 0
    [[ -n $out ]] || return 0

    fl=("${(@f)out}")
    if [[ ${fl[1]} == f2 ]]; then
      del_mode=$(( 1 - del_mode ))
      continue
    fi

    line=${fl[1]}
    [[ -n $line ]] || return 0

    IFS=$'\t' read -r name desc kind payload <<<"$line"
    [[ -n $name && -n $kind && -n $payload ]] || return 1

    if (( del_mode )); then
      cnt=$(_luo_usage_get "$name")
      cnt=$(( cnt + 0 ))
      if (( cnt > 30 )); then
        if [[ -t 0 ]]; then
          read -q "?该条目在 help 中已使用 ${cnt} 次（>30），确认删除？[y/N] " || {
            print ""
            continue
          }
          print ""
        else
          print -u2 "luo: 非交互终端且使用次数 ${cnt}>30，未删除: $name"
          continue
        fi
      fi
      if _luo_remove_by_name "$name"; then
        _luo_usage_remove_name "$name"
      fi
      continue
    fi

    if [[ $kind == shell ]]; then
      _luo_usage_incr "$name"
      print -z -- "$payload"
      return 0
    fi

    if [[ $kind != file ]]; then
      print -u2 "luo: 未知 kind: $kind"
      return 1
    fi

    fullpath="$h/$payload"
    if [[ ! -e $fullpath ]]; then
      print -u2 "luo: 文件不存在: $fullpath"
      return 1
    fi
    if [[ -x $fullpath ]]; then
      cmd=${(q)fullpath}
    else
      cmd="zsh ${(q)fullpath}"
    fi
    _luo_usage_incr "$name"
    print -z -- "$cmd"
    return 0
  done
}

luo() {
  local sub=${1:-}
  case $sub in
    help | pick)
      shift
      _luo_pick "$@"
      ;;
    list)
      shift
      _luo_list "$@"
      ;;
    add)
      shift
      _luo_add "$@"
      ;;
    sync)
      shift
      _luo_sync "$@"
      ;;
    remove | rm)
      if [[ -n ${2-} ]]; then
        print -u2 "luo rm/remove: 不再接受名称参数；请执行: luo help，按 Fn+F2 进入删除模式"
        return 1
      fi
      LUO_DELETE_START=1
      _luo_pick
      ;;
    home)
      _luo_home
      ;;
    "" | -h | --help)
      _luo_usage
      ;;
    *)
      print -u2 "luo: 未知子命令: $sub"
      _luo_usage
      return 1
      ;;
  esac
}

# ---- zsh 补全（子命令等）----
# 使用独立函数名 _luo_cmd_complete，避免与 $fpath 里名为 _luo 的系统补全片段冲突。
_luo_cmd_complete() {
  local sub

  if (( CURRENT == 2 )); then
    compadd help list add sync remove rm home pick
    return
  fi

  sub=${words[2]:l}
  case $sub in
    add)
      _files "$@"
      ;;
    sync)
      if (( CURRENT == 3 )); then
        compadd -p -S '' -- -p
      else
        _default "$@"
      fi
      ;;
    *)
      _default "$@"
      ;;
  esac
}

_luo_register_compdef_once() {
  (( $+functions[compdef] )) || return 0
  compdef -r luo 2>/dev/null
  compdef _luo_cmd_complete luo 2>/dev/null
  add-zsh-hook -d precmd _luo_register_compdef_once 2>/dev/null
}

_luo_try_compdef() {
  (( $+functions[compdef] )) || return 0
  compdef -r luo 2>/dev/null
  compdef _luo_cmd_complete luo 2>/dev/null
}

if (( $+functions[compdef] )); then
  _luo_try_compdef
elif autoload -Uz add-zsh-hook 2>/dev/null; then
  add-zsh-hook precmd _luo_register_compdef_once
fi

# 若 zshrc 里先 source 本文件、后 compinit，第一次执行 luo 时再注册一次
# unfunction 在目标不存在时返回非 0，会导致「source 本文件」整体退出码为 1
unfunction _luo 2>/dev/null || :
