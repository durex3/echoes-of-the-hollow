# 开发交接与下一步

## 接手位置

- 仓库：`https://github.com/durex3/echoes-of-the-hollow.git`。
- 当前交接分支：`fix/enemy-art-separation`；玩法基线提交：`3ba389f`（本交接文档在其后补充）。换机应拉取该分支最新提交，不要仅检出基线而漏掉文档。
- 固定工程约定：Godot 4.7.2 标准版、GDScript、Compatibility；目标机器安装对应引擎前先确认实际版本，不擅自降级项目或改检查脚本绕过版本校验。
- 阅读顺序：`AGENTS.md` → [README](../README.md) → [架构](architecture.md) → [开发经验](development_lessons.md) → 本文 → [第三关场景规格](tasks/chapter_three_scene_plan.md)。技能迁移见 [本机 Skills 清单](local-skills.md)。

## 已完成与边界

第一、二关主线仍由 `app/main.tscn` 启动。第三关目前是 **9 个原生房间的独立试玩**：风蚀阶庭、守钟外廊、断钟中庭、回音修院、悬铃回廊、承钟机室、静声藏室、合鸣桥廊、终钟台。壁跃、鸣石、法师与铃翼技能、双承重回桥、可选生命奖励和缚钟守望者第一可玩切片已接入。试玩进度仍只在内存。

试玩入口为 `features/world/prototypes/bell_court_preview.tscn`。默认 6HP，具备二段跳、冲刺和护盾；踏壁在试玩中领取。另有 5HP 无盾的基线检查。试玩进度只在内存中，不写主线存档。

**尚未完成：**缚钟守望者 Boss 的完整真人难度验收、第三关正式章节入口/地图/存档/结局。双支路、承重回桥、钟庭之心、合鸣桥廊和 Boss 第一可玩切片已在独立试玩中接入；试玩仍不是完整第三关，第三关整体难度高于第二关仍需终局验收。

## 下一项实际开发：Boss 验收与正式主线接线

Mac 的导入、试玩和检查入口已完成。Windows 换机后先拉取本分支并复跑检查。下一项内容是 **缚钟守望者完整组合与真人难度验收，以及第三关正式主线接线**；不重建手工地图。

1. 核对终钟台 Boss 的镰刀、印记、幽魂组合，检查伤害去重、边界、死亡清理与可读反击窗口。
2. 用默认 6HP/护盾和 5HP 无盾基线进行真实输入路线，并记录真人首次理解、失败原因和休整节奏。
3. 将入口、地图/HUD、踏壁、钟庭之心、双回桥、Boss 胜利和结局接入 `Session`/`SaveRepository`，再验证旧档与跨章往返。
4. 先沿用实测的可达范围；新组合跳跃必须先隔离测量再定平台。机关与法术不能同时封死唯一落脚点。

本任务交付已包含原生场景、两种顺序的真实输入路线、门两端/出生点检查、桥面截图和状态记录。默认 6HP 与 5HP 无可选盾分别留证；自动通过不等于真人觉得合理、有趣或更难。

## 后续开发顺序

| 顺序 | 交付 | 验收重点 | 相关 skills |
|---|---|---|---|
| 0 | Mac 开发基线 | 导入/运行现有工程；适配启动与检查入口；记录 Mac 实测结果，不改玩法凑兼容 | `godot-gdscript` |
| 1 | 两支路、承重和回桥 | 已完成第一版：两种先后顺序、真实返回捷径、门两端一致 | `level-design`、`godot-tilemap`、`godot-nodes-scenes`、`godot-resources` |
| 2 | 静声藏室与钟庭之心 | 已完成第一版：可选壁跃/二段跳/冲刺路线，失败回安全下层；唯一 +1 上限与一次回血 | `platformer`、`level-design`、`save-systems` |
| 3 | 合鸣桥廊 | 已完成第一版：两承重后开启；杖使与铃翼组合；后段安全祭坛 | `game-ai`、`level-design`、`game-feel` |
| 4 | 终钟台与缚钟守望者 | 第一版已接入：镰刀横扫、锁向突进、回声印记、低血量幽魂阶段、固定单屏与战前重试点；完整组合和真人难度仍待验收 | `create-game-assets`、`godot-animation`、`godot-physics`、`game-ai`、`game-feel` |
| 5 | 正式主线集成 | 第二关入口门槛、第三页地图/HUD、能力/奖励/桥/Boss/结局保存、跨章往返与旧档 | `save-systems`、`godot-signals-groups`、`godot-ui-control`、`game-ui-ux` |
| 6 | 整章回归与真人难度验收 | 两种支路顺序、可选路线、5HP 无盾主线；首次理解、失败原因、迷路/折返与第二关对比 | `level-design`、`game-design-theory` |

步骤 2 的奖励在独立试玩阶段明确为内存状态；步骤 5 完成后才能宣称永久奖励已进入主线。生命上限按奖励推导：基础 5 + 第一关生命花 1 + 第三关钟庭之心 1，收齐为 7；第二关水闸奖励不增加上限。主线不得强制领取可选生命或护盾。

Boss 使用已登记的 `Bringer-Of-Death` 精选图集；项目副本、`.import`、许可文本和 SHA-256 随 Git 交接，完整原包不提交。无需为运行试玩重新下载；新增原包动作时仍须核验脚底、比例、来源和授权。正式发布许可审核尚未完成。

## Mac 接手检查

```bash
git clone --branch fix/enemy-art-separation https://github.com/durex3/echoes-of-the-hollow.git
cd echoes-of-the-hollow
```

在 Godot 项目管理器导入 `project.godot`，先等资源导入完成，再分别运行主场景和第三关试玩场景。保留版本控制中的 `.uid` 和 `.import`，让目标机器重新生成被忽略的 `.godot` 缓存。

现有 `.cmd` 是 Windows 启动器，Windows 检查入口仍是 `tools/check.ps1`。macOS 使用 `tools/run.sh`、`tools/check.sh`；后者需要 Python 3 和可执行的 Godot 路径，默认查找 `/Applications/Godot.app/Contents/MacOS/Godot`，也支持 `GODOT_BIN` 或 `--godot PATH`。两套入口共用相同测试场景，不能因平台切换减少检查范围。Mac 已完成导入和全量无头回归；图形显示与真人输入体验仍需单独验收，详见[验证记录](verification.md)。

如果新增 shell/Python 检查入口，必须与现有检查覆盖保持一致，包括法师真实反击扣血、三章 AI、壁跃、第三关默认/基线路线、前两章路线和跨进程存档；不能只测引擎能启动。玩家正式存档与测试档继续隔离；玩家存档、完整下载素材包、本机 skills 不会通过 Git 自动同步。

## 验证与保持项

玩法基线 `3ba389f` 在 Windows 完成 `tools/check.ps1 -Full -Visual`；Mac 已完成 `tools/check.sh --full`，结果见[验证记录](verification.md)。Mac 图形检查与真人体验仍待完成。

- 每个行为变更运行 `tools/check.ps1`；共享移动/战斗、存档或章节流程加 `-Full`；视觉变化加 `-Visual` 并看实际截图。Mac 新入口要执行相同检查。
- 保留已认可的主角操作、两章地图与 Boss 身份、法师比例/技能、铃翼尖啸和踏壁辅助；只针对新增任务或可复现问题调整。
- 小怪连续受击仍正常扣血；反击必须在真实生效帧命中玩家，不能把玩家移动到有利位置凑测试。祭坛及 Boss 入口保存不回血。
- 不覆盖玩家存档，不重跑生成器覆盖手工房间，不提交缓存/测试截图/原始下载包，不修改桌面原素材。
- 内容开发优先；Windows 发布包、浏览器适配和发布验收仍在内容完成后推进。Mac 开发验证不等于 Mac 发布包验收。
