# STermux

> Android Termux 上的 SillyTavern 安装、更新与管理工具。

**打开 Termux，剩下的交给菜单。**

STermux 希望让 Android 手机上的 SillyTavern 使用体验更简单。

无需反复输入 Git 命令，也无需手动寻找酒馆数据进行备份。通过统一的终端菜单，你可以完成 SillyTavern 的安装、启动、更新、酒馆扩展管理、备份恢复和 STermux 自更新。

> 当前版本：v0.0.1  
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