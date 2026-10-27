// Плашка внизу экрана: текст, кнопка действия («Отменить», «Открыть»…) и таймер 6 с с паузой на наведении.
// Стор — одна общая плашка на всё приложение; показывает её lib/Toast.svelte.
const LIFE = 6000;

export const toast = $state({ msg: '', undo: null, label: 'Отменить', n: 0 });

let timer, left = 0, startedAt = 0;

/** Показать плашку; undo — действие кнопки (по умолчанию «Отменить», label — другая подпись, например «Открыть»). */
export function say(msg, undo = null, label = 'Отменить') {
  toast.msg = msg;
  toast.undo = undo;
  toast.label = label;
  toast.n++; // номер плашки — заново запускает полоску-таймер
  left = LIFE;
  resume();
}

export function hide() {
  clearTimeout(timer);
  toast.msg = '';
  toast.undo = null;
}

export function resume() {
  clearTimeout(timer);
  startedAt = Date.now();
  timer = setTimeout(hide, left);
}

export function pause() {
  clearTimeout(timer);
  left = Math.max(800, left - (Date.now() - startedAt));
}

/** Нажали кнопку действия: плашка уходит, действие выполняется. */
export function act() {
  const fn = toast.undo;
  hide();
  fn?.();
}

/** Сейчас на экране плашка с действием — её не стоит перебивать служебным сообщением. */
export const busy = () => !!toast.undo;
