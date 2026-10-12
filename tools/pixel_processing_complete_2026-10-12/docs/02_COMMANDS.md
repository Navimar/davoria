# Отдельные исполняемые этапы

Команды выполняются из корня архива с активированной средой Python.
Папки выходов ниже должны быть новыми. ImageMagick не требуется.

## Нарезка по реальным промежуткам

```bash
python3 src/split_sheet.py assets/monsters_tileset_04_light_naive_magenta_pseudo.png \
  -o work/01_highres --rows 4 --columns 4
```

Точная нарезка из записанного рецепта:

```bash
python3 src/split_sheet.py assets/monsters_tileset_04_light_naive_magenta_pseudo.png \
  -o work/exact_crops --layout recipes/sheet04.json
```

`crops.json` фиксирует каждое окно. Столбцы для разных рядов могут отличаться.

## Удаление магенты у high-res фрагмента

```bash
python3 src/remove_chroma_key.py \
  --input assets/monster_tiles_04_light_naive_magenta_sources/01_giant_snail.png \
  --out work/snail_alpha.png --auto-key border --tolerance 64
```

Допуск — максимальная поканальная разница до выбранного ключа. Для почти
ровной магенты используется hard key, без feather и soft matte. Скрипт
также содержит прежние экспериментальные параметры soft matte и despill.

## Независимая реконструкция

```bash
python3 src/true_pixel.py work/snail_alpha.png -o work/snail_pixels.png \
  --palette none --min-cell 4.5 --max-cell 5.5 --alpha-coverage 0.5 -v
```

## AAP64, обводка, отражение и холст

```bash
python3 src/map_palette.py work/snail_pixels.png -o work/snail_aap64.png
python3 src/outline.py work/snail_aap64.png -o work/snail_outline.png --color 242234
python3 src/mirror.py work/snail_outline.png -o work/snail_right.png
python3 src/align_canvas.py work/snail_right.png -o work/snail66.png --size 66x66 --baseline 63
```

Эти четыре скрипта принимают также папку PNG и папку результатов.
`mirror.py --names 01_giant_snail 08_armored_war_boar` отражает только
указанные имена, сохраняя остальные файлы.

## Портретный crop без изменения масштаба

```bash
python3 src/crop_portrait.py assets/wolf_true_pixel_aap64.png \
  -o work/wolf96.png --size 96x96 --x 58 --y 34 --shift-y 8
```

Положительный `shift-y` опускает камеру. Координаты отсчитываются в
настоящих восстановленных пикселях. Выход за границы считается ошибкой.

## Лист, сравнение, проверка

```bash
python3 src/assemble_preview.py assets/monster_tiles_04_light_naive_individual_aap64_alpha_first_outline \
  -o work/sheet04.png --columns 4
python3 src/compare_sets.py assets/monster_tiles_03_light_naive_individual_aap64_alpha_first_outline \
  --other assets/monster_tiles_04_light_naive_individual_aap64_alpha_first_outline \
  -o work/comparison.png --report work/consistency.json
python3 src/validate_assets.py assets/monster_tiles_04_light_naive_individual_aap64_alpha_first_outline \
  --size 66x66 --baseline 63 --count 16 -o work/qa.json
```

Валидация возвращает код 1 при нарушении условий. `--reference DIR`
добавляет проверку совпадения с эталонными PNG. У отдельных операций
`--force` разрешает замену их выходов; входные PNG они не перезаписывают.
