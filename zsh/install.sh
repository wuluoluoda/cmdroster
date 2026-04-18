#!/usr/bin/env bash
# CmdRoster (luo) — 安装脚本
# macOS : ./install.sh  或  curl -fsSL .../install.sh | bash
# WSL   : 同上（在 WSL 终端里运行）
# curl  : curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/install.sh | bash
set -euo pipefail

GITHUB_RAW="https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh"
DEST="${LUO_HOME:-$HOME/.luo}"
MARK_BEGIN="# >>> luo script hub"
MARK_END="# <<< luo script hub"

_require_cmd() { command -v "$1" >/dev/null 2>&1; }

# ── 平台检测 ─────────────────────────────────────────────────────────────────
_is_macos() { [[ "$(uname -s 2>/dev/null)" == Darwin ]]; }
_is_wsl()   { [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; }
_is_linux() { [[ "$(uname -s 2>/dev/null)" == Linux ]]; }

# curl | bash 时 BASH_SOURCE[0] 为空、"bash" 或 "-"
_is_remote() {
  local src="${BASH_SOURCE[0]:-}"
  [[ -z "$src" || "$src" == "bash" || "$src" == "-" ]]
}

# ── 平台提示 ─────────────────────────────────────────────────────────────────
if ! _is_macos && ! _is_linux; then
  echo "⚠  未识别的操作系统（$(uname -s 2>/dev/null)）。" >&2
  echo "   CmdRoster 支持 macOS 和 Linux（含 WSL）。继续请按 Enter，Ctrl+C 中止。" >&2
  read -r
fi

if _is_wsl; then
  echo "✔  检测到 WSL 环境。"
elif _is_macos; then
  echo "✔  检测到 macOS 环境。"
elif _is_linux; then
  echo "✔  检测到 Linux 环境。"
fi

# ── fzf 检测与安装 ────────────────────────────────────────────────────────────
_install_fzf() {
  if _is_macos; then
    if _require_cmd brew; then
      echo "→  通过 Homebrew 安装 fzf …"
      brew install fzf
    else
      echo "未找到 Homebrew，请先安装：" >&2
      echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
      echo "  brew install fzf" >&2
      exit 1
    fi
  elif _is_linux; then
    if _require_cmd apt-get; then
      echo "→  通过 apt-get 安装 fzf …"
      sudo apt-get update -qq && sudo apt-get install -y fzf
    elif _require_cmd apt; then
      echo "→  通过 apt 安装 fzf …"
      sudo apt update -qq && sudo apt install -y fzf
    elif _require_cmd pacman; then
      echo "→  通过 pacman 安装 fzf …"
      sudo pacman -Sy --noconfirm fzf
    elif _require_cmd dnf; then
      echo "→  通过 dnf 安装 fzf …"
      sudo dnf install -y fzf
    elif _require_cmd yum; then
      echo "→  通过 yum 安装 fzf …"
      sudo yum install -y fzf
    elif _require_cmd zypper; then
      echo "→  通过 zypper 安装 fzf …"
      sudo zypper install -y fzf
    else
      echo "未找到支持的包管理器，请手动安装 fzf：" >&2
      echo "  https://github.com/junegunn/fzf#installation" >&2
      exit 1
    fi
  else
    echo "请手动安装 fzf：https://github.com/junegunn/fzf#installation" >&2
    exit 1
  fi
}

if ! _require_cmd fzf; then
  echo ""
  echo "CmdRoster 依赖 fzf，当前环境未安装。"
  if [[ -t 0 ]]; then
    read -rp "是否自动安装 fzf？[Y/n] " _yn
    _yn="${_yn:-Y}"
    if [[ "$_yn" =~ ^[Yy] ]]; then
      _install_fzf
    else
      echo "请先安装 fzf 后再运行本脚本。" >&2
      exit 1
    fi
  else
    # 非交互模式（curl | bash）：直接安装
    echo "非交互模式，自动安装 fzf …"
    _install_fzf
  fi
fi

# ── 建目录 & 复制/下载文件 ───────────────────────────────────────────────────
mkdir -p "$DEST/scripts"

if _is_remote; then
  if ! _require_cmd curl; then
    echo "需要 curl，但未找到。" >&2; exit 1
  fi
  echo "正在从 GitHub 下载 luo.zsh …"
  curl -fsSL "$GITHUB_RAW/luo.zsh"              -o "$DEST/luo.zsh"
  curl -fsSL "$GITHUB_RAW/registry.tsv.example" -o "$DEST/registry.tsv.example"
  if [[ ! -f "$DEST/registry.tsv" ]]; then
    cp "$DEST/registry.tsv.example" "$DEST/registry.tsv"
  fi
else
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cp "$ROOT/luo.zsh" "$DEST/luo.zsh"
  chmod a+r "$DEST/luo.zsh"
  if [[ ! -f "$DEST/registry.tsv" ]]; then
    cp "$ROOT/registry.tsv.example" "$DEST/registry.tsv"
    chmod a+r "$DEST/registry.tsv"
  fi
fi

# ── 写入 zshrc ────────────────────────────────────────────────────────────────
# WSL 下 zsh 的配置文件路径与原生 Linux/macOS 一致：$ZDOTDIR/.zshrc 或 ~/.zshrc
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
[[ -f "$ZSHRC" ]] || touch "$ZSHRC"

if grep -qF "$MARK_BEGIN" "$ZSHRC" 2>/dev/null; then
  echo "已检测到 ~/.zshrc 中的 luo 配置块，跳过写入。"
else
  {
    printf '\n%s\n' "$MARK_BEGIN"
    if [[ "$DEST" != "$HOME/.luo" ]]; then
      printf 'export LUO_HOME=%q\n' "$DEST"
    fi
    printf '[ -f %q ] && source %q\n' "$DEST/luo.zsh" "$DEST/luo.zsh"
    printf '%s\n' "$MARK_END"
  } >>"$ZSHRC"
  echo "已写入: ${ZSHRC}（新开终端自动生效）"
fi

# ── 完成提示 ─────────────────────────────────────────────────────────────────
cat <<EOF

✅  luo 已安装到 $DEST

▶  在当前终端立刻激活（或新开一个终端）：
     source "$DEST/luo.zsh"

▶  快速上手：
     luo add "ping google.com"   # 登记一条命令
     luo help                    # fzf 选命令，回车后出现在命令行
     luo alias ql                # 把 ql 设为 luo help 的快捷方式

EOF

if _is_wsl; then
  cat <<'WSLNOTE'
💡  WSL 提示：
    · 若希望在 Windows Terminal 里使用，请确保默认 Shell 已设为 zsh：
        chsh -s $(which zsh)
    · 若 zsh 未安装：sudo apt-get install -y zsh
    · 若 fzf 界面无法显示，请检查终端仿真器是否支持 256 色（Windows Terminal 默认支持）。

WSLNOTE
fi
