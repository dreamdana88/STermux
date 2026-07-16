
# STermux 项目进度

> 本文件记录项目真实开发状态。  
> 每个 Phase 完成或项目状态发生重要变化后必须更新。

## 当前状态

当前阶段：Phase 2

阶段名称：SillyTavern 更新

状态：Phase 2 补充开发完成，待 Termux 实机复测

最后更新：2026-07-16（更新中心普通用户界面简化完成，本地回归 6/6 通过）

---

## Phase 进度

| Phase   | 内容             | 状态   |
| ------- | ---------------- | ------ |
| Phase 1 | 基础骨架         | UI 修复待复测 |
| Phase 2 | SillyTavern 更新 | 补充完成，待实机复测 |
| Phase 3 | 第三方扩展更新   | 未开始 |
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

---

## 当前开发中功能

暂无。当前等待 Termux 实机复测，不进入 Phase 3。

---

## 待验证功能

- Phase 1 终端主菜单社区标题边框的 Android Termux 目视复测
- `tests/test_manager.sh` 配置隔离修复的 Android Termux 回归测试
- Phase 2 更新功能的 Android Termux 实机测试

---

## 已知问题

暂无未修复问题。配置隔离缺陷已完成本地修复，等待 Termux 回归确认。

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
| Bash 语法 | 通过 | 未执行（当前无 WSL Linux 发行版） | 待测试 | 本地测试通过 |
| Git 本地状态读取 | 本地仓库 Fixture 通过 | 未执行 | 待测试 | 待 Termux 实机验证 |
| 远程更新检测 | 本地裸仓库 Fixture 通过 | 未执行 | 待测试 | 待 Termux 实机验证 |
| `pull --rebase --autostash` | 两轮更新测试通过 | 未执行 | 待测试 | 待 Termux 实机验证 |
| 本地修改恢复 | 通过 | 未执行 | 待测试 | 待 Termux 实机验证 |
| 分叉、无 upstream、fetch 失败 | 通过 | 未执行 | 待测试 | 待 Termux 实机验证 |
| 更新历史 | 通过 | 未执行 | 待测试 | 待 Termux 实机验证 |
| 更新中心菜单 | 集成测试通过 | 未执行 | 待测试 | 待 Termux 实机验证 |
| 普通摘要与技术详情分层 | 默认隐藏 Git 字段、详情入口断言通过 | 未执行 | 待复测 | 本地补充完成 |
| 管理器配置隔离 | 毒化配置与启动哨兵回归通过 | 未执行 | 待复测 | 修复完成，待 Termux 回归 |
| 本地与 upstream 版本读取 | 本地裸仓库 Fixture 通过 | 未执行 | 待复测 | 本地补充完成 |
| 版本相同但存在新 Commit | 通过，仍判定可更新 | 未执行 | 待复测 | Git Commit 判断保持有效 |
| `package.json` 缺失或版本异常 | 通过，显示未知且 Git 检查继续 | 未执行 | 待复测 | 非阻塞降级通过 |
| 更新结果与历史版本字段 | v2 写入及旧记录兼容通过 | 未执行 | 待复测 | 本地补充完成 |

---

## 下一步

先执行 `test_manager.sh` 配置隔离修复与 `test_version.sh` 版本展示的 Termux 回归，再继续 Phase 1 UI 复测和 Phase 2 实机验收；全部确认前不进入 Phase 3。

---

## 最近一次阶段验收

2026-07-16：Phase 1 本地自动测试与 Android Termux 实机验收通过。
