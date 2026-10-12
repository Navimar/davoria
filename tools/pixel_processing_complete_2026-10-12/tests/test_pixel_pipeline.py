from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

import pixel_ops as ops
import pixel_pipeline


class PixelOperationsTests(unittest.TestCase):
    def test_outline_preserves_alpha_and_only_recolors_inner_edge(self):
        image=Image.new("RGBA",(7,7),(0,0,0,0))
        for y in range(1,6):
            for x in range(1,6): image.putpixel((x,y),(255,213,65,255))
        image.putpixel((3,3),(0,0,0,0))
        result=ops.inner_outline(image)
        self.assertEqual(image.getchannel("A").tobytes(),result.getchannel("A").tobytes())
        self.assertEqual(result.getpixel((1,1))[:3],ops.OUTLINE)
        self.assertEqual(result.getpixel((3,2))[:3],ops.OUTLINE)
        self.assertEqual(result.getpixel((0,0))[3],0)
        with self.assertRaises(ValueError): ops.inner_outline(image,(17,17,17))

    def test_mirror_and_align_preserve_every_visible_pixel(self):
        image=Image.new("RGBA",(8,9),(0,0,0,0))
        image.putpixel((1,2),(255,213,65,255)); image.putpixel((4,5),(6,6,8,255))
        self.assertEqual(ops.mirror(ops.mirror(image)).tobytes(),image.tobytes())
        result=ops.align_canvas(ops.mirror(image),(10,10),8)
        self.assertEqual(result.getchannel("A").getbbox(),(3,4,7,8))
        self.assertEqual(sum(p[3]>0 for p in result.get_flattened_data()),2)
        self.assertEqual(result.getpixel((3,7)),(6,6,8,255))
        with self.assertRaises(ValueError): ops.align_canvas(image,(2,2),2)

    def test_crop_moves_camera_down_without_scaling(self):
        image=Image.new("RGB",(12,12))
        for y in range(12):
            for x in range(12): image.putpixel((x,y),(x,y,0))
        cropped,box=ops.crop_portrait(image,(6,6),x=2,y=3,shift_y=2)
        self.assertEqual(box,[2,5,8,11]); self.assertEqual(cropped.getpixel((0,0)),(2,5,0))
        with self.assertRaises(ValueError): ops.crop_portrait(image,(13,13))

    def test_sheet_detection_uses_different_column_gaps_per_row(self):
        image=Image.new("RGB",(100,100),(255,0,255))
        positions=[(5,5,35,35),(65,5,95,35),(5,65,25,95),(45,65,95,95)]
        for box in positions: image.paste((255,213,65),box)
        boxes,meta=ops.detect_sheet_layout(image,2,2,minimum_gap=3,empty_fraction=0)
        self.assertNotEqual(meta["column_boundaries"][0],meta["column_boundaries"][1])
        alpha,_=ops.key_background(image)
        for box,object_box in zip(boxes,positions):
            self.assertLessEqual(box[0],object_box[0]);self.assertGreaterEqual(box[2],object_box[2])
        self.assertEqual(sum(sum(p[3]>0 for p in alpha.crop(box).get_flattened_data()) for box in boxes),sum(p[3]>0 for p in alpha.get_flattened_data()))

    def test_explicit_layout_rejects_out_of_bounds_and_missing_columns(self):
        image=Image.new("RGB",(10,10))
        with self.assertRaises(ValueError): ops.explicit_sheet_layout(image,[0,11],[[0,10]])
        with self.assertRaises(ValueError): ops.explicit_sheet_layout(image,[0,5,10],[[0,10]])

    def test_validation_fails_palette_baseline_and_reference_drift(self):
        image=Image.new("RGBA",(4,4),(0,0,0,0));image.putpixel((1,1),(17,17,17,255))
        report=ops.validate_images([image],size=(4,4),baseline=3)
        self.assertFalse(report["ok"]);self.assertEqual(len(report["errors"]),2)
        changed=image.copy();changed.putpixel((1,1),(18,17,17,255))
        self.assertFalse(ops.compare_reference(image,changed)["exact"])


class PipelineIntegrationTests(unittest.TestCase):
    def test_complete_sheet_pipeline_and_failure_for_wrong_reference(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name)
            low=Image.new("RGB",(8,8),(255,0,255))
            for y in range(1,7):
                for x in range(1,7): low.putpixel((x,y),(255,213,65))
            low.resize((40,40),Image.Resampling.NEAREST).save(root/"input.png")
            recipe={"version":1,"kind":"sheet","source":"input.png","layout":{"rows":1,"columns":1},
                    "chroma":{"auto_key":"border","tolerance":64},"reconstruction":{"grid":[8,8]},
                    "palette":"aap64","outline":{"color":"242234"},"canvas":{"size":[10,10],"baseline":8},"sprites":[{"name":"test","flip_horizontal":True}]}
            ops.save_json(root/"recipe.json",recipe)
            result=pixel_pipeline.run(root/"recipe.json",root/"output")
            self.assertEqual(result["status"],"complete")
            for stage in pixel_pipeline.STAGES: self.assertTrue((root/"output"/stage/"test.png").is_file())
            qa=json.loads((root/"output/qa.json").read_text());self.assertTrue(qa["ok"])
            with self.assertRaises(ValueError): pixel_pipeline.run(root/"recipe.json",root/"output")
            (root/"reference").mkdir();Image.new("RGBA",(10,10),(0,0,0,0)).save(root/"reference/test.png")
            recipe["reference_dir"]="reference";ops.save_json(root/"bad.json",recipe)
            with self.assertRaises(ValueError): pixel_pipeline.run(root/"bad.json",root/"bad_output")
            self.assertEqual(json.loads((root/"bad_output/run.json").read_text())["status"],"failed")


if __name__=="__main__": unittest.main()
