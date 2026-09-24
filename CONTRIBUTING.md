# 贡献与日常开发

先阅读 `AGENTS.md`、`docs/development-workflow.md`、`docs/architecture.md`。

1. 新任务先明确触发条件和验收，不先增加抽象框架。
2. 使用 `feat/<topic>` 或 `fix/<topic>` 短分支，保持 main 可运行。
3. 行为修改补对应检查，地图/画面修改补截图和试玩。
4. 提交前运行 `tools/check.ps1` 和 `git diff --check`。
5. 同一提交更新相关说明与 CHANGELOG；不提交 .godot、artifacts、玩家存档和导出包。
6. 不公开提交尚未核对分发授权的素材。当前为本地工程。

新机器：安装 Godot 4.7.2、Python 3、Git；设置 GODOT_BIN 或向脚本传 GodotPath。
首次打开由引擎自动导入，之后直接运行与测试。不要重复运行初始场景生成器覆盖内容。
