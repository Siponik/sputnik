<script>
  // Поиск по всем задачам и быстрый переход (Ctrl+K или /). ↑↓ — выбор, Enter — открыть, Esc — закрыть.
  import { tick } from 'svelte';
  import { fade, pop } from './motion.js';
  import { findTasks, findPlaces } from './search.js';
  import { humanDue, dueState } from './api.js';

  let { lists, tasks, places, onopen, ongo, onclose } = $props();

  let q = $state('');
  let sel = $state(0);
  let input;
  let box;

  const found = $derived(q.trim() ? findTasks(q, lists, tasks) : []);
  const jumps = $derived(findPlaces(q, places).slice(0, q.trim() ? 4 : places.length));
  // Одна общая лента для стрелок: сначала переходы, потом задачи.
  const rows = $derived([...jumps.map((p) => ({ kind: 'place', key: 'p' + p.id, p })), ...found.map((x) => ({ kind: 'task', key: 't' + x.task.id, x }))]);

  $effect(() => { q; sel = 0; });
  $effect(() => { tick().then(() => input?.focus()); });

  function pick(r) {
    if (!r) return;
    if (r.kind === 'place') ongo(r.p);
    else onopen(r.x.list.id, r.x.task.parent || r.x.task.id);
  }
  function key(e) {
    if (e.key === 'Escape') { e.preventDefault(); onclose(); }
    else if (e.key === 'ArrowDown') { e.preventDefault(); sel = Math.min(rows.length - 1, sel + 1); scroll(); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); sel = Math.max(0, sel - 1); scroll(); }
    else if (e.key === 'Enter') { e.preventDefault(); pick(rows[sel]); }
  }
  const scroll = () => tick().then(() => box?.querySelector('.sr-row.on')?.scrollIntoView({ block: 'nearest' }));
</script>

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose} transition:fade={{ duration: 160 }}></button>
<div transition:pop class="dialog srch" role="dialog" aria-label="Поиск">
  <input bind:this={input} bind:value={q} onkeydown={key} class="sr-input" type="search" placeholder="Найти задачу или перейти: «рендер», «привычки», «Работа»…"
    role="combobox" aria-expanded="true" aria-controls="sr-list" aria-activedescendant={rows[sel] ? 'sr-' + rows[sel].key : undefined} autocomplete="off" spellcheck="false" />
  <div class="sr-list" id="sr-list" role="listbox" bind:this={box}>
    {#each rows as r, i (r.key)}
      <button type="button" id={'sr-' + r.key} role="option" aria-selected={i === sel} class="sr-row" class:on={i === sel} onmousemove={() => (sel = i)} onclick={() => pick(r)}>
        {#if r.kind === 'place'}
          <span class="sr-kind">{r.p.kind}</span>
          <span class="sr-t">{r.p.name}</span>
          {#if r.p.n != null}<span class="sr-m">{r.p.n}</span>{/if}
        {:else}
          <span class="sr-dot" class:done={r.x.task.status === 'completed'} aria-hidden="true"></span>
          <span class="sr-t" class:done={r.x.task.status === 'completed'}>
            {r.x.task.title || 'Без названия'}
            {#if r.x.parent}<small> · подзадача «{r.x.parent.title}»</small>{/if}
          </span>
          {#if r.x.task.due && r.x.task.status !== 'completed'}<span class="sr-m {dueState(r.x.task)}">{humanDue(r.x.task.due)}</span>{/if}
          <span class="sr-m">{r.x.list.title}</span>
        {/if}
      </button>
    {:else}
      <p class="sr-empty">Ничего не нашлось. Ищу по названиям и заметкам во всех списках, выполненные тоже.</p>
    {/each}
  </div>
  <p class="sr-hint"><span class="kbd">↑↓</span> выбрать <span class="kbd">Enter</span> открыть <span class="kbd">Esc</span> закрыть</p>
</div>
