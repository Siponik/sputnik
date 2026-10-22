// Акцентный цвет (Настройки → Вид → «Акцент»): settings.accent.v = id набора или «#RRGGBB» (свой цвет).
// Меняются только --clay, --clay-soft и --on-clay — всё, что «подсвечено» акцентом. Тип «Творческое»,
// золото, «выполнено» и енот остаются прежними. Для тёмной и светлой темы у цвета свои оттенки.

/** Готовые наборы: dark — для тёмной темы, light — для светлой (темнее, чтобы читался на белом). */
export const ACCENTS = [
  { id: 'clay', name: 'Глина', dark: '#D9774F', light: '#AD4F2C' },
  { id: 'coral', name: 'Коралл', dark: '#E8766E', light: '#B23A33' },
  { id: 'rose', name: 'Роза', dark: '#E07A9B', light: '#A83A60' },
  { id: 'lavender', name: 'Лаванда', dark: '#A68BE8', light: '#5B45A8' },
  { id: 'sky', name: 'Небо', dark: '#6E9EE8', light: '#2D5BA8' },
  { id: 'mint', name: 'Мята', dark: '#5DBB98', light: '#1E7356' },
  { id: 'olive', name: 'Олива', dark: '#A8B85A', light: '#55661A' },
];

export const DEFAULT_ACCENT = 'clay';

const BG_DARK = '#1C1B19';
const BG_LIGHT = '#FFFFFF';

const hex = (s) => (typeof s === 'string' && /^#?[0-9a-f]{6}$/i.test(s.trim()) ? '#' + s.trim().replace('#', '').toUpperCase() : null);
const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const toHex = (c) => '#' + c.map((x) => Math.round(Math.max(0, Math.min(255, x))).toString(16).padStart(2, '0')).join('').toUpperCase();

/** Смесь цветов a и b: t = доля a (0…1). */
export function mix(a, b, t) {
  const A = rgb(a), B = rgb(b);
  return toHex(A.map((x, i) => x * t + B[i] * (1 - t)));
}

/** Относительная яркость (WCAG). */
export function luminance(h) {
  const [r, g, b] = rgb(h).map((x) => { x /= 255; return x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4; });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** Контраст двух цветов (1…21). */
export function contrast(a, b) {
  const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
}

/** Подогнать цвет под фон: смешивать с белым (на тёмном) или чёрным (на светлом), пока контраст не станет ≥ min. */
export function fit(c, bg, min) {
  const toward = luminance(bg) < 0.5 ? '#FFFFFF' : '#000000';
  let out = c;
  for (let t = 1; t >= 0.3 && contrast(out, bg) < min; t -= 0.05) out = mix(c, toward, t);
  return out;
}

/** Набор по значению настройки: id из ACCENTS, свой «#RRGGBB» или пусто (= Глина). */
export function accentOf(v) {
  const p = ACCENTS.find((a) => a.id === v);
  if (p) return p;
  const h = hex(v);
  if (!h) return ACCENTS[0];
  // Свой цвет: в тёмной теме — светлее до читаемого на тёмном фоне, в светлой — темнее до читаемого на белом.
  return { id: 'custom', name: 'Свой', dark: fit(h, BG_DARK, 4.5), light: fit(h, BG_LIGHT, 4.5) };
}

/** Три переменные для одной темы. */
export function vars(c, theme) {
  if (theme === 'light') return { clay: c, soft: mix(c, BG_LIGHT, 0.1), on: contrast(c, '#FFFFFF') >= 3 ? '#FFFFFF' : '#1C1B19' };
  return { clay: c, soft: mix(c, BG_DARK, 0.13), on: contrast(c, BG_DARK) >= contrast(c, '#FFFFFF') ? BG_DARK : '#FFFFFF' };
}

const block = (v) => `--clay: ${v.clay}; --clay-soft: ${v.soft}; --on-clay: ${v.on};`;

/** CSS для <style id="sp-accent">: те же три места, что в tokens.css, но сильнее (:root:root). Глина — пусто. */
export function accentCss(v) {
  const a = accentOf(v);
  if (a.id === DEFAULT_ACCENT) return '';
  const d = block(vars(a.dark, 'dark')), l = block(vars(a.light, 'light'));
  return `:root:root { ${d} }\n`
    + `@media (prefers-color-scheme: light) { :root:root:not([data-theme="dark"]) { ${l} } }\n`
    + `:root:root[data-theme="light"] { ${l} }\n`;
}
