import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

// Tauri ждёт фронтенд на фиксированном порту.
export default defineConfig({
  plugins: [svelte()],
  clearScreen: false,
  // src-tauri не отслеживаем: там Rust собирает .exe, и на Windows слежка за ними роняет сервер (EBUSY).
  server: { port: 1420, strictPort: true, watch: { ignored: ['**/src-tauri/**'] } },
  build: { target: 'es2021', outDir: 'dist', emptyOutDir: true },
});
