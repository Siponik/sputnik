<script>
  import { humanDue, dueState } from './api.js';

  // Галочки на карточке нет: задача становится выполненной, только когда её переносят в «Готово».
  // Стрелка (видна при наведении и фокусе) переносит на следующий этап.
  let { task, subs = [], listName = '', remind = '', type = '', draggable = true, next = null, onopen, onadvance } = $props();
  const TYPE_LABEL = { work: 'Работа', creative: 'Ассет', study: 'Учёба', personal: 'Личное' };
  const done = $derived(task.status === 'completed');
  const subDone = $derived(subs.filter((s) => s.status === 'completed').length);
  const firstLine = $derived((task.notes ?? '').split('\n')[0]);
  const ds = $derived(dueState(task));
</script>

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
<article
  class="sp-card no-check"
  class:is-done={done}
  class:has-adv={!!next}
  {draggable}
  ondragstart={(e) => { e.dataTransfer.setData('text/plain', task.id); e.dataTransfer.effectAllowed = 'move'; }}
  onclick={() => onopen(task)}
>
  <!-- Клик по любому месту карточки открывает задачу; кнопка — для клавиатуры, её клик всплывает сюда. -->
  <button class="t" type="button">{task.title || 'Без названия'}</button>
  {#if firstLine}<p class="d">{firstLine}</p>{/if}
  {#if task.due || subs.length || listName || remind || type}
    <div class="meta">
      {#if type && TYPE_LABEL[type]}<span class="sp-chip sp-chip-{type}"><span class="dot"></span>{TYPE_LABEL[type]}</span>{/if}
      {#if task.due}
        <span class="sp-chip" class:sp-chip-overdue={ds === 'overdue'} class:sp-chip-soon={ds === 'soon'}>
          {ds === 'overdue' ? 'просрочено · ' : ''}{humanDue(task.due)}
        </span>
      {/if}
      {#if remind && !done}
        <span class="data bell" title="Напоминание"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20.5a2 2 0 0 0 4 0" /></svg>{remind}</span>
      {/if}
      {#if subs.length}<span class="data">{subDone}/{subs.length}</span>{/if}
      {#if listName}<span class="data">{listName}</span>{/if}
    </div>
  {/if}
  {#if next}
    <button type="button" class="adv" aria-label="Перенести в «{next.name}»" title="Перенести в «{next.name}»"
      onclick={(e) => { e.stopPropagation(); onadvance(); }}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h13M13 6l6 6-6 6" /></svg>
    </button>
  {/if}
</article>
