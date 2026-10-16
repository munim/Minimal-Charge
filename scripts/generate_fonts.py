#!/usr/bin/env python3
"""Generate pre-baked JetBrains Mono Light (weight 300) 0-9 bitmap fonts (.fnt + .png)
across Garmin Connect IQ resolution buckets (218-240, 260-280, 320-360, 390-416, 454,
plus rectangular 40% buckets) and the launcher icon."""

import math
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

FONT_CANDIDATES = [
    os.path.expanduser("~/Library/Fonts/JetBrainsMonoNerdFont-Light.ttf"),
    "/Library/Fonts/JetBrainsMono-Light.ttf",
    os.path.expanduser("~/Library/Fonts/JetBrainsMono-Light.ttf"),
]

BOLD_FONT_CANDIDATES = [
    os.path.expanduser("~/Library/Fonts/JetBrainsMonoNerdFont-Bold.ttf"),
    "/Library/Fonts/JetBrainsMono-Bold.ttf",
    os.path.expanduser("~/Library/Fonts/JetBrainsMono-Bold.ttf"),
]

BUCKETS = {
    "resources": 154,          # 454px round default (34% of 454 = 154px)
    "resources-218-240": 78,   # 218-240px round (34% of ~230 = 78px)
    "resources-260-280": 92,   # 260-280px round (34% of ~270 = 92px)
    "resources-320-360": 122,  # 320-360px round (34% of 360 = 122px)
    "resources-390-416": 136,  # 390-416px round (34% of ~400 = 136px)
    "resources-454": 154,      # 454px round (34% of 454 = 154px)
    "resources-rect-240": 96,  # 240x240 square (40% of 240 = 96px)
    "resources-rect-320": 128, # 320x360 square (40% of 320 = 128px)
    "resources-rect-448": 179, # 448x486 square (40% of 448 = 179px)
}

DIGITS = "0123456789"


def find_font_path(candidates: list[str] = FONT_CANDIDATES) -> str:
    for path in candidates:
        if os.path.exists(path):
            return path
    raise FileNotFoundError(f"JetBrains Mono TTF not found in candidates: {candidates}")


def next_pow2(n: int) -> int:
    p = 64
    while p < n:
        p *= 2
    return p


def render_outline_glyph(bold_ttf_path: str, target_px: int, ch: str) -> tuple[Image.Image, int, int, tuple[int, int, int, int]]:
    """Render a hollow outline glyph from JetBrains Mono Bold using 4x supersampled morphological erosion."""
    scale = 4
    hi_font = ImageFont.truetype(bold_ttf_path, target_px * scale)
    bbox_1x = ImageFont.truetype(bold_ttf_path, target_px).getbbox(ch)
    gw = max(1, bbox_1x[2] - bbox_1x[0] + 2)
    gh = max(1, bbox_1x[3] - bbox_1x[1] + 2)

    # Outline wall thickness in 1x pixels: ~2.6% of target_px (2px..5px)
    stroke_1x = max(2, int(round(target_px * 0.026)))
    erode_px = stroke_1x * scale
    margin = erode_px + scale * 2

    hi_w = gw * scale + margin * 2
    hi_h = gh * scale + margin * 2
    outer = Image.new("L", (hi_w, hi_h), 0)
    draw = ImageDraw.Draw(outer)
    draw.text(
        (margin + (-bbox_1x[0] + 1) * scale, margin + (-bbox_1x[1] + 1) * scale),
        ch,
        fill=255,
        font=hi_font,
    )

    kernel_size = erode_px * 2 + 1
    inner = outer.filter(ImageFilter.MinFilter(kernel_size))
    hollow_hi = ImageChops.subtract(outer, inner).crop((margin, margin, margin + gw * scale, margin + gh * scale))

    resample = getattr(Image, "Resampling", Image).LANCZOS
    canvas = hollow_hi.resize((gw, gh), resample=resample)
    return canvas, gw, gh, bbox_1x


def save_fnt_and_atlas(
    fonts_dir: str,
    face_name: str,
    fnt_filename: str,
    png_name: str,
    target_px: int,
    line_height: int,
    max_adv: int,
    glyph_images: dict,
) -> None:
    cols = 5
    rows = 2
    cell_w = max(g[1] for g in glyph_images.values()) + 4
    cell_h = max(g[2] for g in glyph_images.values()) + 4
    atlas_w = next_pow2(cols * cell_w + 4)
    atlas_h = next_pow2(rows * cell_h + 4)

    atlas = Image.new("L", (atlas_w, atlas_h), 0)
    char_lines = []

    for idx, ch in enumerate(DIGITS):
        col = idx % cols
        row = idx // cols
        x = 2 + col * cell_w
        y = 2 + row * cell_h
        img, gw, gh, xoff, yoff = glyph_images[ch]
        atlas.paste(img, (x, y))
        char_lines.append(
            f"char id={ord(ch):<4d} x={x:<5d} y={y:<5d} width={gw:<5d} height={gh:<5d} "
            f"xoffset={xoff:<5d} yoffset={yoff:<5d} xadvance={max_adv:<5d} page=0  chnl=15"
        )

    png_path = os.path.join(fonts_dir, png_name)
    atlas.save(png_path, "PNG")

    fnt_lines = [
        f'info face="{face_name}" size=-{target_px} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
        f"common lineHeight={line_height} base={line_height} scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0",
        f'page id=0 file="{png_name}"',
        f"chars count={len(char_lines)}",
        *char_lines,
    ]
    fnt_path = os.path.join(fonts_dir, fnt_filename)
    with open(fnt_path, "w", encoding="utf-8") as f:
        f.write("\n".join(fnt_lines) + "\n")


def build_bucket_font(ttf_path: str, bold_ttf_path: str, folder: str, target_px: int) -> None:
    fonts_dir = os.path.join(folder, "fonts")
    os.makedirs(fonts_dir, exist_ok=True)

    # Line-height is 0.8 of numeral size per spec
    line_height = max(16, int(round(target_px * 0.8)))
    font = ImageFont.truetype(ttf_path, target_px)
    bold_font = ImageFont.truetype(bold_ttf_path, target_px)

    # Measure '0'..'9' bounding boxes to enforce fixed-width tabular cells
    glyph_images = {}
    outline_glyph_images = {}
    max_adv = 0
    min_top = 9999
    max_bottom = -9999

    for ch in DIGITS:
        bbox = font.getbbox(ch)
        adv = int(round(font.getlength(ch)))
        max_adv = max(max_adv, adv)
        min_top = min(min_top, bbox[1])
        max_bottom = max(max_bottom, bbox[3])

    cap_height = max(1, max_bottom - min_top)
    vertical_pad = max(0, (line_height - cap_height) // 2)

    for ch in DIGITS:
        bbox = font.getbbox(ch)
        gw = max(1, bbox[2] - bbox[0] + 2)
        gh = max(1, bbox[3] - bbox[1] + 2)
        canvas = Image.new("L", (gw, gh), 0)
        draw = ImageDraw.Draw(canvas)
        draw.text((-bbox[0] + 1, -bbox[1] + 1), ch, fill=255, font=font)
        xoffset = max(0, (max_adv - gw) // 2)
        yoffset = max(0, vertical_pad + (bbox[1] - min_top) - 1)
        glyph_images[ch] = (canvas, gw, gh, xoffset, yoffset)

        out_canvas, out_gw, out_gh, out_bbox = render_outline_glyph(bold_ttf_path, target_px, ch)
        out_xoffset = max(0, (max_adv - out_gw) // 2)
        out_yoffset = max(0, vertical_pad + (out_bbox[1] - min_top) - 1)
        outline_glyph_images[ch] = (out_canvas, out_gw, out_gh, out_xoffset, out_yoffset)

    save_fnt_and_atlas(
        fonts_dir,
        "JetBrainsMono-Light",
        "time_font.fnt",
        "time_font_0.png",
        target_px,
        line_height,
        max_adv,
        glyph_images,
    )

    save_fnt_and_atlas(
        fonts_dir,
        "JetBrainsMono-BoldOutline",
        "time_outline_font.fnt",
        "time_outline_font_0.png",
        target_px,
        line_height,
        max_adv,
        outline_glyph_images,
    )

    fonts_xml_path = os.path.join(fonts_dir, "fonts.xml")
    with open(fonts_xml_path, "w", encoding="utf-8") as f:
        f.write(
            '<fonts xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">\n'
            '    <font id="TimeFont" filename="time_font.fnt" antialias="true" filter="0123456789" />\n'
            '    <font id="TimeOutlineFont" filename="time_outline_font.fnt" antialias="true" filter="0123456789" />\n'
            "</fonts>\n"
        )


def build_launcher_icon(ttf_path: str) -> None:
    drawables_dir = os.path.join("resources", "drawables")
    os.makedirs(drawables_dir, exist_ok=True)
    img = Image.new("RGBA", (60, 60), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(ttf_path, 22)
    draw.text((14, 6), "11", fill=(245, 247, 250, 255), font=font)
    draw.text((14, 30), "58", fill=(59, 158, 255, 255), font=font)
    img.save(os.path.join(drawables_dir, "launcher_icon.png"), "PNG")
    with open(os.path.join(drawables_dir, "drawables.xml"), "w", encoding="utf-8") as f:
        f.write(
            '<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">\n'
            '    <bitmap id="LauncherIcon" filename="launcher_icon.png" />\n'
            "</drawables>\n"
        )


def main() -> None:
    ttf_path = find_font_path(FONT_CANDIDATES)
    bold_ttf_path = find_font_path(BOLD_FONT_CANDIDATES)
    for folder, size in BUCKETS.items():
        build_bucket_font(ttf_path, bold_ttf_path, folder, size)
    build_launcher_icon(ttf_path)
    print(f"Generated {len(BUCKETS)} bitmap font buckets (Light + Bold Outline) from {ttf_path} and {bold_ttf_path}")


if __name__ == "__main__":
    main()
