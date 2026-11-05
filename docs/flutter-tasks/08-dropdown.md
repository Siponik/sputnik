# Задача 08: перенести `dropdown` в Dart

**Прочитай сначала:** `docs/flutter-architecture.md` (особенно п. 4 «Как переносится логика» и «Подводные камни JS → Dart»).

- Источник: `tracker/src/lib/dropdown.js` (~87 строк), старый тест: `tracker/tests/dropdown.test.js`
- Куда: `app/lib/core/dropdown.dart`, тест `app/test/core/dropdown_test.dart`
- Нужно готовое до этой задачи: нет
- Важно: Только логика (lib/dropdown.js), без виджета.

## Шаги
1. Создай `tools/golden/dropdown.mjs` по образцу `tools/golden/gen.mjs` (тот же `write`, одна строка — один случай):
   импортируй функции из `../../tracker/src/lib/dropdown.js`, прогони их на входах и запиши `app/test/golden/dropdown.json`.
   Входы: все примеры из старого теста + граничные (пустые значения, конец месяца/года, русский регистр, дубликаты).
   Если функция зависит от «сейчас» — передавай дату явно. Запуск: `node tools/golden/dropdown.mjs`.
2. Перенеси в `app/lib/core/dropdown.dart` все экспортируемые чистые функции: те же имена, те же правила.
   Шапка файла: `// Порт tracker/src/lib/dropdown.js`. Не импортируй `data/`, `state/`, `ui/` и Flutter — только Dart и `core/`.
3. Тест читает golden-файл и для каждого случая требует тот же ответ (образец — `app/test/core/when_test.dart`).
4. `cd app; dart format -l 120 lib test; flutter analyze; flutter test` — без ошибок.

## Нельзя
- менять `tracker/`, `bot/`, `reminders/` и чужие файлы в `app/`;
- добавлять пакеты;
- «чинить» поведение старого кода: если JS делает странно — повтори и опиши в PR.

## PR
Ветка от `beta`, PR в `beta`, название «Flutter: перенос dropdown». Описание:
```
## Что нового
- Внутренняя часть нового приложения, пользователю пока не видна.
```
Плюс список перенесённых функций и что пропущено (и почему).
