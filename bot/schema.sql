-- Общий бот Спутника (bot/). Применяется: npx wrangler d1 execute sputnik-bot --remote --file schema.sql
CREATE TABLE IF NOT EXISTS users (
  chat TEXT PRIMARY KEY,      -- id чата Telegram
  key_hash TEXT NOT NULL,     -- sha256 ключа трекера (сам ключ хранится только у человека)
  name TEXT,
  tz TEXT DEFAULT 'Europe/Moscow',
  muted INTEGER DEFAULT 0,
  state TEXT,                 -- JSON: { items, today, snoozed, at } — присылает трекер
  next_at INTEGER,            -- ближайшее напоминание (мс), для выборки раз в минуту
  created INTEGER
);
CREATE INDEX IF NOT EXISTS users_key ON users (key_hash);
CREATE INDEX IF NOT EXISTS users_next ON users (next_at);
CREATE TABLE IF NOT EXISTS codes (code TEXT PRIMARY KEY, chat TEXT NOT NULL, name TEXT, exp INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS inbox (id INTEGER PRIMARY KEY AUTOINCREMENT, chat TEXT NOT NULL, body TEXT NOT NULL, at INTEGER);
CREATE INDEX IF NOT EXISTS inbox_chat ON inbox (chat);
CREATE TABLE IF NOT EXISTS sent (id INTEGER PRIMARY KEY AUTOINCREMENT, chat TEXT NOT NULL, key TEXT NOT NULL, item TEXT, at INTEGER);
CREATE INDEX IF NOT EXISTS sent_chat ON sent (chat, key);
