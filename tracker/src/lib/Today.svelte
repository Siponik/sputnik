<script>
  import { dueToYmd, ymd, humanDue } from './api.js';

  let { lists, tasksByList, events, statusOf, onopen, ontoggle } = $props();

  const today = ymd(new Date());
  const WEEK = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
  const MONTHS = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  const now = new Date();
  const dateLine = `${WEEK[now.getDay()]} · ${now.getDate()} ${MONTHS[now.getMonth()]} ${now.getFullYear()}`;

  const all = $derived(lists.flatMap((l) => (tasksByList[l.id] ?? []).filter((t) => !t.parent).map((t) => ({ task: t, list: l }))));
  const open = $derived(all.filter((x) => x.task.status !== 'completed'));
  const overdue = $derived(open.filter((x) => x.task.due && dueToYmd(x.task.due) < today));
  const dueToday = $derived(open.filter((x) => x.task.due && dueToYmd(x.task.due) === today));
  const doing = $derived(open.filter((x) => !['inbox', 'refs', 'done'].includes(statusOf(x.task)) && !(x.task.due && dueToYmd(x.task.due) <= today)));
  const doneToday = $derived(all.filter((x) => x.task.status === 'completed' && x.task.completed && ymd(new Date(x.task.completed)) === today));

  function plural(n, f) { const a = n % 10, b = n % 100; return a === 1 && b !== 11 ? f[0] : a >= 2 && a <= 4 && (b < 12 || b > 14) ? f[1] : f[2]; }
  const timed = $derived(events.filter((e) => e.start?.dateTime));
  const headline = $derived.by(() => {
    const n = overdue.length + dueToday.length;
    const parts = [];
    if (n) parts.push(`${n} ${plural(n, ['задача', 'задачи', 'задач'])} на сегодня`);
    if (timed.length) parts.push(`${timed.length} ${plural(timed.length, ['событие', 'события', 'событий'])} в календаре`);
    if (!parts.length) return 'День свободен — можно взяться за большое.';
    const s = parts.join(' и ');
    return s[0].toUpperCase() + s.slice(1) + '.';
  });

  const hm = (s) => new Date(s).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
  function eventTime(e) {
    if (!e.start?.dateTime) return 'весь день';
    return `${hm(e.start.dateTime)}–${hm(e.end?.dateTime ?? e.start.dateTime)}`;
  }
  function isNow(e) {
    if (!e.start?.dateTime) return false;
    const t = Date.now();
    return new Date(e.start.dateTime).getTime() <= t && t < new Date(e.end?.dateTime ?? e.start.dateTime).getTime();
  }
</script>

{#snippet row(x)}
  <div class="row">
    <input class="sp-check" type="checkbox" checked={x.task.status === 'completed'} aria-label="Выполнено" onchange={(e) => ontoggle(x.task, e.currentTarget.checked, x.list.id)} />
    <button class="title" type="button" onclick={() => onopen(x.task, x.list.id)}>{x.task.title || 'Без названия'}</button>
    {#if x.task.due && dueToYmd(x.task.due) < today}<span class="sp-chip sp-chip-overdue">просрочено · {humanDue(x.task.due)}</span>{/if}
    <span class="list">{x.list.title}</span>
  </div>
{/snippet}

<section class="today-hero">
  <p class="date">{dateLine}</p>
  <h1>{headline}</h1>
</section>

<div class="today-grid">
  <main>
    {#if overdue.length}
      <section class="group">
        <h2 class="over">Просрочено · {overdue.length}</h2>
        {#each overdue as x (x.task.id)}{@render row(x)}{/each}
      </section>
    {/if}
    <section class="group">
      <h2>Сегодня · {dueToday.length}</h2>
      {#each dueToday as x (x.task.id)}{@render row(x)}{:else}<p class="empty">На сегодня задач со сроком нет.</p>{/each}
    </section>
    {#if doing.length}
      <section class="group">
        <h2>В работе · {doing.length}</h2>
        {#each doing as x (x.task.id)}{@render row(x)}{/each}
      </section>
    {/if}
    {#if doneToday.length}
      <section class="group">
        <h2>Сделано сегодня · {doneToday.length}</h2>
        {#each doneToday as x (x.task.id)}{@render row(x)}{/each}
      </section>
    {/if}
  </main>

  <aside aria-label="Календарь на сегодня">
    <div class="group"><h2>Календарь</h2></div>
    {#each events as e (e.id + (e.calendar ?? ''))}
      <div class="event" class:now={isNow(e)}>
        <time>{eventTime(e)}</time>
        <span><b>{e.summary || 'Без названия'}</b><br /><span style="color: var(--ink-soft)">{e.calendar}</span></span>
      </div>
    {:else}
      <p class="empty">Событий сегодня нет.</p>
    {/each}
  </aside>
</div>
