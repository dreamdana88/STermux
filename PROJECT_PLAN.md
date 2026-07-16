# ST-Manager-Termux 项目计划

> 终端显示名：**STermux**  
> 项目类型：Android Termux 下的 SillyTavern 管理器  
> 主要语言：Bash  
> 开发方式：Codex 分阶段实施，Android Termux 实机验证  
> 当前目标：优先满足个人长期稳定使用，同时保留未来模块接入能力

---

## 1. 项目背景

Android 端 SillyTavern 通常通过 Termux 安装、运行和维护。

现有第三方脚本可以完成安装、启动、更新、备份或附加工具管理，但长期使用存在以下问题：

1. 部分项目停止维护，更新逻辑会随 SillyTavern 上游变化逐渐失效。
2. 不同脚本分别负责启动、备份或其他功能，需要退出一个脚本后再手动进入另一个脚本。
3. 缺少统一的 SillyTavern 更新、版本回退、数据备份和第三方扩展更新入口。
4. 第三方扩展通常需要进入 SillyTavern 后逐个检查和更新，更新后常常还需要重新刷新或重启。
5. 用户并不希望所有第三方扩展永远同步到最新版本，需要支持按需选择更新。
6. 用户曾发生聊天记录意外丢失，因此需要长期、自动、可验证的数据备份机制。
7. 未来可能继续接入其他 Termux 工具，需要保留轻量、清晰的模块接口。

因此开发：

```text
ST-Manager-Termux
```

终端显示名：

```text
STermux
```

项目定位：

> 一个面向 Android Termux 的模块化 SillyTavern 管理器，用于统一完成启动、更新、扩展管理、备份、恢复、版本回退和未来外部工具接入。

---

# 2. 核心设计目标

## 2.1 SillyTavern 统一管理

支持：

```text
安装
启动
检查更新
执行更新
查看当前分支
查看当前 Commit
查看更新历史
版本回退
```

用户无需频繁手动进入 SillyTavern 目录执行 Git 或 Node 命令。

---

## 2.2 数据安全优先

备份系统必须作为项目核心能力。

需要支持四类备份来源：

```text
1. scheduled
   定时自动备份

2. protective
   更新、回退等重要操作前的保护备份

3. manual
   用户主动创建的手动备份

4. catchup
   定时备份逾期后的补偿备份
```

程序版本与用户数据分开管理：

```text
程序代码
→ Git 管理

用户数据
→ 独立备份系统管理
```

允许用户：

```text
只回退 SillyTavern 程序版本
```

也允许：

```text
回退程序版本
+
单独恢复指定数据备份
```

两类操作互不强制绑定。

---

## 2.3 第三方扩展统一管理

默认扫描目录：

```text
SillyTavern/
└── public/
    └── scripts/
        └── extensions/
            └── third-party/
```

第三方扩展管理必须支持：

```text
扫描全部扩展
识别 Git 仓库
检查远程更新
显示更新状态
显示可更新数量
选择一个或多个扩展更新
一键更新全部允许自动更新的扩展
单独查看扩展状态
设置“仅手动更新”
重新检测
```

第一版无需实现：

```text
插件代码安全审查
恶意仓库检测
复杂本地修改保护
重复实现 SillyTavern 已具备的安全提示
```

扩展更新逻辑以简单、透明、可靠为优先。

---

## 2.4 模块化与可扩展性

未来可能接入：

```text
ClewdR
gcli2api
GPT-SoVITS 相关工具
其他本地 API 工具
未来个人常用工具
```

核心程序只负责：

```text
程序入口
菜单
配置
公共 Git 工具
公共备份工具
模块加载
公共 UI
公共状态管理
```

具体业务功能放入独立模块。

---

# 3. 理想使用体验

用户打开 Termux：

```text
打开 Termux
    ↓
进入 STermux
    ↓
显示主菜单
```

主菜单建议：

```text
╔══════════════════════════════════╗
║              STermux             ║
║      仅发布在外神们茶话会社区      ║
╠══════════════════════════════════╣
║ 1. 启动 SillyTavern              ║
║ 2. 更新中心                      ║
║ 3. 备份与恢复                    ║
║ 4. 版本管理                      ║
║ 5. 模块管理                      ║
║ 6. 设置                          ║
║ 0. 退出                          ║
╚══════════════════════════════════╝
```

可选状态摘要：

```text
SillyTavern：已安装
本体更新：1
扩展更新：4
最近成功备份：6 小时前
定时备份：已开启
```

状态摘要不得阻塞启动。

即使网络不可用，用户仍然必须能够：

```text
启动 SillyTavern
查看本地备份
恢复本地备份
查看本地版本信息
```

---

# 4. V1 核心功能范围

V1 优先完成：

```text
基础菜单
配置系统
SillyTavern 路径检测
启动 SillyTavern

检测 SillyTavern 更新
更新 SillyTavern
记录更新历史

扫描第三方扩展
检测扩展更新
选择性更新
批量更新
仅手动更新策略

手动备份
保护备份
定时自动备份
逾期补偿备份
备份列表
备份恢复
备份保留策略
备份健康状态

Git 版本回退

基础模块加载系统
安装器
Termux 自动进入功能
```

暂不进入 V1：

```text
复杂 GUI
Web 管理后台
云端备份
插件市场
复杂插件安全扫描
SillyTavern 内部配置编辑器
GitHub 账号管理
任意第三方扩展自动安装器
复杂模块市场
```

---

# 5. 推荐目录结构

```text
ST-Manager-Termux/
│
├── manager.sh
├── install.sh
├── uninstall.sh
│
├── core/
│   ├── config.sh
│   ├── ui.sh
│   ├── utils.sh
│   ├── git.sh
│   ├── backup.sh
│   ├── scheduler.sh
│   ├── state.sh
│   └── module_loader.sh
│
├── modules/
│   ├── sillytavern/
│   │   ├── module.conf
│   │   ├── main.sh
│   │   ├── install.sh
│   │   ├── launch.sh
│   │   ├── update.sh
│   │   ├── extensions.sh
│   │   ├── version.sh
│   │   └── backup_rules.sh
│   │
│   └── example/
│       ├── module.conf
│       └── main.sh
│
├── config/
│   ├── default.conf
│   ├── user.conf
│   └── extension-policy.conf
│
├── data/
│   ├── state/
│   ├── cache/
│   └── logs/
│
├── backups/
│   └── sillytavern/
│
├── scripts/
│   └── scheduled-backup.sh
│
├── docs/
│   ├── MODULE_GUIDE.md
│   ├── BACKUP_DESIGN.md
│   └── TESTING.md
│
├── PROJECT_PLAN.md
└── README.md
```

说明：

- `manager.sh` 只作为入口和流程控制。
- `core/` 放公共能力。
- `modules/` 放具体工具模块。
- `config/` 放默认配置、用户配置和扩展更新策略。
- `data/` 放运行状态、缓存和日志。
- `backups/` 放备份数据。
- `scripts/` 放可被后台调度器独立调用的脚本。

---

# 6. 核心程序职责

`manager.sh` 负责：

```text
初始化环境
加载默认配置
加载用户配置
加载公共函数
加载模块
检查必要运行状态
显示主菜单
调用对应模块功能
```

禁止把 SillyTavern 的全部业务逻辑堆入 `manager.sh`。

---

# 7. 配置系统

建议使用：

```text
config/default.conf
config/user.conf
config/extension-policy.conf
```

`default.conf`：

```bash
ST_PATH="$HOME/SillyTavern"

AUTO_BACKUP_BEFORE_UPDATE=true
AUTO_BACKUP_BEFORE_ROLLBACK=true

SCHEDULED_BACKUP_ENABLED=false
SCHEDULED_BACKUP_INTERVAL="daily"
SCHEDULED_BACKUP_TIME="03:00"

SCHEDULED_BACKUP_KEEP=7
PROTECTIVE_BACKUP_KEEP=5

CHECK_ST_UPDATE_ON_START=false
CHECK_EXTENSION_UPDATE_ON_START=false

AUTO_ENTER_MANAGER=true

GITHUB_PROXY=""
```

`user.conf` 覆盖默认配置。

所有脚本必须通过统一配置加载器读取配置。

禁止在多个文件中分别写死 SillyTavern 路径、备份目录或第三方扩展目录。

---

# 8. SillyTavern 路径检测

检测顺序：

```text
读取 ST_PATH
    ↓
检查目录存在
    ↓
检查是否为有效 SillyTavern 安装
```

若无效：

```text
尝试常见路径
```

例如：

```text
$HOME/SillyTavern
```

仍未找到：

```text
提示用户输入路径
    ↓
验证
    ↓
保存到 user.conf
```

有效安装判断必须基于当前实际安装结构中的稳定特征文件。

实施阶段需要先检查真实 SillyTavern 目录，再确定最终验证规则。

---

# 9. SillyTavern 启动

主菜单第一项：

```text
启动 SillyTavern
```

启动流程：

```text
验证 ST_PATH
    ↓
进入 SillyTavern 目录
    ↓
调用当前适用的官方启动方式
```

启动功能不得强制依赖网络。

启动前更新检查必须为可选功能。

用户始终可以直接启动。

---

# 10. SillyTavern 更新系统

更新中心显示：

```text
SillyTavern

当前分支：
当前 Commit：
远程状态：
是否有更新：
```

更新流程：

```text
验证 SillyTavern 路径
    ↓
确认 Git 仓库状态
    ↓
获取当前 Commit
    ↓
获取当前分支
    ↓
检查远程更新
    ↓
提示用户确认
    ↓
按配置创建 protective 保护备份
    ↓
记录更新前 Commit
    ↓
执行 Git 更新
    ↓
执行必要的依赖同步
    ↓
记录更新后 Commit
    ↓
记录结果
```

更新命令必须在实现阶段根据当前 SillyTavern 官方推荐方式确认。

不得长期硬编码已经过时的上游更新流程。

更新记录：

```text
data/state/update-history.log
```

每次至少记录：

```text
时间
更新前 Commit
更新后 Commit
分支
执行结果
错误摘要
```

---

# 11. 更新中心

建议界面：

```text
更新中心

SillyTavern
状态：有更新

第三方扩展
已识别：12
可更新：4
仅手动更新：2

1. 更新 SillyTavern
2. 管理第三方扩展更新
3. 更新全部允许自动更新的项目
4. 重新检测
5. 查看更新历史
0. 返回
```

“一键更新全部”必须尊重扩展更新策略。

设置为“仅手动更新”的扩展不得被自动批量更新。

---

# 12. 第三方扩展扫描

默认目录：

```bash
$ST_PATH/public/scripts/extensions/third-party
```

扫描规则：

```text
遍历一级子目录
    ↓
存在 .git
    → 识别为 Git 管理扩展

不存在 .git
    → 标记为非 Git 安装
```

非 Git 安装的扩展：

```text
显示
跳过自动更新
不报致命错误
```

扩展目录路径应通过 SillyTavern 模块统一提供。

---

# 13. 第三方扩展更新检测

每个 Git 扩展：

```text
进入扩展目录
    ↓
确认 remote
    ↓
执行 git fetch
    ↓
确定当前上游分支
    ↓
比较本地与远程 Commit
```

统一状态：

```text
latest
update_available
manual_only_update_available
fetch_failed
no_upstream
not_git
```

界面示例：

```text
✓ FayeyphoneSupport           最新
↑ JS-Slash-Runner             可更新 3 commits
◉ ShenLing-Extension          可更新，仅手动
✓ SillyTavern-Variable-Viewer 最新
! ExampleExtension            检测失败
```

---

# 14. 第三方扩展选择性更新

必须支持：

```text
1. 更新全部允许自动更新的扩展
2. 选择一个扩展更新
3. 选择多个扩展更新
4. 重新检测
5. 设置扩展为“仅手动更新”
6. 取消“仅手动更新”
7. 查看当前更新策略
```

多选输入可以支持：

```text
2 3 5
```

或：

```text
2,3,5
```

解析逻辑需要：

```text
过滤非法编号
去重
确认最终选择
```

---

# 15. 扩展更新策略

配置文件：

```text
config/extension-policy.conf
```

可以保存：

```text
TheGhostFace=manual
SomeOtherExtension=manual
```

默认策略：

```text
auto
```

支持：

```text
auto
manual
```

含义：

```text
auto
→ 参与“一键更新全部”

manual
→ 不参与“一键更新全部”
→ 仍然允许用户主动选择更新
```

第一版无需实现复杂版本锁定。

未来可考虑：

```text
固定 Commit
固定 Tag
固定分支
```

---

# 16. 第三方扩展批量更新

批量更新要求：

```text
逐个处理
单项失败隔离
不中断后续项目
记录每个结果
最后统一汇总
```

结果示例：

```text
更新完成

成功：5
失败：1
跳过：2

失败：
ExampleExtension
原因：git pull failed
```

禁止因为一个扩展失败导致整个批量任务直接退出。

---

# 17. 备份系统总设计

统一备份入口：

```bash
backup_create TYPE REASON
```

类型：

```text
scheduled
protective
manual
catchup
```

所有备份流程使用同一套核心引擎。

备份根目录：

```text
backups/
└── sillytavern/
```

单次备份：

```text
backups/
└── sillytavern/
    └── 2026-07-15_183000/
        ├── backup.tar.gz
        └── metadata.conf
```

---

# 18. 备份元数据

示例：

```bash
BACKUP_TIME="2026-07-15 18:30:00"
BACKUP_TYPE="scheduled"
BACKUP_REASON="daily-backup"

ST_COMMIT="abcdef123456"
ST_BRANCH="release"

BACKUP_STATUS="success"
BACKUP_SIZE="123456789"
```

建议附加：

```text
备份规则版本
备份内容摘要
创建工具版本
```

便于未来恢复兼容。

---

# 19. 备份内容

备份系统必须优先保护：

```text
聊天记录
角色卡
世界书
用户设置
用户上传或生成的数据
其他无法通过重新安装恢复的数据
```

具体路径必须根据当前真实 SillyTavern 数据结构确定。

Codex 在实施前必须：

```text
1. 检查当前 SillyTavern 目录
2. 确认用户数据实际存储位置
3. 区分程序源码与用户数据
4. 再编写备份规则
```

禁止凭记忆写死所有数据目录。

---

# 20. 备份类型行为

## 20.1 manual

用户主动创建。

默认永久保留。

不参与自动清理。

---

## 20.2 protective

重要操作前自动创建。

典型触发：

```text
更新 SillyTavern
重要版本回退
高风险恢复操作前
```

默认保留最近：

```text
5
```

可配置。

---

## 20.3 scheduled

后台计划任务创建。

默认频率：

```text
daily
```

默认保留最近：

```text
5
```

可配置。

---

## 20.4 catchup

发现定时备份已逾期时创建。

创建后应更新“最近成功定时备份”状态。

是否独立保留或计入 scheduled 保留数量，由实现阶段统一确定。

建议计入 scheduled 自动轮换，避免重复占用空间。

---

# 21. 定时备份

设置界面：

```text
定时备份

状态：已开启
频率：每天
计划时间：03:00
最近成功：2026-07-15 03:02
下一次计划：2026-07-16
保留数量：5
```

V1 支持：

```text
关闭
每天
每周
```

未来可扩展：

```text
每 N 天
自定义 Cron 表达式
```

---

# 22. 定时备份调度原则

定时备份需要独立脚本：

```text
scripts/scheduled-backup.sh
```

该脚本必须可以在不进入交互菜单的情况下执行。

调度层放在：

```text
core/scheduler.sh
```

要求：

```text
检测当前 Termux 环境可用的后台调度能力
注册定时任务
更新定时任务
取消定时任务
查询调度状态
```

具体采用哪一种 Termux 后台调度方案，需要在实施阶段根据当前环境、依赖和 Android 兼容性验证后决定。

不得假设后台任务永远可靠。

因此必须同时实现“逾期补偿备份”。

---

# 23. 逾期补偿备份

每次进入 STermux 时：

```text
读取最近成功 scheduled/catchup 备份时间
    ↓
读取当前计划周期
    ↓
判断是否已经逾期
```

若逾期：

```text
提示用户检测到备份逾期
    ↓
执行 catchup 补偿备份
    ↓
记录结果
    ↓
进入主菜单
```

建议允许配置：

```text
AUTO_CATCHUP_BACKUP=true
```

如果关闭自动补偿：

```text
只提示
不自动执行
```

核心目标：

> 即使 Android 后台调度偶尔失效，用户下一次进入 STermux 时也能自动发现并补做备份。

---

# 24. 备份保留策略

默认：

```text
scheduled：保留最近 7 份
protective：保留最近 5 份
manual：永久保留
```

自动清理要求：

```text
只删除明确属于可轮换类型的旧备份
绝不自动删除 manual
删除前验证目标路径位于备份根目录
禁止危险通配符误删
```

---

# 25. 备份健康状态

主菜单可以显示：

```text
最近成功备份：6 小时前
```

超过安全阈值：

```text
最近成功备份：3 天前 ⚠
```

建议配置：

```bash
BACKUP_WARNING_HOURS=24
```

备份健康状态必须基于“成功完成的备份”。

失败备份不得更新最近成功时间。

---

# 26. 备份验证

创建备份后必须验证：

```text
归档文件存在
文件大小大于 0
压缩命令返回成功
元数据写入成功
```

可选增强：

```text
测试归档可读取
生成校验值
```

只有验证通过后才记录：

```text
BACKUP_STATUS="success"
```

---

# 27. 恢复系统

流程：

```text
显示备份列表
    ↓
选择备份
    ↓
显示备份元数据
    ↓
确认恢复范围
    ↓
创建 pre-restore protective 备份
    ↓
执行恢复
    ↓
验证恢复结果
```

恢复失败时必须保留：

```text
恢复前保护备份
错误日志
```

---

# 28. Git 版本回退

版本回退仅负责 SillyTavern 程序代码。

V1 优先支持：

```text
回退上一次更新
查看最近更新记录
恢复到当前远程最新版
```

后续支持：

```text
选择历史 Commit
选择 Tag
```

回退前：

```text
显示目标 Commit
显示当前 Commit
询问确认
按配置创建 protective 备份
```

版本回退不得默认覆盖用户数据。

---

# 29. 模块化设计

模块目录：

```text
modules/example/
├── module.conf
└── main.sh
```

配置示例：

```bash
MODULE_ID="example"
MODULE_NAME="Example"
MODULE_VERSION="1.0"
MODULE_ENABLED=true
MODULE_ENTRY="main.sh"
```

建议模块接口：

```bash
module_menu
module_install
module_update
module_start
module_status
```

模块可以只实现自己需要的函数。

核心程序不得假定每个模块拥有全部接口。

---

# 30. 模块加载器

启动时扫描：

```text
modules/*/module.conf
```

读取：

```text
MODULE_ID
MODULE_NAME
MODULE_ENABLED
MODULE_ENTRY
```

启用模块加入模块菜单。

模块加载失败：

```text
记录错误
跳过该模块
继续启动核心程序
```

一个第三方模块故障不得导致整个 STermux 无法运行。

---

# 31. 安装器

最终提供：

```text
install.sh
```

流程：

```text
检测 Termux
    ↓
检查必要依赖
    ↓
安装缺少依赖
    ↓
下载 STermux
    ↓
初始化配置
    ↓
寻找 SillyTavern
    ↓
询问是否启用自动进入
    ↓
完成
```

默认优先直连 GitHub。

配置：

```bash
GITHUB_PROXY=""
```

用户自行设置代理。

不得把第三方 GitHub 镜像写死为唯一来源。

---

# 32. Termux 自动进入 STermux

支持：

```text
启用
关闭
```

修改 Shell 启动文件前必须备份。

写入内容需要明确标记：

```bash
# >>> STermux >>>
...
# <<< STermux <<<
```

关闭功能时只移除标记范围内的 STermux 内容。

不得破坏用户其他 `.bashrc` 或 `.zshrc` 配置。

---

# 33. 错误处理原则

关键命令必须单独检查返回状态：

```text
git fetch
git pull
git checkout
git reset
tar
文件复制
目录移动
目录删除
调度任务注册
```

错误信息至少说明：

```text
执行了什么
哪里失败
当前状态
错误摘要
可以采取什么下一步操作
```

避免一条巨大命令链把多个关键操作串在一起。

---

# 34. 网络失败原则

依赖网络：

```text
检查更新
更新 SillyTavern
更新第三方扩展
下载安装
更新模块
```

网络失败不得影响：

```text
启动 SillyTavern
查看本地备份
恢复本地备份
查看本地版本
查看本地状态
```

所有网络操作需要合理超时和失败反馈。

---

# 35. 日志系统

建议记录：

```text
data/logs/stermux.log
data/logs/update.log
data/logs/backup.log
```

日志应包含：

```text
时间
功能
结果
错误摘要
```

不要默认记录敏感聊天内容或备份文件内容。

---

# 36. 开发阶段

## Phase 1：基础骨架

目标：

```text
建立项目目录
manager.sh 可运行
加载配置
显示主菜单
检测 SillyTavern 路径
启动 SillyTavern
```

完成标准：

```text
用户可以通过 STermux 正常启动现有 SillyTavern
```

暂不实现更新、备份和扩展更新。

---

## Phase 2：SillyTavern 更新

实现：

```text
查看当前分支
查看当前 Commit
检查远程更新
执行更新
记录更新前 Commit
记录更新后 Commit
记录更新历史
```

完成标准：

```text
用户可以在 Termux 菜单中安全检查并更新 SillyTavern
```

---

## Phase 3：第三方扩展更新

实现：

```text
扫描 third-party
识别 Git 扩展
检测更新
显示状态
单独更新
多选更新
批量更新
仅手动更新策略
错误隔离
```

完成标准：

```text
用户可以自行选择更新哪些扩展
一键更新不会更新“仅手动”扩展
```

---

## Phase 4：备份核心

实现：

```text
统一 backup_create
手动备份
protective 备份
备份元数据
备份验证
备份列表
恢复
恢复前保护备份
```

完成标准：

```text
用户可以可靠创建和恢复本地数据备份
```

---

## Phase 5：定时备份

实现：

```text
定时备份配置
scheduler 抽象层
scheduled-backup.sh
后台调度注册
后台调度取消
最近成功备份状态
逾期检测
catchup 补偿备份
备份自动轮换
备份健康提醒
```

完成标准：

```text
定时备份可以独立运行
后台任务失效后可以在下次进入 STermux 时发现并补偿
```

---

## Phase 6：版本回退

实现：

```text
回退上一次更新
读取更新历史
回到当前远程最新版
回退前 protective 备份
```

完成标准：

```text
用户可以回退 SillyTavern 程序代码
用户数据不会被版本回退默认覆盖
```

---

## Phase 7：模块系统整理

审查现有代码：

```text
识别公共核心
识别 SillyTavern 专属逻辑
```

完成：

```text
module_loader.sh
module.conf
example module
MODULE_GUIDE.md
```

完成标准：

```text
新增模块无需修改核心业务逻辑
```

---

## Phase 8：安装与发布

实现：

```text
install.sh
uninstall.sh
首次配置
自动进入 Termux
README
完整错误处理
基础测试文档
GitHub Release
```

形成：

```text
v1.0.0
```

---

# 37. 推荐版本路线

## v0.1

```text
基础菜单
配置
路径检测
启动 ST
```

## v0.2

```text
ST 更新检测
ST 更新
更新历史
```

## v0.3

```text
第三方扩展扫描
选择性更新
批量更新
仅手动更新策略
```

## v0.4

```text
备份核心
手动备份
保护备份
恢复
```

## v0.5

```text
定时自动备份
逾期补偿备份
备份轮换
备份健康状态
```

从此版本开始适合个人长期日常使用。

## v0.6

```text
版本回退
更新历史联动
保护备份联动
```

## v0.7

```text
模块加载体系
模块模板
模块开发文档
```

## v1.0

```text
安装器
卸载器
自动进入
首次配置
完整错误处理
正式发布
```

---

# 38. Codex 开发原则

Codex 在实施过程中必须遵守：

1. 每次只完成当前阶段明确要求的功能。
2. 不提前大规模实现未来阶段。
3. 修改前先阅读 `PROJECT_PLAN.md` 和现有项目结构。
4. 先理解已有实现，再修改代码。
5. 优先复用已有公共函数。
6. 不把所有逻辑塞入单个 Bash 文件。
7. 不凭记忆假定 SillyTavern 数据目录结构。
8. 涉及用户数据前先确认真实路径。
9. 删除操作必须严格验证目标路径。
10. 每个阶段完成后执行语法检查。
11. 每个阶段完成后给出 Termux 实机测试步骤。
12. 保持已经验证可用的功能不被后续重构破坏。
13. 不自动引入没有必要的第三方依赖。
14. 不将第三方 GitHub 代理硬编码为强制依赖。
15. 所有路径变量必须正确处理空格和特殊字符。
16. Bash 变量引用原则上使用双引号。
17. 批量任务中单项失败不得导致无关任务全部中断。
18. 网络失败不得阻止本地功能使用。
19. 所有高风险操作都需要明确确认或保护机制。
20. 备份成功状态必须建立在实际验证成功之上。
21. 手动备份不得被自动轮换机制删除。
22. “一键更新全部扩展”必须跳过仅手动更新扩展。
23. 定时备份不得完全依赖单一后台机制，必须保留逾期补偿逻辑。
24. 实现当前阶段前，不要擅自扩张项目范围。

---

# 39. Codex 每阶段工作流程

开始新阶段：

```text
1. 阅读 PROJECT_PLAN.md
2. 阅读当前目录结构
3. 阅读相关现有代码
4. 总结当前实现状态
5. 说明本阶段实施方案
6. 列出计划修改或新增的文件
7. 再开始编码
```

完成后：

```text
1. 列出修改文件
2. 说明核心实现
3. 执行 Bash 语法检查
4. 执行现有自动测试
5. 给出 Android Termux 实机测试步骤
6. 说明已知限制
7. 等待实机测试结果
```

不要一次生成整个项目。

---

# 40. Phase 1 首次开工指令

创建空仓库并放入本文件后，可以向 Codex 发送：

```text
请先完整阅读项目根目录的 PROJECT_PLAN.md。

我们现在只开始 Phase 1，只实施以下内容：

1. 建立合理的基础目录结构。
2. 创建 manager.sh 作为程序入口。
3. 建立 core/config.sh、core/ui.sh、core/utils.sh。
4. 创建 config/default.conf 和 config/user.conf。
5. 实现基础终端主菜单。
6. 实现 SillyTavern 安装路径检测。
7. 优先从配置读取 ST_PATH。
8. 配置路径无效时尝试常见安装目录。
9. 仍然找不到时允许用户手动输入路径并保存。
10. 实现启动 SillyTavern 功能。
11. 所有路径变量正确引用，兼容空格。
12. 暂时不要实现更新、备份、定时任务、扩展更新、版本回退和完整模块系统。

开始编码前，请先：

1. 阅读当前仓库内容。
2. 说明准备创建的目录结构。
3. 说明每个文件的职责。
4. 说明 Phase 1 的具体实现方案。

确认方案后再修改代码。

完成后请：

1. 列出所有新增和修改文件。
2. 执行 Bash 语法检查。
3. 给出 Android Termux 实机测试步骤。
4. 说明任何未完成项和已知限制。

不要提前实施 PROJECT_PLAN.md 中后续 Phase 的功能。
```

---

# 41. 项目验收总标准

STermux v1.0 至少需要满足：

```text
1. 能稳定启动已有 SillyTavern。
2. 能检测并更新 SillyTavern。
3. 能扫描第三方扩展更新。
4. 能选择一个或多个扩展更新。
5. 能一键更新允许自动更新的扩展。
6. 能将指定扩展设为仅手动更新。
7. 能创建手动备份。
8. 能在重要操作前创建保护备份。
9. 能执行定时自动备份。
10. 能在定时备份逾期时进行补偿。
11. 能查看最近备份状态。
12. 能恢复指定备份。
13. 能安全轮换自动备份。
14. 永不自动删除手动备份。
15. 能回退 SillyTavern 上一次更新。
16. 网络异常时仍能启动和使用本地功能。
17. 一个扩展或模块失败不会拖垮整个管理器。
18. 可以通过模块接口继续增加未来工具。
19. 可以安装、卸载并控制 Termux 自动进入行为。
20. README 足以让新用户完成安装和基础使用。
```

---

# 42. 项目核心原则总结

STermux 的长期设计原则：

```text
更新可以选择
版本可以回退
数据持续备份
故障可以恢复
网络失效也能启动
模块可以继续增加
核心逻辑保持简单透明
```

项目优先级：

```text
数据安全
稳定可靠
可维护
易使用
可扩展
功能数量
```

任何新增功能都不得以牺牲备份可靠性、恢复能力和基础启动稳定性为代价。

最后汇报：

- 每完成一个 Phase，必须主动更新 `PROJECT_STATUS.md`，不得只在对话中汇报进度。
- 阶段中发生重要状态变化时，也必须同步更新 `PROJECT_STATUS.md`。
