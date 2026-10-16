# 文字绑定与接入说明

常规文字由游戏字体渲染，切片不含这些字；只有game_title_art是艺术字图像。preview.json为资源比对样例及字体/文字绑定元数据，不是新增游戏运行接口。

| 元素id | strings key | 示例文字 | 字体文件 | 对齐 |
|---|---|---|---|---|
| `subtitle` | `(静态/动态值)` | ARTIFICIAL DIVINITY | `Cinzel-Regular.ttf` | left / 垂直居中 |
| `btn_start` | `ui.menu_start` | 开始 | `NotoSerifSC-Bold.otf` | center / 垂直居中 |
| `btn_settings` | `ui.menu_settings` | 设置 | `NotoSerifSC-Regular.otf` | center / 垂直居中 |
| `btn_quit` | `ui.menu_quit` | 退出 | `NotoSerifSC-Regular.otf` | center / 垂直居中 |

首项在设计图中有默认键盘焦点，使用hover切片；focus复用hover样式。error_manifest是完整错误状态样例，首项disabled；实际运行只在DataRegistry.has_errors时显示error_bar/error_text。所有按钮text_rect的中心与设计图一致。
