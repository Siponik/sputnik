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
    // «Входящие от Claude» — файл Inbox.gs в этом же проекте.
    if (typeof inboxTick_ === 'function') {
      try { inboxTick_(); } catch (e) { console.error('Входящие: ' + e); }
    }
  } finally {
    lock.releaseLock();
  }
}

function remindersTick_() {
  const data = readFile_();
  if (!data) return;
  const props = PropertiesService.getScriptProperties();
  const sent = JSON.parse(props.getProperty('SENT') || '{}');
  const now = Date.now();
  let changed = false;

  for (const item of data.items || []) {
    const at = Date.parse(item.fireAt);
    if (!at || at > now || sent[item.key]) continue;
    // Если Telegram не ответил, не отмечаем — попробуем через минуту.
    if (now - at <= LATE_LIMIT_MS && stillOpen_(item)) {
      try { send_(format_(item)); } catch (e) { console.error(e); continue; }
    }
    sent[item.key] = now;
    changed = true;
  }

  for (const k of Object.keys(sent)) if (now - sent[k] > KEEP_SENT_MS) { delete sent[k]; changed = true; }
  if (changed) props.setProperty('SENT', JSON.stringify(sent));
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
    return t.status !== 'completed' && !t.deleted;
  } catch (e) {
    return false; // задачи больше нет
  }
}

function format_(item) {
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

function send_(text) {
  const props = PropertiesService.getScriptProperties();
  const token = props.getProperty('TELEGRAM_BOT_TOKEN');
  const chat = props.getProperty('TELEGRAM_CHAT_ID');
  if (!token || !chat) throw new Error('Добавь TELEGRAM_BOT_TOKEN и TELEGRAM_CHAT_ID в свойства скрипта');
  UrlFetchApp.fetch('https://api.telegram.org/bot' + token + '/sendMessage', {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({ chat_id: chat, text: text, parse_mode: 'HTML', disable_web_page_preview: true }),
  });
}
