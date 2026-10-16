# 文字绑定与接入说明

常规文字由游戏字体渲染，切片不含这些字；只有game_title_art是艺术字图像。preview.json为资源比对样例及字体/文字绑定元数据，不是新增游戏运行接口。

| 元素id | strings key | 示例文字 | 字体文件 | 对齐 |
|---|---|---|---|---|
| `title` | `ui.menu_settings` | 设置 | `NotoSerifSC-Bold.otf` | left / 垂直居中 |
| `btn_close` | `ui.settings_close` | 关闭 | `NotoSerifSC-Regular.otf` | center / 垂直居中 |
| `section_audio` | `ui.settings_section_audio` | 声音 | `NotoSerifSC-Regular.otf` | left / 垂直居中 |
| `label_master` | `ui.settings_master` | 主音量 | `NotoSerifSC-Regular.otf` | left / 垂直居中 |
| `pct_master` | `(静态/动态值)` | 100% | `Cinzel-Regular.ttf` | left / 垂直居中 |
| `label_music` | `ui.settings_music` | 音乐 | `NotoSerifSC-Regular.otf` | left / 垂直居中 |
| `pct_music` | `(静态/动态值)` | 80% | `Cinzel-Regular.ttf` | left / 垂直居中 |
| `label_sfx` | `ui.settings_sfx` | 音效 | `NotoSerifSC-Regular.otf` | left / 垂直居中 |
| `pct_sfx` | `(静态/动态值)` | 85% | `Cinzel-Regular.ttf` | left / 垂直居中 |
| `section_display` | `ui.settings_section_display` | 显示 | `NotoSerifSC-Regular.otf` | left / 垂直居中 |
| `label_fullscreen` | `ui.settings_fullscreen` | 全屏 | `NotoSerifSC-Regular.otf` | left / 垂直居中 |
| `label_target_lines` | `ui.settings_target_lines` | 显示目标连线 | `NotoSerifSC-Regular.otf` | left / 垂直居中 |
| `label_font_scale` | `ui.settings_font_scale` | 字体大小 | `NotoSerifSC-Regular.otf` | left / 垂直居中 |
| `font_scale_value` | `ui.settings_font_scale_option` | 100% | `Cinzel-Regular.ttf` | left / 垂直居中 |
| `section_debug` | `ui.settings_section_debug` | 调试 | `NotoSerifSC-Regular.otf` | left / 垂直居中 |
| `label_sim_log` | `ui.settings_sim_log` | 记录模拟日志（调试用） | `NotoSerifSC-Regular.otf` | left / 垂直居中 |
| `log_hint` | `ui.settings_log_hint` | 日志位置：user://logs/ | `NotoSerifSC-Regular.otf` | left / 垂直居中 |

manifest只包含浮窗层，不加载主菜单背景；设计比对以当前主菜单为上下文。切片阴影/alpha均需保留。百分比、把手位置、fill宽度是样例值，实际由GameState.settings和HSlider驱动；轨、fill、grabber三层对应同一滑条。fill须保留两端圆角（九宫格），不能从全长图直接硬裁。toggle切片实际81×37，是原PIL包含右/下端像素的绘制尺寸，点击尺寸仍可用80×36。字体倍率选项仍为100/115/130%。日志路径动态替换。grabber焦点/拖动/禁用四态在common中；按钮/下拉四态按states字段。
