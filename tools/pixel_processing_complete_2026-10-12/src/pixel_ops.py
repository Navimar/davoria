"""Shared operations for reproducible pseudo-pixel processing (Pillow only)."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
from statistics import mean, pstdev

from PIL import Image

import remove_chroma_key as chroma
import true_pixel

OUTLINE = (36, 34, 52)


def save_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def file_sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest() if hasattr(hashlib, "file_digest") else hashlib.sha256(stream.read()).hexdigest()


def read_png(path: Path) -> Image.Image:
    return true_pixel.load_image(path)


def key_background(image: Image.Image, *, auto_key: str = "border", key_color: str = "ff00ff", tolerance: int = 64) -> tuple[Image.Image, dict]:
    if auto_key not in {"border", "corners", "none"}:
        raise ValueError("auto_key must be border, corners or none")
    if not 0 <= tolerance <= 255:
        raise ValueError("chroma tolerance must be in 0..255")
    result = image.convert("RGBA")
    key = chroma._parse_key_color(key_color) if auto_key == "none" else chroma._sample_border_key(result, auto_key)
    chroma._apply_alpha_to_image(result, key=key, tolerance=tolerance, spill_cleanup=False,
                                soft_matte=False, transparent_threshold=32, opaque_threshold=128)
    return result, {"key": list(key), "tolerance": tolerance, "auto_key": auto_key}


def _gap_runs(values: list[int], threshold: float, minimum: int) -> list[tuple[int, int]]:
    runs = []
    start = None
    for i, value in enumerate(values + [math.inf]):
        if value <= threshold and start is None:
            start = i
        elif value > threshold and start is not None:
            if i - start >= minimum:
                runs.append((start, i))
            start = None
    return runs


def _gap_boundaries(values: list[int], divisions: int, cross_length: int, empty_fraction: float, minimum_gap: int) -> list[int]:
    length = len(values)
    if not 1 <= divisions <= length:
        raise ValueError("invalid number of sheet rows/columns")
    runs = _gap_runs(values, cross_length * empty_fraction, minimum_gap)
    boundaries = [0]
    for index in range(1, divisions):
        target = index * length / divisions
        radius = length / divisions * 0.4
        candidates = [(a, b) for a, b in runs if a > boundaries[-1] and b < length and abs((a+b)/2-target) <= radius]
        if not candidates:
            raise ValueError(f"no empty gap near division {index}/{divisions}; provide explicit row/column boundaries")
        a, b = min(candidates, key=lambda run: abs(sum(run)/2-target))
        boundaries.append((a+b-1)//2)
    boundaries.append(length)
    return boundaries


def detect_sheet_layout(image: Image.Image, rows: int = 4, columns: int = 4,
                        chroma_options: dict | None = None, empty_fraction: float = 0.01,
                        minimum_gap: int = 5) -> tuple[list[tuple[int, int, int, int]], dict]:
    if not 0 <= empty_fraction <= 1 or minimum_gap < 1:
        raise ValueError("invalid gap detection options")
    mask, key_meta = key_background(image, **(chroma_options or {}))
    alpha = mask.getchannel("A"); px = alpha.load(); w, h = mask.size
    ys = _gap_boundaries([sum(px[x,y]>0 for x in range(w)) for y in range(h)], rows, w, empty_fraction, minimum_gap)
    xs = []
    boxes = []
    for top, bottom in zip(ys, ys[1:]):
        boundaries = _gap_boundaries([sum(px[x,y]>0 for y in range(top,bottom)) for x in range(w)], columns, bottom-top, empty_fraction, minimum_gap)
        xs.append(boundaries)
        boxes.extend((left, top, right, bottom) for left, right in zip(boundaries, boundaries[1:]))
    return boxes, {"rows": rows, "columns": columns, "row_boundaries": ys, "column_boundaries": xs,
                   "detection_key": key_meta, "empty_fraction": empty_fraction, "minimum_gap": minimum_gap}


def explicit_sheet_layout(image: Image.Image, row_boundaries: list[int], column_boundaries: list[list[int]]) -> list[tuple[int,int,int,int]]:
    if row_boundaries[0] != 0 or row_boundaries[-1] != image.height:
        raise ValueError("row boundaries must cover the complete input image")
    if any(a >= b for a,b in zip(row_boundaries, row_boundaries[1:])):
        raise ValueError("row boundaries must be strictly increasing")
    if len(column_boundaries) != len(row_boundaries)-1:
        raise ValueError("one set of column boundaries is required for every row")
    boxes = []
    count = None
    for top, bottom, xs in zip(row_boundaries, row_boundaries[1:], column_boundaries):
        if not xs or xs[0] != 0 or xs[-1] != image.width or any(a>=b for a,b in zip(xs,xs[1:])):
            raise ValueError("column boundaries must increase and cover the complete input image")
        if count is None: count = len(xs)
        if len(xs) != count: raise ValueError("every row must contain the same number of columns")
        boxes.extend((a,top,b,bottom) for a,b in zip(xs,xs[1:]))
    return boxes


def reconstruct(image: Image.Image, options: dict) -> tuple[Image.Image, dict]:
    from dataclasses import asdict
    inset = options.get("inset", 0.18); coverage = options.get("alpha_coverage", 0.5)
    if not 0 <= inset < 0.5 or not 0 <= coverage <= 1:
        raise ValueError("invalid inset or alpha_coverage")
    grid = options.get("grid")
    if isinstance(grid, list):
        w,h = grid
        if not 1 <= w <= image.width or not 1 <= h <= image.height:
            raise ValueError("logical grid must not enlarge the input")
        result = true_pixel.reconstruct_pixels(image,w,h,inset,alpha_coverage=coverage)
        return result, {"mode":"edge_aligned", "width":w, "height":h, "inset":inset,"alpha_coverage":coverage}
    if isinstance(grid, dict):
        sx,sy = grid["cell_size_x"],grid["cell_size_y"]
        ox,oy = grid.get("offset_x",0),grid.get("offset_y",0)
        xs = true_pixel.phased_cell_ranges(image.width,sx,ox); ys = true_pixel.phased_cell_ranges(image.height,sy,oy)
        result = true_pixel.reconstruct_pixels(image,len(xs),len(ys),inset,cell_size_x=sx,cell_size_y=sy,offset_x=ox,offset_y=oy,alpha_coverage=coverage)
        return result, {"mode":"explicit_phase", **grid,"width":result.width,"height":result.height,"inset":inset,"alpha_coverage":coverage}
    selected,candidates = true_pixel.estimate_grid(image,options.get("min_cell",4.5),options.get("max_cell",5.5))
    maximum_bbox=options.get("max_bbox")
    tried=0
    for candidate in candidates if maximum_bbox else [selected]:
        if maximum_bbox and candidate.score < selected.score*0.75:
            raise ValueError("no strong grid candidate fits the canvas; review the cell-size range")
        result = true_pixel.reconstruct_pixels(image,candidate.width,candidate.height,inset,
                 cell_size_x=candidate.cell_size_x,cell_size_y=candidate.cell_size_y,offset_x=candidate.offset_x,offset_y=candidate.offset_y,alpha_coverage=coverage)
        tried+=1
        bbox=result.convert("RGBA").getchannel("A").getbbox()
        if not maximum_bbox or (bbox and bbox[2]-bbox[0]<=maximum_bbox[0] and bbox[3]-bbox[1]<=maximum_bbox[1]):
            selected=candidate
            break
    else:
        raise ValueError("no grid candidate fits the canvas")
    return result, {"mode":"detected_phase",**asdict(selected),"inset":inset,"alpha_coverage":coverage,
                    "fit_candidates_tried":tried,"candidates":[asdict(c) for c in candidates[:8]]}


def map_palette(image: Image.Image, mode: str = "aap64", colors: int = 64) -> Image.Image:
    if mode == "aap64": return true_pixel.map_to_reference_palette(image,true_pixel.AAP64_PALETTE)
    if mode == "image": return true_pixel.reduce_image_palette(image,colors)
    if mode == "none": return image.copy()
    raise ValueError("palette must be aap64, image or none")


def inner_outline(image: Image.Image, color: tuple[int,int,int] = OUTLINE, neighbors: int = 8) -> Image.Image:
    if tuple(color) not in true_pixel.AAP64_PALETTE:
        raise ValueError("outline color must belong to AAP64")
    if neighbors not in {4,8}: raise ValueError("outline neighbors must be 4 or 8")
    source = image.convert("RGBA"); result = source.copy(); src=source.load(); dst=result.load(); w,h=source.size
    offsets = [(dx,dy) for dy in (-1,0,1) for dx in (-1,0,1) if (dx or dy) and (neighbors==8 or abs(dx)+abs(dy)==1)]
    for y in range(h):
        for x in range(w):
            if not src[x,y][3]: continue
            if any(not (0<=x+dx<w and 0<=y+dy<h) or src[x+dx,y+dy][3]==0 for dx,dy in offsets):
                dst[x,y] = (*color,src[x,y][3])
    return result


def mirror(image: Image.Image, horizontal: bool = True) -> Image.Image:
    return image.transpose(Image.Transpose.FLIP_LEFT_RIGHT if horizontal else Image.Transpose.FLIP_TOP_BOTTOM)


def align_canvas(image: Image.Image, size: tuple[int,int] = (66,66), baseline: int = 63) -> Image.Image:
    w,h = size
    if w<1 or h<1 or not 1<=baseline<=h: raise ValueError("invalid canvas size or baseline")
    source = image.convert("RGBA"); bbox=source.getchannel("A").getbbox()
    if bbox is None: raise ValueError("cannot align an empty sprite")
    sprite=source.crop(bbox)
    if sprite.width>w or sprite.height>baseline:
        raise ValueError(f"sprite {sprite.size} does not fit canvas {size} with baseline {baseline}; no clipping/resizing performed")
    result=Image.new("RGBA",size,(0,0,0,0))
    result.alpha_composite(sprite,((w-sprite.width)//2,baseline-sprite.height))
    return result


def crop_portrait(image: Image.Image, size: tuple[int,int] = (96,96), *, x: int | None = None, y: int | None = None,
                  shift_x: int = 0, shift_y: int = 0) -> tuple[Image.Image, list[int]]:
    w,h=size
    left=(image.width-w)//2 if x is None else x
    top=(image.height-h)//2 if y is None else y
    left+=shift_x; top+=shift_y
    box=[left,top,left+w,top+h]
    if min(w,h)<=0 or left<0 or top<0 or box[2]>image.width or box[3]>image.height:
        raise ValueError(f"portrait crop {box} lies outside {image.size}; no padding/resizing performed")
    return image.crop(box),box


def assemble_preview(images: list[Image.Image], columns: int = 4, gap: int = 0) -> Image.Image:
    if not images or columns<1 or gap<0: raise ValueError("invalid contact sheet inputs")
    w,h=images[0].size
    if any(im.size!=(w,h) for im in images): raise ValueError("preview tiles must have identical sizes")
    rows=math.ceil(len(images)/columns)
    result=Image.new("RGBA",(columns*w+(columns-1)*gap,rows*h+(rows-1)*gap),(0,0,0,0))
    for i,im in enumerate(images): result.alpha_composite(im.convert("RGBA"),((i%columns)*(w+gap),(i//columns)*(h+gap)))
    return result


def checker_preview(image: Image.Image, square: int = 8) -> Image.Image:
    result=Image.new("RGBA",image.size,(235,235,235,255)); px=result.load()
    for y in range(image.height):
        for x in range(image.width):
            if (x//square+y//square)%2: px[x,y]=(200,200,200,255)
    result.alpha_composite(image.convert("RGBA"))
    return result


def compare_previews(images: list[Image.Image], gap: int = 24) -> Image.Image:
    if not images or gap<0: raise ValueError("invalid comparison inputs")
    result=Image.new("RGBA",(sum(im.width for im in images)+gap*(len(images)-1),max(im.height for im in images)),(0,0,0,0))
    x=0
    for im in images:
        result.alpha_composite(im.convert("RGBA"),(x,0)); x+=im.width+gap
    return result


def validate_images(images: list[Image.Image], *, expected_count: int | None = None, size: tuple[int,int] | None = None,
                    baseline: int | None = None, palette: bool = True, binary_alpha: bool = True) -> dict:
    errors=[]; details=[]; union=set(); lumas=[]; widths=[]; heights=[]; populations=[]
    if not images: errors.append("no images")
    if expected_count is not None and len(images)!=expected_count: errors.append(f"count {len(images)} != {expected_count}")
    for index,image in enumerate(images):
        rgba=image.convert("RGBA"); data=list(rgba.get_flattened_data()); alpha={p[3] for p in data}; colors={p[:3] for p in data if p[3]}
        bbox=rgba.getchannel("A").getbbox(); visible=[p for p in data if p[3]]
        problems=[]
        if size is not None and image.size!=size: problems.append(f"size {image.size} != {size}")
        if binary_alpha and not alpha<={0,255}: problems.append("non-binary alpha")
        if not bbox: problems.append("empty sprite")
        if baseline is not None and bbox and bbox[3]!=baseline: problems.append(f"baseline {bbox[3]} != {baseline}")
        if palette and not colors<=set(true_pixel.AAP64_PALETTE): problems.append("colors outside AAP64")
        errors.extend(f"image {index+1}: {problem}" for problem in problems)
        details.append({"size":list(image.size),"bbox":list(bbox) if bbox else None,"alpha":sorted(alpha),"colors":len(colors),"errors":problems})
        if bbox: widths.append(bbox[2]-bbox[0]); heights.append(bbox[3]-bbox[1])
        populations.append(len(visible)); union.update(colors)
        lumas.extend((0.2126*r+0.7152*g+0.0722*b)/255 for r,g,b,a in visible)
    def stats(values): return {"mean":mean(values) if values else 0,"sd":pstdev(values) if values else 0}
    return {"ok":not errors,"errors":errors,"count":len(images),"images":details,"palette_used":[list(c) for c in sorted(union)],
            "metrics":{"bbox_width":stats(widths),"bbox_height":stats(heights),"opaque_pixels":stats(populations),
                       "luma_mean":mean(lumas) if lumas else 0,"dark_fraction":mean(y<0.25 for y in lumas) if lumas else 0}}


def compare_reference(actual: Image.Image, reference: Image.Image) -> dict:
    first=actual.convert("RGBA"); second=reference.convert("RGBA")
    if first.size!=second.size: return {"exact":False,"size_match":False,"actual_size":list(first.size),"reference_size":list(second.size)}
    different=0; alpha_different=0
    for a,b in zip(first.get_flattened_data(),second.get_flattened_data()):
        alpha_different+=a[3]!=b[3]
        different+=a[3]!=b[3] or (a[3]>0 and a[:3]!=b[:3])
    return {"exact":different==0,"rgba_pixels_exact":first.tobytes()==second.tobytes(),"size_match":True,"different_visible_or_alpha_pixels":different,"different_alpha_pixels":alpha_different}


def consistency_metrics(first: list[Image.Image], second: list[Image.Image]) -> dict:
    a=validate_images(first,palette=False,binary_alpha=False)
    b=validate_images(second,palette=False,binary_alpha=False)
    ac={tuple(c) for c in a["palette_used"]};bc={tuple(c) for c in b["palette_used"]}
    common=ac&bc;union=ac|bc
    return {"first":a,"second":b,"palette_overlap":{"shared":len(common),"union":len(union),"jaccard":len(common)/len(union) if union else 0},
            "luma_mean_delta":b["metrics"]["luma_mean"]-a["metrics"]["luma_mean"],
            "dark_fraction_delta":b["metrics"]["dark_fraction"]-a["metrics"]["dark_fraction"]}
