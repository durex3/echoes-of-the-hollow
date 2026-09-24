# 空谷回响 / Echoes of the Hollow

Godot 4.7.2 + GDScript 的 2D 类银河恶魔城工程基础，使用本机《类银河恶魔城锻造坊》素材。
当前版本 **0.1.0：两个可往返房间的探索原型**。这是继续开发的工程起点，不是完整商业游戏。

## 立即运行

1. 双击根目录 `Play.cmd` 运行；或双击 `Open-Editor.cmd` 打开编辑器，按 F6 运行当前场景、F5 运行整个项目。
2. 启动器优先使用 `E:\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`。
3. 也可以在 Godot 项目管理器导入此目录的 `project.godot`。无需安装插件、Python 包或 .NET。
4. 双击 `Check.cmd` 运行项目规范、引擎导入、行为测试与跨进程存档检查。

命令行（在项目根目录运行）：

```powershell
.\tools\run.ps1 -Editor
.\tools\run.ps1
.\tools\check.ps1
.\tools\check.ps1 -Visual
# 换电脑后显式指定，不必修改工程：
.\tools\run.ps1 -GodotPath 'D:\Tools\Godot.exe'
```

`-Visual` 会开启短暂的测试窗口并生成 `artifacts/` 截图；普通检查不打开窗口。
开发检查需要 Python 3（仅标准库，用于静态检查）；运行游戏本身只需要 Godot。

## 当前玩法

- A/D 或方向键移动；空格跳跃，短按跳得低，长按跳得高。
- J 挥剑；E 与附近存档点、门、能力和终点交互。
- ESC 暂停/继续；M 静音。
- 手柄初始映射：左摇杆/方向键移动、底部按钮跳跃、左侧按钮攻击、顶部按钮交互、Start 暂停。实体手柄验收待完成，界面当前显示键盘提示。
- 森林向右进入遗迹，跳上两级平台获得二段跳；返回森林，登上较高祭坛并交互完成原型。
- 存档点恢复生命并保存；能力获取和终点也保存。死亡回到最近存档点，小怪随房间重载刷新。
- 主菜单存在有效存档时显示 Continue；新游戏在下一次保存时覆盖原存档，菜单有提示。

## 工程导航

```text
app/                  主入口与游戏流程接线
core/                 会话状态、纯数据存档、音频服务
features/
  player/             玩家场景、状态、动画资源、可编辑配置
  combat/             生命、攻击区、受击区可复用组件
  enemies/            史莱姆场景与行为
  world/              房间、TileSet、交互点、背景、rooms/*.tscn
  ui/                 原生 Control/Container 界面
assets/               当前使用/预留的素材与来源清单
tests/                真场景/真物理集成测试，跨进程存档测试
tools/                启动、检查、首次资源整理工具
docs/                 设计、架构、流程、测试与决策记录
artifacts/            本机检查日志和截图（不提交）
```

## 文档阅读顺序

1. [开发流程](docs/development-workflow.md)：需求 → 实现 → 自动检查 → 试玩 → 文档 → 提交。
2. [架构与编码规范](docs/architecture.md)：模块职责、信号、碰撞层、数据边界。
3. [玩法与关卡设计](docs/game-design.md)：范围、路线、移动指标和存档规则。
4. [测试与验收](docs/testing.md)：命令、覆盖范围、手动验收和故障定位。
5. [首版测试记录](docs/verification.md)：实际执行结果与尚未验证项。
6. [里程碑](docs/roadmap.md)：后续工作和每阶段的退出条件。
7. [技能到工程的映射](docs/skill-map.md)：采用哪些 skill，如何落实。
8. [技术决策](docs/decisions/0001-project-baseline.md)：为什么这样组织。
9. [变更记录](CHANGELOG.md)、[贡献约定](CONTRIBUTING.md)、[任务模板](docs/templates/task.md)。

## 素材与范围

原始桌面素材保持不变；复制文件的源路径与 SHA-256 在 `assets/manifest.json`。
解压章节未附完整授权文本，因此来源已记录、授权状态标为待核对，尚未公开发布工程或素材。
本版未实现 Boss、完整地图 UI、冲刺、按键重绑、中文游戏界面及正式发布包；详见路线图。
