# 第三关素材盘点与手动下载清单

2026-09-27。状态：三个角色包均已由用户解压到artifacts/downloads；完整静态动作、尺寸与透明边距已检查，合成比例对照已查看。无需重复下载。Evil Wizard 2与Bat的12张使用中PNG已正式复制、登记摘要/许可并导入原生SpriteFrames；已进入前半段实机检查。Bringer仍待Boss阶段正式导入。详情见[前半段实现](chapter_three_preview.md)。

对应[第三关设计](chapter_three.md)。保持已确定的能力成长、探索回环和难度节奏；角色武器与招式表现需在看到完整原图后定稿。

## 原资源优先

- 只读检查了桌面课程目录全部文件及7个ZIP的文件清单。6章压缩包与DoomScribe.zip没有额外隐藏的新角色；现有主角、史莱姆、铠甲、施法者、宝箱及粉色Boss已经用于前两关。
- 环境继续用课程的forest.png图集：砌石、拱柱、堡垒边缘、木梁与平台可组合成高庭/断桥。门、开关、能力图标、祭坛沿用已有资源，不另下载整套地图替换风格。
- 课程中尚未接入的dust_effects.png可优先评估用于壁跃脚底尘土、机关启动和重击落地反馈；危害回鸣需要另核对实际帧与危险段，不把尘土装饰当成伤害范围。
- 工程已有royal_earth_bump/royal_earth_wall等历史特效可作候选，必须先核对原帧和本章尺寸，不能直接恢复第一关废弃招式。
- 桌面“美术资源”中的KayKit为3D资源，不列入本项目2D像素角色候选。另有2D特效包，优先保留作补充；仅因名字包含Warrior不能认定有完整角色动作，当前该目录列的是VFX资源。
- 断钟/承重装置/可蹬墙刻槽仍需具体原图方案。现阶段不把地标占位标为完成美术。

## 已收到的角色包

| 目录（artifacts/downloads下） | 设计用途 | 检查结果 |
|---|---|---|
| `EVil Wizard 2` | 暗影杖使，低数量技能型精英 | Sprites下八张PNG完整；Attack1与Attack2各8帧；包内License.txt为CC0声明 |
| `Monsters Creatures Fantasy 2` | Bat作为铃翼掠食者 | Bat下六张PNG完整；不是缺包，不需要再下载；Rat/Mimic/Slime不纳入本章阵容 |
| `Bringer-Of-Death` | 缚钟守望者 | Individual Sprite中待机/走/攻击/施法/受伤/死亡/独立法术齐全，已查看全部原帧；实际武器为镰刀 |

源作者：Evil Wizard 2与Monsters Creatures Fantasy 2为LuizMelo，Bringer为Clembod。来源地址分别为https://luizmelo.itch.io/evil-wizard-2、https://luizmelo.itch.io/monsters-creatures-fantasy-2、https://clembod.itch.io/bringer-of-death-free。

Monsters目录未附许可文件，本轮已读取其作者页并缓存到artifacts/monsters_two_author.html，页面明确CC0及商业/非商业项目使用。它不是文件缺失或重新下载请求；正式导入时保存项目来源说明，不能伪造“包内原许可”。Bringer的License.txt允许项目使用与修改，并声明不可重新分发或转售素材；不标为CC0，不把任何一包的许可扩展到课程资源。运行游戏的集成验收与公开分发原始素材是不同事项，当前未执行发布。

## 静态核验与比例结论

- 全部动作联系表：artifacts/chapter_three_wizard_contact.png、chapter_three_bat_contact.png、chapter_three_bringer_contact.png，均已打开检查；详见[动画核验](chapter_three_animation_audit.md)。
- artifacts/chapter_three_art_audit.json记录每帧alpha包围范围、画布/单格尺寸和每个源文件SHA-256。检查脚本只读原目录。
- artifacts/chapter_three_scale_comparison.png为800×450明确标注的合成对照，包含现有主角、课程石墙截块与拟用天空底色，**不是第三关游戏截图**。
- 杖使采用内部画面1倍源像素作为初选，蝙蝠/Boss采用2倍；250×250画布不代表角色250px高，杖使待机含长杖仅95–104源像素高。所有动作使用同一固定脚底/枢轴，不按每帧alpha自动居中。
- 对照确认深色法术和蝙蝠在深石墙背景辨识度偏低；通过第三关开敞战斗背景、低细节中灰蓝远景保障对比，再做引擎内动态验收。不先修改原图、不扩大光晕。
- 新能力、生命奖励、教学/组合、回环和公平预警保持；原剑士/执戟卫和重槌招式表已从当前设计撤换。

## 不采用的候选

Medieval Warrior Pack 3已因画风及剑士玩法重复撤回。Rat素材存在，但用户要求更强技能，本章不以普通鼠怪替代技能型敌人。Fire Worm预览主攻击是火球，和现有直线弹体应对接近，本轮不再要求下载。Huntress 2与Undead Executioner没有进入选定阵容。

## 后续接入边界

角色素材已齐，剩余是制作与验证，不是等待用户下载。先测壁跃指标和安全能力回环，建立代表战斗场的原生动画/碰撞，再接支路与Boss。来源登记、Godot.import、深浅背景动态检查、真实攻击与护盾去重必须随正式导入完成。

本轮只修改设计/核验记录及artifacts内分析文件；没有新增可玩房间或改变前两关行为，不把第二关自动测试计数用作第三关证据。原始解压文件未修改；没有自动下载新的角色包。
