#!/usr/bin/env python3
"""Crop and fit high-res silhouettes before running the project's pixel stages."""
from __future__ import annotations

import argparse
from array import array
from collections import deque
import json
from pathlib import Path
import sys

from PIL import Image

BUNDLE = Path(__file__).resolve().parent / "pixel_processing_complete_2026-10-12"
sys.path.insert(0, str(BUNDLE / "src"))
import pixel_ops as ops
import pixel_pipeline
from pixel_stages import safe_names


def fit_highres(image: Image.Image, size: tuple[int, int]) -> tuple[Image.Image, dict]:
    image = image.convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("cannot fit an empty creature")
    cropped = image.crop(bbox)
    scale = min(size[0] / cropped.width, size[1] / cropped.height)
    width = min(size[0], max(1, round(cropped.width * scale)))
    height = min(size[1], max(1, round(cropped.height * scale)))
    fitted = Image.new("RGBA", size, (0, 0, 0, 0))
    fitted.alpha_composite(
        cropped.resize((width, height), Image.Resampling.NEAREST),
        ((size[0] - width) // 2, size[1] - height),
    )
    return fitted, {"source_bbox": list(bbox), "cropped_size": list(cropped.size),
                    "fitted_body_size": [width, height], "scale": scale}


def split_silhouettes(image: Image.Image, rows: int, columns: int, chroma: dict | None) -> tuple[list, list]:
    """Keep connected silhouettes intact when their rectangular bounds overlap."""
    alpha, _ = ops.key_background(image, **chroma) if chroma is not None else (image.convert("RGBA"), None)
    width, height = alpha.size
    pixels = alpha.getchannel("A").tobytes()
    labels = array("i", [0]) * (width * height)
    components = []
    for start, opacity in enumerate(pixels):
        if not opacity or labels[start]:
            continue
        label = len(components) + 1
        labels[start] = label
        queue = deque([start])
        left = right = start % width
        top = bottom = start // width
        count = sum_x = sum_y = 0
        while queue:
            index = queue.popleft()
            x, y = index % width, index // width
            left, right = min(left, x), max(right, x)
            top, bottom = min(top, y), max(bottom, y)
            count += 1
            sum_x += x
            sum_y += y
            for dy in (-1, 0, 1):
                ny = y + dy
                if not 0 <= ny < height:
                    continue
                for dx in (-1, 0, 1):
                    nx = x + dx
                    if not 0 <= nx < width or (dx == 0 and dy == 0):
                        continue
                    neighbor = ny * width + nx
                    if pixels[neighbor] and not labels[neighbor]:
                        labels[neighbor] = label
                        queue.append(neighbor)
        components.append({"label": label, "count": count, "center": (sum_x / count, sum_y / count),
                           "box": (left, top, right + 1, bottom + 1)})
    if len(components) < rows * columns:
        raise ValueError("not enough disconnected silhouettes; review the source sheet")
    mains = sorted(components, key=lambda c: c["count"], reverse=True)[:rows * columns]
    slots = {}
    for component in mains:
        x, y = component["center"]
        slot = min(rows - 1, int(y * rows / height)) * columns + min(columns - 1, int(x * columns / width))
        if slot in slots:
            raise ValueError("two main silhouettes occupy the same cell; review the source sheet")
        slots[slot] = component
    assigned = {c["label"]: slot for slot, c in slots.items()}
    for component in components:
        if component["label"] in assigned:
            continue
        x, y = component["center"]
        slot = min(slots, key=lambda i: (slots[i]["center"][0] - x) ** 2 + (slots[i]["center"][1] - y) ** 2)
        assigned[component["label"]] = slot
    boxes, images = [], []
    for slot in range(rows * columns):
        parts = [c["box"] for c in components if assigned[c["label"]] == slot]
        box = (min(b[0] for b in parts), min(b[1] for b in parts), max(b[2] for b in parts), max(b[3] for b in parts))
        cropped = alpha.crop(box)
        mask = bytes(pixels[y * width + x] if assigned.get(labels[y * width + x]) == slot else 0
                     for y in range(box[1], box[3]) for x in range(box[0], box[2]))
        cropped.putalpha(Image.frombytes("L", cropped.size, mask))
        boxes.append(box)
        images.append(cropped)
    return boxes, images


def run(recipe_path: Path, output: Path, source_override: Path | None = None) -> dict:
    recipe = json.loads(recipe_path.read_text(encoding="utf-8"))
    if not recipe.get("fit_visible_before_pixelization"):
        return pixel_pipeline.run(recipe_path, output, source_override)
    if output.exists() and any(output.iterdir()):
        raise ValueError("output directory must be new or empty")
    source = source_override.resolve() if source_override else (recipe_path.parent / recipe["source"]).resolve()
    if source.is_relative_to(output.resolve()):
        raise ValueError("output must not contain the input source")
    source_hash = ops.file_sha256(source)
    if recipe.get("source_sha256") and recipe["source_sha256"] != source_hash:
        raise ValueError("source SHA-256 differs from the recipe")
    if recipe.get("version") != 1 or recipe.get("kind", "sheet") != "sheet":
        raise ValueError("preparation requires a version 1 sheet recipe")
    size = tuple(recipe["canvas"]["size"])
    if len(size) != 2 or min(size) < 1 or size[0] != size[1]:
        raise ValueError("a positive square canvas is required")
    image = ops.read_png(source)
    layout = recipe.get("layout", {})
    chroma = recipe.get("chroma")
    isolated = None
    if layout.get("split_silhouettes"):
        boxes, isolated = split_silhouettes(image, layout.get("rows", 4), layout.get("columns", 4), chroma)
    elif "row_boundaries" in layout:
        boxes = ops.explicit_sheet_layout(image, layout["row_boundaries"], layout["column_boundaries"])
    else:
        boxes, _ = ops.detect_sheet_layout(image, layout.get("rows", 4), layout.get("columns", 4), chroma,
                                          layout.get("empty_fraction", 0.01), layout.get("minimum_gap", 5))
    sprites = recipe.get("sprites") or [{"name": f"{i + 1:02d}_tile"} for i in range(len(boxes))]
    safe_names([s["name"] for s in sprites], len(boxes))
    columns = recipe.get("preview_columns", 4)
    if columns < 1 or len(boxes) % columns:
        raise ValueError("the preparation sheet must have complete rows")
    prep = output / "preparation"
    prep.mkdir(parents=True)
    source_cell = (size[0] * 8, size[1] * 8)
    fitted_images = []
    report = {"source": str(source), "source_sha256": source_hash,
              "order": ["split_highres", "chroma_key", "crop_alpha_bbox", "fit_highres", "pixelize"],
              "padding": 0, "target_size": list(size), "sprites": []}
    for index, (sprite, box) in enumerate(zip(sprites, boxes)):
        raw = image.crop(box)
        if isolated is not None:
            alpha = isolated[index]
        else:
            alpha, _ = ops.key_background(raw, **chroma) if chroma is not None else (raw.convert("RGBA"), None)
        fitted, info = fit_highres(alpha, source_cell)
        filename = sprite["name"] + ".png"
        ops.true_pixel.save_png_atomic(alpha.crop(tuple(info["source_bbox"])), prep / "cropped" / filename)
        ops.true_pixel.save_png_atomic(fitted, prep / "fitted" / filename)
        fitted_images.append(fitted)
        report["sprites"].append({"name": sprite["name"], "source_box": list(box), **info})
    prepared = prep / "sheet.png"
    ops.true_pixel.save_png_atomic(ops.assemble_preview(fitted_images, columns), prepared)
    ops.save_json(prep / "run.json", report)
    rows = len(boxes) // columns
    runtime = {**recipe, "source": "sheet.png", "source_sha256": ops.file_sha256(prepared),
               "chroma": None, "fit_canvas_candidates": False,
               "reconstruction": {"grid": list(size), "inset": 0.0, "alpha_coverage": 0.0},
               "canvas": {"size": list(size), "baseline": size[1]},
               "layout": {"row_boundaries": [y * source_cell[1] for y in range(rows + 1)],
                          "column_boundaries": [[x * source_cell[0] for x in range(columns + 1)] for _ in range(rows)]},
               "sprites": [{k: v for k, v in sprite.items() if k != "reconstruction"} for sprite in sprites]}
    runtime.pop("reference_dir", None)
    runtime.pop("fit_visible_before_pixelization", None)
    prepared_recipe = prep / "recipe.json"
    ops.save_json(prepared_recipe, runtime)
    return pixel_pipeline.run(prepared_recipe, output / "processed")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recipe", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument("--source", type=Path)
    args = parser.parse_args()
    try:
        run(args.recipe, args.output, args.source)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"Error: {error}\n")


if __name__ == "__main__":
    main()
