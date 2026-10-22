// Значки и цвета привычек (habits[id].icon, habits[id].color) — design/screens/HabitEdit.dc.html.
// Значок — линии 24×24 (класс svg.li), цвет — один из токенов; цвет только у значка, «сделано» везде золотое.

export const ICONS = {
  cup: '<path d="M5 8h12v6a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5z"/><path d="M17 10h1.5a2.5 2.5 0 0 1 0 5H17M8 3v2M12 3v2"/>',
  gym: '<path d="M3 10v4M6 8v8M18 8v8M21 10v4M6 12h12"/>',
  pencil: '<path d="M4 20l1-4L16 5l3 3L8 19z"/><path d="M14 7l3 3"/>',
  book: '<path d="M4 5.5C6.5 4.5 9.5 4.5 12 6c2.5-1.5 5.5-1.5 8-.5V19c-2.5-1-5.5-1-8 .5-2.5-1.5-5.5-1.5-8-.5z"/><path d="M12 6v13.5"/>',
  moon: '<path d="M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z"/>',
  lang: '<path d="M4 6h7M7.5 6v12M4 18h7M14 9l3 9 3-9M15 15h4"/>',
  walk: '<circle cx="13" cy="4.5" r="1.6"/><path d="M9 20l2.5-5.5L14 17v3M8 11.5l3-3h3l2 3.5h3M11 8.5l.5 6"/>',
  heart: '<path d="M12 19.5s-7-4.3-7-9.5a3.8 3.8 0 0 1 7-2.1A3.8 3.8 0 0 1 19 10c0 5.2-7 9.5-7 9.5z"/>',
  leaf: '<path d="M5 19C5 11 10 6 19 5c0 9-5 14-14 14z"/><path d="M5 19l8-8"/>',
  music: '<path d="M9 17V6l10-2v11"/><circle cx="6.5" cy="17" r="2.5"/><circle cx="16.5" cy="15" r="2.5"/>',
};
export const ICON_IDS = Object.keys(ICONS);

export const COLORS = {
  work: 'var(--type-work)', clay: 'var(--clay)', gold: 'var(--gold)',
  personal: 'var(--type-personal)', study: 'var(--type-study)', done: 'var(--signal-done)',
};
export const COLOR_IDS = Object.keys(COLORS);

/** Значок привычки: свой или по порядку (у старых привычек значка нет). */
export const iconOf = (h, i = 0) => (ICONS[h?.icon] ? h.icon : ICON_IDS[i % 6]);
export const colorOf = (h, i = 0) => COLORS[h?.color] ?? COLORS[COLOR_IDS[i % COLOR_IDS.length]];

/** Заготовки для пустого экрана (клик открывает окно привычки уже заполненным). */
export const PRESETS = [
  { name: 'Вода', icon: 'cup', color: 'work', part: 'morning', goal: { n: 8, unit: 'стаканов' }, sub: '8 стаканов в день' },
  { name: 'Зарядка', icon: 'gym', color: 'clay', part: 'morning', sub: 'утро · 10 минут' },
  { name: 'Скетч 15 минут', icon: 'pencil', color: 'gold', part: 'evening', time: '21:00', sub: 'вечер · каждый день' },
  { name: 'Чтение', icon: 'book', color: 'personal', part: 'evening', days: [0, 1, 2, 3, 4], goal: { n: 20, unit: 'страниц' }, sub: '20 страниц · по будням' },
  { name: 'Английский', icon: 'lang', color: 'study', part: 'any', perWeek: 3, sub: '3 раза в неделю' },
];

export const UNITS = ['раз', 'стаканов', 'страниц', 'минут', 'км', 'шагов'];
