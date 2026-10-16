# 低噪音整图逐项检查

本批检查以文件完整性、图库可用性和艺术审阅稿的目视检查为范围；不等同实机或切片验收。

## 自动检查：每个用例及结果

| 用例 | 检查 | 结果 | 证据 |
|---|---|---|---|
| PNG-ui_01 | 局内HUD · 部署 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_01 | 局内HUD · 部署 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_02 | 局内HUD · 战斗 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_02 | 局内HUD · 战斗 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_03 | 局内HUD · 暂停 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_03 | 局内HUD · 暂停 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_04 | 局内HUD · 固定出场 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_04 | 局内HUD · 固定出场 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_05 | 预算超出与开始校验 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_05 | 预算超出与开始校验 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_06 | 任务弹窗 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_06 | 任务弹窗 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_07 | 机制说明 · 可滚动正文 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_07 | 机制说明 · 可滚动正文 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_08 | 分层提示 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_08 | 分层提示 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_09 | 推荐阵型确认 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_09 | 推荐阵型确认 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_10 | 结算 · 胜利 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_10 | 结算 · 胜利 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_11 | 结算 · 失败 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_11 | 结算 · 失败 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_12 | 角色详情与指令编辑 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_12 | 角色详情与指令编辑 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_13 | 指令运行 · 生效与原因 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_13 | 指令运行 · 生效与原因 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_14 | 敌方只读详情 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_14 | 敌方只读详情 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_15 | 添加行为列表 PNG完整解码 | 通过 | 1672×940 |
| COPY-ui_15 | 添加行为列表 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_16 | 信标列表与操作 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_16 | 信标列表与操作 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_17 | 指令编辑 · 双条件与或 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_17 | 指令编辑 · 双条件与或 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_18 | 指令编辑 · 等待参数 PNG完整解码 | 通过 | 1671×941 |
| COPY-ui_18 | 指令编辑 · 等待参数 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_19 | 指令编辑 · 信标模式与起点 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_19 | 指令编辑 · 信标模式与起点 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_20 | 敌方特性与公开规则 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_20 | 敌方特性与公开规则 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_21 | 部署反馈 · 数字牌、三类血条、地格、提示 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_21 | 部署反馈 · 数字牌、三类血条、地格、提示 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_22 | 章节地图 · 可挑战 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_22 | 章节地图 · 可挑战 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_23 | 章节地图 · 锁定 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_23 | 章节地图 · 锁定 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_24 | 章节地图 · 已完成与回放 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_24 | 章节地图 · 已完成与回放 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_25 | 章节地图 · 横移末端占位 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_25 | 章节地图 · 横移末端占位 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_26 | 章节地图 · 首领与后半区域 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_26 | 章节地图 · 首领与后半区域 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_27 | 主界面 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_27 | 主界面 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_28 | 主界面·数据错误 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_28 | 主界面·数据错误 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-ui_29 | 设置浮窗 PNG完整解码 | 通过 | 1672×941 |
| COPY-ui_29 | 设置浮窗 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-bg_01 | 第1关背景 PNG完整解码 | 通过 | 1672×941 |
| COPY-bg_01 | 第1关背景 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-bg_02 | 第2关背景 PNG完整解码 | 通过 | 1672×941 |
| COPY-bg_02 | 第2关背景 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-bg_03 | 第3关背景 PNG完整解码 | 通过 | 1672×941 |
| COPY-bg_03 | 第3关背景 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-bg_04 | 第4关背景 PNG完整解码 | 通过 | 1672×941 |
| COPY-bg_04 | 第4关背景 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-bg_05 | 第5关背景 PNG完整解码 | 通过 | 1672×941 |
| COPY-bg_05 | 第5关背景 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-bg_06 | 第6关背景 PNG完整解码 | 通过 | 1672×941 |
| COPY-bg_06 | 第6关背景 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-bg_07 | 第7关背景 PNG完整解码 | 通过 | 1672×941 |
| COPY-bg_07 | 第7关背景 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-bg_08 | 第8关背景 PNG完整解码 | 通过 | 1672×941 |
| COPY-bg_08 | 第8关背景 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-bg_chapter | 章节完整宽图 PNG完整解码 | 通过 | 2172×724 |
| COPY-bg_chapter | 章节完整宽图 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-bg_menu | 主界面背景 PNG完整解码 | 通过 | 1672×941 |
| COPY-bg_menu | 主界面背景 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| PNG-style | 窄边框公共结构参考板 PNG完整解码 | 通过 | 1672×941 |
| COPY-style | 窄边框公共结构参考板 原生文件逐字节一致 | 通过 | SHA-256与原生输出及记录一致，未裁切/缩放/叠字 |
| SOURCE-assets/ui/hud/design.png | 原图保留 assets/ui/hud/design.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_running.png | 原图保留 assets/ui/hud/design_running.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_paused.png | 原图保留 assets/ui/hud/design_paused.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_fixed_roster.png | 原图保留 assets/ui/hud/design_fixed_roster.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_validation.png | 原图保留 assets/ui/hud/design_validation.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_objectives.png | 原图保留 assets/ui/hud/design_objectives.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_mechanics.png | 原图保留 assets/ui/hud/design_mechanics.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_hint.png | 原图保留 assets/ui/hud/design_hint.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_recommend.png | 原图保留 assets/ui/hud/design_recommend.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_result_win.png | 原图保留 assets/ui/hud/design_result_win.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_result_lose.png | 原图保留 assets/ui/hud/design_result_lose.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/side_panel/design.png | 原图保留 assets/ui/side_panel/design.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/side_panel/design_runtime.png | 原图保留 assets/ui/side_panel/design_runtime.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/side_panel/design_enemy.png | 原图保留 assets/ui/side_panel/design_enemy.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/side_panel/design_add_action.png | 原图保留 assets/ui/side_panel/design_add_action.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/side_panel/design_beacons.png | 原图保留 assets/ui/side_panel/design_beacons.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/side_panel/design_two_conditions.png | 原图保留 assets/ui/side_panel/design_two_conditions.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/side_panel/design_wait.png | 原图保留 assets/ui/side_panel/design_wait.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/side_panel/design_follow_beacons.png | 原图保留 assets/ui/side_panel/design_follow_beacons.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/side_panel/design_enemy_traits.png | 原图保留 assets/ui/side_panel/design_enemy_traits.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/battle_fx/design.png | 原图保留 assets/ui/battle_fx/design.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/chapter/design.png | 原图保留 assets/ui/chapter/design.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/chapter/design_locked.png | 原图保留 assets/ui/chapter/design_locked.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/chapter/design_completed.png | 原图保留 assets/ui/chapter/design_completed.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/chapter/design_pan_end.png | 原图保留 assets/ui/chapter/design_pan_end.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/chapter/design_boss.png | 原图保留 assets/ui/chapter/design_boss.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/main_menu/design.png | 原图保留 assets/ui/main_menu/design.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/main_menu/design_error.png | 原图保留 assets/ui/main_menu/design_error.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/settings_overlay/design.png | 原图保留 assets/ui/settings_overlay/design.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/backdrops/review_p3/level_01_full_review.png | 原图保留 assets/backdrops/review_p3/level_01_full_review.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/backdrops/review_p3/level_02_full_review.png | 原图保留 assets/backdrops/review_p3/level_02_full_review.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/backdrops/review_p3/level_03_full_review.png | 原图保留 assets/backdrops/review_p3/level_03_full_review.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/backdrops/review_p3/level_04_full_review.png | 原图保留 assets/backdrops/review_p3/level_04_full_review.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/backdrops/review_p3/level_05_full_review.png | 原图保留 assets/backdrops/review_p3/level_05_full_review.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/backdrops/review_p3/level_06_full_review.png | 原图保留 assets/backdrops/review_p3/level_06_full_review.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/backdrops/review_p3/level_07_full_review.png | 原图保留 assets/backdrops/review_p3/level_07_full_review.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/backdrops/review_p3/level_08_full_review.png | 原图保留 assets/backdrops/review_p3/level_08_full_review.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/chapter/map_chapter_01_review.png | 原图保留 assets/ui/chapter/map_chapter_01_review.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/main_menu/slices/bg.png | 原图保留 assets/ui/main_menu/slices/bg.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/hud/design_deploy_native_v6.png | 原图保留 assets/ui/hud/design_deploy_native_v6.png | 通过 | 与本轮开始时的SHA-256一致 |
| SOURCE-assets/ui/main_menu/slices/game_title_art.png | 原图保留 assets/ui/main_menu/slices/game_title_art.png | 通过 | 与本轮开始时的SHA-256一致 |
| REUSE-assets/sprites/portraits/bulwark.png | 复用来源 assets/sprites/portraits/bulwark.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/portraits/lancer.png | 复用来源 assets/sprites/portraits/lancer.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/portraits/spitter.png | 复用来源 assets/sprites/portraits/spitter.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/portraits/striker.png | 复用来源 assets/sprites/portraits/striker.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/portraits/swift.png | 复用来源 assets/sprites/portraits/swift.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/portraits/warden.png | 复用来源 assets/sprites/portraits/warden.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/drag_handle.svg | 复用来源 assets/sprites/ui/drag_handle.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/hp_bar_ally.png | 复用来源 assets/sprites/ui/hp_bar_ally.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/hp_bar_enemy.png | 复用来源 assets/sprites/ui/hp_bar_enemy.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/hp_bar_structure.png | 复用来源 assets/sprites/ui/hp_bar_structure.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/exit.svg | 复用来源 assets/sprites/ui/icons/exit.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/pause.svg | 复用来源 assets/sprites/ui/icons/pause.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/play.svg | 复用来源 assets/sprites/ui/icons/play.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/reset.svg | 复用来源 assets/sprites/ui/icons/reset.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/stat_aps.svg | 复用来源 assets/sprites/ui/icons/stat_aps.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/stat_attack.svg | 复用来源 assets/sprites/ui/icons/stat_attack.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/stat_hp.svg | 复用来源 assets/sprites/ui/icons/stat_hp.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/stat_range.svg | 复用来源 assets/sprites/ui/icons/stat_range.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/stat_speed.svg | 复用来源 assets/sprites/ui/icons/stat_speed.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/stat_vision.svg | 复用来源 assets/sprites/ui/icons/stat_vision.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/icons/trait_blast.svg | 复用来源 assets/sprites/ui/icons/trait_blast.svg | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/portrait_mask.png | 复用来源 assets/sprites/ui/portrait_mask.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/rule_row_bg_active.png | 复用来源 assets/sprites/ui/rule_row_bg_active.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/ui/rule_row_bg_normal.png | 复用来源 assets/sprites/ui/rule_row_bg_normal.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/units/brute.png | 复用来源 assets/sprites/units/brute.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/units/bulwark.png | 复用来源 assets/sprites/units/bulwark.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/units/echo_pillar.png | 复用来源 assets/sprites/units/echo_pillar.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/units/raider.png | 复用来源 assets/sprites/units/raider.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/units/striker.png | 复用来源 assets/sprites/units/striker.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/units/swift.png | 复用来源 assets/sprites/units/swift.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/units/transit_node.png | 复用来源 assets/sprites/units/transit_node.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/sprites/units/warden.png | 复用来源 assets/sprites/units/warden.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/common/button_compact_disabled.png | 复用来源 assets/ui/common/button_compact_disabled.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/common/button_compact_hover.png | 复用来源 assets/ui/common/button_compact_hover.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/common/button_compact_normal.png | 复用来源 assets/ui/common/button_compact_normal.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/common/button_menu_disabled.png | 复用来源 assets/ui/common/button_menu_disabled.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/common/button_menu_hover.png | 复用来源 assets/ui/common/button_menu_hover.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/common/dropdown_arrow.png | 复用来源 assets/ui/common/dropdown_arrow.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/common/dropdown_disabled.png | 复用来源 assets/ui/common/dropdown_disabled.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/common/dropdown_normal.png | 复用来源 assets/ui/common/dropdown_normal.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/common/panel_dark.png | 复用来源 assets/ui/common/panel_dark.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/common/panel_settings.png | 复用来源 assets/ui/common/panel_settings.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| REUSE-assets/ui/settings_overlay/slices/mask.png | 复用来源 assets/ui/settings_overlay/slices/mask.png | 通过 | 来源存在；作为参考，不声称工具逐像素复用 |
| COVERAGE | 交付数量 | 通过 | 29界面+10背景+1未切参考板 |
| ALPHA | 新结构板透明通道 | 通过 | 新增板保留透明，尚未切分 |
| GALLERY-ui_01 | 图库图片加载 ui_01 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_02 | 图库图片加载 ui_02 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_03 | 图库图片加载 ui_03 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_04 | 图库图片加载 ui_04 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_05 | 图库图片加载 ui_05 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_06 | 图库图片加载 ui_06 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_07 | 图库图片加载 ui_07 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_08 | 图库图片加载 ui_08 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_09 | 图库图片加载 ui_09 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_10 | 图库图片加载 ui_10 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_11 | 图库图片加载 ui_11 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_12 | 图库图片加载 ui_12 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_13 | 图库图片加载 ui_13 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_14 | 图库图片加载 ui_14 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_15 | 图库图片加载 ui_15 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_16 | 图库图片加载 ui_16 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_17 | 图库图片加载 ui_17 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_18 | 图库图片加载 ui_18 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_19 | 图库图片加载 ui_19 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_20 | 图库图片加载 ui_20 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_21 | 图库图片加载 ui_21 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_22 | 图库图片加载 ui_22 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_23 | 图库图片加载 ui_23 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_24 | 图库图片加载 ui_24 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_25 | 图库图片加载 ui_25 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_26 | 图库图片加载 ui_26 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_27 | 图库图片加载 ui_27 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_28 | 图库图片加载 ui_28 | 通过 | 浏览器实际解码成功 |
| GALLERY-ui_29 | 图库图片加载 ui_29 | 通过 | 浏览器实际解码成功 |
| GALLERY-bg_01 | 图库图片加载 bg_01 | 通过 | 浏览器实际解码成功 |
| GALLERY-bg_02 | 图库图片加载 bg_02 | 通过 | 浏览器实际解码成功 |
| GALLERY-bg_03 | 图库图片加载 bg_03 | 通过 | 浏览器实际解码成功 |
| GALLERY-bg_04 | 图库图片加载 bg_04 | 通过 | 浏览器实际解码成功 |
| GALLERY-bg_05 | 图库图片加载 bg_05 | 通过 | 浏览器实际解码成功 |
| GALLERY-bg_06 | 图库图片加载 bg_06 | 通过 | 浏览器实际解码成功 |
| GALLERY-bg_07 | 图库图片加载 bg_07 | 通过 | 浏览器实际解码成功 |
| GALLERY-bg_08 | 图库图片加载 bg_08 | 通过 | 浏览器实际解码成功 |
| GALLERY-bg_chapter | 图库图片加载 bg_chapter | 通过 | 浏览器实际解码成功 |
| GALLERY-bg_menu | 图库图片加载 bg_menu | 通过 | 浏览器实际解码成功 |
| GALLERY-style | 图库图片加载 style | 通过 | 浏览器实际解码成功 |
| FILTER-ui | 图库筛选 ui | 通过 | 可见 29 张 |
| FILTER-bg | 图库筛选 bg | 通过 | 可见 10 张 |
| FILTER-style | 图库筛选 style | 通过 | 可见 1 张 |
| FILTER-all | 图库筛选 all | 通过 | 可见 40 张 |
| LIGHTBOX | 整图弹窗 | 通过 | 弹窗打开、图片成功加载 |
| COMPARE | 原版切换 | 通过 | 旧图实际加载 |
| ZOOM | 原尺寸查看 | 通过 | 仅浏览器展示原尺寸，文件未修改 |
| NEXT | 下一张导航 | 通过 | ui_01切至ui_02 |
| CLOSE | 关闭弹窗 | 通过 | 弹窗关闭 |
| BROWSER | 图库JS运行 | 通过 | 无pageerror |

## 逐张目视复查

| ID | 内容 | 检查点 | 结果 |
|---|---|---|---|
| ui_01 | 局内HUD · 部署 | 部署：预算左、开始右下、清空提示在其上；五张卡与费用行 | 已复查，待用户判断整图 |
| ui_02 | 局内HUD · 战斗 | 战斗计时与阶段；开始灰显 | 已复查，待用户判断整图 |
| ui_03 | 局内HUD · 暂停 | 暂停/继续及开始、清空、提示灰显，工具修正后复查 | 已复查，待用户判断整图 |
| ui_04 | 局内HUD · 固定出场 | 固定出场阵容与锁定预备卡 | 已复查，待用户判断整图 |
| ui_05 | 预算超出与开始校验 | 12/8红色预算、灰显开始和独立错误提示 | 已复查，待用户判断整图 |
| ui_06 | 任务弹窗 | 任务、胜利条件、失败条件的留白与颜色 | 已复查，待用户判断整图 |
| ui_07 | 机制说明 · 可滚动正文 | 四段机制说明换行、滚动条与正文留白 | 已复查，待用户判断整图 |
| ui_08 | 分层提示 | 两层提示正文与进度点 | 已复查，待用户判断整图 |
| ui_09 | 推荐阵型确认 | 四段推荐正文与摆放/取消配色 | 已复查，待用户判断整图 |
| ui_10 | 结算 · 胜利 | 胜利时间、存活与解锁；底层按钮灰显修正 | 已复查，待用户判断整图 |
| ui_11 | 结算 · 失败 | 失败原因换行与底层灰显修正 | 已复查，待用户判断整图 |
| ui_12 | 角色详情与指令编辑 | 头像、六项属性、指令三个分离模块；删除红/添加青 | 已复查，待用户判断整图 |
| ui_13 | 指令运行 · 生效与原因 | 运行只读与执行/不成立；开始和清空提示位置已修正 | 已复查，待用户判断整图 |
| ui_14 | 敌方只读详情 | 敌方只读、六项属性、公开规则与当前目标 | 已复查，待用户判断整图 |
| ui_15 | 添加行为列表 | 五类行为选择与取消；独立功能颜色 | 已复查，待用户判断整图 |
| ui_16 | 信标列表与操作 | 信标三行坐标、删除、路线与复制操作 | 已复查，待用户判断整图 |
| ui_17 | 指令编辑 · 双条件与或 | 双条件、与、40%阈值；最近字样已交工具修正 | 已复查，待用户判断整图 |
| ui_18 | 指令编辑 · 等待参数 | 等待2.0秒及两条条件 | 已复查，待用户判断整图 |
| ui_19 | 指令编辑 · 信标模式与起点 | 沿我的信标/单程/起点1与条件、说明 | 已复查，待用户判断整图 |
| ui_20 | 敌方特性与公开规则 | 敌方特性和公开规则段落；战斗编辑控件灰显 | 已复查，待用户判断整图 |
| ui_21 | 部署反馈 · 数字牌、三类血条、地格、提示 | 无巨型展示板；放置反馈、小数字牌、三类血条与提示 | 已复查，待用户判断整图 |
| ui_22 | 章节地图 · 可挑战 | 可挑战节点、任务、进入；背景二次大块化 | 已复查，待用户判断整图 |
| ui_23 | 章节地图 · 锁定 | 锁定节点与前置关卡、进入灰显；背景二次简化 | 已复查，待用户判断整图 |
| ui_24 | 章节地图 · 已完成与回放 | 通关勾、回放及04锁标记补回；背景二次简化 | 已复查，待用户判断整图 |
| ui_25 | 章节地图 · 横移末端占位 | 末端十个未开放节点、灰显进入、滚动末端 | 已复查，待用户判断整图 |
| ui_26 | 章节地图 · 首领与后半区域 | 首领节点、任务、挑战状态；根枝地表二次简化 | 已复查，待用户判断整图 |
| ui_27 | 主界面 | 艺术标题、开始最大、设置紫/退出红；前景二次简化 | 已复查，待用户判断整图 |
| ui_28 | 主界面·数据错误 | 开始禁用、独立错误提示；前景二次简化 | 已复查，待用户判断整图 |
| ui_29 | 设置浮窗 | 声音/显示/调试三组内容；前景二次简化 | 已复查，待用户判断整图 |
| bg_01 | 第1关背景 | 开放战斗地面、农田栅栏大轮廓；减少地表碎纹 | 已复查，待用户判断整图 |
| bg_02 | 第2关背景 | 谷仓轮廓与道具组；减少碎纹与散点 | 已复查，待用户判断整图 |
| bg_03 | 第3关背景 | 保留哭墙与中央低墙主题、安静砖面 | 已复查，待用户判断整图 |
| bg_04 | 第4关背景 | 保留四组低根障碍及巢穴主题，减少细枝碎物 | 已复查，待用户判断整图 |
| bg_05 | 第5关背景 | 保留中央低木板堆与坡地主题，减少碎纹 | 已复查，待用户判断整图 |
| bg_06 | 第6关背景 | 保留右中低遗迹与金色地面大线条，减少碎石 | 已复查，待用户判断整图 |
| bg_07 | 第7关背景 | 车站、归途主题与开放地面，减少密集高光 | 已复查，待用户判断整图 |
| bg_08 | 第8关背景 | 两条低根带与温室主题，减少碎纹和高光 | 已复查，待用户判断整图 |
| bg_chapter | 章节完整宽图 | 完整五区域宽景，二次简化地表/枝叶；无首版白边 | 已复查，待用户判断整图 |
| bg_menu | 主界面背景 | 女孩右侧与左侧留白、少量大骨轮廓下四分之一；二次简化 | 已复查，待用户判断整图 |
| style | 窄边框公共结构参考板 | 新增未切公共结构参考板：窄弹窗、模块、行与节点；保留透明 | 已复查，待用户判断整图 |

## 验收边界

普通文字字体文件绑定、逐字OCR、动态布局与真实透明度、角色位置/障碍占格、实机效果、素材切片与回拼均未验收；本批只提交整图方案。整图采用绘图工具统一生成，不能声称精确像素保持。普通文字后续须由游戏字体渲染，艺术字须单独作为素材。没有改运行切片、关卡数据或生成客户端。

## 收尾用例与结果

| 用例 | 检查 | 结果 | 证据 |
|---|---|---|---|
| CLEANUP-1 | 生成复制临时脚本删除 | 通过 | `_p3_lownoise.cjs` 已删除，目录复查无匹配文件 |
| CLEANUP-2 | 汇总与图库测试临时脚本删除 | 通过 | `_p3_lownoise_finish.cjs` 已删除，目录复查无匹配文件；未留测试截图 |
| DIFF | Git空白错误检查 | 通过 | `git diff --check` 返回0；仅换行格式提示 |

结论：216个自动检查用例通过，3个收尾用例通过；40张图均已逐张目视复查并记录检查点。当前为整图审阅批，等待用户判断后再实际拆分。
