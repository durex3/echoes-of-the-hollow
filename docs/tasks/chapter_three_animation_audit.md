# 第三关角色原图与动画核验

当前交接：本文保留初始静态联系表与候选倍率；法师现已按用户反馈改为Sprite 1.0（原5/7），当前动态映射见[动画维护](../animation-map.md)。Bringer仍未正式接入，原包仅在被忽略的下载目录，Mac需另行携带；详情见[素材迁移表](chapter_three_assets.md)。后续开发不得仅按历史候选恢复法师尺寸或重建已调整资源。

## 后续接入更新：2026-09-27

Evil Wizard 2和Bat现已正式导入，两种敌人使用独立FSM、固定锚点和物理时钟定位源帧，左右方向/实机尺度与伤害测试见[前半段试玩](chapter_three_preview.md)。根据原图逐帧叠加检查，上挑第6帧仅有分散消散线，保持播放但不再造成伤害；3–5仍有实心轮廓，回卷4–6保留伤害。原始静态核验记录如下，不能把其中的历史“未接入”当成当前状态。Bringer尚未进入运行关卡。

2026-09-27。三个解压包已经收到，无需再下载。应用create-game-assets的完整动作、固定锚点和原生尺度对照流程，结合level-design与game-ai修订遭遇设计。**本记录是静态素材核验，不是Godot内动态验收或已实现玩法的证明。**

## 实际检查范围

只读`artifacts/downloads/EVil Wizard 2`、`Monsters Creatures Fantasy 2/Bat`及`Bringer-Of-Death/Individual Sprite`。逐文件读取PNG、校验网格、统计每帧alpha包围范围并记录SHA-256；查看完整联系表，共147帧：杖使46、蝙蝠37、Boss64。没有修改源PNG、玩家文件、地图或存档。

原包保留在用户指定位置；分析工具和图片在忽略提交的artifacts内：

- `audit_chapter_three_art.ps1` / `chapter_three_art_audit.json`
- `chapter_three_wizard_contact.png`
- `chapter_three_bat_contact.png`
- `chapter_three_bringer_contact.png`
- `compare_chapter_three_scale.ps1` / `chapter_three_scale_comparison.png`

后者明确标记“ART SCALE COMPOSITE - not gameplay”，是现有主角、课程背景截块和新角色的800×450比例对照，不是新关卡截图。联系表按整段动画的共同包围范围展示，不能把该展示裁切误当成运行时每帧重新居中。

## 暗影杖使：Evil Wizard 2

全部单格250×250。使用原包八张水平条带，以下索引从0开始。

| 文件 | 实际尺寸 | 帧数 | 拟用映射 |
|---|---|---:|---|
| Idle.png | 2000×250 | 8 | 原序循环 |
| Run.png | 2000×250 | 8 | 接近/换位；不把奔跑硬接成瞬移 |
| Attack1.png | 2000×250 | 8 | 0–2收杖准备；3–6暗影斜上展开；7收势 |
| Attack2.png | 2000×250 | 8 | 0–3举杖准备；4–6前方回卷；7收势 |
| Take hit.png | 750×250 | 3 | 受伤原序，无整帧纯白替代图 |
| Death.png | 1750×250 | 7 | 原序非循环 |
| Jump.png | 500×250 | 2 | 已有但当前地面AI不需要 |
| Fall.png | 500×250 | 2 | 已有但当前地面AI不需要 |

待机含长杖可见高度95–104px，透明画布远大于身体。初选固定脚底锚点(125,167)，面向右；实施时用镜像而非变动物理身体。内部画面按源像素1倍初选，对应1.4倍镜头下Sprite 5/7；既有主角保持现状。2倍对照使长杖体积抢过Boss，故不以包围盒统一放大成2倍。

Attack1第3–6帧可见alpha高度79/115/120/141px；Attack2第4–6帧为129/139/149px。法术与角色烘焙在同一条带，不能自动等同于独立弹体。攻击碰撞要由法术实心轮廓校准，不包含大片透明区域、长杖装饰和纯消散尾迹。所列阶段划分是实现候选，正式计时须和帧及伤害同步验证。

## 铃翼掠食者：Monsters Creatures Fantasy 2 / Bat

该目录存在且齐全，不需要重新下载。单格87×87。

| 文件 | 实际尺寸 | 帧数 | 拟用映射 |
|---|---|---:|---|
| fly.png | 957×87 | 11 | 常态盘旋、低位收招循环 |
| attack.png | 957×87 | 11 | 0–7展翼/收翼准备；8–9扑击弧；10结束 |
| hurt.png | 261×87 | 3 | 受伤 |
| fly-to-fall.png | 261×87 | 3 | 死亡时由飞行转失控坠落 |
| fall.png | 435×87 | 5 | 失控坠落，等真实地面碰撞 |
| death.png | 348×87 | 4 | 接地后倒地，不在空中播放贴地尸体 |

`fly`首帧可见54×33px，1倍在主角旁躯干过小；初选内部画面2倍、Sprite 10/7。飞行接近正面，攻击弧偏向一侧，不能仅凭飞行帧认定朝向；左右掠袭需要分别核验。候选飞行枢轴(43,54)，攻击保持同一枢轴，接地死亡另校地面视觉锚点，禁止用Sprite偏移修物理轨迹。

原包不含独立音波/分身/追踪弹。技能来自有预警的锁点斜向掠袭、速度和低位反击窗口，不能为了“技能更厉害”声称素材有不存在的特效。

## 缚钟守望者：Bringer Of Death

使用`Individual Sprite`下七组原始逐帧PNG，均140×93；文件名从1开始，本项目设计表用0起算。`No Effect Sprites`为备选版本，本轮没有与带效果帧混用。

| 目录 | 帧数 | 拟用映射 |
|---|---:|---|
| Idle | 8 | 待机、入场/转阶段基础姿势 |
| Walk | 8 | 地面接近 |
| Attack | 10 | 0–3抬镰；4–7挥出；8–9消散回收 |
| Cast | 9 | 0–3蓄势；4–7举手释放；8结束 |
| Hurt | 3 | 受伤姿势，不能凭动画增加未经设计的招式中断 |
| Death | 10 | 非循环消散 |
| Spell | 16 | 独立上方旋涡/向下幽魂，非地面岩爆 |

Idle首帧alpha范围(86,38,40,54)，固定身体锚点候选(105,92)，原攻击朝左，面向右须镜像。内部画面2倍、Sprite 10/7，54源像素的身体约108内部像素高；仍需与实际碰撞和主角站位动态对齐。

Spell 0–3只有小旋涡，4–5开始伸出幽魂，6–12明显实体段，13–15回到小旋涡消散。完整效果alpha联合范围约x=49–86、y=35–92，帧宽29–36、高16–57；候选以(68,92)锚定锁定地面，使幽魂从旋涡向下伸出。每帧危险形状应随实体变化，不把整个旋涡下方透明柱子提前设成伤害。

此包没有重槌动画，旧重槌设计已撤换。镰击和幽魂分别教学，第二阶段才加入一次幽魂与一次镰击的组合；不复刻已有剑庭或空中下砸。

## 风格与许可记录

三者都是侧视玩法可用的像素角色；当前选择基于完整静态联系表和比例对照，尚未宣称用户认可最终动态观感。暗紫/深红在旧水道深石墙上对比偏低，拟用开敞天空与低细节中灰蓝远景提高可读性；这些是背景布局要求，不能靠不透明光雾遮盖原图。

Evil Wizard 2包内License.txt为CC0声明。Monsters目录没有附许可文本，本轮已读取对应作者页，明确CC0，网页缓存为`artifacts/monsters_two_author.html`；不是缺少素材包。Bringer包内License.txt含允许个人/商业项目使用与修改、禁止重新分发/转售素材的声明；不标为CC0，不宣称可以公开分发原始包。来源地址见[素材清单](chapter_three_assets.md)。

用于识别当前下载版本的SHA-256：

| 源文件 | SHA-256 |
|---|---|
| Evil Wizard 2/Sprites/Attack1.png | `fba330fe3777e798c3bb9f0a980999c7cd425369912f61cb83e5a7d4cf67f0e4` |
| Evil Wizard 2/Sprites/Attack2.png | `79fd38e6104877786e797e17bfafa578cfd60b553d03abef3e8ecfd2fc78ecec` |
| Evil Wizard 2/License.txt | `87f82ace98b17a6a9cb906b525063d866a6fbe8baacf5cf73b7f90916982b626` |
| Monsters Creatures Fantasy 2/Bat/attack.png | `3679999a79f26b9de02c5f9a3cbd46f9aaba8b86c4ab7b10baa7eb88dbe93e6a` |
| Bringer-Of-Death/SpriteSheet/Bringer-of-Death-SpritSheet.png | `126c755e384332bf4868bb09e06cc187d3b04466e08595c4676926064a239ed8` |
| Bringer-Of-Death/License.txt | `fe17ba9f2e13877d0bbefb9274cc4a32bd1deff647df10ca64e1e8dc8e1178e3` |

## 下一步的验收边界

- [x] 三个包路径、原PNG网格/数量、完整静态动作与许可依据核对。
- [x] 800×450合成比例和深浅背景可读性检查；旧剑士/重槌规格撤换。
- [ ] 正式复制所需资产并登记assets/manifest.json，保存来源、许可证、摘要与.import。
- [ ] 原生SpriteFrames/场景内动态动画、统一锚点、方向与透明边距验证。
- [ ] 生效帧和危险形状同步、身体/攻击去重、护盾、死亡/切房/暂停清理。
- [ ] 壁跃测量、白盒遭遇、真实输入路线与前两章回归。

本轮没有运行行为修改，不需要把原图核验冒充行为测试；进入实际接入阶段时按AGENTS执行tools/check.ps1，共享行为用-Full，视觉用-Visual并实际看图。
