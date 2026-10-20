<script>
  // Меню задачи (⋯, правый клик, Shift+F10): те же действия, что клавиши, с подписанными клавишами.
  // Общее для Канбана, Конвейера и Списка. Подменю (приоритет, этап, список) раскрываются внутри меню.
  import { untrack } from 'svelte';
  import { PRIORITIES } from './meta.js';

  // at — { x, y } точка привязки (правый верхний угол карточки или курсор); expand — сразу раскрыть подменю ('list' для M).
  let { at, cols = [], cur = '', priority = null, lists = [], expand = '', onaction, onclose } = $props();
  let sub = $state(untrack(() => expand));
  let el = $state(null);
  // Не вылезать за окно: если не помещается снизу или справа — сдвигаем.
  let pos = $state(untrack(() => ({ x: at.x, y: at.y })));
  $effect(() => {
    if (!el) return;
    sub;
    const r = el.getBoundingClientRect();
    pos = { x: Math.max(8, Math.min(at.x, innerWidth - r.width - 8)), y: Math.max(8, Math.min(at.y, innerHeight - r.height - 8)) };
  });
  $effect(() => { el?.querySelector('button')?.focus(); });

  function act(name, arg) { onaction(name, arg); onclose(); }
  function key(e) {
    if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); onclose(); return; }
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      const b = [...el.querySelectorAll('button')];
      const i = b.indexOf(document.activeElement);
      b[(i + (e.key === 'ArrowDown' ? 1 : -1) + b.length) % b.length]?.focus();
    }
  }
  const toggle = (s) => (sub = sub === s ? '' : s);
</script>

<svelte:window onkeydowncapture={key} />

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div class="cm-back" onclick={onclose} oncontextmenu={(e) => { e.preventDefault(); onclose(); }}></div>
<div class="cmenu" role="menu" aria-label="Действия с задачей" bind:this={el} style="left: {pos.x}px; top: {pos.y}px">
  <button type="button" role="menuitem" onclick={() => act('open')}>Открыть<kbd>Enter</kbd></button>
  <button type="button" role="menuitem" onclick={() => act('rename')}>Переименовать<kbd>F2</kbd></button>
  <button type="button" role="menuitem" onclick={() => act('due')}>Срок и время<kbd>D</kbd></button>
  <button type="button" role="menuitem" aria-expanded={sub === 'prio'} onclick={() => toggle('prio')}>Приоритет {sub === 'prio' ? '▾' : '▸'}<kbd>Alt+1…3</kbd></button>
  {#if sub === 'prio'}
    <div class="cm-sub row">
      {#each PRIORITIES as p (p.id)}<button type="button" role="menuitemradio" aria-checked={priority === p.id} title={p.label} onclick={() => act('priority', p.id)}>{p.mark}</button>{/each}
      <button type="button" role="menuitemradio" aria-checked={!priority} title="Без приоритета" onclick={() => act('priority', null)}>—</button>
    </div>
  {/if}
  {#if cols.length}
    <button type="button" role="menuitem" aria-expanded={sub === 'stage'} onclick={() => toggle('stage')}>Этап {sub === 'stage' ? '▾' : '▸'}<kbd>Alt+← →</kbd></button>
    {#if sub === 'stage'}
      <div class="cm-sub">
        {#each cols as c, i (c.id)}<button type="button" role="menuitemradio" aria-checked={cur === c.id} onclick={() => act('stage', c.id)}><span class="num">{i + 1}</span>{c.name}</button>{/each}
      </div>
    {/if}
  {/if}
  {#if lists.length}
    <button type="button" role="menuitem" aria-expanded={sub === 'list'} onclick={() => toggle('list')}>В другой список {sub === 'list' ? '▾' : '▸'}<kbd>M</kbd></button>
    {#if sub === 'list'}
      <div class="cm-sub">
        {#each lists as l (l.id)}<button type="button" role="menuitem" onclick={() => act('list', l.id)}>{l.title}</button>{/each}
      </div>
    {/if}
  {/if}
  <hr />
  <button type="button" role="menuitem" onclick={() => act('duplicate')}>Дублировать<kbd>Ctrl+D</kbd></button>
  <button type="button" role="menuitem" class="danger" onclick={() => act('delete')}>Удалить<kbd>Del</kbd></button>
</div>
