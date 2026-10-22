# Общий бот Спутника

Один Telegram-бот для всех, кто поставил Спутник. Живёт на Cloudflare Workers (бесплатный тариф),
база — Cloudflare D1 `sputnik-bot`. Ключей Google здесь нет: трекер сам присылает напоминания и задачи
на неделю (`PUT /state`) и забирает то, что человек написал боту (`GET /inbox`, `POST /ack`).

Личный бот на Apps Script (`reminders/`) продолжает работать как раньше.

- `src/logic.js` — команды, привязка по коду, напоминания (тесты — `tracker/tests/shared-bot.test.js`)
- `src/store.js` — таблицы D1 (`schema.sql`)
- `src/index.js` — адреса воркера и cron раз в минуту

## Привязка

Человек пишет боту `/start` → бот даёт код из 6 цифр (15 минут) → человек вводит код в Спутнике
(«Настройки» → «Напоминания» → «Telegram») → трекер шлёт `POST /link { code, key }`, где `key` — случайный
ключ, который трекер хранит в слое (`settings.tgbot`). В базе — только sha256 ключа.

## Выкладка (PowerShell, папка `bot`)

```
npx wrangler login
npx wrangler deploy
Get-Content ..\bot-token.txt -Raw | npx wrangler secret put BOT_TOKEN
$sec = -join ((48..57) + (97..122) | Get-Random -Count 32 | % { [char]$_ }); $sec | npx wrangler secret put TG_SECRET
$tok = (Get-Content ..\bot-token.txt -Raw).Trim()
Invoke-RestMethod "https://api.telegram.org/bot$tok/setWebhook" -Method Post -Body @{ url = "<адрес воркера>/tg"; secret_token = $sec; allowed_updates = '["message","callback_query"]' }
```

`bot-token.txt` (токен от @BotFather) исключён `.gitignore` и в репозиторий не попадает.
Таблицы уже созданы; заново — `npx wrangler d1 execute sputnik-bot --remote --file schema.sql`.
