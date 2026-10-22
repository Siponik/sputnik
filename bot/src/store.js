// Хранилище общего бота в Cloudflare D1 (таблицы — schema.sql). Тот же набор методов в тестах — в памяти.

export function d1Store(db) {
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
      for (const t of ['users', 'inbox', 'sent', 'codes']) await run(`DELETE FROM ${t} WHERE chat = ?`, chat);
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
    purge: (before) => run('DELETE FROM sent WHERE at < ?', before),
    addInbox: (chat, body) => run('INSERT INTO inbox (chat, body, at) VALUES (?, ?, ?)', chat, JSON.stringify(body), Date.now()),
    async inbox(chat) { return (await all('SELECT id, body FROM inbox WHERE chat = ? ORDER BY id LIMIT 100', chat)).map((r) => ({ id: r.id, ...JSON.parse(r.body) })); },
    async ack(chat, ids) { for (const id of ids) await run('DELETE FROM inbox WHERE chat = ? AND id = ?', chat, id); },
  };
}
