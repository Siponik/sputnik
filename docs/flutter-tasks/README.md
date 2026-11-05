# Задачи переписывания на Flutter

Архитектура и правила — `docs/flutter-architecture.md`. Один файл — одна задача — один PR в `beta`.

## Как отдавать задачи (памятка для Siponik)

1. Открой новый чат с моделью подешевле (например, Sonnet или Haiku) на этом репозитории.
2. Вставь: «Выполни задачу из `docs/flutter-tasks/01-repeat.md`. Сначала прочитай `docs/flutter-architecture.md`.»
3. Модель сделает ветку и PR в `beta`. Проверка на GitHub (`app-check`) должна быть зелёной: она гоняет golden-тесты,
   то есть сравнивает ответы нового кода со старым. Зелёная — можно сливать.
4. Порядок — по номерам. Задачи без зависимостей (колонка «Нужно») можно отдавать параллельно в разных чатах.
5. Если модель застряла или PR красный два раза подряд — позови меня (сильную модель) в этот проект.

Готово: `dates`, `when`, `layer` (merge), `oauth`, пилот «Сегодня», вход в Google.

## Волна 1: логика (`app/lib/core`)

| № | Модуль | Нужно | Готово, когда |
|---|---|---|---|
| [01](01-repeat.md) | `repeat` | нет | есть `app/lib/core/…dart` |
| [02](02-dupes.md) | `dupes` | нет | есть `app/lib/core/…dart` |
| [03](03-search.md) | `search` | нет | есть `app/lib/core/…dart` |
| [04](04-timer.md) | `timer` | нет | есть `app/lib/core/…dart` |
| [05](05-fresh.md) | `fresh` | нет | есть `app/lib/core/…dart` |
| [06](06-accent.md) | `accent` | нет | есть `app/lib/core/…dart` |
| [07](07-authcheck.md) | `authcheck` | нет | есть `app/lib/core/…dart` |
| [08](08-dropdown.md) | `dropdown` | нет | есть `app/lib/core/…dart` |
| [09](09-meta.md) | `meta` | нет | есть `app/lib/core/…dart` |
| [10](10-spheres.md) | `spheres` | нет | есть `app/lib/core/…dart` |
| [11](11-templates.md) | `templates` | нет | есть `app/lib/core/…dart` |
| [12](12-boardedit.md) | `boardedit` | `core/templates.dart` | есть `app/lib/core/…dart` |
| [13](13-today.md) | `today` | `core/when.dart`, `core/meta.dart`, `core/repeat.dart` | есть `app/lib/core/…dart` |
| [14](14-stickers.md) | `stickers` | `core/spheres.dart`, `core/when.dart`, `core/repeat.dart` | есть `app/lib/core/…dart` |
| [15](15-habits.md) | `habits` | нет | есть `app/lib/core/…dart` |
| [16](16-calendar.md) | `calendar` | `core/habits.dart` | есть `app/lib/core/…dart` |
| [17](17-reminders.md) | `reminders` | `core/calendar.dart`, `core/habits.dart` | есть `app/lib/core/…dart` |
| [18](18-taskpanel.md) | `taskpanel` | `core/reminders.dart` | есть `app/lib/core/…dart` |
| [19](19-route.md) | `route` | `core/when.dart`, `core/repeat.dart`, `core/templates.dart`, `core/stickers.dart` | есть `app/lib/core/…dart` |
| [20](20-create.md) | `create` | `core/stickers.dart` | есть `app/lib/core/…dart` |
| [21](21-inbox.md) | `inbox` | `core/templates.dart`, `core/stickers.dart`, `core/spheres.dart` | есть `app/lib/core/…dart` |
| [22](22-shell.md) | `shell` | нет | есть `app/lib/core/…dart` |
| [23](23-preview.md) | `preview` | нет | есть `app/lib/core/…dart` |
| [24](24-sharedcore.md) | `sharedcore` | нет | есть `app/lib/core/…dart` |
| [25](25-sharedbot.md) | `sharedbot` | `core/route.dart`, `core/today.dart` | есть `app/lib/core/…dart` |

Волна 2 (данные: очередь исходящих, слой на Drive, Calendar) и экраны (по дизайну G) — файлы задач появятся после волны 1.
