// Демо-режим: пустышки вместо окна, уведомлений и обновлений Tauri (см. vite.config.js, mode === 'demo').
const win = {
  minimize: async () => {}, toggleMaximize: async () => {}, maximize: async () => {}, unmaximize: async () => {},
  close: async () => {}, isMaximized: async () => false, startDragging: async () => {},
  onResized: async () => () => {}, onFocusChanged: async () => () => {}, listen: async () => () => {},
  setTitle: async () => {},
};
export const getCurrentWindow = () => win;
export const getVersion = async () => '0.6.0';
// Проверка шапки и «Состояния»: window.__demo = { upd: '0.6.4' } (или ?upd=0.6.4 в адресе) — «вышла новая версия»;
// установка идёт 4 с с прогрессом и ничего не ставит.
const demoUpd = () => globalThis.__demo?.upd ?? new URLSearchParams(location.search).get('upd');
export const check = async () => {
  const version = demoUpd();
  if (!version) return null;
  return {
    version,
    body: '- Окно «Создать»: само понимает, куда положить задачу\n- Стикеры: раскладка по срокам\n- Исправлено: енот на доске теперь всегда виден\n- Ещё мелочи',
    downloadAndInstall: async (cb) => {
      cb({ event: 'Started', data: { contentLength: 100 } });
      for (let i = 0; i < 10; i++) { await new Promise((r) => setTimeout(r, 400)); cb({ event: 'Progress', data: { chunkLength: 10 } }); }
      cb({ event: 'Finished' });
    },
  };
};
export const relaunch = async () => {};
export const isPermissionGranted = async () => false;
export const requestPermission = async () => 'denied';
export const sendNotification = (o) => console.info('[demo] уведомление:', o);
