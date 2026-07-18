# STermux

> Android Termux 上的 SillyTavern 安装、更新与管理工具。

**打开 Termux，剩下的交给菜单。**

STermux 希望让 Android 手机上的 SillyTavern 使用体验更简单。

无需反复输入 Git 命令，也无需手动寻找酒馆数据进行备份。通过统一的终端菜单，你可以完成 SillyTavern 的安装、启动、更新、酒馆扩展管理、备份恢复和 STermux 自更新。

> 当前版本：v0.0.2
> 当前阶段：早期测试版


## 快速开始

首次使用时，打开 Termux，复制并执行：

```
pkg update && pkg install -y git && git clone https://github.com/dreamdana88/STermux.git ~/STermux && cd ~/STermux && bash manager.sh
```

进入 STermux 后，按照菜单提示即可安装新的SillyTavern，或管理设备上已有的SillyTavern。

以后手动启动 STermux：
```
cd ~/STermux && bash manager.sh
```

也可以在 STermux 的「设置」中开启 自启动脚本，之后打开 Termux 即可直接进入管理菜单。

## 自动备份

进入「备份与恢复 → 自动备份设置」可以开启轻量定时备份、设置每 1–30 天的备份频率，以及调整自动备份池最大数量。自动备份默认关闭；开启后，STermux 每次启动时检查一次计划，不需要 cron、Termux:API、Termux:Boot 或常驻后台服务。

计划到期时创建“计划备份”；长时间未打开 STermux 时，下次启动只补做一份“补做备份”。保护备份、计划备份和补做备份继续共用自动备份池，手动备份不计入上限且不会被自动清理。
