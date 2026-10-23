<script>
  // Обзор сферы (design/screens/Spheres.dc.html): шапка, карточки списков, «Срочное в сфере».
  import { ymd, dueToYmd, humanDue } from './api.js';
  import { plural } from './habits.js';
  import { startOfWeek, addDays } from './calendar.js';
  import { sphereColor } from './spheres.js';
  import SphereIcon from './SphereIcon.svelte';
  import SharedTag from './SharedTag.svelte';
  import AvStack from './AvStack.svelte';
  import { whoOf } from './sharedcore.js';

  // people — участники, если сфера общая и в ней есть кто-то кроме владельца (иначе пусто).
  let { sphere, lists, tasksByList, templateFor, colOf, onedit, onaddlist, onopenlist, onopentask,
    people = [], me = '', layTasks = {}, onshare } = $props();
  const owner = $derived(people.find((p) => p.owner) ?? null);

  const today = ymd(new Date());
  const weekEnd = ymd(addDays(startOfWeek(new Date()), 6));
  const monthAgo = Date.now() - 30 * 864e5;

  const cards = $derived(lists.map((l) => {
    const all = (tasksByList[l.id] ?? []).filter((t) => !t.parent);
    const open = all.filter((t) => t.status !== 'completed');
    const tpl = templateFor(l.id);
    const per = Object.fromEntries(tpl.cols.map((c) => [c.id, 0]));
    for (const t of open) per[colOf(t, tpl.cols)] = (per[colOf(t, tpl.cols)] ?? 0) + 1;
    const next = open.filter((t) => t.due).sort((a, b) => a.due.localeCompare(b.due))[0];
    return {
      l, tpl, per,
      open: open.length,
      week: open.filter((t) => t.due && dueToYmd(t.due) <= weekEnd).length,
      month: all.filter((t) => t.status === 'completed' && t.completed && new Date(t.completed).getTime() > monthAgo).length,
      next,
    };
  }));
  const totals = $derived({
    open: cards.reduce((n, c) => n + c.open, 0),
    week: cards.reduce((n, c) => n + c.week, 0),
  });
  const mineN = $derived(lists.reduce((n, l) => n + (tasksByList[l.id] ?? [])
    .filter((t) => !t.parent && t.status !== 'completed' && me && whoOf(layTasks[t.id]) === me).length, 0));
  // Срочное: просрочено (красным), сегодня (clay), завтра–послезавтра.
  const urgent = $derived(lists.flatMap((l) => (tasksByList[l.id] ?? [])
    .filter((t) => !t.parent && t.status !== 'completed' && t.due && dueToYmd(t.due) <= ymd(addDays(new Date(), 2)))
    .map((t) => ({ t, l })))
    .sort((a, b) => a.t.due.localeCompare(b.t.due)).slice(0, 8));
</script>

<div class="page sph-view">
  <header class="sv-head">
    <SphereIcon {sphere} size={48} />
    <div class="sv-t">
      {#if people.length}
        <h1 class="sv-sh">{sphere.name} <SharedTag /></h1>
        <p>{lists.length} {plural(lists.length, ['список', 'списка', 'списков'])} · {totals.open} {plural(totals.open, ['задача', 'задачи', 'задач'])} · {mineN} {plural(mineN, ['твоя', 'твои', 'твоих'])}{owner ? ` · владелец — ${owner.email === me ? 'ты' : owner.name}` : ''}</p>
      {:else}
        <h1>{sphere.name}</h1>
        <p>{lists.length} {plural(lists.length, ['список', 'списка', 'списков'])} · {totals.open} {plural(totals.open, ['открытая', 'открытых', 'открытых'])}{totals.week ? ` · ${totals.week} на этой неделе` : ''}</p>
      {/if}
    </div>
    {#if people.length}
      <AvStack {people} size={28} {me} max={5} />
      <button type="button" class="sp-btn" onclick={onshare}>Участники</button>
    {:else if onshare}
      <button type="button" class="sp-btn" onclick={onshare}>{sphere.shared ? 'Пригласить' : 'Сделать общей'}</button>
    {/if}
    <button type="button" class="sp-btn" onclick={onedit}>Изменить сферу</button>
    <button type="button" class="sp-btn sp-btn-primary" onclick={onaddlist}>＋ Список в сферу</button>
  </header>

  <div class="sv-body">
    <section class="sv-cards" aria-label="Списки сферы">
      {#each cards as c (c.l.id)}
        <article class="lc" style="--sc: {sphereColor(sphere)}">
          <div class="lc-h"><h3>{c.l.title}</h3><span>{c.tpl.name}</span></div>
          <div class="lc-cols" aria-label="Колонки шаблона">
            {#each c.tpl.cols as col (col.id)}<i class:on={c.per[col.id] > 0} title="{col.name}: {c.per[col.id] ?? 0}">{col.name}</i>{/each}
          </div>
          <div class="stat"><span><b>{c.open}</b>открыто</span><span><b>{c.week}</b>на неделе</span><span><b>{c.month}</b>за месяц</span></div>
          <p class="nx">Ближайшее: {#if c.next}<button type="button" class="link2" onclick={() => onopentask(c.next, c.l.id)}>{c.next.title}</button> · {humanDue(c.next.due)}{:else}<span class="muted">сроков нет</span>{/if}</p>
          <button type="button" class="sp-btn" style="align-self: flex-start; min-height: 30px" onclick={() => onopenlist(c.l.id)}>Открыть доску →</button>
        </article>
      {:else}
        <p class="empty">В сфере пока нет списков. Добавь существующий через «Изменить сферу» или создай новый — «＋ Список в сферу».</p>
      {/each}
    </section>

    <aside class="sv-urg" aria-label="Срочное в сфере">
      <p class="cap">Срочное в сфере</p>
      {#each urgent as u (u.t.id)}
        {@const d = dueToYmd(u.t.due)}
        <button type="button" class="urg" onclick={() => onopentask(u.t, u.l.id)}>
          <span class="dt" style="background: {sphereColor(sphere)}"></span>
          <span class="ut">{u.t.title}<small>{u.l.title}</small></span>
          <span class="uw" class:over={d < today} class:now={d === today}>{d < today ? 'просрочено' : humanDue(u.t.due)}</span>
        </button>
      {:else}
        <p class="hint">Ничего горящего. Можно спокойно работать.</p>
      {/each}
      <p class="hint">Сфера в «Сегодня» и «Календаре» (чип над списком) показывает только её задачи.</p>
    </aside>
  </div>
</div>
