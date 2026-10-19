<script>
  import { tick } from 'svelte';
  import TaskCard from './TaskCard.svelte';
  import Coon from './Coon.svelte';
  import { ymd, dueToYmd } from './api.js';
  import { TEMPLATES, isArchived, ARCHIVE_AFTER_DAYS } from './templates.js';
  import { startOfWeek, addDays } from './calendar.js';

  let { list, tasks, template, colOf, typeOf, layTasks, project = null, remindOf = () => '',
    onopen, onmove, oncreate, onarchive, ontemplate } = $props();

  const WIP = 3; // лимит «В работе»
  const TYPES = [
    { k: '', label: 'Все' }, { k: 'work', label: 'Работа' }, { k: 'creative', label: 'Ассет' },
    { k: 'study', label: 'Учёба' }, { k: 'personal', label: 'Личное' },
  ];
  // Что говорит пустая колонка и какой енот там сидит.
  const EMPTY = {
    inbox: ['cheer', 'Входящие разобраны. Енот доволен!'],
    doing: ['sleep', 'Ничего в работе. Возьми задачу из входящих.'],
    review: ['sleep', 'На ревью пусто — енот дремлет до новой работы.'],
    done: ['sleep', 'Пока ничего не готово.'],
  };

  let over = $state('');
  let type = $state('');
  let showDone = $state(false);
  let composing = $state(''); // id колонки, где открыта форма
  let draft = $state('');
  let composeInput = $state(null);

  const cols = $derived(template.cols);
  const top = $derived(tasks.filter((t) => !t.parent));
  const live = $derived(top.filter((t) => !isArchived(t)));
  const archived = $derived(top.length - live.length);
  const open = $derived(top.filter((t) => t.status !== 'completed'));
  const weekDue = $derived.by(() => {
    const a = ymd(startOfWeek(new Date())), b = ymd(addDays(startOfWeek(new Date()), 6));
    return open.filter((t) => t.due && dueToYmd(t.due) >= a && dueToYmd(t.due) <= b).length;
  });
  const present = $derived(new Set(top.map((t) => typeOf(list.id, t.id))));
  const types = $derived(TYPES.filter((f) => !f.k || present.has(f.k)));
  const visible = (t) => (!type || typeOf(list.id, t.id) === type) && (!project || layTasks?.[t.id]?.project === project);

  const subsOf = (id) => tasks.filter((t) => t.parent === id);
  const byPos = (a, b) => (a.position || '').localeCompare(b.position || '');
  function column(id) {
    const items = live.filter((t) => colOf(t, cols) === id && visible(t));
    if (id === 'done') return items.sort((a, b) => (b.completed || '').localeCompare(a.completed || ''));
    return items.sort(byPos);
  }
  const nextOf = (i) => (i < cols.length - 1 ? cols[i + 1] : null);

  function drop(e, col) {
    e.preventDefault();
    over = '';
    const id = e.dataTransfer.getData('text/plain');
    const task = tasks.find((t) => t.id === id);
    if (task && colOf(task, cols) !== col) onmove(task, col);
  }

  async function startAdd(colId) {
    composing = colId;
    draft = '';
    await tick();
    composeInput?.focus();
  }
  async function commit() {
    const title = draft.trim();
    if (!title) return;
    const col = composing;
    draft = '';
    await oncreate(title, col);
    composeInput?.focus();
  }
  function composeKey(e) {
    if (e.key === 'Enter') { e.preventDefault(); commit(); }
    else if (e.key === 'Escape') { e.stopPropagation(); composing = ''; draft = ''; }
  }
</script>

<div class="page bd">
  <header class="page-head">
    <div>
      <h1>{list?.title ?? 'Задачи'}</h1>
      <p>Список Google Tasks · {template.name} · {open.length} открытых{weekDue ? ` · ${weekDue} со сроком на этой неделе` : ''}{project ? ` · проект «${project}»` : ''}</p>
    </div>
    <div class="head-tools">
      {#if types.length > 2}
        <div class="types" role="group" aria-label="Тип">
          {#each types as f (f.k)}
            <button type="button" class="tf" aria-pressed={type === f.k} onclick={() => (type = f.k)}>
              {#if f.k}<span class="dot" style="background: var(--type-{f.k})"></span>{/if}{f.label}
            </button>
          {/each}
        </div>
      {/if}
      <label class="tpl">
        <span>Шаблон</span>
        <select value={template.id} onchange={(e) => ontemplate(e.currentTarget.value)}>
          {#each TEMPLATES as t (t.id)}<option value={t.id}>{t.name}</option>{/each}
        </select>
      </label>
      <button class="sp-btn" type="button" onclick={onarchive}>Архив · {archived}</button>
    </div>
  </header>

  <div class="board">
    {#each cols as col, i (col.id)}
      {@const items = column(col.id)}
      {@const isDoneCol = col.id === 'done'}
      {@const shown = isDoneCol && !showDone ? items.slice(0, 2) : items}
      {@const next = nextOf(i)}
      {@const empty = EMPTY[col.id] ?? ['sleep', `${col.name}: пусто — енот дремлет.`]}
      <section
        class="bcol"
        class:over={over === col.id}
        aria-label={col.name}
        ondragover={(e) => { e.preventDefault(); over = col.id; }}
        ondragleave={() => { if (over === col.id) over = ''; }}
        ondrop={(e) => drop(e, col.id)}
      >
        <header class="colh" class:donecol={isDoneCol}>
          <h3>{col.name}</h3><span class="n">{items.length}</span>
          {#if col.id === 'doing'}<span class="wip" class:hot={items.length > WIP} title="Лимит задач в работе">{items.length} / {WIP}</span>{/if}
        </header>
        {#if col.id === 'doing' && items.length > WIP}
          <p class="wip-warn">Много всего в работе. Закончи одну, прежде чем брать новую.</p>
        {/if}

        {#each shown as task (task.id)}
          <TaskCard {task} subs={subsOf(task.id)} remind={remindOf(task)} type={typeOf(list.id, task.id)} {onopen}
            next={isDoneCol ? null : next} onadvance={() => onmove(task, next.id)} />
        {/each}

        {#if !items.length && composing !== col.id}
          <div class="bempty"><Coon pose={i === 0 ? 'cheer' : empty[0]} size={84} /><span>{i === 0 && col.id !== 'inbox' ? `${col.name}: всё разобрано. Енот доволен!` : empty[1]}</span></div>
        {/if}
        {#if isDoneCol && items.length > 2}
          <button class="more" type="button" onclick={() => (showDone = !showDone)}>{showDone ? 'Свернуть' : `Ещё ${items.length - 2} →`}</button>
        {/if}
        {#if isDoneCol && archived}
          <button class="col-foot" type="button" onclick={onarchive}>Старше {ARCHIVE_AFTER_DAYS} дней — в архиве · {archived}</button>
        {/if}

        {#if !isDoneCol}
          {#if composing === col.id}
            <div class="compose">
              <input bind:this={composeInput} bind:value={draft} type="text" aria-label="Название задачи" placeholder="Что сделать?" onkeydown={composeKey} />
              <div class="ca">
                <button class="sp-btn sp-btn-primary" type="button" style="min-height: 30px" disabled={!draft.trim()} onclick={commit}>Добавить</button>
                <button class="sp-btn sp-btn-ghost" type="button" style="min-height: 30px" onclick={() => { composing = ''; draft = ''; }}>Отмена</button>
              </div>
            </div>
          {:else}
            <button class="add" type="button" onclick={() => startAdd(col.id)}>+ Добавить задачу</button>
          {/if}
        {/if}
      </section>
    {/each}
  </div>
  <p class="bd-hint">Наведи на карточку — стрелка переносит её на следующий этап. Можно и перетаскивать.</p>
</div>
