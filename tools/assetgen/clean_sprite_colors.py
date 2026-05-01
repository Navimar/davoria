#!/usr/bin/env python3
"""Soft color cleanup for generated lineart sprites.

This is intentionally not palette quantization. It preserves alpha, generated
shadow pixels, and dark lineart, then gently denoises only opaque fill regions.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageFilter


def is_shadow_pixel(r: int, g: int, b: int, a: int) -> bool:
    return a < 180 and max(r, g, b) < 45


def is_line_pixel(r: int, g: int, b: int, a: int, threshold: int) -> bool:
    return a >= 180 and max(r, g, b) <= threshold


def cleanup(
    image: Image.Image,
    line_threshold: int,
    strength: float,
    median_size: int,
) -> Image.Image:
    image = image.convert("RGBA")
    rgb = image.convert("RGB")
    median = rgb.filter(ImageFilter.MedianFilter(size=median_size))

    out = []
    for (r, g, b, a), (mr, mg, mb) in zip(image.getdata(), median.getdata()):
        if a == 0:
            out.append((0, 0, 0, 0))
            continue
        if is_shadow_pixel(r, g, b, a):
            out.append((0, 0, 0, a))
            continue
        if is_line_pixel(r, g, b, a, line_threshold):
            out.append((r, g, b, a))
            continue
        if a < 220:
            # Preserve antialiased sprite edges.
            out.append((r, g, b, a))
            continue

        nr = round(r * (1.0 - strength) + mr * strength)
        ng = round(g * (1.0 - strength) + mg * strength)
        nb = round(b * (1.0 - strength) + mb * strength)
        out.append((nr, ng, nb, a))

    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    result.putdata(out)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--line-threshold", type=int, default=58)
    parser.add_argument("--strength", type=float, default=0.72)
    parser.add_argument("--median-size", type=int, default=3)
    args = parser.parse_args()

    if args.median_size % 2 == 0 or args.median_size < 3:
        raise ValueError("--median-size must be an odd integer >= 3")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    cleaned = cleanup(
        Image.open(args.input),
        line_threshold=args.line_threshold,
        strength=max(0.0, min(1.0, args.strength)),
        median_size=args.median_size,
    )
    cleaned.save(args.output)
    print(args.output)


if __name__ == "__main__":
    main()
