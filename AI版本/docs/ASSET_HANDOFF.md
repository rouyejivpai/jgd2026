# 资源方交接（程序侧 → 资源 AI）

程序侧整合已完成：资源放到约定路径并 `--import` 后自动生效，不需要改代码。下表只列程序侧发现的问题与约定，供资源 AI 处理。

## 1. 需要资源方处理
| 编号 | 问题 | 建议 |
|---|---|---|
| A-01 | 背景中的墙体/荆棘与关卡阻挡格对不齐：第三关哀嚎墙约高半格；第八关荆棘墙位置偏移 | 背景按关卡网格（地图宽×高格，居中裁切到地图比例）重出或把结构物去掉，阻挡格由道具精灵表现 |
| A-02 | 背景整体偏亮偏卡通，需要 CanvasModulate 压暗后才贴合调色板 | 重出时降低明度与饱和度 |
| A-03 | 尚缺：BGM 7 段、SFX 32 条、程序化贴图（projectiles、vfx、ui 控件）、SVG 图标 | 见 tasks/资源生产任务包_GPT.md 第三～五阶段；文件名与路径必须一致 |

## 2. 程序侧读取约定（已实现）
- 背景 `assets/backgrounds/<level.background>.png`：居中裁切到地图宽高比，缩放到地图像素，四边 96 px 渐隐。
- 道具 `assets/sprites/props/<name>.png`：按 `data/biomes.json` 放在每个阻挡格，缩放 0.42，底部对齐格子；墙/荆棘按端段/中段变体，右端自动镜像。
- 单位 `assets/sprites/units/<id>.png`：缩放 0.5，脚底在格心下方；敌方自动水平翻转面向左。
- 头像 `portraits/<id>.png`、立绘 `illustrations/doll.png`、`witch.png`；主菜单 `ui/key_art_menu.png`；关卡选择 `ui/chapter_map_plain.png`（55% 不透明叠底）。
- 音频：BGM `assets/audio/bgm/<name>.mp3`（循环）；SFX/环境 `assets/audio/sfx/<name>.(ogg|wav|mp3)`。
- 主题贴图到位后运行 `tools/make_theme.gd` 重生成主题；导入预设运行 `python tools/apply_import_presets.py` 后再 `--import`。
