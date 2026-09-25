# Skill 如何落实到工程

采用本机安装的技能作为工作方法，Godot 4.7.2 实际运行结果作为兼容性证据；不盲复制示例版本或未验证 API。

| Skill | 工程中的落点 | 验收方式 |
|---|---|---|
| godot-gdscript | 类型标注、生命周期、export、物理帧 | 原生导入/解析 |
| godot-nodes-scenes | Player/Slime/Room 可复用场景与入口接线 | 独立实例与切房 |
| godot-signals-groups | 血量、死亡、进度、交互事件 | HUD/复活/换房断言 |
| godot-resources | PlayerConfig、AttackProfile、ArmorConfig | 跳跃实测、攻击阶段边界 |
| godot-2d-movement / platformer | CharacterBody2D、缓冲、宽限、短跳、双跳 | 真实物理与关卡攀升 |
| godot-physics | 命名碰撞层、Hitbox/Hurtbox、边缘射线 | 去重伤害、无敌、敌人释放 |
| godot-animation | SpriteFrames 原生图集与状态动画 | 实际帧渲染检查 |
| godot-tilemap | 原生 TileSet/TileMapLayer、可编辑持久场景 | 地面碰撞与地图数据检查 |
| input-systems | 命名动作、键盘/手柄映射 | 模拟动作；手柄硬件待验收 |
| level-design | 移动指标先行、能力获取先于门槛 | 正常跳/双跳实测 |
| save-systems | schema 1→2 迁移、临时文件、备份、世界标记、准确检查点 | 旧档/坏档/未知版本/跨进程 |
| game-ai | 铠甲七状态 FSM、视线、锁向、前方边缘检测 | 预警/反击/隔墙/边缘回归；手感待试玩 |
| camera-systems | Camera2D 平滑、前视、房间边界、重置 | 截图；动态手感待试玩 |
| godot-ui-control | 原生容器、主题、按钮焦点 | 菜单/暂停图形回归 |
| godot-audio | Music/SFX 总线、场景切曲、清理 | 图形模式加载与退出 |
| game-feel | 命中粒子、轻微镜头偏移、击退、闪白及辅助设置 | 挥空无反馈、粒子释放、镜头归零、开关存取、图形回归 |
| create-game-assets | 原图检查、帧网格、复制不改源、来源摘要 | manifest + 图形复核 |
| prototype-fast | 把首版限定为一个可验证探索闭环 | M1 门禁；后续实验单独隔离 |
| godot-export | Windows 预设、固定引擎、CLI 检查 | 导出包测试尚待执行 |

安装了但暂未使用的 Godot Shader 等技能不强行加入工程；需求出现时再读取和应用。
