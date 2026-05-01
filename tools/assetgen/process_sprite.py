#!/usr/bin/env python3
"""Palette-process a transparent sprite with a fixed Pillow palette.

This intentionally does not discover a palette from the image. It maps opaque
sprite pixels into a project palette with no dithering, while preserving
transparent pixels and generated semi-transparent black shadows.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageFilter


def parse_hex(value: str) -> tuple[int, int, int]:
    value = value.strip()
    if value.startswith("#"):
        value = value[1:]
    if len(value) != 6:
        raise ValueError(f"Expected #rrggbb color, got {value!r}")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def load_palette(path: Path) -> tuple[str, tuple[int, int, int], list[tuple[int, int, int]]]:
    data = json.loads(path.read_text())
    name = data.get("name", path.stem)
    outline = parse_hex(data["outline"])
    colors = [parse_hex(color) for color in data["colors"]]
    if outline not in colors:
        colors.insert(0, outline)
    if not colors or len(colors) > 256:
        raise ValueError(f"Palette must contain 1..256 colors: {path}")
    return name, outline, colors


def make_pillow_palette(colors: list[tuple[int, int, int]]) -> Image.Image:
    pal = Image.new("P", (1, 1))
    flat: list[int] = []
    for rgb in colors:
        flat.extend(rgb)
    flat.extend([0, 0, 0] * (256 - len(colors)))
    pal.putpalette(flat)
    return pal


def is_shadow_pixel(r: int, g: int, b: int, a: int) -> bool:
    return a < 180 and max(r, g, b) < 45


def force_outline_pass(
    image: Image.Image,
    outline: tuple[int, int, int],
    threshold: int,
) -> Image.Image:
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pixels = []
    for r, g, b, a in image.getdata():
        if a == 0:
            pixels.append((0, 0, 0, 0))
            continue
        if is_shadow_pixel(r, g, b, a):
            pixels.append((0, 0, 0, a))
            continue
        if max(r, g, b) <= threshold:
            pixels.append((*outline, a))
        else:
            pixels.append((r, g, b, a))
    out.putdata(pixels)
    return out


def quantize_fixed_palette(
    image: Image.Image,
    palette_image: Image.Image,
    outline: tuple[int, int, int],
    outline_threshold: int,
) -> Image.Image:
    prepared = force_outline_pass(image, outline, outline_threshold)
    alpha = prepared.getchannel("A")

    # Preserve shadow separately. Quantizing shadow would turn it into opaque
    # palette colors and break the recovered alpha from chroma-key extraction.
    shadow_mask = Image.new("L", prepared.size, 0)
    shadow_data = []
    rgb_data = []
    for r, g, b, a in prepared.getdata():
        shadow = is_shadow_pixel(r, g, b, a)
        shadow_data.append(255 if shadow else 0)
        rgb_data.append((0, 0, 0) if shadow or a == 0 else (r, g, b))
    shadow_mask.putdata(shadow_data)

    rgb = Image.new("RGB", prepared.size)
    rgb.putdata(rgb_data)
    quantized = rgb.quantize(palette=palette_image, dither=Image.Dither.NONE).convert("RGBA")
    quantized.putalpha(alpha)

    # Restore transparent pixels and shadow pixels, then force darks again.
    restored = []
    for (qr, qg, qb, qa), (or_, og, ob, oa), sm in zip(
        quantized.getdata(), prepared.getdata(), shadow_mask.getdata()
    ):
        if oa == 0:
            restored.append((0, 0, 0, 0))
        elif sm:
            restored.append((0, 0, 0, oa))
        elif max(qr, qg, qb) <= outline_threshold:
            restored.append((*outline, oa))
        else:
            restored.append((qr, qg, qb, oa))
    out = Image.new("RGBA", prepared.size, (0, 0, 0, 0))
    out.putdata(restored)
    return out


def remove_tiny_islands(image: Image.Image, size: int) -> Image.Image:
    if size <= 1:
        return image
    alpha = image.getchannel("A")
    filtered = image.filter(ImageFilter.ModeFilter(size=size)).convert("RGBA")
    # Keep alpha and transparent/shadow pixels from the original. The mode
    # filter is only a mild cleanup for color islands in opaque body regions.
    data = []
    for orig, filt, a in zip(image.getdata(), filtered.getdata(), alpha.getdata()):
        r, g, b, oa = orig
        if oa == 0:
            data.append((0, 0, 0, 0))
        elif is_shadow_pixel(r, g, b, oa):
            data.append(orig)
        elif oa < 220:
            data.append(orig)
        else:
            data.append((filt[0], filt[1], filt[2], oa))
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out.putdata(data)
    return out


def validate_colors(
    image: Image.Image,
    colors: set[tuple[int, int, int]],
    outline: tuple[int, int, int],
) -> tuple[int, int]:
    off_palette = 0
    body_pixels = 0
    for r, g, b, a in image.getdata():
        if a == 0 or is_shadow_pixel(r, g, b, a):
            continue
        body_pixels += 1
        if (r, g, b) not in colors and (r, g, b) != outline:
            off_palette += 1
    return body_pixels, off_palette


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--palette", required=True, type=Path)
    parser.add_argument("--outline-threshold", type=int, default=48)
    parser.add_argument("--mode-filter-size", type=int, default=0)
    args = parser.parse_args()

    name, outline, colors = load_palette(args.palette)
    source = Image.open(args.input).convert("RGBA")
    palette_image = make_pillow_palette(colors)
    processed = quantize_fixed_palette(source, palette_image, outline, args.outline_threshold)
    processed = remove_tiny_islands(processed, args.mode_filter_size)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    processed.save(args.output)

    body_pixels, off_palette = validate_colors(processed, set(colors), outline)
    print(f"palette={name}")
    print(f"input={args.input}")
    print(f"output={args.output}")
    print(f"body_pixels={body_pixels}")
    print(f"off_palette_pixels={off_palette}")


if __name__ == "__main__":
    main()
