#!/usr/bin/env python3
"""Package pixel-processing source, recipes, documentation and all saved assets."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import zipfile

import pixel_ops as ops

SOURCES=("true_pixel.py","remove_chroma_key.py","pixel_ops.py","pixel_stages.py","pixel_pipeline.py",
         "split_sheet.py","outline.py","mirror.py","align_canvas.py","crop_portrait.py","map_palette.py",
         "assemble_preview.py","compare_sets.py","validate_assets.py","verify_examples.py","build_pixel_bundle.py")
SINGLES={"goblin_pseudo_pixel.png","goblin_true_pixel_aap64.png","kraken_pseudo_pixel.png","kraken_true_pixel.png",
         "kraken_true_pixel_aap64.png","kraken_true_pixel_aap64_96.png","wolf_pseudo_pixel.png",
         "wolf_true_pixel_aap64.png","wolf_true_pixel_aap64_96.png","wolf_portrait_aap64_96.png","wolf_portrait_aap64_96_v2.png"}


def build(project: Path, destination: Path, generated: Path | None = None) -> dict:
    project=project.resolve();destination=destination.resolve();archive=destination.with_suffix(".zip")
    if destination.exists() or archive.exists(): raise ValueError("bundle directory and ZIP must not already exist")
    if not (project/"pixel_docs/README.md").is_file(): raise ValueError("project root must contain the full pixel pipeline and pixel_docs")
    destination.mkdir(parents=True)
    for name in SOURCES:
        (destination/"src").mkdir(exist_ok=True);shutil.copy2(project/name,destination/"src"/name)
    (destination/"tests").mkdir()
    for name in ("test_true_pixel.py","test_pixel_pipeline.py"): shutil.copy2(project/name,destination/"tests"/name)
    shutil.copytree(project/"pixel_docs",destination/"docs")
    shutil.copy2(project/"pixel_docs/README.md",destination/"README.md")
    shutil.copy2(project/"pixel_docs/requirements.txt",destination/"requirements.txt")
    (destination/"palettes").mkdir()
    shutil.copy2(project/"pixel_palettes/aap64.hex",destination/"palettes/aap64.hex")
    (destination/"assets").mkdir()
    assets=[]
    for path in sorted(project.rglob("*.png")):
        relative=path.relative_to(project)
        if len(relative.parts)==1 and (path.name in SINGLES or path.name.startswith(("monsters_","beetle_"))):
            target=destination/"assets"/relative
        elif len(relative.parts)==2 and relative.parts[0].startswith("monster_tiles"):
            target=destination/"assets"/relative
        else: continue
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target);assets.append(str(relative))
    provenance=[]
    if generated:
        for path in sorted(generated.glob("*.png")):
            target=destination/"assets/original_generated"/path.name
            target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
            provenance.append({"name":path.name,"sha256":ops.file_sha256(path)})
    (destination/"recipes").mkdir()
    for recipe in sorted((project/"pixel_recipes").glob("*.json")):
        value=json.loads(recipe.read_text(encoding="utf-8"))
        for field in ("source","reference_dir"):
            if field in value:
                old=value[field];value[field]="../assets" if old==".." else "../assets/"+old.removeprefix("../")
        ops.save_json(destination/"recipes"/recipe.name,value)
    (destination/"reports").mkdir()
    if (project/"pixel_runs_2026-10-12/reproducibility.json").is_file():
        shutil.copy2(project/"pixel_runs_2026-10-12/reproducibility.json",destination/"reports/reproducibility.json")
    if (project/"pixel_runs_2026-10-12/consistency.json").is_file():
        shutil.copy2(project/"pixel_runs_2026-10-12/consistency.json",destination/"reports/consistency.json")
        shutil.copy2(project/"pixel_runs_2026-10-12/comparison.png",destination/"reports/comparison.png")
    for name in ("sheet03","sheet04","wolf_portrait96"):
        run=project/"pixel_runs_2026-10-12"/name
        if run.is_dir(): shutil.copytree(run,destination/"examples"/name)
    manifest={"bundle":"complete pixel processing pipeline","source_files":list(SOURCES),"saved_pixel_assets":assets,
              "original_generated":provenance,"recipes":sorted(p.name for p in (destination/"recipes").glob("*.json")),
              "historical_archive":"2026-07-30 ZIP is preserved separately; this ZIP supersedes it"}
    ops.save_json(destination/"MANIFEST.json",manifest)
    files=sorted(p for p in destination.rglob("*") if p.is_file())
    sums="".join(f"{ops.file_sha256(path)}  {path.relative_to(destination).as_posix()}\n" for path in files)
    (destination/"SHA256SUMS").write_text(sums,encoding="utf-8")
    with zipfile.ZipFile(archive,"x",compression=zipfile.ZIP_DEFLATED,compresslevel=9) as handle:
        for path in sorted(destination.rglob("*")):
            if path.is_file() and "__pycache__" not in path.parts: handle.write(path,Path(destination.name)/path.relative_to(destination))
    with zipfile.ZipFile(archive) as handle:
        bad=handle.testzip()
        if bad: raise ValueError(f"ZIP integrity failure: {bad}")
    return {"folder":str(destination),"archive":str(archive),"files":len(files)+1,"assets":len(assets),
            "original_generations":len(provenance),"bytes":archive.stat().st_size,"sha256":ops.file_sha256(archive)}


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project",type=Path,default=Path(__file__).resolve().parent)
    parser.add_argument("-o","--output",type=Path,required=True)
    parser.add_argument("--generated",type=Path,help="optional original ImageGen files for provenance")
    args=parser.parse_args()
    try: result=build(args.project,args.output,args.generated)
    except (OSError,ValueError) as error: parser.exit(1,f"Error: {error}\n")
    print(json.dumps(result,ensure_ascii=False,indent=2))


if __name__=="__main__": main()
