# Image Generation Pipeline

This project uses AI image generation only to create source art. Final game
assets are normalized locally into a deterministic 2D lineart format.

The stable contract is:

- generate a simple readable source image;
- remove or preserve transparency deterministically;
- fit the visible sprite into a fixed square canvas;
- normalize colors through named project swatches;
- normalize outlines after quantization;
- store shadows separately from the clean sprite body;
- validate the final PNG instead of trusting the generated image.

Prompts are not the source of truth. The manifest, swatch library, processing
rules, and validators define the final asset.

## Target Style

Sprites are clean lineart with flat color fills, readable silhouettes, and a
limited paper/card palette. They should read at small gameplay scale.

Generated source images should use:

- simple flat vector-like line art;
- thick clean outline;
- a few large color regions;
- centered subject;
- generous but not excessive padding;
- no text, letters, numbers, logos, or watermarks;
- no gradients, realistic shadows, material rendering, painterly texture, or
  tiny decorative details.

If the generated source looks like concept art when viewed alone, it is too
detailed. Regenerate it with fewer details instead of trying to repair it
locally.

## Asset Manifest

Every generated asset should have a small manifest entry before generation.

```yaml
id: goblin
type: enemy
size: 500
palette: card_swatches
palette_set: damage_or_danger_card
background: transparent
shadow: separate_oval
output: img/enemy/enemy_goblin.png
prompt_subject: small goblin monster creature
```

Required fields:

- `id`: stable file-safe asset id.
- `type`: asset family, for example `enemy`, `creature`, `item`, or `tile`.
- `size`: final square PNG size.
- `palette`: swatch library name.
- `palette_set`: named recipe inside the swatch library.
- `background`: `transparent` for sprites, `full_cell` for tiles.
- `shadow`: `none`, `separate_oval`, or `generated_extract`.
- `output`: final project-relative PNG path.
- `prompt_subject`: short subject description used by generation prompts.

Optional fields:

- `outline`: named outline swatch override. If omitted, use the outline from
  `recommended_sets[palette_set].outline`.

## Semantic Swatch Libraries

Project palettes should be stored as semantic swatch libraries, not only as
flat lists of hex values.

Example:

```json
{
  "name": "card_swatches",
  "backgrounds": {
    "white": "#ffffff"
  },
  "outline": {
    "black": "#000000",
    "charcoal": "#303030"
  },
  "fills": {
    "leaf_mint": "#78c0a0",
    "apple_red": "#e82030"
  },
  "recommended_sets": {
    "damage_or_danger_card": {
      "background": "white",
      "outline": "charcoal",
      "fills": ["apple_red"]
    }
  }
}
```

A processor must resolve a semantic set into a machine palette before
quantization:

1. Load the swatch library.
2. Select `recommended_sets[palette_set]`.
3. Resolve `background`, `outline`, and `fills` names into hex colors.
4. Build a fixed Pillow palette from the resolved colors.
5. Quantize with no dithering.
6. Validate that all non-shadow body pixels are in the resolved palette.

This keeps art direction centralized. A manifest references
`palette_set: damage_or_danger_card` instead of duplicating hex lists per asset.

## Generation

Use built-in image generation for source art unless a task explicitly requires
another path. Do not ask the model for pixel art.

Include the relevant palette schema directly in the prompt. Current image
models can follow named roles and hex colors well enough that source art may not
need forced quantization for preview-quality assets.

Prompt palette schema example:

```text
Use this exact palette schema as strongly as possible. Use these color families
only, with flat fills and very few intermediate colors:
- outline black: #303030
- eye yellow: #ffd94a
- fur brown dark/base/light: #6b3f1d, #9a6128, #bd7c35
- leather brown dark/base/light: #4c2d14, #76461c, #a46224
- bone cream/base/light: #d7ca9b, #f4ebbe
- chitin dark/base/light: #151923, #252b36, #3a414d
- metal gray dark/base/light: #46494e, #91989e, #dce2e4
Avoid all other hue families. Avoid dirty gradients, speckles, painterly color
variation, and extra unlisted colors.
```

### Sprite Prompt Template

```text
Game prototype sprite, simple flat vector-like line art.
Subject: <prompt_subject>.
Equipment: simple readable fantasy clothing or armor that belongs to the
creature silhouette; small gear details are allowed, but no large loose props
unless the manifest explicitly requires them.
Style: very simple mono-color fills, clean thick black outline, flat paper
cutout look, no shadows, no gradients, no texture, no tiny details.
Composition: centered living subject in a classic tile-based roguelike view,
three-quarter top-down camera, full body visible, generous padding, readable at
small size. Plain removable background. No text, no letters, no numbers, no
watermark.
```

For transparent sprites, prefer a perfectly flat chroma-key background when
native transparency is unavailable:

```text
Create the sprite on a perfectly flat solid #00ff00 chroma-key background for
background removal. The background must be one uniform color with no shadows,
gradients, texture, reflections, floor plane, or lighting variation. Do not use
#00ff00 anywhere in the subject.
```

Use a different chroma-key color if the subject itself is green.

### Source Acceptance

Reject and regenerate source images when:

- the subject is not the requested asset;
- the subject is too small in the source square;
- the creature lacks simple clothing, armor, or readable worn equipment;
- the camera angle does not read as a classic tile-based roguelike
  three-quarter top-down creature view;
- text, letters, numbers, logos, or watermarks are present;
- an unintended object or loose prop dominates the silhouette;
- realistic shadows or gradients are baked into the body;
- the silhouette is not readable at small size;
- the background is not removable.

## Local Processing

Use Pillow or an equivalent deterministic image library. The processor should
not derive a new palette from the source image.

If the prompt-level palette is visually consistent, preview assets may skip
quantization and only run background/shadow extraction, crop, fit, and color
drift validation. Use fixed Pillow quantization when strict palette membership
is required for final export.

Do not use blur, median blur, or generic smoothing as a normal cleanup step.
These filters make the lineart feel soft and damage the crisp sprite style. If
generated fills have visible ripple/speckle artifacts, prefer regenerating with
a stricter flat-fill prompt or use a true region/shape repaint pass that
preserves hard lineart edges.

### Sprite Body Steps

1. Open the generated PNG.
2. Convert to `RGBA`.
3. Remove chroma-key background if present.
4. Crop to visible non-background content.
5. Resize and center into the target square canvas.
6. Preserve transparent background.
7. For paper-cutout sprites, make the body alpha binary after chroma-key
   removal and fitting. Do not keep semi-transparent body edge pixels; they
   create white or key-color fringes after quantization. Semi-transparent alpha
   is allowed for the separate shadow layer only.
8. Before quantization, force almost-black body pixels to the configured
   outline swatch from the resolved semantic palette.
9. Quantize opaque body pixels with a fixed palette:

   ```python
   q = rgb.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
   ```

10. Restore the binary body alpha.
11. After quantization, force dark body pixels to the outline swatch again.
12. Force the outside silhouette edge to the outline swatch to remove any
    white/key-color fringe.
13. Save the clean sprite PNG to the manifest `output` path.

The final sprite body should have transparent corners and no baked background.
It should not contain semi-transparent body pixels.

### Outline Normalization

Outline normalization happens twice:

- before quantization, so dirty generated near-black pixels map consistently;
- after quantization, so dark palette accidents are forced back to the outline
  swatch.

Default sprite outline comes from `recommended_sets[palette_set].outline`.
Use a manifest `outline` value only as an explicit override, not as a hidden
processor default.

### Shadow Processing

Do not bake shadows into the clean sprite body PNG. Produce the clean body first,
then compose any deliverable shadow as a separate alpha layer under that body.

Default shadow mode is `separate_oval`:

- draw a hard-edged transparent oval below the sprite;
- use black with alpha, not a colored shadow;
- use only a tiny edge blur if needed to avoid jagged pixels;
- width: `45-65%` of the sprite cell;
- height: `10-18%` of the sprite cell;
- opacity: `34-46%`;
- place it under the feet or contact area;
- draw it below the sprite in previews, runtime scenes, or the shadowed
  deliverable PNG.

When writing a shadowed PNG, keep the body pixels unchanged after palette
quantization. Start with the black alpha shadow layer, then copy non-transparent
body pixels over it without RGB blending. This preserves the body swatch palette
and keeps the shadow limited to black pixels with varying alpha.

`generated_extract` is allowed only when the source image uses a flat chroma-key
background and explicitly asks for a simple flat contact shadow. Extract the
shadow separately and never run the shadow pixels through body palette
quantization.

## Output Contracts

### Enemy Icons

Enemy clean body sprites are stored under:

```text
img/enemy/enemy_<id>.png
```

Enemy sprites with the default composed oval shadow are stored under:

```text
img/enemy/enemy_<id>_shadow.png
```

Contract:

- final PNG is exactly `500x500`;
- mode is `RGBA`;
- background is transparent in both clean and shadowed outputs;
- colors come from a semantic swatch set, usually `card_swatches`;
- outline is normalized to the configured outline swatch;
- no baked shadow in the clean PNG;
- shadowed PNGs may add only black alpha shadow pixels under the unchanged
  clean body.

### Tiles

Tiles are different from sprites:

- final PNG is square;
- background is `full_cell`;
- no transparent corners;
- no object-icon composition;
- no hard accidental border unless the tile type requires one.

## Validation

Every processed asset should pass automatic checks:

- output size equals manifest `size x size`;
- sprite outputs have alpha;
- sprite corners are transparent;
- tile outputs are fully opaque;
- all non-shadow body pixels are in the resolved fixed palette;
- outline pixels are normalized to the configured outline swatch;
- chroma-key colors and background fringes are absent;
- no text, letters, numbers, logos, or watermarks are visible;
- the visible subject fits inside safe cell bounds;
- preview rendering shows the separate shadow below the sprite when requested.

## Preview Sheets

For every batch, generate a preview sheet with:

- clean sprite on a dark checker/background;
- clean sprite on a light background;
- sprite inside a game cell;
- sprite with its separate shadow layer;
- `1x`, `2x`, and `4x` previews;
- filename and manifest id.

Review assets at the size used in-game. If the silhouette is weak at gameplay
scale, regenerate the source image instead of over-fixing it locally.

## Suggested Project Layout

```text
assets/
  generation/
    manifests/
    prompts/
    raw/
    processed/
      creatures/
      items/
      tiles/
    previews/
img/
  enemy/
tools/
  assetgen/
    palettes/
      card_swatches.json
    process_sprite.py
    process_enemy_icon.py
    validate_asset.py
    build_preview_sheet.py
```

## Implementation Notes

`tools/assetgen/process_sprite.py` currently expects a flat palette schema:

```json
{
  "name": "creature_main",
  "outline": "#303030",
  "shadow": "#000000",
  "colors": ["#303030"]
}
```

To support semantic swatch libraries, add a resolver layer or a separate enemy
processor that accepts:

```text
--palette tools/assetgen/palettes/card_swatches.json
--palette-set damage_or_danger_card
--size 500
--background transparent
--shadow separate_oval
```

The resolver should convert semantic swatches into the flat fixed palette used
by Pillow quantization, then run the same deterministic quantization and
validation steps.
