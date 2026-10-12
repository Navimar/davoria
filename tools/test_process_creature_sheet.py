from pathlib import Path
import json
import tempfile
import unittest

from PIL import Image, ImageDraw

import process_creature_sheet as process


class FullCellProcessingTests(unittest.TestCase):
    def test_silhouette_split_preserves_overlapping_boxes_and_detached_orb(self):
        image = Image.new("RGBA", (200, 100), (255, 0, 255, 255))
        draw = ImageDraw.Draw(image)
        draw.rectangle((20, 30, 60, 80), fill=(180, 100, 30, 255))
        draw.rectangle((60, 35, 120, 39), fill=(180, 100, 30, 255))
        draw.rectangle((110, 50, 180, 90), fill=(40, 150, 70, 255))
        draw.rectangle((150, 15, 160, 25), fill=(70, 100, 180, 255))
        boxes, sprites = process.split_silhouettes(image, 1, 2, {"auto_key": "border", "tolerance": 64})
        self.assertEqual(boxes, [(20, 30, 121, 81), (110, 15, 181, 91)])
        self.assertEqual(sprites[0].getpixel((100, 5)), (180, 100, 30, 255))
        self.assertEqual(sprites[1].getpixel((45, 5)), (70, 100, 180, 255))
        self.assertEqual(sprites[0].getpixel((95, 35))[3], 0)
        self.assertEqual(sprites[1].getpixel((5, 20))[3], 0)

    def test_highres_fit_removes_source_air_and_keeps_aspect_ratio(self):
        image = Image.new("RGBA", (200, 160), (0, 0, 0, 0))
        ImageDraw.Draw(image).rectangle((40, 50, 159, 109), fill=(200, 120, 30, 255))
        fitted, info = process.fit_highres(image, (512, 512))
        self.assertEqual(info["source_bbox"], [40, 50, 160, 110])
        self.assertEqual(info["cropped_size"], [120, 60])
        self.assertEqual(fitted.getchannel("A").getbbox(), (0, 256, 512, 512))
        self.assertEqual(info["fitted_body_size"], [512, 256])

    def test_full_sheet_crops_before_pixelization_and_preserves_thin_tip(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image = Image.new("RGBA", (512, 256), (255, 0, 255, 255))
            draw = ImageDraw.Draw(image)
            draw.rectangle((40, 100, 210, 210), fill=(100, 180, 40, 255))
            draw.rectangle((340, 100, 430, 224), fill=(200, 120, 30, 255))
            draw.line((385, 16, 385, 100), fill=(200, 120, 30, 255), width=1)
            image.save(root / "source.png")
            recipe = {"version": 1, "kind": "sheet", "source": "source.png",
                      "fit_visible_before_pixelization": True,
                      "layout": {"row_boundaries": [0, 256], "column_boundaries": [[0, 256, 512]]},
                      "chroma": {"auto_key": "border", "tolerance": 64},
                      "canvas": {"size": [64, 64], "baseline": 64},
                      "palette": "aap64", "outline": {"color": "242234", "neighbors": 8},
                      "preview_columns": 2, "sprites": [{"name": "wide"}, {"name": "tall"}]}
            path = root / "recipe.json"
            path.write_text(json.dumps(recipe))
            result = process.run(path, root / "output")
            self.assertEqual(result["status"], "complete")
            preparation = json.loads((root / "output/preparation/run.json").read_text())
            self.assertLess(preparation["order"].index("crop_alpha_bbox"), preparation["order"].index("pixelize"))
            self.assertEqual(preparation["padding"], 0)
            for name in ["wide", "tall"]:
                with Image.open(root / "output/processed/final" / (name + ".png")) as final:
                    bbox = final.getchannel("A").getbbox()
                    self.assertEqual(final.size, (64, 64))
                    self.assertEqual(max(bbox[2] - bbox[0], bbox[3] - bbox[1]), 64)
                    self.assertEqual(bbox[3], 64)
            with Image.open(root / "output/processed/final/tall.png") as tall:
                self.assertEqual(tall.getchannel("A").getbbox()[1], 0)
                self.assertGreater(tall.getchannel("A").crop((0, 0, 64, 1)).getbbox()[2], 0)


if __name__ == "__main__":
    unittest.main()
