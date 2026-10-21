<script>
  // Поповер от кнопки в шапке («Состояние», «Что нового»): под кнопкой, по центру, не вылезает за окно.
  // Закрывается Esc и кликом мимо (клик по самой кнопке её же и переключает).
  import { pop } from './motion.js';

  let { anchor, width = 378, label = '', onclose, children } = $props();
  let el = $state(null);
  let pos = $state({ x: 8, y: 60 });
  function place() {
    if (!anchor) return;
    const r = anchor.getBoundingClientRect();
    // Внизу не помещается, а сверху есть место — открываем над кнопкой (чипы внизу экрана «Сегодня»).
    const h = el?.offsetHeight ?? 0;
    const up = h && r.bottom + 6 + h > innerHeight - 8 && r.top - 6 - h >= 8;
    pos = { x: Math.max(8, Math.min(r.left + r.width / 2 - width / 2, innerWidth - width - 8)), y: up ? r.top - 6 - h : r.bottom + 6 };
  }
  $effect(() => { if (el) place(); });
  function down(e) { if (el && !el.contains(e.target) && !anchor?.contains(e.target)) onclose(); }
  function key(e) { if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); onclose(); anchor?.focus(); } }
</script>

<svelte:window onpointerdown={down} onkeydowncapture={key} onresize={place} />

<div class="st-pop" role="dialog" aria-label={label} bind:this={el} transition:pop
  style="left: {pos.x}px; top: {pos.y}px; width: {width}px; transform-origin: top center">
  {@render children()}
</div>
