# 剩余资源生成与检查记录 · 2026-10-05

本轮交付仅为资源审阅，不覆盖 Godot 的运行时素材。

## 新生成资源

- 原生绘图主标题金光最亮帧整图：`title_peak_native.png`。
- 复用已确认原图与标题透明素材的 4.8 秒循环预览：`title_motion.html`；准确坐标的最亮帧：`title_peak_exact.png`。此预览是动效演示，没有新增 UI 切图。
- 第 03、04、05、06、08 关去障碍底图：五个 `level_XX_base_native.png`。第 01、02、07 关 blocked 为空，复用现有整图，避免重复生成。
- 原生输出的真实尺寸见下表；仍是审阅稿，尚未归一化为 R4 最终的 1920×1080 交付。

## 检查用例与结果

| 用例 | 内容 | 结果 | 证据 |
|---|---|---|---|
| T01 | 静止帧与已确认 design.png 逐像素比较 | 通过 | 0 不同像素 |
| T02 | 最亮帧标题作用区域之外逐像素比较 | 通过 | 0 不同像素 |
| T03 | 动效确实产生金光变化 | 通过 | 44999 变化像素 |
| T04 | 4.8 秒循环端点一致 | 通过 | 循环终点与起点 PNG 字节一致 |
| S05 | 已确认源文件未改写：assets/ui/main_menu/design.png | 通过 | SHA-256 相同 |
| S06 | 已确认源文件未改写：assets/ui/main_menu/slices/game_title_art.png | 通过 | SHA-256 相同 |
| S07 | 已确认源文件未改写：assets/backdrops/review_low_noise/level_01_full_review.png | 通过 | SHA-256 相同 |
| S08 | 已确认源文件未改写：assets/backdrops/review_low_noise/level_02_full_review.png | 通过 | SHA-256 相同 |
| S09 | 已确认源文件未改写：assets/backdrops/review_low_noise/level_03_full_review.png | 通过 | SHA-256 相同 |
| S10 | 已确认源文件未改写：assets/backdrops/review_low_noise/level_04_full_review.png | 通过 | SHA-256 相同 |
| S11 | 已确认源文件未改写：assets/backdrops/review_low_noise/level_05_full_review.png | 通过 | SHA-256 相同 |
| S12 | 已确认源文件未改写：assets/backdrops/review_low_noise/level_06_full_review.png | 通过 | SHA-256 相同 |
| S13 | 已确认源文件未改写：assets/backdrops/review_low_noise/level_07_full_review.png | 通过 | SHA-256 相同 |
| S14 | 已确认源文件未改写：assets/backdrops/review_low_noise/level_08_full_review.png | 通过 | SHA-256 相同 |
| F15 | 原生生成文件可解码且横版比例符合 16:9：title_peak_native.png | 通过 | 1672×941；原生输出，不伪称1920×1080 |
| F16 | 原生生成文件可解码且横版比例符合 16:9：level_03_base_native.png | 通过 | 1672×941；原生输出，不伪称1920×1080 |
| F17 | 原生生成文件可解码且横版比例符合 16:9：level_04_base_native.png | 通过 | 1672×941；原生输出，不伪称1920×1080 |
| F18 | 原生生成文件可解码且横版比例符合 16:9：level_05_base_native.png | 通过 | 1672×941；原生输出，不伪称1920×1080 |
| F19 | 原生生成文件可解码且横版比例符合 16:9：level_06_base_native.png | 通过 | 1672×941；原生输出，不伪称1920×1080 |
| F20 | 原生生成文件可解码且横版比例符合 16:9：level_08_base_native.png | 通过 | 1672×941；原生输出，不伪称1920×1080 |
| V03 | 去障碍底图目视检查 · 第03关 | 通过 | 低矮横墙移除，石板地面延续；未见明显残留或新增阻挡物，边缘场景风格保持 |
| V04 | 去障碍底图目视检查 · 第04关 | 通过 | 四个根堆移除，土质地面延续；未见明显残留或新增阻挡物，边缘场景风格保持 |
| V05 | 去障碍底图目视检查 · 第05关 | 通过 | 中央碎木堆移除，平坦地面延续；未见明显残留或新增阻挡物，边缘场景风格保持 |
| V06 | 去障碍底图目视检查 · 第06关 | 通过 | 中央低矮遗迹移除，石板和炼金线纹延续；未见明显残留或新增阻挡物，边缘场景风格保持 |
| V08 | 去障碍底图目视检查 · 第08关 | 通过 | 两道荆棘移除，浅紫地砖延续；未见明显残留或新增阻挡物，边缘场景风格保持 |

自动检查 20/20 通过，目视检查 5/5 通过。检查范围只包括本轮资源及演示：不代表 Godot 实机性能、接入或障碍物回贴验收。

## 尚未完成的交付

- R6a：等主标题动效视觉判断后，再交付最终动效分层、manifest 与 motion.md。当前循环仅为预览，不宣称最终图层已交付。
- R6b：章节标题、关卡名牌、胜利/失败、战斗开始艺术字依照已定顺序，须主标题动效目视通过后继续生成。
- R4：已制作完整候选包 `godot/assets/backdrops/review_r4/`，8关 full/base、9张透明切片和8份 obstacles.json；5关共35个 blocked 格全部覆盖，隔离夹具回贴差异0.00%。候选整图待用户目视确认，正式运行资源与关卡数据尚未接入。详见 `R4_ASSET_REVIEW.md`。
- R2/R3/R5 等已有整图继续复用；尚未拆分的界面遵照先整图判断后拆分的流程。

## 视觉规范

主标题保留已确认字形与位置，轻缓金光呼吸，不使用火焰、粒子噪声或额外边框。预览 t=0 与 design.png 像素完全一致；峰值只改变标题周围光晕区域。原生绘图整图用于判断效果方向，不能用生成器的重绘结果替换已确认字形。背景以已有低噪声场景为参考，仅移除指定内部障碍。
