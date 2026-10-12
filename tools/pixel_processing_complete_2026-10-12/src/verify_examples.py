#!/usr/bin/env python3
"""Reproduce all canonical examples and compare their pixels to references."""
from __future__ import annotations

import argparse
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile

import pixel_ops as ops
import pixel_pipeline

RECIPES=("sheet03","sheet04","sheet03_replay","sheet04_replay","goblin96","kraken120","kraken96","wolf162","wolf_portrait96")


def verify_stages(recipe_path: Path, output: Path, scripts: Path) -> dict:
    """Exercise the actual individual CLIs, including argument/path handling."""
    config=json.loads(recipe_path.read_text(encoding="utf-8"))
    source=(recipe_path.parent/config["source"]).resolve()
    reference=(recipe_path.parent/config["reference_dir"]).resolve()
    def command(script,*arguments):
        result=subprocess.run([sys.executable,str(scripts/script),*[str(a) for a in arguments]],capture_output=True,text=True)
        if result.returncode: raise ValueError(f"{script} failed: {result.stderr or result.stdout}")
    command("split_sheet.py",source,"-o",output/"raw","--layout",recipe_path)
    for sprite in config["sprites"]:
        filename=sprite["name"]+".png"
        command("remove_chroma_key.py","--input",output/"raw"/filename,"--out",output/"alpha"/filename,"--auto-key","border","--tolerance",64)
        settings={**config["reconstruction"],**sprite.get("reconstruction",{})}
        command("true_pixel.py",output/"alpha"/filename,"-o",output/"pixels"/filename,"--palette","none",
                "--min-cell",settings["min_cell"],"--max-cell",settings["max_cell"],"--alpha-coverage",0.5)
    command("map_palette.py",output/"pixels","-o",output/"palette")
    command("outline.py",output/"palette","-o",output/"outline")
    flips=[s["name"] for s in config["sprites"] if s.get("flip_horizontal")]
    command("mirror.py",output/"outline","-o",output/"oriented","--names",*flips)
    command("align_canvas.py",output/"oriented","-o",output/"final","--size","66x66","--baseline",63)
    command("assemble_preview.py",output/"final","-o",output/"preview.png","--columns",4)
    command("validate_assets.py",output/"final","--reference",reference,"--size","66x66","--baseline",63,"--count",16,"-o",output/"qa.json")
    command("compare_sets.py",output/"final","--other",reference,"-o",output/"comparison.png","--report",output/"consistency.json")
    wolf=json.loads((recipe_path.parent/"wolf162.json").read_text(encoding="utf-8"))
    wolf_pixels=(recipe_path.parent/wolf["reference_dir"]/wolf["sprites"][0]["reference"]).resolve()
    portrait=json.loads((recipe_path.parent/"wolf_portrait96.json").read_text(encoding="utf-8"))
    portrait_reference=(recipe_path.parent/portrait["reference_dir"]/portrait["sprites"][0]["reference"]).resolve()
    command("crop_portrait.py",wolf_pixels,"-o",output/"wolf96.png","--size","96x96","--x",58,"--y",34,"--shift-y",8)
    command("validate_assets.py",output/"wolf96.png","--reference",portrait_reference,"--size","96x96","--count",1)
    qa=json.loads((output/"qa.json").read_text(encoding="utf-8"))
    return {"ok":qa["ok"],"exact_images":sum(r["exact"] for r in qa["reference"].values()),
            "scripts":11,"portrait_exact":ops.compare_reference(ops.read_png(output/"wolf96.png"),ops.read_png(portrait_reference))["exact"],
            "preview_reference_exact":ops.compare_reference(ops.read_png(output/"preview.png"),ops.assemble_preview([ops.read_png(p) for p in sorted(reference.glob("*.png"))]))["exact"]}


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--recipes",type=Path)
    parser.add_argument("--report",type=Path)
    args=parser.parse_args()
    project=Path(__file__).resolve().parent
    if project.name=="src": project=project.parent
    folder=args.recipes or project/("recipes" if (project/"recipes").exists() else "pixel_recipes")
    report={"ok":True,"recipes":[],"exact_images":0}
    with tempfile.TemporaryDirectory(prefix="pixel_reproduction_") as name:
        for recipe in RECIPES:
            try:
                with redirect_stdout(io.StringIO()): result=pixel_pipeline.run(folder/f"{recipe}.json",Path(name)/recipe)
                exact=sum(s.get("reference",{}).get("exact",False) for s in result["sprites"])
                report["recipes"].append({"name":recipe,"ok":True,"count":len(result["sprites"]),"reference_exact_count":exact})
                report["exact_images"]+=exact
                print(f"{recipe}: {exact}/{len(result['sprites'])} exact")
            except (OSError,ValueError,KeyError,TypeError) as error:
                report["ok"]=False; report["recipes"].append({"name":recipe,"ok":False,"error":str(error)})
                print(f"{recipe}: FAILED: {error}")
        try:
            report["standalone_stages"]=verify_stages(folder/"sheet04.json",Path(name)/"standalone",Path(__file__).resolve().parent)
            report["ok"] &= report["standalone_stages"]["ok"] and report["standalone_stages"]["preview_reference_exact"] and report["standalone_stages"]["portrait_exact"]
            print("Standalone stages: 16/16 exact, preview exact, portrait exact")
        except (OSError,ValueError,KeyError,TypeError) as error:
            report["ok"]=False; report["standalone_stages"]={"ok":False,"error":str(error)}
    if args.report: ops.save_json(args.report,report)
    print(json.dumps(report,ensure_ascii=False,indent=2))
    if not report["ok"]: parser.exit(1)


if __name__=="__main__": main()
