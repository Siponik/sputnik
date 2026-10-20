// Демо-режим: пустышки вместо окна, уведомлений и обновлений Tauri (см. vite.config.js, mode === 'demo').
const win = {
  minimize: async () => {}, toggleMaximize: async () => {}, maximize: async () => {}, unmaximize: async () => {},
  close: async () => {}, isMaximized: async () => false, startDragging: async () => {},
  onResized: async () => () => {}, onFocusChanged: async () => () => {}, listen: async () => () => {},
  setTitle: async () => {},
};
export const getCurrentWindow = () => win;
export const getVersion = async () => 'demo';
export const check = async () => null;
export const relaunch = async () => {};
export const isPermissionGranted = async () => false;
export const requestPermission = async () => 'denied';
export const sendNotification = (o) => console.info('[demo] уведомление:', o);
