# Генерация и сохранённые эксперименты

## Рабочая художественная настройка

Слишком тёмный, детализированный исходник после реконструкции и палитры
становился плохо читаемой тёмной массой. Светлый простой пиксель-арт с
небольшим влиянием наивной живописи дал существенно более ясные формы.

Переносимый шаблон промпта ниже описывает принятое направление. Это
восстановленная спецификация, а не заявленная дословная копия всех старых
вызовов генератора.

> Create a 4 by 4 fantasy monster sprite sheet, exactly one complete creature
> per cell, with generous empty gaps. Bright, simple pixel art inspired by
> early DOS fantasy strategy games and the first Heroes of Might and Magic,
> with a gentle naive-painting feeling. Clear silhouettes, readable local
> colors, simple shading, consistent creature scale and detail density.
> Large approximately five-pixel square pseudo-pixels. Flat solid #FF00FF
> background. No magenta inside creatures, no ground shadows, no labels,
> frames or cell borders. All limbs, wings, tails and weapons must fit fully.
> Use the previous accepted sheet only as a style and scale reference.
> Generate new creatures and poses rather than copying its subjects.

Новые существа четвёртого листа: улитка, гнолл-лучник, пугало, разбойник-
полурослик, огненный элементаль, болотная ведьма, циклоп, бронированный
кабан, краб, саламандра-воин, грифон, чумной маг, голем, рыцарь без головы,
дух фонаря и виверна.

Генерация сама не гарантирует точного периода, фазы или AAP64. Эти
ограничения устанавливаются локальной обработкой после генерации.

## Исходные генерации

Девять оригинальных PNG сохранены с исходными именами в
`assets/original_generated/`. Их SHA-256 записаны в `MANIFEST.json`.

| Исходный файл | Назначение |
|---|---|
| `call_pakpAWGx9J9c9M449W0yX1Mg.png` | первая более мелкопиксельная генерация гоблина |
| `call_pNTm6s2vfuua7hnJnVAp3ToT.png` | крупнопиксельный гоблин, источник результата 96×96 |
| `call_oJiMA98d3MYGbBXe2mnNqOqF.png` | кракен |
| `call_MQjN8E6VpGAyJr5EIpIC3Jrw.png` | волк |
| `call_p4QJ2eE3g7nyABmY9fipMGlE.png` | первый лист с чёрным фоном |
| `call_CI9pGaTAMbrb9OG28zly8L7T.png` | первый лист на магенте |
| `call_SocTuiGLr8REI9kfiRjPitXE.png` | второй, более тёмный лист |
| `call_ur9mKXMPCEMQ4JSeMrbIVWzh.png` | третий, светлый принятый лист |
| `call_G0UOwq2vEUuAR1aob93W8vNq.png` | четвёртый, светлый принятый лист |

Рецепты используют копии с осмысленными именами в `assets/`.

## Что сохраняет архив

В `assets/` включены все обнаруженные в проекте пиксельные PNG: входные
листы, отдельные фрагменты, ранние обработанные варианты, soft/hard key,
phase-aware, alpha-first, версии с обводкой, портреты и сравнения. Старые
неудачные варианты сохранены как исторические контрольные изображения.

Канонические рецепты воспроизводят принятые результаты. Прежние
эксперименты можно повторять отдельными этапами: ручная `--grid`,
`--palette image/none`, параметры soft matte или другое расположение
chroma key. Старые ошибочные реализации не используются по умолчанию.

## Выясненные проблемы

- Чёрный фон удалял чёрные части персонажей; фон заменён магентой.
- Общая сетка листа сминала независимо смещённые спрайты; сначала режем.
- Сетка от края не учитывала фазу; теперь она определяется независимо.
- RGB прозрачной магенты загрязнял края; chroma key выполняется до
  реконструкции, а alpha исключает прозрачные образцы.
- Завышенная агрессивность ключа выедала дырки в летучей мыши; принят
  допуск 64 и hard key без feather.
- Розовые и светлые остатки на кромке дополнительно закрывает внутренняя
  одно-пиксельная обводка из AAP64.
- Портрет волка исправлен сдвигом камеры на восемь пикселей вниз.
