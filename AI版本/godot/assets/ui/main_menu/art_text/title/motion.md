# 主标题艺术字动效 · 已确认 2026-10-06

静态基准：原主菜单 design.png 与原 game_title_art.png。标题 rect 为 [148,261,580,149]；base.png 字节完全复用原透明字形，不改位置、字号或轮廓。

时长 3.6 秒，循环。phase = t mod 3.6，envelope = sin(π·phase/3.6)²。t=0：base 显示，其他图层透明，冻结时与静态设计一致。

叠加顺序：base → glow → sweep。glow.png 为已确认预览中提取的光晕，660×229，标题局部偏移 (-40,-40)，screen 混合，opacity = 0.95×envelope。screen 公式：result = 1-(1-destination)×(1-source×opacity)，不可替换为强度不同的 Add 混合。

sweep_frames/0000.png…0107.png 是 30 fps、108 帧透明扫光覆盖层（不是含底字的整标题帧），局部偏移 (0,0)，普通 source-over 混合；透明度已经烘焙，不要再次乘 envelope。下一循环返回 0000。可选用 sweep_mask.png 在 shader 中实现同样渐变：中心从 -130 移到 710，半宽 110；色标和透明度参数见 manifest。该 mask 与原字形 alpha 完全一致。

不移动字形、不做缩放、无颗粒。只播放主标题，不影响普通文字与按钮。motion_enabled=false 或 disabled 时使用 base.png 并隐藏 glow 与 sweep。

本目录是资源交付，现行 apply_ui_manifest.py 尚未注册 art_text；本次不改动该工具或运行时布局，由程序方按 P8 接入。审阅预览仍位于 tools/_raw/p3/remaining_review/title_motion.html。
