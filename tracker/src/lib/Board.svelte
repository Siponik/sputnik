<script>
  import TaskCard from './TaskCard.svelte';

  let { list, tasks, statusOf, onopen, ontoggle, onmove, oncreate } = $props();

  const COLS = [
    { id: 'inbox', name: 'Входящие' },
    { id: 'doing', name: 'В работе' },
    { id: 'review', name: 'На ревью' },
    { id: 'done', name: 'Готово' },
  ];

  let over = $state('');
  let draft = $state('');

  const top = $derived(tasks.filter((t) => !t.parent));
  const subsOf = (id) => tasks.filter((t) => t.parent === id);
  const byPos = (a, b) => (a.position || '').localeCompare(b.position || '');
  function column(id) {
    const items = top.filter((t) => statusOf(t) === id);
    if (id === 'done') return items.sort((a, b) => (b.completed || '').localeCompare(a.completed || '')).slice(0, 30);
    return items.sort(byPos);
  }
  const counts = $derived(Object.fromEntries(COLS.map((c) => [c.id, top.filter((t) => statusOf(t) === c.id).length])));

  function drop(e, col) {
    e.preventDefault();
    over = '';
    const id = e.dataTransfer.getData('text/plain');
    const task = tasks.find((t) => t.id === id);
    if (task && statusOf(task) !== col) onmove(task, col);
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
      <p>Список Google Tasks · {top.filter((t) => t.status !== 'completed').length} открытых</p>
    </div>
  </header>

  <div class="board">
    {#each COLS as col (col.id)}
      <section
        class="sp-col"
        class:over={over === col.id}
        aria-label={col.name}
        ondragover={(e) => { e.preventDefault(); over = col.id; }}
        ondragleave={() => { if (over === col.id) over = ''; }}
        ondrop={(e) => drop(e, col.id)}
      >
        <header class="sp-col-head"><h3>{col.name}</h3><span class="n">{counts[col.id]}</span></header>
        {#each column(col.id) as task (task.id)}
          <TaskCard {task} subs={subsOf(task.id)} {onopen} {ontoggle} />
        {/each}
        {#if col.id === 'inbox'}
          <form class="add-row" onsubmit={add}>
            <input bind:value={draft} placeholder="Новая задача" aria-label="Новая задача" />
            <button class="sp-btn" type="submit" aria-label="Добавить">+</button>
          </form>
        {/if}
      </section>
    {/each}
  </div>
</div>
