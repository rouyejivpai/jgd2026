# 第三阶段剩余界面 · 整图审阅批次

P5已由用户确认无误。本批全部是整图提案，等待用户统一判断后再拆分新增素材。现有R1公共件、游戏头像优先复用；战场背景采用本批新增场景完整提案，不改运行代码或数据。

流程：控件/状态清单 → 素材复用评估 → 全部整图 → 用户判断 → 仅拆新增素材/引用公共件 → manifest回拼 → 程序P6/P7 → 实机diff → 用户目视。

| # | 界面/状态 | 整图 |
|---|---|---|
| 1 | 局内HUD · 部署 | [查看整图](../godot/assets/ui/hud/design.png) |
| 2 | 局内HUD · 战斗 | [查看整图](../godot/assets/ui/hud/design_running.png) |
| 3 | 局内HUD · 暂停 | [查看整图](../godot/assets/ui/hud/design_paused.png) |
| 4 | 局内HUD · 固定出场 | [查看整图](../godot/assets/ui/hud/design_fixed_roster.png) |
| 5 | 预算超出与开始校验 | [查看整图](../godot/assets/ui/hud/design_validation.png) |
| 6 | 任务弹窗 | [查看整图](../godot/assets/ui/hud/design_objectives.png) |
| 7 | 机制说明 · 可滚动正文 | [查看整图](../godot/assets/ui/hud/design_mechanics.png) |
| 8 | 分层提示 | [查看整图](../godot/assets/ui/hud/design_hint.png) |
| 9 | 推荐阵型确认 | [查看整图](../godot/assets/ui/hud/design_recommend.png) |
| 10 | 结算 · 胜利 | [查看整图](../godot/assets/ui/hud/design_result_win.png) |
| 11 | 结算 · 失败 | [查看整图](../godot/assets/ui/hud/design_result_lose.png) |
| 12 | 角色详情与指令编辑 | [查看整图](../godot/assets/ui/side_panel/design.png) |
| 13 | 指令运行 · 生效与原因 | [查看整图](../godot/assets/ui/side_panel/design_runtime.png) |
| 14 | 敌方只读详情 | [查看整图](../godot/assets/ui/side_panel/design_enemy.png) |
| 15 | 添加行为列表 | [查看整图](../godot/assets/ui/side_panel/design_add_action.png) |
| 16 | 信标列表与操作 | [查看整图](../godot/assets/ui/side_panel/design_beacons.png) |
| 17 | 指令编辑 · 双条件与或 | [查看整图](../godot/assets/ui/side_panel/design_two_conditions.png) |
| 18 | 指令编辑 · 等待参数 | [查看整图](../godot/assets/ui/side_panel/design_wait.png) |
| 19 | 指令编辑 · 信标模式与起点 | [查看整图](../godot/assets/ui/side_panel/design_follow_beacons.png) |
| 20 | 敌方特性与公开规则 | [查看整图](../godot/assets/ui/side_panel/design_enemy_traits.png) |
| 21 | 部署反馈 · 数字牌、三类血条、地格、提示 | [查看整图](../godot/assets/ui/battle_fx/design.png) |
| 22 | 章节地图 · 可挑战 | [查看整图](../godot/assets/ui/chapter/design.png) |
| 23 | 章节地图 · 锁定 | [查看整图](../godot/assets/ui/chapter/design_locked.png) |
| 24 | 章节地图 · 已完成与回放 | [查看整图](../godot/assets/ui/chapter/design_completed.png) |
| 25 | 章节地图 · 横移末端占位 | [查看整图](../godot/assets/ui/chapter/design_pan_end.png) |
| 26 | 章节地图 · 首领与后半区域 | [查看整图](../godot/assets/ui/chapter/design_boss.png) |

详细复用来源、游戏字体、示例文字来源及绘图几何见 `godot/tools/_raw/p3/review_batch/review_plan.json`。该文件为设计生产记录，不是运行manifest。

玩法矩形不变：顶栏64px、底栏120px。右侧520px浮动面板沿用原语义。章节固定右侧560px，地图3840×1080、25节点坐标复用现有数据，不修改占位归属。

HUD预览按线性光alpha合成，对应局内HDR 2D；章节按sRGB。公共PNG不改，程序P6需按该渲染基准截图验证。

待批准后才制作节点三态、角色卡/指令行四态等新切片，以及R5反馈manifest。艺术字只在已批准游戏名上使用，所有普通标题和正文均由实际游戏字体排版。

## 全图画廊与场景

[打开整图画廊](../godot/tools/_raw/p3/review_batch/review_gallery.html)（35张，点击可放大）

[章节完整宽图](../godot/assets/ui/chapter/map_chapter_01_review.png)

[R4八关 full/base、障碍切片与逐关检查](R4_ASSET_REVIEW.md) · [候选场景总览](../godot/assets/backdrops/review_r4/contact_sheet.png)

- [第1关场景整图](../godot/assets/backdrops/review_p3/level_01_full_review.png)
- [第2关场景整图](../godot/assets/backdrops/review_p3/level_02_full_review.png)
- [第3关场景整图](../godot/assets/backdrops/review_p3/level_03_full_review.png)
- [第4关场景整图](../godot/assets/backdrops/review_p3/level_04_full_review.png)
- [第5关场景整图](../godot/assets/backdrops/review_p3/level_05_full_review.png)
- [第6关场景整图](../godot/assets/backdrops/review_p3/level_06_full_review.png)
- [第7关场景整图](../godot/assets/backdrops/review_p3/level_07_full_review.png)
- [第8关场景整图](../godot/assets/backdrops/review_p3/level_08_full_review.png)

## 复用结论

复用43个现有素材来源：R1面板/菜单按钮/紧凑按钮/下拉/箭头/遮罩，原属性与操作SVG、拖拽柄、指令行三态、头像与圆形mask、单位精灵、三种血条轮廓。新绘制主要是章节区域节点、卡片框、数字牌和少量列表/滚动结构；仅画入整图，未导出独立素材。

原始场景整图仍是美术审阅提案，不能凭生成图判断像素级落点。2026-10-06 已另制 `review_r4/` 候选包：full/base、障碍格、anchor 与 obstacles.json 按现行接口核对，项目回贴脚本测得差异0.00%。候选场景尚待用户目视确认，未替换运行资源或关卡数据。源图小于目标画布的候选按1920×1080输出，但不声称拥有原生目标分辨率细节。章节地理美术与现有临时节点坐标也在本次审阅范围内，数据归属没有修改。

等待你对整图和障碍视觉判断后，再将R4候选资源迁入正式目录并接入关卡；R2/R3/R5的新运行manifest与切片仍未制作。
