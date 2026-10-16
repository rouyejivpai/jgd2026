# 资源评审修正记录

日期：2026-10-04  
依据：`docs/ASSET_REVIEW.md`。BGM 不在本次范围内。

## 已应用

- **UI 图标**：修正待机、目标选择、倍速、追击、撤退可行、攻击、攻击属性、提示、血量阈值与超距状态等图标。完成 43 个 SVG 图标的 72px 联系表检查；新增 `dropdown_arrow.svg` 和 `drag_handle.svg`。程序生成的图标、柔边圆、阵营底座、骨质面板和下拉框底图已同步更新。
- **朝向**：水平镜像 `hound.png` 与 `lancer.png`，源素材现朝右。
- **Q 版单位**：更新 `bone_guard`、`brute`、`husk`、`priest`、`raider`、`warden`、`spitter`；另更新 Q 版 `bulwark`、`swift`。外观采用不同体型与轮廓，spitter 改为张口蜥蜴状血肉口器。
- **背景**：替换并调色 L2–L8。L2 谷仓位于实际可见带；L3/L4/L6 中央不再预画障碍；L8 的荆棘位置与障碍带一致。各图保持 1536×1024，实测平均亮度：L2 87.5、L3 87.5、L4 87.5、L5 75.5、L6 87.5、L7 71.5、L8 71.5。
- **章节地图**：保留四区域和路线、无文字，改成暗旧羊皮纸配色，保持 1920×1080。
- **墙与荆棘**：四个端段/中段主体统一为 170px 高，基线 y=232；按 96px 地图格距缩放预览，中段可连续拼接。
- **职责立绘**：替换蛮兵和迅袭立绘，强化厚重骨板与前倾长肢剪影。重做女巫构图留白，保留透明背景、角色设计和姿势；画布 768×1152，主体 alpha 框为 `(36, 99, 731, 1128)`，不再贴边或裁切骨爪、衣摆和鞋尖。
- **低噪点要求**：新绘资源统一使用干净线稿、宽阔色块和平滑阴影，提示明确排除颗粒、点描、密集划痕和碎小装饰；面板纹理使用缓慢变化的宽波段色差，没有叠加颗粒噪点。
- **字体**：`Cinzel-Bold.ttf` 原先与 Regular 相同。现以 `Cinzel-Bold.tres` 读取 `Cinzel-Regular.ttf` 的 `wght=700` 轴，`blast_marker.gd` 已切到该资源。Godot 的 `FontVariation` 支持 OpenType 轴坐标；当前未在 Godot 编辑器或运行时验证导入与实际字形显示。[Godot FontVariation 文档](https://docs.godotengine.org/en/4.5/classes/class_fontvariation.html)
- **字体打包**：Unifont 仅被 `tools/gen_alchemy_phrase.py` 用作离线像素字形，不是游戏运行时字体。OTF 和许可证现放在 `tools/assets/fonts/`，生成器路径已更新，避免随游戏打包。
- **规格外演示资源**：`burning_title`、`qu_li_bi_hai`、`qu_li_bi_hai_alchemy` 已移出 `assets/`，保存在 `tools/_raw/review_archive/spec_extras/`。检查时未发现游戏运行时引用。
- **环境音循环**：`amb_wind.wav` 与 `amb_greenhouse.wav` 使用 120ms 首尾交叉淡化并裁齐，不再循环首尾淡入淡出。实测分别为 24.88s / 29.88s，peak 0.45；首尾 150ms RMS 分别为 0.0759/0.0870、0.0820/0.0840，边界样本平均差 0.00204、0.00046。

## 尚未完成

`dialogue_advance.ogg` 开头 74ms 静音未裁。当前执行环境没有 FFmpeg、SoX、Godot 或可用 OGG/Vorbis 编解码模块，且网络受限，无法安装解码器；因此保留了该源文件，未做未经解码的破坏性裁切。

## 检查范围

- 已核对正式图片尺寸、透明 alpha 框、道具高度/基线和背景亮度，并目检单位、立绘、道具、背景及 72px 图标联系表。
- 已核对两个环境 WAV 的时长、电平和循环接缝。
- 未启动 Godot 编辑器、未运行游戏导入或 1920×1080 实机截图；字体运行时呈现与最终场景合成仍需工程侧 `--import` / 实机确认。
- 本次没有修改 BGM。原素材备份位于 `tools/_raw/review_before/assets/`，候选文件位于 `tools/_raw/review_candidates/`。
