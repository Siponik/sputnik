// Вход в Google на первом запуске: проверка файла ключа до отправки в Rust и понятные объяснения ошибок.
// Rust (google.rs) проверяет то же самое ещё раз — здесь только чтобы сразу сказать человеку, что не так.

export const SECRET_MAX = 64 * 1024;

/** Пустая строка — файл похож на client_secret.json типа Desktop app; иначе — что не так. */
export function checkSecretText(text, size = String(text ?? '').length) {
  if (size > SECRET_MAX) return 'Файл слишком большой — это не client_secret.json. Нужен маленький файл ключа из Google Cloud.';
  const t = String(text ?? '').replace(/^﻿/, '').trim();
  if (!t) return 'Файл пустой. Скачай JSON клиента в Google Cloud ещё раз.';
  let j;
  try { j = JSON.parse(t); } catch { return 'Это не похоже на client_secret.json: в файле не JSON.'; }
  if (!j || typeof j !== 'object' || Array.isArray(j)) return 'Это не похоже на client_secret.json из Google Cloud.';
  if (!j.installed && j.web) return 'Это ключ типа «Веб-приложение», а нужен «Приложение для компьютера» (Desktop app). Создай в Google Cloud клиента Desktop app и скачай его JSON.';
  if (j.type === 'service_account') return 'Это ключ сервисного аккаунта, а нужен ключ OAuth типа Desktop app (Google Cloud → Clients).';
  if (!j.installed || typeof j.installed !== 'object') return 'В файле нет раздела «installed» — нужен ключ OAuth типа Desktop app из Google Cloud → Clients.';
  const id = String(j.installed.client_id ?? '').trim();
  if (!id || /\s/.test(id) || !id.endsWith('.apps.googleusercontent.com')) return 'В файле неправильный client_id — скачай JSON клиента заново.';
  return '';
}

/** Вход прервали из самого приложения («Отмена», смена ключа) — показывать нечего. */
export const isStopped = (e) => /Вход прерван/.test(String(e ?? ''));

/** Google не дал часть доступов (сняли галочки на странице входа). */
export const isScopeLack = (e) => /не дал(?: Спутнику все)? доступ|insufficient authentication scopes/i.test(String(e ?? ''));

/** Текст ошибки входа для человека: убираем служебное начало и добавляем, что делать. */
export function loginHint(e) {
  const s = String(e ?? '').replace(/^Error:\s*/, '');
  if (!s || isStopped(s)) return '';
  if (isScopeLack(s)) {
    const names = s.match(/не дал доступ — (.+?)\./)?.[1];
    return (names ? `Google не дал доступ: ${names}.` : 'Google не дал Спутнику все доступы.')
      + ' Нажми «Открыть вход» ещё раз и на странице Google отметь все галочки (или «Выбрать всё»).';
  }
  if (/access_denied/.test(s)) return 'Вход отменён на странице Google. Если там было «доступ заблокирован» — приложение в Google Cloud ещё в режиме теста: добавь свою почту в тестовые пользователи или опубликуй его.';
  if (/invalid_client|unauthorized_client|401/i.test(s)) return 'Google не принял ключ приложения. Верни встроенный ключ или скачай client_secret.json заново.';
  if (/за 5 минут/.test(s)) return 'Вход не завершился за 5 минут. Нажми «Открыть вход» ещё раз.';
  return s;
}

/** Первый запуск: сразу включены только основной календарь и праздники, остальные человек отмечает сам. */
export const calDefaultOn = (c) => !!c?.primary || /#holiday@/.test(String(c?.id ?? ''));
