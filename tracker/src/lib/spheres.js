// Сферы — группы списков Google Tasks со своим именем, цветом и значком (docs/design-v2.md — «Сферы»).
// Только в слое Спутника: spheres[id] = { name, color, icon, order }, список → lists[listId].sphere.
// Список — максимум в одной сфере; без сферы — группа «Без сферы» внизу.

export const SPHERE_COLORS = [
  { id: 'clay', name: 'Глина', v: 'var(--clay)' },
  { id: 'gold', name: 'Золото', v: 'var(--gold)' },
  { id: 'work', name: 'Синий', v: 'var(--type-work)' },
  { id: 'study', name: 'Фиолетовый', v: 'var(--type-study)' },
  { id: 'personal', name: 'Зелёный', v: 'var(--type-personal)' },
  { id: 'done', name: 'Бирюзовый', v: 'var(--signal-done)' },
];

// 8 штриховых значков (пути из design/screens/Spheres.dc.html), viewBox 0 0 24 24.
export const SPHERE_ICONS = {
  cube: { name: 'Куб', d: 'M12 3l8 4.5v9L12 21l-8-4.5v-9zM12 12l8-4.5M12 12v9M12 12L4 7.5' },
  case: { name: 'Портфель', d: 'M4 8h16v11H4zM9 8V5h6v3M4 13h16' },
  book: { name: 'Книга', d: 'M5 4h10a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3zM5 17a3 3 0 0 1 3-3h10' },
  home: { name: 'Дом', d: 'M4 11l8-7 8 7M6 10v10h12V10M10 20v-6h4v6' },
  users: { name: 'Люди', d: 'M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14c2 .8 3 3 3 6' },
  heart: { name: 'Сердце', d: 'M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z' },
  brush: { name: 'Кисть', d: 'M18 3l3 3-9.5 9.5-3-3zM8.5 12.5C6 12.5 4 14.5 4 17c0 1.5-1 2.5-2 3 4 1 8-1 8-4.5' },
  star: { name: 'Звезда', d: 'M12 3l2.7 5.6 6.1.8-4.4 4.3 1 6.1L12 17l-5.4 2.8 1-6.1-4.4-4.3 6.1-.8z' },
};

export const sphereColor = (s) => (SPHERE_COLORS.find((c) => c.id === s?.color) ?? SPHERE_COLORS[0]).v;
export const iconPath = (s) => (SPHERE_ICONS[s?.icon] ?? SPHERE_ICONS.star).d;
/** Плитка значка: цвет значка и 16 % этого цвета фоном. */
export const iconStyle = (s) => `color: ${sphereColor(s)}; background: color-mix(in srgb, ${sphereColor(s)} 16%, transparent)`;

/** Сферы по порядку (удалённые — с removed: true — не показываем). */
export function spheresFrom(lay) {
  return Object.entries(lay?.spheres ?? {})
    .filter(([, s]) => s && !s.removed)
    .map(([id, s]) => ({ id, ...s }))
    .sort((a, b) => (a.order ?? 0) - (b.order ?? 0) || (a.name ?? '').localeCompare(b.name ?? '', 'ru'));
}

/** Сфера списка или null (если сферу удалили — тоже null). */
export function sphereOf(listId, lay) {
  const id = lay?.lists?.[listId]?.sphere;
  return id && lay.spheres?.[id] && !lay.spheres[id].removed ? id : null;
}
