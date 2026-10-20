// Спутник · задачи через Telegram-бота: добавить, посмотреть, отметить выполненной.
// Команды разбирает handle_() в Bot.gs, кнопки под сообщениями — onCallback_() здесь.
// Задачи живут в Google Tasks. Поля Спутника (тип, приоритет, время) бот кладёт в pendingLayer статуса
// «Входящих» (Inbox.gs) — трекер забирает их в свой слой, как и задачи из чатов Claude.
//
//   позвонить маме завтра 17:00     — просто текст: новая задача (вторая строка — заметка)
//   @работа  #work #asset #client #study #personal  !!! !! !   — список, тип, приоритет
//   /today            — на сегодня и просроченное
//   /tasks [список]   — все открытые задачи (или одного списка)
//   /done 3 | /done молоко — отметить выполненной (номер из последнего списка или часть названия)
//   /lists [список]   — списки; с названием — сделать список основным (туда идут задачи без @)
//   /week             — на 7 дней вперёд по дням (и просроченное)
//   /move 3 завтра | /move молоко в пятницу 17:00 — перенести срок (/move 3 без срока — убрать срок)

const HABITS_LIST = 'Привычки'; // привычки отмечают в трекере, в списках бота их нет
const SHOW_MAX = 30;
const TASK_MAP_MAX = 80;
const TZ = 'Europe/Moscow';
const MONTH_IDX = { янв: 0, фев: 1, мар: 2, апр: 3, мая: 4, май: 4, июн: 5, июл: 6, авг: 7, сен: 8, окт: 9, ноя: 10, дек: 11 };
// Теги — как в строке «Сегодня» трекера (латиницей; старые русские тоже понимаем).
const TASK_TAGS = {
  asset: { type: 'creative' }, work: { type: 'work' }, client: { type: 'work', tag: 'client' },
  study: { type: 'study' }, personal: { type: 'personal' },
};
const OLD_TASK_TAGS = { 'ассет': 'asset', 'работа': 'work', 'клиент': 'client', 'учёба': 'study', 'учеба': 'study', 'личное': 'personal' };
const PRIO_MARK = { 1: '!!!', 2: '!!', 3: '!' };
const WEEKDAY_NAMES = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];

// ---------- команды ----------

/** Просто текст → новая задача. */
function cmdAdd_(raw) {
  if (!raw.trim()) return 'Напиши задачу, например: <i>позвонить маме завтра 17:00</i>';
  const lists = taskLists_();
  const p = parseTask_(raw);
  let list = defaultList_(lists);
  if (p.listWord) {
    list = findListByWord_(lists, p.listWord);
    if (!list) return 'Не нашёл список «' + esc_(p.listWord) + '».\n\n' + listsLine_(lists);
  }
  if (!p.title) return 'Не понял, что за задача. Пример: <i>скетч таверны в пятницу #asset</i>';

  const body = { title: p.title };
  if (p.notes) body.notes = p.notes;
  if (p.day) body.due = p.day + 'T00:00:00.000Z';
  const t = Tasks.Tasks.insert(body, list.id);
  rememberTask_(t.id, list.id);

  const layer = {};
  if (p.kind) { layer.type = p.kind.type; if (p.kind.tag) layer.tags = [p.kind.tag]; }
  if (p.priority) layer.priority = p.priority;
  if (p.time) layer.slot = { s: p.time, e: plusHour_(p.time) };
  if (Object.keys(layer).length) queueLayer_(t.id, list.id, layer);

  const bits = [p.day ? humanDay_(p.day) : 'без срока'];
  if (p.time) bits[0] += ' ' + p.time;
  if (p.priority) bits.push(PRIO_MARK[p.priority]);
  if (p.kind) bits.push('#' + Object.keys(TASK_TAGS).find((k) => TASK_TAGS[k] === p.kind));
  return {
    text: '✅ <b>' + esc_(p.title) + '</b>\n' + bits.join(' · ') + ' · <i>' + esc_(list.title) + '</i>',
    markup: { inline_keyboard: [[{ text: 'Отменить', callback_data: 'x:' + t.id }]] },
  };
}

/** /today — сегодня и просроченное по всем спискам. */
function cmdToday_() {
  const today = todayYmd_();
  const items = [];
  for (const l of taskLists_()) {
    if (l.title === HABITS_LIST) continue;
    for (const t of topTasks_(l.id)) if (t.due && t.due.slice(0, 10) <= today) items.push({ t: t, list: l });
  }
  items.sort((a, b) => a.t.due.localeCompare(b.t.due) || (a.t.position || '').localeCompare(b.t.position || ''));
  if (!items.length) return '☀ На сегодня задач со сроком нет. Все открытые — /tasks';
  return showTasks_('<b>Сегодня</b>', items.map((x) => [x]), true);
}

/** /tasks [список] — открытые задачи, по спискам. */
function cmdTasks_(word) {
  const lists = taskLists_();
  let pick = lists.filter((l) => l.title !== HABITS_LIST);
  if (word) {
    const l = findListByWord_(lists, word);
    if (!l) return 'Не нашёл список «' + esc_(word) + '».\n\n' + listsLine_(lists);
    pick = [l];
  }
  const groups = [];
  for (const l of pick) {
    const ts = topTasks_(l.id);
    if (ts.length) groups.push(ts.map((t) => ({ t: t, list: l })));
  }
  if (!groups.length) return word ? 'В «' + esc_(pick[0].title) + '» открытых задач нет 🎉' : 'Открытых задач нет 🎉';
  return showTasks_(word ? '' : '<b>Открытые задачи</b>', groups, false);
}

/** /week — просроченное и 7 дней вперёд, по дням. */
function cmdWeek_() {
  const today = todayYmd_(), end = ymdAdd_(today, 6);
  const byDay = {};
  for (const l of taskLists_()) {
    if (l.title === HABITS_LIST) continue;
    for (const t of topTasks_(l.id)) {
      const d = t.due ? t.due.slice(0, 10) : '';
      if (!d || d > end) continue;
      const k = d < today ? 'over' : d;
      (byDay[k] = byDay[k] || []).push({ t: t, list: l });
    }
  }
  const groups = [];
  if (byDay.over) { byDay.over.head = '⚠ Просрочено'; groups.push(byDay.over); }
  for (let i = 0; i < 7; i++) {
    const d = ymdAdd_(today, i);
    if (!byDay[d]) continue;
    byDay[d].head = WEEKDAY_NAMES[ymdDow_(d)] + ', ' + humanDay_(d);
    groups.push(byDay[d]);
  }
  if (!groups.length) return '🌿 На неделю задач со сроком нет. Все открытые — /tasks';
  return showTasks_('<b>Неделя</b>', groups, true);
}

/** /move N когда | /move текст когда — перенести срок. Время («17:00») уходит в слой трекера. */
function cmdMove_(raw) {
  if (!raw) return 'Что и куда перенести? Пример: /move 2 завтра или /move молоко в пятницу';
  let found = null, rest = raw;
  const num = /^(\d+)\s+([\s\S]*)$/.exec(raw);
  if (num) {
    const shown = JSON.parse(PropertiesService.getScriptProperties().getProperty('TG_SHOWN') || '[]');
    const id = shown[+num[1] - 1];
    if (!id) return 'Номера ' + num[1] + ' нет в последнем списке. Пришли /today, /week или /tasks.';
    const listId = listOfTask_(id);
    if (!listId) return 'Эта задача уже удалена.';
    found = { t: Tasks.Tasks.get(listId, id), listId: listId };
    rest = num[2];
  }
  const clear = /(^|\s)без срока(\s|$)/i.test(rest);
  const w = parseWhen_(clear ? rest.replace(/без срока/i, ' ') : rest, todayYmd_());
  if (!w.day && w.time) w.day = todayYmd_(); // «/move 2 в 17:00» — сегодня
  if (!w.day && !clear) return 'Не понял, на когда. Пример: /move 2 завтра, /move 2 в пятницу 17:00, /move 2 без срока';
  if (!found) {
    const q = w.rest.toLowerCase();
    if (!q) return 'Какую задачу перенести? Напиши номер из списка или часть названия.';
    const hits = [];
    for (const l of taskLists_()) {
      if (l.title === HABITS_LIST) continue;
      for (const t of topTasks_(l.id)) if (t.title.toLowerCase().indexOf(q) >= 0) hits.push({ t: t, list: l, listId: l.id });
    }
    if (!hits.length) return 'Открытой задачи с «' + esc_(w.rest) + '» не нашёл.';
    if (hits.length > 1) return showTasks_('Нашёл несколько — пришли /move номер ' + esc_(clear ? 'без срока' : (w.time ? humanDay_(w.day) + ' ' + w.time : humanDay_(w.day))), hits.map((x) => [x]), true);
    found = hits[0];
  }
  Tasks.Tasks.patch({ due: clear ? null : w.day + 'T00:00:00.000Z' }, found.listId, found.t.id);
  rememberTask_(found.t.id, found.listId);
  if (w.time && !clear) queueLayer_(found.t.id, found.listId, { slot: { s: w.time, e: plusHour_(w.time) } });
  return '📅 <b>' + esc_(found.t.title) + '</b> → ' + (clear ? 'без срока' : humanDay_(w.day) + (w.time ? ' ' + w.time : ''));
}

/** Строки для утреннего сообщения: задачи на сегодня и просроченные (или '', если их нет или Google не ответил). */
function todayBrief_() {
  try {
    const today = todayYmd_();
    const items = [];
    for (const l of taskLists_()) {
      if (l.title === HABITS_LIST) continue;
      for (const t of topTasks_(l.id)) if (t.due && t.due.slice(0, 10) <= today) items.push(t);
    }
    if (!items.length) return '\n\n☀ Задач со сроком на сегодня нет.';
    items.sort((a, b) => a.due.localeCompare(b.due));
    const over = items.filter((t) => t.due.slice(0, 10) < today).length;
    const lines = items.slice(0, 5).map((t) => '• ' + (t.due.slice(0, 10) < today ? '⚠ ' : '') + esc_(t.title));
    if (items.length > 5) lines.push('…и ещё ' + (items.length - 5) + ' — /today');
    return '\n\n<b>Сегодня ' + items.length + ' ' + plural_(items.length, ['задача', 'задачи', 'задач']) + '</b>' + (over ? ' (просрочено ' + over + ')' : '') + '\n' + lines.join('\n');
  } catch (e) {
    console.error('Задачи для сводки: ' + e);
    return '';
  }
}

function plural_(n, f) {
  const a = n % 10, b = n % 100;
  return a === 1 && b !== 11 ? f[0] : a >= 2 && a <= 4 && (b < 12 || b > 14) ? f[1] : f[2];
}

// ---------- итог недели ----------
// По пятницам в REVIEW_AT (18:00 МСК) бот сам присылает итог; /review — в любой момент, /review off|on — выключить/включить.
const REVIEW_AT = 18 * 60;

/** Текст итога: сделано за 7 дней (по спискам), просрочено и что на следующей неделе. */
function cmdReview_(arg) {
  const props = PropertiesService.getScriptProperties();
  if (/^(off|выкл|нет)/i.test(arg || '')) { props.setProperty('REVIEW_OFF', '1'); return '⏸ Итог недели по пятницам выключен. Включить — /review on.'; }
  if (/^(on|вкл|да)/i.test(arg || '')) { props.deleteProperty('REVIEW_OFF'); return '▶ Итог недели будет приходить по пятницам в 18:00.'; }
  const today = todayYmd_(), weekAgo = ymdAdd_(today, -6), nextEnd = ymdAdd_(today, 7);
  const since = new Date(Date.now() - 7 * 864e5).toISOString();
  const done = [], over = [], ahead = [];
  for (const l of taskLists_()) {
    if (l.title === HABITS_LIST) continue;
    let page;
    do {
      const r = Tasks.Tasks.list(l.id, { maxResults: 100, showCompleted: true, showHidden: true, completedMin: since, pageToken: page });
      for (const t of r.items || []) if (t.status === 'completed' && !t.parent && t.title && !t.deleted) done.push({ t: t, list: l });
      page = r.nextPageToken;
    } while (page);
    for (const t of topTasks_(l.id)) {
      const d = t.due ? t.due.slice(0, 10) : '';
      if (d && d < today) over.push(t);
      else if (d && d > today && d <= nextEnd) ahead.push(t);
    }
  }
  const lines = ['🗓 <b>Итог недели</b> · ' + humanDay_(weekAgo) + ' — ' + humanDay_(today)];
  if (done.length) {
    const byList = {};
    for (const x of done) byList[x.list.title] = (byList[x.list.title] || 0) + 1;
    lines.push('', '✅ <b>Сделано: ' + done.length + '</b> · ' + Object.keys(byList).map((k) => esc_(k) + ' ' + byList[k]).join(', '));
    done.sort((a, b) => (b.t.completed || '').localeCompare(a.t.completed || ''));
    for (const x of done.slice(0, 8)) lines.push('• ' + esc_(x.t.title));
    if (done.length > 8) lines.push('…и ещё ' + (done.length - 8));
  } else lines.push('', 'За неделю выполненных задач нет — бывает. Енот верит в следующую 🦝');
  if (over.length) {
    lines.push('', '⚠ <b>Просрочено: ' + over.length + '</b> — перенести: /move номер когда');
    for (const t of over.slice(0, 5)) lines.push('• ' + esc_(t.title) + ' · ' + humanDay_(t.due.slice(0, 10)));
  }
  if (ahead.length) lines.push('', '➡ На следующей неделе со сроком: ' + ahead.length + '. По дням — /week');
  return lines.join('\n');
}

/** Раз в минуту из tick(): по пятницам после REVIEW_AT — итог недели, один раз в день. */
function reviewTick_() {
  const props = PropertiesService.getScriptProperties();
  if (props.getProperty('REVIEW_OFF') === '1') return;
  const now = new Date();
  if (Utilities.formatDate(now, TZ, 'u') !== '5') return;
  const min = +Utilities.formatDate(now, TZ, 'H') * 60 + +Utilities.formatDate(now, TZ, 'm');
  if (min < REVIEW_AT || min > REVIEW_AT + 180) return;
  const today = todayYmd_();
  if (props.getProperty('REVIEW_SENT') === today) return;
  props.setProperty('REVIEW_SENT', today); // до отправки: при сбое не повторяем каждую минуту
  send_(cmdReview_(''));
}

/** /done N | /done текст. */
function cmdDone_(arg) {
  if (!arg) {
    const r = cmdToday_();
    return typeof r === 'string' ? 'Что отметить? Напиши /done номер или часть названия.\n\n' + r : { text: r.text + '\n\nНажми номер, чтобы отметить.', markup: r.markup };
  }
  let found = [];
  if (/^\d+$/.test(arg)) {
    const shown = JSON.parse(PropertiesService.getScriptProperties().getProperty('TG_SHOWN') || '[]');
    const id = shown[+arg - 1];
    if (!id) return 'Номера ' + arg + ' нет в последнем списке. Пришли /today или /tasks.';
    const listId = listOfTask_(id);
    if (!listId) return 'Эта задача уже удалена.';
    const t = Tasks.Tasks.get(listId, id);
    if (t.status === 'completed') return 'Уже выполнена: <b>' + esc_(t.title) + '</b>';
    found = [{ t: t, listId: listId }];
  } else {
    const q = arg.toLowerCase();
    for (const l of taskLists_()) {
      if (l.title === HABITS_LIST) continue;
      for (const t of topTasks_(l.id)) if (t.title.toLowerCase().indexOf(q) >= 0) found.push({ t: t, list: l, listId: l.id });
    }
    if (!found.length) return 'Открытой задачи с «' + esc_(arg) + '» не нашёл.';
    if (found.length > 1) {
      const r = showTasks_('Нашёл несколько — какую отметить?', found.map((x) => [x]), true);
      return r;
    }
  }
  const x = found[0];
  Tasks.Tasks.patch({ status: 'completed' }, x.listId, x.t.id);
  rememberTask_(x.t.id, x.listId);
  return {
    text: '✔ Выполнено: <b>' + esc_(x.t.title) + '</b>',
    markup: { inline_keyboard: [[{ text: 'Вернуть', callback_data: 'r:' + x.t.id }]] },
  };
}

/** /lists — списки с числом открытых задач; /lists Работа — сделать основным. */
function cmdLists_(word) {
  const lists = taskLists_();
  if (word) {
    const l = findListByWord_(lists, word);
    if (!l) return 'Не нашёл список «' + esc_(word) + '».\n\n' + listsLine_(lists);
    PropertiesService.getScriptProperties().setProperty('TASKS_LIST', l.id);
    return '⭐ Теперь задачи без @списка идут в «' + esc_(l.title) + '».';
  }
  const def = defaultList_(lists);
  const lines = ['<b>Списки</b> · ⭐ основной (туда идут задачи без @)'];
  const kb = [];
  for (const l of lists) {
    if (l.title === HABITS_LIST) continue;
    const n = topTasks_(l.id).length;
    lines.push((l.id === def.id ? '⭐ ' : '• ') + esc_(l.title) + (n ? ' — ' + n : ''));
    if (l.id !== def.id) kb.push([{ text: '⭐ ' + l.title, callback_data: 'l:' + l.id }]);
  }
  lines.push('', 'Задачи списка — /tasks название. Сделать основным — кнопка ниже.');
  return { text: lines.join('\n'), markup: kb.length ? { inline_keyboard: kb.slice(0, 20) } : null };
}

/** Нумерованный список с кнопками «✓ N». groups — массивы { t, list }; flat — подписывать список у каждой задачи. */
function showTasks_(head, groups, flat) {
  const today = todayYmd_();
  const lines = head ? [head] : [];
  const ids = [];
  let more = 0;
  for (const g of groups) {
    // Заголовок группы: день (/week, g.head) или список (/tasks).
    if (g.head || !flat) lines.push((lines.length ? '\n' : '') + '<b>' + (g.head || esc_(g[0].list.title)) + '</b>');
    for (const x of g) {
      if (ids.length >= SHOW_MAX) { more++; continue; }
      ids.push(x.t.id);
      rememberTask_(x.t.id, x.list.id);
      const due = x.t.due ? x.t.due.slice(0, 10) : '';
      let line = ids.length + '. ' + esc_(x.t.title);
      if (due && !g.head) line += ' · ' + (due < today ? '⚠ ' : '') + humanDay_(due);
      else if (due && due < today) line += ' · ' + humanDay_(due);
      if (flat) line += ' · <i>' + esc_(x.list.title) + '</i>';
      lines.push(line);
    }
  }
  if (more) lines.push('…и ещё ' + more + '. Список целиком — /tasks название');
  PropertiesService.getScriptProperties().setProperty('TG_SHOWN', JSON.stringify(ids));
  const kb = [];
  ids.forEach((id, i) => {
    if (i % 5 === 0) kb.push([]);
    kb[kb.length - 1].push({ text: '✓ ' + (i + 1), callback_data: 'd:' + id });
  });
  return { text: lines.join('\n'), markup: { inline_keyboard: kb } };
}

// ---------- кнопки ----------

function onCallback_(q) {
  const data = String(q.data || '');
  const op = data.slice(0, 1), id = data.slice(2);
  const msg = q.message;
  let note = '';
  try {
    if (op === 'd' || op === 'u') {
      // «✓ N» в списке: отметить; повторное нажатие на «✅ N» — вернуть.
      const listId = listOfTask_(id);
      if (!listId) note = 'Задача уже удалена';
      else {
        Tasks.Tasks.patch({ status: op === 'd' ? 'completed' : 'needsAction' }, listId, id);
        note = op === 'd' ? 'Выполнено ✔' : 'Вернул в работу';
        const kb = msg.reply_markup.inline_keyboard.map((row) => row.map((b) => {
          if (b.callback_data !== data) return b;
          const rest = b.text.replace(/^\S+\s*/, '');
          return op === 'd' ? { text: '✅ ' + rest, callback_data: 'u:' + id } : { text: '✓ ' + rest, callback_data: 'd:' + id };
        }));
        tg_('editMessageReplyMarkup', { chat_id: msg.chat.id, message_id: msg.message_id, reply_markup: { inline_keyboard: kb } });
      }
    } else if (op === 'x' || op === 'r') {
      // «Отменить» после добавления — удалить задачу; «Вернуть» после /done — снова открыть.
      const listId = listOfTask_(id);
      let text;
      if (!listId) text = 'Задачи уже нет.';
      else if (op === 'x') {
        const t = Tasks.Tasks.get(listId, id);
        Tasks.Tasks.remove(listId, id);
        text = '🗑 Отменил: <s>' + esc_(t.title) + '</s>';
      } else {
        const t = Tasks.Tasks.patch({ status: 'needsAction' }, listId, id);
        text = '↩ Вернул в работу: <b>' + esc_(t.title) + '</b>';
      }
      tg_('editMessageText', { chat_id: msg.chat.id, message_id: msg.message_id, text: text, parse_mode: 'HTML' });
    } else if (op === 'l') {
      const l = taskLists_().find((x) => x.id === id);
      if (!l) note = 'Такого списка уже нет';
      else {
        PropertiesService.getScriptProperties().setProperty('TASKS_LIST', l.id);
        note = 'Основной список: ' + l.title;
        const r = cmdLists_('');
        tg_('editMessageText', { chat_id: msg.chat.id, message_id: msg.message_id, text: r.text, parse_mode: 'HTML', reply_markup: r.markup || { inline_keyboard: [] } });
      }
    }
  } catch (e) {
    note = 'Не получилось: ' + (e.message || e);
    console.error('Кнопка ' + data + ': ' + e);
  }
  tg_('answerCallbackQuery', { callback_query_id: q.id, text: note.slice(0, 190) });
}

// ---------- разбор текста задачи ----------

/** «скетч таверны в пятницу 17:00 #asset !! @работа\nзаметка» → { title, notes, day, time, kind, priority, listWord } */
function parseTask_(raw) {
  const nl = raw.indexOf('\n');
  const notes = nl >= 0 ? raw.slice(nl + 1).trim() : '';
  let txt = ' ' + (nl >= 0 ? raw.slice(0, nl) : raw) + ' ';
  let listWord = null, priority = null, kind = null;
  const lm = txt.match(/\s@(\S+)/);
  if (lm) { listWord = lm[1]; txt = txt.replace(lm[0], ' '); }
  const pm = txt.match(/\s(!{1,3})(?=\s)/);
  if (pm) { priority = 4 - pm[1].length; txt = txt.replace(pm[0], ' '); }
  const tg = txt.match(/#([^\s#]+)/);
  if (tg) {
    const k = tg[1].toLowerCase();
    kind = TASK_TAGS[OLD_TASK_TAGS[k] || k] || null;
    if (kind) txt = txt.replace(tg[0], ' ');
  }
  const w = parseWhen_(txt, todayYmd_());
  const title = w.rest ? w.rest[0].toUpperCase() + w.rest.slice(1) : '';
  return { title: title.slice(0, 250), notes: notes.slice(0, 4000), day: w.day, time: w.time, kind: kind, priority: priority, listWord: listWord };
}

/** Тот же разбор, что tracker/src/lib/when.js → parseWhen, только даты — строки ГГГГ-ММ-ДД по Москве. */
function parseWhen_(text, base) {
  let t = ' ' + String(text || '').replace(/\s+/g, ' ') + ' ';
  let day = null, time = null, allDay = false;
  const take = (re, fn) => { const m = t.match(re); if (m) { fn(m); t = t.replace(m[0], ' '); return true; } return false; };
  const hm = (h, m) => String(+h).padStart(2, '0') + ':' + m;

  take(/\s(весь день)(?=\s)/i, () => (allDay = true));
  take(/\s(?:в\s)?([01]?\d|2[0-3]):([0-5]\d)(?=\s|[,.!?]\s)/, (m) => (time = hm(m[1], m[2])))
    || take(/\s(?:в\s)?([6-9]|0[6-9]|1\d|2[0-3])\.([0-5][05])(?=\s|[,!?]\s)/, (m) => (time = hm(m[1], m[2])))
    || take(/\sв\s([01]?\d|2[0-3])(?=\s)(?!\s*(?:янв|фев|мар|апр|ма|июн|июл|авг|сен|окт|ноя|дек))/i, (m) => (time = hm(m[1], '00')));

  take(/\s(послезавтра)(?=\s|[,.!?])/i, () => (day = ymdAdd_(base, 2)))
    || take(/\s(завтра)(?=\s|[,.!?])/i, () => (day = ymdAdd_(base, 1)))
    || take(/\s(сегодня)(?=\s|[,.!?])/i, () => (day = base))
    || take(/\sчерез\s(\d{1,3}|неделю|день)\s?(дн[еяй]+|день|недел[июь]+)?(?=\s|[,.!?])/i, (m) => {
      const n = m[1] === 'неделю' ? 7 : m[1] === 'день' ? 1 : Number(m[1]) * (/недел/i.test(m[2] || '') ? 7 : 1);
      day = ymdAdd_(base, n);
    })
    || take(/\s(\d{1,2})\s(янв|фев|мар|апр|мая|май|июн|июл|авг|сен|окт|ноя|дек)[а-я]*\.?(?=\s|[,!?])/i, (m) => {
      day = nearestYmd_(base, MONTH_IDX[m[2].toLowerCase().slice(0, 3)], +m[1]);
    })
    || take(/\s(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?(?=\s|[,!?])/, (m) => {
      if (m[3]) day = ymdMake_(+(m[3].length === 2 ? '20' + m[3] : m[3]), +m[2] - 1, +m[1]);
      else day = nearestYmd_(base, +m[2] - 1, +m[1]);
    })
    || take(/(?:^|\s)(?:(?:в|во)\s+)?(понедельник|вторник|сред[ау]|четверг|пятниц[ау]|суббот[ау]|воскресенье|пн|вт|ср|чт|пт|сб|вс)(?=\s|$|[,.!?])/i, (m) => {
      const w = m[1].toLowerCase();
      const i = [/^(понедельник|пн)$/, /^(вторник|вт)$/, /^(сред[ау]|ср)$/, /^(четверг|чт)$/, /^(пятниц[ау]|пт)$/, /^(суббот[ау]|сб)$/, /^(воскресенье|вс)$/]
        .findIndex((re) => re.test(w));
      day = ymdAdd_(base, ((i - ymdDow_(base) + 7) % 7) || 7);
    });

  if (allDay) time = null;
  return { day: day, time: time, rest: t.replace(/\s+/g, ' ').trim() };
}

// ---------- даты: строки ГГГГ-ММ-ДД, считаем в UTC, чтобы не зависеть от часового пояса ----------

function todayYmd_() { return Utilities.formatDate(new Date(), TZ, 'yyyy-MM-dd'); }
function ymdParts_(s) { const p = s.split('-').map(Number); return new Date(Date.UTC(p[0], p[1] - 1, p[2])); }
function ymdAdd_(s, n) { const d = ymdParts_(s); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); }
function ymdDow_(s) { return (ymdParts_(s).getUTCDay() + 6) % 7; } // пн = 0
function ymdMake_(y, m, d) {
  const x = new Date(Date.UTC(y, m, d));
  return x.getUTCMonth() === m && x.getUTCDate() === d ? x.toISOString().slice(0, 10) : null;
}
/** «25 окт» без года — ближайшее такое число: в этом году или, если прошло, в следующем. */
function nearestYmd_(base, m, d) {
  const y = +base.slice(0, 4);
  const a = ymdMake_(y, m, d);
  return a && a < base ? ymdMake_(y + 1, m, d) : a;
}
function plusHour_(hm) {
  const p = hm.split(':').map(Number);
  const t = Math.min(p[0] * 60 + p[1] + 60, 23 * 60 + 59);
  return String(Math.floor(t / 60)).padStart(2, '0') + ':' + String(t % 60).padStart(2, '0');
}
/** «сегодня», «завтра», «вчера» или «25 окт.» */
function humanDay_(s) {
  const today = todayYmd_();
  if (s === today) return 'сегодня';
  if (s === ymdAdd_(today, 1)) return 'завтра';
  if (s === ymdAdd_(today, -1)) return 'вчера';
  const p = s.split('-').map(Number);
  return p[2] + ' ' + MONTHS[p[1] - 1] + (p[0] !== +today.slice(0, 4) ? ' ' + p[0] : '');
}

// ---------- списки и задачи ----------

function taskLists_() { return Tasks.Tasklists.list({ maxResults: 100 }).items || []; }

/** Открытые задачи верхнего уровня, по порядку списка. */
function topTasks_(listId) {
  return openTasks_(listId).filter((t) => !t.parent && t.title).sort((a, b) => (a.position || '').localeCompare(b.position || ''));
}

/** Основной список: выбранный в /lists или первый, кроме «Привычек». */
function defaultList_(lists) {
  const id = PropertiesService.getScriptProperties().getProperty('TASKS_LIST');
  return lists.find((l) => l.id === id) || lists.find((l) => l.title !== HABITS_LIST) || lists[0];
}

/** «@раб» → «Работа», «@3d» → «3D-ассеты»: точное совпадение, начало названия, часть названия. */
function findListByWord_(lists, word) {
  const norm = (s) => s.toLowerCase().replace(/ё/g, 'е').replace(/[\s\-_·.]+/g, '');
  const w = norm(word);
  if (!w) return null;
  return lists.find((l) => norm(l.title) === w) || lists.find((l) => norm(l.title).indexOf(w) === 0)
    || lists.find((l) => norm(l.title).indexOf(w) >= 0) || null;
}

function listsLine_(lists) {
  return 'Списки: ' + lists.filter((l) => l.title !== HABITS_LIST).map((l) => esc_(l.title)).join(', ');
}

/** taskId → listId: кнопкам хватает id задачи (в callback_data влезает только 64 байта). */
function rememberTask_(taskId, listId) {
  const props = PropertiesService.getScriptProperties();
  const map = JSON.parse(props.getProperty('TG_TASKMAP') || '{}');
  delete map[taskId];
  map[taskId] = listId;
  const keys = Object.keys(map);
  for (const k of keys.slice(0, Math.max(0, keys.length - TASK_MAP_MAX))) delete map[k];
  props.setProperty('TG_TASKMAP', JSON.stringify(map));
}

function listOfTask_(taskId) {
  const map = JSON.parse(PropertiesService.getScriptProperties().getProperty('TG_TASKMAP') || '{}');
  const ok = (listId) => { try { return !Tasks.Tasks.get(listId, taskId).deleted; } catch (e) { return false; } };
  if (map[taskId] && ok(map[taskId])) return map[taskId];
  for (const l of taskLists_()) if (ok(l.id)) { rememberTask_(taskId, l.id); return l.id; }
  return null;
}

/** Тип, приоритет и время задачи — в pendingLayer статуса «Входящих»; трекер перенесёт их в свой слой. */
function queueLayer_(taskId, listId, layer) {
  try {
    const status = readStatus_();
    status.pendingLayer[taskId] = Object.assign({ listId: listId, at: new Date().toISOString() }, layer);
    writeStatus_(status);
  } catch (e) {
    console.error('pendingLayer: ' + e); // задача уже создана — без типа и времени, но не теряется
  }
}
