#!/usr/bin/env python3
"""Recover a true low-resolution pixel image from generated pseudo-pixel art."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import math
import os
from pathlib import Path
from statistics import median_low
from typing import Iterable, Sequence

from PIL import Image, UnidentifiedImageError


MAX_DIMENSION = 8192
DEFAULT_MIN_CELL_SIZE = 4.0
DEFAULT_MAX_CELL_SIZE = 32.0
DEFAULT_IMAGE_PALETTE_SIZE = 64
DEFAULT_INSET = 0.18
DEFAULT_ALPHA_COVERAGE = 0.5
GRID_CELL_SIZE_STEP = 0.05
GRID_PHASE_STEP = 0.25
MAX_AXIS_CANDIDATES = 96

Pixel = tuple[int, ...]
RGBPixel = tuple[int, int, int]

# AAP-64 by Adigun A. Polack:
# https://lospec.com/palette-list/aap-64
AAP64_HEX = (
    "060608",
    "141013",
    "3b1725",
    "73172d",
    "b4202a",
    "df3e23",
    "fa6a0a",
    "f9a31b",
    "ffd541",
    "fffc40",
    "d6f264",
    "9cdb43",
    "59c135",
    "14a02e",
    "1a7a3e",
    "24523b",
    "122020",
    "143464",
    "285cc4",
    "249fde",
    "20d6c7",
    "a6fcdb",
    "ffffff",
    "fef3c0",
    "fad6b8",
    "f5a097",
    "e86a73",
    "bc4a9b",
    "793a80",
    "403353",
    "242234",
    "221c1a",
    "322b28",
    "71413b",
    "bb7547",
    "dba463",
    "f4d29c",
    "dae0ea",
    "b3b9d1",
    "8b93af",
    "6d758d",
    "4a5462",
    "333941",
    "422433",
    "5b3138",
    "8e5252",
    "ba756a",
    "e9b5a3",
    "e3e6ff",
    "b9bffb",
    "849be4",
    "588dbe",
    "477d85",
    "23674e",
    "328464",
    "5daf8d",
    "92dcba",
    "cdf7e2",
    "e4d2aa",
    "c7b08b",
    "a08662",
    "796755",
    "5a4e44",
    "423934",
)
AAP64_PALETTE: tuple[RGBPixel, ...] = tuple(
    tuple(bytes.fromhex(color)) for color in AAP64_HEX
)


@dataclass(frozen=True)
class GridCandidate:
    """One possible logical pixel grid and its periodic-edge score."""

    width: int
    height: int
    cell_size_x: float
    cell_size_y: float
    offset_x: float
    offset_y: float
    score_x: float
    score_y: float
    score: float


@dataclass(frozen=True)
class AxisCandidate:
    """One possible pseudo-pixel period and phase on a source axis."""

    cell_size: float
    offset: float
    score: float


def parse_positive_float(value: str) -> float:
    try:
        number = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("ожидалось положительное число") from error
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("ожидалось положительное число")
    return number


def parse_inset(value: str) -> float:
    try:
        inset = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("отступ должен быть числом") from error
    if not 0.0 <= inset < 0.5:
        raise argparse.ArgumentTypeError("отступ должен быть от 0 до 0.49")
    return inset


def parse_alpha_coverage(value: str) -> float:
    try:
        coverage = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError(
            "покрытие alpha должно быть числом"
        ) from error
    if not 0.0 <= coverage <= 1.0:
        raise argparse.ArgumentTypeError(
            "покрытие alpha должно быть от 0 до 1"
        )
    return coverage


def parse_palette_size(value: str) -> int:
    try:
        colors = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError(
            "число цветов должно быть целым"
        ) from error
    if not 0 <= colors <= 256:
        raise argparse.ArgumentTypeError(
            "число цветов должно быть от 0 до 256"
        )
    return colors


def parse_grid(value: str) -> tuple[int, int]:
    normalized = value.lower().replace("×", "x")
    try:
        raw_width, raw_height = normalized.split("x", maxsplit=1)
        width = int(raw_width)
        height = int(raw_height)
    except (ValueError, TypeError) as error:
        raise argparse.ArgumentTypeError(
            "сетка должна иметь формат WIDTHxHEIGHT, например 128x128"
        ) from error

    if (
        not 1 <= width <= MAX_DIMENSION
        or not 1 <= height <= MAX_DIMENSION
    ):
        raise argparse.ArgumentTypeError(
            f"стороны сетки должны быть от 1 до {MAX_DIMENSION}"
        )
    return width, height


def sampled_positions(length: int, limit: int = 640) -> range:
    """Return a stable sample of an axis without changing its coordinates."""

    stride = max(1, math.ceil(length / limit))
    return range(0, length, stride)


def color_distance(first: Pixel, second: Pixel) -> int:
    """Fast perceptual-ish RGB distance suitable for edge detection."""

    red = abs(first[0] - second[0])
    green = abs(first[1] - second[1])
    blue = abs(first[2] - second[2])
    # Green contributes most to perceived brightness; the maximum term keeps
    # saturated color boundaries visible even when their luminance is similar.
    return 2 * red + 3 * green + blue + max(red, green, blue)


def normalize_profile(profile: Sequence[float]) -> list[float]:
    """Suppress isolated scene edges while retaining repeated grid edges."""

    if not profile:
        return []
    ordered = sorted(profile)
    cap = ordered[min(len(ordered) - 1, round(len(ordered) * 0.94))]
    if cap <= 0:
        return [0.0 for _ in profile]
    return [math.sqrt(min(value, cap)) for value in profile]


def edge_profiles(image: Image.Image) -> tuple[list[float], list[float]]:
    """Measure vertical and horizontal boundary strength across the image."""

    rgb = image.convert("RGB")
    pixels = rgb.load()
    width, height = rgb.size
    sampled_rows = sampled_positions(height)
    sampled_columns = sampled_positions(width)

    vertical = [0.0] * max(0, width - 1)
    for x in range(1, width):
        total = 0
        for y in sampled_rows:
            total += color_distance(pixels[x - 1, y], pixels[x, y])
        vertical[x - 1] = total / len(sampled_rows)

    horizontal = [0.0] * max(0, height - 1)
    for y in range(1, height):
        total = 0
        for x in sampled_columns:
            total += color_distance(pixels[x, y - 1], pixels[x, y])
        horizontal[y - 1] = total / len(sampled_columns)

    return normalize_profile(vertical), normalize_profile(horizontal)


def boundary_score(
    profile: Sequence[float],
    source_length: int,
    cell_size: float,
    offset: float,
    prefix_energy: Sequence[float],
    total_energy: float,
) -> float:
    """Score edge energy on a regular grid with an independent phase."""

    if cell_size <= 0 or not profile or total_energy <= 0:
        return 0.0

    radius = max(0, min(2, round(cell_size * 0.11)))
    phase = offset % cell_size
    boundary = phase if phase > 1e-9 else cell_size
    intervals: list[tuple[int, int]] = []
    while boundary < source_length - 1e-9:
        # profile[index] represents the boundary between source pixels index
        # and index + 1, hence the -1 conversion from image coordinates.
        center = round(boundary) - 1
        start = max(0, center - radius)
        stop = min(len(profile), center + radius + 1)
        if start < stop:
            if intervals and start <= intervals[-1][1]:
                intervals[-1] = (
                    intervals[-1][0],
                    max(intervals[-1][1], stop),
                )
            else:
                intervals.append((start, stop))
        boundary += cell_size

    selected_count = sum(stop - start for start, stop in intervals)
    if selected_count == 0 or selected_count == len(profile):
        return 0.0

    selected_energy = sum(
        prefix_energy[stop] - prefix_energy[start]
        for start, stop in intervals
    )
    coverage = selected_energy / total_energy
    baseline = selected_count / len(profile)
    excess = coverage - baseline
    if excess <= 0:
        return 0.0

    enrichment = coverage / baseline
    return excess * math.sqrt(enrichment)


def best_axis_phase(
    profile: Sequence[float],
    source_length: int,
    cell_size: float,
) -> tuple[float, float]:
    """Return the strongest boundary score and phase for one cell period."""

    total_energy = sum(profile)
    if total_energy <= 0:
        return 0.0, 0.0

    weighted_cosine = 0.0
    weighted_sine = 0.0
    for index, value in enumerate(profile):
        angle = math.tau * ((index + 1) % cell_size) / cell_size
        weighted_cosine += value * math.cos(angle)
        weighted_sine += value * math.sin(angle)
    phase_coherence = (
        math.hypot(weighted_cosine, weighted_sine) / total_energy
    )
    coherent_offset = (
        math.atan2(weighted_sine, weighted_cosine) % math.tau
    ) * cell_size / math.tau

    prefix_energy = [0.0]
    for value in profile:
        prefix_energy.append(prefix_energy[-1] + value)

    phase_count = max(1, math.ceil(cell_size / GRID_PHASE_STEP))
    best_score = -1.0
    best_offset = 0.0
    for phase_index in range(phase_count):
        offset = phase_index * cell_size / phase_count
        score = boundary_score(
            profile,
            source_length,
            cell_size,
            offset,
            prefix_energy,
            total_energy,
        )
        if score > best_score:
            best_score = score
            best_offset = offset

    # A slightly wrong period can still hit every edge through the tolerance
    # radius, but its edge residues drift around the period. Circular phase
    # coherence penalizes that drift and resolves the otherwise broad score
    # plateau. On genuinely regular source pixels it also gives a more precise
    # phase than the quarter-pixel exhaustive scan.
    score = max(0.0, best_score) * (0.5 + 0.5 * phase_coherence)
    offset = coherent_offset if phase_coherence >= 0.15 else best_offset
    return score, offset


def estimate_axis_candidates(
    profile: Sequence[float],
    source_length: int,
    minimum_cell_size: float,
    maximum_cell_size: float,
) -> list[AxisCandidate]:
    """Rank pseudo-pixel periods without anchoring them to either image edge."""

    sample_count = max(
        1,
        math.ceil(
            (maximum_cell_size - minimum_cell_size) / GRID_CELL_SIZE_STEP
        ),
    )
    candidates: list[AxisCandidate] = []
    for sample_index in range(sample_count + 1):
        cell_size = minimum_cell_size + (
            (maximum_cell_size - minimum_cell_size)
            * sample_index
            / sample_count
        )
        score, offset = best_axis_phase(profile, source_length, cell_size)
        if score > 0:
            candidates.append(
                AxisCandidate(
                    cell_size=cell_size,
                    offset=offset,
                    score=score,
                )
            )

    candidates.sort(key=lambda candidate: candidate.score, reverse=True)
    return candidates[:MAX_AXIS_CANDIDATES]


def estimate_grid_candidates(
    image: Image.Image,
    minimum_cell_size: float,
    maximum_cell_size: float,
) -> list[GridCandidate]:
    """Rank square-pixel grids using independently phased edge periodicity."""

    width, height = image.size
    vertical, horizontal = edge_profiles(image)
    x_candidates = estimate_axis_candidates(
        vertical,
        width,
        minimum_cell_size,
        maximum_cell_size,
    )
    y_candidates = estimate_axis_candidates(
        horizontal,
        height,
        minimum_cell_size,
        maximum_cell_size,
    )

    candidates: list[GridCandidate] = []
    for x_candidate in x_candidates:
        for y_candidate in y_candidates:
            size_mismatch = abs(
                math.log(x_candidate.cell_size / y_candidate.cell_size)
            )
            if size_mismatch > 0.08:
                continue

            score_x = x_candidate.score
            score_y = y_candidate.score
            harmonic = (
                2 * score_x * score_y / (score_x + score_y)
                if score_x > 0 and score_y > 0
                else 0.0
            )
            combined = (harmonic + 0.08 * (score_x + score_y)) * math.exp(
                -8.0 * size_mismatch
            )
            x_ranges = phased_cell_ranges(
                width,
                x_candidate.cell_size,
                x_candidate.offset,
            )
            y_ranges = phased_cell_ranges(
                height,
                y_candidate.cell_size,
                y_candidate.offset,
            )
            if len(x_ranges) < 2 or len(y_ranges) < 2:
                continue
            candidates.append(
                GridCandidate(
                    width=len(x_ranges),
                    height=len(y_ranges),
                    cell_size_x=x_candidate.cell_size,
                    cell_size_y=y_candidate.cell_size,
                    offset_x=x_candidate.offset,
                    offset_y=y_candidate.offset,
                    score_x=score_x,
                    score_y=score_y,
                    score=combined,
                )
            )

    candidates.sort(key=lambda candidate: candidate.score, reverse=True)
    return candidates


def estimate_grid(
    image: Image.Image,
    minimum_cell_size: float,
    maximum_cell_size: float,
) -> tuple[GridCandidate, list[GridCandidate]]:
    if minimum_cell_size >= maximum_cell_size:
        raise ValueError(
            "минимальный размер псевдопикселя должен быть меньше максимального"
        )
    if min(image.size) < minimum_cell_size * 2:
        raise ValueError("изображение слишком маленькое для поиска сетки")

    candidates = estimate_grid_candidates(
        image,
        minimum_cell_size,
        maximum_cell_size,
    )
    if not candidates:
        raise ValueError(
            "не удалось обнаружить регулярную пиксельную сетку; "
            "задайте её вручную через --grid"
        )
    return candidates[0], candidates


def cell_bounds(index: int, logical_length: int, source_length: int) -> tuple[int, int]:
    start = round(index * source_length / logical_length)
    stop = round((index + 1) * source_length / logical_length)
    return start, max(start + 1, stop)


def phased_cell_ranges(
    source_length: int,
    cell_size: float,
    offset: float,
) -> list[tuple[int, int]]:
    """Return complete source cells for a period and phase, dropping edge scraps."""

    if cell_size <= 0:
        raise ValueError("размер псевдопикселя должен быть положительным")

    start_float = offset % cell_size
    if math.isclose(start_float, cell_size, abs_tol=1e-9):
        start_float = 0.0

    ranges: list[tuple[int, int]] = []
    while start_float + cell_size <= source_length + 1e-9:
        start = max(0, round(start_float))
        stop = min(source_length, round(start_float + cell_size))
        if stop > start and (not ranges or start >= ranges[-1][1]):
            ranges.append((start, stop))
        start_float += cell_size
    return ranges


def inset_bounds(start: int, stop: int, inset: float) -> tuple[int, int]:
    length = stop - start
    margin = min((length - 1) // 2, round(length * inset))
    return start + margin, stop - margin


def weighted_median(values: Iterable[tuple[int, int]]) -> int:
    """Return a median where each channel value is weighted by source alpha."""

    ordered = sorted(values)
    total_weight = sum(weight for _, weight in ordered)
    midpoint = total_weight / 2
    cumulative = 0
    for value, weight in ordered:
        cumulative += weight
        if cumulative >= midpoint:
            return value
    raise ValueError("невозможно вычислить медиану пустой выборки")


def representative_color(
    samples: Iterable[Pixel],
    channels: int,
    alpha_coverage: float,
) -> Pixel:
    sampled = list(samples)
    if not sampled:
        raise ValueError("невозможно прочитать цвет пустой ячейки")

    if channels != 4:
        channel_values: list[list[int]] = [[] for _ in range(channels)]
        for sample in sampled:
            for channel in range(channels):
                channel_values[channel].append(sample[channel])
        return tuple(median_low(values) for values in channel_values)

    total_alpha = sum(sample[3] for sample in sampled)
    coverage = total_alpha / (255 * len(sampled))
    visible = [sample for sample in sampled if sample[3] > 0]
    if not visible or coverage < alpha_coverage:
        # Transparent RGB is normalized to black so a removed chroma key can
        # never leak back through later palette conversion or compositing.
        return 0, 0, 0, 0

    rgb = tuple(
        weighted_median((sample[channel], sample[3]) for sample in visible)
        for channel in range(3)
    )
    alpha = median_low([sample[3] for sample in visible])
    return (*rgb, alpha)


def reconstruct_pixels(
    image: Image.Image,
    logical_width: int,
    logical_height: int,
    inset: float,
    *,
    cell_size_x: float | None = None,
    cell_size_y: float | None = None,
    offset_x: float = 0.0,
    offset_y: float = 0.0,
    alpha_coverage: float = DEFAULT_ALPHA_COVERAGE,
) -> Image.Image:
    """Collapse every inferred pseudo-pixel cell into exactly one pixel."""

    has_alpha = "A" in image.getbands()
    mode = "RGBA" if has_alpha else "RGB"
    source = image.convert(mode)
    pixels = source.load()
    source_width, source_height = source.size
    channels = len(mode)
    reconstructed: list[Pixel] = []

    if (cell_size_x is None) != (cell_size_y is None):
        raise ValueError("размер ячейки должен быть задан для обеих осей")

    if cell_size_x is None or cell_size_y is None:
        raw_x_ranges = [
            cell_bounds(column, logical_width, source_width)
            for column in range(logical_width)
        ]
        raw_y_ranges = [
            cell_bounds(row, logical_height, source_height)
            for row in range(logical_height)
        ]
    else:
        raw_x_ranges = phased_cell_ranges(
            source_width,
            cell_size_x,
            offset_x,
        )
        raw_y_ranges = phased_cell_ranges(
            source_height,
            cell_size_y,
            offset_y,
        )
        if not raw_x_ranges or not raw_y_ranges:
            raise ValueError("смещённая сетка не содержит полных ячеек")

    x_ranges = [
        inset_bounds(start, stop, inset)
        for start, stop in raw_x_ranges
    ]
    y_ranges = [
        inset_bounds(start, stop, inset)
        for start, stop in raw_y_ranges
    ]

    for y_start, y_stop in y_ranges:
        for x_start, x_stop in x_ranges:
            samples = (
                pixels[x, y]
                for y in range(y_start, y_stop)
                for x in range(x_start, x_stop)
            )
            reconstructed.append(
                representative_color(
                    samples,
                    channels,
                    alpha_coverage,
                )
            )

    output = Image.new(mode, (len(x_ranges), len(y_ranges)))
    output.putdata(reconstructed)
    return output


def reduce_image_palette(image: Image.Image, colors: int) -> Image.Image:
    """Merge near colors without introducing any dithering."""

    if colors == 0 or colors >= image.width * image.height:
        return image

    rgb = image.convert("RGB")
    quantized = rgb.quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    if image.mode == "RGBA":
        quantized.putalpha(image.getchannel("A"))
        return quantized
    return quantized


def srgb_channel_to_linear(channel: int) -> float:
    value = channel / 255.0
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def rgb_to_oklab(color: RGBPixel) -> tuple[float, float, float]:
    """Convert an sRGB color to perceptually uniform OKLab coordinates."""

    red, green, blue = (
        srgb_channel_to_linear(channel) for channel in color
    )
    light = 0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue
    medium = 0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue
    short = 0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue

    light_root = light ** (1 / 3)
    medium_root = medium ** (1 / 3)
    short_root = short ** (1 / 3)

    return (
        0.2104542553 * light_root
        + 0.7936177850 * medium_root
        - 0.0040720468 * short_root,
        1.9779984951 * light_root
        - 2.4285922050 * medium_root
        + 0.4505937099 * short_root,
        0.0259040371 * light_root
        + 0.7827717662 * medium_root
        - 0.8086757660 * short_root,
    )


def squared_oklab_distance(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
) -> float:
    return sum(
        (first_channel - second_channel) ** 2
        for first_channel, second_channel in zip(first, second)
    )


def map_to_reference_palette(
    image: Image.Image,
    palette: Sequence[RGBPixel],
) -> Image.Image:
    """Map every color to the nearest fixed palette entry in OKLab."""

    if not palette:
        raise ValueError("эталонная палитра не должна быть пустой")

    has_alpha = image.mode == "RGBA"
    source = image.convert("RGBA" if has_alpha else "RGB")
    palette_oklab = tuple(rgb_to_oklab(color) for color in palette)
    color_cache: dict[RGBPixel, RGBPixel] = {}
    mapped_pixels: list[Pixel] = []

    for pixel in source.get_flattened_data():
        rgb = (pixel[0], pixel[1], pixel[2])
        mapped = color_cache.get(rgb)
        if mapped is None:
            source_oklab = rgb_to_oklab(rgb)
            closest_index = min(
                range(len(palette)),
                key=lambda index: squared_oklab_distance(
                    source_oklab,
                    palette_oklab[index],
                ),
            )
            mapped = palette[closest_index]
            color_cache[rgb] = mapped

        if has_alpha:
            mapped_pixels.append((*mapped, pixel[3]))
        else:
            mapped_pixels.append(mapped)

    result = Image.new(source.mode, source.size)
    result.putdata(mapped_pixels)
    return result


def default_output_path(input_path: Path) -> Path:
    return input_path.with_name(f"{input_path.stem}_true_pixel.png")


def save_png_atomic(image: Image.Image, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.{os.getpid()}.tmp")
    try:
        image.save(temporary, format="PNG", optimize=True)
        os.replace(temporary, output)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Восстанавливает настоящее низкоразрешённое пиксельное изображение "
            "из сгенерированного псевдопиксельного PNG."
        ),
        epilog=(
            "Пример: python3 true_pixel.py kraken.png "
            "-o kraken_true_pixel.png"
        ),
    )
    parser.add_argument("input", type=Path, help="исходный PNG")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="результирующий PNG; по умолчанию рядом с исходником",
    )
    parser.add_argument(
        "--grid",
        type=parse_grid,
        help="задать логическую сетку вручную, например 128x128",
    )
    parser.add_argument(
        "--min-cell",
        type=parse_positive_float,
        default=DEFAULT_MIN_CELL_SIZE,
        help=(
            "минимальный ожидаемый размер псевдопикселя "
            f"(по умолчанию: {DEFAULT_MIN_CELL_SIZE:g})"
        ),
    )
    parser.add_argument(
        "--max-cell",
        type=parse_positive_float,
        default=DEFAULT_MAX_CELL_SIZE,
        help=(
            "максимальный ожидаемый размер псевдопикселя "
            f"(по умолчанию: {DEFAULT_MAX_CELL_SIZE:g})"
        ),
    )
    parser.add_argument(
        "--palette",
        choices=("aap64", "image", "none"),
        default="aap64",
        help=(
            "цветовая палитра: фиксированная AAP-64, палитра из изображения "
            "или без сведения (по умолчанию: aap64)"
        ),
    )
    parser.add_argument(
        "--colors",
        type=parse_palette_size,
        default=DEFAULT_IMAGE_PALETTE_SIZE,
        help=(
            "размер динамической палитры для --palette image; "
            "0 отключает сведение "
            f"(по умолчанию: {DEFAULT_IMAGE_PALETTE_SIZE})"
        ),
    )
    parser.add_argument(
        "--inset",
        type=parse_inset,
        default=DEFAULT_INSET,
        help=(
            "доля отступа от краёв псевдопикселя при чтении цвета "
            f"(по умолчанию: {DEFAULT_INSET:g})"
        ),
    )
    parser.add_argument(
        "--alpha-coverage",
        type=parse_alpha_coverage,
        default=DEFAULT_ALPHA_COVERAGE,
        help=(
            "минимальная доля непрозрачного покрытия ячейки RGBA; "
            "прозрачные образцы не участвуют в вычислении RGB "
            f"(по умолчанию: {DEFAULT_ALPHA_COVERAGE:g})"
        ),
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="показать лучшие варианты автоматически найденной сетки",
    )
    return parser


def load_image(path: Path) -> Image.Image:
    if not path.is_file():
        raise ValueError(f"файл не найден: {path}")
    try:
        image = Image.open(path)
        image.load()
    except (UnidentifiedImageError, OSError) as error:
        raise ValueError(f"не удалось прочитать PNG: {path}") from error

    if image.format != "PNG":
        raise ValueError("поддерживается только формат PNG")
    if (
        image.width > MAX_DIMENSION
        or image.height > MAX_DIMENSION
        or image.width < 2
        or image.height < 2
    ):
        raise ValueError(
            f"размер PNG должен быть от 2x2 до {MAX_DIMENSION}x{MAX_DIMENSION}"
        )
    return image


def main() -> None:
    parser = build_parser()
    arguments = parser.parse_args()

    try:
        image = load_image(arguments.input)
        output = arguments.output or default_output_path(arguments.input)
        if output.resolve() == arguments.input.resolve():
            raise ValueError("результат не должен перезаписывать исходный PNG")

        candidates: list[GridCandidate] = []
        if arguments.grid:
            logical_width, logical_height = arguments.grid
            cell_size_x = image.width / logical_width
            cell_size_y = image.height / logical_height
            selected = GridCandidate(
                width=logical_width,
                height=logical_height,
                cell_size_x=cell_size_x,
                cell_size_y=cell_size_y,
                offset_x=0.0,
                offset_y=0.0,
                score_x=0.0,
                score_y=0.0,
                score=0.0,
            )
        else:
            selected, candidates = estimate_grid(
                image,
                arguments.min_cell,
                arguments.max_cell,
            )

        if arguments.grid:
            result = reconstruct_pixels(
                image,
                selected.width,
                selected.height,
                arguments.inset,
                alpha_coverage=arguments.alpha_coverage,
            )
        else:
            result = reconstruct_pixels(
                image,
                selected.width,
                selected.height,
                arguments.inset,
                cell_size_x=selected.cell_size_x,
                cell_size_y=selected.cell_size_y,
                offset_x=selected.offset_x,
                offset_y=selected.offset_y,
                alpha_coverage=arguments.alpha_coverage,
            )
        if arguments.palette == "aap64":
            result = map_to_reference_palette(result, AAP64_PALETTE)
        elif arguments.palette == "image":
            result = reduce_image_palette(result, arguments.colors)
        save_png_atomic(result, output)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Ошибка: {error}\n")

    if arguments.verbose and candidates:
        print("Лучшие варианты сетки:")
        for candidate in candidates[:8]:
            print(
                f"  {candidate.width}x{candidate.height}: "
                f"{candidate.cell_size_x:.2f}x{candidate.cell_size_y:.2f} px, "
                f"offset={candidate.offset_x:.2f}x"
                f"{candidate.offset_y:.2f}, "
                f"score={candidate.score:.5f}"
            )

    print(
        f"Сетка: {selected.width}x{selected.height} "
        f"(псевдопиксель ≈ "
        f"{selected.cell_size_x:.2f}x{selected.cell_size_y:.2f} px, "
        f"смещение ≈ {selected.offset_x:.2f}x{selected.offset_y:.2f})"
    )
    if arguments.palette == "aap64":
        palette_label = "AAP-64 (фиксированная, OKLab)"
    elif arguments.palette == "image" and arguments.colors:
        palette_label = f"из изображения ({arguments.colors} цветов)"
    else:
        palette_label = "без сведения"
    print(f"Палитра: {palette_label}")
    print(f"Создано: {output.resolve()}")


if __name__ == "__main__":
    main()
