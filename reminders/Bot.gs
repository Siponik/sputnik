// Спутник · команды боту в Telegram: время утренней сводки, дни, пауза.
// Без вебхука: tick() в Code.gs раз в минуту забирает новые сообщения (getUpdates),
// поэтому ответ приходит в течение минуты. Слушаем только свой чат (TELEGRAM_CHAT_ID).
//
// Команды:
//   /time          — когда приходит сводка
//   /time 7:30     — поставить время (можно и просто прислать «7:30»)
//   /days будни    — только по будням; /days все — каждый день
//   /off, /on      — поставить сводку на паузу и включить снова
//   /now           — прислать ссылку на сводку сейчас
//   /help          — список команд

const BRIEF_READY_AT = 7 * 60 + 45; // сводка обновляется в 7:45 МСК (задача Claude «Утренняя сводка»)

/** Запустить один раз: включает меню команд в Telegram и шлёт пробное сообщение. */
function setupBot() {
  tg_('deleteWebhook', {}); // getUpdates не работает, пока у бота есть вебхук
  tg_('setMyCommands', {
    commands: [
      { command: 'time', description: 'Время сводки: /time 7:30' },
      { command: 'days', description: 'По будням или каждый день' },
      { command: 'off', description: 'Пауза сводки' },
      { command: 'on', description: 'Включить сводку' },
      { command: 'now', description: 'Прислать сводку сейчас' },
      { command: 'help', description: 'Что я умею' },
    ],
  });
  send_('🛰 Спутник: теперь мне можно писать.\n\n' + statusText_() + '\n\n' + HELP_);
}

const HELP_ = [
  '/time 7:30 — поменять время (или просто пришли «7:30»)',
  '/days будни или /days все',
  '/off — пауза, /on — включить',
  '/now — прислать сводку сейчас',
].join('\n');

function botTick_() {
  const props = PropertiesService.getScriptProperties();
  // Скрипт обновляется сам из GitHub — меню команд включаем при первом запуске новой версии.
  if (props.getProperty('BOT_READY') !== '1') {
    props.setProperty('BOT_READY', '1');
    setupBot();
  }
  const offset = +(props.getProperty('TG_OFFSET') || 0);
  const res = tg_('getUpdates', { offset: offset, timeout: 0, allowed_updates: ['message'] });
  if (!res || !res.ok || !res.result.length) return;
  const chat = String(props.getProperty('TELEGRAM_CHAT_ID'));
  let last = offset;
  for (const u of res.result) {
    last = u.update_id + 1;
    // Сразу запоминаем: если команда упадёт, она не будет повторяться каждую минуту.
    props.setProperty('TG_OFFSET', String(last));
    const m = u.message;
    if (!m || !m.text || String(m.chat.id) !== chat) continue; // чужие чаты молча пропускаем
    try { send_(handle_(m.text.trim())); } catch (e) { console.error('Команда «' + m.text + '»: ' + e); }
  }
}

/** Разбирает сообщение и возвращает ответ. */
function handle_(text) {
  const props = PropertiesService.getScriptProperties();
  const parts = text.replace(/@\w+/, '').split(/\s+/);
  let cmd = parts[0].toLowerCase();
  let arg = parts.slice(1).join(' ').toLowerCase();
  // Просто время без команды: «7:30», «07.30», «8»
  if (/^\d{1,2}([:.]\d{2})?$/.test(cmd)) { arg = cmd; cmd = '/time'; }
  const alias = { '/время': '/time', '/дни': '/days', '/пауза': '/off', '/вкл': '/on', '/сейчас': '/now', '/start': '/help', '/помощь': '/help' };
  cmd = alias[cmd] || cmd;

  if (cmd === '/time') {
    if (!arg) return statusText_();
    const t = parseTime_(arg);
    if (t === null) return 'Не понял время. Пример: /time 7:30';
    props.setProperty('BRIEF_AT', String(t));
    props.deleteProperty('BRIEF_OFF');
    let msg = '✅ Сводка будет приходить в ' + hhmm_(t) + ' (' + daysText_() + ').';
    if (t < BRIEF_READY_AT) msg += '\n⚠ Сама сводка обновляется в 7:45 — до этого по ссылке будет вчерашняя.';
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
