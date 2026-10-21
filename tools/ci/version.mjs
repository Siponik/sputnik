// Номер версии трекера: МАЖОР.МИНОР берутся из tracker/src-tauri/tauri.conf.json, третье число считается по релизам.
// Новый минор (в tauri.conf.json поставили 0.7.0) — первый релиз 0.7.0, дальше 0.7.1, 0.7.2…
// tags — имена тегов релизов («tracker-0.6.0», «tracker-0.6.1»…), из них берётся наибольший номер этого минора.
export function nextVersion(base, tags = []) {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(base ?? '');
  if (!m) throw new Error(`Непонятная версия в tauri.conf.json: ${base}`);
  const [, major, minor, patch] = m;
  const re = new RegExp(`^tracker-${major}\\.${minor}\\.(\\d+)$`);
  const used = tags.map((t) => re.exec(String(t).trim())?.[1]).filter(Boolean).map(Number);
  return `${major}.${minor}.${used.length ? Math.max(...used) + 1 : Number(patch)}`;
}
