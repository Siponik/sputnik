# Задачи переписывания на Flutter

Архитектура и правила — `docs/flutter-architecture.md`. Здесь — шаблон файла задачи и таблица модулей.

## Шаблон файла задачи (`NN-имя.md`)

```
# Задача NN: <модуль>
Источник: tracker/src/lib/<файл>.js (+ tests/<файл>.test.js)
Куда: app/lib/core/<файл>.dart, app/test/core/<файл>_test.dart
Как:
1. Добавь в tools/golden/gen.mjs генерацию случаев для функций модуля (по образцу when).
2. Запусти `node tools/golden/gen.mjs`, получи app/test/golden/<файл>.json.
3. Перенеси функции в Dart один в один (внимание: месяцы JS с 0, truthiness, undefined/null, неустойчивая сортировка).
4. Тест читает golden и требует одинаковые ответы.
Готово, когда: `cd app && flutter analyze && flutter test` зелёные.
Нельзя: трогать tracker/, bot/, reminders/; добавлять пакеты; чинить старое поведение молча.
PR: один в beta, раздел «## Что нового» — «внутренняя часть переписывания».
```

## Волны 1–2: модули

| Модуль JS | Строк ~ | Статус |
|---|---|---|
| dates (ymd, due) | 30 | ✅ |
| when | 250 | ✅ |
| layer (merge) | 200 | ✅ |
| repeat | | ○ |
| reminders | | ○ |
| habits | | ○ |
| calendar | | ○ |
| route | | ○ |
| create | | ○ |
| today | | ○ |
| search | | ○ |
| inbox | | ○ |
| dupes | | ○ |
| templates / boardedit | | ○ |
| spheres | | ○ |
| stickers | | ○ |
| taskpanel | | ○ |
| timer | | ○ |
| accent | | ○ |
| shell | | ○ |
| sharedcore | | ○ |
| sharedbot | | ○ |
| authcheck | | ○ |
| dropdown | | ○ |

Файлы отдельных задач добавляются по мере готовности пилота (волна 3).
