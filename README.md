# Arch-useful-software-scripts

[![](scrshot)](https://raw.githubusercontent.com/huiinyg-explorer/Arch-useful-software-scripts/refs/heads/main/Screenshots/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE_20260206_193934.png)

交互式 Arch 软件安装器，基于 `fzf` 做选择界面、`yay` 作为唯一安装工具（同时处理官方仓库与 AUR）。支持分组显示、彩色渲染、包说明预览与编辑（Ctrl-E）、日志与错误报告。本脚本供每个新（或旧的）的**Archlinux**安装一些软件，但这个脚本只是一个不带推荐软件列表的外壳而已（也还在**测试**中）。当然，在本项目的packages文件夹（也可能是分支）下放着一些默认推荐的软件列表，每一组推荐软件名称都放在后缀为.list的文件了。另一个文件夹装着这些软件的描述文档（截止目前这些描述文件还没有写完），后缀是.md，命名格式是 软件包名称加.md（空格用下划线代替） 。**需要注意的是，这两个文件夹脚本的同一目录下**。你可以自己做一份推荐软件列表，或者下载别人做的，这给了像我这样想不起来需要装哪些软件的人很大便利。我目前正在写一份推荐软件清单，可能要久一点


主要特点
- 所有软件通过 `yay` 安装（若系统缺少 `yay`，可选择自动从 AUR 构建并安装）。
- fzf 多选交互界面，显示组别与软件名称（组别着色）。
- 本地 descriptions/ 支持：在界面按 Ctrl-E 编辑单个包的用途说明，右侧预览显示该说明。
- 自动生成描述模板（首次遇到包时会生成 descriptions/<pkg>.md）。
- 日志记录与运行汇总（默认保存在 $XDG_STATE_HOME 或 ~/.local/state）。
- 支持 dry-run 与按包逐个安装并记录失败项。
-*This repository contains an interactive Arch Linux package installer using fzf + yay. The project was created with assistance from an AI (ChatGPT).*

快速开始
````bash
# 1. 克隆或创建仓库目录，然后把文件放入
git init
git add .
git commit -m "Initial import: interactive Arch installer (AI-assisted)"

# 2. 安装依赖（示例）
sudo pacman -Syu fzf git base-devel

# 3. 使脚本可执行并运行 dry-run（先测试）
chmod +x interactive-arch-installer-yay-only_with_logging_fixed.sh
./interactive-arch-installer-yay-only_with_logging_fixed.sh ./packages --dry-run

# 4. 真正运行（脚本会在缺少 yay 时提示并可以自动安装）
./interactive-arch-installer-yay-only_with_logging_fixed.sh ./packages
