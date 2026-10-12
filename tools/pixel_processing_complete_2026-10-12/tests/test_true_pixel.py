from __future__ import annotations

import unittest

from PIL import Image

import true_pixel


class TruePixelGridPhaseTests(unittest.TestCase):
    def make_shifted_pixel_art(
        self,
        width: int = 24,
        height: int = 20,
        cell_size: int = 5,
        left: int = 2,
        top: int = 3,
        right: int = 1,
        bottom: int = 4,
    ) -> tuple[Image.Image, Image.Image]:
        colors = (
            (18, 32, 32),
            (255, 213, 65),
            (40, 92, 196),
            (232, 106, 115),
        )
        low = Image.new("RGB", (width, height))
        low.putdata(
            [
                colors[(x + 2 * y) % len(colors)]
                for y in range(height)
                for x in range(width)
            ]
        )
        scaled = low.resize(
            (width * cell_size, height * cell_size),
            Image.Resampling.NEAREST,
        )
        source = Image.new(
            "RGB",
            (
                left + scaled.width + right,
                top + scaled.height + bottom,
            ),
            (255, 0, 255),
        )
        source.paste(scaled, (left, top))
        return low, source

    def test_reconstruct_pixels_respects_explicit_phase(self) -> None:
        expected, source = self.make_shifted_pixel_art()

        reconstructed = true_pixel.reconstruct_pixels(
            source,
            expected.width,
            expected.height,
            inset=0.18,
            cell_size_x=5.0,
            cell_size_y=5.0,
            offset_x=2.0,
            offset_y=3.0,
        )

        self.assertEqual(reconstructed.size, expected.size)
        self.assertEqual(
            list(reconstructed.get_flattened_data()),
            list(expected.get_flattened_data()),
        )

    def test_estimate_grid_finds_shifted_phase(self) -> None:
        expected, source = self.make_shifted_pixel_art()

        selected, _ = true_pixel.estimate_grid(source, 4.5, 5.5)
        reconstructed = true_pixel.reconstruct_pixels(
            source,
            selected.width,
            selected.height,
            inset=0.18,
            cell_size_x=selected.cell_size_x,
            cell_size_y=selected.cell_size_y,
            offset_x=selected.offset_x,
            offset_y=selected.offset_y,
        )

        self.assertAlmostEqual(selected.cell_size_x, 5.0, delta=0.06)
        self.assertAlmostEqual(selected.cell_size_y, 5.0, delta=0.06)
        self.assertAlmostEqual(selected.offset_x, 2.0, delta=0.3)
        self.assertAlmostEqual(selected.offset_y, 3.0, delta=0.3)
        self.assertEqual(reconstructed.size, expected.size)
        self.assertEqual(
            list(reconstructed.get_flattened_data()),
            list(expected.get_flattened_data()),
        )

    def test_rgba_reconstruction_ignores_transparent_chroma_rgb(self) -> None:
        source = Image.new("RGBA", (10, 5), (255, 0, 255, 0))
        pixels = source.load()

        for index in range(13):
            pixels[index % 5, index // 5] = (40, 180, 90, 255)
        for index in range(12):
            pixels[5 + index % 5, index // 5] = (40, 180, 90, 255)

        reconstructed = true_pixel.reconstruct_pixels(
            source,
            logical_width=2,
            logical_height=1,
            inset=0.0,
            alpha_coverage=0.5,
        )

        self.assertEqual(
            list(reconstructed.get_flattened_data()),
            [
                (40, 180, 90, 255),
                (0, 0, 0, 0),
            ],
        )


if __name__ == "__main__":
    unittest.main()
