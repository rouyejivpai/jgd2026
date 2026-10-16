# P6 缺失资源补充

按 `P6_MISSING_ASSETS.md` 对照批准整图补入无字透明 PNG。资源进入 `godot/assets/ui/unified_low_noise/slices/`；行为图标进入 `godot/assets/sprites/ui/icons/`，沿用 `Art.texture()` 的相对路径规则。拟合数据写入 `godot/assets/ui/battle_hud/fit_spec.json`，资源哈希登记在 `layout.json`。

| P6 项 | 补充或处理 | 接入情况 |
|---|---|---|
| 1 按钮状态 | 继续使用单张切片加 hover / pressed / disabled 调色；开始、清空、提示的既有派生态保留 | 拟合管线生成四态引用，不另造重复图片 |
| 2 角色卡 | 保留现有形态卡和状态调色 | `card_spitter` 内容确为己方 lancer，未改 ID |
| 3 切片瑕疵 | `p6_task_clean.png`、`p6_clear_clean.png`、`p6_start_clean.png` | 清理副本登记到 `task`、`clear`、`start`；原图保留 |
| 4 任务弹窗 | `p6_crescent_moon.png`、`p6_close_gem.png` | 标题月牙与关闭按钮宝石已加入 |
| 5 描边关闭按钮 | `p6_button_close_outline.png` | 机制说明与提示弹窗复用；四态由调色派生。推荐确认框以取消按钮关闭，没有单独关闭控件 |
| 6 推荐确认按钮 | `p6_button_place.png`、`p6_button_cancel.png` | 青色摆放、暗红取消按钮已切换为切片与四态调色 |
| 7 胜利结算 | `p6_victory_sigil.png`、`p6_victory_title_lines.png`、复用 `p6_crescent_moon.png` | 背景纹章、标题两侧菱形线、月牙角饰已加入 |
| 8 失败结算 | `p6_defeat_compass.png`、`p6_defeat_divider.png` | 红裂罗盘与中央菱形分隔线已加入 |
| 9 结算按钮 | `p6_button_result_purple.png`、`p6_button_result_teal.png` | 紫色重试/返回、青色下一关/失败重试；九宫格边距 `[34,16,34,16]`（贴图像素），四态由调色派生 |
| 10 详情框底标签 | `p6_footer_tab.png` | 单独凸出标签；九宫格边距 `[42,15,42,7]` |
| 11 移除按钮 | `p6_button_remove.png` | 已替换详情弹窗平面按钮，包含红色叉标 |
| 12 条件框和分隔线 | 保留现有 StyleBoxFlat 与 1 px 色线 | 原清单允许继续使用平面样式 |
| 13 数值输入框 | 保留金框下拉底与现有透明上下调节 | 不增造资源 |
| 14 滚动条箭头 | `p6_scroll_arrow_up.png`、`p6_scroll_arrow_down.png` | 已放在详情滚动条两端 |
| 15 金框下拉 | 保留现有 `dropdown` 切片 | 遵循清单中用户已关闭的补图项 |
| 16 行为图标 | `act_follow_beacons.png`、`act_wait.png`、`act_cancel.png` | 通过 `ui/icons/...` 注册到行为列表 |
| 17 部署反馈 | `p6_beacon_badge.png`、`p6_placement_blocked_bubble.png`、`p6_hp_bar_gold_frame.png` | 数字牌与含指向尖角的气泡已接入；血条金框仅登记为候选，沿用当前运行素材 |

六种九宫格素材的四边边距按 `[左, 上, 右, 下]`、原 PNG 像素登记：结算胶囊 `[34,16,34,16]`、footer tab `[42,15,42,7]`、信标牌 `[8,8,8,8]`、不可放置气泡 `[14,12,14,12]`、血条候选 `[5,2,5,2]`。结算按钮九宫格边距现由 `ui_fit_reference.py` 传递到 manifest。

P6 #16 的行为行底色、描边与四态由现有 `rule_editor.gd` 根据 `det_pick.data.colors` 生成；该列表目前没有按行为切片的资源槽，因此只补了缺失的三个图标，没有添加无法被运行界面读取的重复底图。

章节资源改由图片生成工具产出透明 PNG 图集，再按格裁切、缩放并清理边缘色；未使用 SVG 绘制这批资源。未对运行场景或游戏逻辑做修改。
| 18 标题装饰 | `p6_chapter_title_moon_badge`、`p6_chapter_title_line`、`p6_chapter_title_plaque` | ImageGen 月牙徽牌、右端菱形线与深色标题底牌均切入 fit_spec；底牌置于标题内容下方 |
| 19 返回 / 设置 | `p6_chapter_button_back_red`、`p6_chapter_button_settings_purple` | 返回红胶囊已按清单更新重导，完整透明切片和两端端帽九宫格接入；紫色胶囊沿用原切片 |
| 20 详情框装饰 | `p6_chapter_panel_top_ornament`、`p6_chapter_panel_bottom_ornament` | 上框月牙与四角宝石；下框四角宝石、顶中菱形与星盘，作为独立透明叠层交付 |
| 21 分隔线 | `p6_chapter_separator_diamond` | 上下两条复用较细、低对比的中央菱形切片 |
| 22 进入按钮 | `p6_chapter_enter_teal`、`p6_chapter_enter_disabled` | 普通青色月牙胶囊四态由调色派生；占位灰色款已按清单更新重导完整切片，去掉旧裁片偏移 |
| 23 剧情控件 | `p6_chapter_story_dropdown`、`p6_chapter_replay` | 回放切片已重导并加入左侧 ▶ 播放三角；剧情下拉和回放均登记四态 |
| 24 节点 | `chapter/nodes/{rake,grid,shield,crosshair,flower,wolf_head}.png`、`p6_chapter_node_{locked,challengeable,completed,selected,boss}`、锁 / 勾角标与名牌胶囊 | 透明区域图标已按五个现有 region 写入 `chapter_01.json` 的 `node_art`；盾图标也单独交付。节点徽章、角标、名牌已生成；节点圆盘目前仍由 `level_select.gd` 绘制，这些 ImageGen 生成图先作为独立切片登记 |
| 25 连线节点 | `p6_chapter_link_diamond` | 单独透明菱形装饰；菱形由 ImageGen 生成；当前连线仍由 `level_select.gd` 绘制直线 |
| 26 滚动指示 | `p6_chapter_scroll_rail`、`p6_chapter_scroll_thumb` | 轨道重导为更小的月牙 / 菱形端头，并用九宫格固定端帽；菱形亮段沿用原切片 |
| 27 占位标题牌 | `p6_chapter_placeholder_plaque` | 紫色月牙 / 宝石九宫格胶囊已切入 fit_spec |

章节 ImageGen 图集切片完成并清理了红色透明边缘；节点徽章、角标、面板纹饰、星盘与连线菱形为独立资源。章节新增九宫格边距按 `[左, 上, 右, 下]`、PNG 原始像素登记：标题线 `[10,0,20,0]`、进入 `[96,0,52,0]`、剧情下拉 `[32,18,22,18]`、回放 `[32,18,32,18]`、占位标题牌 `[86,0,62,0]`、滚动亮段 `[12,0,12,0]`。节点角标、面板纹饰、星盘与连线菱形为独立透明图，供地图节点叠层使用。


## 章节清单更新（2026-10-06）

按 `P6_MISSING_ASSETS.md` 的接入差异，用 ImageGen 生成透明图集并裁切替换：新增标题深色底牌；重导返回红胶囊、占位灰色进入胶囊、带播放三角的回放胶囊、较细分隔线及端饰缩小的滚动轨道。更新了 `fit_spec.json` / `layout.json` 的切片映射、九宫格边距和哈希；本批切片未使用 SVG 或代码绘图。
