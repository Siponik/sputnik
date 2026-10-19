<script>
  import { humanDue, dueState } from './api.js';

  let { task, subs = [], listName = '', draggable = true, onopen, ontoggle } = $props();
  const done = $derived(task.status === 'completed');
  const subDone = $derived(subs.filter((s) => s.status === 'completed').length);
  const firstLine = $derived((task.notes ?? '').split('\n')[0]);
  const ds = $derived(dueState(task));
</script>

<article
  class="sp-card"
  class:is-done={done}
  {draggable}
  ondragstart={(e) => { e.dataTransfer.setData('text/plain', task.id); e.dataTransfer.effectAllowed = 'move'; }}
>
  <input class="sp-check" type="checkbox" checked={done} aria-label="Выполнено" onchange={(e) => ontoggle(task, e.currentTarget.checked)} />
  <button class="t" type="button" onclick={() => onopen(task)}>{task.title || 'Без названия'}</button>
  {#if firstLine}<p class="d">{firstLine}</p>{/if}
  {#if task.due || subs.length || listName}
    <div class="meta">
      {#if task.due}
        <span class="sp-chip" class:sp-chip-overdue={ds === 'overdue'} class:sp-chip-soon={ds === 'soon'}>
          {ds === 'overdue' ? 'просрочено · ' : ''}{humanDue(task.due)}
        </span>
      {/if}
      {#if subs.length}<span class="data">{subDone}/{subs.length}</span>{/if}
      {#if listName}<span class="data">{listName}</span>{/if}
    </div>
  {/if}
</article>
