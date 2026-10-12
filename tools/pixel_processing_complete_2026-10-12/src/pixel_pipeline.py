#!/usr/bin/env python3
"""Run the complete pipeline from a portable JSON recipe."""
from __future__ import annotations

import argparse
import json
import platform
from pathlib import Path

from PIL import __version__ as pillow_version

import pixel_ops as ops
from pixel_stages import safe_names
import true_pixel

STAGES=("01_highres","02_alpha","03_pixels","04_palette","05_outline","06_oriented","final")


def run(recipe_path: Path, output: Path, source_override: Path | None = None) -> dict:
    config=json.loads(recipe_path.read_text(encoding="utf-8"))
    if config.get("version")!=1: raise ValueError("recipe version must be 1")
    source=source_override.resolve() if source_override else (recipe_path.parent/config["source"]).resolve()
    output=output.resolve()
    if source.is_relative_to(output): raise ValueError("output must not contain the input source")
    if output.exists() and any(output.iterdir()): raise ValueError("output directory must be new or empty")
    source_hash=ops.file_sha256(source)
    if config.get("source_sha256") and source_hash!=config["source_sha256"]:
        raise ValueError("source SHA-256 differs from the recipe; use a generic recipe for another source")
    image=ops.read_png(source)
    kind=config.get("kind","sheet")
    if kind not in {"sheet","single"}: raise ValueError("kind must be sheet or single")
    key_options=config.get("chroma")
    layout_meta=None
    if kind=="sheet":
        layout=config.get("layout",{})
        if "row_boundaries" in layout:
            boxes=ops.explicit_sheet_layout(image,layout["row_boundaries"],layout["column_boundaries"]); layout_meta=layout
        else:
            boxes,layout_meta=ops.detect_sheet_layout(image,layout.get("rows",4),layout.get("columns",4),key_options,
                          layout.get("empty_fraction",0.01),layout.get("minimum_gap",5))
        sprites=config.get("sprites") or [{"name":f"{i+1:02d}_tile"} for i in range(len(boxes))]
    else:
        boxes=[(0,0,image.width,image.height)]; sprites=config.get("sprites",[{"name":"image"}])
    names=safe_names([sprite["name"] for sprite in sprites],len(boxes))
    for stage in STAGES: (output/stage).mkdir(parents=True,exist_ok=True)
    ops.save_json(output/"recipe.json",config)
    report={"status":"running","recipe":config,"source":str(source),"source_sha256":source_hash,
            "runtime":{"python":platform.python_version(),"pillow":pillow_version},"layout":layout_meta,"sprites":[]}
    final_images=[]
    reference_root=(recipe_path.parent/config["reference_dir"]).resolve() if config.get("reference_dir") else None
    try:
        for index,(sprite,box) in enumerate(zip(sprites,boxes)):
            name=sprite["name"]; filename=f"{name}.png"
            raw=image.crop(box)
            true_pixel.save_png_atomic(raw,output/"01_highres"/filename)
            alpha,key_meta=ops.key_background(raw,**key_options) if key_options is not None else (raw.copy(),None)
            true_pixel.save_png_atomic(alpha,output/"02_alpha"/filename)
            settings={**config.get("reconstruction",{}),**sprite.get("reconstruction",{})}
            if config.get("fit_canvas_candidates") and config.get("canvas") and not settings.get("grid"):
                canvas_options=config["canvas"]
                settings["max_bbox"]=[canvas_options.get("size",[66,66])[0],canvas_options.get("baseline",63)]
            if settings.pop("skip",False): pixels,grid=alpha.copy(),{"mode":"already_pixel"}
            else: pixels,grid=ops.reconstruct(alpha,settings)
            true_pixel.save_png_atomic(pixels,output/"03_pixels"/filename)
            palette=config.get("palette","aap64")
            mapped=ops.map_palette(pixels,palette,config.get("colors",64))
            true_pixel.save_png_atomic(mapped,output/"04_palette"/filename)
            outline_options=config.get("outline")
            outlined=ops.inner_outline(mapped,tuple(bytes.fromhex(outline_options.get("color","242234").lstrip("#"))),outline_options.get("neighbors",8)) if outline_options else mapped.copy()
            if outline_options and mapped.convert("RGBA").getchannel("A").tobytes()!=outlined.getchannel("A").tobytes():
                raise ValueError("outline changed alpha")
            true_pixel.save_png_atomic(outlined,output/"05_outline"/filename)
            oriented=ops.mirror(outlined) if sprite.get("flip_horizontal",False) else outlined.copy()
            true_pixel.save_png_atomic(oriented,output/"06_oriented"/filename)
            canvas=config.get("canvas")
            final=ops.align_canvas(oriented,tuple(canvas.get("size",[66,66])),canvas.get("baseline",63)) if canvas else oriented.copy()
            crop=config.get("crop"); crop_box=None
            if crop:
                final,crop_box=ops.crop_portrait(final,tuple(crop.get("size",[96,96])),x=crop.get("x"),y=crop.get("y"),shift_x=crop.get("shift_x",0),shift_y=crop.get("shift_y",0))
            true_pixel.save_png_atomic(final,output/"final"/filename); final_images.append(final)
            entry={"name":name,"source_box":list(box),"chroma":key_meta,"grid":grid,"flip_horizontal":sprite.get("flip_horizontal",False),"crop_box":crop_box}
            if reference_root:
                reference=reference_root/sprite.get("reference",filename)
                entry["reference"]=ops.compare_reference(final,ops.read_png(reference)) if reference.exists() else {"exact":False,"missing":str(reference)}
            report["sprites"].append(entry)
            print(f"[{index+1}/{len(sprites)}] {name}: {pixels.size} -> {final.size}",flush=True)
        canvas=config.get("canvas"); crop=config.get("crop")
        expected_size=tuple(crop.get("size",[96,96])) if crop else tuple(canvas.get("size",[66,66])) if canvas else None
        qa=ops.validate_images(final_images,expected_count=len(sprites),size=expected_size,
                             baseline=canvas.get("baseline",63) if canvas and not crop else None,palette=config.get("palette","aap64")=="aap64")
        qa["names"]=names
        if reference_root:
            mismatches=[s["name"] for s in report["sprites"] if not s["reference"]["exact"]]
            qa["reference_exact_count"]=len(sprites)-len(mismatches)
            qa["reference_mismatches"]=mismatches
            if mismatches: qa["errors"].append(f"reference mismatches: {mismatches}"); qa["ok"]=False
        ops.save_json(output/"qa.json",qa)
        if len({im.size for im in final_images})==1:
            preview=ops.assemble_preview(final_images,config.get("preview_columns",4 if kind=="sheet" else 1))
            true_pixel.save_png_atomic(preview,output/"preview.png")
            true_pixel.save_png_atomic(ops.checker_preview(preview),output/"preview_checker.png")
        report["status"]="complete" if qa["ok"] else "failed_qa"
        ops.save_json(output/"run.json",report)
        if not qa["ok"]: raise ValueError(f"QA failed; inspect {output/'qa.json'}")
        return report
    except (OSError,ValueError,KeyError,TypeError) as error:
        report["status"]="failed"; report["error"]=str(error)
        ops.save_json(output/"run.json",report)
        raise


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recipe",type=Path)
    parser.add_argument("-o","--output",type=Path,required=True,help="new or empty output folder")
    parser.add_argument("--source",type=Path,help="override input path for a generic recipe")
    args=parser.parse_args()
    try: run(args.recipe,args.output,args.source)
    except (OSError,ValueError,KeyError,TypeError) as error: parser.exit(1,f"Error: {error}\n")
    print(f"Complete. Stages, final PNGs and QA: {args.output.resolve()}")


if __name__=="__main__": main()
