"""片尾群二维码（2026-10-20 用户定稿：黑底白码，和结束卡的黑底融在一起）：按群链接重新编码，透明底（游戏里压在纯黑上）、
骨白圆角方点与圆角定位角，中心一颗红菱（灵魂）。反色码（深底浅码）手机 QQ / 微信扫码均支持；
校验时合成到黑底、反色后用 zbar 在三档缩放下解码，扫不出来就报错退出。
用法（在 godot/ 目录，需 pip install qrcode pyzbar pillow numpy）：python -I tools/credits/make_qr.py assets/credits/qq_group_qr.png
"""
import sys
import numpy as np
import qrcode
from PIL import Image, ImageDraw

URL = "https://qm.qq.com/q/PDW4OQdvc4?from=tim"
DOT = (232, 220, 196, 255)     ## Palette.BONE
BLOOD = (179, 26, 44, 255)
SIZE = 1200            ## 输出边长
SS = 2                 ## 超采样倍数（抗锯齿）
QUIET = 4              ## 码区留白（模块数，透明 = 黑）


def diamond(d: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float, fill, outline=None, width: int = 0) -> None:
	d.polygon([(cx, cy - ry), (cx + rx, cy), (cx, cy + ry), (cx - rx, cy)], fill=fill, outline=outline, width=width)


def render() -> Image.Image:
	qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, border=0)
	qr.add_data(URL)
	qr.make(fit=True)
	m = np.array(qr.get_matrix(), dtype=bool)
	n = m.shape[0]
	W = SIZE * SS
	img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	cell = W / (n + QUIET * 2)
	off = QUIET * cell
	finders = [(0, 0), (0, n - 7), (n - 7, 0)]

	def in_finder(r: int, c: int) -> bool:
		return any(fr <= r < fr + 7 and fc <= c < fc + 7 for fr, fc in finders)

	k = cell * 2.6                         # 中心红菱半高；菱形周围整格空出（不画被切掉一半的点），面积远小于 H 级纠错容量
	krx, kry = k * 0.72 + cell * 0.9, k + cell * 0.9

	def in_heart(r: int, c: int) -> bool:
		dx = abs(off + (c + 0.5) * cell - W / 2)
		dy = abs(off + (r + 0.5) * cell - W / 2)
		return dx / krx + dy / kry <= 1.0

	for r in range(n):
		for c in range(n):
			if m[r, c] and not in_finder(r, c) and not in_heart(r, c):
				x, y = off + c * cell, off + r * cell
				p = cell * 0.1
				d.rounded_rectangle([x + p, y + p, x + cell - p, y + cell - p], radius=cell * 0.34, fill=DOT)
	for fr, fc in finders:
		x, y = off + fc * cell, off + fr * cell
		d.rounded_rectangle([x, y, x + 7 * cell, y + 7 * cell], radius=cell * 1.6, fill=DOT)
		d.rounded_rectangle([x + cell, y + cell, x + 6 * cell, y + 6 * cell], radius=cell * 1.1, fill=(0, 0, 0, 0))
		d.rounded_rectangle([x + 2 * cell, y + 2 * cell, x + 5 * cell, y + 5 * cell], radius=cell * 0.7, fill=DOT)
	diamond(d, W / 2, W / 2, k * 0.72, k, BLOOD)
	return img.resize((SIZE, SIZE), Image.LANCZOS)


def decode(img: Image.Image) -> str:
	"""合成到黑底（同游戏里），反色后 zbar 在原尺寸 / 0.6 / 0.4 三档都要解出同一个链接（模拟远近不同的手机扫码）"""
	from PIL import ImageOps
	from pyzbar.pyzbar import decode as zbar
	flat = Image.new("RGB", img.size, (0, 0, 0))
	flat.paste(img, mask=img.split()[3])
	flat = ImageOps.invert(flat)
	for s in (1.0, 0.6, 0.4):
		small = flat.resize((int(flat.width * s), int(flat.height * s)), Image.LANCZOS)
		if URL not in [r.data.decode("utf-8") for r in zbar(small)]:
			return ""
	return URL


def main() -> None:
	out = sys.argv[1]
	img = render()
	text = decode(img)
	if text != URL:
		sys.exit("QR check failed: %r" % text)
	img.save(out)
	print("ok", out, img.size, text)


if __name__ == "__main__":
	main()
