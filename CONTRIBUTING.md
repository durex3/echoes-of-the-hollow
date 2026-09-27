# 贡献与日常开发

先阅读 `AGENTS.md`、`docs/development-workflow.md`、`docs/architecture.md`。

当前状态与下一个任务见[开发交接](docs/next-development.md)，本机技能依赖见[Skills 清单](docs/local-skills.md)。第三关五房间独立试玩已实现，下一项内容任务为双支路和承重回桥。

1. 新任务先明确触发条件和验收，不先增加抽象框架。
2. 使用 `feat/<topic>` 或 `fix/<topic>` 短分支，保持 main 可运行。
3. 行为修改补对应检查，地图/画面修改补截图和试玩。
4. 行为变更运行 `tools/check.ps1`；共享移动/战斗、存档或章节流程加 `-Full`；视觉变更加 `-Visual` 并实际看图。纯文档变更检查链接、状态和 `git diff --check`，不冒称重新跑过玩法。
5. 同一提交更新相关说明与 CHANGELOG；不提交 .godot、artifacts、玩家存档和导出包。
6. 不公开提交尚未核对分发授权的素材。项目已按用户授权推送 GitHub；这不等于所有素材都获得公开再分发许可，也不代表已制作发布包。

新机器：准备匹配的 Godot 4.7.2、Python 3、Git；沿用 `.ps1` 检查入口时还需要 PowerShell，设置 GODOT_BIN 或向脚本传 GodotPath。Mac 的客户端技能目录、Python 命令和 Godot 可执行路径需实际确认，`.cmd` 不作为 Mac 启动方式。
首次打开由引擎自动导入，之后直接运行与测试。不要重复运行初始场景生成器覆盖内容。提交保留 `.uid`/`.import`；测试用 `user://test_*` 与玩家档隔离。详见[换机检查](docs/next-development.md#mac-接手检查)。
