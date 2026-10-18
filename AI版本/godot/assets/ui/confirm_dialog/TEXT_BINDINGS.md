# 文字绑定与接入说明（确认弹窗）

通用确认弹窗，目前用于主菜单「新游戏」清档确认。没有独立切片：遮罩、底板、分隔线复用 `settings_overlay/slices`，两个按钮复用设置浮窗「关闭」按钮四态（九宫格拉宽）。
文字由调用方按场景传入 strings key（下表为主菜单「新游戏」的用法）；正文自动换行。

| 元素id | strings key | 示例文字 | 字体文件 | 对齐 |
|---|---|---|---|---|
| `title` | `ui.new_game_confirm_title` | 开始新游戏 | `NotoSerifSC-Bold.otf` | center |
| `body` | `ui.new_game_confirm_body` | 开始新游戏会清空全部存档…… | `NotoSerifSC-Regular.otf` | center / 自动换行 |
| `btn_ok` | `ui.new_game_confirm_ok` | 清空并开始 | `NotoSerifSC-Regular.otf` | center |
| `btn_cancel` | `ui.new_game_confirm_cancel` | 取消 | `NotoSerifSC-Regular.otf` | center |

打开时默认焦点在「取消」（防误触）；Esc 等同取消；遮罩挡住下层点击。
