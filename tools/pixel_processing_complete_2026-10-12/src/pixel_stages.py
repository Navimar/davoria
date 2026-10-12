"""Command-line entry points for each individual processing stage."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import pixel_ops as ops
import true_pixel


def size_argument(value: str) -> tuple[int,int]:
    return true_pixel.parse_grid(value)


def safe_names(names: list[str], count: int) -> list[str]:
    if len(names)!=count or len(set(names))!=count:
        raise ValueError("one unique name is required for every tile")
    if any(not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*",name) for name in names):
        raise ValueError("tile names may contain ASCII letters, digits, underscores and hyphens")
    return names


def main(stage: str) -> None:
    parser=argparse.ArgumentParser(description=f"Pixel pipeline stage: {stage}")
    parser.add_argument("input",type=Path,help="PNG file, or folder of PNGs")
    parser.add_argument("-o","--output",type=Path,required=stage!="validate")
    parser.add_argument("--force",action="store_true",help="overwrite generated files")
    if stage=="split":
        parser.add_argument("--rows",type=int,default=4); parser.add_argument("--columns",type=int,default=4)
        parser.add_argument("--layout",type=Path,help="recipe JSON containing layout and sprite names")
        parser.add_argument("--names",nargs="+")
        parser.add_argument("--tolerance",type=int,default=64)
        parser.add_argument("--empty-fraction",type=float,default=0.01)
        parser.add_argument("--minimum-gap",type=int,default=5)
    elif stage=="outline":
        parser.add_argument("--color",default="242234"); parser.add_argument("--neighbors",type=int,choices=[4,8],default=8)
    elif stage=="mirror":
        parser.add_argument("--names",nargs="+",help="only mirror these stems; default: all")
        parser.add_argument("--vertical",action="store_true")
    elif stage=="align":
        parser.add_argument("--size",type=size_argument,default=(66,66)); parser.add_argument("--baseline",type=int,default=63)
    elif stage=="crop":
        parser.add_argument("--size",type=size_argument,default=(96,96))
        parser.add_argument("--x",type=int); parser.add_argument("--y",type=int)
        parser.add_argument("--shift-x",type=int,default=0); parser.add_argument("--shift-y",type=int,default=0)
    elif stage=="palette":
        parser.add_argument("--palette",choices=["aap64","image","none"],default="aap64")
        parser.add_argument("--colors",type=int,default=64)
    elif stage=="preview":
        parser.add_argument("--columns",type=int,default=4); parser.add_argument("--gap",type=int,default=0)
        parser.add_argument("--checker",action="store_true")
    elif stage=="compare":
        parser.add_argument("--other",type=Path,nargs="+",required=True); parser.add_argument("--gap",type=int,default=24)
        parser.add_argument("--columns",type=int,default=4);parser.add_argument("--report",type=Path)
    elif stage=="validate":
        parser.add_argument("--size",type=size_argument); parser.add_argument("--baseline",type=int)
        parser.add_argument("--count",type=int); parser.add_argument("--no-palette-check",action="store_true")
        parser.add_argument("--reference",type=Path)
    args=parser.parse_args()
    try:
        files=sorted(args.input.glob("*.png")) if args.input.is_dir() else [args.input]
        if not files: raise ValueError("input contains no PNGs")
        images=[ops.read_png(p) for p in files]
        def save(image,path):
            if path.resolve() in {p.resolve() for p in files}: raise ValueError("output must not overwrite input")
            if path.exists() and not args.force: raise ValueError(f"output exists: {path}; use --force")
            true_pixel.save_png_atomic(image,path)
        if stage=="validate":
            report=ops.validate_images(images,expected_count=args.count,size=args.size,baseline=args.baseline,palette=not args.no_palette_check)
            if args.reference:
                report["reference"]={}
                for p,im in zip(files,images):
                    reference=args.reference/p.name if args.reference.is_dir() else args.reference
                    if not reference.exists(): item={"exact":False,"missing":str(reference)}
                    else: item=ops.compare_reference(im,ops.read_png(reference))
                    report["reference"][p.name]=item
                    if not item["exact"]: report["errors"].append(f"reference mismatch: {p.name}")
                report["ok"]=not report["errors"]
            if args.output:
                if args.output.resolve() in {p.resolve() for p in files}: raise ValueError("report must not overwrite input PNG")
                ops.save_json(args.output,report)
            print(json.dumps(report,ensure_ascii=False,indent=2))
            if not report["ok"]: parser.exit(1)
            return
        if stage=="split":
            if len(images)!=1: raise ValueError("split requires one source sheet")
            config=json.loads(args.layout.read_text(encoding="utf-8")) if args.layout else {}
            layout=config.get("layout",config)
            if "row_boundaries" in layout:
                boxes=ops.explicit_sheet_layout(images[0],layout["row_boundaries"],layout["column_boundaries"]); meta=layout
            else:
                boxes,meta=ops.detect_sheet_layout(images[0],args.rows,args.columns,{"tolerance":args.tolerance},args.empty_fraction,args.minimum_gap)
            names=args.names or [s["name"] for s in config.get("sprites",[])] or [f"{i+1:02d}_tile" for i in range(len(boxes))]
            safe_names(names,len(boxes))
            for name,box in zip(names,boxes): save(images[0].crop(box),args.output/f"{name}.png")
            ops.save_json(args.output/"crops.json",{"layout":meta,"tiles":[{"name":name,"box":list(box)} for name,box in zip(names,boxes)]})
        elif stage in {"preview","compare"}:
            if stage=="preview": result=ops.assemble_preview(images,args.columns,args.gap)
            else:
                previews=[ops.assemble_preview(images,args.columns) if args.input.is_dir() else images[0]]
                metrics=[]
                for other in args.other:
                    other_files=sorted(other.glob("*.png")) if other.is_dir() else [other]
                    other_images=[ops.read_png(p) for p in other_files]
                    previews.append(ops.assemble_preview(other_images,args.columns) if other.is_dir() else other_images[0])
                    metrics.append({"other":str(other),**ops.consistency_metrics(images,other_images)})
                result=ops.compare_previews(previews,args.gap)
                if args.report: ops.save_json(args.report,{"first":str(args.input),"comparisons":metrics})
            if stage=="preview" and args.checker: result=ops.checker_preview(result)
            save(result,args.output)
        else:
            if stage=="mirror" and args.names:
                unknown=set(args.names)-{p.stem for p in files}
                if unknown: raise ValueError(f"unknown mirror names: {sorted(unknown)}")
            for p,image in zip(files,images):
                if stage=="outline": result=ops.inner_outline(image,tuple(bytes.fromhex(args.color.lstrip("#"))),args.neighbors)
                elif stage=="mirror": result=ops.mirror(image,not args.vertical) if not args.names or p.stem in args.names else image.copy()
                elif stage=="align": result=ops.align_canvas(image,args.size,args.baseline)
                elif stage=="crop": result,_=ops.crop_portrait(image,args.size,x=args.x,y=args.y,shift_x=args.shift_x,shift_y=args.shift_y)
                elif stage=="palette": result=ops.map_palette(image,args.palette,args.colors)
                else: raise ValueError(f"unknown stage {stage}")
                save(result,args.output/p.name if args.input.is_dir() else args.output)
        print(f"{stage}: complete -> {args.output}")
    except (ValueError,OSError,KeyError,TypeError) as error:
        parser.exit(1,f"Error: {error}\n")
