#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""第四阶段：用资源目录的人物 / 怪物设定图（H:/其他/人工神灵/resource/人物角色设计（人物+部分怪））替换能对应上的游戏图。
对应关系（设定图上的手写标注 / 角色身份）：
  人偶 (2).png 中间一版（发饰版）→ 基础攻击形态 striker（单位精灵 + 头像）、剧情立绘 doll
  魔女 (2).png                     → 剧情立绘 witch
  红色猎犬设定（标注"猎犬更加狂暴"）左上一只 → 骸猎犬 hound（单位精灵 + 头像；原图朝左，水平翻转为默认朝右）
  骨花设定 左侧主图                → 骨花核心 bone_core（第八关首领；单位精灵 + 头像）
其余设定（钟、蓝树、白衣女鬼、高帽人、恐惧、愤怒）在第一章没有对应单位，未使用。
处理：抠图（已透明的直接用；白底 / 黑底用 rembg isnet-anime）→ 按原图的不透明外框等比放入（脚底对齐原图），头像 = 头部方形裁切 + 深紫径向底。
原图备份到 tools/_work/char_backup_20261008/（不入库），可用 --restore 还原。
用法（godot/ 目录）：python tools/import_character_designs.py [--restore]
"""
import io
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GODOT = Path(__file__).resolve().parent.parent
SRC = GODOT.parent.parent / "resource" / "人物角色设计（人物+部分怪）"
BACKUP = GODOT / "tools/_work/char_backup_20261008"
SPR = GODOT / "assets/sprites"

# 名称 → (源文件名, 源图裁切框 或 "component:<序号>", 是否水平翻转, 头像框（裁切后图上的比例 [x0, y0, x1, y1]）, 输出列表)
JOBS = {
    "doll": ("人偶 (2).png", "component:1", False, [0.12, 0.0, 0.88, 0.40], ["units/striker.png", "portraits/striker.png", "illustrations/doll.png"]),
    "witch": ("魔女 (2).png", None, False, None, ["illustrations/witch.png"]),
    "hound": ("NR8AVjViQ2dBeE1USTNPRFUzTkRRemZJRENhdjFVTmk0IQUAcXVuZ3o!.png", (200, 90, 1200, 610), True, [0.66, 0.0, 1.0, 0.62], ["units/hound.png", "portraits/hound.png"]),
    "bone_core": ("NR8AVjViQ2dBeE1USTNPRFUzTkRRemJRM0VhaHNNWlJjIQUAcXVuZ3o!.png", (60, 150, 960, 1360), False, [0.08, 0.04, 0.92, 0.62], ["units/bone_core.png", "portraits/bone_core.png"]),
}


def rembg_cut(im: Image.Image) -> Image.Image:
    from rembg import new_session, remove
    sess = new_session("isnet-anime")
    return remove(im.convert("RGB"), session=sess).convert("RGBA")


def components(alpha: np.ndarray, min_area: int):
    import cv2
    n, lab, st, _ = cv2.connectedComponentsWithStats((alpha > 32).astype(np.uint8), 8)
    out = [(st[i, cv2.CC_STAT_LEFT], st[i, cv2.CC_STAT_TOP], st[i, cv2.CC_STAT_WIDTH], st[i, cv2.CC_STAT_HEIGHT], st[i, cv2.CC_STAT_AREA], i) for i in range(1, n) if st[i, cv2.CC_STAT_AREA] >= min_area]
    return sorted(out), lab


def cutout(name: str) -> Image.Image:
    fname, box, flip, _, _ = JOBS[name]
    im = Image.open(SRC / fname).convert("RGBA")
    a = np.array(im)[..., 3]
    if isinstance(box, str):                                  # 透明底：取第 n 个大连通块（按 x 排序）
        comps, lab = components(a, 20000)
        x, y, w, h, _, idx = comps[int(box.split(":")[1])]
        arr = np.array(im)
        arr[..., 3] = np.where(lab == idx, arr[..., 3], 0)
        im = Image.fromarray(arr).crop((x, y, x + w, y + h))
    else:
        if box is not None:
            im = im.crop(box)
        corners = np.array(im)[[0, 0, -1, -1], [0, -1, 0, -1]]
        if (corners[:, 3] > 200).all():                       # 四角不透明 = 白底 / 黑底：抠图
            im = rembg_cut(im)
        arr = np.array(im)
        comps, lab = components(arr[..., 3], 4000)            # 去掉零星的小装饰 / 污点，只留主体
        keep = [c[5] for c in comps if c[4] >= max(cc[4] for cc in comps) * 0.05]
        arr[..., 3] = np.where(np.isin(lab, keep), arr[..., 3], 0)
        im = Image.fromarray(arr)
        im = im.crop(im.getchannel("A").getbbox())
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return im


def fit_into(fig: Image.Image, canvas: tuple, target_box: tuple) -> Image.Image:
    """等比缩放放入 target_box（x0, y0, x1, y1），底边对齐、水平居中"""
    x0, y0, x1, y1 = target_box
    k = min((x1 - x0) / fig.width, (y1 - y0) / fig.height)
    f = fig.resize((max(1, round(fig.width * k)), max(1, round(fig.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    out.alpha_composite(f, (round((x0 + x1) / 2 - f.width / 2), y1 - f.height))
    return out


def portrait(fig: Image.Image, head: list, size: int = 512) -> Image.Image:
    w, h = fig.size
    x0, y0, x1, y1 = head[0] * w, head[1] * h, head[2] * w, head[3] * h
    side = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2, y0 + side / 2
    crop = fig.crop((round(cx - side / 2), round(cy - side / 2), round(cx + side / 2), round(cy + side / 2))).resize((size, size), Image.LANCZOS)
    bg = Image.new("RGBA", (size, size))
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.sqrt((xx - size / 2) ** 2 + (yy - size * 0.42) ** 2) / (size * 0.75)
    inner, outer = np.array([62, 36, 82]), np.array([16, 9, 22])
    col = inner[None, None, :] * (1 - d[..., None].clip(0, 1)) + outer[None, None, :] * d[..., None].clip(0, 1)
    bg = Image.fromarray(np.dstack([col, np.full((size, size), 255)]).astype(np.uint8), "RGBA")
    bg.alpha_composite(crop)
    return bg


CARD_SLICES = {"striker": GODOT / "assets/ui/unified_low_noise/slices/card_striker.png"}   # 出场卡切片里画着头像：把新头像合成进头像圆窗


def card_with_portrait(card_path: Path, portrait_img: Image.Image) -> Image.Image:
    """在卡片切片的头像圆窗内换上新头像：沿水平 / 竖直中线找金环内沿定圆心与半径，圆内贴新头像（金环与卡面不动）"""
    card = Image.open(card_path).convert("RGBA")
    a = np.array(card).astype(int)
    goldm = (a[..., 0] > 170) & (a[..., 1] > 120) & (a[..., 2] < 110)
    h, w = goldm.shape
    cx0 = w // 2
    col = np.nonzero(goldm[:, cx0])[0]
    top = col[(col > 20) & (col < h // 3)].min()                 # 圆环上沿（跳过顶上宝石的金边）
    bottom = col[(col > h // 4) & (col < h * 0.62)].max()        # 圆环下沿
    cy = (top + bottom) / 2
    row = np.nonzero(goldm[int(cy), :])[0]
    left, right = row[(row < cx0) & (row > 20)].max(), row[(row > cx0) & (row < w - 20)].min()
    cx = (left + right) / 2
    r = min(right - left, bottom - top) / 2 - 2.5                # 金环内侧（环略扁，取小半径）
    side = int(round(r * 2))
    p = portrait_img.resize((side, side), Image.LANCZOS)
    mask = Image.new("L", (side * 4, side * 4), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, side * 4 - 1, side * 4 - 1], fill=255)
    mask = mask.resize((side, side), Image.LANCZOS)
    out = card.copy()
    out.paste(p, (int(round(cx - side / 2)), int(round(cy - side / 2))), mask)
    return out


def main() -> int:
    if "--restore" in sys.argv:
        for f in BACKUP.rglob("*.png"):
            if f.parent.name == "cards":
                shutil.copy2(f, CARD_SLICES[f.stem.replace("card_", "")])
            else:
                shutil.copy2(f, SPR / f.relative_to(BACKUP))
            print("restored", f.relative_to(BACKUP))
        return 0
    for name, (fname, box, flip, head, outs) in JOBS.items():
        fig = cutout(name)
        for rel in outs:
            dst = SPR / rel
            bk = BACKUP / rel
            if dst.exists() and not bk.exists():
                bk.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(dst, bk)
            old = Image.open(bk if bk.exists() else dst).convert("RGBA")
            if rel.startswith("portraits/"):
                img = portrait(fig, head, old.width)
            else:
                bb = old.getchannel("A").getbbox() or (0, 0, old.width, old.height)
                if rel.startswith("units/"):
                    bb = (bb[0], min(bb[1], bb[3] - 200) if name == "doll" else bb[1], bb[2], bb[3])
                img = fit_into(fig, old.size, bb)
            img.save(dst)
            print(f"{name} → {rel} {img.size}")
    for form, card in CARD_SLICES.items():
        bk = BACKUP / "cards" / card.name
        if not bk.exists():
            bk.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(card, bk)
        card_with_portrait(bk, Image.open(SPR / f"portraits/{form}.png").convert("RGBA")).save(card)
        print(f"card {form} → {card.relative_to(GODOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
