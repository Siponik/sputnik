<script>
  // Свои кнопки окна вместо виндовской рамки (tauri.conf.json → decorations: false).
  // Перетаскивание — атрибут data-tauri-drag-region на шапке (App.svelte, Setup.svelte).
  import { onMount } from 'svelte';
  import { getCurrentWindow } from '@tauri-apps/api/window';

  let maximized = $state(false);
  let win = null;
  onMount(() => {
    let off = null;
    try {
      win = getCurrentWindow();
      const sync = async () => { try { maximized = await win.isMaximized(); } catch {} };
      sync();
      win.onResized(sync).then((u) => (off = u)).catch(() => {});
    } catch { win = null; } // в обычном браузере (разработка интерфейса) окна Tauri нет
    return () => off?.();
  });
  const run = (fn) => () => { try { win && fn(win); } catch {} };
</script>

<div class="winctl" role="group" aria-label="Окно">
  <button type="button" title="Свернуть" aria-label="Свернуть" onclick={run((w) => w.minimize())}>
    <svg viewBox="0 0 12 12" aria-hidden="true"><path d="M2 6h8" /></svg>
  </button>
  <button type="button" title={maximized ? 'Вернуть размер' : 'Развернуть'} aria-label={maximized ? 'Вернуть размер' : 'Развернуть'} onclick={run((w) => w.toggleMaximize())}>
    {#if maximized}
      <svg viewBox="0 0 12 12" aria-hidden="true"><path d="M3.5 3.5V2h6.5v6.5H8.5M2 3.5h6.5V10H2z" /></svg>
    {:else}
      <svg viewBox="0 0 12 12" aria-hidden="true"><rect x="2" y="2" width="8" height="8" rx="1" /></svg>
    {/if}
  </button>
  <button type="button" class="close" title="Закрыть" aria-label="Закрыть" onclick={run((w) => w.close())}>
    <svg viewBox="0 0 12 12" aria-hidden="true"><path d="M2.5 2.5l7 7M9.5 2.5l-7 7" /></svg>
  </button>
</div>
