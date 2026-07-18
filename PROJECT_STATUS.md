
# STermux 项目进度

> 本文件记录项目真实开发状态。  
> 每个 Phase 完成或项目状态发生重要变化后必须更新。

## 当前状态

当前阶段：Phase 5

阶段名称：定时自动备份

状态：Phase 5 本地实现与隔离自动测试通过，待 Android Termux 实机验证

最后更新：2026-07-18（Phase 5 定时自动备份本地实现与 13/13 隔离回归通过，待 Android Termux 实机验证）

---

## Phase 进度

| Phase   | 内容             | 状态   |
| ------- | ---------------- | ------ |
| Phase 1 | 基础骨架         | UI 修复待复测 |
| Phase 2 | SillyTavern 更新 | 已完成 |
| Phase 2.5 | SillyTavern 安装与首次配置 | 已完成 |
| Phase 2.6 | STermux 自更新 | 已完成 |
| Phase 3 | 第三方扩展更新   | 已完成（扩展删除补充待实机验证） |
| Phase 4 | 备份核心         | 本地通过，待实机验证 |
| Phase 5 | 定时备份         | 本地通过，待实机验证 |
| Phase 6 | 版本回退         | 未开始 |
| Phase 7 | 模块系统整理     | 未开始 |
| Phase 8 | 安装与发布       | 未开始（自动进入、卸载管理子功能本地通过） |

独立优化项：终端 UI 基线与交互精简——本地通过，待 Android Termux 实机验证；其验收状态与 Phase 5 分开记录。

独立补全项：早期公开测试前核心体验补全——卸载管理、扩展删除和自动备份上限设置均已本地通过，待 Android Termux 实机验证；不代表进入 Phase 5 或正式启动 Phase 8。

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
- 独立 STermux 更新页面与统一正式版本显示
- STermux 自身分支、upstream、fetch 及 ahead / behind 检查
- 使用 `git pull --ff-only` 执行安全自更新，不使用 `reset --hard`
- tracked 程序文件修改、本地领先、分叉、无 upstream 和 detached HEAD 保护
- `config/user.conf`、data 与日志等运行时文件不参与程序修改拦截
- STermux 自更新技术详情、结果日志和更新后 `exec` 自动重启
- 项目根目录 `VERSION` 作为 STermux 单一可信版本来源，当前为 `v0.0.2`
- 主菜单采用品牌区、本地状态摘要和 SillyTavern/系统分组，不再显示长路径或 Git 技术字段
- 已安装首页显示 SillyTavern 本地版本、STermux 版本与真实自动备份开关状态
- 未安装首页显示安装和已有路径入口，并隐藏更新中心、扩展管理与备份恢复
- 设置页简化为路径、脚本自启、颜色、当前路径、版本信息和卸载管理，不增加单项分组标题
- `core/ui.sh` 统一颜色、页面标题、分隔线、状态行、菜单提示及中英文显示宽度处理；未设置 UTF-8 locale 时仍按 UTF-8 字节安全计算中文宽度
- 支持 `COLOR_ENABLED`、`NO_COLOR`、非 TTY 与 `TERM=dumb` 纯文本降级
- 备份、扩展、SillyTavern 更新与 STermux 更新页面完成一致的展示层整理
- 卸载管理支持卸载 STermux、卸载当前 SillyTavern、删除全部有效备份和删除自动进入托管区域，并支持安全多选组合
- STermux 自删除由项目目录外临时脚本最后接管，重复校验根目录结构和危险路径；不执行任何公共 Termux 依赖卸载
- SillyTavern 卸载只接受当前有效 `ST_PATH`，删除成功后清理用户配置中的路径状态
- 第三方扩展管理支持从当前扫描清单单选或多选删除 Git / 非 Git 扩展
- 扩展删除拒绝 third-party 根目录、路径穿越、目录外目标与符号链接逃逸，并保持单项失败隔离
- 第三方扩展更新菜单精简为检查、选择更新、更新全部、删除和技术详情；选择更新统一支持单选与多选
- 所有正常 Git 扩展统一参与更新检查和“更新全部”，不再存在 manual / 仅手动更新状态或跳过逻辑
- 旧 `config/extension-policy.conf` 保留在原位但彻底失效；程序不再读取、写入或根据其内容改变扩展行为
- `AUTOMATIC_BACKUP_KEEP` 可在备份设置中配置为 1 到 20，默认及旧配置回退值保持 2
- 降低自动备份上限时先显示清理数量并默认取消；确认后只轮换 protective、scheduled、catchup 统一池，manual 始终不参与
- Phase 5 使用 `AUTO_BACKUP_ENABLED=false` 和 `AUTO_BACKUP_INTERVAL_DAYS=7` 作为安全默认值，频率允许 1 到 30 天
- STermux 启动并完成路径检测后只执行一次轻量到期检查，不依赖 cron、Termux:API、Termux:Boot 或常驻后台服务
- 自动备份 epoch 状态保存到 `data/state/automatic-backup.conf`，状态缺失或损坏时只建立未来计划
- 正常到期创建 scheduled；至少额外错过一个完整周期创建 catchup，错过多个周期仍只补做一份
- scheduled / catchup 成功后才原子更新最近成功和下一次计划时间，失败保留原到期状态供下次启动重试
- 自动备份检查使用进程锁隔离并发 STermux 启动，并通过到期 epoch 元数据恢复未提交状态，同一周期不会重复触发
- 自动备份设置页统一管理开关、每 N 天频率和现有最大数量；首页只显示开启或关闭

---

## 当前开发中功能

Phase 5 定时自动备份已完成本地实现和隔离自动测试，等待 Android Termux 实机验证。Phase 4、独立终端 UI 与早期公开测试补充仍保持各自原有的待实机验证状态。

---

## 待验证功能

- Phase 1 终端主菜单社区标题边框的 Android Termux 目视复测
- Phase 4 完成后的 Android Termux 真实备份与恢复验证
- Phase 8 自动进入子功能的 Android Termux Bash 实机验证
- 独立终端 UI 优化的 Android Termux 标题居中、窄屏、颜色、动态菜单和入口回归验证
- 卸载管理的 Android Termux 临时脚本、自删除、组合操作与告别信息验证
- 第三方扩展精简菜单、单选 / 多选更新、更新全部与安全删除的 Android Termux 验证
- 自动备份上限设置的 Android Termux 持久化、降低上限取消和确认轮换验证
- Phase 5 自动备份开关、频率、启动到期检查、scheduled / catchup、失败重试和状态文件的 Android Termux 验证

---

## 已知问题

- 第三方扩展显示名可能与目录名不一致；暂作为未来 UI 优化事项，不扩展 Phase 3 范围。
- Phase 4 V1 处理 `config.yaml + data/ + public/scripts/extensions/third-party/`；检测到自定义 `dataRoot` 时仍会明确拒绝备份，避免产生漏数据的伪成功结果。

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
- Phase 2.6 初始阶段未虚构版本号；现已由独立 UI 优化建立根目录 `VERSION`，Git Commit 与 ahead / behind 仍只在技术详情显示。
- 更新成功后通过 `exec bash manager.sh` 重新加载最新版程序，并覆盖重启失败状态。
- 新增 `tests/test_self_update.sh`，全部使用临时本地 Git 仓库和重启 Mock，不操作真实项目仓库。
- 完整本地自动测试由 7 项增加到 8 项，结果 8/8 通过。
- Phase 2.6 Android Termux 实机验收通过：成功发现 upstream 新 Commit、正确显示可用更新，并完成真实 fast-forward 自更新。
- Phase 2.6 保留本地修改、分叉、无 upstream、detached HEAD、fetch/pull 失败及重启失败的隔离自动测试覆盖。
- 新增 `modules/sillytavern/extensions.sh`，集中提供全局 third-party 扩展路径、一级目录扫描、Git 状态和更新流程。
- 扩展列表区分最新、可更新、非 Git、无 upstream、fetch 失败及更新失败。
- 支持检查更新、单选或多选更新、更新全部、删除扩展和查看技术详情。
- 多选支持空格或逗号分隔，自动过滤非法编号并去重，执行前展示最终选择并确认。
- 更新全部逐项处理所有检测到可更新的 Git 扩展；单个 pull 失败不会中断后续扩展，非 Git 扩展不会执行 Git 更新。
- manual / 仅手动更新机制已经移除；旧 `config/extension-policy.conf` 不读取、不写入且不影响扩展状态或更新结果。
- 扩展更新结果写入 `data/logs/extension-update.log`，记录扩展名、前后 Commit、结果和错误摘要。
- STermux 自更新继续保留遗留策略文件，并通过回归测试确认其内容不会被自更新覆盖。
- 新增 `tests/test_extensions.sh`，全部使用临时扩展目录和本地裸 Git 仓库；完整自动测试由 8 项增加到 9 项，结果 9/9 通过。
- Phase 4 计划调整：manual 永不自动删除；protective、scheduled、catchup 共用默认最多 2 份的自动备份池。
- `config/default.conf` 已预置 `AUTOMATIC_BACKUP_KEEP=2`；Phase 4 实施时，每次成功创建自动备份后按时间保留最新 2 份。
- Phase 4 计划新增手动清理：支持单个和多选删除任意类型备份，默认 N 二次确认、单项失败隔离、删除日志和严格路径越界保护。
- catchup 计划明确为错过计划任务后的单次补偿；无论错过多少周期，下一次合适启动最多补做 1 份。
- Phase 3 Android Termux 实机验收通过：成功识别 15 个 third-party 一级扩展，Git/非 Git 扫描与分类正常。
- 实机曾完成旧 manual 策略设置、列表显示、持久化和取消；该机制现已按新要求停用，此记录仅保留为历史验收信息。
- 实机当时没有存在可用更新的扩展，因此未触发真实 Git 扩展更新；单个、多选和批量更新流程已由隔离自动测试覆盖，未来自然出现更新时可补充观察，不阻塞 Phase 3 验收。
- 新增 `core/backup.sh` 与 `modules/sillytavern/backup-rules.sh`，统一实现 manual、protective、scheduled、catchup 四类备份及元数据。
- 统一备份范围覆盖整个 `data/`、`config.yaml` 和全局 `public/scripts/extensions/third-party/`；四种备份类型使用相同范围。
- `third-party/` 使用独立归档完整保存 Git 元数据、隐藏文件和普通文件；目录不存在时元数据与日志记录 `missing`，不会导致备份失败。
- 新格式恢复会同步恢复整个 third-party 快照；备份时为 `missing` 则恢复为目录不存在，旧格式备份则保持当前扩展目录不变。
- 备份验证升级为同时核对 data 与 third-party 归档可读性、各归档实际大小、总大小和元数据一致性。
- 主菜单新增“备份与恢复”，支持列表、手动备份创建、恢复、单个删除和安全多选批量删除。
- 备份用户界面统一显示“手动备份、保护备份、计划备份、补做备份”；内部和元数据继续使用 manual、protective、scheduled、catchup。
- manual 永不参与自动轮换；protective、scheduled、catchup 共用自动池并只保留创建时间最新 2 份。
- 删除操作只允许经过校验的备份根目录直属条目，自动删除显式拒绝 manual；批量删除单项失败不阻断后续项并写入日志。
- 恢复前先验证归档成员并创建 protective 备份，当前数据通过同目录暂存与移动替换，失败时尝试回滚，不直接递归删除当前 `data`。
- SillyTavern 本体更新在用户确认后先创建 protective 备份；保护备份失败会取消 Git 更新。
- 新增 `tests/test_backup.sh`，全部使用临时 SillyTavern、备份根目录与更新 Mock；完整本地测试由 9 项增至 10 项，结果 10/10 通过。
- Phase 8 的“自动进入 STermux”子功能提前独立实现，但 Phase 8 整体仍保持未开始，且不改变 Phase 4 待实机验收状态。
- 主菜单新增设置页面，可查看、开启和关闭 Bash 自动进入；默认配置为 `AUTO_ENTER_MANAGER=false`。
- 自动进入仅维护带有 `STermux autostart` 明确标记的 `.bashrc` 区域，修改前创建唯一备份，重复开启/关闭保持幂等。
- 生成入口使用当前实际 `STERMUX_ROOT/manager.sh`，只在交互式 Shell、入口文件存在且未设置防递归环境标记时运行；退出后返回原 Shell。
- 当前检测到 Zsh 或其他不支持 Shell 时只显示错误，不修改配置文件。
- 新增 `tests/test_autostart.sh`，使用临时 HOME、临时 `.bashrc` 和特殊字符项目路径；完整本地测试增至 11 项，结果 11/11 通过。
- 早期公开测试前补全新增 `core/uninstall.sh` 和 `tests/test_uninstall.sh`；设置页新增“卸载管理”。
- 卸载操作只处理用户明确选择的 STermux、有效 SillyTavern、有效备份或 autostart 托管块；不包含 `pkg uninstall`、`pkg remove` 或 `apt remove`。
- STermux 自删除在项目外生成一次性脚本并最后 `exec` 交接；脚本再次保护 `/`、HOME、PREFIX、SillyTavern 和缺少结构标记的目录，完成后自行清理。
- 扩展删除复用现有扫描清单与多选解析；Git / 非 Git 均可删除，单项失败不阻断后续项并写入现有扩展日志。
- 自动备份上限继续使用统一配置 `AUTOMATIC_BACKUP_KEEP`；允许 1 到 20，旧配置缺失或异常时安全回退到 2。
- 降低保留上限时默认取消；确认后 protective、scheduled、catchup 按时间统一轮换，manual 数量和内容保持不变。
- Bash 语法、卸载专项、扩展删除专项、自动备份上限专项与完整隔离回归通过；当前完整测试为 13/13。

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
| Bash 语法 | 通过 | Git Bash 通过 | 通过 | 已完成 |
| 全局 third-party 一级目录扫描 | Git/非 Git/空目录 Fixture 通过 | Git Bash 通过 | 识别 15 个一级扩展 | 已完成 |
| 中文、空格扩展路径 | 通过 | Git Bash 通过 | 扫描正常 | 已完成 |
| latest、可更新、非 Git 与失败状态 | 本地裸 Git 远程通过 | Git Bash 通过 | 分类显示正常；当时无可用更新 | 已完成 |
| 无 upstream 与 fetch 失败 | 通过 | Git Bash 通过 | 自动测试覆盖 | 已完成 |
| 单个与多选更新 | 非法编号过滤、逗号/空格和去重通过 | Git Bash 通过 | 自动测试覆盖 | 已完成 |
| 更新全部覆盖所有可更新 Git 扩展 | 包含遗留 manual 记录对应扩展，全部通过 | Git Bash 通过 | 自动测试覆盖 | 已完成 |
| 非 Git 扩展不执行 Git 更新 | 通过 | Git Bash 通过 | 自动测试覆盖 | 已完成 |
| 单项 pull 失败继续后续扩展 | 模拟 pull 失败后后续真实本地更新通过 | Git Bash 通过 | 自动测试覆盖 | 已完成 |
| 遗留 extension-policy.conf 失效 | 存在时不读取、不写入且不影响状态和更新 | Git Bash 通过 | 待按新版界面复测 | 本地通过 |
| 扩展更新日志 | 成功、失败、跳过记录通过 | Git Bash 通过 | 自动测试覆盖 | 已完成 |
| 扫描与更新不破坏未选扩展 | 隔离目录断言通过 | Git Bash 通过 | 扩展仍存在，无异常移动或删除 | 已完成 |
| 真实用户配置与扩展隔离 | 管理器 Fixture 与临时根目录通过 | Git Bash 通过 | 不适用 | 已完成 |

---

## Phase 4 测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| Bash 语法 | 通过 | Git Bash 通过 | 待测试 | 待实机验证 |
| manual 与四类元数据 | 临时数据 Fixture 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 归档非空、可读取与成功状态 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| third-party 正常备份与四类型统一范围 | manual/protective/scheduled/catchup 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| third-party Git 仓库与隐藏文件 | 实际 `.git`、扩展隐藏文件和根隐藏文件通过 | Git Bash 通过 | 待测试 | 本地通过 |
| third-party 不存在 | 备份成功、元数据与日志记录 missing | Git Bash 通过 | 待测试 | 本地通过 |
| 自动池混合类型仅保留最新 2 份 | protective/scheduled/catchup 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| manual 自动清理隔离 | 自动轮换和自动删除接口均拒绝 manual | Git Bash 通过 | 待测试 | 本地通过 |
| 列表时间、类型、大小和标识 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 单删、批删、取消、非法与重复编号 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 单项删除失败继续后续项 | 删除函数 Mock 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 根目录、越界、穿越和符号链接保护 | 临时外部哨兵通过；符号链接在兼容环境执行 | Git Bash 路径边界通过 | 待测试 | 本地通过 |
| 恢复与恢复前 protective | data、config.yaml、third-party 往返通过 | Git Bash 通过 | 待测试 | 本地通过 |
| third-party 同步恢复完整性 | Git/隐藏/普通文件恢复并移除快照外新增项 | Git Bash 通过 | 待测试 | 本地通过 |
| third-party missing 状态恢复 | 当前扩展先由 protective 保存，再同步恢复为不存在 | Git Bash 通过 | 待测试 | 本地通过 |
| 更新前 protective 联动 | 更新与失败路径 Mock 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 自定义 dataRoot 安全拒绝 | 通过，未写入成功备份 | Git Bash 通过 | 待测试 | 本地通过 |
| 真实用户配置、数据与备份隔离 | 临时项目与独立 Fixture 通过 | Git Bash 通过 | 不适用 | 本地通过 |
| 用户界面中文备份类型 | 手动/保护/计划/补做显示通过，英文内部标识保持 | Git Bash 通过 | 待测试 | 本地通过 |
| 自动备份上限默认、1、5 与非法输入 | 通过，允许范围 1 到 20 | Git Bash 通过 | 待测试 | 本地通过 |
| 提高上限与降低上限取消 | 不删除；取消后配置和备份均不变 | Git Bash 通过 | 待测试 | 本地通过 |
| 降低上限确认与立即轮换 | 三种自动类型统一排序，manual 保留 | Git Bash 通过 | 待测试 | 本地通过 |
| 配置持久化与旧配置回退 | user.conf 持久化、缺失字段回退 2 | Git Bash 通过 | 待测试 | 本地通过 |
| 完整回归 | 13/13 通过 | Git Bash 通过 | 待测试 | 本地通过 |

---

## Phase 5 测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| 默认关闭与旧配置安全默认值 | 开关 false、频率 7 天通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 开启、关闭与配置持久化 | 临时 user.conf 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 频率 1–30 天与无效输入 | 3/7 天、空值、文本、0、31、负数通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 未到时间不创建备份 | 固定 epoch 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 正常到期 scheduled | 真实 Phase 4 备份引擎与元数据通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 逾期 catchup 与多周期单份限制 | 错过 4 个周期只新增 1 份通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 成功后下一次时间计算 | 从成功 epoch + 当前频率计算通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 失败不更新状态并继续重试 | config.yaml 缺失失败、恢复后重试通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 同周期去重与并发启动锁 | 重复检查及活动 PID 锁通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 备份成功但状态提交中断 | 识别同到期 epoch 元数据，只补写状态不重复备份 | Git Bash 通过 | 待测试 | 本地通过 |
| 状态缺失与损坏恢复 | 只重建未来计划、不创建历史备份 | Git Bash 通过 | 待测试 | 本地通过 |
| 无效 SillyTavern 路径 | 安全跳过且状态不变 | Git Bash 通过 | 待测试 | 本地通过 |
| 关闭期间与重新开启 | 不触发；重新开启不补历史备份 | Git Bash 通过 | 待测试 | 本地通过 |
| 统一自动池与 manual 隔离 | protective/scheduled/catchup 共池，manual 保留 | Git Bash 通过 | 待测试 | 本地通过 |
| 自定义最大数量 | 现有 1–20 配置及即时轮换回归通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 首页状态与自动备份设置页 | 开启/关闭、频率、下次时间和数量通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 版本单一来源 | VERSION、首页、设置和自更新读取 v0.0.2 | Git Bash 通过 | 待测试 | 本地通过 |
| Bash 语法与完整回归 | 13/13 通过 | Git Bash 通过 | 待测试 | 本地通过 |

Phase 5 未经过 Android Termux 实机验证，因此不得标记为最终完成。

---

## Phase 8 自动进入子功能测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| 默认关闭与设置状态 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 开启与重复开启 | 单一托管区域、幂等通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 关闭与重复关闭 | 仅移除托管区域、幂等通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 用户原 `.bashrc` 保留与修改前备份 | 字节内容对比与备份文件通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 特殊字符 STermux 路径 | 实际启动 Fixture 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 交互式 Shell 限制 | 交互触发、非交互跳过 | Git Bash 通过 | 待测试 | 本地通过 |
| 防递归与退出后返回 Shell | 嵌套交互 Shell 仅启动一次，返回哨兵通过 | Git Bash 通过 | 待测试 | 本地通过 |
| manager.sh 不存在 | 安全跳过，Shell 正常退出 | Git Bash 通过 | 待测试 | 本地通过 |
| Zsh/不支持 Shell | 明确拒绝且配置不变 | Git Bash 通过 | 待测试 | 本地通过 |
| 真实 Shell 配置隔离 | 临时 HOME 与临时 `.bashrc` | Git Bash 通过 | 不适用 | 本地通过 |

该矩阵只代表 Phase 8 自动进入子功能；卸载管理另列于早期公开测试前补全矩阵，安装器发布与 Release 等 Phase 8 其余范围仍未开始。

---

## 独立终端 UI 优化测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| 已安装 / 未安装动态菜单 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 主菜单既有功能路由 | 隔离 manager Fixture 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| SillyTavern 本地版本与异常降级 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| STermux VERSION 单一来源 | 正常、缺失、异常通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 自动备份真实状态 | 读取真实开关；未安装时显示未开启 | Git Bash 通过 | 待测试 | 本地通过 |
| 颜色开关与 NO_COLOR | 开启、关闭、空值 NO_COLOR 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 非 TTY / TERM=dumb 降级 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| ANSI 与中英文显示宽度 | UTF-8 / C locale、固定宽度和状态间距通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 中文与中英文混排标题居中 | ANSI 开启 / 关闭均通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 设置页分组留白与信息入口 | 1–3、4–5、6 分组通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 卸载页主选项与灰色说明 | 白色主文字、灰色次级文字通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 扩展展示区、分隔线与精简菜单 | 菜单文案和入口路由通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 自动备份设置页排版 | 状态、频率、下次时间、数量与选项留白通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 完整回归 | 13/13 通过 | Git Bash 通过 | 待测试 | 本地通过 |

---

## 早期公开测试前核心体验补全测试矩阵

| 功能 | 本地测试 | Linux / 模拟 Termux | Termux 实机 | 状态 |
| ---- | -------- | ------------------- | ----------- | ---- |
| 卸载单选、多选、非法编号与去重 | 空格、逗号、过滤、去重通过 | Git Bash 通过 | 待测试 | 本地通过 |
| STermux 安全自删除 | 外部临时脚本、项目与内部备份删除通过 | Git Bash 通过 | 待测试 | 本地通过 |
| STermux 卸载保留 SillyTavern 与公共依赖 | 外部 SillyTavern 哨兵保留；无包卸载命令 | Git Bash 通过 | 待测试 | 本地通过 |
| autostart 删除与用户 Shell 配置保留 | 单独、组合、保留选择、重复关闭通过 | Git Bash 通过 | 待测试 | 本地通过 |
| SillyTavern 卸载与 ST_PATH 清理 | 有效 Fixture 删除并移除用户配置项 | Git Bash 通过 | 待测试 | 本地通过 |
| 卸载危险路径保护 | 空、`/`、HOME、PREFIX、错误 ST 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 全部备份统计与删除 | manual/protective/scheduled/catchup 数量和大小通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 组合去重、取消与部分失败 | 默认 N、备份不重复、失败后停止自删除通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 扩展 Git / 非 Git 单删与多删 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 扩展删除取消、非法、重复与失败隔离 | 通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 扩展删除日志 | 成功、失败日志通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 扩展根目录、越界、穿越与符号链接保护 | 外部哨兵通过；符号链接在兼容环境执行 | Git Bash 路径边界通过 | 待测试 | 本地通过 |
| 自动备份上限 1–20、持久化与轮换 | 默认 2、1、5、非法值、取消、确认通过 | Git Bash 通过 | 待测试 | 本地通过 |
| 完整隔离边界 | 临时 HOME/STermux/ST/备份/扩展/.bashrc/遗留策略文件 | Git Bash 通过 | 不适用 | 本地通过 |
| Bash 语法与完整回归 | 13/13 通过 | Git Bash 通过 | 待测试 | 本地通过 |

---

## 下一步

完成 Phase 5 定时自动备份、Phase 4 备份、终端 UI、早期公开测试补充与 Bash 自动进入子功能的 Android Termux 验收；实机通过前不进入 Phase 6，也不提前展开 Phase 8 其他范围。

---

## 最近一次阶段验收

2026-07-16：Phase 1 本地自动测试与 Android Termux 实机验收通过。

2026-07-16：Phase 2 更新中心、语义版本展示、技术详情、更新历史及测试隔离通过 Android Termux 实机验收。

2026-07-16：Phase 2.5 在纯净 Android Termux 完成依赖安装、完整 clone、路径保存和首次启动验收。

2026-07-16：Phase 2.6 在 Android Termux 成功检测 upstream 新 Commit、显示可用更新并完成 fast-forward 自更新，阶段验收通过。

2026-07-16：Phase 3 在 Android Termux 成功扫描 15 个 third-party 一级扩展，Git/非 Git 分类通过，阶段验收完成。当时通过的 manual 策略已在 2026-07-17 的交互精简中正式停用。

2026-07-16：Phase 4 备份范围扩展至 data、config.yaml 和全局 third-party；Git/隐藏文件、目录缺失与同步恢复回归通过。Bash 语法及完整 10/10 回归通过，等待 Android Termux 实机验收。

2026-07-16：备份界面类型完成中文化；Phase 8 自动进入子功能完成本地实现与隔离测试，完整回归 11/11 通过，Phase 4 状态保持待 Android Termux 实机验收。

2026-07-17：独立终端 UI 基线重整完成本地实现。新增 `VERSION v0.0.1`、动态分组首页、简洁设置页、统一颜色与纯文本降级；Bash 语法和完整隔离回归 11/11 通过，Phase 4 状态未改变。

2026-07-17：早期公开测试前核心体验补全完成本地实现。卸载管理、扩展安全删除与自动备份上限设置专项测试通过，完整隔离回归 12/12 通过；Phase 4 和 Phase 8 整体状态均未提前改变，等待 Android Termux 实机验收。

2026-07-17：终端 UI 与第三方扩展交互完成精简。标题按可见宽度居中，设置和卸载页层级整理，扩展菜单统一为检查、选择更新、更新全部、删除及技术详情；manual 策略及运行时读写彻底移除，遗留文件保持原样且不影响行为。专项与完整隔离回归通过，等待 Android Termux 目视和交互复测。

2026-07-17：Android Termux 截图复测发现中文标题仍偏右且“自动备份”标签间距过大。根因为 UTF-8 locale 下 Bash 已按完整字符切片，旧算法仍按 UTF-8 字节长度跳过后续字符，造成中文宽度严重低估。公共宽度函数现已区分完整字符与 C locale 字节切片；固定宽度、双 locale、精确状态间距及完整 12/12 回归均通过，等待 Android Termux 再次目视确认。

2026-07-18：Phase 5 定时自动备份完成本地实现。新增默认关闭的开关、每 1–30 天频率、启动时单次 epoch 检查、scheduled / catchup 区分、失败重试、状态损坏恢复与并发检查锁；继续复用 Phase 4 备份引擎和统一自动池。VERSION 更新为 `v0.0.2`，Bash 语法、Phase 5 专项及完整 13/13 隔离回归通过，等待 Android Termux 实机验收。
