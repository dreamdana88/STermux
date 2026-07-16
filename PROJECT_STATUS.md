
# STermux 项目进度

> 本文件记录项目真实开发状态。  
> 每个 Phase 完成或项目状态发生重要变化后必须更新。

## 当前状态

当前阶段：Phase 1

阶段名称：基础骨架

状态：待实机验证

最后更新：2026-07-16（Phase 1 编码与本地验证完成）

---

## Phase 进度

| Phase   | 内容             | 状态   |
| ------- | ---------------- | ------ |
| Phase 1 | 基础骨架         | 待验收 |
| Phase 2 | SillyTavern 更新 | 未开始 |
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

---

## 当前开发中功能

暂无。

---

## 待验证功能

- Android Termux 实机启动 STermux
- 自动识别真实 `$HOME/SillyTavern`
- 手动选择真实 SillyTavern 安装目录
- 通过真实 SillyTavern `start.sh` 启动和停止服务

---

## 已知问题

- 当前开发环境为 Windows Git Bash，尚未在 Android Termux 实机验证。

---

## 最近阶段成果

- 新增 `manager.sh`。
- 新增 `core/config.sh`、`core/ui.sh`、`core/utils.sh`。
- 新增 `config/default.conf`、`config/user.conf`。
- 新增 `tests/run_all.sh`、`tests/test_config.sh`、`tests/test_paths.sh`、`tests/test_manager.sh`。
- Bash 语法检查通过。
- 本地自动测试 3/3 通过：配置读写、常见路径、无效路径、中文/空格路径、启动及菜单返回。

---

## Phase 1 测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| Bash 语法 | 通过 | 未执行（当前无 WSL Linux 发行版） | 待测试 | 本地测试通过 |
| 配置加载与保存 | 通过 | 不需要 | 不需要 | 已完成 |
| SillyTavern 路径检测 | Fixture 测试通过 | 未执行 | 待测试 | 待 Termux 实机验证 |
| 菜单与取消流程 | 通过 | 未执行 | 待测试 | 待 Termux 实机验证 |
| SillyTavern 启动 | 模拟 `start.sh` 通过 | 未执行 | 待测试 | 待 Termux 实机验证 |

---

## 下一步

在 Android Termux 实机执行 Phase 1 验收步骤，并根据结果修复问题或确认阶段完成。

---

## 最近一次阶段验收

2026-07-16：本地开发环境验证通过，等待 Android Termux 实机验收。
