# 本机 Skills 清单与换机交接

本清单按 Windows 开发机实际目录核对：37 个用户级 skill 文件夹均含 `SKILL.md`。它们是开发助手的工作方法，不是 Godot 插件，也不是游戏运行依赖。克隆本仓库会取得此清单和工程文档，**不会自动安装这些 skills**。

工程应用记录见 [技能到工程的映射](skill-map.md)，下一步任务见 [开发交接与下一步](next-development.md)。本机路径只用于找到待迁移文件，不应写入游戏运行代码。

## 本机位置与迁移范围

| 类型 | Windows 本机位置 | 换机处理 |
|---|---|---|
| 用户安装的 skills | `C:\Users\liuge\.codex\skills\<名称>\SKILL.md` | 复制需要的完整 skill 文件夹，包括引用的 scripts、references、assets 等文件 |
| 客户端管理的系统 skills | `C:\Users\liuge\.codex\skills\.system\` | 由目标客户端提供或更新，不用旧电脑的整个 `.system` 覆盖 |
| 插件提供的 skills | `C:\Users\liuge\.codex\plugins\cache\` 下的插件包 | 在目标客户端重新安装所需插件；不要把缓存目录当成安装包 |
| 工程约定与任务记录 | 仓库中的 `AGENTS.md`、`docs/` | 已随 Git 保存；在新机器继续开发前先读 |

## 本机用户级清单（37 个）

优先级表示对本项目的用途，不代表每次开发都必须读取所有 skills。名称与目录一一对应。

| 分类 | Skill 名称 | 本项目用途 |
|---|---|---|
| 关卡与玩法设计 | `level-design`、`game-design-theory`、`platformer`、`prototype-fast` | 第三关可达性、教学到组合、回环、难度与小范围验证；优先迁移 |
| 基础敌人决策 | `game-ai` | 独立敌人 FSM、选招、距离、边缘/墙体和反击窗口；优先迁移 |
| Godot 脚本与组合 | `godot-gdscript`、`godot-nodes-scenes`、`godot-signals-groups`、`godot-resources` | 类型、原生场景、事件接线、只读配置与实例状态；优先迁移 |
| Godot 移动与地图 | `godot-2d-movement`、`godot-physics`、`godot-tilemap` | 物理帧移动、真实伤害、可编辑 TileMapLayer；优先迁移 |
| 角色、美术与反馈 | `create-game-assets`、`godot-animation`、`game-feel`、`camera-systems`、`godot-shaders`、`shader-programming` | 素材许可/帧表/比例、动画与攻击同步、命中反馈、镜头与材质；按任务使用 |
| 输入、存档、界面 | `input-systems`、`save-systems`、`godot-ui-control`、`game-ui-ux` | 能力输入、跨章存档、三章地图与双语 HUD；正式接线前准备 |
| 音频 | `godot-audio`、`audio-design` | 音频总线、音效反馈、后续音乐与混音 |
| 性能与运动调试 | `performance-optimization`、`physics-tuning` | 有实测问题时排查，不为换机预先改物理或架构 |
| 发布与限时制作 | `godot-export`、`itch-publish`、`game-jam` | 内容完成后的打包/发布，或明确限时任务；当前非优先 |
| 按需工具 | `ai-behavior-trees-utility-ai`、`procedural-gen`、`game-engine`、`relay-imagegen` | 已安装；本项目不因此引入行为树框架、随机地图、Web 引擎或图片生成服务 |
| Three.js 专项 | `threejs-game-ui-designer`、`threejs-gltf-loading`、`threejs-materials-lighting`、`threejs-scene-setup` | 已安装；不属于当前 Godot 工程依赖 |

本次仅核对目录与入口文件，没有核实每个用户 skill 的原始下载地址、提交版本或跨平台脚本兼容性。为保留当前工作方法，优先迁移本机完整文件夹；若选择重装，应核对同名技能的来源与内容，不能仅凭同名认定相同版本。

## 系统与插件技能

本机 `.system` 目录另有 `imagegen`、`openai-docs`、`plugin-creator`、`review-agent`、`skill-creator`、`skill-installer`。目录存在不等于目标客户端一定会将它们列为可用；以新会话实际显示的技能为准。

当前开发环境另提供文档、PDF、演示文稿、表格、可视化、计算机操作及模板制作等插件技能。这些不是上述 37 个用户文件夹，也不是继续第三关必需的依赖；按新机器实际支持的插件重新配置。Windows 计算机操作工具不可视为 Mac 上的等价能力。

## Mac 迁移步骤

1. 在 Windows 打开 `C:\Users\liuge\.codex\skills`，把上表需要的用户级文件夹复制到 U 盘或个人传输目录。复制整个文件夹，不只复制 `SKILL.md`；不要复制整个 `.codex` 用户目录。
2. 在 Mac 先安装并打开开发客户端，确认该版本实际识别的用户技能目录，再将完整文件夹放进去。本机 `.codex/skills` 是已核实的 Windows 来源位置，不能据此保证所有 Mac 客户端版本都使用相同位置。若目标客户端明确使用 `~/.codex/skills`，才使用该对应目录。
3. 保留目标机器已有的同名技能，先比较内容再决定替换；不要覆盖客户端管理的 `.system` 或照搬插件缓存。重开项目会话，核对需要的技能是否出现，并试读 `level-design` 和 `godot-gdscript` 的入口及相对引用文件。
4. 个别技能附带的脚本可能有 Windows 路径或系统依赖，使用前单独检查。`relay-imagegen` 的服务配置与凭据不属于迁移清单；只有需要生成图片时再在新机器单独配置。
5. 在新机器先读 `AGENTS.md`、`README.md`、`docs/architecture.md` 和本次交接文档；只按当次任务读取相关 skills。用户要求和工程约定优先于 skill 示例，不能照搬示例引擎版本、数值或 API。

本仓库只记录清单与交接说明，没有收录这些技能的全文，也没有把凭据、用户设置或本机缓存加入 Git。Mac 上的安装识别和技能脚本执行尚待实际验证。
