// Спутник · напоминания в Telegram.
// Живёт в Google Apps Script в аккаунте пользователя и раз в минуту:
//   1) читает с Google Drive файл sputnik-reminders.json (его пишет трекер);
//   2) для напоминаний, время которых пришло, проверяет, что задача ещё не выполнена;
//   3) шлёт сообщение боту и запоминает, что отправил.
// Настройка — в reminders/README.md.

const FILE_NAME = 'sputnik-reminders.json';
const LATE_LIMIT_MS = 12 * 3600 * 1000; // опоздавшее больше чем на 12 ч не шлём
const KEEP_SENT_MS = 3 * 24 * 3600 * 1000;
const MONTHS = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];

/** Запустить один раз: включает проверку каждую минуту и шлёт пробное сообщение. */
function setup() {
  ScriptApp.getProjectTriggers().forEach((t) => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('tick').timeBased().everyMinutes(1).create();
  send_('🛰 Спутник: напоминания подключены. Сюда будут приходить напоминания о задачах.');
}

/** Выключить напоминания. */
function stop() {
  ScriptApp.getProjectTriggers().forEach((t) => ScriptApp.deleteTrigger(t));
}

function tick() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(0)) return; // прошлый запуск ещё идёт
  try {
    try { remindersTick_(); } catch (e) { console.error('Напоминания: ' + e); }
    try { morningTick_(); } catch (e) { console.error('Утренняя сводка: ' + e); }
    // Итог недели по пятницам — BotTasks.gs.
    if (typeof reviewTick_ === 'function') {
      try { reviewTick_(); } catch (e) { console.error('Итог недели: ' + e); }
    }
    // «Входящие от Claude» — файл Inbox.gs в этом же проекте.
    if (typeof inboxTick_ === 'function') {
      try { inboxTick_(); } catch (e) { console.error('Входящие: ' + e); }
    }
    // Команды боту (/time, /off …) — файл Bot.gs в этом же проекте.
    if (typeof botTick_ === 'function') {
      try { botTick_(); } catch (e) { console.error('Бот: ' + e); }
    }
  } finally {
    lock.releaseLock();
  }
}

function remindersTick_() {
  const data = readFile_();
  const props = PropertiesService.getScriptProperties();
  const snoozed = JSON.parse(props.getProperty('SNOOZED') || '[]'); // «⏰ Через час» под напоминанием
  const botRem = JSON.parse(props.getProperty('BOT_REM') || '[]'); // задачи из бота, пока трекер их не видел (BotTasks.gs)
  if (!data && !snoozed.length && !botRem.length) return;
  const sent = JSON.parse(props.getProperty('SENT') || '{}');
  const now = Date.now();
  let changed = false;

  for (const item of ((data && data.items) || []).concat(snoozed, botRem)) {
    const at = Date.parse(item.fireAt);
    if (!at || at > now || sent[item.key]) continue;
    // Если Telegram не ответил, не отмечаем — попробуем через минуту.
    // События и дни рождения выполненными не бывают — проверяем только задачи.
    // Привычки тоже: отмеченную трекер просто убирает из файла. 'test' — «Проверить» в настройках трекера.
    const isEvent = item.kind === 'event' || item.kind === 'birthday' || item.kind === 'habit' || item.kind === 'test';
    if (now - at <= LATE_LIMIT_MS && (isEvent || stillOpen_(item))) {
      try { send_(format_(item), remindButtons_(item)); } catch (e) { console.error(e); continue; }
    }
    sent[item.key] = now;
    changed = true;
  }

  for (const k of Object.keys(sent)) if (now - sent[k] > KEEP_SENT_MS) { delete sent[k]; changed = true; }
  if (changed) props.setProperty('SENT', JSON.stringify(sent));
  const left = snoozed.filter((x) => !sent[x.key]);
  if (left.length !== snoozed.length) props.setProperty('SNOOZED', JSON.stringify(left));
  const botLeft = botRem.filter((x) => !sent[x.key] && now - Date.parse(x.fireAt) <= LATE_LIMIT_MS);
  if (botLeft.length !== botRem.length) props.setProperty('BOT_REM', JSON.stringify(botLeft));
}

// ── Кнопки под напоминанием: «✓ Готово» (задача) и «⏰ Через час» ──
// Кнопке хватает короткого номера: само напоминание лежит в свойстве REM_LAST (последние REM_KEEP).
const REM_KEEP = 40;
const SNOOZE_MIN = 60;

function remindButtons_(item) {
  if (item.kind === 'milestone' || item.kind === 'test') return null;
  const props = PropertiesService.getScriptProperties();
  const seq = +(props.getProperty('REM_SEQ') || 0) + 1;
  props.setProperty('REM_SEQ', String(seq));
  const last = JSON.parse(props.getProperty('REM_LAST') || '{}');
  last[seq] = item;
  const ids = Object.keys(last).map(Number).sort((a, b) => a - b);
  for (const k of ids.slice(0, Math.max(0, ids.length - REM_KEEP))) delete last[k];
  props.setProperty('REM_LAST', JSON.stringify(last));
  const row = [];
  if (item.taskId && item.listId) {
    if (typeof rememberTask_ === 'function') rememberTask_(item.taskId, item.listId); // для кнопки ✓ (BotTasks.gs)
    row.push({ text: '✓ Готово', callback_data: 'd:' + item.taskId });
  }
  row.push({ text: '⏰ Через час', callback_data: 'z:' + seq });
  return { inline_keyboard: [row] };
}

/** «⏰ Через час»: напоминание n повторится через SNOOZE_MIN минут. Возвращает подпись для кнопки или null. */
function snoozeRemind_(n) {
  const props = PropertiesService.getScriptProperties();
  const item = JSON.parse(props.getProperty('REM_LAST') || '{}')[n];
  if (!item) return null;
  const at = new Date(Date.now() + SNOOZE_MIN * 60e3);
  const snoozed = JSON.parse(props.getProperty('SNOOZED') || '[]').filter((x) => x.from !== n);
  snoozed.push(Object.assign({}, item, { key: 'snooze|' + n + '|' + at.getTime(), fireAt: at.toISOString(), from: n }));
  props.setProperty('SNOOZED', JSON.stringify(snoozed.slice(-REM_KEEP)));
  return Utilities.formatDate(at, 'Europe/Moscow', 'H:mm');
}

function readFile_() {
  const files = DriveApp.getFilesByName(FILE_NAME);
  let newest = null;
  while (files.hasNext()) {
    const f = files.next();
    if (f.isTrashed()) continue;
    if (!newest || f.getLastUpdated() > newest.getLastUpdated()) newest = f;
  }
  return newest ? JSON.parse(newest.getBlob().getDataAsString()) : null;
}

/** Задачу могли выполнить или удалить на телефоне, пока трекер был закрыт. */
function stillOpen_(item) {
  try {
    const t = Tasks.Tasks.get(item.listId, item.taskId);
    // Напоминание из бота привязано к сроку: срок перенесли — старое не шлём (трекер посчитает новое).
    if (item.bot && String(t.due || '').slice(0, 10) !== item.due) return false;
    return t.status !== 'completed' && !t.deleted;
  } catch (e) {
    return false; // задачи больше нет
  }
}

function format_(item) {
  if (item.kind === 'birthday') {
    const p = item.due.split('-').map(Number);
    return '🎂 <b>' + esc_(item.title) + '</b>\nДень рождения ' + p[2] + ' ' + MONTHS[p[1] - 1] + (item.lead ? ' · <i>' + esc_(item.lead.toLowerCase()) + '</i>' : '');
  }
  if (item.kind === 'event') {
    const when = item.start
      ? Utilities.formatDate(new Date(item.start), 'Europe/Moscow', 'd') + ' ' + MONTHS[+Utilities.formatDate(new Date(item.start), 'Europe/Moscow', 'M') - 1] + ', ' + Utilities.formatDate(new Date(item.start), 'Europe/Moscow', 'H:mm')
      : (() => { const p = item.due.split('-').map(Number); return p[2] + ' ' + MONTHS[p[1] - 1] + ', весь день'; })();
    const ev = ['📅 <b>' + esc_(item.title) + '</b>', when];
    if (item.note) ev.push(esc_(item.note));
    return ev.join('\n');
  }
  if (item.kind === 'habit') {
    return '⏰ <b>' + esc_(item.title) + '</b>\nПривычка · ' + Utilities.formatDate(new Date(item.fireAt), 'Europe/Moscow', 'H:mm');
  }
  // Веха серии привычки (трекер кладёт её с kind: 'milestone') — без колокольчика, эмодзи уже в заголовке.
  const lines = [(item.kind === 'milestone' ? '' : '🔔 ') + '<b>' + esc_(item.title) + '</b>'];
  if (item.due) {
    const p = item.due.split('-').map(Number);
    lines.push('Срок: ' + p[2] + ' ' + MONTHS[p[1] - 1]);
  }
  if (item.note) lines.push(esc_(item.note));
  lines.push('<i>' + esc_(item.list) + '</i>');
  return lines.join('\n');
}

function esc_(s) {
  return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// ── Утренняя сводка: ссылка в Telegram (по умолчанию по будням в 08:00 МСК) ──
// tick() идёт раз в минуту. Время, дни и паузу меняют командами боту (Bot.gs): свойства BRIEF_AT, BRIEF_DAYS, BRIEF_OFF.
// Синхронизация со сборкой: задача Claude «Утренняя сводка» собирает страницу заранее (по будням в 5:45 МСК)
// и, опубликовав её, ставит в календарь «Спутник · входящие» событие «Спутник · сводка готова» на сегодня.
// Ссылка уходит в выбранное время, но не раньше этой отметки; если отметки нет — ждём до BRIEF_WAIT_MIN
// после выбранного времени и шлём с пометкой, что по ссылке прошлая сводка.
const BRIEF_URL_DEFAULT = 'https://claude.ai/artifact/Mftfm4G7jmnrQZhnVJw728';
const BRIEF_AT_DEFAULT = 8 * 60; // минуты от полуночи по Москве
const BRIEF_READY_TITLE = 'Спутник · сводка готова';
const BRIEF_WAIT_MIN = 180;

/** Время отправки в минутах от полуночи по Москве. */
function briefAt_() {
  const v = PropertiesService.getScriptProperties().getProperty('BRIEF_AT');
  return v === null || isNaN(+v) ? BRIEF_AT_DEFAULT : +v;
}

/** 'work' — по будням, 'all' — каждый день. */
function briefDays_() {
  return PropertiesService.getScriptProperties().getProperty('BRIEF_DAYS') === 'all' ? 'all' : 'work';
}

/** Есть ли сегодня отметка «сводка готова». Старые отметки заодно удаляет. */
function briefReady_() {
  const cal = typeof inboxCalendar_ === 'function' ? inboxCalendar_(false) : null;
  if (!cal) return null; // календаря нет — синхронизация не работает, шлём по времени
  const now = new Date(), tz = 'Europe/Moscow';
  const today = Utilities.formatDate(now, tz, 'yyyy-MM-dd');
  let ready = false;
  for (const ev of cal.getEvents(new Date(now.getTime() - 7 * 864e5), new Date(now.getTime() + 864e5))) {
    if (ev.getTitle().indexOf(BRIEF_READY_TITLE) !== 0) continue;
    if (Utilities.formatDate(ev.getStartTime(), tz, 'yyyy-MM-dd') === today) ready = true;
    else ev.deleteEvent();
  }
  return ready;
}

function morningTick_() {
  const tz = 'Europe/Moscow', now = new Date();
  const props = PropertiesService.getScriptProperties();
  if (props.getProperty('BRIEF_OFF') === '1') return;
  const dow = +Utilities.formatDate(now, tz, 'u'); // 1 = пн … 7 = вс
  if (dow > 5 && briefDays_() === 'work') return;
  const min = +Utilities.formatDate(now, tz, 'H') * 60 + +Utilities.formatDate(now, tz, 'm');
  const at = briefAt_();
  if (min < at || min > at + BRIEF_WAIT_MIN) return;
  const today = Utilities.formatDate(now, tz, 'yyyy-MM-dd');
  if (props.getProperty('BRIEF_SENT') === today) return;
  const ready = briefReady_();
  // Свежей сводки ещё нет — ждём; в выходные (сводку не собирают) и по истечении ожидания шлём как есть.
  if (ready === false && dow <= 5 && min < at + BRIEF_WAIT_MIN) return;
  sendBrief_((ready === false ? '\n<i>Свежая сводка сегодня не собралась — по ссылке прошлая.</i>' : '') + (typeof todayBrief_ === 'function' ? todayBrief_() : ''));
  props.setProperty('BRIEF_SENT', today);
}

/** Отправить ссылку на сводку прямо сейчас (для проверки). */
function sendBrief_(note) {
  const url = PropertiesService.getScriptProperties().getProperty('BRIEF_URL') || BRIEF_URL_DEFAULT;
  send_('🛰 Спутник · утренняя сводка готова' + (note || ''), { inline_keyboard: [[{ text: 'Открыть сводку', url: url }]] });
}

/** Запустить вручную из редактора: пришлёт сводку сейчас — проверка, что всё работает. */
function testBrief() { sendBrief_(); }

function send_(text, markup) {
  const props = PropertiesService.getScriptProperties();
  const token = props.getProperty('TELEGRAM_BOT_TOKEN');
  const chat = props.getProperty('TELEGRAM_CHAT_ID');
  if (!token || !chat) throw new Error('Добавь TELEGRAM_BOT_TOKEN и TELEGRAM_CHAT_ID в свойства скрипта');
  const post = (body) => UrlFetchApp.fetch('https://api.telegram.org/bot' + token + '/sendMessage', {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(Object.assign({ chat_id: chat, disable_web_page_preview: true }, body, markup ? { reply_markup: markup } : {})),
    muteHttpExceptions: true,
  });
  let r = post({ text: text, parse_mode: 'HTML' });
  // Telegram не разобрал разметку (например, «<» в названии задачи) — шлём тем же текстом без тегов,
  // иначе напоминание повторялось бы каждую минуту и так и не дошло.
  if (r.getResponseCode() === 400 && /can't parse entities/i.test(r.getContentText())) {
    r = post({ text: text.replace(/<[^>]+>/g, '').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&') });
  }
  if (r.getResponseCode() !== 200) throw new Error('Telegram ' + r.getResponseCode() + ': ' + r.getContentText());
}
