# 统一窄边框与低噪音整图重绘

当前基准：用户已认可部署HUD V6。用户最新明确流程优先于旧任务包的底栏方位：预算左、开始右下，清空与提示在开始上方；五卡位同排，费用独立栏；上方渐变衬底处于UI下、场景上。先整图审阅，确认后实际拆分。

## 已有素材与复用决定

| 类别 | 已有内容 | 本轮决定 |
|---|---|---|
| 界面风格 | 已认可HUD V6：细描边、功能配色、半透明、五卡位与费用栏 | 所有局内界面共同参考 |
| 角色 | 四种己方形态及敌方头像、战场单位精灵 | 继续作为生成参考；不创造新单位或解锁 |
| 字形 | Noto Serif SC / Cinzel，主界面已认可艺术字 | 普通文字按已有样式参考，艺术字单独复用参考 |
| 公共资源 | 既有43个复用来源：按钮、面板、下拉、图标、指令行、血条、头像等 | 先检查再选为参考；旧粗重整板结构重绘 |
| 背景 | 8关完整场景、章节宽图、主界面背景 | 全部检查并按原主题减少碎纹、碎石、细叶等高频细节 |
| 新结构 | 轻边框弹窗、侧栏分区、指令行和章节节点 | 需要新增参考；先生成未切分的公共结构参考板 |

## 交付范围与流程

10张背景（8关＋章节宽图＋主界面背景）与29张界面状态（旧批26张＋主界面正常/错误＋设置浮窗）统一重绘。生产原图保留，不覆盖已认可设计、既有运行切片或玩法数据。

背景低噪音重绘 → 必要新结构参考板 → 每个状态将内容旧图、新背景、V6/新结构参考交给原生工具统一生成 → 逐张检查 → 整批画廊交用户判断 → 确认后再拆分。

背景按语义减细节，保留地形、低矮障碍、区域主题和主要轮廓；不使用全图模糊代替设计。普通文字不再后期叠加或用代码重新布局。本轮为艺术审阅，不声称原生工具自动满足字形绑定、像素级障碍对齐或回拼指标。

生成中的逐图记录位于godot/tools/_raw/p3/low_noise_review/records/；完成后追加画廊和每项测试结果。

## 本批完成与审阅入口

本批已完成39张整图（29界面＋10背景），另新增1张未拆分透明公共结构参考板。所有交付均为原生文件直接复制，无代码拼接、后期叠字或缩放。章节与主界面在整图生成后再次由绘图工具降低环境碎纹；暂停、结算与运行按钮状态、双条件的“最近”字样、通关地图锁标记也进行了工具修正。

[打开整图图库](../godot/tools/_raw/p3/low_noise_review/review_gallery.html) · [逐项检查结果](P3_LOW_NOISE_VALIDATION.md)

原生输出约1672×941，个别尺寸为1671×941或1672×940；章节宽图2172×724，实际3:1。没有把原生结果伪称1920×1080/3840×1080，也没有为了凑尺寸进行缩放。正式素材规格在整图确认后的拆分阶段处理。

普通文字只要求工具参考游戏字形，本轮未绑定字体文件，不能以目视认定字体完全相同。审阅稿中角色位置、关卡节点与背景网格可能存在工具重绘偏移；实机障碍占格、字体绑定、动态布局、透明度与切片回拼均待确认后验证。本批不改运行资源或玩法，不做打包。

## 全部交付清单

| ID | 内容 | 原生尺寸 | 文件 |
|---|---|---|---|
| ui_01 | 局内HUD · 部署 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_low_noise.png) |
| ui_02 | 局内HUD · 战斗 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_running_low_noise.png) |
| ui_03 | 局内HUD · 暂停 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_paused_low_noise.png) |
| ui_04 | 局内HUD · 固定出场 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_fixed_roster_low_noise.png) |
| ui_05 | 预算超出与开始校验 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_validation_low_noise.png) |
| ui_06 | 任务弹窗 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_objectives_low_noise.png) |
| ui_07 | 机制说明 · 可滚动正文 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_mechanics_low_noise.png) |
| ui_08 | 分层提示 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_hint_low_noise.png) |
| ui_09 | 推荐阵型确认 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_recommend_low_noise.png) |
| ui_10 | 结算 · 胜利 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_result_win_low_noise.png) |
| ui_11 | 结算 · 失败 | 1672×941 | [原生整图](../godot/assets/ui/hud/design_result_lose_low_noise.png) |
| ui_12 | 角色详情与指令编辑 | 1672×941 | [原生整图](../godot/assets/ui/side_panel/design_low_noise.png) |
| ui_13 | 指令运行 · 生效与原因 | 1672×941 | [原生整图](../godot/assets/ui/side_panel/design_runtime_low_noise.png) |
| ui_14 | 敌方只读详情 | 1672×941 | [原生整图](../godot/assets/ui/side_panel/design_enemy_low_noise.png) |
| ui_15 | 添加行为列表 | 1672×940 | [原生整图](../godot/assets/ui/side_panel/design_add_action_low_noise.png) |
| ui_16 | 信标列表与操作 | 1672×941 | [原生整图](../godot/assets/ui/side_panel/design_beacons_low_noise.png) |
| ui_17 | 指令编辑 · 双条件与或 | 1672×941 | [原生整图](../godot/assets/ui/side_panel/design_two_conditions_low_noise.png) |
| ui_18 | 指令编辑 · 等待参数 | 1671×941 | [原生整图](../godot/assets/ui/side_panel/design_wait_low_noise.png) |
| ui_19 | 指令编辑 · 信标模式与起点 | 1672×941 | [原生整图](../godot/assets/ui/side_panel/design_follow_beacons_low_noise.png) |
| ui_20 | 敌方特性与公开规则 | 1672×941 | [原生整图](../godot/assets/ui/side_panel/design_enemy_traits_low_noise.png) |
| ui_21 | 部署反馈 · 数字牌、三类血条、地格、提示 | 1672×941 | [原生整图](../godot/assets/ui/battle_fx/design_low_noise.png) |
| ui_22 | 章节地图 · 可挑战 | 1672×941 | [原生整图](../godot/assets/ui/chapter/design_low_noise.png) |
| ui_23 | 章节地图 · 锁定 | 1672×941 | [原生整图](../godot/assets/ui/chapter/design_locked_low_noise.png) |
| ui_24 | 章节地图 · 已完成与回放 | 1672×941 | [原生整图](../godot/assets/ui/chapter/design_completed_low_noise.png) |
| ui_25 | 章节地图 · 横移末端占位 | 1672×941 | [原生整图](../godot/assets/ui/chapter/design_pan_end_low_noise.png) |
| ui_26 | 章节地图 · 首领与后半区域 | 1672×941 | [原生整图](../godot/assets/ui/chapter/design_boss_low_noise.png) |
| ui_27 | 主界面 | 1672×941 | [原生整图](../godot/assets/ui/main_menu/design_low_noise.png) |
| ui_28 | 主界面·数据错误 | 1672×941 | [原生整图](../godot/assets/ui/main_menu/design_error_low_noise.png) |
| ui_29 | 设置浮窗 | 1672×941 | [原生整图](../godot/assets/ui/settings_overlay/design_low_noise.png) |
| bg_01 | 第1关背景 | 1672×941 | [原生整图](../godot/assets/backdrops/review_low_noise/level_01_full_review.png) |
| bg_02 | 第2关背景 | 1672×941 | [原生整图](../godot/assets/backdrops/review_low_noise/level_02_full_review.png) |
| bg_03 | 第3关背景 | 1672×941 | [原生整图](../godot/assets/backdrops/review_low_noise/level_03_full_review.png) |
| bg_04 | 第4关背景 | 1672×941 | [原生整图](../godot/assets/backdrops/review_low_noise/level_04_full_review.png) |
| bg_05 | 第5关背景 | 1672×941 | [原生整图](../godot/assets/backdrops/review_low_noise/level_05_full_review.png) |
| bg_06 | 第6关背景 | 1672×941 | [原生整图](../godot/assets/backdrops/review_low_noise/level_06_full_review.png) |
| bg_07 | 第7关背景 | 1672×941 | [原生整图](../godot/assets/backdrops/review_low_noise/level_07_full_review.png) |
| bg_08 | 第8关背景 | 1672×941 | [原生整图](../godot/assets/backdrops/review_low_noise/level_08_full_review.png) |
| bg_chapter | 章节完整宽图 | 2172×724 | [原生整图](../godot/assets/ui/chapter/map_chapter_01_low_noise.png) |
| bg_menu | 主界面背景 | 1672×941 | [原生整图](../godot/assets/backdrops/review_low_noise/main_menu_background.png) |
| style | 窄边框公共结构参考板 | 1672×941 | [原生整图](../godot/tools/_raw/p3/low_noise_review/new_material_reference.png) |

## 既有43项复用来源

头像6项、单位8项、交互图标及属性图标11项、血条3项、拖动/头像遮罩/指令行4项、公共按钮/下拉/面板10项、设置遮罩1项。作为内容与风格参考，不声称生成工具逐像素复用。具体文件：

- [bulwark.png](../godot/assets/sprites/portraits/bulwark.png)
- [lancer.png](../godot/assets/sprites/portraits/lancer.png)
- [spitter.png](../godot/assets/sprites/portraits/spitter.png)
- [striker.png](../godot/assets/sprites/portraits/striker.png)
- [swift.png](../godot/assets/sprites/portraits/swift.png)
- [warden.png](../godot/assets/sprites/portraits/warden.png)
- [drag_handle.svg](../godot/assets/sprites/ui/drag_handle.svg)
- [hp_bar_ally.png](../godot/assets/sprites/ui/hp_bar_ally.png)
- [hp_bar_enemy.png](../godot/assets/sprites/ui/hp_bar_enemy.png)
- [hp_bar_structure.png](../godot/assets/sprites/ui/hp_bar_structure.png)
- [exit.svg](../godot/assets/sprites/ui/icons/exit.svg)
- [pause.svg](../godot/assets/sprites/ui/icons/pause.svg)
- [play.svg](../godot/assets/sprites/ui/icons/play.svg)
- [reset.svg](../godot/assets/sprites/ui/icons/reset.svg)
- [stat_aps.svg](../godot/assets/sprites/ui/icons/stat_aps.svg)
- [stat_attack.svg](../godot/assets/sprites/ui/icons/stat_attack.svg)
- [stat_hp.svg](../godot/assets/sprites/ui/icons/stat_hp.svg)
- [stat_range.svg](../godot/assets/sprites/ui/icons/stat_range.svg)
- [stat_speed.svg](../godot/assets/sprites/ui/icons/stat_speed.svg)
- [stat_vision.svg](../godot/assets/sprites/ui/icons/stat_vision.svg)
- [trait_blast.svg](../godot/assets/sprites/ui/icons/trait_blast.svg)
- [portrait_mask.png](../godot/assets/sprites/ui/portrait_mask.png)
- [rule_row_bg_active.png](../godot/assets/sprites/ui/rule_row_bg_active.png)
- [rule_row_bg_normal.png](../godot/assets/sprites/ui/rule_row_bg_normal.png)
- [brute.png](../godot/assets/sprites/units/brute.png)
- [bulwark.png](../godot/assets/sprites/units/bulwark.png)
- [echo_pillar.png](../godot/assets/sprites/units/echo_pillar.png)
- [raider.png](../godot/assets/sprites/units/raider.png)
- [striker.png](../godot/assets/sprites/units/striker.png)
- [swift.png](../godot/assets/sprites/units/swift.png)
- [transit_node.png](../godot/assets/sprites/units/transit_node.png)
- [warden.png](../godot/assets/sprites/units/warden.png)
- [button_compact_disabled.png](../godot/assets/ui/common/button_compact_disabled.png)
- [button_compact_hover.png](../godot/assets/ui/common/button_compact_hover.png)
- [button_compact_normal.png](../godot/assets/ui/common/button_compact_normal.png)
- [button_menu_disabled.png](../godot/assets/ui/common/button_menu_disabled.png)
- [button_menu_hover.png](../godot/assets/ui/common/button_menu_hover.png)
- [dropdown_arrow.png](../godot/assets/ui/common/dropdown_arrow.png)
- [dropdown_disabled.png](../godot/assets/ui/common/dropdown_disabled.png)
- [dropdown_normal.png](../godot/assets/ui/common/dropdown_normal.png)
- [panel_dark.png](../godot/assets/ui/common/panel_dark.png)
- [panel_settings.png](../godot/assets/ui/common/panel_settings.png)
- [mask.png](../godot/assets/ui/settings_overlay/slices/mask.png)

后续按本批整图判断统一修正；全部整图确认后再实际拆分。拆分时保留艺术字为独立素材，普通文字由游戏字体渲染，新增薄边框与图标优先复用，拆分后进行统一回拼检查。
