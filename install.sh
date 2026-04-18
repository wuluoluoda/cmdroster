#!/usr/bin/env bash
# luo — 一键安装脚本
# 用法（克隆后）: ./install.sh
# curl: curl -fsSL https://raw.githubusercontent.com/wuluoluoda/luo/main/install.sh | bash
set -euo pipefail

GITHUB_RAW="https://raw.githubusercontent.com/wuluoluoda/luo/main"

DEST="${LUO_HOME:-$HOME/.luo}"
MARK_BEGIN="# >>> luo script hub"
MARK_END="# <<< luo script hub"

_require_cmd() { command -v "$1" >/dev/null 2>&1; }

# curl | bash 时 BASH_SOURCE[0] 为空、"bash" 或 "-"
_is_remote() {
  local src="${BASH_SOURCE[0]:-}"
  [[ -z "$src" || "$src" == "bash" || "$src" == "-" ]]
}

# ── macOS 检查 ────────────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "luo 目前仅在 macOS 上测试过，继续安装请按 Enter，Ctrl+C 中止。" >&2
  read -r
fi

# ── fzf 检查 ─────────────────────────────────────────────────────────────────
if ! _require_cmd fzf; then
  echo ""
  echo "luo 依赖 fzf，当前环境未安装。"
  if _require_cmd brew; then
    read -rp "用 Homebrew 安装 fzf？[Y/n] " _yn
    _yn="${_yn:-Y}"
    if [[ "$_yn" =~ ^[Yy] ]]; then
      brew install fzf
    else
      echo "请先安装 fzf：brew install fzf" >&2
      exit 1
    fi
  else
    echo "未找到 Homebrew。请先安装 fzf 再重新运行：" >&2
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
    echo "  brew install fzf" >&2
    exit 1
  fi
fi

# ── 建目录 & 复制/下载文件 ───────────────────────────────────────────────────
mkdir -p "$DEST/scripts"

if _is_remote; then
  # curl | bash 模式：从 GitHub 拉取源文件
  if ! _require_cmd curl; then
    echo "luo: 需要 curl，但未找到" >&2; exit 1
  fi
  echo "正在从 GitHub 下载 luo.zsh …"
  curl -fsSL "$GITHUB_RAW/luo.zsh"             -o "$DEST/luo.zsh"
  curl -fsSL "$GITHUB_RAW/registry.tsv.example" -o "$DEST/registry.tsv.example"
  if [[ ! -f "$DEST/registry.tsv" ]]; then
    cp "$DEST/registry.tsv.example" "$DEST/registry.tsv"
  fi
else
  # 本地克隆模式
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cp "$ROOT/luo.zsh" "$DEST/luo.zsh"
  chmod a+r "$DEST/luo.zsh"
  if [[ ! -f "$DEST/registry.tsv" ]]; then
    cp "$ROOT/registry.tsv.example" "$DEST/registry.tsv"
    chmod a+r "$DEST/registry.tsv"
  fi
fi

# ── 写入 ~/.zshrc ────────────────────────────────────────────────────────────
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
[[ -f "$ZSHRC" ]] || touch "$ZSHRC"

if grep -qF "$MARK_BEGIN" "$ZSHRC" 2>/dev/null; then
  echo "已检测到 ~/.zshrc 中的 luo 配置块，跳过写入。"
else
  {
    printf '\n%s\n' "$MARK_BEGIN"
    # 仅当用户指定了非默认路径时，才写 export LUO_HOME
    if [[ "$DEST" != "$HOME/.luo" ]]; then
      printf 'export LUO_HOME=%q\n' "$DEST"
    fi
    printf '[ -f %q ] && source %q\n' "$DEST/luo.zsh" "$DEST/luo.zsh"
    printf '%s\n' "$MARK_END"
  } >>"$ZSHRC"
  echo "已将 luo 写入: ${ZSHRC}（新开终端自动生效）"
fi

# ── 安装完成提示 ──────────────────────────────────────────────────────────────
cat <<EOF

✅  luo 已安装到 $DEST

▶  在当前终端立刻激活（或新开一个终端）：
     source "$DEST/luo.zsh"

▶  快速上手：
     luo add "caffeinate -di"    # 登记一条 shell 命令
     luo help                    # fzf 选命令填入命令行
     luo add ./你的脚本.sh       # 登记一个脚本

EOF
