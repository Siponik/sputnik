<script>
  import { pop } from './motion.js';
  // Короткое меню по правому клику (или Shift+F10) для списка, сферы, шаблона в левой колонке.
  // items — [{ id, label, danger?, sep?, kbd? }]: sep — черта перед пунктом, kbd — клавиша справа. Внешний вид — как у меню задачи (.cmenu).
  import { untrack } from 'svelte';

  let { at, label = 'Действия', items = [], onaction, onclose } = $props();
  let el = $state(null);
  let pos = $state(untrack(() => ({ x: at.x, y: at.y })));
  $effect(() => {
    if (!el) return;
    const r = el.getBoundingClientRect();
    pos = { x: Math.max(8, Math.min(at.x, innerWidth - r.width - 8)), y: Math.max(8, Math.min(at.y, innerHeight - r.height - 8)) };
  });
  $effect(() => { el?.querySelector('button')?.focus(); });

  function act(id) { onaction(id); onclose(); }
  function key(e) {
    if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); onclose(); return; }
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      const b = [...el.querySelectorAll('button')];
      const i = b.indexOf(document.activeElement);
      b[(i + (e.key === 'ArrowDown' ? 1 : -1) + b.length) % b.length]?.focus();
    }
  }
</script>

<svelte:window onkeydowncapture={key} />

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div class="cm-back" onclick={onclose} oncontextmenu={(e) => { e.preventDefault(); onclose(); }}></div>
<div transition:pop class="cmenu" role="menu" aria-label={label} bind:this={el} style="left: {pos.x}px; top: {pos.y}px; transform-origin: top left">
  {#each items as it (it.id)}
    {#if it.sep}<hr />{/if}
    <button type="button" role="menuitem" class:danger={it.danger} onclick={() => act(it.id)}>{it.label}{#if it.kbd}<kbd>{it.kbd}</kbd>{/if}</button>
  {/each}
</div>
