// Хранилище общего бота в Cloudflare D1 (таблицы — schema.sql). Тот же набор методов в тестах — в памяти.

// Таблица утренней сводки появилась позже остальных — создаём её сами, чтобы выкладка не требовала миграции.
const BRIEF_SQL = 'CREATE TABLE IF NOT EXISTS brief (chat TEXT PRIMARY KEY, at INTEGER, days TEXT, off INTEGER DEFAULT 0, sent TEXT)';
let briefReady = null;
// Черновики задач (drafts.js) — тоже своя таблица, создаётся сама. Строка с id '~' — настройки и выученное (draftMeta).
const DRAFT_SQL = 'CREATE TABLE IF NOT EXISTS drafts (chat TEXT NOT NULL, id TEXT NOT NULL, body TEXT NOT NULL, at INTEGER, PRIMARY KEY (chat, id))';
const DRAFT_TTL = 2 * 864e5;
let draftReady = null;

export function d1Store(db) {
  const briefTable = () => (briefReady ??= db.prepare(BRIEF_SQL).run().catch((e) => { briefReady = null; throw e; }));
  const draftTable = () => (draftReady ??= db.prepare(DRAFT_SQL).run().catch((e) => { draftReady = null; throw e; }));
  const one = (sql, ...a) => db.prepare(sql).bind(...a).first();
  const all = async (sql, ...a) => (await db.prepare(sql).bind(...a).all()).results ?? [];
  const run = (sql, ...a) => db.prepare(sql).bind(...a).run();
  return {
    user: (chat) => one('SELECT chat, name, tz, muted FROM users WHERE chat = ?', chat),
    userByKey: (hash) => one('SELECT chat, name, tz, muted FROM users WHERE key_hash = ?', hash),
    async putCode(code, chat, name, exp) {
      await run('DELETE FROM codes WHERE chat = ? OR exp < ?', chat, Date.now());
      await run('INSERT OR REPLACE INTO codes (code, chat, name, exp) VALUES (?, ?, ?, ?)', code, chat, name, exp);
    },
    async takeCode(code) {
      const c = await one('SELECT chat, name, exp FROM codes WHERE code = ?', code);
      if (c) await run('DELETE FROM codes WHERE code = ?', code);
      return c;
    },
    link: (chat, hash, tz, name) => run(
      `INSERT INTO users (chat, key_hash, tz, name, created) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(chat) DO UPDATE SET key_hash = excluded.key_hash, tz = excluded.tz, name = excluded.name, muted = 0`,
      chat, hash, tz, name, Date.now()),
    async unlink(chat) {
      await briefTable();
      await draftTable();
      for (const t of ['users', 'inbox', 'sent', 'codes', 'brief', 'drafts']) await run(`DELETE FROM ${t} WHERE chat = ?`, chat);
    },
    setMuted: (chat, v) => run('UPDATE users SET muted = ? WHERE chat = ?', v ? 1 : 0, chat),
    async state(chat) { const r = await one('SELECT state FROM users WHERE chat = ?', chat); return r?.state ? JSON.parse(r.state) : null; },
    putState: (chat, state, tz, next) => run('UPDATE users SET state = ?, tz = COALESCE(?, tz), next_at = ? WHERE chat = ?', JSON.stringify(state), tz ?? null, next, chat),
    async addSnooze(chat, item) {
      const st = (await this.state(chat)) ?? {};
      st.snoozed = [...(st.snoozed ?? []), item].slice(-40);
      const r = await one('SELECT next_at FROM users WHERE chat = ?', chat);
      const at = Date.parse(item.fireAt);
      await run('UPDATE users SET state = ?, next_at = ? WHERE chat = ?', JSON.stringify(st), r?.next_at ? Math.min(r.next_at, at) : at, chat);
    },
    setNext: (chat, next) => run('UPDATE users SET next_at = ? WHERE chat = ?', next, chat),
    due: (now) => all('SELECT chat, tz FROM users WHERE muted = 0 AND next_at IS NOT NULL AND next_at <= ? LIMIT 200', now),
    async sentKeys(chat) { return new Set((await all('SELECT key FROM sent WHERE chat = ?', chat)).map((r) => r.key)); },
    async markSent(chat, item, now) { const r = await run('INSERT INTO sent (chat, key, item, at) VALUES (?, ?, ?, ?)', chat, item.key, JSON.stringify(item), now); return r.meta.last_row_id; },
    unmarkSent: (chat, id) => run('DELETE FROM sent WHERE chat = ? AND id = ?', chat, id),
    async sentById(chat, id) { const r = await one('SELECT item FROM sent WHERE chat = ? AND id = ?', chat, id); return r ? { item: JSON.parse(r.item) } : null; },
    async purge(before) {
      await run('DELETE FROM sent WHERE at < ?', before);
      await run('DELETE FROM tries WHERE at < ?', Date.now() - 3600e3);
    },
    async tries(ip, since) { return (await one('SELECT COUNT(*) AS n FROM tries WHERE ip = ? AND at > ?', ip, since))?.n ?? 0; },
    addTry: (ip, at) => run('INSERT INTO tries (ip, at) VALUES (?, ?)', ip, at),
    async addInbox(chat, body) { const r = await run('INSERT INTO inbox (chat, body, at) VALUES (?, ?, ?)', chat, JSON.stringify(body), Date.now()); return r.meta.last_row_id; },
    /** Поменять запись в очереди, пока трекер её не забрал. false — уже забрал. */
    async updateInbox(chat, id, body) { const r = await run('UPDATE inbox SET body = ? WHERE chat = ? AND id = ?', JSON.stringify(body), chat, id ?? -1); return r.meta.changes > 0; },
    async dropInbox(chat, id) { const r = await run('DELETE FROM inbox WHERE chat = ? AND id = ?', chat, id ?? -1); return r.meta.changes > 0; },
    // черновики задач (drafts.js)
    async draft(chat, id) { await draftTable(); const r = await one('SELECT body FROM drafts WHERE chat = ? AND id = ?', chat, id); return r ? JSON.parse(r.body) : null; },
    async lastDraft(chat) { await draftTable(); const r = await one("SELECT body FROM drafts WHERE chat = ? AND id <> '~' ORDER BY at DESC LIMIT 1", chat); return r ? JSON.parse(r.body) : null; },
    async putDraft(chat, d, at) {
      await draftTable();
      await run('INSERT OR REPLACE INTO drafts (chat, id, body, at) VALUES (?, ?, ?, ?)', chat, d.id, JSON.stringify({ ...d, at }), at);
      await run("DELETE FROM drafts WHERE id <> '~' AND at < ?", at - DRAFT_TTL);
    },
    async dropDraft(chat, id) { await draftTable(); await run('DELETE FROM drafts WHERE chat = ? AND id = ?', chat, id); },
    async draftMeta(chat) { await draftTable(); const r = await one("SELECT body FROM drafts WHERE chat = ? AND id = '~'", chat); return r ? JSON.parse(r.body) : null; },
    async setDraftMeta(chat, meta) { await draftTable(); await run("INSERT OR REPLACE INTO drafts (chat, id, body, at) VALUES (?, '~', ?, ?)", chat, JSON.stringify(meta), Date.now()); },
    async inbox(chat) { return (await all('SELECT id, body FROM inbox WHERE chat = ? ORDER BY id LIMIT 100', chat)).map((r) => ({ id: r.id, ...JSON.parse(r.body) })); },
    async ack(chat, ids) { for (const id of ids) await run('DELETE FROM inbox WHERE chat = ? AND id = ?', chat, id); },
    // утренняя сводка (brief.js)
    async brief(chat) { await briefTable(); return one('SELECT at, days, off, sent FROM brief WHERE chat = ?', chat); },
    async briefUsers() {
      await briefTable();
      return all('SELECT u.chat, u.tz, u.muted, b.at, b.days, b.off, b.sent FROM users u LEFT JOIN brief b ON b.chat = u.chat');
    },
    async setBrief(chat, { at = null, days = null, off = null, sent = null }) {
      await briefTable();
      await run(`INSERT INTO brief (chat, at, days, off, sent) VALUES (?, ?, ?, COALESCE(?, 0), ?)
        ON CONFLICT(chat) DO UPDATE SET at = COALESCE(excluded.at, at), days = COALESCE(excluded.days, days),
        off = COALESCE(?, off), sent = COALESCE(excluded.sent, sent)`, chat, at, days, off, sent, off);
    },
  };
}
