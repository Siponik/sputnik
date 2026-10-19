<script>
  import { isArchived, ARCHIVE_AFTER_DAYS } from './templates.js';

  // Архив: выполненные задачи старше ARCHIVE_AFTER_DAYS дней. Можно посмотреть все списки сразу.
  let { lists, tasksByList, activeId, onopen, onrestore, onback } = $props();

  let scope = $state('list'); // list | all
  let q = $state('');

  const MONTHS = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
  const activeList = $derived(lists.find((l) => l.id === activeId));

  const items = $derived.by(() => {
    const src = scope === 'all' ? lists : lists.filter((l) => l.id === activeId);
    const needle = q.trim().toLowerCase();
    return src
      .flatMap((l) => (tasksByList[l.id] ?? []).filter((t) => !t.parent && isArchived(t)).map((t) => ({ task: t, list: l })))
      .filter((x) => !needle || (x.task.title ?? '').toLowerCase().includes(needle) || (x.task.notes ?? '').toLowerCase().includes(needle))
      .sort((a, b) => (b.task.completed || '').localeCompare(a.task.completed || ''));
  });

  const groups = $derived.by(() => {
    const out = [];
    for (const x of items) {
      const d = new Date(x.task.completed);
      const name = `${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
      if (out.at(-1)?.name !== name) out.push({ name, items: [] });
      out.at(-1).items.push(x);
    }
    return out;
  });

  const day = (s) => new Date(s).toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' });
</script>

<div class="page">
  <header class="page-head">
    <div>
      <h1>Архив</h1>
      <p>Выполнено больше {ARCHIVE_AFTER_DAYS} дней назад · {items.length}</p>
    </div>
    <div class="head-tools">
      <div class="seg" role="group" aria-label="Какие списки">
        <button type="button" aria-pressed={scope === 'list'} onclick={() => (scope = 'list')}>{activeList?.title ?? 'Список'}</button>
        <button type="button" aria-pressed={scope === 'all'} onclick={() => (scope = 'all')}>Все списки</button>
      </div>
      <button class="sp-btn" type="button" onclick={onback}>К доске</button>
    </div>
  </header>

  <input class="search" type="search" bind:value={q} placeholder="Найти в архиве" aria-label="Найти в архиве" />

  {#each groups as g (g.name)}
    <section class="group">
      <h2>{g.name} · {g.items.length}</h2>
      {#each g.items as x (x.task.id)}
        <div class="row">
          <button class="title done" type="button" onclick={() => onopen(x.task, x.list.id)}>{x.task.title || 'Без названия'}</button>
          {#if scope === 'all'}<span class="list">{x.list.title}</span>{/if}
          <span class="list">{day(x.task.completed)}</span>
          <button class="sp-btn sp-btn-ghost" type="button" style="min-height: 30px" onclick={() => onrestore(x.task, x.list.id)}>Вернуть</button>
        </div>
      {/each}
    </section>
  {:else}
    <p class="empty">{q ? 'Ничего не нашлось.' : 'В архиве пока пусто.'}</p>
  {/each}
</div>
