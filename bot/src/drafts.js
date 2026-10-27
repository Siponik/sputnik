// Общий бот: черновики задач. Догадка и вид карточки — draft.js, здесь — Telegram, хранилище и очередь для трекера.
//
//   переслал сообщение   → черновик с догадкой; «✅ Создать» — задача уходит в очередь трекера (GET /inbox)
//   свой текст           → сразу в очередь, карточка «📥 Записал» с кнопками правки (/ask on — тоже черновиком)
//   текст сразу после    → «завтра 18:00», «@работа», «!!» правят последнюю карточку
//   трекер забрал задачу → карточка меняется на «✅ В Спутнике» (POST /ack → ackDrafts)
//
// Списки, основной список и выученные слова присылает трекер в PUT /state (lists, def, words).
// Пока трекер не забрал задачу, правки меняют запись в очереди; потом — только в самом Спутнике.

import * as D from './draft.js';
import { parts } from './logic.js';

export const EDIT_MS = 15 * 60e3; // текстом правится карточка не старше 15 минут
const LEARN_MAX = 200;

/** Контекст догадки: сегодня в часовом поясе человека, списки от трекера, выученное. */
async function ctxOf(chat, tz, store, now) {
  const st = (await store.state(chat)) ?? {};
  const meta = (await store.draftMeta(chat)) ?? {};
  const lists = Array.isArray(st.lists) ? st.lists.filter((l) => l && l.id && l.title) : [];
  return { today: parts(new Date(now), tz).ymd, lists, def: st.def, words: st.words ?? {}, learned: meta.learned ?? {}, ask: !!meta.ask, meta };
}

/** Поля задачи для трекера (sharedbot.fromDraft). */
const payload = (d) => ({ title: d.title, notes: d.notes, due: d.day, time: d.time, listId: d.list, prio: d.prio, rem: d.rem, ...(d.src ? { src: d.src } : {}) });

function sayCard(tg, chat, d, ctx) {
  const c = D.card(d, ctx);
  return tg('sendMessage', { chat_id: chat, text: c.text, parse_mode: 'HTML', disable_web_page_preview: true, reply_markup: c.markup });
}
function editCard(tg, chat, msgId, d, ctx) {
  const c = D.card(d, ctx);
  return tg('editMessageText', { chat_id: chat, message_id: msgId, text: c.text, parse_mode: 'HTML', disable_web_page_preview: true, reply_markup: c.markup })
    .catch((e) => { if (!/not modified/i.test(String(e))) throw e; });
}

/** В очередь трекера; возвращает черновик с made: 'sent' и номером записи. */
async function send(chat, d, store, now) {
  const qid = await store.addInbox(chat, { type: 'add', text: d.title, draft: payload(d), did: d.id, at: now });
  return { ...d, made: 'sent', mode: '', qid };
}

async function learn(chat, ctx, d, store) {
  if (!d.fkey || !d.listSet || !d.list) return;
  const learned = { ...ctx.learned };
  delete learned[d.fkey];
  learned[d.fkey] = d.list;
  const keys = Object.keys(learned);
  for (const k of keys.slice(0, Math.max(0, keys.length - LEARN_MAX))) delete learned[k];
  await store.setDraftMeta(chat, { ...ctx.meta, learned });
}

/** Сообщение без команды от подключённого человека: пересланное, правка карточки или новая задача. */
export async function onDraftMessage(msg, chat, user, { store, tg, now }) {
  const ctx = await ctxOf(chat, user.tz, store, now);
  const fwd = D.senderOf(msg);
  const text = String(msg.text ?? '').trim();
  const last = await store.lastDraft(chat);
  const recent = last && now - last.at < EDIT_MS ? last : null;
  const fresh = recent && recent.made !== 'final' ? recent : null;

  if (fwd) {
    // Несколько пересланных подряд — в один черновик.
    if (fresh && !fresh.made && fresh.from && now - fresh.at < D.MERGE_MS) {
      const d = D.merge(fresh, msg, ctx);
      await store.putDraft(chat, d, now);
      return editCard(tg, chat, d.msg, d, ctx);
    }
    const d = { ...D.guess(msg, ctx), id: D.newId(now) };
    const r = await sayCard(tg, chat, d, ctx);
    return store.putDraft(chat, { ...d, msg: r?.result?.message_id }, now);
  }
  if (!text) return;

  if (fresh) {
    const d = D.editByText(fresh, text, ctx);
    if (d) {
      let next = d;
      if (fresh.made === 'sent' && !(await store.updateInbox(chat, fresh.qid, { type: 'add', text: d.title, draft: payload(d), did: d.id, at: now }))) {
        next = { ...fresh, made: 'final' }; // трекер уже забрал
        await tg('sendMessage', { chat_id: chat, text: 'Эта задача уже в Спутнике — поправь её там.' });
      }
      if (fresh.msg) await tg('deleteMessage', { chat_id: chat, message_id: fresh.msg }).catch(() => {});
      const r = await sayCard(tg, chat, next, ctx);
      return store.putDraft(chat, { ...next, msg: r?.result?.message_id }, now);
    }
  }

  // src — исходный текст: трекер возьмёт из него #тип и повтор («каждую неделю»), которых в карточке нет.
  if (recent && !fresh && D.editByText(recent, text, ctx)) return tg('sendMessage', { chat_id: chat, text: 'Эта задача уже в Спутнике — поправь её там.' });
  let d = { ...D.guess({ text: text.slice(0, 1000) }, ctx), id: D.newId(now), src: text.slice(0, 1000) };
  if (!d.title) return tg('sendMessage', { chat_id: chat, text: 'Не понял, что за задача. Пример: <i>купить корм завтра 18:00</i>', parse_mode: 'HTML' });
  if (!ctx.ask) d = await send(chat, d, store, now);
  const r = await sayCard(tg, chat, d, ctx);
  return store.putDraft(chat, { ...d, msg: r?.result?.message_id }, now);
}

/** Нажали кнопку на карточке («g<id>|<op>»). Возвращает текст всплывающей подсказки. */
export async function onDraftButton(q, chat, { store, tg, now }) {
  const g = D.parseData(q.data);
  const msgId = q.message?.message_id;
  const d0 = await store.draft(chat, g.id);
  if (!d0) {
    await tg('editMessageReplyMarkup', { chat_id: chat, message_id: msgId, reply_markup: { inline_keyboard: [] } }).catch(() => {});
    return 'Черновик устарел — перешли сообщение ещё раз';
  }
  const user = await store.user(chat);
  const ctx = await ctxOf(chat, user?.tz, store, now);
  const { d, act } = D.press({ ...d0, msg: msgId }, g.op, ctx);

  if (act === 'create') {
    const sent = await send(chat, d, store, now);
    await learn(chat, ctx, sent, store);
    await store.putDraft(chat, sent, now);
    await editCard(tg, chat, msgId, sent, ctx);
    return '📥 Отправил в Спутник';
  }
  if (act === 'split') {
    const items = D.split(d);
    for (const x of items) await store.addInbox(chat, { type: 'add', text: x.title, draft: payload(x), at: now });
    await learn(chat, ctx, d, store);
    await store.dropDraft(chat, d.id);
    const list = ctx.lists.find((l) => l.id === d.list);
    await tg('editMessageText', { chat_id: chat, message_id: msgId, parse_mode: 'HTML',
      text: `📥 <b>Записал задач: ${items.length}</b>${list ? ` · <i>${D.esc(list.title)}</i>` : ''}\n` + items.map((x) => '• ' + D.esc(x.title)).join('\n') + '\nПоявятся в Спутнике, когда он синхронизируется.' });
    return '';
  }
  if (act === 'cancel') {
    let text = `✕ Черновик убран: <s>${D.esc(d.title)}</s>`;
    if (d0.made === 'sent') {
      text = (await store.dropInbox(chat, d0.qid)) ? `🗑 Отменил: <s>${D.esc(d.title)}</s>` : 'Задача уже в Спутнике — удали её там.';
    }
    await store.dropDraft(chat, d.id);
    await tg('editMessageText', { chat_id: chat, message_id: msgId, text, parse_mode: 'HTML' });
    return '';
  }
  // Правка поля. Уже в очереди — меняем запись; трекер успел забрать — карточка без кнопок.
  let next = d;
  let note = '';
  if (d0.made === 'sent' && JSON.stringify(payload(d)) !== JSON.stringify(payload(d0)) && !(await store.updateInbox(chat, d0.qid, { type: 'add', text: d.title, draft: payload(d), did: d.id, at: now }))) {
    next = { ...d0, made: 'final', mode: '' };
    note = 'Задача уже в Спутнике — поправь её там';
  }
  if (next.listSet && next.list !== d0.list) await learn(chat, ctx, next, store);
  await store.putDraft(chat, next, now);
  await editCard(tg, chat, msgId, next, ctx);
  return note;
}

/** Трекер забрал записи из очереди: карточки этих задач → «✅ В Спутнике». */
export async function ackDrafts(chat, ids, { store, tg, now = Date.now() }) {
  const rows = (await store.inbox(chat)).filter((x) => ids.includes(x.id) && x.did);
  await store.ack(chat, ids);
  if (!rows.length) return;
  const user = await store.user(chat);
  const ctx = await ctxOf(chat, user?.tz, store, now);
  for (const x of rows) {
    const d = await store.draft(chat, x.did);
    if (!d || d.qid !== x.id || !d.msg) continue;
    const fin = { ...d, made: 'final', mode: '' };
    await store.putDraft(chat, fin, d.at);
    await editCard(tg, chat, d.msg, fin, ctx).catch(() => {});
  }
}

/** /ask on|off — свой текст сначала черновиком или сразу задачей. */
export async function askCommand(chat, arg, { store, tg }) {
  const meta = (await store.draftMeta(chat)) ?? {};
  const say = (text) => tg('sendMessage', { chat_id: chat, text, parse_mode: 'HTML' });
  if (/^(on|вкл|да)/i.test(arg)) { await store.setDraftMeta(chat, { ...meta, ask: true }); return say('📝 Теперь и свои сообщения сначала приходят черновиком — отправляешь кнопкой «✅ Создать». Сразу задачей — /ask off.'); }
  if (/^(off|выкл|нет)/i.test(arg)) { await store.setDraftMeta(chat, { ...meta, ask: false }); return say('⚡ Свои сообщения снова сразу уходят в Спутник, под ответом — кнопки, чтобы поправить. Черновиком — /ask on.'); }
  return say(meta.ask ? 'Сейчас свои сообщения приходят черновиком. Сразу задачей — /ask off.' : 'Сейчас свои сообщения сразу уходят в Спутник. Черновиком — /ask on.');
}
