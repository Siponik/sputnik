<script>
  import TaskCard from './TaskCard.svelte';
  import { TEMPLATES, isArchived, ARCHIVE_AFTER_DAYS } from './templates.js';

  let { list, tasks, template, colOf, remindOf = () => '', onopen, onmove, oncreate, onarchive, ontemplate } = $props();

  let over = $state('');
  let draft = $state('');

  const cols = $derived(template.cols);
  const top = $derived(tasks.filter((t) => !t.parent));
  const live = $derived(top.filter((t) => !isArchived(t)));
  const archived = $derived(top.length - live.length);
  const subsOf = (id) => tasks.filter((t) => t.parent === id);
  const byPos = (a, b) => (a.position || '').localeCompare(b.position || '');
  function column(id) {
    const items = live.filter((t) => colOf(t, cols) === id);
    if (id === 'done') return items.sort((a, b) => (b.completed || '').localeCompare(a.completed || ''));
    return items.sort(byPos);
  }

  function drop(e, col) {
    e.preventDefault();
    over = '';
    const id = e.dataTransfer.getData('text/plain');
    const task = tasks.find((t) => t.id === id);
    if (task && colOf(task, cols) !== col) onmove(task, col);
  }

  async function add(e) {
    e.preventDefault();
    const title = draft.trim();
    if (!title) return;
    draft = '';
    await oncreate(title);
  }
</script>

<div class="page">
  <header class="page-head">
    <div>
      <h1>{list?.title ?? 'Задачи'}</h1>
      <p>{template.name} · {top.filter((t) => t.status !== 'completed').length} открытых</p>
    </div>
    <div class="head-tools">
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
      <section
        class="sp-col"
        class:over={over === col.id}
        aria-label={col.name}
        ondragover={(e) => { e.preventDefault(); over = col.id; }}
        ondragleave={() => { if (over === col.id) over = ''; }}
        ondrop={(e) => drop(e, col.id)}
      >
        <header class="sp-col-head"><h3>{col.name}</h3><span class="n">{column(col.id).length}</span></header>
        {#each column(col.id) as task (task.id)}
          <TaskCard {task} subs={subsOf(task.id)} remind={remindOf(task)} {onopen} />
        {/each}
        {#if i === 0}
          <form class="add-row" onsubmit={add}>
            <input bind:value={draft} placeholder="Новая задача" aria-label="Новая задача" />
            <button class="sp-btn" type="submit" aria-label="Добавить">+</button>
          </form>
        {/if}
        {#if col.id === 'done' && archived}
          <button class="col-foot" type="button" onclick={onarchive}>Старше {ARCHIVE_AFTER_DAYS} дней — в архиве · {archived}</button>
        {/if}
      </section>
    {/each}
  </div>
</div>
