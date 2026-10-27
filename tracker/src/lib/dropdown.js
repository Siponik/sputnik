// Выпадающий список Спутника (Dropdown.svelte) — чистая логика: поиск, ходьба по пунктам, прыжок по букве,
// подпись кнопки «несколько сразу» и место меню на экране. Дизайн — docs/design-v2.md,
// «Окно задачи v2 и выпадающие списки», лист design/screens/Dropdowns.dc.html.

const norm = (s) => String(s ?? '').toLowerCase().replace(/ё/g, 'е');

/** Пункты, подходящие под поиск: все слова запроса в названии (ё = е). Пустой запрос — все. */
export function filterOpts(opts, q) {
  const words = norm(q).trim().split(/\s+/).filter(Boolean);
  if (!words.length) return opts;
  return opts.filter((o) => { const t = norm(o.label); return words.every((w) => t.includes(w)); });
}

/** Название, разбитое на куски для подсветки совпадения: [{ t, hit }]. Подсвечивается первое вхождение запроса. */
export function marks(label, q) {
  const s = String(label ?? '');
  const k = norm(q).trim();
  const i = k ? norm(s).indexOf(k) : -1;
  if (i < 0) return [{ t: s, hit: false }];
  return [{ t: s.slice(0, i), hit: false }, { t: s.slice(i, i + k.length), hit: true }, { t: s.slice(i + k.length), hit: false }]
    .filter((p) => p.t);
}

const usable = (o) => o && !o.disabled;

/**
 * Следующий активный пункт по клавише: ArrowDown / ArrowUp (по кругу), Home, End. Недоступные пропускаются.
 * cur = -1 — ничего не выбрано. Возвращает индекс или -1, если выбрать нечего.
 */
export function moveActive(opts, cur, key) {
  const n = opts.length;
  if (!opts.some(usable)) return -1;
  if (key === 'Home') return opts.findIndex(usable);
  if (key === 'End') return n - 1 - [...opts].reverse().findIndex(usable);
  const step = key === 'ArrowUp' ? -1 : 1;
  let i = cur < 0 ? (step > 0 ? -1 : n) : cur;
  for (let k = 0; k < n; k++) {
    i = (i + step + n) % n;
    if (usable(opts[i])) return i;
  }
  return cur;
}

/** Прыжок по букве: следующий после cur доступный пункт, название которого начинается с этой буквы. */
export function jumpTo(opts, cur, ch) {
  const c = norm(ch);
  if (!c.trim()) return cur;
  const n = opts.length;
  for (let k = 1; k <= n; k++) {
    const i = (Math.max(cur, -1) + k + n) % n;
    if (usable(opts[i]) && norm(opts[i].label).startsWith(c)) return i;
  }
  return cur;
}

/** Выбор «несколько сразу»: добавить или убрать id, порядок — как в списке пунктов. */
export function toggleIn(values, id, opts = []) {
  const set = new Set(values ?? []);
  if (set.has(id)) set.delete(id); else set.add(id);
  const order = opts.map((o) => o.id);
  return [...set].sort((a, b) => order.indexOf(a) - order.indexOf(b));
}

/** Подпись кнопки: один пункт — его название; несколько — «первые два, +N»; ничего — ''. */
export function buttonText(opts, value, multi = false) {
  if (!multi) return opts.find((o) => o.id === value)?.label ?? '';
  const on = opts.filter((o) => (value ?? []).includes(o.id)).map((o) => o.short ?? o.label);
  if (on.length <= 2) return on.join(', ');
  return `${on.slice(0, 2).join(', ')}, +${on.length - 2}`;
}

/**
 * Место меню: под кнопкой, если не влезает — над ней (если сверху места больше). Ширина — не меньше кнопки,
 * не больше max; меню не вылезает за край окна (отступ 8). Возвращает top (под кнопкой) или bottom (над ней). btn — {left, top, right, bottom, width};
 * h, w — высота и естественная ширина меню; view — {w, h}.
 */
export function placeMenu(btn, h, w, view, { gap = 6, max = 320, pad = 8 } = {}) {
  const width = Math.min(Math.max(w, btn.width), Math.max(max, btn.width), view.w - pad * 2);
  const below = view.h - pad - (btn.bottom + gap);
  const above = btn.top - gap - pad;
  const up = h > below && above > below;
  const left = Math.max(pad, Math.min(btn.left, view.w - pad - width));
  const room = Math.max(0, up ? above : below);
  // Над кнопкой меню держится нижним краем (bottom от низа окна), чтобы рост при поиске не наезжал на кнопку.
  return up ? { left, top: null, bottom: view.h - (btn.top - gap), width, up, maxH: room }
    : { left, top: btn.bottom + gap, bottom: null, width, up, maxH: room };
}
