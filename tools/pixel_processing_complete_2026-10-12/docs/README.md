# Полный пайплайн пиксельной обработки

Весь путь от генеративного high-res PNG до готовых настоящих пиксельных
спрайтов выполняется программами в `src/`. Нарезка, обводка, отражение,
укладка и портретное кадрирование имеют отдельные исполняемые скрипты.
`pixel_pipeline.py` объединяет их в один запуск по JSON-рецепту.

## Установка

Требуются Python 3.10+ и Pillow. Проверенная версия Pillow закреплена:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

Все команды ниже запускаются из распакованной папки. Если виртуальная
среда активирована, `.venv/bin/python` можно заменить на `python3`.

## Полный запуск сохранённого листа

```bash
.venv/bin/python src/pixel_pipeline.py recipes/sheet04.json -o output/sheet04
```

Это заново нарежет исходный PNG, удалит магенту у каждого high-res
фрагмента, независимо найдёт сетку, восстановит настоящие пиксели,
сведёт RGB к AAP64, сделает обводку, отразит выбранных персонажей,
выровняет их на 66×66 и сравнит с сохранённым эталоном.

`output/sheet04/final/` содержит тайлы; `preview.png` — лист;
`run.json` — полный протокол; `qa.json` — проверки.
Каталог результата должен быть новым или пустым.

## Повторение всех канонических примеров

```bash
.venv/bin/python src/verify_examples.py --report output/reproduction.json
```

Проверяются девять рецептов: два листа в режиме поиска и два в режиме
фиксированных фаз, гоблин, две версии кракена и две версии волка.
Всего 69 сравнений. Сохранённый результат проверки —
`reports/reproducibility.json`.

## Новый лист

```bash
.venv/bin/python src/pixel_pipeline.py recipes/new_sheet.json \
  --source /absolute/path/new_sheet.png -o output/new_sheet
```

Нарезка будет автоматически найдена по пустым промежуткам. Имена по
умолчанию — `01_tile` … `16_tile`. Для направления взгляда задайте
`flip_horizontal` у нужных существ в копии рецепта: классификатор
направления взгляда не используется.

## Одиночные изображения

```bash
.venv/bin/python src/pixel_pipeline.py recipes/goblin96.json -o output/goblin
.venv/bin/python src/pixel_pipeline.py recipes/kraken96.json -o output/kraken
.venv/bin/python src/pixel_pipeline.py recipes/wolf_portrait96.json -o output/wolf
```

Волк сначала восстанавливается как 162×162, затем кадрируется до 96×96
с камерой, опущенной на восемь пикселей относительно предыдущего кадра.
Никакого дополнительного рескейла нет.

## Отдельные этапы и документы

Скрипты этапов: `split_sheet.py`, `remove_chroma_key.py`, `true_pixel.py`,
`map_palette.py`, `outline.py`, `mirror.py`, `align_canvas.py`,
`crop_portrait.py`, `assemble_preview.py`, `compare_sets.py`,
`validate_assets.py`. Каждый имеет `--help`.

Читайте `docs/01_PIPELINES.md`, `02_COMMANDS.md`, `03_RECIPE_FORMAT.md`,
`04_ALGORITHM.md`, `05_GENERATION_AND_HISTORY.md` и `06_VERIFICATION.md`.

## Состав

- `src/` — весь код и общий запуск;
- `tests/` — тесты сетки, alpha и недостающих ранее этапов;
- `recipes/` — переносимые настройки всех канонических примеров;
- `assets/` — все сохранённые пиксельные исходники, промежуточные PNG,
  итоговые версии и исторические сравнения;
- `assets/original_generated/` — девять исходных генераций этой работы;
- `examples/` — полный свежий прогон третьего и четвёртого листов;
- `palettes/` — AAP64;
- `reports/`, `MANIFEST.json`, `SHA256SUMS` — проверка и состав архива.

Код генератора изображений в комплект не входит: ImageGen был встроенным
инструментом. Исходные генерации и переносимый шаблон промпта приложены;
вся последующая обработка выполняется локально одной командой.
