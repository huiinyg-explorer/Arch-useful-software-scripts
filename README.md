# Arch-useful-software-scripts

交互式 Arch 软件安装器，基于 `fzf` 做选择界面、`yay` 作为唯一安装工具（同时处理官方仓库与 AUR）。支持分组显示、彩色渲染、包说明预览与编辑（Ctrl-E）、日志与错误报告。

主要特点
- 所有软件通过 `yay` 安装（若系统缺少 `yay`，可选择自动从 AUR 构建并安装）。
- fzf 多选交互界面，显示组别与软件名称（组别着色）。
- 本地 descriptions/ 支持：在界面按 Ctrl-E 编辑单个包的用途说明，右侧预览显示该说明。
- 自动生成描述模板（首次遇到包时会生成 descriptions/<pkg>.md）。
- 日志记录与运行汇总（默认保存在 $XDG_STATE_HOME 或 ~/.local/state）。
- 支持 dry-run 与按包逐个安装并记录失败项。

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
