<script>
  // Карточка канбана (design/screens/Kanban.dc.html, docs/design-v2.md — «Канбан и Конвейер»).
  // Галочки нет: выполнено = последняя колонка. Слева полоска приоритета, ряд чипов, справа сверху — → · срок · ⋯.
  // Клик по названию — открыть окно задачи, по остальной карточке — только выбрать. Двойной клик по названию или F2 — переименовать.
  import { humanDue, dueState } from './api.js';
  import { typeLabel } from './meta.js';
  import { repeatLabel } from './repeat.js';

  // fields — что показывать (шаблон → «На карточке»); пусто — срок, приоритет, тип. Подзадачи «☑ 3 из 5» — всегда, если они есть (как на макете). extra — запись слоя (клиент, сумма).
  let { task, subs = [], remind = '', type = '', priority = null, fields = [], extra = null, next = null,
    selected = false, editing = false, ghost = false,
    onopen, onadvance, ondue, onmenu, onselect, onrename, onstartedit, onendedit, ondragstart, ondragend } = $props();
  const show = (f) => (fields.length ? fields.includes(f) : ['due', 'prio', 'type', 'subtasks'].includes(f));
  const money = $derived(extra?.money ? Number(extra.money).toLocaleString('ru-RU') + ' ₽' : '');
  const done = $derived(task.status === 'completed');
  const subDone = $derived(subs.filter((s) => s.status === 'completed').length);
  const segN = $derived(Math.min(8, subs.length));
  const segOn = $derived(subs.length ? Math.round((subDone / subs.length) * segN) : 0);
  const firstLine = $derived((task.notes ?? '').split('\n')[0]);
  const ds = $derived(dueState(task));
  const rep = $derived(done ? '' : repeatLabel(extra?.repeat));
  const PC = { 1: 'var(--clay)', 2: 'var(--gold)', 3: 'var(--ink-faint)' };
  const pc = $derived(!done && show('prio') ? PC[priority] ?? 'transparent' : 'transparent');

  let draft = $state('');
  const focusSel = (el) => { draft = task.title || ''; el.focus(); el.select(); };
  function finish(keep) {
    const t = draft.trim();
    onendedit?.();
    if (keep && t && t !== task.title) onrename?.(task, t);
  }
  const stop = (fn) => (e) => { e.stopPropagation(); fn(e); };
  // Одиночный клик по названию открывает окно чуть позже, чтобы двойной клик успел перейти в переименование.
  let openTimer = 0;
  function titleClick(e) {
    e.stopPropagation();
    onselect?.(task);
    clearTimeout(openTimer);
    if (e.detail > 1) return;
    openTimer = setTimeout(() => onopen(task), 220);
  }
  function titleDbl(e) {
    e.stopPropagation();
    clearTimeout(openTimer);
    onstartedit?.(task);
  }
</script>

<!-- svelte-ignore a11y_no_noninteractive_tabindex, a11y_no_noninteractive_element_interactions -->
<article
  class="kc"
  class:done
  class:sel={selected}
  class:ghost
  data-id={task.id}
  tabindex="0"
  style="--pc: {pc}"
  aria-label="{task.title || 'Без названия'}{task.due ? `, срок ${humanDue(task.due)}` : ''}{priority === 1 ? ', высокий приоритет' : ''}"
  draggable={!editing}
  ondragstart={(e) => ondragstart?.(e, task)}
  ondragend={() => ondragend?.()}
  onfocus={() => onselect?.(task)}
  onclick={() => onselect?.(task)}
  oncontextmenu={(e) => { e.preventDefault(); onselect?.(task); onmenu?.(task, e.currentTarget); }}
  onkeydown={() => {}}
>
  {#if editing}
    <input class="kc-ren" use:focusSel bind:value={draft} aria-label="Название задачи"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => { e.stopPropagation(); if (e.key === 'Enter') { e.preventDefault(); finish(true); } else if (e.key === 'Escape') { e.preventDefault(); finish(false); } }}
      onblur={() => finish(true)} />
  {:else}
    <!-- Кнопки — плавающий блок внутри названия: первая строка обтекает их, вторая идёт на всю ширину. -->
    <!-- svelte-ignore a11y_no_static_element_interactions, a11y_click_events_have_key_events -->
    <div class="t" title="Открыть задачу · Enter" onclick={titleClick} ondblclick={titleDbl}>
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="kc-qa" ondblclick={(e) => e.stopPropagation()}>
        {#if next}
          <button type="button" aria-label="Перенести в «{next.name}»" title="Перенести в «{next.name}» · Alt+→" onclick={stop(() => onadvance(task))}>
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h13M13 6l6 6-6 6" /></svg>
          </button>
        {/if}
        <button type="button" aria-label="Срок" title="Срок · D" onclick={stop(() => ondue(task))}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="5" width="16" height="15" rx="3" /><path d="M4 10h16M9 3v4M15 3v4" /></svg>
        </button>
        <button type="button" aria-label="Ещё действия" title="Ещё · правый клик" aria-haspopup="menu" onclick={stop((e) => onmenu(task, e.currentTarget.closest('.kc')))}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="5" cy="12" r="1.2" /><circle cx="12" cy="12" r="1.2" /><circle cx="19" cy="12" r="1.2" /></svg>
        </button>
      </div>
      {task.title || 'Без названия'}</div>
  {/if}
  {#if firstLine && !done}<p class="d">{firstLine}</p>{/if}
  {#if (show('client') && extra?.client) || (show('money') && money)}
    <p class="d client">{show('client') && extra?.client ? extra.client : ''}{show('client') && extra?.client && show('money') && money ? ' · ' : ''}{show('money') ? money : ''}</p>
  {/if}
  {#if (show('due') && task.due) || (show('type') && typeLabel(type)) || (subs.length && !done) || (remind && !done) || rep}
    <div class="mt">
      {#if show('due') && task.due}
        <span class="chip" class:late={ds === 'overdue' && !done} class:soon={ds === 'soon' && !done}>{done ? '✓ ' : ds === 'overdue' ? 'просрочено · ' : ''}{humanDue(task.due)}</span>
      {/if}
      {#if show('type') && typeLabel(type)}<span class="chip" style="color: var(--type-{type})"><i></i>{typeLabel(type)}</span>{/if}
      {#if subs.length && !done}
        <span class="chip sub" class:all={subDone === subs.length} title="Подзадачи: {subDone} из {subs.length}">
          <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="4" width="16" height="16" rx="4" /><path d="M8.5 12.5l2.5 2.5 4.5-5" /></svg>{subDone} из {subs.length}
          <span class="segs" aria-hidden="true">{#each Array(segN) as _, i}<b class:on={i < segOn}></b>{/each}</span>
        </span>
      {/if}
      {#if remind && !done}<span class="chip" title="Напоминание">🔔 {remind}</span>{/if}
      {#if rep}<span class="chip" title="Повторяется {rep}">↻ {rep}</span>{/if}
    </div>
  {/if}
</article>
