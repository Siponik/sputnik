// Спутник · команды боту в Telegram: задачи (BotTasks.gs) и время утренней сводки.
// Без вебхука: tick() в Code.gs раз в минуту забирает новые сообщения (getUpdates),
// поэтому ответ приходит в течение минуты. Слушаем только свой чат (TELEGRAM_CHAT_ID).
//
// Команды:
//   текст          — новая задача; /today, /tasks, /done, /lists — см. BotTasks.gs
//   /time          — когда приходит сводка
//   /time 7:30     — поставить время (можно и просто прислать «7:30»)
//   /days будни    — только по будням; /days все — каждый день
//   /off, /on      — поставить сводку на паузу и включить снова
//   /now           — прислать ссылку на сводку сейчас
//   /help          — список команд

const BOT_VERSION = '2'; // поменять, когда меняется меню команд: бот обновит его и расскажет, что нового
const BRIEF_READY_AT = 6 * 60; // сводка обычно готова к 6:00 МСК (задача Claude «Утренняя сводка» стартует в 5:45)

/** Запустить один раз: включает меню команд в Telegram и шлёт пробное сообщение. */
function setupBot() {
  tg_('deleteWebhook', {}); // getUpdates не работает, пока у бота есть вебхук
  tg_('setMyCommands', {
    commands: [
      { command: 'today', description: 'Задачи на сегодня' },
      { command: 'tasks', description: 'Все открытые задачи: /tasks Работа' },
      { command: 'done', description: 'Отметить: /done 3 или /done молоко' },
      { command: 'lists', description: 'Списки и основной список' },
      { command: 'time', description: 'Время сводки: /time 7:30' },
      { command: 'days', description: 'По будням или каждый день' },
      { command: 'off', description: 'Пауза сводки' },
      { command: 'on', description: 'Включить сводку' },
      { command: 'now', description: 'Прислать сводку сейчас' },
      { command: 'help', description: 'Что я умею' },
    ],
  });
  send_('🛰 Спутник: теперь через меня можно вести задачи.\n\n' + HELP_ + '\n\n' + statusText_());
}

const HELP_ = [
  '<b>Задачи</b>',
  'Просто напиши — добавлю задачу: <i>позвонить маме завтра 17:00</i>',
  'Можно дописать @список, #work #asset #client #study #personal, приоритет !!! / !! / !, а со второй строки — заметку.',
  '/today — на сегодня и просроченное',
  '/tasks — все открытые, /tasks работа — одного списка',
  '/done 3 или /done молоко — отметить (в списках есть кнопки ✓)',
  '/lists — списки и основной',
  '',
  '<b>Сводка</b>',
  '/time 7:30 — поменять время (или просто пришли «7:30»)',
  '/days будни или /days все',
  '/off — пауза, /on — включить',
  '/now — прислать сводку сейчас',
].join('\n');

function botTick_() {
  const props = PropertiesService.getScriptProperties();
  // Скрипт обновляется сам из GitHub — меню команд включаем при первом запуске новой версии.
  if (props.getProperty('BOT_READY') !== BOT_VERSION) {
    props.setProperty('BOT_READY', BOT_VERSION);
    setupBot();
  }
  const offset = +(props.getProperty('TG_OFFSET') || 0);
  const res = tg_('getUpdates', { offset: offset, timeout: 0, allowed_updates: ['message', 'callback_query'] });
  if (!res || !res.ok || !res.result.length) return;
  const chat = String(props.getProperty('TELEGRAM_CHAT_ID'));
  let last = offset;
  for (const u of res.result) {
    last = u.update_id + 1;
    // Сразу запоминаем: если команда упадёт, она не будет повторяться каждую минуту.
    props.setProperty('TG_OFFSET', String(last));
    if (u.callback_query) { // нажали кнопку под сообщением
      const q = u.callback_query;
      if (q.message && String(q.message.chat.id) === chat) onCallback_(q);
      continue;
    }
    const m = u.message;
    if (!m || !m.text || String(m.chat.id) !== chat) continue; // чужие чаты молча пропускаем
    try {
      const r = handle_(m.text.trim());
      if (typeof r === 'string') send_(r); else send_(r.text, r.markup);
    } catch (e) {
      console.error('Команда «' + m.text + '»: ' + e);
      try { send_('⚠ Не получилось: ' + esc_(e.message || e)); } catch (e2) { /* Telegram недоступен */ }
    }
  }
}

/** Разбирает сообщение и возвращает ответ: строку или { text, markup }. */
function handle_(text) {
  const props = PropertiesService.getScriptProperties();
  text = text.replace(/^(\/\S+?)@\w+/, '$1'); // «/time@SputnikBot 7:30» из меню в группе
  // Просто время без команды: «7:30», «07.30», «8»
  if (/^\d{1,2}([:.]\d{2})?$/.test(text)) text = '/time ' + text;
  // Просто текст — новая задача.
  if (text[0] !== '/') return cmdAdd_(text);
  const sp = text.search(/\s/);
  let cmd = (sp < 0 ? text : text.slice(0, sp)).toLowerCase();
  const raw = sp < 0 ? '' : text.slice(sp + 1).trim(); // с регистром и переносами строк — для задач
  const arg = raw.toLowerCase();
  const alias = {
    '/время': '/time', '/дни': '/days', '/пауза': '/off', '/вкл': '/on', '/сейчас': '/now', '/start': '/help', '/помощь': '/help',
    '/задача': '/add', '/добавь': '/add', '/сегодня': '/today', '/задачи': '/tasks', '/список': '/tasks',
    '/готово': '/done', '/сделано': '/done', '/списки': '/lists',
  };
  cmd = alias[cmd] || cmd;

  if (cmd === '/add') return cmdAdd_(raw);
  if (cmd === '/today') return cmdToday_();
  if (cmd === '/tasks') return cmdTasks_(raw);
  if (cmd === '/done') return cmdDone_(raw);
  if (cmd === '/lists') return cmdLists_(raw);

  if (cmd === '/time') {
    if (!arg) return statusText_();
    const t = parseTime_(arg);
    if (t === null) return 'Не понял время. Пример: /time 7:30';
    props.setProperty('BRIEF_AT', String(t));
    props.deleteProperty('BRIEF_OFF');
    let msg = '✅ Сводка будет приходить в ' + hhmm_(t) + ' (' + daysText_() + ').';
    if (t < BRIEF_READY_AT) msg += '\nСводка собирается около 6:00 — если к ' + hhmm_(t) + ' она не будет готова, пришлю, как только соберётся.';
    return msg;
  }
  if (cmd === '/days') {
    if (/^(все|всё|каждый|ежедн|all|every)/.test(arg)) props.setProperty('BRIEF_DAYS', 'all');
    else if (/^(будн|раб|work)/.test(arg)) props.setProperty('BRIEF_DAYS', 'work');
    else return 'Напиши /days будни или /days все. Сейчас: ' + daysText_() + '.';
    let msg = '✅ Сводка приходит ' + daysText_() + ' в ' + hhmm_(briefAt_()) + '.';
    if (briefDays_() === 'all') msg += '\n⚠ Саму сводку Claude пока собирает только по будням — в выходные по ссылке будет пятничная.';
    return msg;
  }
  if (cmd === '/off') {
    props.setProperty('BRIEF_OFF', '1');
    return '⏸ Сводка на паузе. Включить — /on.';
  }
  if (cmd === '/on') {
    props.deleteProperty('BRIEF_OFF');
    return '▶ Сводка снова включена.\n' + statusText_();
  }
  if (cmd === '/now') {
    sendBrief_();
    return 'Вот она 👆';
  }
  if (cmd === '/help') return statusText_() + '\n\n' + HELP_;
  return 'Не знаю такой команды.\n\n' + HELP_;
}

function statusText_() {
  const props = PropertiesService.getScriptProperties();
  if (props.getProperty('BRIEF_OFF') === '1') return '⏸ Сводка на паузе (обычно ' + daysText_() + ' в ' + hhmm_(briefAt_()) + '). Включить — /on.';
  return '🕗 Сводка приходит ' + daysText_() + ' в ' + hhmm_(briefAt_()) + ' по Москве.';
}

function daysText_() {
  return briefDays_() === 'all' ? 'каждый день' : 'по будням';
}

/** «7:30», «07.30», «7» → минуты от полуночи или null. */
function parseTime_(s) {
  const m = /^(\d{1,2})(?:[:.](\d{2}))?$/.exec(s.trim());
  if (!m) return null;
  const h = +m[1], min = +(m[2] || 0);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

function hhmm_(t) {
  return Math.floor(t / 60) + ':' + String(t % 60).padStart(2, '0');
}

function tg_(method, body) {
  const token = PropertiesService.getScriptProperties().getProperty('TELEGRAM_BOT_TOKEN');
  if (!token) throw new Error('Добавь TELEGRAM_BOT_TOKEN в свойства скрипта');
  const r = UrlFetchApp.fetch('https://api.telegram.org/bot' + token + '/' + method, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(body),
    muteHttpExceptions: true,
  });
  const res = JSON.parse(r.getContentText() || '{}');
  if (!res.ok) console.error('Telegram ' + method + ': ' + r.getContentText());
  return res;
}
