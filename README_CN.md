# CmdRoster (luo)

> 命令行 & 脚本管理工具——把任意 shell 命令或脚本注册一次，随时通过模糊搜索秒找秒用。

[English](README.md)

## 平台支持

| 平台 | Shell | 对应版本 |
|------|-------|---------|
| macOS | **zsh** | `zsh/` |
| Linux（原生） | **zsh** | `zsh/` |
| Windows（WSL 2） | **zsh** | `zsh/` |
| Windows（PowerShell） | **pwsh** | `pwsh/` |
| Linux / macOS（PowerShell Core） | **pwsh** | `pwsh/` |

仓库提供 **两个独立版本**，分别位于 `zsh/` 和 `pwsh/` 目录。  
两个版本共用相同的 TSV registry 格式，可共享同一个 `~/.luo/` 数据目录。

---

## 安装 — macOS / Linux / WSL 2（zsh 版）

### 一行命令安装（无需克隆仓库）

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh/install.sh | bash
```

安装脚本自动检测系统并安装 **fzf**（macOS 用 `brew`，Linux/WSL 用 `apt-get / pacman / dnf / yum`）。

### 克隆后安装

```bash
git clone https://github.com/wuluoluoda/cmdroster.git
cd cmdroster
./zsh/install.sh
```

安装完成后，在**当前终端**执行以下命令立刻激活（新终端会从 `~/.zshrc` 自动加载）：

```bash
source ~/.luo/luo.zsh
```

### WSL 2 初次安装

```powershell
# PowerShell（管理员）——安装 WSL 2 + Ubuntu
wsl --install
```

```bash
# Ubuntu 终端中
sudo apt-get update && sudo apt-get install -y zsh fzf
chsh -s $(which zsh)   # 把 zsh 设为默认 Shell
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh/install.sh | bash
```

---

## 安装 — Windows / 跨平台（PowerShell 版）

需要 **Windows PowerShell 5.1+**（Windows 内置）或 **PowerShell Core 7+**（跨平台）。

### 一行命令安装 — Windows（无需克隆仓库）

```powershell
irm https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | iex
```

### 一行命令安装 — Linux / macOS（已安装 pwsh）

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | pwsh
```

### 克隆后安装

```powershell
git clone https://github.com/wuluoluoda/cmdroster.git
cd cmdroster
./pwsh/install.ps1
```

安装脚本自动安装 **fzf**（Windows 依次尝试 `winget → scoop → choco`，macOS 用 `brew`，Linux 用 `apt-get / pacman / dnf`）。

安装完成后，在**当前会话**执行以下命令立刻激活（新终端会从 `$PROFILE` 自动加载）：

```powershell
. "$HOME/.luo/luo.ps1"
```

---

## 快速上手

```bash
luo add "ping -c 4 google.com"   # 登记一条 shell 命令
luo add ./deploy.sh               # 登记一个本地脚本
luo help                          # fzf 选命令，Enter 后命令出现在命令行
luo alias ql                      # 把 ql 设为 luo help 的快捷方式
```

PowerShell 版专属：按 **Ctrl+Shift+L** 直接弹出 fzf，选中后命令直接注入命令行（最佳体验）。

---

## 命令一览

| 命令 | 说明 |
|------|------|
| `luo help` | 交互式模糊选择（fzf），Enter 将命令放到命令行 |
| `luo list` | 打印所有已登记的条目 |
| `luo add [-n 名称] [-d 简介] [-f] <文本>` | 登记一条 shell 命令或脚本路径 |
| `luo sync [-p]` | 扫描 `scripts/` 补全缺失条目；`-p` 删除失效的 file 条目 |
| `luo rm` / `luo remove` | 直接进入**删除模式**（绿色界面），Enter 删除选中条目 |
| `luo alias [名字]` | 设置 `luo help` 的快捷命令；`luo alias off` 取消 |
| `luo home` | 打印 `LUO_HOME` |

### 删除模式

在 fzf 界面按 **Fn+F2**（zsh 版）或 **F2**（pwsh 版）切换删除模式（绿色界面）。  
已使用超过 30 次的条目删除前会交互确认。

### luo alias — luo help 的快捷方式

```bash
luo alias ql       # 把 ql 设为 luo help 的快捷命令
ql                 # 等同于 luo help
luo alias          # 查看当前快捷命令
luo alias off      # 取消快捷命令
```

别名名称保存在 `~/.luo/alias`，每次新开终端自动加载。

### luo help 如何把命令放到命令行

**zsh 版**：借助 `precmd` 钩子，fzf 退出后终端状态还原完毕时再执行 `print -z`，稳定可靠。

**pwsh 版**：在 prompt 函数中包装一帧，让 `PSConsoleReadLine::Insert()` 在 PSReadLine 就绪时触发。快捷键 `Ctrl+Shift+L` 始终稳定注入。

---

## 自定义安装目录

```bash
LUO_HOME=~/my-luo ./zsh/install.sh     # zsh 版
LUO_HOME=~/my-luo ./pwsh/install.ps1   # pwsh 版
```

---

## 目录结构

```
cmdroster/
├── zsh/
│   ├── luo.zsh            # zsh 版（macOS / Linux / WSL 2）
│   ├── install.sh         # bash 安装脚本
│   └── registry.tsv.example
├── pwsh/
│   ├── luo.ps1            # PowerShell 版（Windows / Linux / macOS）
│   ├── install.ps1        # PowerShell 安装脚本
│   └── registry.tsv.example
├── README.md
├── README_CN.md
└── LICENSE

~/.luo/                    # 默认 LUO_HOME（zsh 与 pwsh 可共用）
├── luo.zsh  或  luo.ps1
├── registry.tsv           # name / description / kind / payload
├── usage.tsv              # 每条命令的使用次数
├── alias                  # 当前快捷命令名
└── scripts/               # 托管的脚本与符号链接
```

---

## 许可证

MIT © [wuluoluoda](https://github.com/wuluoluoda)
