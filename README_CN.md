# CmdRoster 中文说明

**CmdRoster** 是一个面向 **macOS zsh** 的个人命令与脚本管理工具。把常用的 shell 片段或脚本登记一次，之后随时用 **fzf** 交互搜索，回车后命令直接出现在命令行上，确认无误再按 Enter 执行。

命令行工具名叫 **`luo`**（三个字母，好打）。数据默认存放在 **`~/.luo/`**（可通过 `LUO_HOME` 自定义）。

> English documentation: [README.md](README.md)

## 依赖

| 工具 | 安装方式 |
|------|---------|
| zsh | macOS 自带 |
| [fzf](https://github.com/junegunn/fzf) | `brew install fzf` |

## 安装

### 一行命令安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/install.sh | bash
```

安装脚本会自动检测 fzf，若未安装会询问是否通过 Homebrew 安装。

### 克隆后安装

```bash
git clone https://github.com/wuluoluoda/cmdroster.git
cd cmdroster
./install.sh
```

安装完成后，在**当前终端**执行一行激活（新开终端会从 `~/.zshrc` 自动加载）：

```bash
source ~/.luo/luo.zsh
```

### 自定义安装目录

```bash
LUO_HOME=~/my-tools ./install.sh
```

若 `LUO_HOME` 不是默认的 `~/.luo`，安装脚本会在 `~/.zshrc` 里写入 `export LUO_HOME=…`。

## 快速上手

```bash
# 登记一条 shell 命令
luo add "caffeinate -di"

# 登记一个脚本（在 ~/.luo/scripts/ 下建软链接）
luo add ./my-script.sh

# 给条目起一个好记的名字
luo add -n wake "caffeinate -di"

# 打开交互选择菜单，回车后命令出现在命令行
luo help

# 设置一个更短的快捷命令（例如 ql），以后直接 ql 即可
luo alias ql
ql
```

## 命令一览

| 命令 | 说明 |
|------|------|
| `luo help` | fzf 交互菜单（字母序）；**Tab** 用当前名称缩小搜索范围；**Enter** 把命令填到命令行（可编辑后再回车执行）；**Fn+F2** 切换删除模式（绿色界面，Enter 直接删当前项）；**Ctrl+N** / **Esc** 退出 |
| `luo add [选项] …` | 登记命令或脚本（见下文） |
| `luo list` | 打印全部条目（带表头的 TSV） |
| `luo sync [-p]` | 扫描 `scripts/` 补全缺失条目；`-p` 同时清理失效行 |
| `luo rm` / `luo remove` | 等同于 `luo help` 但直接进入删除模式 |
| `luo alias [名字]` | 设置 / 查看 / 取消 `luo help` 的快捷命令（见下文） |
| `luo home` | 打印当前 `LUO_HOME` |

### luo add 选项

| 选项 | 说明 |
|------|------|
| `-n <名称>` | 自定义显示名称（默认取命令的第一个词或脚本的文件名） |
| `-d <简介>` | 自定义简介（脚本文件内可写 `# luo:desc …` 自动读取） |
| `-f` | 强制覆盖同名条目 |

**自动判定规则**：参数含 `/` 或以 `./` `../` 开头且文件存在 → 按**脚本**处理，在 `~/.luo/scripts/` 下建软链接；否则整段字符串视为 **shell 命令**。

```bash
luo add "npm run dev"               # shell 命令
luo add -n dev "npm run dev"        # 自定义名称
luo add ./build.sh                  # 脚本（建软链接）
luo add ~/bin/deploy.sh             # 绝对路径脚本
luo add -f "npm run dev"            # 强制覆盖同名条目
```

### luo alias — 设置快捷命令

不想每次输 `luo help`？给它起个任意不冲突的短名字：

```bash
luo alias ql        # 把 "ql" 设为 luo help 的快捷方式
ql                  # 直接打开交互菜单

luo alias           # 查看当前设置的快捷命令
luo alias off       # 取消快捷命令
```

快捷命令名保存在 `~/.luo/alias`，每次 `source luo.zsh` 时自动读取并定义对应函数，**新开终端无需任何额外操作**。改名时旧函数自动清理，不会残留。

> **注意**：若命令名与系统命令冲突，会警告并要求确认后再设置。

### luo help 如何把命令填到命令行

选中后，命令通过 `print -z` 写入 **ZLE 行编辑缓冲**（在 `precmd` 钩子里调用，确保 fzf 已彻底退出、终端状态已还原）。命令出现在提示符后，你可以修改，确认无误再按 **Enter** 执行。

### 删除模式

在 `luo help` 界面按 **Fn+F2**（Mac 笔记本 F 行默认为媒体键，需 Fn）进入绿色的删除模式：

- **Enter** — 删除当前选中条目（`kind=file` 时同时删除 `scripts/` 下的软链接）
- 使用次数 **> 30** 的条目删除前会提示确认
- 再按 **Fn+F2** 退出删除模式，回到普通模式

也可直接 `luo rm` 打开菜单并自动进入删除模式。

## 目录结构

```
~/.luo/
├── luo.zsh          # 主逻辑（由 install.sh 安装/更新）
├── registry.tsv     # 条目数据库（制表符分隔，UTF-8）
├── usage.tsv        # 各条目使用次数（超过 30 次删除时提示确认）
├── alias            # 快捷命令名（一行纯文本，由 luo alias 写入）
└── scripts/         # 已登记脚本的软链接目录
```

注册表列：`name`、`description`、`kind`（`shell` | `file`）、`payload`。

## Tab 补全

`luo.zsh` 用 `compdef _luo_cmd_complete luo` 注册补全。需确保 `~/.zshrc` 中 **`compinit` 在 `source luo.zsh` 之前执行**，否则补全不生效。

## 卸载

```bash
rm -rf ~/.luo

# 同时从 ~/.zshrc 中删除以下两行标记之间的配置块：
# >>> luo script hub
# <<< luo script hub
```

## License

MIT — 详见 [LICENSE](LICENSE)。
