# battle_hud 拟合报告

参考：`../hud/design_low_noise.png`（1672×941）→ 设计 1920×1080（x × 1.14833，y × 1.14772）

| 元素 | 类型 | 来源 | 结果（设计坐标） | 分数 / 字号 |
|---|---|---|---|---|
| quest | image | 切片 quest | [46, 35, 358, 124] | 轮廓 NCC 0.636，缩放 0.865 |
| quest_title 文字 | text_style | 锚点 quest-title「第 3 关 · 墙缝」 | ink [149, 76, 157, 24] → label [148, 68, 211, 37] | NotoSerifSC-Bold 25px，实测 ink 147×25，色 #EBD48A |
| quest_objective 文字 | text_style | 锚点 quest-objective「摧毁哭墙后方的回响骸柱」 | ink [149, 110, 188, 15] → label [149, 105, 211, 25] | NotoSerifSC 17px，实测 ink 187×18，色 #E5E0E6 |
| timer | image | 切片 timer | [808, 25, 312, 122] | 轮廓 NCC 0.772，缩放 0.850 |
| timer_value 文字 | text_style | 锚点 timer-value「00.0」 | ink [937, 78, 47, 18] → label [931, 71, 57, 33] | NotoSerifSC-Bold 22px，实测 ink 46×17，色 #F4F8F8 |
| timer_phase 文字 | text_style | 锚点 timer-phase「部署阶段」 | ink [1017, 81, 59, 13] → label [1010, 78, 73, 21] | NotoSerifSC 14px，实测 ink 56×14，色 #D3DEE1 |
| btn_retry | button | 切片 retry | [1354, 39, 80, 96] | 轮廓 NCC 0.779，缩放 0.875 |
| btn_retry 文字 | button | 锚点 retry-label「重试」 | ink [1383, 86, 30, 16] → label [1375, 83, 46, 23] | NotoSerifSC-Bold 15px，实测 ink 30×17，色 #EAE6E5 |
| btn_speed1 | button | 切片 speed1 | [1434, 40, 79, 95] | 轮廓 NCC 0.829，缩放 0.865 |
| btn_speed1 文字 | button | 锚点 speed1-label「1×」 | ink [1464, 86, 22, 15] → label [1453, 81, 46, 25] | NotoSerifSC-Bold 17px，实测 ink 25×13，色 #D8DDDB |
| btn_speed2 | button | 切片 speed2 | [1513, 39, 80, 96] | 轮廓 NCC 0.763，缩放 0.875 |
| btn_speed2 文字 | button | 锚点 speed2-label「2×」 | ink [1540, 86, 23, 15] → label [1529, 81, 46, 25] | NotoSerifSC-Bold 17px，实测 ink 27×13，色 #E2E4DF |
| btn_pause | button | 切片 pause | [1593, 39, 80, 96] | 轮廓 NCC 0.807，缩放 0.875 |
| btn_pause 文字 | button | 锚点 pause-label「暂停」 | ink [1616, 86, 31, 15] → label [1608, 83, 46, 21] | NotoSerifSC-Bold 14px，实测 ink 28×15，色 #D6D7D5 |
| btn_settings | button | 切片 settings | [1678, 40, 80, 96] | 轮廓 NCC 0.770，缩放 0.875 |
| btn_settings 文字 | button | 锚点 settings-label「设置」 | ink [1702, 86, 31, 15] → label [1694, 83, 46, 23] | NotoSerifSC-Bold 15px，实测 ink 30×16，色 #E3E5E1 |
| btn_exit | button | 切片 exit | [1766, 39, 80, 96] | 轮廓 NCC 0.724，缩放 0.875 |
| btn_exit 文字 | button | 锚点 exit-label「退出」 | ink [1789, 86, 32, 15] → label [1782, 83, 46, 23] | NotoSerifSC-Bold 15px，实测 ink 30×15，色 #FEF4EB |
| btn_task | button | 切片 task | [1617, 137, 134, 57] | 轮廓 NCC 0.853，缩放 0.805 |
| btn_task 文字 | button | 锚点 task-label「任务」 | ink [1673, 157, 29, 14] → label [1662, 153, 51, 21] | NotoSerifSC-Bold 14px，实测 ink 28×16，色 #EDF3F6 |
| btn_mechanics | button | 切片 mechanics | [1753, 137, 134, 57] | 轮廓 NCC 0.721，缩放 0.805 |
| btn_mechanics 文字 | button | 锚点 mechanics-label「机制说明」 | ink [1790, 157, 61, 14] → label [1785, 154, 70, 21] | NotoSerifSC-Bold 14px，实测 ink 56×16，色 #E1D5E2 |
| btn_clear | button | 切片 clear | [1563, 857, 165, 68] | 轮廓 NCC 0.834，缩放 0.850 |
| btn_clear 文字 | button | 锚点 clear-label「清空」 | ink [1629, 884, 34, 17] → label [1606, 880, 83, 24] | NotoSerifSC-Bold 16px，实测 ink 32×17，色 #DAEDF0 |
| btn_clear 禁用态 | button | 整图 ../hud/design_running_low_noise.png | 派生 derived/clear_disabled.png | 亮度 × 0.739，饱和度 × 0.119，禁用文字色 #969192 |
| btn_hint | button | 切片 hint | [1727, 856, 169, 69] | 轮廓 NCC 0.787，缩放 0.865 |
| btn_hint 文字 | button | 锚点 hint-label「提示」 | ink [1788, 884, 36, 17] → label [1766, 880, 78, 25] | NotoSerifSC-Bold 17px，实测 ink 36×19，色 #EAECF9 |
| btn_hint 禁用态 | button | 整图 ../hud/design_running_low_noise.png | 派生 derived/hint_disabled.png | 亮度 × 0.798，饱和度 × 0.154，禁用文字色 #A4A09F |
| btn_start | button | 切片 start | [1544, 917, 360, 139] | 轮廓 NCC 0.807，缩放 0.890 |
| btn_start 文字 | button | 锚点 start-label「开始」 | ink [1685, 958, 85, 40] → label [1640, 948, 172, 59] | NotoSerifSC-Bold 40px，实测 ink 83×40，色 #FBF2D2 |
| btn_start 禁用态 | button | 整图 ../hud/design_running_low_noise.png | 派生 derived/start_disabled.png | 亮度 × 0.886，饱和度 × 0.165，禁用文字色 #958F8E |
| budget | image | 切片 budget | [24, 919, 325, 130] | 轮廓 NCC 0.805，缩放 0.835 |
| budget_title 文字 | text_style | 锚点 budget-title「预算」 | ink [188, 956, 36, 17] → label [120, 953, 172, 24] | NotoSerifSC 16px，实测 ink 32×17，色 #F1F0D4 |
| budget_value 文字 | text_style | 锚点 budget-value「6 / 8」 | ink [170, 985, 67, 24] → label [118, 979, 172, 44] | Cinzel 32px，实测 ink 65×26，色 #F2EABB |
| budget_fixed 文字 | text_style | 锚点 整图 ../hud/design_fixed_roster_low_noise.png 自动取 ink「固定出场」 | ink [149, 966, 122, 29] → label [123, 957, 172, 44] | NotoSerifSC-Bold 30px，实测 ink 120×30，色 #FAF1BD |
| card_1 | image | 切片 card_swift | [422, 827, 200, 230] | 轮廓 NCC 0.711，缩放 0.925 |
| card_2 | image | 切片 card_striker | [642, 828, 199, 229] | 轮廓 NCC 0.674，缩放 0.920 |
| card_3 | image | 切片 card_bulwark | [860, 827, 200, 230] | 轮廓 NCC 0.691，缩放 0.925 |
| card_4 | image | 切片 card_spitter | [1081, 827, 200, 230] | 轮廓 NCC 0.695，缩放 0.925 |
| card_5 | image | 切片 card_locked | [1301, 828, 199, 229] | 轮廓 NCC 0.704，缩放 0.920 |
| card_name 文字 | text_style | 锚点 card-striker-name「基础攻击形态」 | ink [690, 977, 106, 17] → label [669, 973, 149, 25] | NotoSerifSC-Bold 17px，实测 ink 104×18，色 #EDE9EF |
| card_cost_label 文字 | text_style | 锚点 card-swift-cost「COST」 | ink [503, 1017, 38, 11] → label [498, 1013, 46, 19] | NotoSerifSC-Bold 13px，实测 ink 36×10，色 #F4DD74 |
| card_cost_value 文字 | text_style | 锚点 card-swift-value「3」 | ink [562, 1010, 17, 26] → label [554, 1002, 34, 46] | Cinzel 33px，实测 ink 16×25，色 #FDEB89 |
| problems_panel | ninepatch | 切片 modal_panel | [559, 693, 801, 176] | 轮廓 NCC 0.000，缩放 1.000 |
| problems_title 文字 | text_style | 锚点 整图 ../hud/design_validation_low_noise.png 自动取 ink「无法开始：」 | ink [607, 729, 113, 24] → label [607, 722, 712, 34] | NotoSerifSC-Bold 23px，实测 ink 115×25，色 #EA453B |
| problems_line 文字 | text_style | 锚点 整图 ../hud/design_validation_low_noise.png 自动取 ink「出场 Cost 12，超出预算」 | ink [607, 775, 230, 22] → label [607, 768, 712, 31] | NotoSerifSC 21px，实测 ink 225×24，色 #D74339 |
| obj_panel | ninepatch | 切片 modal_panel | [460, 214, 999, 577] | 轮廓 NCC 0.000，缩放 1.000 |
| obj_close | button | 切片 button_delete | [1265, 246, 151, 73] | 轮廓 NCC 0.000，缩放 1.000 |
| obj_close 文字 | button | 锚点 整图 ../hud/design_objectives_low_noise.png 自动取 ink「关闭」 | ink [1321, 272, 42, 22] → label [1296, 265, 92, 31] | NotoSerifSC 21px，实测 ink 42×21，色 #ECDFCF |
| obj_moon | image | 切片 p6_crescent_moon | [503, 239, 67, 88] | 轮廓 NCC 0.000，缩放 1.000 |
| obj_close_gem | image | 切片 p6_close_gem | [1389, 270, 20, 25] | 轮廓 NCC 0.000，缩放 1.000 |
| obj_title 文字 | text_style | 锚点 整图 ../hud/design_objectives_low_noise.png 自动取 ink「任务」 | ink [572, 266, 75, 36] → label [572, 256, 574, 54] | NotoSerifSC-Bold 37px，实测 ink 74×37，色 #FCF3D4 |
| obj_sep | flatbox | 整图量取 | [520, 324, 881, 1] | {'bg': '#79574D'} |
| obj_text 文字 | text_style | 锚点 整图 ../hud/design_objectives_low_noise.png 自动取 ink「摧毁哭墙后方的回响骸柱」 | ink [521, 363, 319, 28] → label [521, 355, 881, 43] | NotoSerifSC 29px，实测 ink 319×30，色 #EBC14B |
| obj_win_header 文字 | text_style | 锚点 整图 ../hud/design_objectives_low_noise.png 自动取 ink「胜利条件」 | ink [522, 456, 100, 23] → label [522, 449, 881, 37] | NotoSerifSC 25px，实测 ink 100×25，色 #F2C54A |
| obj_box | flatbox | 整图量取 | [520, 492, 881, 69] | {'bg': '#241B29', 'border': '#55425C', 'border_width': 1.7, 'radius': 6.9} |
| obj_box_text 文字 | text_style | 锚点 整图 ../hud/design_objectives_low_noise.png 自动取 ink「摧毁：回响骸柱」 | ink [550, 514, 173, 24] → label [550, 507, 827, 37] | NotoSerifSC 25px，实测 ink 175×26，色 #EEE9DD |
| obj_lose_header 文字 | text_style | 锚点 整图 ../hud/design_objectives_low_noise.png 自动取 ink「失败条件」 | ink [524, 595, 99, 24] → label [524, 588, 881, 37] | NotoSerifSC 25px，实测 ink 100×25，色 #E84E3C |
| obj_box2 | flatbox | 整图量取 | [520, 631, 881, 69] | {'bg': '#241B29', 'border': '#55425C', 'border_width': 1.7, 'radius': 6.9} |
| mech_panel | ninepatch | 切片 modal_panel | [425, 197, 1069, 644] | 轮廓 NCC 0.000，缩放 1.000 |
| mech_close | button | 切片 p6_button_close_outline | [1317, 252, 124, 46] | 轮廓 NCC 0.000，缩放 1.000 |
| mech_close 文字 | button | 锚点 整图 ../hud/design_mechanics_low_noise.png 自动取 ink「关闭」 | ink [1361, 265, 38, 20] → label [1336, 258, 92, 31] | NotoSerifSC 21px，实测 ink 42×21，色 #E2D6C1 |
| mech_title 文字 | text_style | 锚点 整图 ../hud/design_mechanics_low_noise.png 自动取 ink「机制说明」 | ink [487, 254, 150, 36] → label [487, 244, 689, 53] | NotoSerifSC-Bold 36px，实测 ink 144×36，色 #FCEFCF |
| mech_sep | flatbox | 整图量取 | [485, 313, 968, 1] | {'bg': '#604C4E'} |
| mech_hint 文字 | text_style | 锚点 整图 ../hud/design_mechanics_low_noise.png 自动取 ink「本关要点：先让它看见谁，会改变它接下来追谁。哭墙守卫锁定首个进入视野的分裂体，直到它死亡或」 | ink [489, 353, 961, 21] → label [489, 348, 968, 31] | NotoSerifSC 21px，实测 ink 945×24，色 #D1A441 |
| mech_box | flatbox | 整图量取 | [485, 442, 949, 106] | {'bg': '#201624', 'border': '#48374D', 'border_width': 1.7, 'radius': 6.9} |
| mech_box_text 文字 | text_style | 锚点 整图 ../hud/design_mechanics_low_noise.png 自动取 ink「单位从上到下检查指令，执行第一条条件成立的；之后的指令本次不再看。每次决策都从顶部重新」 | ink [510, 472, 897, 20] → label [510, 469, 907, 31] | NotoSerifSC 21px，实测 ink 903×24，色 #D9CDB7 |
| mech_box2 | flatbox | 整图量取 | [485, 560, 949, 107] | {'bg': '#201624', 'border': '#48374D', 'border_width': 1.7, 'radius': 6.9} |
| mech_track | ninepatch | 切片 scroll_track | [1443, 445, 6, 357] | 轮廓 NCC 0.000，缩放 1.000 |
| mech_thumb | ninepatch | 切片 scroll_thumb | [1443, 446, 6, 127] | 轮廓 NCC 0.000，缩放 1.000 |
| hint_panel | ninepatch | 切片 modal_panel | [512, 257, 895, 418] | 轮廓 NCC 0.000，缩放 1.000 |
| hint_title 文字 | text_style | 锚点 整图 ../hud/design_hint_low_noise.png 自动取 ink「提示」 | ink [567, 306, 68, 33] → label [567, 297, 643, 48] | NotoSerifSC-Bold 33px，实测 ink 68×33，色 #FCF1D2 |
| hint_close | button | 切片 p6_button_close_outline | [1251, 302, 104, 45] | 轮廓 NCC 0.000，缩放 1.000 |
| hint_close 文字 | button | 锚点 整图 ../hud/design_hint_low_noise.png 自动取 ink「关闭」 | ink [1287, 314, 36, 20] → label [1265, 307, 87, 31] | NotoSerifSC 21px，实测 ink 42×21，色 #D0C5BC |
| hint_sep | flatbox | 整图量取 | [565, 364, 790, 1] | {'bg': '#513C3D'} |
| hint_line 文字 | text_style | 锚点 整图 ../hud/design_hint_low_noise.png 自动取 ink「1. 点开守卫的面板。注意它的视野只有 6 格，而且「锁定首个进入视野的分裂体」。」 | ink [568, 421, 736, 21] → label [568, 415, 790, 30] | NotoSerifSC 20px，实测 ink 742×23，色 #D0C1B0 |
| hint_line2 文字 | text_style | 锚点 整图 ../hud/design_hint_low_noise.png 自动取 ink「2. 快速形态移速 4.5，守卫只有 1.2。让快速形态先走进守卫视野，再在被追近时撤离」 | ink [567, 507, 777, 20] → label [567, 501, 790, 30] | NotoSerifSC 20px，实测 ink 749×23，色 #D3C4B7 |
| hint_dot_on | flatbox | 整图量取 | [572, 608, 10, 10] | {'bg': '#EBBA4D', 'radius': 5.2} |
| hint_dot_off | flatbox | 整图量取 | [596, 608, 10, 10] | {'bg': '#734C79', 'radius': 5.2} |
| rec_panel | ninepatch | 切片 modal_panel | [514, 188, 891, 650] | 轮廓 NCC 0.000，缩放 1.000 |
| rec_hint4 文字 | text_style | 锚点 整图 ../hud/design_recommend_low_noise.png 自动取 ink「4. 推荐部署：快速形态 (2,5) 面向庭院；基础攻击形态 (2,1) 走通道。」 | ink [570, 603, 607, 21] → label [570, 597, 790, 30] | NotoSerifSC 20px，实测 ink 607×22，色 #D8AD3B |
| rec_sep | flatbox | 整图量取 | [565, 660, 790, 1] | {'bg': '#49383C'} |
| rec_confirm 文字 | text_style | 锚点 整图 ../hud/design_recommend_low_noise.png 自动取 ink「将覆盖当前部署与指令，确定摆放推荐阵型？」 | ink [571, 689, 419, 20] → label [571, 682, 790, 31] | NotoSerifSC 21px，实测 ink 420×24，色 #DEB43D |
| rec_apply | button | 切片 p6_button_place | [1038, 737, 146, 54] | 轮廓 NCC 0.000，缩放 1.000 |
| rec_apply 文字 | button | 锚点 整图 ../hud/design_recommend_low_noise.png 自动取 ink「摆放」 | ink [1090, 754, 42, 20] → label [1048, 747, 126, 31] | NotoSerifSC 21px，实测 ink 42×22，色 #EDF2F3 |
| rec_cancel | button | 切片 p6_button_cancel | [1209, 737, 141, 54] | 轮廓 NCC 0.000，缩放 1.000 |
| rec_cancel 文字 | button | 锚点 整图 ../hud/design_recommend_low_noise.png 自动取 ink「取消」 | ink [1259, 754, 40, 20] → label [1219, 747, 122, 31] | NotoSerifSC 21px，实测 ink 42×21，色 #FAF4F5 |
| rec_hint1 文字 | text_style | 锚点 整图 ../hud/design_recommend_low_noise.png 自动取 ink「1. 点开守卫的面板。注意它的视野只有 6 格，而且「锁定首个进入视野的分裂体」。」 | ink [573, 331, 721, 21] → label [573, 325, 790, 30] | NotoSerifSC 20px，实测 ink 742×23，色 #DACEC4 |
| rec_hint2 文字 | text_style | 锚点 整图 ../hud/design_recommend_low_noise.png 自动取 ink「2. 快速形态移速 4.5，守卫只有 1.2。让快速形态先走进守卫视野，再在被追近时撤离——」 | ink [570, 402, 781, 20] → label [570, 396, 790, 30] | NotoSerifSC 20px，实测 ink 785×23，色 #D8CCC1 |
| rec_title 文字 | text_style | 锚点 整图 ../hud/design_recommend_low_noise.png 自动取 ink「推荐阵型」 | ink [567, 234, 142, 34] → label [567, 225, 643, 48] | NotoSerifSC-Bold 33px，实测 ink 132×33，色 #FDF7E0 |
| win_panel | ninepatch | 切片 modal_panel | [551, 203, 816, 613] | 轮廓 NCC 0.000，缩放 1.000 |
| win_title_sigil | image | 切片 p6_victory_sigil | [871, 217, 180, 180] | 轮廓 NCC 0.000，缩放 1.000 |
| win_title_crescent | image | 切片 p6_crescent_moon | [581, 227, 54, 70] | 轮廓 NCC 0.000，缩放 1.000 |
| win_title_lines | image | 切片 p6_victory_title_lines | [637, 305, 661, 22] | 轮廓 NCC 0.000，缩放 1.000 |
| win_title 文字 | text_style | 锚点 整图 ../hud/design_result_win_low_noise.png 自动取 ink「战斗胜利」 | ink [842, 287, 238, 68] → label [721, 269, 482, 88] | NotoSerifSC-Bold 60px，实测 ink 240×59，色 #F8EDB9 |
| win_sep | flatbox | 整图量取 | [586, 381, 746, 1] | {'bg': '#6B5240'} |
| win_level 文字 | text_style | 锚点 整图 ../hud/design_result_win_low_noise.png 自动取 ink「墙缝」 | ink [621, 420, 61, 29] → label [621, 411, 735, 44] | NotoSerifSC-Bold 30px，实测 ink 60×30，色 #F9D043 |
| win_time 文字 | text_style | 锚点 整图 ../hud/design_result_win_low_noise.png 自动取 ink「完成时间：24.8」 | ink [630, 487, 184, 24] → label [630, 480, 735, 38] | NotoSerifSC 26px，实测 ink 183×26，色 #E4D6C0 |
| win_survivors 文字 | text_style | 锚点 整图 ../hud/design_result_win_low_noise.png 自动取 ink「存活单位：快速形态、基础攻击形态」 | ink [630, 538, 424, 24] → label [630, 531, 735, 38] | NotoSerifSC 26px，实测 ink 417×26，色 #E0D4C1 |
| win_reward_head 文字 | text_style | 锚点 整图 ../hud/design_result_win_low_noise.png 自动取 ink「解锁」 | ink [632, 615, 46, 23] → label [632, 608, 735, 38] | NotoSerifSC 26px，实测 ink 53×27，色 #E8B42E |
| win_reward 文字 | text_style | 锚点 整图 ../hud/design_result_win_low_noise.png 自动取 ink「新选敌：最远、生命最低」 | ink [630, 651, 274, 23] → label [630, 644, 735, 38] | NotoSerifSC 26px，实测 ink 286×26，色 #DEAD32 |
| win_retry | button | 切片 p6_button_result_purple | [619, 709, 192, 59] | 轮廓 NCC 0.000，缩放 1.000 |
| win_retry 文字 | button | 锚点 整图 ../hud/design_result_win_low_noise.png 自动取 ink「重试」 | ink [695, 728, 44, 22] → label [650, 721, 134, 33] | NotoSerifSC 22px，实测 ink 44×22，色 #EEE8EB |
| win_next | button | 切片 p6_button_result_teal | [850, 709, 220, 59] | 轮廓 NCC 0.000，缩放 1.000 |
| win_next 文字 | button | 锚点 整图 ../hud/design_result_win_low_noise.png 自动取 ink「下一关」 | ink [934, 728, 61, 22] → label [885, 721, 163, 33] | NotoSerifSC 22px，实测 ink 66×22，色 #C7D3D7 |
| win_back | button | 切片 p6_button_result_purple | [1110, 709, 191, 59] | 轮廓 NCC 0.000，缩放 1.000 |
| win_back 文字 | button | 锚点 整图 ../hud/design_result_win_low_noise.png 自动取 ink「返回」 | ink [1183, 728, 46, 22] → label [1138, 721, 133, 33] | NotoSerifSC 22px，实测 ink 44×22，色 #FAF8FA |
| lose_panel | ninepatch | 切片 modal_panel | [494, 187, 933, 609] | 轮廓 NCC 0.000，缩放 1.000 |
| lose_title_compass | image | 切片 p6_defeat_compass | [998, 209, 293, 293] | 轮廓 NCC 0.000，缩放 1.000 |
| lose_title 文字 | text_style | 锚点 整图 ../hud/design_result_lose_low_noise.png 自动取 ink「战斗失败」 | ink [563, 239, 191, 46] → label [563, 225, 482, 69] | NotoSerifSC-Bold 47px，实测 ink 188×48，色 #F8515A |
| lose_sep | image | 切片 p6_defeat_divider | [551, 305, 815, 18] | 轮廓 NCC 0.000，缩放 1.000 |
| lose_level 文字 | text_style | 锚点 整图 ../hud/design_result_lose_low_noise.png 自动取 ink「墙缝」 | ink [560, 351, 56, 28] → label [560, 344, 735, 42] | NotoSerifSC-Bold 28px，实测 ink 56×29，色 #F54D54 |
| lose_time 文字 | text_style | 锚点 整图 ../hud/design_result_lose_low_noise.png 自动取 ink「完成时间：24.8」 | ink [562, 428, 180, 23] → label [562, 421, 735, 38] | NotoSerifSC 26px，实测 ink 183×26，色 #E4D3AE |
| lose_survivors 文字 | text_style | 锚点 整图 ../hud/design_result_lose_low_noise.png 自动取 ink「存活单位：无」 | ink [563, 476, 152, 24] → label [563, 469, 735, 38] | NotoSerifSC 26px，实测 ink 156×26，色 #D6C6A3 |
| lose_sep2 | flatbox | 整图量取 | [551, 546, 815, 1] | {'bg': '#6B5240'} |
| lose_reason 文字 | text_style | 锚点 整图 ../hud/design_result_lose_low_noise.png 自动取 ink「原因：分裂体全部倒下。回看守卫锁定了谁：如果快速形态离开了守卫视野，」 | ink [563, 583, 800, 23] → label [563, 576, 816, 35] | NotoSerifSC 24px，实测 ink 816×27，色 #E34349 |
| lose_retry | button | 切片 p6_button_result_teal | [655, 690, 287, 62] | 轮廓 NCC 0.000，缩放 1.000 |
| lose_retry 文字 | button | 锚点 整图 ../hud/design_result_lose_low_noise.png 自动取 ink「重试」 | ink [774, 709, 46, 23] → label [681, 702, 230, 33] | NotoSerifSC 22px，实测 ink 44×22，色 #F8F7F4 |
| lose_back | button | 切片 p6_button_result_purple | [976, 690, 299, 62] | 轮廓 NCC 0.000，缩放 1.000 |
| lose_back 文字 | button | 锚点 整图 ../hud/design_result_lose_low_noise.png 自动取 ink「返回」 | ink [1100, 709, 48, 23] → label [1002, 702, 241, 33] | NotoSerifSC 22px，实测 ink 44×22，色 #FCF8FD |
| det_panel | ninepatch | 切片 modal_panel | [413, 115, 1093, 841] | 轮廓 NCC 0.000，缩放 1.000 |
| det_footer_tab | ninepatch | 切片 p6_footer_tab | [811, 918, 299, 44] | 轮廓 NCC 0.000，缩放 1.000 |
| det_scrim | flatbox | 整图量取 | [0, 0, 1920, 1080] | {'bg': '#0C060E99'} |
| det_portrait | flatbox | 整图量取 | [465, 149, 149, 145] | {'bg': '#00000000'} |
| det_close | button | 切片 button_delete | [1331, 144, 154, 81] | 轮廓 NCC 0.000，缩放 1.000 |
| det_close 文字 | button | 锚点 detail:detail-close「关闭」 | ink [1392, 174, 36, 20] → label [1358, 169, 103, 27] | NotoSerifSC 18px，实测 ink 36×18，色 #F9F6F5 |
| det_remove | button | 切片 p6_button_remove | [1208, 156, 124, 56] | 轮廓 NCC 0.000，缩放 1.000 |
| det_remove 文字 | button | 锚点 detail:detail-close「关闭」 | ink [1392, 174, 36, 20] → label [1220, 169, 103, 27] | NotoSerifSC 18px，实测 ink 36×18，色 #F9F6F5 |
| det_title 文字 | text_style | 锚点 detail:detail-title「快速形态」 | ink [640, 163, 172, 40] → label [640, 151, 551, 62] | NotoSerifSC-Bold 42px，实测 ink 171×42，色 #F9CB52 |
| det_desc 文字 | text_style | 锚点 detail:detail-description「四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。」 | ink [644, 234, 593, 23] → label [644, 227, 804, 34] | NotoSerifSC 23px，实测 ink 598×23，色 #D8D3D6 |
| det_cost 文字 | text_style | 锚点 detail:detail-description「四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。」 | ink [644, 234, 593, 23] → label [644, 259, 804, 25] | NotoSerifSC 17px，实测 ink 442×18，色 #D8D3D6 |
| det_stats | ninepatch | 切片 stats_panel | [433, 283, 1060, 92] | 轮廓 NCC 0.000，缩放 1.000 |
| det_stat_icon_0 | flatbox | 整图量取 | [464, 313, 30, 30] | {'bg': '#00000000'} |
| det_stat_name_0 文字 | text_style | 锚点 detail:stat-0-name「生命」 | ink [506, 318, 42, 22] → label [506, 311, 69, 31] | NotoSerifSC 21px，实测 ink 42×21，色 #D5D3D5 |
| det_stat_value_0 文字 | text_style | 锚点 detail:stat-0-value「60」 | ink [573, 320, 24, 17] → label [573, 311, 69, 31] | NotoSerifSC 21px，实测 ink 24×16，色 #FED442 |
| det_stat_icon_1 | flatbox | 整图量取 | [640, 313, 30, 30] | {'bg': '#00000000'} |
| det_stat_name_1 文字 | text_style | 锚点 detail:stat-1-name「攻击」 | ink [678, 318, 44, 21] → label [678, 313, 69, 31] | NotoSerifSC 21px，实测 ink 42×21，色 #E2DCE0 |
| det_stat_value_1 文字 | text_style | 锚点 detail:stat-1-value「6」 | ink [760, 320, 10, 17] → label [759, 313, 69, 30] | NotoSerifSC 20px，实测 ink 11×15，色 #F5CF48 |
| det_stat_icon_2 | flatbox | 整图量取 | [814, 313, 30, 30] | {'bg': '#00000000'} |
| det_stat_name_2 文字 | text_style | 锚点 detail:stat-2-name「攻速」 | ink [854, 318, 42, 21] → label [854, 314, 69, 30] | NotoSerifSC 20px，实测 ink 40×20，色 #EAE5E8 |
| det_stat_value_2 文字 | text_style | 锚点 detail:stat-2-value「1.0」 | ink [924, 320, 29, 18] → label [924, 311, 69, 31] | NotoSerifSC 21px，实测 ink 29×16，色 #EDC444 |
| det_stat_icon_3 | flatbox | 整图量取 | [996, 313, 30, 30] | {'bg': '#00000000'} |
| det_stat_name_3 文字 | text_style | 锚点 detail:stat-3-name「移速」 | ink [1036, 318, 44, 21] → label [1036, 311, 69, 31] | NotoSerifSC 21px，实测 ink 42×21，色 #E6E1E1 |
| det_stat_value_3 文字 | text_style | 锚点 detail:stat-3-value「4.5」 | ink [1100, 320, 32, 17] → label [1100, 313, 69, 31] | NotoSerifSC 21px，实测 ink 31×17，色 #EBC344 |
| det_stat_icon_4 | flatbox | 整图量取 | [1170, 313, 30, 30] | {'bg': '#00000000'} |
| det_stat_name_4 文字 | text_style | 锚点 detail:stat-4-name「视野」 | ink [1215, 318, 42, 22] → label [1215, 311, 69, 31] | NotoSerifSC 21px，实测 ink 42×21，色 #E5E2E3 |
| det_stat_value_4 文字 | text_style | 锚点 detail:stat-4-value「9」 | ink [1279, 320, 10, 17] → label [1278, 313, 69, 30] | NotoSerifSC 20px，实测 ink 11×15，色 #F0CF49 |
| det_stat_icon_5 | flatbox | 整图量取 | [1323, 313, 30, 30] | {'bg': '#00000000'} |
| det_stat_name_5 文字 | text_style | 锚点 detail:stat-5-name「射程」 | ink [1364, 318, 44, 22] → label [1364, 311, 69, 31] | NotoSerifSC 21px，实测 ink 42×21，色 #E4DFE3 |
| det_stat_value_5 文字 | text_style | 锚点 detail:stat-5-value「1.5」 | ink [1431, 320, 28, 18] → label [1430, 313, 69, 31] | NotoSerifSC 21px，实测 ink 29×16，色 #F0BE43 |
| det_scroll | flatbox | 整图量取 | [447, 370, 994, 494] | {'bg': '#00000000'} |
| det_track | ninepatch | 切片 scroll_track | [1445, 382, 9, 471] | 轮廓 NCC 0.000，缩放 1.000 |
| det_thumb | ninepatch | 切片 scroll_thumb | [1445, 383, 9, 92] | 轮廓 NCC 0.000，缩放 1.000 |
| det_scroll_arrow_up | image | 切片 p6_scroll_arrow_up | [1438, 377, 23, 16] | 轮廓 NCC 0.000，缩放 1.000 |
| det_scroll_arrow_down | image | 切片 p6_scroll_arrow_down | [1438, 843, 23, 16] | 轮廓 NCC 0.000，缩放 1.000 |
| det_add | button | 切片 button_add | [770, 860, 402, 53] | 轮廓 NCC 0.000，缩放 1.000 |
| det_add 文字 | button | 锚点 detail:detail-add「添加指令」 | ink [918, 884, 85, 21] → label [817, 879, 287, 31] | NotoSerifSC-Bold 21px，实测 ink 84×22，色 #F4F8F8 |
| det_beacons 文字 | text_style | 锚点 detail:detail-beacons「信标：尚无信标」 | ink [887, 931, 148, 20] → label [673, 924, 574, 31] | NotoSerifSC 21px，实测 ink 148×21，色 #D9D4D9 |
| det_row1 | ninepatch | 切片 command_panel | [431, 351, 1027, 242] | 轮廓 NCC 0.000，缩放 1.000 |
| det_row2 | ninepatch | 切片 command_panel | [431, 570, 1027, 242] | 轮廓 NCC 0.000，缩放 1.000 |
| det_handle | image | 切片 drag_handle | [462, 391, 32, 52] | 轮廓 NCC 0.000，缩放 1.000 |
| det_prio 文字 | text_style | 锚点 detail:row-1-priority「优先级 1」 | ink [524, 403, 101, 23] → label [524, 395, 126, 40] | NotoSerifSC-Bold 27px，实测 ink 101×27，色 #F4CC45 |
| det_action | button | 切片 dropdown | [644, 376, 236, 78] | 轮廓 NCC 0.000，缩放 1.000 |
| det_action 文字 | button | 锚点 detail:row-1-action「沿我的信标」 | ink [674, 404, 107, 20] → label [674, 397, 141, 31] | NotoSerifSC 21px，实测 ink 106×21，色 #E7E3E6 |
| det_p1 | button | 切片 dropdown | [870, 377, 202, 74] | 轮廓 NCC 0.000，缩放 1.000 |
| det_p2 | button | 切片 dropdown | [1065, 377, 171, 74] | 轮廓 NCC 0.000，缩放 1.000 |
| det_delete | button | 切片 button_delete | [1298, 378, 137, 75] | 轮廓 NCC 0.000，缩放 1.000 |
| det_delete 文字 | button | 锚点 detail:row-1-delete「删除」 | ink [1346, 406, 40, 21] → label [1323, 402, 87, 28] | NotoSerifSC 19px，实测 ink 39×19，色 #F6EBE5 |
| det_c1_label 文字 | text_style | 锚点 detail:row-1-condition-one「条件一」 | ink [668, 464, 62, 20] → label [668, 458, 103, 30] | NotoSerifSC 20px，实测 ink 60×20，色 #C4C0C7 |
| det_c2_label 文字 | text_style | 锚点 detail:row-1-condition-two「条件二」 | ink [669, 528, 61, 21] → label [669, 522, 103, 30] | NotoSerifSC 20px，实测 ink 60×20，色 #C7C0C7 |
| det_c1 | button | 切片 dropdown | [782, 441, 445, 67] | 轮廓 NCC 0.000，缩放 1.000 |
| det_c2 | button | 切片 dropdown | [782, 509, 445, 67] | 轮廓 NCC 0.000，缩放 1.000 |
| det_c1_narrow | button | 切片 dropdown | [782, 658, 307, 71] | 轮廓 NCC 0.000，缩放 1.000 |
| det_cparam | button | 切片 dropdown | [1084, 658, 143, 71] | 轮廓 NCC 0.000，缩放 1.000 |
| det_cunit 文字 | text_style | 锚点 整图 ../../../tools/_raw/p3/unified_ui/detail_modal_whole.png 自动取 ink「%」 | ink [1234, 686, 17, 16] → label [1234, 677, 46, 30] | NotoSerifSC 20px，实测 ink 18×16，色 #DBD6D7 |
| det_wait_label 文字 | text_style | 锚点 detail:row-2-duration-label「持续时间」 | ink [949, 623, 82, 18] → label [949, 617, 115, 30] | NotoSerifSC 20px，实测 ink 80×21，色 #D3CDD3 |
| det_wait_box | button | 切片 dropdown | [1038, 595, 164, 76] | 轮廓 NCC 0.000，缩放 1.000 |
| det_wait_unit 文字 | text_style | 锚点 detail:row-2-duration-unit「秒」 | ink [1207, 623, 17, 18] → label [1207, 618, 46, 27] | NotoSerifSC 18px，实测 ink 19×18，色 #DFDBDE |
| det_logic_line_l | flatbox | 整图量取 | [795, 507, 175, 1] | {'bg': '#6E6670'} |
| det_logic_line_r | flatbox | 整图量取 | [1038, 507, 176, 1] | {'bg': '#6E6670'} |
| det_logic | 平面按钮 | 整图量取 | [981, 494, 46, 28] | {'bg': '#00000000', 'border': '', 'border_width': 0.0, 'radius': 0.0} |
| det_logic 文字 | button | 锚点 整图 ../../../tools/_raw/p3/unified_ui/detail_modal_whole.png 自动取 ink「∧」 | ink [997, 502, 14, 13] → label [987, 495, 34, 23] | NotoSerifSC 15px，实测 ink 15×12，色 #F2EFF2 |
| det_pick | flatbox | 整图量取 | [1456, 537, 411, 44] | {'bg': '#00000000'} |
| fx_beacon | ninepatch | 切片 p6_beacon_badge | [975, 363, 55, 55] | 轮廓 NCC 0.000，缩放 1.000 |
| fx_beacon_text 文字 | text_style | 锚点 整图 ../battle_fx/design_low_noise.png 自动取 ink「3」 | ink [997, 379, 11, 20] → label [981, 368, 46, 38] | NotoSerifSC 26px，实测 ink 14×19，色 #F5D869 |
| fx_toast | ninepatch | 切片 p6_placement_blocked_bubble | [734, 557, 286, 57] | 轮廓 NCC 0.000，缩放 1.000 |
| fx_toast_text 文字 | text_style | 锚点 整图 ../battle_fx/design_low_noise.png 自动取 ink「无法放置：障碍格不能放置」 | ink [757, 574, 238, 20] → label [739, 568, 276, 30] | NotoSerifSC 20px，实测 ink 240×21，色 #E34840 |
