# R4 场景大地图与障碍候选包

日期：2026-10-06。状态：候选资源已齐，等待整批场景美术审阅；尚未接入运行关卡。

## 文件

[八关场景总览](../godot/assets/backdrops/review_r4/contact_sheet.png)

输出目录：`godot/assets/backdrops/review_r4/`。每关有 `level_0X_full.png`、`level_0X_base.png` 和 `obstacles/level_0X/obstacles.json`；有阻挡格的关卡另有透明 PNG 切片。8 组 full/base 都是 1920×1080。无阻挡格的 01、02、07 关 full 与 base 像素完全相同。

| 关卡 | 场景 | blocked / 障碍切片 |
|---|---|---|
| 01 | [full](../godot/assets/backdrops/review_r4/level_01_full.png) · [base](../godot/assets/backdrops/review_r4/level_01_base.png) | 无 |
| 02 | [full](../godot/assets/backdrops/review_r4/level_02_full.png) · [base](../godot/assets/backdrops/review_r4/level_02_base.png) | 无 |
| 03 | [full](../godot/assets/backdrops/review_r4/level_03_full.png) · [base](../godot/assets/backdrops/review_r4/level_03_base.png) | `[4..12,2]`，低矮石墙；[01.png](../godot/assets/backdrops/review_r4/obstacles/level_03/01.png) · [obstacles.json](../godot/assets/backdrops/review_r4/obstacles/level_03/obstacles.json) |
| 04 | [full](../godot/assets/backdrops/review_r4/level_04_full.png) · [base](../godot/assets/backdrops/review_r4/level_04_base.png) | `[3,3]`、`[8,3]`、`[3,8]`、`[8,8]`，四个低矮根团；[01](../godot/assets/backdrops/review_r4/obstacles/level_04/01.png) · [02](../godot/assets/backdrops/review_r4/obstacles/level_04/02.png) · [03](../godot/assets/backdrops/review_r4/obstacles/level_04/03.png) · [04](../godot/assets/backdrops/review_r4/obstacles/level_04/04.png) · [obstacles.json](../godot/assets/backdrops/review_r4/obstacles/level_04/obstacles.json) |
| 05 | [full](../godot/assets/backdrops/review_r4/level_05_full.png) · [base](../godot/assets/backdrops/review_r4/level_05_base.png) | `[7..8,4]`，贴地碎木堆；[01.png](../godot/assets/backdrops/review_r4/obstacles/level_05/01.png) · [obstacles.json](../godot/assets/backdrops/review_r4/obstacles/level_05/obstacles.json) |
| 06 | [full](../godot/assets/backdrops/review_r4/level_06_full.png) · [base](../godot/assets/backdrops/review_r4/level_06_base.png) | `[8..11,4..5]`，低矮遗迹石板；[01.png](../godot/assets/backdrops/review_r4/obstacles/level_06/01.png) · [obstacles.json](../godot/assets/backdrops/review_r4/obstacles/level_06/obstacles.json) |
| 07 | [full](../godot/assets/backdrops/review_r4/level_07_full.png) · [base](../godot/assets/backdrops/review_r4/level_07_base.png) | 无 |
| 08 | [full](../godot/assets/backdrops/review_r4/level_08_full.png) · [base](../godot/assets/backdrops/review_r4/level_08_base.png) | `[6..11,2]` 与 `[6..11,8]`，两排低矮荆棘；[01](../godot/assets/backdrops/review_r4/obstacles/level_08/01.png) · [02](../godot/assets/backdrops/review_r4/obstacles/level_08/02.png) · [obstacles.json](../godot/assets/backdrops/review_r4/obstacles/level_08/obstacles.json) |

所有 `cells` 均取自各关现有 `grid.blocked`，位置与大小依 `tools/print_playfield_rects.py` 和 `tools/obstacle_check.py` 中的玩法矩形公式计算。切片保留原生透明 alpha，`anchor_px` 为 `[0,0]`，`size_px` 对应所占格外接框像素尺寸。01、02、07 也附空 `pieces` 清单，方便夹具中统一验证。

## 生成与来源

障碍使用内置 image_gen 生成原生透明位图，没有使用 SVG。共 8 次生成/编辑调用：五类障碍各生成一次，之后将石墙、根团、碎木堆分别按低矮贴地要求定向编辑一次。最终采用：一段低矮石墙、单格根团、平放碎木堆、矮遗迹石板、长条荆棘根。输出 PNG 为按阻挡格尺寸排布的切片，full 由 base 与切片逐像素合成。

最终 prompt 要点：

| 素材 | Prompt 要点 |
|---|---|
| 石墙 | 灰紫碎石、一层塌落矮墙、连续横向九格、清除高端垛与多层砌石、原生透明底 |
| 根团 | 暗色扭根与少量干血红叶、单格紧凑、地面低伏、移除高环形根枝、原生透明底 |
| 碎木 | 灰紫石屑与暗木板、横向两格、木板平放、清除直立/斜立木板、高度低于一单位、原生透明底 |
| 遗迹石板 | 破碎石板与克制金色炼金纹样、四乘二格、贴地、无柱体、原生透明底 |
| 荆棘根 | 暗根与少量干血红叶、六格长条、稀疏贴地、后排单位仍可见、原生透明底 |

场景底图沿用 `review_low_noise` 的八张审阅整图；五张有阻挡格的 base 沿用 `tools/_raw/p3/remaining_review/level_0X_base_native.png`。原始图为 1672×941，本候选包缩放至 1920×1080，尺寸符合任务格式，但不是原生 1920 细节。该限制应在正式接入前由美术审阅确认。

## 检查结果

| 关卡用例 | 输出尺寸 | blocked覆盖 | 障碍块数 | 回贴差异 |
|---|---:|---:|---:|---:|
| level_01 | 1920×1080 | 0/0 | 0 | 0.00%，通过 |
| level_02 | 1920×1080 | 0/0 | 0 | 0.00%，通过 |
| level_03 | 1920×1080 | 9/9 | 1 | 0.00%，通过 |
| level_04 | 1920×1080 | 4/4 | 4 | 0.00%，通过 |
| level_05 | 1920×1080 | 2/2 | 1 | 0.00%，通过 |
| level_06 | 1920×1080 | 8/8 | 1 | 0.00%，通过 |
| level_07 | 1920×1080 | 0/0 | 0 | 0.00%，通过 |
| level_08 | 1920×1080 | 12/12 | 2 | 0.00%，通过 |

附加用例：9/9 张障碍 PNG 同时含透明像素和不透明主体，通过；无阻挡格关卡 full/base 像素相同，01/02/07 共 3/3，通过；`validate_data.py` 在隔离夹具中通过，夹具复制现有关卡数据后只加入 R4 场景路径并校验 manifest 文件与 `cells ⊆ blocked`。真实运行关卡数据本轮未修改，`scene.obstacles` 尚未写入真实 `data/levels`。

## 审阅后步骤

整图与障碍对应关系需由用户目视确认后，才能从 `review_r4/` 转为正式资源并把 `scene.backdrop`、`scene.obstacles` 接入关卡数据。该候选包尚未执行 Godot 实机截图验收。
