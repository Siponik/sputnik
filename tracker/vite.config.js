import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

// Tauri ждёт фронтенд на фиксированном порту.
// npm run demo — трекер в обычном браузере на выдуманных данных (src/demo/): Tauri и Google подменены.
const demo = {
  '@tauri-apps/api/core': '/src/demo/tauri-core.js',
  '@tauri-apps/api/window': '/src/demo/tauri-stubs.js',
  '@tauri-apps/api/app': '/src/demo/tauri-stubs.js',
  '@tauri-apps/plugin-notification': '/src/demo/tauri-stubs.js',
  '@tauri-apps/plugin-process': '/src/demo/tauri-stubs.js',
  '@tauri-apps/plugin-updater': '/src/demo/tauri-stubs.js',
};

export default defineConfig(({ mode }) => ({
  plugins: [svelte()],
  resolve: { alias: mode === 'demo' ? Object.entries(demo).map(([find, to]) => ({ find, replacement: fileURLToPath(new URL('.' + to, import.meta.url)) })) : [] },
  clearScreen: false,
  // src-tauri не отслеживаем: там Rust собирает .exe, и на Windows слежка за ними роняет сервер (EBUSY).
  // fs.allow: енот берётся прямо из design/mascot — это выше папки tracker.
  server: { port: mode === 'demo' ? 1421 : 1420, strictPort: true, fs: { allow: ['..'] }, watch: { ignored: ['**/src-tauri/**'] } },
  build: { target: 'es2021', outDir: 'dist', emptyOutDir: true },
}));
