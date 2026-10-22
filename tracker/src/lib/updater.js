// Обновление из приложения: Tauri updater смотрит latest.json в последнем релизе Siponik/sputnik
// (адрес и открытый ключ — tauri.conf.json → plugins.updater). Установщик подписан, чужой файл не встанет.
// Бета-канал (settings.update.beta, только у владельца): сначала latest.json релиза tracker-beta (команда beta_check,
// src-tauri/src/beta.rs), если там ничего нового — обычный: 0.7.3-beta.2 обновится на вышедший 0.7.3 сам.
import { check, Update } from '@tauri-apps/plugin-updater';
import { invoke } from '@tauri-apps/api/core';
import { relaunch } from '@tauri-apps/plugin-process';
import { getVersion } from '@tauri-apps/api/app';

export const currentVersion = () => getVersion().catch(() => '');

/** Есть ли новая версия: { version, notes, update, beta } или null. В режиме разработки обновлений нет. */
export async function findUpdate(beta = false) {
  if (import.meta.env.DEV && import.meta.env.MODE !== 'demo') return null;
  if (beta && import.meta.env.MODE !== 'demo') {
    const meta = await invoke('beta_check');
    if (meta) {
      const update = new Update(meta);
      return { version: update.version, notes: update.body ?? '', update, beta: true };
    }
  }
  const update = await check({ timeout: 30000 });
  return update ? { version: update.version, notes: update.body ?? '', update } : null;
}

/** Скачать и поставить; onprogress(0..1). После установки приложение перезапускается. */
export async function install(found, onprogress) {
  let total = 0, got = 0;
  await found.update.downloadAndInstall((ev) => {
    if (ev.event === 'Started') total = ev.data.contentLength ?? 0;
    else if (ev.event === 'Progress') { got += ev.data.chunkLength; if (total) onprogress(Math.min(1, got / total)); }
    else if (ev.event === 'Finished') onprogress(1);
  });
  await relaunch();
}
