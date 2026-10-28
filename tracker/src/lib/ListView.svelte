<script>
  // Вид «Список» (шаблоны с малым числом этапов, например «Учёба»): строка = задача, этап — метка с выбором,
  // прогресс по подзадачам «3 из 10». Выполнить — перевести метку на последний этап.
  import { humanDue, dueState } from './api.js';
  import { colColor, isArchived, orderTasks } from './templates.js';
  import { priorityOf } from './meta.js';
  import Dropdown from './Dropdown.svelte';

  let { tasks, cols, colOf, layTasks, fields = [], days = 3, sort = 'own', visible = () => true, onopen, onmove, onmenu } = $props();
  // Правый клик по строке — то же меню задачи, что на канбане (onmenu от доски).

  const has = (f) => fields.includes(f);
  const stageOpts = $derived(cols.map((x) => ({ id: x.id, label: x.name, color: colColor(x) })));
  const subsOf = (id) => tasks.filter((t) => t.parent === id);
  // по этапам, внутри — в порядке списка (lists[id].sort)
  const rows = $derived(orderTasks(tasks.filter((t) => !t.parent && visible(t) && !isArchived(t, days)), layTasks, sort)
    .sort((a, b) => cols.findIndex((c) => c.id === colOf(a, cols)) - cols.findIndex((c) => c.id === colOf(b, cols))));
</script>

<div class="lv">
  {#each rows as t (t.id)}
    {@const c = cols.find((x) => x.id === colOf(t, cols)) ?? cols[0]}
    {@const subs = subsOf(t.id)}
    {@const sd = subs.filter((s) => s.status === 'completed').length}
    {@const pr = priorityOf(layTasks?.[t.id]?.priority)}
    {@const ds = dueState(t)}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="lvr" class:done={t.status === 'completed'} oncontextmenu={(e) => { e.preventDefault(); onmenu?.(t, e.currentTarget); }}>
      <span class="lv-stage" style="--c: {colColor(c)}">
        <Dropdown ghost small mark="dot" title="Этап" label="Этап задачи «{t.title}»" value={c.id} options={stageOpts} onchange={(v) => onmove(t, v)} />
      </span>
      <button type="button" class="lv-title" onclick={() => onopen(t)}>{t.title || 'Без названия'}</button>
      {#if has('prio') && pr && t.status !== 'completed'}<span class="prio {pr.cls}">{pr.mark}</span>{/if}
      {#if (has('progress') || has('subtasks')) && subs.length}
        <span class="lv-prog" title="Подзадачи">
          <i><span style="width: {Math.round((sd / subs.length) * 100)}%"></span></i>{sd} из {subs.length}
        </span>
      {/if}
      {#if has('due') && t.due}<span class="sp-chip" class:sp-chip-overdue={ds === 'overdue'} class:sp-chip-soon={ds === 'soon'}>{humanDue(t.due)}</span>{/if}
    </div>
  {:else}
    <p class="empty">Пока пусто — добавь первую задачу кнопкой «Создать».</p>
  {/each}
</div>
