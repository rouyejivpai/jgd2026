"""片尾对话框装饰（2026-10-20）：从剧情对话框切图 assets/ui/gothic/dialogue_box.png 里抠出名牌两侧的银白弯刃，
按亮度转成「白色 + alpha」的透明贴图，供 credits_bubble.gd 夹在名字两侧；
并从指令详情面板底图 assets/ui/gothic/cmd_panel.png 切出头像位周围的一块（灰色圆盘外沿、两侧银白弯刃、红蓝星芒），
左右镜像（实机面板镜像在右侧）、外圈径向渐隐成透明，作为片尾头像的底座 portrait_backdrop.png（头像本身仍按实机用 circle_mask 金圈）。
用法（在 godot/ 目录）：python -I tools/credits/cut_ornaments.py
"""
import numpy as np
from PIL import Image

SRC = "assets/ui/gothic/dialogue_box.png"
OUT = "assets/credits/"
## 弯刃在 dialogue_box.png 中的范围（x0, y0, x1, y1），名牌位于整图 y = 516 + 210 起
BLADES = {"name_blade_l.png": (200, 204, 262, 318), "name_blade_r.png": (657, 204, 720, 318)}


def key_out(img: Image.Image) -> Image.Image:
	"""背景是紫灰渐变：按每列上下两端估背景亮度，比背景亮出的部分转成 alpha"""
	a = np.asarray(img.convert("RGB")).astype(np.float32)
	lum = a.mean(axis=2)
	bg = np.minimum(lum[:6].mean(axis=0), lum[-6:].mean(axis=0))      # 每列背景亮度
	alpha = np.clip((lum - bg[None, :] - 6.0) / (235.0 - bg[None, :]), 0.0, 1.0)
	alpha = np.clip(alpha * 1.25, 0.0, 1.0)
	out = np.zeros((a.shape[0], a.shape[1], 4), np.uint8)
	out[:, :, :3] = 245
	out[:, :, 3] = (alpha * 255).astype(np.uint8)
	return Image.fromarray(out, "RGBA")


PANEL = "assets/ui/gothic/cmd_panel.png"
PORTRAIT_CENTER = (113, 131)   ## side_detail 布局 det_portrait [38, 56, 150, 150] 的圆心
BACKDROP_R = 132               ## 切出半径（含弯刃与星芒）
FADE_FROM = 0.72               ## 从该半径比例开始渐隐到 0


def cut_backdrop() -> None:
	panel = Image.open(PANEL).convert("RGBA")
	cx, cy = PORTRAIT_CENTER
	r = BACKDROP_R
	img = panel.crop((cx - r, cy - r, cx + r, cy + r)).transpose(Image.FLIP_LEFT_RIGHT)
	a = np.asarray(img).astype(np.float32)
	yy, xx = np.mgrid[0:2 * r, 0:2 * r]
	d = np.sqrt((xx - r + 0.5) ** 2 + (yy - r + 0.5) ** 2) / r
	fade = np.clip((1.0 - d) / (1.0 - FADE_FROM), 0.0, 1.0)
	fade = fade * fade * (3.0 - 2.0 * fade)
	a[:, :, 3] *= fade
	Image.fromarray(a.astype(np.uint8), "RGBA").save(OUT + "portrait_backdrop.png")
	print("portrait_backdrop.png", img.size)


def main() -> None:
	cut_backdrop()
	box = Image.open(SRC).convert("RGBA")
	for name, rect in BLADES.items():
		cut = key_out(box.crop(rect))
		bbox = cut.getbbox()
		cut = cut.crop(bbox) if bbox else cut
		cut.save(OUT + name)
		print(name, cut.size)


if __name__ == "__main__":
	main()
