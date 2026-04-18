# CmdRoster (luo)

> A command-line & script hub for your terminal — register any shell command or script once, then recall it instantly with fuzzy search.

[中文文档](README_CN.md)

## Platform support

| Platform | Shell | Version |
|----------|-------|---------|
| macOS | **zsh** | `zsh/` |
| Linux (native) | **zsh** | `zsh/` |
| Windows (WSL 2) | **zsh** | `zsh/` |
| Windows (PowerShell) | **pwsh** | `pwsh/` |
| Linux / macOS (PowerShell Core) | **pwsh** | `pwsh/` |

The repo ships **two independent versions** under `zsh/` and `pwsh/`.  
They share the same TSV registry format so you can keep one `~/.luo/` folder across both shells.

---

## Install — macOS / Linux / WSL 2 (zsh)

### One-liner (no clone needed)

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh/install.sh | bash
```

The installer auto-detects the OS and installs **fzf** if missing  
(`brew` on macOS · `apt-get / pacman / dnf / yum` on Linux / WSL 2).

### After cloning

```bash
git clone https://github.com/wuluoluoda/cmdroster.git
cd cmdroster
./zsh/install.sh
```

Activate in the **current** terminal (new shells load from `~/.zshrc` automatically):

```bash
source ~/.luo/luo.zsh
```

### WSL 2 — first-time setup

```powershell
# In PowerShell (Admin) — install WSL 2 with Ubuntu
wsl --install
```

```bash
# In Ubuntu terminal
sudo apt-get update && sudo apt-get install -y zsh fzf
chsh -s $(which zsh)   # set zsh as default shell
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh/install.sh | bash
```

---

## Install — Windows / cross-platform (PowerShell)

Requires **PowerShell 5.1+** (Windows built-in) or **PowerShell Core 7+** (cross-platform).

### One-liner — Windows (no clone needed)

```powershell
irm https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | iex
```

### One-liner — Linux / macOS with pwsh (no clone needed)

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | pwsh
```

### After cloning

```powershell
git clone https://github.com/wuluoluoda/cmdroster.git
cd cmdroster
./pwsh/install.ps1
```

The installer auto-installs **fzf** if missing  
(`winget → scoop → choco` on Windows · `brew` on macOS · `apt-get / pacman / dnf` on Linux).

Activate in the **current** session (new sessions load from `$PROFILE` automatically):

```powershell
. "$HOME/.luo/luo.ps1"
```

---

## Quick start

```bash
luo add "ping -c 4 google.com"   # register a shell command
luo add ./deploy.sh               # register a local script
luo help                          # fzf picker → Enter puts it on the command line
luo alias ql                      # set 'ql' as a short alias for luo help
```

PowerShell bonus: press **Ctrl+Shift+L** to open the picker directly in the readline buffer.

---

## Commands

| Command | Description |
|---------|-------------|
| `luo help` | Interactive fuzzy picker (fzf). Enter puts the command on the command line. |
| `luo list` | Print all registered entries. |
| `luo add [-n name] [-d desc] [-f] <text>` | Register a shell command or script path. |
| `luo sync [-p]` | Scan `scripts/` and fill missing entries; `-p` removes stale file entries. |
| `luo rm` / `luo remove` | Open picker in **delete mode** (green). Enter deletes the selected entry. |
| `luo alias [name]` | Set a short alias for `luo help`; `luo alias off` to remove. |
| `luo home` | Print `LUO_HOME`. |

### Delete mode

Press **Fn+F2** (zsh) or **F2** (pwsh) inside the picker to toggle delete mode (green UI).  
Entries used more than 30 times prompt for confirmation before deletion.

### luo alias — short alias for luo help

```bash
luo alias ql       # create 'ql' → calls luo help
ql                 # same as luo help
luo alias          # show current alias
luo alias off      # remove alias
```

The alias name is saved to `~/.luo/alias` and reloaded on every new shell.

### How luo help puts a command on the command line

**zsh version**: uses a `precmd` hook so `print -z` runs after fzf exits and the terminal state is clean.

**pwsh version**: wraps the `prompt` function for one tick so `PSConsoleReadLine::Insert()` fires when PSReadLine is ready. The key binding `Ctrl+Shift+L` always works inline.

---

## Custom install directory

```bash
LUO_HOME=~/my-luo ./zsh/install.sh     # zsh
LUO_HOME=~/my-luo ./pwsh/install.ps1   # pwsh
```

---

## Repository layout

```
cmdroster/
├── zsh/
│   ├── luo.zsh            # zsh version (macOS / Linux / WSL 2)
│   ├── install.sh         # bash installer
│   └── registry.tsv.example
├── pwsh/
│   ├── luo.ps1            # PowerShell version (Windows / Linux / macOS)
│   ├── install.ps1        # PowerShell installer
│   └── registry.tsv.example
├── README.md
├── README_CN.md
└── LICENSE

~/.luo/                    # default LUO_HOME (shared between zsh & pwsh)
├── luo.zsh  or  luo.ps1
├── registry.tsv           # name / description / kind / payload
├── usage.tsv              # pick count per entry
├── alias                  # current alias name
└── scripts/               # managed scripts / symlinks
```

---

## License

MIT © [wuluoluoda](https://github.com/wuluoluoda)
