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
5. 用户需要既能选择一个或多个第三方扩展更新，也能一次更新全部可更新 Git 扩展。
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
一键更新全部可更新 Git 扩展
单独查看扩展状态
安全删除一个或多个扩展
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

主菜单使用品牌区、本地状态摘要和分组功能入口。已安装 SillyTavern 时：

```text
============================================
                  STermux
          仅发布在外神们茶话会社区
============================================

SillyTavern : 1.15.0
STermux     : v0.0.3
自动备份    : 已关闭

--------------------------------------------
[SillyTavern 管理]

1. 启动 SillyTavern
2. SillyTavern 更新中心
3. 第三方扩展管理
4. 备份与恢复

[系统]

5. STermux 更新
6. 设置

0. 退出
--------------------------------------------
```

首页摘要只读取本地 SillyTavern 版本、统一 `VERSION` 中的 STermux 版本，以及计划备份的真实启用状态。不得在绘制首页时 fetch、扫描扩展远程状态、计算备份校验或显示路径和 Git 技术信息。自动备份默认关闭，首页不得把更新前 protective 备份误显示为计划备份已开启。

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
扩展安全删除

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
│   └── extension-policy.conf  # 旧版本遗留文件；运行时不再读取或写入
│
├── data/
│   ├── state/
│   ├── cache/
│   └── logs/
│
├── backups/
│   └── sillytavern/
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
- `config/` 放默认配置和用户配置；旧扩展策略文件仅为升级兼容保留。
- `data/` 放运行状态、缓存和日志。
- `backups/` 放备份数据。

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
```

旧版本可能存在 `config/extension-policy.conf`。新版不读取、不写入、不删除该文件，也不再根据其中内容改变扩展更新行为。

`default.conf`：

```bash
ST_PATH="$HOME/SillyTavern"

BACKUP_ROOT="$STERMUX_ROOT/backups/sillytavern"

AUTO_BACKUP_BEFORE_UPDATE=true
AUTO_BACKUP_BEFORE_ROLLBACK=true

AUTO_BACKUP_ENABLED=false
AUTO_BACKUP_INTERVAL_DAYS=7

# protective、scheduled、catchup 共用自动备份保留池。
AUTOMATIC_BACKUP_KEEP=2

CHECK_ST_UPDATE_ON_START=false
CHECK_EXTENSION_UPDATE_ON_START=false

AUTO_ENTER_MANAGER=false
COLOR_ENABLED=true

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

1. 更新 SillyTavern
2. 管理第三方扩展更新
3. 更新全部可更新项目
4. 重新检测
5. 查看更新历史
0. 返回
```

第三方扩展统一使用相同更新判断；更新全部只处理检测到可更新的 Git 扩展。

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
fetch_failed
no_upstream
not_git
```

界面示例：

```text
✓ FayeyphoneSupport           最新
↑ JS-Slash-Runner             可更新 3 commits
✓ SillyTavern-Variable-Viewer 最新
! ExampleExtension            检测失败
```

---

# 14. 第三方扩展选择性更新

必须支持：

```text
1. 检查更新
2. 更新扩展（支持单选和多选）
3. 更新全部
4. 删除扩展
5. 查看扩展技术详情
0. 返回主菜单
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

# 15. 第三方扩展统一更新规则

第三方扩展不再维护独立更新策略。所有正常 Git 扩展统一参与检查，用户可以选择单个、多个或全部可更新扩展。

旧 `config/extension-policy.conf` 为避免升级时主动删除用户文件而保留，但它已彻底失效：

```text
不读取
不写入
不影响状态
不影响更新全部
删除扩展时也不处理该文件
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

备份创建必须提供真实进度展示。V1 使用“当前阶段 + 已用时间心跳”，覆盖 data 归档、third-party 归档和完整性验证；耗时步骤每 10 秒提示仍在进行，完成后显示总耗时和备份大小。不得在无法可靠计算总字节进度时伪造百分比，且不得隐藏 `tar` 的错误输出或影响用户使用 Ctrl+C 取消。

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

Phase 4 V1 依据当前官方独立安装结构，统一备份：

```text
data/
config.yaml
public/scripts/extensions/third-party/
```

`third-party/` 存在时整体归档，包含 Git 元数据和隐藏文件；不存在时备份仍可成功，但元数据与日志必须记录为 `missing`。恢复新格式备份时必须同步恢复该目录的完整快照；若备份时目录不存在，恢复后也应为不存在。旧格式备份没有 third-party 状态字段时，不得擅自改动当前扩展目录。

manual、protective、scheduled、catchup 必须通过统一 `backup_create` 使用完全相同的内容范围。若 `config.yaml` 声明了非默认 `dataRoot`，在尚未能可靠解析并验证该路径前必须明确停止，不能把不完整备份记录为成功。

---

# 20. 备份类型行为

## 20.1 manual

用户主动创建。

默认永久保留。

永不参与自动清理，也不计入自动备份池的保留数量。

用户仍然可以在明确选择并二次确认后手动删除 manual 备份。

---

## 20.2 protective

重要操作前自动创建。

典型触发：

```text
更新 SillyTavern
重要版本回退
高风险恢复操作前
```

保留 `protective` 类型标记，用于展示备份来源和日志记录。

归入统一的自动备份保留池，不再设置独立保留数量。

---

## 20.3 scheduled

STermux 启动时的轻量到期检查创建。

默认频率：

```text
每 7 天
```

保留 `scheduled` 类型标记，用于展示备份来源和日志记录。

归入统一的自动备份保留池，不再设置独立保留数量。

---

## 20.4 catchup

当计划备份因为 STermux 未运行而错过时，在下一次合适的启动时补做。

创建后应更新“最近成功定时备份”状态。

保留 `catchup` 类型标记，用于展示备份来源和日志记录。

catchup 本质上属于自动备份，归入统一的自动备份保留池。

不得按错过的周期数量补做多份备份。无论错过 1 个还是多个周期，下一次合适的启动最多补做 1 份 catchup，避免瞬间生成大量重复备份。

---

# 21. 定时备份

设置界面：

```text
自动备份设置

自动备份：已开启
备份频率：每 7 天
下次备份：2026-07-25 10:00
最大自动备份数量：2 份

1. 开启 / 关闭自动备份
2. 设置备份频率
3. 设置最大自动备份数量
```

V1 支持：

```text
关闭
开启
每 1 到 30 天
```

未来可扩展：

```text
指定每日时刻
自定义 Cron 表达式
```

---

# 22. 定时备份调度原则

调度层放在：

```text
core/scheduler.sh
```

V1 采用无后台服务的轻量检查：

```text
STermux 启动并完成路径检测后检查一次
不在主菜单每次刷新时重复检查
不要求 cron 常驻服务
不强制依赖 Termux:API 或 Termux:Boot
不注册系统级后台服务
```

时间状态使用 epoch 保存到 `data/state/automatic-backup.conf`。状态缺失或损坏时，只从当前时间建立下一次未来计划，不立即生成历史补做备份。scheduled 或 catchup 备份成功后才原子更新时间状态；失败时保留原到期时间，下次启动继续尝试。

---

# 23. 逾期补偿备份

每次进入 STermux 时：

```text
读取下一次计划 epoch
    ↓
读取当前计划周期
    ↓
判断是否已经逾期
```

若逾期：

```text
执行 catchup 补偿备份
    ↓
记录结果
    ↓
进入主菜单
```

一次逾期检测最多创建 1 份 catchup。不得根据错过天数或错过周期数循环补做多份历史备份。

核心目标：

> 即使用户长时间没有运行 STermux，下一次进入时也只补做一份备份，不按错过周期批量生成。

---

# 24. 备份保留策略

默认：

```text
manual：独立管理，永不自动删除
protective + scheduled + catchup：共用自动备份保留池
自动备份池：总共最多保留最新 2 份
```

配置项：

```bash
AUTOMATIC_BACKUP_KEEP=2
```

自动备份池仍保留每份备份原有的 `protective`、`scheduled` 或 `catchup` 类型标记。类型仅用于展示来源、状态和日志，不再对应独立保留数量。

每次成功创建并验证一份 `protective`、`scheduled` 或 `catchup` 自动备份后，必须立即执行统一自动备份池轮换。

轮换流程：

```text
只读取元数据确认属于 protective、scheduled 或 catchup
    ↓
按真实备份创建时间排序
    ↓
保留最新 2 份自动备份
    ↓
超过上限时只删除最旧的自动备份
```

自动清理要求：

```text
只删除元数据明确标记为 protective、scheduled 或 catchup 的旧备份
manual 永远不计入自动备份池数量
manual 绝不参与自动清理
删除前验证目标路径位于备份根目录
禁止危险通配符误删
元数据缺失、类型未知或路径无法验证时拒绝自动删除
```

---

## 24.1 手动清理备份

用户可以查看所有已有备份。列表至少显示：

```text
创建时间
备份类型
文件大小
文件名或唯一标识
```

手动清理允许用户主动删除任意类型：

```text
manual
protective
scheduled
catchup
```

manual 的“永久保留”仅表示不参与自动清理，不禁止用户主动删除。

使用一个统一的“删除备份”入口，同时支持：

```text
删除单个备份
选择多个备份批量删除
```

多选输入复用安全编号解析规则：

```text
支持空格分隔
支持逗号分隔
过滤非法编号
自动去重
```

删除前必须完整显示最终选择的备份，并进行二次确认：

```text
确认删除以上备份？[y/N]
```

默认回答必须为 `N`。不得提供默认的一键“删除全部备份”功能。

批量删除要求：

```text
逐项验证路径
逐项执行删除
单项失败不影响后续项目
显示失败项和原因
为每个结果写入日志
```

所有手动和自动删除操作都必须验证：

```text
目标路径非空
目标路径位于 STermux 配置的备份根目录内
目标路径不是备份根目录本身
目标路径不是 HOME、ST_PATH 或文件系统根目录
路径规范化后仍位于允许范围
```

任何路径越界、路径穿越、符号链接逃逸或归属无法确认的目标都必须拒绝删除。

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

版本回退仅负责 SillyTavern 程序代码，入口位于 SillyTavern 更新中心。普通用户只从经过验证的正式语义版本列表中选择，不接受任意 Commit、分支、tag 或路径输入。

正式版本来源：

```text
当前分支对应的官方 Git remote
    ↓
刷新本地与远程 tag
    ↓
只接受不带 v 的三段正式版本 tag，例如 1.18.0
    ↓
要求 tag 中 package.json version 与 tag 完全一致
    ↓
要求目标 Commit 是当前 HEAD 的历史祖先
    ↓
只显示当前版本之前的版本，按版本倒序排列，最多保留最近 5 个可选版本
```

官方 tag 网络刷新失败时，可以继续使用本地已有且通过相同验证的 tag。不得内置或自动使用第三方 GitHub 代理。

执行前必须验证有效 ST_PATH、Git 仓库、正常分支、HEAD、upstream、目标版本和 tracked 工作区。detached HEAD、无 upstream、本地领先、分叉、合并冲突或 tracked 文件修改均必须停止；未跟踪的用户 data 不得被当作程序修改强制删除。

回退流程：

```text
显示当前版本与目标版本及兼容性风险
    ↓
用户明确确认，默认 N
    ↓
创建完整 protective 保护备份
    ↓
保护备份成功后，在当前正常分支上将 HEAD 安全指向已验证 tag Commit
    ↓
保持原分支名和 upstream，不进入 detached HEAD
    ↓
同步目标版本生产 Node Modules，并持续显示输出与耗时心跳
    ↓
验证 HEAD、package.json、安装结构、分支和 upstream
    ↓
记录 data/state/rollback-history.log
```

代码切换使用已验证目标 Commit 的 `git reset --hard`，但只有在 tracked 工作区完全干净、已保存原 Commit 且保护备份成功后才允许执行。不得运行 `git clean`，不得删除未跟踪用户数据。Git、依赖或最终验证失败时不得报告成功；代码已切换后失败应尽力恢复原 Commit，但不得自动恢复用户数据备份。

回退后当前分支会落后 upstream，现有更新中心必须仍能通过原 `git pull --rebase --autostash` 流程重新升级到当前 release 最新版本。

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

本功能归入 Phase 8 的安装与发布、首次配置和 Shell 入口管理范围。可以作为独立子功能提前实现，但不得因此改变尚在实机验收中的其他 Phase 状态，也不得提前宣称 Phase 8 完成。

默认关闭。用户可以在 STermux 设置中：

```text
查看当前状态
开启自动进入
关闭自动进入
```

第一版至少支持 Bash。应检测当前 `SHELL`；可以评估 Zsh 支持，但对尚未支持的 Shell 必须明确提示并拒绝修改任何配置文件。

修改 Shell 启动文件前必须备份。不得覆盖用户原有文件；所有写入和删除仅限 STermux 托管区域。

写入内容需要明确标记：

```bash
# >>> STermux autostart >>>
...
# <<< STermux autostart <<<
```

重复开启只能更新现有托管区域，不得产生重复代码。关闭功能时只移除完整托管区域；重复关闭应安全成功。

不得破坏用户其他 `.bashrc` 或 `.zshrc` 配置。

自动启动代码必须：

```text
只在交互式 Shell 中运行
通过环境标记防止递归启动和无限循环
根据 STermux 实际安装目录生成 manager.sh 路径
仅在 manager.sh 仍然存在时启动
用户从主菜单退出后返回原 Termux Shell
```

自动测试必须使用临时 `HOME` 和临时 Shell 配置文件，不得读取或修改开发机及用户真实的 `~/.bashrc`、`~/.zshrc`。至少覆盖开启、重复开启、关闭、重复关闭、原配置保留、特殊字符安装路径、manager.sh 不存在和防递归逻辑。

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

## Phase 2.5：SillyTavern 安装与首次配置

### 目标

为尚未安装 SillyTavern 的 Termux 环境提供完整安装能力。

当 STermux 未检测到有效 SillyTavern 安装时，应允许用户直接通过 STermux 完成安装。

### 功能范围

实现：

```text
检测 SillyTavern 是否已安装
检测必要运行依赖
提示缺失依赖
安装必要依赖
选择安装目录
安装 SillyTavern
记录安装路径
验证安装结果
首次启动测试
```

默认安装目录建议：

```text
$HOME/SillyTavern
```

用户可以选择其他目录。

---

### 主菜单行为

当已经检测到 SillyTavern 时：

```text
1. 启动 SillyTavern
2. 更新中心
...
```

当未检测到 SillyTavern 时，应显示：

```text
SillyTavern：未安装

1. 安装 SillyTavern
2. 设置已有 SillyTavern 路径
0. 退出
```

不要让没有安装 SillyTavern 的用户只能看到路径错误提示。

---

### 安装前环境检测

安装前检查当前环境是否具备所需命令和依赖。

具体依赖列表和安装方式必须在开发时根据当前 SillyTavern 官方 Termux 安装文档确认。

不得长期依赖硬编码的过时安装流程。

环境检测至少应区分：

```text
依赖已安装
依赖缺失
依赖存在但无法正常运行
```

例如：

```text
git 命令存在
```

不能直接等同于：

```text
git 可以正常运行
```

应通过实际执行版本检查确认命令可用。

这项要求用于避免出现软件包安装不完整或依赖损坏时误判环境正常。

---

### Termux 软件包处理

安装 SillyTavern 前，应确保必要软件包处于可正常工作的状态。

如果发现依赖缺失：

```text
提示用户
    ↓
确认安装
    ↓
安装必要依赖
    ↓
重新验证
```

不得静默执行大规模系统升级。

如果检测到依赖命令已经安装但无法运行，应：

```text
停止 SillyTavern 安装
显示明确错误
提供建议修复步骤
```

避免在损坏的 Termux 环境中继续安装。

---

### SillyTavern 安装流程

推荐流程：

```text
检查运行环境
    ↓
检查必要依赖
    ↓
确认安装目录
    ↓
确认目标目录不存在冲突
    ↓
按照当前官方推荐方式获取 SillyTavern
    ↓
完成必要初始化
    ↓
验证安装结构
    ↓
保存 ST_PATH
    ↓
提示安装成功
```

安装过程必须：

```text
显示当前执行步骤
显示失败原因
失败后保留可诊断信息
避免留下被误识别为完整安装的半成品目录
```

---

### 已存在目录处理

如果目标目录已经存在：

```text
$HOME/SillyTavern
```

不得直接覆盖。

必须判断：

```text
有效 SillyTavern 安装
普通非空目录
不完整安装
空目录
```

对应处理：

```text
有效安装
→ 提示直接使用现有安装

普通非空目录
→ 拒绝覆盖并要求选择其他目录

疑似不完整安装
→ 提示用户选择重新安装或手动处理

空目录
→ 根据实际安装方式安全处理
```

禁止无确认执行：

```text
rm -rf "$ST_PATH"
```

---

### 安装完成验证

安装完成后至少验证：

```text
安装目录存在
关键 SillyTavern 文件存在
启动脚本存在
配置路径可以正确保存
```

验证成功后：

```text
写入 ST_PATH
    ↓
返回主菜单
```

主菜单应立即显示：

```text
SillyTavern：已安装
```

---

### 首次启动

安装完成后可以提示：

```text
SillyTavern 安装完成

1. 立即启动
2. 返回主菜单
```

首次启动仍然通过 STermux 已有的统一启动逻辑执行。

不要单独维护第二套启动代码。

---

### 错误处理

必须覆盖：

```text
网络失败
Git 不可用
依赖安装失败
目标目录冲突
下载中断
安装不完整
路径保存失败
```

任何安装失败都不得影响 STermux 本身继续运行。

---

### 自动测试

至少增加：

```text
无 SillyTavern 时显示安装入口
已有 SillyTavern 时不重复提示安装
目标目录冲突处理
依赖缺失检测
依赖命令存在但不可运行
模拟安装成功
模拟安装失败
安装成功后保存 ST_PATH
安装失败时不保存无效 ST_PATH
```

自动测试不得真正联网安装 SillyTavern。

应使用 Mock 或临时测试仓库验证流程控制。

---

### Termux 实机验收

使用没有安装过 SillyTavern 的纯净测试手机完成。

测试流程：

```text
全新或无 SillyTavern 的 Termux
    ↓
启动 STermux
    ↓
正确显示“未安装”
    ↓
选择安装 SillyTavern
    ↓
完成环境检测
    ↓
完成安装
    ↓
自动保存路径
    ↓
首次启动 SillyTavern
```

该 Phase 的最终验收必须至少包含一次真实的从零安装。

---

### 完成标准

```text
1. 无酒馆环境可以正确识别。
2. 用户可以通过菜单安装 SillyTavern。
3. 必要依赖能够正确检测。
4. 安装失败不会破坏 STermux。
5. 已存在安装不会被错误覆盖。
6. 安装成功后自动保存 ST_PATH。
7. 安装后的 SillyTavern 可以正常启动。
8. 纯净测试手机完成一次真实从零安装。
```

---

## Phase 2.6：STermux 自更新

### 目标

让普通用户可以直接在 STermux 菜单中检查和更新 STermux 自身，无需手动执行 `git pull`。

本阶段只实现 STermux 自更新，不进入后续功能阶段。

---

### 菜单入口

主菜单增加独立的：

```text
STermux 更新
```

STermux 自更新不得与 SillyTavern 更新中心混合。

---

### 更新检查

通过 STermux 自身 Git 仓库执行：

```text
确认有效 Git 仓库
获取当前分支
获取 upstream
执行 git fetch
比较本地 HEAD 与 upstream
```

必须区分：

```text
已是最新
有可用更新
本地领先
分支分叉
无 upstream
detached HEAD
Git 命令不可用或损坏
Git 操作失败
```

普通用户界面只显示用户状态；Commit、upstream、ahead / behind 放入技术详情和日志。

---

### 执行更新

普通安装仓库使用：

```text
git pull --ff-only
```

禁止：

```text
git reset --hard
自动删除用户文件
强制覆盖本地程序文件修改
```

tracked 程序文件存在本地修改时必须停止自动更新并明确提示。

`config/user.conf`、`data/`、日志等运行时数据不作为程序文件修改，并应通过忽略规则与程序更新隔离。

---

### 更新后自动重启

更新成功后当前 Bash 进程不得继续长期使用旧版函数和模块。

应执行等价于：

```bash
exec bash "$STERMUX_ROOT/manager.sh"
```

重新加载最新版 `manager.sh`、`core/` 和 `modules/`。

---

### 异常处理

至少覆盖：

```text
当前目录不是 Git 仓库
git 命令不可用或损坏
没有 upstream
detached HEAD
tracked 程序文件存在修改
本地领先或与远程分叉
fetch 失败
pull 失败
更新成功但重新启动失败
```

任何异常不得破坏当前 STermux 安装，不得自动执行 `reset --hard`。

---

### 版本显示

STermux 使用项目根目录 `VERSION` 作为单一可信版本来源，Phase 6 版本为：

```text
v0.0.3
```

版本号只用于用户友好展示，不替代 Git upstream 与 Commit 状态判断。Git Commit 信息仅在技术详情显示。

---

### 自动测试

使用临时本地 Git 仓库，至少覆盖：

```text
已是最新
远程有新提交
更新成功
tracked 程序文件存在修改时拒绝更新
分支分叉时拒绝自动更新
无 upstream
detached HEAD
fetch 失败
pull 失败
更新后触发重新启动逻辑
重新启动失败
```

测试不得操作真实 STermux 仓库、访问真实用户数据或联网依赖 GitHub。

---

### Termux 实机验收

至少验证：

```text
从主菜单进入独立 STermux 更新页面
检查真实 upstream 状态
使用 fast-forward 更新 STermux
更新成功后自动重新启动 manager.sh
本地程序修改时拒绝更新
运行时配置和日志不被覆盖
```

---

### 完成标准

```text
1. 普通用户可以从菜单检查 STermux 更新。
2. 有更新时可以安全执行 fast-forward 更新。
3. 本地修改、分叉及 Git 异常不会被强制覆盖。
4. 用户运行时配置和日志不会被程序更新覆盖。
5. 更新成功后自动重新加载最新版程序。
6. 自动测试全部通过。
7. Android Termux 实机完成一次真实自更新验收。
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
从当前扫描列表中单选或多选删除扩展
扩展删除路径、路径穿越与符号链接逃逸保护
错误隔离
```

完成标准：

```text
用户可以自行选择更新哪些扩展
更新全部会处理所有检测到可更新的正常 Git 扩展
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
手动删除单个备份
手动选择多个备份批量删除
删除前展示与默认 N 二次确认
统一自动备份池保留策略
manual 自动清理隔离
备份删除路径越界保护
恢复
恢复前保护备份
third-party 整体备份、缺失记录与同步恢复
自动备份池最大保留数量可配置（默认 2，允许 1 到 20）
降低保留上限时确认并立即统一轮换
```

自动测试至少覆盖：

```text
删除单个 manual 备份
删除单个 protective、scheduled 或 catchup 自动备份
批量删除多个备份
用户取消删除
非法编号过滤
重复编号去重
单项删除失败后继续处理其他备份
manual 不被自动清理
protective、scheduled、catchup 混合时只保留最新 2 份
自动清理只删除最旧的自动备份
备份根目录路径越界与路径穿越保护
third-party 包含 Git 仓库和隐藏文件时完整备份与恢复
third-party 不存在时记录缺失且不阻止备份
保留上限配置持久化、非法输入拒绝与旧配置默认值兼容
提高上限不创建或删除备份
降低上限取消时配置和备份均保持不变
```

完成标准：

```text
用户可以可靠创建和恢复本地数据备份
```

---

## 独立优化项：终端 UI 基线与交互精简

本项是跨阶段展示层优化，不属于 Phase 5，也不改变 Phase 4 的验收状态。

实现：

```text
品牌区与中英文宽度安全居中
本地快速状态摘要
已安装 / 未安装动态分组菜单
简洁设置页
统一页面标题、分隔线和输入提示
统一信息、成功、警告、错误颜色
COLOR_ENABLED 与 NO_COLOR 降级
VERSION 单一版本来源
备份类型中文显示
扩展与更新状态颜色
ANSI 安全的中文及中英文混排标题居中
设置页按逻辑分组留白
卸载选项主文字与灰色次级说明分层
第三方扩展展示区与操作区分隔
扩展菜单精简为检查、选择更新、更新全部、删除与技术详情
```

第三方扩展更新不再维护 manual / 仅手动策略。所有正常 Git 扩展使用统一更新逻辑，“更新扩展”复用安全多选解析并同时支持单选和多选，“更新全部”处理所有检测到可更新的 Git 扩展。旧 `config/extension-policy.conf` 仅作为遗留用户文件保留，运行时不得读取、写入或据此改变更新行为。

约束：

```text
不修改 SillyTavern 数据与备份格式
不修改 Git 更新策略
不改变 Git 扩展的既有安全检查、失败隔离与日志规则
不修改 autostart 托管区域
首页不执行网络操作或耗时扫描
首页自动备份状态只反映 AUTO_BACKUP_ENABLED，不得把 protective 备份误当成计划备份已开启
```

完成标准：

```text
已安装与未安装菜单均正确分流
菜单入口继续调用既有业务函数
颜色可关闭并支持 NO_COLOR
ANSI 不影响中文宽度与对齐
本地隔离测试通过
Android Termux 完成显示、颜色和交互验收
```

---

## 独立补全项：早期公开测试前核心体验补全

本项不进入新的大 Phase，也不改变 Phase 4 的实机验收状态。它由三个已有范围的补充组成：

```text
Phase 8 提前子功能：卸载管理与安全自删除
Phase 3 补充：第三方扩展删除
Phase 4 增强：自动备份池最大保留数量设置
```

卸载管理支持单选和多选：卸载 STermux、卸载当前 SillyTavern、删除全部有效备份、删除自动进入托管区域。STermux 自删除必须在其他操作完成后交接给项目目录外的临时脚本，且不得卸载任何 Termux 公共依赖。所有危险操作默认取消，所有删除目标均需经过严格路径与结构验证。

该项本地测试通过后统一保持“待 Android Termux 实机验证”；不得据此把 Phase 8 整体标记为已开始或已完成。

---

## Phase 5：定时备份

实现：

```text
定时备份配置
scheduler 抽象层
启动时单次到期检查
epoch 时间状态
自动备份开关与每 N 天频率
最近成功备份状态
逾期检测
catchup 补偿备份
一次逾期只补做一份 catchup
备份自动轮换
失败保留到期状态并在下次启动重试
```

完成标准：

```text
自动备份开启后可在 STermux 启动时完成到期检查
长时间未运行后可以在下次进入 STermux 时发现并补偿
不需要常驻后台服务或额外 Termux 插件
```

---

## Phase 6：版本回退

实现：

```text
官方正式 tag 获取、过滤与本地降级
只允许从验证列表选择历史版本
tracked 修改、detached、分叉与无 upstream 保护
回退前 protective 完整备份
保持 release 分支和 upstream 的安全代码回退
Node Modules 依赖同步与失败恢复
回退日志
回退后通过现有更新中心重新升级
```

完成标准：

```text
用户可以回退 SillyTavern 程序代码
用户数据不会被版本回退默认覆盖
回退后不处于 detached HEAD
回退后仍可正常升级到当前 release 最新版本
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
卸载管理、安全自删除与组合操作
自动进入 Termux
自动进入设置、Bash 托管区域与防递归测试
README
完整错误处理
基础测试文档
GitHub Release
```

形成：

```text
v1.0.0
```

其中卸载管理可以作为“早期公开测试前核心体验补全”的独立子功能提前实现；Phase 8 的安装、发布与 Release 等其余范围仍保持未开始。

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
扩展安全删除
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
22. “更新全部扩展”必须处理所有检测到可更新的正常 Git 扩展，并保持单项失败隔离。
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
5. 能一键更新全部可更新的正常 Git 扩展。
6. 能安全删除用户明确选择的第三方扩展。
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
