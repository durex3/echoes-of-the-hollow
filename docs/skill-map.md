# Skill 如何落实到工程

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

安装了但暂未使用的 Godot Shader 等技能不强行加入工程；需求出现时再读取和应用。

0.9.0：level-design 增加两种连续输入通关及战前路程测量；save-systems 同样用于独立设置的版本/验证/临时文件/备份恢复；game-ui-ux 用于可滚动设置、焦点跟随、覆盖确认、地图印记和目标。godot-animation 修复普通铠甲帧表，按实际片段长度驱动表现而不改战斗规则。
