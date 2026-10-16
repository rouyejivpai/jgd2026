# battle_start · 静态艺术字交付

本包基于已批准的 R6b 源图提取。静止态 t=0 只显示 base.png；glow.png 在 t=0 隐藏。保留源字形颜色、描边和源图中可见的光效。资产坐标见 manifest.json。

当前不播放扫光、循环帧、缩放或位移动效；本轮没有为这些效果建立验收基准。sweep_mask.png 与帧序列因此不提供。程序侧接入时应将 base.png 作为默认静止层，glow.png 仅在后续明确启用时使用。

源图：godot/tools/_raw/p3/art_text_review/battle_start.png
源图分辨率：1672×941
源图裁切：[590, 345, 490, 150]
提取说明：亮金色文字按源图像素提取；角色遮挡区域留透明，便于运行时角色层保持在字样前方。
