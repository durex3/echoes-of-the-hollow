# Skill 如何落实到工程

2026-09-27第三关前半段实现：create-game-assets先核对原包/许可与固定锚点，再导入12张原图并查看实际800×450左右攻击截图；godot-animation/godot-physics把状态、显示帧、凹形法术查询及身体去重统一到物理时钟；game-ai分别实现杖使双式和蝙蝠锁旧站位/低位收招；level-design根据实测把压力竖井拆成两段224px、每段3次壁跃与中继平台；godot-tilemap/godot-nodes-scenes保存五个可编辑房间、稳定门/出生点和独立试玩宿主。见[tasks/chapter_three_preview.md](tasks/chapter_three_preview.md)。没有为了套用skill引入新框架；图形初版和真人难度仍需反馈。

2026-09-27第三关设计：level-design落实移动指标/白盒/能力回环与休整；game-design-theory落实新能力与生命奖励、选择和渐进掌握；game-ai约束两敌/Boss的读招、锁向和组合窗口；create-game-assets只读盘点课程素材并明确完整动作缺口；save-systems将环境修复、能力、机关、生命与Boss胜利分开。方案见[tasks/chapter_three.md](tasks/chapter_three.md)，未把设计或候选数值标成已实现。第二关旧档修复使用save-systems与godot-gdscript，验证真实旧进度的首领出场和隔离存档回归。

2026-09-27：create-game-assets用于外部骑士的许可/摘要、接触表和实景比例审核；godot-animation将原图动作绑定到伤害阶段并保留逐次按键左右手交替；godot-shaders用于蓄力染色、轮廓光和残影，校验Nearest与暗部细节；godot-physics核对身体接触、护盾去重、薄墙扫掠和火墙高台判定。game-ai与level-design用于两种独立Boss节奏、固定战斗房及门/地图一致性。工程经验已归入[执行规则](../AGENTS.md)与[开发复盘](development_lessons.md)。

0.14.0：`level-design` 用现有玩家跳高与速度限定低裂焰、标记预警和休整窗口；`game-ai` 用有限状态明确预警/施法/泄压/转阶段，保证反击读得懂；`create-game-assets` 核验同课程图源、登记摘要和游戏内选帧；`godot-animation` 将动作帧速度匹配状态时间；`godot-gdscript` 与 `godot-nodes-scenes` 保证物理帧状态、独立原生场景、父场景接线。验证使用真实碰撞、两条正常输入主线、隔离存档和视觉截图。

0.10.1：`create-game-assets` 用于先核对课程图集、记录统一素材与独立章节风格、选区/来源/游戏内截图验收；`godot-tilemap` 将第二关砌石地表与无碰撞建筑背景保存在独立原生层，不在运行时重建地图。没有使用其他包的3D素材或生成图片。

0.10.0 第二关：使用 `level-design` 的移动实测、先教学后组合、张弛节奏和双支路汇合；`godot-tilemap` 将四个显式布局保存为可编辑原生场景，制作工具拒绝覆盖；`godot-resources` 将蒸汽数值保存为只读 SteamConfig，各喷口独立持有时钟；`godot-gdscript` 落实类型与物理帧状态。测试以两种连续输入路线、真实碰撞/时序、跨进程存档和中英文截图验证。没有为应用技能引入新框架。

采用本机安装的技能作为工作方法，Godot 4.7.2 实际运行结果作为兼容性证据；不盲复制示例版本或未验证 API。

| Skill | 工程中的落点 | 验收方式 |
|---|---|---|
| godot-gdscript | 类型标注、生命周期、export、物理帧 | 原生导入/解析 |
| godot-nodes-scenes | Player/Enemy/InkBolt/Room 可复用场景与入口接线 | 独立实例、弹体归属和切房释放 |
| godot-signals-groups | 血量、死亡、进度、交互事件 | HUD/复活/换房断言 |
| godot-resources | PlayerConfig、AttackProfile、ArmorConfig、ScribeConfig | 跳跃实测、攻击阶段、独立弹体测试配置 |
| godot-2d-movement / platformer | CharacterBody2D、缓冲、宽限、短跳、双跳、固定距离冲刺 | 真实物理与关卡攀升、111.6px 位移、空中次数/冷却/墙体 |
| godot-physics | Hitbox/Hurtbox、边缘/视线射线、墨弹扫掠 | 去重、无敌、2px 薄墙、最近碰撞和释放 |
| godot-animation | SpriteFrames 原生图集与状态动画 | 实际帧渲染检查 |
| godot-tilemap | 原生 TileSet/TileMapLayer、可编辑持久场景 | 地面碰撞与地图数据检查 |
| input-systems | 命名动作、键盘/手柄按钮重绑、冲突拒绝、保留暂停键、设备提示 | 实际按键事件跳跃、冲突/取消/恢复/持久化；手柄硬件待验收 |
| level-design | 移动指标先行、能力先于门槛、教学/掩体/组合、三印支路汇合与战前休息段 | 正常跳/双跳、冲刺开门、八房间门槛图可达、缺印组合与前庭往返实测 |
| save-systems | schema 1→2 迁移、临时文件、备份、世界标记、准确检查点、由唯一奖励推导生命上限 | 旧档/坏档/未知版本/跨进程、奖励不重复、死亡/重建玩家恢复 |
| game-ai | 铠甲七状态 FSM；守门者独立九状态、锁向交替攻击、收招后转阶段 | 预警/反击/隔墙/半血/撤退/死亡/同帧结算回归；难度待试玩 |
| camera-systems | Camera2D 平滑、前视、房间边界、重置 | 截图；动态手感待试玩 |
| godot-ui-control / game-ui-ux | 原生容器、主题、按钮焦点、房间地图、即时双语切换、独立奖励卡片 | 中英文菜单/地图/奖励图形复核、焦点保持、暂停保留阅读时间、设置跨进程 |
| godot-audio | Music/SFX 独立音量、零值静音、首领预警音调、场景切曲与清理 | 实际总线值/图形加载/退出；听感待验收 |
| game-feel | 命中粒子、轻微镜头偏移、击退、闪白及辅助设置 | 挥空无反馈、粒子释放、镜头归零、开关存取、图形回归 |
| create-game-assets | 原图检查、帧网格、复制不改源、来源摘要 | manifest + 图形复核 |
| prototype-fast | 把首版限定为一个可验证探索闭环 | M1 门禁；后续实验单独隔离 |
| godot-export | Windows 预设、固定引擎、CLI 检查 | 导出包测试尚待执行 |

其他已安装但与当前任务无关的技能不强行加入工程；需求出现时再读取和应用。

2026-09-27第三关首轮落地：level-design要求先实测移动再定几何，完成旧能力与壁跃指标、原生回环白盒和九房间视线/教学/组合/休整/捷径规格；game-ai用于杖使双式与飞行掠袭的独立FSM和安全组合设计，尚未冒称敌人已实现。godot-gdscript、godot-2d-movement、godot-nodes-scenes落实Player组件、物理碰撞法线、只读Resource和明确墙标记；create-game-assets保持原包、完整帧核验与实际显示尺度。全量回归通过，正式关卡及真人难度待后续验证。

0.13.1：godot-gdscript为Hurtbox定义明确的IGNORED/DAMAGED/BLOCKED结果，Hitbox对挡住的同次挥击去重；godot-signals-groups保持Player组合并接入自身防护回调、damage_blocked表示已发生的抵挡、伤害反馈仅在实际扣血时发出。粉焰剑士/宝箱/墨弹真实场景验证，不以检查技能函数返回值替代玩法回归。

0.13.0：input-systems将steam_ward纳入InputMap、双设备提示、重绑和菜单释放输入规则，兼容旧动作占用新默认键；save-systems落实旧心权益保留、校验后幂等补能力、保存失败后重试、新旧档跨进程验证；godot-gdscript落实只读能力Resource、实例计时、物理帧推进与事件驱动HUD。实现、测试、图形复核、文档和本地提交遵循development-workflow.md，人工验收与自动检查分别记录。

0.12.0：level-design将第二关改为七房间上下层回环、两条解锁捷径、可选二段跳秘库与先教学再组合的节拍，约束记录在level_progression.md；game-ai为粉焰剑士实现独立后撤突斩FSM；create-game-assets核对原课程80×80帧表并复制未用图集；godot-tilemap将新房间持久化为可编辑原生TileMapLayer并拒绝重建覆盖；godot-gdscript负责类型、物理帧时序和父场景接线。主线与可选路线真实输入验证，章节敌人不重叠有自动断言。

0.9.0：level-design 增加两种连续输入通关及战前路程测量；save-systems 同样用于独立设置的版本/验证/临时文件/备份恢复；game-ui-ux 用于可滚动设置、焦点跟随、覆盖确认、地图印记和目标。godot-animation 修复普通铠甲帧表，按实际片段长度驱动表现而不改战斗规则。
