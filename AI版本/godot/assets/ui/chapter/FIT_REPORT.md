# chapter 拟合报告

参考：`design_low_noise.png`（1672×941）→ 设计 1920×1080（x × 1.14833，y × 1.14772）

| 元素 | 类型 | 来源 | 结果（设计坐标） | 分数 / 字号 |
|---|---|---|---|---|
| title_plaque | ninepatch | 切片 p6_chapter_title_plaque | [28, 11, 643, 108] | 轮廓 NCC 0.000，缩放 1.000 |
| title 文字 | text_style | 锚点 整图 design_low_noise.png 自动取 ink「腐土平原」 | ink [150, 34, 186, 42] → label [146, 22, 436, 65] | NotoSerifSC-Bold 45px，实测 ink 182×45，色 #FAC960 |
| title_moon | image | 切片 p6_chapter_title_moon_badge | [37, 16, 91, 91] | 轮廓 NCC 0.000，缩放 1.000 |
| title_line | ninepatch | 切片 p6_chapter_title_line | [36, 81, 557, 24] | 轮廓 NCC 0.000，缩放 1.000 |
| btn_back | button | 切片 p6_chapter_button_back_red | [1489, 34, 196, 53] | 轮廓 NCC 0.000，缩放 1.000 |
| btn_back 文字 | button | 锚点 整图 design_low_noise.png 自动取 ink「返回」 | ink [1565, 53, 44, 21] → label [1530, 46, 115, 33] | NotoSerifSC 22px，实测 ink 44×22，色 #F8ECF0 |
| btn_settings | button | 切片 p6_chapter_button_settings_purple | [1695, 34, 189, 53] | 轮廓 NCC 0.000，缩放 1.000 |
| btn_settings 文字 | button | 锚点 整图 design_low_noise.png 自动取 ink「设置」 | ink [1773, 53, 42, 21] → label [1736, 48, 115, 31] | NotoSerifSC 21px，实测 ink 42×21，色 #E7E2E3 |
| panel_top | ninepatch | 切片 modal_panel | [1372, 109, 534, 294] | 轮廓 NCC 0.000，缩放 1.000 |
| panel_bottom | ninepatch | 切片 modal_panel | [1372, 393, 534, 404] | 轮廓 NCC 0.000，缩放 1.000 |
| moon_orn | image | 切片 p6_chapter_title_moon_badge | [1714, 131, 172, 200] | 轮廓 NCC 0.000，缩放 1.000 |
| astro_orn | image | 切片 p6_chapter_astrolabe | [1756, 613, 132, 164] | 轮廓 NCC 0.000，缩放 1.000 |
| gem1_orn | image | 切片 p6_chapter_corner_gem | [1375, 154, 24, 24] | 轮廓 NCC 0.000，缩放 1.000 |
| gem2_orn | image | 切片 p6_chapter_corner_gem | [1880, 154, 24, 24] | 轮廓 NCC 0.000，缩放 1.000 |
| gem3_orn | image | 切片 p6_chapter_corner_gem | [1375, 438, 24, 24] | 轮廓 NCC 0.000，缩放 1.000 |
| gem4_orn | image | 切片 p6_chapter_corner_gem | [1880, 438, 24, 24] | 轮廓 NCC 0.000，缩放 1.000 |
| level_no 文字 | text_style | 锚点 整图 design_low_noise.png 自动取 ink「第 3 关」 | ink [1431, 165, 73, 23] → label [1430, 158, 413, 35] | NotoSerifSC 24px，实测 ink 73×24，色 #D8AA42 |
| level_title 文字 | text_style | 锚点 整图 design_low_noise.png 自动取 ink「墙缝」 | ink [1430, 213, 100, 47] → label [1429, 202, 413, 69] | NotoSerifSC-Bold 47px，实测 ink 94×47，色 #FEFBEC |
| sep_top | image | 切片 p6_chapter_separator_diamond | [1428, 270, 417, 46] | 轮廓 NCC 0.000，缩放 1.000 |
| region 文字 | text_style | 锚点 整图 design_low_noise.png 自动取 ink「区域 · 哭墙」 | ink [1431, 323, 131, 23] → label [1429, 314, 413, 38] | NotoSerifSC 26px，实测 ink 127×26，色 #E9E4E6 |
| summary 文字 | text_style | 锚点 整图 design_low_noise.png 自动取 ink「查看敌人规则，诱敌撤离，绕后破坏」 | ink [1432, 466, 409, 26] → label [1431, 458, 416, 38] | NotoSerifSC 26px，实测 ink 417×29，色 #E4DFE2 |
| sep_bottom | image | 切片 p6_chapter_separator_diamond | [1428, 509, 417, 46] | 轮廓 NCC 0.000，缩放 1.000 |
| objective_head 文字 | text_style | 锚点 整图 design_low_noise.png 自动取 ink「任务」 | ink [1430, 572, 52, 24] → label [1424, 566, 413, 35] | NotoSerifSC-Bold 24px，实测 ink 48×25，色 #F7CD49 |
| objective 文字 | text_style | 锚点 整图 design_low_noise.png 自动取 ink「摧毁哭墙后方的回响骸柱」 | ink [1432, 619, 278, 23] → label [1434, 612, 413, 37] | NotoSerifSC 25px，实测 ink 275×26，色 #EAE6E9 |
| state 文字 | text_style | 锚点 整图 design_low_noise.png 自动取 ink「状态 · 可挑战」 | ink [1433, 712, 165, 25] → label [1435, 704, 413, 40] | NotoSerifSC-Bold 27px，实测 ink 158×29，色 #F6C844 |
| btn_enter | button | 切片 p6_chapter_enter_teal | [1386, 805, 507, 114] | 轮廓 NCC 0.000，缩放 1.000 |
| btn_enter 文字 | button | 锚点 整图 design_low_noise.png 自动取 ink「进入」 | ink [1590, 838, 93, 41] → label [1519, 827, 230, 63] | NotoSerifSC-Bold 43px，实测 ink 86×41，色 #FCEDC4 |
| btn_enter 禁用态 | button | 整图 design_locked_low_noise.png | 派生 derived/p6_chapter_enter_teal_disabled.png | 亮度 × 0.816，饱和度 × 0.210，禁用文字色 #876955 |
| replay_pick | button | 切片 p6_chapter_story_dropdown | [1373, 923, 300, 78] | 轮廓 NCC 0.000，缩放 1.000 |
| replay_pick 文字 | button | 锚点 整图 design_low_noise.png 自动取 ink「开场剧情」 | ink [1434, 951, 87, 21] → label [1433, 946, 172, 31] | NotoSerifSC 21px，实测 ink 84×21，色 #F2EBE8 |
| replay_pick 禁用态 | button | 整图 design_locked_low_noise.png | 派生 derived/p6_chapter_story_dropdown_disabled.png | 亮度 × 1.041，饱和度 × 0.387，禁用文字色 #7A6F6F |
| btn_replay | button | 切片 p6_chapter_replay | [1661, 920, 243, 83] | 轮廓 NCC 0.000，缩放 1.000 |
| btn_replay 文字 | button | 锚点 整图 design_low_noise.png 自动取 ink「回放剧情」 | ink [1737, 951, 85, 20] → label [1718, 946, 161, 31] | NotoSerifSC 21px，实测 ink 84×21，色 #F0E8E2 |
| btn_replay 禁用态 | button | 整图 design_locked_low_noise.png | 派生 derived/p6_chapter_replay_disabled.png | 亮度 × 1.024，饱和度 × 0.355，禁用文字色 #847879 |
| ph_plaque | ninepatch | 切片 p6_chapter_placeholder_plaque | [1412, 166, 480, 98] | 轮廓 NCC 0.000，缩放 1.000 |
| ph_title 文字 | text_style | 锚点 整图 design_pan_end_low_noise.png 自动取 ink「未开放」 | ink [1542, 194, 123, 38] → label [1542, 182, 322, 60] | NotoSerifSC-Bold 41px，实测 ink 123×41，色 #FCFBF0 |
| ph_panel | ninepatch | 切片 modal_panel | [1408, 269, 492, 324] | 轮廓 NCC 0.000，缩放 1.000 |
| ph_text 文字 | text_style | 锚点 整图 design_pan_end_low_noise.png 自动取 ink「未解锁」 | ink [1470, 356, 75, 24] → label [1470, 349, 390, 35] | NotoSerifSC 24px，实测 ink 73×25，色 #DECFBC |
| ph_enter | button | 切片 p6_chapter_enter_disabled | [1450, 618, 410, 62] | 轮廓 NCC 0.000，缩放 1.000 |
| ph_enter 文字 | button | 锚点 整图 design_pan_end_low_noise.png 自动取 ink「进入」 | ink [1619, 636, 60, 28] → label [1533, 628, 230, 43] | NotoSerifSC-Bold 29px，实测 ink 58×29，色 #CBBEB3 |
| scroll_line | ninepatch | 切片 p6_chapter_scroll_rail | [34, 984, 1323, 78] | 轮廓 NCC 0.000，缩放 1.000 |
| scroll_thumb | ninepatch | 切片 p6_chapter_scroll_thumb | [2, 1008, 362, 40] | 轮廓 NCC 0.000，缩放 1.000 |
| node | flatbox | 整图量取 | [163, 774, 87, 87] | {'bg': '#1D121A', 'border': '#C7973F', 'border_width': 3.4, 'radius': 43.6} |
| node_tex_locked | image | 切片 p6_chapter_node_locked | [152, 763, 109, 109] | 轮廓 NCC 0.000，缩放 1.000 |
| node_tex_open | image | 切片 p6_chapter_node_challengeable | [152, 763, 109, 109] | 轮廓 NCC 0.000，缩放 1.000 |
| node_tex_done | image | 切片 p6_chapter_node_completed | [152, 763, 109, 109] | 轮廓 NCC 0.000，缩放 1.000 |
| node_tex_selected | image | 切片 p6_chapter_node_selected | [152, 763, 109, 109] | 轮廓 NCC 0.000，缩放 1.000 |
| node_tex_boss | image | 切片 p6_chapter_node_boss | [152, 763, 109, 109] | 轮廓 NCC 0.000，缩放 1.000 |
| node_lock_marker | image | 切片 p6_chapter_node_lock_marker | [224, 829, 25, 28] | 轮廓 NCC 0.000，缩放 1.000 |
| node_check_marker | image | 切片 p6_chapter_node_check_marker | [224, 829, 25, 28] | 轮廓 NCC 0.000，缩放 1.000 |
| link_gem | image | 切片 p6_chapter_link_diamond | [0, 0, 16, 16] | 轮廓 NCC 0.000，缩放 1.000 |
| plate | ninepatch | 切片 p6_chapter_nameplate | [94, 875, 224, 41] | 轮廓 NCC 0.000，缩放 1.000 |
| plate_text 文字 | text_style | 锚点 整图 design_low_noise.png 自动取 ink「01 · 田埂」 | ink [163, 884, 88, 22] → label [105, 876, 207, 34] | NotoSerifSC 23px，实测 ink 90×22，色 #F4F2F2 |
| link | flatbox | 整图量取 | [0, 0, 3, 3] | {'bg': '#00000000'} |
