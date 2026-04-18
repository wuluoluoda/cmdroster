# CmdRoster

**CmdRoster** is a small **command-line and script management** tool for **zsh on macOS**. Register shell snippets or scripts once, then pick them with **fzf** — the chosen command is appended to your **zsh history** (and thus `HISTFILE` when enabled). Press **↑** (previous line) or **Ctrl+R** to recall it; nothing is executed until you press **Enter**.

The interactive command is still named **`luo`** (three letters, easy to type). Data lives under **`~/.luo/`** by default (`LUO_HOME`).

## Requirements

| Tool | Install |
|------|---------|
| zsh | Built into macOS |
| [fzf](https://github.com/junegunn/fzf) | `brew install fzf` |

## Install

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/install.sh | bash
```

The installer can offer to install **fzf** via Homebrew if it is missing.

### Clone and install

```bash
git clone https://github.com/wuluoluoda/cmdroster.git
cd cmdroster
./install.sh
```

Then activate in the **current** terminal (new shells load it from `~/.zshrc` automatically):

```bash
source ~/.luo/luo.zsh
```

### Custom install directory

```bash
LUO_HOME=~/my-tools ./install.sh
```

If `LUO_HOME` is not the default `~/.luo`, the installer adds `export LUO_HOME=…` to your `~/.zshrc`.

## Quick start

```bash
luo add "caffeinate -di"       # register a shell command
luo add ./my-script.sh         # register a script (symlink under ~/.luo/scripts/)
luo add -n wake "caffeinate -di"   # custom name
luo help                       # fuzzy-find; Enter appends choice to history (↑ to recall)
```

In `luo help`, press **Fn+F2** to toggle **delete mode** (green UI). In delete mode, **Enter** removes the selected entry. Press **Fn+F2** again to leave delete mode.

### How `luo help` applies your choice

Picking uses zsh **`print -s`**: the command becomes the **latest history event** in memory and is written to **`HISTFILE`** according to your options (`INC_APPEND_HISTORY`, `SHARE_HISTORY`, etc.). This avoids `print -z` / ZLE quirks across terminals.

## Commands

| Command | Description |
|---------|-------------|
| `luo help` | fzf UI (sorted by name); **Tab** fills the query with the current name; **Enter** appends the command to **zsh history** (↑ / Ctrl+R to recall); **Fn+F2** toggles delete mode; **Ctrl+N** / **Esc** quit |
| `luo add [options] …` | Register a command or script (see below) |
| `luo list` | Print the registry (TSV with header) |
| `luo sync [-p]` | Merge missing `scripts/` entries; `-p` prunes stale `file` rows |
| `luo rm` / `luo remove` | Same as `luo help` but starts in delete mode |
| `luo home` | Print `LUO_HOME` |

### `luo add` options

| Option | Meaning |
|--------|---------|
| `-n <name>` | Display name (default: first word of command, or script basename) |
| `-d <desc>` | Description (scripts can use `# luo:desc …` in the file) |
| `-f` | Overwrite an existing name |

**Heuristic**: if the argument looks like a path (`/` or `./` / `../`) and resolves to a regular file → **file** entry with a symlink under `~/.luo/scripts/`. Otherwise the whole string is stored as a **shell** command.

## Layout

```
~/.luo/
├── luo.zsh          # logic (copied or downloaded by install.sh)
├── registry.tsv     # entries (tab-separated UTF-8)
├── usage.tsv        # per-name usage counts (for delete confirmation)
└── scripts/         # symlinks to registered scripts
```

Registry columns: `name`, `description`, `kind` (`shell` | `file`), `payload`.

## Completion

`luo.zsh` registers `_luo_cmd_complete` with `compdef`. Run **`compinit` before sourcing `luo.zsh`** in `~/.zshrc` so completion works.

## Uninstall

```bash
rm -rf ~/.luo
# Remove the marked block from ~/.zshrc between:
# >>> luo script hub
# <<< luo script hub
```

## License

MIT — see [LICENSE](LICENSE).
