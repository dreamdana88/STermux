
# STermux 项目进度

> 本文件记录项目真实开发状态。  
> 每个 Phase 完成或项目状态发生重要变化后必须更新。

## 当前状态

当前阶段：Phase 3

阶段名称：第三方扩展更新

状态：Phase 3 本地实现与隔离自动测试通过，待 Android Termux 实机验证

最后更新：2026-07-16（Phase 3 待实机验证；Phase 4 自动备份池默认上限调整为 2，备份逻辑尚未实施）

---

## Phase 进度

| Phase   | 内容             | 状态   |
| ------- | ---------------- | ------ |
| Phase 1 | 基础骨架         | UI 修复待复测 |
| Phase 2 | SillyTavern 更新 | 已完成 |
| Phase 2.5 | SillyTavern 安装与首次配置 | 已完成 |
| Phase 2.6 | STermux 自更新 | 已完成 |
| Phase 3 | 第三方扩展更新   | 本地通过，待实机验证 |
| Phase 4 | 备份核心         | 未开始 |
| Phase 5 | 定时备份         | 未开始 |
| Phase 6 | 版本回退         | 未开始 |
| Phase 7 | 模块系统整理     | 未开始 |
| Phase 8 | 安装与发布       | 未开始 |

---

## 当前已完成功能

- 基础目录结构
- manager.sh 程序入口与菜单循环
- 默认配置与用户配置覆盖机制
- 用户配置安全更新（保留其他配置项）
- SillyTavern 配置路径、常见路径和手动路径检测
- SillyTavern 安装结构验证
- 带空格、中文路径支持
- 通过官方 start.sh 启动 SillyTavern
- SillyTavern 停止后返回主菜单
- 终端主菜单中英文混排边框宽度修复
- SillyTavern 当前分支、Commit 与 upstream 查询
- SillyTavern 远程 fetch 与更新状态比较
- SillyTavern 官方 `git pull --rebase --autostash` 更新流程
- Git 网络命令超时与错误摘要
- 本地领先、远程落后、分叉、无 upstream、detached HEAD 等状态处理
- SillyTavern 更新前确认与本地修改提示
- SillyTavern 更新历史记录与查看
- 从本地 `package.json` 读取当前 SillyTavern 语义版本
- 在 `git fetch` 后通过 `git show <upstream>:package.json` 只读获取最新版本
- 默认更新状态仅显示当前版本、最新版本和简化更新状态
- 新增“查看技术详情”，按需显示分支、Commit、upstream 及 ahead / behind
- 更新成功结果默认显示版本变化，Commit 变化保留在更新日志中
- 更新历史 v2 同时记录更新前后版本、Commit、分支、时间与结果，并兼容旧记录
- 更新历史默认以版本变化为标题，Git 技术字段继续保留在日志中
- `package.json` 缺失或 `version` 异常时降级显示“未知”，不影响 Git 更新判断
- 未安装 SillyTavern 时显示安装入口和已有路径设置入口
- 根据当前官方 Termux 文档检测 `git`、`node`、`npm`、`nano`，32 位设备额外检测 `esbuild`
- 依赖检测区分可用、缺失及命令存在但无法运行，并保留损坏命令诊断输出
- 缺失依赖仅在用户确认后通过 `pkg install` 安装，且不会自动执行大规模系统升级
- 安装目标区分有效安装、普通非空目录、不完整安装、空目录和不存在目录
- 通过临时目录克隆官方 `release` 分支，验证成功后再移动并保存 `ST_PATH`
- 不完整安装可在确认后改名保留再安装，不使用递归覆盖删除
- 安装输出实时显示并同步记录日志、clone 支持用户取消、安装失败隔离及首次启动复用统一启动逻辑
- SillyTavern 首次启动缺少 `node_modules` 时显示可能耗时数分钟的明确提示
- 独立 STermux 更新页面与“开发版”用户状态显示
- STermux 自身分支、upstream、fetch 及 ahead / behind 检查
- 使用 `git pull --ff-only` 执行安全自更新，不使用 `reset --hard`
- tracked 程序文件修改、本地领先、分叉、无 upstream 和 detached HEAD 保护
- `config/user.conf`、data 与日志等运行时文件不参与程序修改拦截
- STermux 自更新技术详情、结果日志和更新后 `exec` 自动重启

---

## 当前开发中功能

暂无。Phase 3 代码与本地测试已完成，等待 Android Termux 实机验证。

---

## 待验证功能

- Phase 1 终端主菜单社区标题边框的 Android Termux 目视复测
- Phase 3 第三方扩展管理的 Android Termux 实机验证

---

## 已知问题

暂无已知未修复问题。

范围说明：Phase 3 按计划只管理 `public/scripts/extensions/third-party` 中为所有用户安装的扩展；新版 SillyTavern 的按用户扩展目录不在本阶段范围内。

---

## 最近阶段成果

- 新增 `manager.sh`。
- 新增 `core/config.sh`、`core/ui.sh`、`core/utils.sh`。
- 新增 `config/default.conf`、`config/user.conf`。
- 新增 `tests/run_all.sh`、`tests/test_config.sh`、`tests/test_paths.sh`、`tests/test_manager.sh`。
- Bash 语法检查通过。
- 本地自动测试 4/4 通过：配置读写、常见路径、无效路径、中文/空格路径、UI 显示宽度、启动及菜单返回。
- Android Termux 实机验证通过：路径检测、菜单、SillyTavern 启动与返回均正常。
- 修复社区标题左右各多出 1 列空格导致的右边框错位。
- 新增 `core/git.sh` 和 `modules/sillytavern/update.sh`。
- 主菜单新增“更新中心”，支持检查、执行更新和查看历史。
- 新增 `tests/test_ui.sh` 和 `tests/test_git.sh`。
- 本地自动测试 5/5 通过，Phase 1 回归测试未发现退化。
- 修复 `tests/test_manager.sh` 复制真实 `config/user.conf`、可能启动真实 SillyTavern 的隔离缺陷。
- 隔离项目现仅复制 `default.conf`，并由测试自身创建专用空白 `user.conf`。
- 新增毒化来源配置与违规启动哨兵回归，确保有效绝对 `ST_PATH` 不会被测试读取或启动。
- 更新 `AGENTS.md` 与 `docs/TESTING.md`，明确禁止自动测试读取真实用户配置或启动真实 SillyTavern。
- 修复后完整本地测试 5/5 通过，`test_manager.sh` 在外部 30 秒上限内正常结束。
- 新增 SillyTavern 本地与 upstream 语义版本读取；远程版本使用 `git show` 读取，不 checkout 或修改工作区。
- 更新中心默认界面简化为当前版本、最新版本和更新状态，不展示 Git 技术字段或 Commit 数量。
- 新增“查看技术详情”入口，集中显示分支、当前 Commit、upstream 和 ahead / behind 状态。
- 更新成功提示及更新历史默认优先展示版本变化；完整 Commit、分支、时间和结果仍保留在 v2 日志中。
- 更新历史升级为 v2 字段，并在保留旧记录的前提下兼容原有历史表头。
- 新增 `tests/test_version.sh`，覆盖正常本地/远程版本、版本不同、同版本新 Commit、文件缺失和字段异常。
- 完整本地自动测试 6/6 通过；版本未知不会阻止 fetch、Commit 比较或更新判断。
- Phase 2 更新中心及补充功能已通过 Android Termux 实机验收。
- 新增 `modules/sillytavern/install.sh`，实现 Termux 环境、依赖三态、目标目录分类和安全安装编排。
- 无安装主菜单现在直接提供“安装 SillyTavern”和“设置已有 SillyTavern 路径”，不再强制显示路径错误提示。
- 依据当前官方文档使用 `git nodejs-lts nano`，并对 32 位设备增加 `esbuild` 检测；所有命令均实际执行版本探针。
- 安装自动测试使用 Mock `pkg` 与本地临时 Git 仓库，禁止真实联网和真实软件包安装。
- 新增 `tests/test_install.sh`；完整本地自动测试 7/7 通过，原 Phase 1/2 测试未发现退化。
- 修复用户在 STermux 确认依赖安装后，底层 `pkg`/apt 再次等待 `[Y/n]` 的问题；现执行 `pkg install -y`。
- 安装命令输出改为通过 `tee` 实时显示并同步追加到安装日志，pkg/apt 正常进度和错误不再被完整隐藏。
- 移除 SillyTavern clone 固定 300 秒总时长限制，保留用户 Ctrl+C 取消能力。
- clone 使用 `--progress` 强制显示真实进度，仍保留完整 Git 历史、隐藏临时目录和失败隔离策略。
- 新增非交互确认、输出透传、pkg 失败、无固定 timeout、clone 成败与隐藏临时目录回归；全量测试 7/7 通过。
- Phase 2.5 纯净 Termux 再次实机验收通过，依赖只需一次确认、安装与 clone 进度可见且可正常进入 SillyTavern。
- SillyTavern 缺少 `node_modules` 时，启动前新增“首次启动可能需要几分钟”的等待提示。
- 新增独立 Phase 2.6：STermux 自更新。
- 主菜单已增加独立“STermux 更新”，与 SillyTavern 更新中心分离。
- 自更新使用 `git pull --ff-only`，更新前拒绝 tracked 程序修改、本地领先和分叉状态。
- 当前没有正式版本体系，普通界面如实显示“开发版”；Commit 与 ahead / behind 仅在技术详情显示。
- 更新成功后通过 `exec bash manager.sh` 重新加载最新版程序，并覆盖重启失败状态。
- 新增 `tests/test_self_update.sh`，全部使用临时本地 Git 仓库和重启 Mock，不操作真实项目仓库。
- 完整本地自动测试由 7 项增加到 8 项，结果 8/8 通过。
- Phase 2.6 Android Termux 实机验收通过：成功发现 upstream 新 Commit、正确显示可用更新，并完成真实 fast-forward 自更新。
- Phase 2.6 保留本地修改、分叉、无 upstream、detached HEAD、fetch/pull 失败及重启失败的隔离自动测试覆盖。
- 新增 `modules/sillytavern/extensions.sh`，集中提供全局 third-party 扩展路径、一级目录扫描、Git 状态和更新流程。
- 扩展列表区分最新、可更新、仅手动可更新、非 Git、无 upstream、fetch 失败及更新失败。
- 支持单个更新、多选更新、批量更新、重新检测、策略查看、设置及取消“仅手动更新”。
- 多选支持空格或逗号分隔，自动过滤非法编号并去重，执行前展示最终选择并确认。
- 批量更新逐项处理；单个 pull 失败不会中断后续扩展，仅手动扩展和非 Git 扩展不会参与自动批量更新。
- `config/extension-policy.conf` 使用纯文本解析而非 `source`；默认策略为 `auto`，仅记录 `manual` 项。
- 扩展更新结果写入 `data/logs/extension-update.log`，记录扩展名、前后 Commit、结果和错误摘要。
- STermux 自更新的程序修改检查已排除扩展策略文件，并通过回归测试确认策略内容不会被自更新覆盖。
- 新增 `tests/test_extensions.sh`，全部使用临时扩展目录和本地裸 Git 仓库；完整自动测试由 8 项增加到 9 项，结果 9/9 通过。
- Phase 4 计划调整：manual 永不自动删除；protective、scheduled、catchup 共用默认最多 2 份的自动备份池。
- `config/default.conf` 已预置 `AUTOMATIC_BACKUP_KEEP=2`；Phase 4 实施时，每次成功创建自动备份后按时间保留最新 2 份。
- Phase 4 计划新增手动清理：支持单个和多选删除任意类型备份，默认 N 二次确认、单项失败隔离、删除日志和严格路径越界保护。
- catchup 计划明确为错过计划任务后的单次补偿；无论错过多少周期，下一次合适启动最多补做 1 份。

---

## Phase 1 测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| Bash 语法 | 通过 | 未执行（当前无 WSL Linux 发行版） | 通过 | 已完成 |
| 配置加载与保存 | 通过 | 不需要 | 不需要 | 已完成 |
| SillyTavern 路径检测 | Fixture 测试通过 | 未执行 | 通过 | 已完成 |
| 菜单与取消流程 | 通过 | 未执行 | 通过 | 已完成 |
| 终端 UI 边框宽度 | 通过 | 未执行 | 待复测 | 本地修复完成 |
| SillyTavern 启动 | 模拟 `start.sh` 通过 | 未执行 | 通过 | 已完成 |

---

## Phase 2 测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| Bash 语法 | 通过 | 未执行（当前无 WSL Linux 发行版） | 通过 | 已完成 |
| Git 本地状态读取 | 本地仓库 Fixture 通过 | 未执行 | 通过 | 已完成 |
| 远程更新检测 | 本地裸仓库 Fixture 通过 | 未执行 | 通过 | 已完成 |
| `pull --rebase --autostash` | 两轮更新测试通过 | 未执行 | 通过 | 已完成 |
| 本地修改恢复 | 通过 | 未执行 | 通过 | 已完成 |
| 分叉、无 upstream、fetch 失败 | 通过 | 未执行 | 通过 | 已完成 |
| 更新历史 | 通过 | 未执行 | 通过 | 已完成 |
| 更新中心菜单 | 集成测试通过 | 未执行 | 通过 | 已完成 |
| 普通摘要与技术详情分层 | 默认隐藏 Git 字段、详情入口断言通过 | 未执行 | 通过 | 已完成 |
| 管理器配置隔离 | 毒化配置与启动哨兵回归通过 | 未执行 | 通过 | 已完成 |
| 本地与 upstream 版本读取 | 本地裸仓库 Fixture 通过 | 未执行 | 通过 | 已完成 |
| 版本相同但存在新 Commit | 通过，仍判定可更新 | 未执行 | 通过 | 已完成 |
| `package.json` 缺失或版本异常 | 通过，显示未知且 Git 检查继续 | 未执行 | 通过 | 已完成 |
| 更新结果与历史版本字段 | v2 写入及旧记录兼容通过 | 未执行 | 通过 | 已完成 |

---

## Phase 2.5 测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| Bash 语法 | 通过 | 未执行（当前无 WSL Linux 发行版） | 通过 | 已完成 |
| 无安装/已有安装菜单分流 | 集成测试通过 | 未执行 | 通过 | 已完成 |
| 依赖可用、缺失、损坏三态 | Mock 测试通过 | 模拟 Termux 通过 | 通过 | 已完成 |
| `pkg` 一次确认、实时输出与复验 | Mock `pkg`、`-y` 和输出透传通过 | 模拟 Termux 通过 | 通过 | 已完成 |
| 目标目录五类状态 | 临时目录测试通过 | 未执行 | 通过 | 已完成 |
| 普通目录拒绝覆盖与危险路径拒绝 | 通过 | 未执行 | 通过 | 已完成 |
| 不完整安装保留重装 | 通过 | 未执行 | 通过 | 已完成 |
| 官方 release 安装流程 | 本地 Git 仓库通过，无固定总超时 | 未执行 | 通过 | 已完成 |
| 安装成功保存 `ST_PATH` | 通过 | 未执行 | 通过 | 已完成 |
| 下载失败不保存无效路径 | 通过 | 未执行 | 通过 | 已完成 |
| 路径保存失败诊断 | 通过 | 未执行 | 通过 | 已完成 |
| 首次启动复用统一启动逻辑 | 代码路径与 Fixture 启动通过 | 未执行 | 通过 | 已完成 |

---

## Phase 2.6 测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| Bash 语法 | 通过 | 未执行（当前无 WSL Linux 发行版） | 核心链路通过 | 已完成 |
| 独立菜单、普通摘要与技术详情 | 集成测试通过 | 未执行 | 通过 | 已完成 |
| 最新状态与远程新 Commit | 临时本地 Git 仓库通过 | 未执行 | 通过 | 已完成 |
| `pull --ff-only` 更新成功 | 临时本地 Git 仓库通过 | 未执行 | 通过 | 已完成 |
| 运行时 `config/user.conf` 保留 | tracked Fixture 更新前后内容一致 | 未执行 | 自动测试覆盖 | 已完成 |
| tracked 程序修改拒绝更新 | 通过，HEAD 保持不变 | 未执行 | 自动测试覆盖 | 已完成 |
| 本地领先与分叉拒绝更新 | 通过 | 未执行 | 自动测试覆盖 | 已完成 |
| 无 upstream 与 detached HEAD | 通过 | 未执行 | 自动测试覆盖 | 已完成 |
| Git 损坏、非仓库、fetch 与 pull 失败 | 通过 | 未执行 | 自动测试覆盖 | 已完成 |
| 更新后重启与重启失败 | 重启 Mock 通过 | 未执行 | 自动测试覆盖 | 已完成 |

---

## Phase 3 测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| Bash 语法 | 通过 | Git Bash 通过 | 待测试 | 待实机验证 |
| 全局 third-party 一级目录扫描 | Git/非 Git/空目录 Fixture 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 中文、空格扩展路径 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| latest、可更新与仅手动可更新状态 | 本地裸 Git 远程通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 无 upstream 与 fetch 失败 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 单个与多选更新 | 非法编号过滤、逗号/空格和去重通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 批量跳过仅手动与非 Git 扩展 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 单项 pull 失败继续后续扩展 | 模拟 pull 失败后后续真实本地更新通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 用户主动更新仅手动扩展 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 策略保存、取消与内容保留 | 临时策略文件通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 扩展更新日志 | 成功、失败、跳过记录通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 真实用户配置与扩展隔离 | 管理器 Fixture 与临时根目录通过 | Git Bash 通过 | 不适用 | 本地通过 |

---

## 下一步

在 Android Termux 对真实全局 third-party 扩展执行扫描、状态检查、选择性更新、批量跳过和失败隔离验收；验收通过前 Phase 3 不标记为完成，也不进入 Phase 4。

---

## 最近一次阶段验收

2026-07-16：Phase 1 本地自动测试与 Android Termux 实机验收通过。

2026-07-16：Phase 2 更新中心、语义版本展示、技术详情、更新历史及测试隔离通过 Android Termux 实机验收。

2026-07-16：Phase 2.5 在纯净 Android Termux 完成依赖安装、完整 clone、路径保存和首次启动验收。

2026-07-16：Phase 2.6 在 Android Termux 成功检测 upstream 新 Commit、显示可用更新并完成 fast-forward 自更新，阶段验收通过。
