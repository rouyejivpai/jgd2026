#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""10 §1.3 美术管线接入：manifest → 主题 + 布局 + 导入预设。
用法（在 godot/ 目录）：python tools/apply_ui_manifest.py <screen> [<screen> ...]     例：python tools/apply_ui_manifest.py main_menu settings_overlay
读取 assets/ui/<screen>/manifest.json（main_menu 另合并 error_manifest.json 的错误态元素与禁用色）与 preview.json（文字绑定、对齐），生成：
  assets/themes/ui_<screen>.tres     Theme：每个 button / text_style / ninepatch 元素一个类型变体 "<screen>__<id>"
                                     （StyleBoxTexture 九宫格、字体、字号、颜色；下拉按钮另带 PopupMenu 变体）
  data/ui_layout/<screen>.json       每个元素的 kind、rect（设计坐标）、text_rect、对齐、贴图路径（res://）、strings key、主题变体名
  以及引用贴图的 .import 预设：Lossless、无 mipmap（线性过滤由 UiKit 在节点上设置）
UI 脚本只读这两个产物（铁律：布局进 JSON，程序不手改）。再运行一次 Godot --import 让 .import 改动生效。
校验：kind 合法、id 唯一、rect 在设计尺寸内、文件存在且位于 assets/ui 下、按钮四态齐全、九宫格边距不超过贴图尺寸；有错误时不写文件、exit 1。"""
import io
import json
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GODOT = Path(__file__).resolve().parent.parent
UI_ROOT = GODOT / "assets" / "ui"
KINDS = {"image", "ninepatch", "button", "icon", "toggle", "slider", "text_style", "flatbox"}
BUTTON_STATES = ("normal", "hover", "pressed", "disabled")
FONT_FILES = {
    "NotoSerifSC": "res://assets/fonts/NotoSerifSC-Regular.otf",
    "NotoSerifSC-Bold": "res://assets/fonts/NotoSerifSC-Bold.otf",
    "Cinzel": "res://assets/fonts/Cinzel-Regular.ttf",
    "NotoSansSC": "res://assets/fonts/NotoSansSC-Regular.otf",
}
IMPORT_PARAMS = {"compress/mode": "0", "mipmaps/generate": "false"}

errors = []


def err(ctx, msg):
    errors.append(f"[{ctx}] {msg}")


def png_size(path: Path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def res_path(screen_dir: Path, rel: str, ctx: str) -> str:
    p = (screen_dir / rel).resolve()
    try:
        p.relative_to(UI_ROOT.resolve())
    except ValueError:
        err(ctx, f"文件 {rel} 不在 assets/ui 内")
        return ""
    if not p.exists():
        err(ctx, f"文件 {rel} 不存在")
        return ""
    return "res://" + p.relative_to(GODOT.resolve()).as_posix()


def color_tres(hexstr: str) -> str:
    h = hexstr.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    a = int(h[6:8], 16) / 255.0 if len(h) == 8 else 1.0
    return f"Color({r:.6g}, {g:.6g}, {b:.6g}, {a:.6g})"


class TresWriter:
    """最小 .tres 生成器：ext_resource（贴图 / 字体）、StyleBoxTexture 子资源、Theme 属性。"""

    def __init__(self):
        self.ext = {}       # path -> (id, type)
        self.subs = []      # (id, lines)
        self.props = []     # "key = value"

    def ext_id(self, path: str, typ: str) -> str:
        if path not in self.ext:
            self.ext[path] = (f"{len(self.ext) + 1}_{typ.lower()}", typ)
        return self.ext[path][0]

    def stylebox(self, texture: str, ninepatch, content, modulate: str = "", expand=None) -> str:
        sid = f"StyleBoxTexture_{len(self.subs) + 1}"
        lines = [f'texture = ExtResource("{self.ext_id(texture, "Texture2D")}")']
        for side, v in zip(("left", "top", "right", "bottom"), expand or (0, 0, 0, 0)):     # 切图装饰画在框线外：外扩到控件矩形之外
            if v:
                lines.append(f"expand_margin_{side} = {float(v)}")
        if modulate:
            lines.append(f"modulate_color = {color_tres(modulate)}")
        for side, v in zip(("left", "top", "right", "bottom"), ninepatch or (0, 0, 0, 0)):
            if v:
                lines.append(f"texture_margin_{side} = {float(v)}")
        for side, v in zip(("left", "top", "right", "bottom"), content):
            lines.append(f"content_margin_{side} = {float(v)}")
        self.subs.append((sid, lines))
        return f'SubResource("{sid}")'

    def flat_style(self, bg: str, border: str, width: float, radius: float, content=(0, 0, 0, 0)) -> str:
        """P6：资源没有切片的简单底板 / 分隔线 / 平面按钮（颜色、边框、圆角取自批准整图）"""
        sid = f"StyleBoxFlat_{len(self.subs) + 1}"
        lines = [f"bg_color = {color_tres(bg)}"]
        for side, v in zip(("left", "top", "right", "bottom"), content):   # 显式内容边距（否则 StyleBoxFlat 以边框宽作内边距，文字会错位）
            lines.append(f"content_margin_{side} = {float(v)}")
        if border and width:
            lines.append(f"border_color = {color_tres(border)}")
            for side in ("left", "top", "right", "bottom"):
                lines.append(f"border_width_{side} = {int(round(width))}")
        if radius:
            for c in ("top_left", "top_right", "bottom_right", "bottom_left"):
                lines.append(f"corner_radius_{c} = {int(round(radius))}")
            lines.append("anti_aliasing = true")
        self.subs.append((sid, lines))
        return f'SubResource("{sid}")'

    def empty_style(self) -> str:
        sid = f"StyleBoxEmpty_{len(self.subs) + 1}"
        self.subs.append((sid, []))
        return f'SubResource("{sid}")'

    def render(self) -> str:
        out = [f'[gd_resource type="Theme" load_steps={len(self.ext) + len(self.subs) + 1} format=3]', ""]
        for path, (rid, typ) in self.ext.items():
            out.append(f'[ext_resource type="{typ}" path="{path}" id="{rid}"]')
        out.append("")
        for sid, lines in self.subs:
            typ = "StyleBoxEmpty" if sid.startswith("StyleBoxEmpty") else ("StyleBoxFlat" if sid.startswith("StyleBoxFlat") else "StyleBoxTexture")
            out.append(f'[sub_resource type="{typ}" id="{sid}"]')
            out.extend(lines)
            out.append("")
        out.append("[resource]")
        out.extend(self.props)
        out.append("")
        return "\n".join(out)


def content_margins(rect, text_rect):
    """text_rect（元素内部坐标）→ content_margin 左上右下"""
    if not text_rect:
        return (0, 0, 0, 0)
    x, y, w, h = text_rect
    return (x, y, rect[2] - x - w, rect[3] - y - h)


def font_props(tw: TresWriter, var: str, font: dict, ctx: str, extra_colors=()):
    fam = font.get("family")
    if fam not in FONT_FILES:
        err(ctx, f"未知字体 {fam}")
        return
    tw.props.append(f'{var}/fonts/font = ExtResource("{tw.ext_id(FONT_FILES[fam], "FontFile")}")')
    tw.props.append(f"{var}/font_sizes/font_size = {int(font.get('size', 16))}")
    col = color_tres(font.get("color", "#FFFFFF"))
    for name in ("font_color",) + tuple(extra_colors):
        tw.props.append(f"{var}/colors/{name} = {col}")
    if font.get("shadow"):                        # 投影（哥特换皮：浅字压在半透明暗底 / 场景上）："shadow": "#RRGGBBAA"，偏移 shadow_offset [x, y]
        off = font.get("shadow_offset", [2, 2])
        tw.props.append(f"{var}/colors/font_shadow_color = {color_tres(font['shadow'])}")
        tw.props.append(f"{var}/constants/shadow_offset_x = {int(off[0])}")
        tw.props.append(f"{var}/constants/shadow_offset_y = {int(off[1])}")
    if font.get("line_spacing") is not None:      # 行距（多行文字，可为负：结算标题两字一行叠紧）
        tw.props.append(f"{var}/constants/line_spacing = {int(font['line_spacing'])}")
    if font.get("outline_size"):                  # 描边："outline_size" 像素 + "outline_color"
        tw.props.append(f"{var}/constants/outline_size = {int(font['outline_size'])}")
        tw.props.append(f"{var}/colors/font_outline_color = {color_tres(font.get('outline_color', '#000000'))}")


def load_json(path: Path, ctx: str):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:      # noqa: BLE001
        err(ctx, f"无法读取：{e}")
        return None


def merge_overrides(man: dict, ov: dict, screen: str) -> dict:
    """skin_overrides.json：叠在 manifest.json（ui_fit_reference 拟合产物，不手改）之上的换皮层。
    elements[] 每项按 id 匹配：已有元素 → 逐字段覆盖（值为 null 删除该字段）；"_remove": true → 删除该元素；
    新元素 → 追加到末尾，或插在 "_after" / "_before" 指定元素的后 / 前（绘制顺序）。以 "_" 开头的键不进 manifest。
    顶层 "reserved"、"design_size" 若给出则整体替换。"""
    out = dict(man)
    for k in ("reserved", "design_size"):
        if k in ov:
            out[k] = ov[k]
    elements = [dict(e) for e in man.get("elements", [])]
    for o in ov.get("elements", []):
        eid = o.get("id")
        idx = next((i for i, e in enumerate(elements) if e.get("id") == eid), -1)
        if o.get("_remove"):
            if idx < 0:
                err(f"{screen}.{eid}", "skin_overrides 要删除的元素不存在")
            else:
                elements.pop(idx)
            continue
        fields = {k: v for k, v in o.items() if not k.startswith("_")}
        if idx >= 0:
            for k, v in fields.items():
                if v is None:
                    elements[idx].pop(k, None)
                else:
                    elements[idx][k] = v
            continue
        anchor = o.get("_after") or o.get("_before")
        at = next((i for i, e in enumerate(elements) if e.get("id") == anchor), -1) if anchor else -1
        if anchor and at < 0:
            err(f"{screen}.{eid}", f"skin_overrides 的定位元素 {anchor} 不存在")
        if at < 0:
            elements.append(fields)
        else:
            elements.insert(at + 1 if o.get("_after") else at, fields)
    out["elements"] = elements
    return out


def build(screen: str):
    sdir = UI_ROOT / screen
    man = load_json(sdir / "manifest.json", f"{screen}/manifest.json")
    if man is None:
        return None
    preview = load_json(sdir / "preview.json", f"{screen}/preview.json") if (sdir / "preview.json").exists() else {}
    bindings = (preview or {}).get("bindings", {})
    if (sdir / "skin_overrides.json").exists():       # 换皮覆盖层（2026-10-19 哥特新切图），见 merge_overrides
        ov = load_json(sdir / "skin_overrides.json", f"{screen}/skin_overrides.json")
        if ov is None:
            return None
        man = merge_overrides(man, ov, screen)
    design = man.get("design_size", [1920, 1080])
    elements = list(man.get("elements", []))
    error_colors = {}
    if (sdir / "error_manifest.json").exists():       # 错误态：只补充主 manifest 没有的元素，并取按钮禁用色
        eman = load_json(sdir / "error_manifest.json", f"{screen}/error_manifest.json") or {}
        ids = {e.get("id") for e in elements}
        for e in eman.get("elements", []):
            if e.get("id") not in ids:
                e = dict(e)
                e["error_only"] = True
                elements.append(e)
            elif e.get("kind") == "button" and e.get("font"):
                error_colors[e["id"]] = e["font"].get("color")
        for k, v in (preview or {}).get("error_bindings", {}).items():
            bindings.setdefault(k, v)
    # 下拉 dropdown_<name> 与其显示值 <name>_value（text_style）配对：OptionButton 自绘文字，值元素的字体与位置并入下拉按钮
    by_id = {e.get("id"): e for e in elements}
    for e in elements:
        eid = e.get("id", "")
        if e.get("kind") == "button" and eid.startswith("dropdown_"):
            val = by_id.get(eid[len("dropdown_"):] + "_value")
            if val and val.get("kind") == "text_style" and "text_rect" not in e:
                r, vr = e["rect"], val["rect"]
                e["text_rect"] = [vr[0] - r[0], vr[1] - r[1], vr[2], vr[3]]
                e["font"] = val.get("font", {})
                val["merged_into"] = eid
    tw = TresWriter()
    layout = {"schema_version": 1, "screen": screen, "design_size": design, "elements": []}
    if "reserved" in man:                         # P6：界面为其他内容让出的区域（如局内 HUD 给战场让出的上下带），原样透传
        layout["reserved"] = man["reserved"]
    seen = set()
    textures = set()
    for e in elements:
        eid = e.get("id", "")
        ctx = f"{screen}.{eid}"
        kind = e.get("kind")
        if kind not in KINDS:
            err(ctx, f"kind 非法：{kind}")
            continue
        if eid in seen:
            err(ctx, "id 重复")
        seen.add(eid)
        rect = e.get("rect")
        if not (isinstance(rect, list) and len(rect) == 4 and rect[2] >= 0 and rect[3] >= 0):
            err(ctx, "rect 必须是 [x, y, w, h]")
            continue
        if rect[0] < 0 or rect[1] < 0 or rect[0] + rect[2] > design[0] or rect[1] + rect[3] > design[1]:
            err(ctx, f"rect {rect} 超出设计尺寸 {design}")
        var = f"{screen}__{eid}"
        b = bindings.get(eid, {})
        item = {"id": eid, "kind": kind, "rect": rect}
        if e.get("error_only"):
            item["error_only"] = True
        if e.get("merged_into"):
            item["merged_into"] = e["merged_into"]
        if "text_rect" in e:
            item["text_rect"] = e["text_rect"]
            item["align"] = e.get("align", b.get("align", "left"))
        if b.get("key") or e.get("key"):
            item["key"] = e.get("key", b.get("key"))
        for k in ("overflow", "data"):            # P6：文字溢出处理（UiKit 遮罩 + 滚动）、界面自定义数据，原样透传
            if k in e:
                item[k] = e[k]
        np_ = e.get("ninepatch")
        if np_ is not None:
            item["ninepatch"] = np_
        if e.get("expand"):                       # 外扩边距（StyleBoxTexture.expand_margin），原样记入布局
            item["expand"] = e["expand"]
        if kind in ("image", "icon", "ninepatch"):
            path = res_path(sdir, e.get("file", ""), ctx)
            item["file"] = path
            textures.add(path)
            if kind == "ninepatch" and path:
                size = png_size(GODOT / path[len("res://"):])
                if size and np_ and (np_[0] + np_[2] > size[0] or np_[1] + np_[3] > size[1]):
                    err(ctx, f"九宫格边距 {np_} 超出贴图 {size}")
                item["theme_type"] = var
                tw.props.append(f'{var}/base_type = &"PanelContainer"')
                tw.props.append(f"{var}/styles/panel = {tw.stylebox(path, np_, (0, 0, 0, 0), '', e.get('expand'))}")
        elif kind == "flatbox":
            st = e.get("style", {})
            item["theme_type"] = var
            tw.props.append(f'{var}/base_type = &"PanelContainer"')
            tw.props.append(f"{var}/styles/panel = {tw.flat_style(st.get('bg', '#000000'), st.get('border', ''), st.get('border_width', 0), st.get('radius', 0))}")
        elif kind == "toggle":
            states = e.get("states", {})
            if set(states) != {"on", "off"}:
                err(ctx, "toggle 需要 on / off 两态")
            item["states"] = {k: res_path(sdir, v, ctx) for k, v in states.items()}
            textures.update(item["states"].values())
        elif kind == "button" and "flat_states" in e:
            # 资源没有切片的平面按钮（整图里的描边按钮）：四态 StyleBoxFlat，颜色由 ui_fit_reference 从整图取样并派生
            item["theme_type"] = var
            content = content_margins(rect, e.get("text_rect"))
            tw.props.append(f'{var}/base_type = &"Button"')
            fs = e["flat_states"]
            for st in BUTTON_STATES + ("hover_pressed",):
                f = fs.get(st if st != "hover_pressed" else "pressed")
                tw.props.append(f"{var}/styles/{st} = {tw.flat_style(f['bg'], f.get('border', ''), f.get('border_width', 0), f.get('radius', 0), content)}")
            tw.props.append(f"{var}/styles/focus = {tw.empty_style()}")
            if e.get("font"):
                font_props(tw, var, e["font"], ctx, ("font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"))
                tw.props.append(f"{var}/colors/font_disabled_color = {color_tres(e['font'].get('disabled_color') or e['font'].get('color'))}")
        elif kind == "button":
            states = e.get("states", {})
            missing = [s for s in BUTTON_STATES if s not in states]
            if missing:
                err(ctx, f"按钮缺少状态 {missing}")
            # 状态可为文件名，或 {"file", "modulate"}（资源只交一态时，其余状态用同一张贴图调色：StyleBoxTexture.modulate_color）
            tints = {k: v.get("modulate", "") for k, v in states.items() if isinstance(v, dict)}
            item["states"] = {k: res_path(sdir, v["file"] if isinstance(v, dict) else v, ctx) for k, v in states.items()}
            textures.update(item["states"].values())
            item["theme_type"] = var
            content = content_margins(rect, e.get("text_rect"))
            tw.props.append(f'{var}/base_type = &"{"OptionButton" if eid.startswith("dropdown_") else "Button"}"')
            for st in BUTTON_STATES:
                if item["states"].get(st):
                    tw.props.append(f"{var}/styles/{st} = {tw.stylebox(item['states'][st], np_, content, tints.get(st, ''), e.get('expand'))}")
            if item["states"].get("pressed"):
                tw.props.append(f"{var}/styles/hover_pressed = {tw.stylebox(item['states']['pressed'], np_, content, tints.get('pressed', ''), e.get('expand'))}")
            tw.props.append(f"{var}/styles/focus = {tw.empty_style()}")     # 焦点复用 hover 贴图（UiKit.skin_button），不叠加
            if e.get("font"):
                font_props(tw, var, e["font"], ctx, ("font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"))
                dis = error_colors.get(eid) or e["font"].get("disabled_color") or e["font"].get("color")
                tw.props.append(f"{var}/colors/font_disabled_color = {color_tres(dis)}")
        elif kind == "text_style":
            item["theme_type"] = var
            tw.props.append(f'{var}/base_type = &"Label"')
            if e.get("font"):
                font_props(tw, var, e["font"], ctx)
        layout["elements"].append(item)
    # 下拉：按钮四态之外，弹出列表用 normal / hover 贴图（UI_INVENTORY §4：弹出选项由程序用公共下拉四态生成）
    for item in layout["elements"]:
        if item["kind"] == "button" and item["id"].startswith("dropdown_"):
            var = f"{screen}__{item['id']}__popup"
            item["popup_theme_type"] = var
            tw.props.append(f'{var}/base_type = &"PopupMenu"')
            tw.props.append(f"{var}/styles/panel = {tw.stylebox(item['states']['normal'], item.get('ninepatch'), (8, 8, 8, 8))}")
            tw.props.append(f"{var}/styles/hover = {tw.stylebox(item['states']['hover'], item.get('ninepatch'), (8, 4, 8, 4))}")
    for t in sorted(textures):
        if t:
            size = png_size(GODOT / t[len("res://"):])
            if size is None and not t.endswith(".svg"):
                err(t, "不是有效 PNG")
    return tw, layout, textures


def apply_import(textures):
    changed = 0
    for t in textures:
        if not t:
            continue
        imp = GODOT / (t[len("res://"):] + ".import")
        if not imp.exists():
            continue         # 首次接入：先跑一次 Godot --import 生成 .import，再运行本工具
        text = imp.read_text(encoding="utf-8")
        new = text
        for k, v in IMPORT_PARAMS.items():
            new = re.sub(r"^" + re.escape(k) + r"=.*$", f"{k}={v}", new, flags=re.MULTILINE)
        if new != text:
            imp.write_text(new, encoding="utf-8", newline="\n")
            changed += 1
    return changed


def main(argv):
    screens = argv[1:]
    if not screens:
        print(__doc__)
        return 2
    results = []
    for s in screens:
        r = build(s)
        if r:
            results.append((s, r))
    if errors:
        print(f"manifest 校验失败，共 {len(errors)} 条：")
        for e in errors:
            print("  " + e)
        return 1
    for s, (tw, layout, textures) in results:
        (GODOT / "assets" / "themes" / f"ui_{s}.tres").write_text(tw.render(), encoding="utf-8", newline="\n")
        out = GODOT / "data" / "ui_layout" / f"{s}.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        layout["_comment"] = f"由 tools/apply_ui_manifest.py 从 assets/ui/{s}/manifest.json 生成，程序不手改（10 §1.3）。rect 为设计坐标，经 UiKit.layout_rect 换算。"
        out.write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        n = apply_import(textures)
        print(f"{s}：{len(layout['elements'])} 个元素 → assets/themes/ui_{s}.tres、data/ui_layout/{s}.json；导入预设改动 {n} 个")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
