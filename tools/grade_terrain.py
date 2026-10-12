#!/usr/bin/env python3
"""Apply the terrain standard once, after the shared AAP64 pixel pipeline."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys

from PIL import ImageFilter

BUNDLE = Path(__file__).resolve().parent / "pixel_processing_complete_2026-10-12"
sys.path.insert(0, str(BUNDLE / "src"))
import pixel_ops as ops
import true_pixel

STANDARD = Path(__file__).resolve().parent / "pixel_recipes" / "terrain_style.json"


def run(source: Path, output: Path, standard: Path = STANDARD) -> dict:
    config = json.loads(standard.read_text(encoding="utf-8"))
    if config.get("version") != 1 or config.get("palette") != "aap64":
        raise ValueError("terrain requires a version 1 AAP64 standard")
    gain = float(config["rgb_gain"])
    if not math.isfinite(gain) or not 0 < gain <= 1:
        raise ValueError("rgb_gain must be greater than zero and at most one")
    blur_radius = float(config.get("blur_radius_px", 0.0))
    if not math.isfinite(blur_radius) or blur_radius < 0:
        raise ValueError("blur_radius_px must be finite and non-negative")
    size = tuple(config["size"])
    source, output = source.resolve(), output.resolve()
    if source == output or source.is_relative_to(output):
        raise ValueError("output must not contain or overwrite source assets")
    if output.exists() and any(output.iterdir()):
        raise ValueError("output must be new or empty")
    files = sorted(source.glob("*.png"))
    if not files:
        raise ValueError("source must contain undarkened AAP64 terrain PNGs")
    palette = set(true_pixel.AAP64_PALETTE)
    lut = [round(value * gain) for value in range(256)]
    images = []
    for path in files:
        image = ops.read_png(path).convert("RGBA")
        if image.size != size or image.getchannel("A").getextrema() != (255, 255):
            raise ValueError(f"expected a full opaque {size} terrain tile: {path.name}")
        if not {p[:3] for p in image.get_flattened_data()} <= palette:
            raise ValueError(f"use the original AAP64 result before darkening: {path.name}")
        images.append((path, image))
    output.mkdir(parents=True, exist_ok=True)
    order = ["pixelize", "aap64", "darken_rgb"]
    if blur_radius > 0:
        order.append("gaussian_blur_rgb")
    report = {"standard": config, "source": str(source), "output": str(output),
              "order": order,
              "rounding": "nearest_ties_even", "palette_remap_after_darkening": False,
              "geometry_changed": False, "alpha_changed": False, "tiles": []}
    for path, image in images:
        rgb = image.convert("RGB").point(lut * 3)
        if blur_radius > 0:
            rgb = rgb.filter(ImageFilter.GaussianBlur(blur_radius))
        graded = rgb.convert("RGBA")
        graded.putalpha(image.getchannel("A"))
        target = output / path.name
        true_pixel.save_png_atomic(graded, target)
        report["tiles"].append({"name": path.name, "size": list(graded.size),
                                "source_sha256": ops.file_sha256(path),
                                "output_sha256": ops.file_sha256(target)})
    ops.save_json(output / "run.json", report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="undarkened AAP64 PNG directory")
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument("--standard", type=Path, default=STANDARD)
    args = parser.parse_args()
    try:
        report = run(args.source, args.output, args.standard)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"Error: {error}\n")
    print(f"Graded {len(report['tiles'])} terrain tiles with RGB × {report['standard']['rgb_gain']}, blur {report['standard'].get('blur_radius_px', 0.0)}px: {args.output.resolve()}")


if __name__ == "__main__":
    main()
