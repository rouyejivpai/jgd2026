"""Extract a .docx to markdown text + image files, in true document order.

Inline base64 image data is replaced by relative markdown image links, so the
extracted text stays small enough to read and diff.

Usage:
    python extract_docx.py <input.docx> <output-dir>

Writes into <output-dir>: 策划案.md (text), media/ (images), manifest.json
(per-image part name, pixel size, SHA1, and body/image mapping).

Note: this project's v0.0.1 is a nested git repository, and spawned processes
are not writable inside it under the current sandbox, so point <output-dir> at
a location outside the repo (e.g. D:\\jgd2026\\_refs).
"""
import hashlib
import json
import os
import re
import sys
from io import BytesIO

from docx import Document
from docx.oxml.ns import qn
from docx.table import Table
from docx.text.paragraph import Paragraph

sys.stdout.reconfigure(encoding="utf-8")

# namespaces python-docx does not pre-register
A_BLIP = "{http://schemas.openxmlformats.org/drawingml/2006/main}blip"
V_IMAGEDATA = "{urn:schemas-microsoft-com:vml}imagedata"
R_EMBED = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed"
R_ID = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"

DOCX = sys.argv[1]
OUTDIR = sys.argv[2]

MEDIA = os.path.join(OUTDIR, "media")
os.makedirs(MEDIA, exist_ok=True)

doc = Document(DOCX)

rel_map = {}
for rid, rel in doc.part.rels.items():
    if "image" in rel.reltype:
        rel_map[rid] = rel.target_part

part_info = {}
seen_hash = {}
order = []


def register(part, label):
    """Register one image part, deduplicating identical blobs by SHA1."""
    key = str(part.partname)
    if key in part_info:
        return part_info[key]
    blob = part.blob
    sha1 = hashlib.sha1(blob).hexdigest()
    if sha1 in seen_hash:
        info = seen_hash[sha1]
        info["aliases"].append(label)
        part_info[key] = info
        return info
    w = h = None
    try:
        from PIL import Image
        with Image.open(BytesIO(blob)) as im:
            w, h = im.size
    except Exception as exc:  # noqa: BLE001
        print(f"  ! dimensions unavailable for {key}: {exc}")
    ext = os.path.splitext(key)[1].lower() or ".png"
    fname = f"img{len(seen_hash) + 1:03d}{ext}"
    with open(os.path.join(MEDIA, fname), "wb") as fh:
        fh.write(blob)
    info = {
        "index": len(seen_hash) + 1,
        "file": fname,
        "part": key,
        "w": w,
        "h": h,
        "bytes": len(blob),
        "sha1": sha1,
        "aliases": [label],
    }
    seen_hash[sha1] = info
    part_info[key] = info
    order.append(info)
    return info


def render_paragraph(par, ctx):
    """Render paragraph text, replacing inline images with markdown links."""
    out = []
    for child in par._p.iter():
        tag = child.tag
        if tag == qn("w:t"):
            out.append(child.text or "")
        elif tag == qn("w:tab"):
            out.append("\t")
        elif tag == qn("w:br"):
            out.append("\n")
        elif tag in (A_BLIP, V_IMAGEDATA):
            rid = child.get(R_EMBED) or child.get(R_ID)
            if not rid or rid not in rel_map:
                continue
            info = register(rel_map[rid], ctx)
            out.append(f"\n\n![{info['file']}](media/{info['file']})\n\n")
    return "".join(out)


def iter_blocks(parent):
    """Yield paragraphs and tables in true document order."""
    for child in parent.element.body.iterchildren():
        if child.tag == qn("w:p"):
            yield Paragraph(child, parent)
        elif child.tag == qn("w:tbl"):
            yield Table(child, parent)


def table_to_md(tbl):
    rows = []
    for row in tbl.rows:
        cells = []
        for c in row.cells:
            txt = " ".join(p.text.strip() for p in c.paragraphs).strip()
            cells.append(txt.replace("|", "\\|"))
        rows.append(cells)
    if not rows:
        return ""
    width = max(len(r) for r in rows)
    rows = [r + [""] * (width - len(r)) for r in rows]
    md = ["| " + " | ".join(rows[0]) + " |", "| " + " | ".join(["---"] * width) + " |"]
    for r in rows[1:]:
        md.append("| " + " | ".join(r) + " |")
    return "\n".join(md)


lines = []
sec = 0
headings = []
for block in iter_blocks(doc):
    if isinstance(block, Table):
        lines.extend(["", table_to_md(block), ""])
        continue
    par = block
    txt = render_paragraph(par, f"p{sec}").replace("\u00a0", " ")
    stripped = txt.strip()
    if not stripped:
        continue
    style = par.style.name if par.style is not None else ""
    level = None
    if style.lower().startswith("heading"):
        try:
            level = int(style.split()[-1])
        except Exception:  # noqa: BLE001
            level = 1
    elif re.match(r"^\d+(\.\d+)*[\.、]?\s*\S", stripped) and len(stripped) < 60:
        # numbered heading that Word did not style as Heading
        level = stripped.split()[0].rstrip(".、").count(".") + 2
    elif style in ("Title", "标题"):
        level = 1
    if level is not None:
        headings.append({"level": level, "text": stripped.splitlines()[0][:80], "block": sec})
        lines.extend(["", "#" * min(level, 6) + " " + stripped])
    else:
        lines.extend(["", stripped])
    sec += 1

body = "\n".join(lines).strip() + "\n"
with open(os.path.join(OUTDIR, "策划案.md"), "w", encoding="utf-8") as fh:
    fh.write(body)

with open(os.path.join(OUTDIR, "manifest.json"), "w", encoding="utf-8") as fh:
    json.dump(
        {
            "source": DOCX,
            "blocks": sec,
            "text_chars": len(body),
            "image_count": len(order),
            "total_image_bytes": sum(i["bytes"] for i in order),
            "headings": headings,
            "images": order,
        },
        fh,
        ensure_ascii=False,
        indent=2,
    )

print(f"blocks         : {sec}")
print(f"images written : {len(order)}")
print(f"total img bytes: {sum(i['bytes'] for i in order):,}")
print(f"markdown chars : {len(body):,}")
print(f"out            : {OUTDIR}")
