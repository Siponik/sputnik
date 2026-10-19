<script>
  import { stats, plural, scheduleLabel, WEEKDAYS } from './habits.js';

  // habits: [{ id, name, days, createdAt }]; log — отметки из слоя.
  let { habits, log, ontoggle, oncreate, onupdate, ondelete } = $props();

  const WEEK = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
  const MONTHS = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  const now = new Date();
  const dateLine = `${WEEK[now.getDay()]} · ${now.getDate()} ${MONTHS[now.getMonth()]} ${now.getFullYear()}`;
  const ALL = [0, 1, 2, 3, 4, 5, 6];
  const WORKDAYS = [0, 1, 2, 3, 4];

  const rows = $derived(habits.map((h) => {
    const s = stats(h, log);
    const daily = !h.days?.length || h.days.length === 7;
    const forms = daily ? ['день', 'дня', 'дней'] : ['занятие', 'занятия', 'занятий'];
    let note;
    if (s.streak === 0 && s.best > 0) note = `Серия прервалась · лучшая ${s.best} ${plural(s.best, forms)}`;
    else if (s.best > 0) note = `Лучшая серия: ${s.best} ${plural(s.best, forms)}`;
    else note = 'Отметь сегодня — и серия начнётся';
    return { h, s, unit: plural(s.streak, forms), note, record: s.streak > 0 && s.streak >= s.best && s.best >= 7 };
  }));

  const doneToday = $derived(rows.filter((r) => r.s.todayDone).length);
  const active = $derived(rows.filter((r) => r.s.streak > 0).length);
  const top = $derived(rows.slice().sort((a, b) => b.s.streak - a.s.streak)[0]);
  const headline = $derived.by(() => {
    if (!rows.length) return 'Начни с одной маленькой привычки.';
    if (doneToday === rows.length) return 'Всё на сегодня отмечено — серии растут.';
    if (top && top.s.streak >= 7) return `Серии растут: «${top.h.name}» идёт ${top.s.streak} ${top.unit} подряд.`;
    const left = rows.length - doneToday;
    return `Осталось отметить ${left} ${plural(left, ['привычку', 'привычки', 'привычек'])}.`;
  });

  // Форма новой привычки и редактирования
  let editing = $state(null); // null | 'new' | id
  let fName = $state('');
  let fDays = $state(ALL);
  let confirmDelete = $state(false);

  function openForm(h = null) {
    editing = h ? h.id : 'new';
    fName = h?.name ?? '';
    fDays = h?.days?.length ? [...h.days] : ALL;
    confirmDelete = false;
  }
  function toggleDay(d) {
    fDays = fDays.includes(d) ? fDays.filter((x) => x !== d) : [...fDays, d].sort();
  }
  async function submit(e) {
    e.preventDefault();
    const name = fName.trim();
    if (!name || !fDays.length) return;
    const days = fDays.length === 7 ? [] : fDays;
    if (editing === 'new') await oncreate(name, days);
    else await onupdate(editing, { name, days });
    editing = null;
  }

  function cellTitle(c) {
    const what = { done: 'сделано', miss: 'пропуск', rest: 'не по расписанию', today: 'сегодня', before: 'до начала', future: '' }[c.state];
    return what ? `${c.title} · ${what}` : c.title;
  }
</script>

{#snippet form()}
  <form class="habit-form" onsubmit={submit}>
    <input bind:value={fName} placeholder="Например: скетч 20 минут" aria-label="Название привычки" />
    <div class="days" role="group" aria-label="Дни">
      {#each WEEKDAYS as w, d (w)}
        <button type="button" class="day" aria-pressed={fDays.includes(d)} onclick={() => toggleDay(d)}>{w}</button>
      {/each}
      <button type="button" class="sp-btn sp-btn-ghost" style="min-height: 30px" onclick={() => (fDays = ALL)}>Каждый день</button>
      <button type="button" class="sp-btn sp-btn-ghost" style="min-height: 30px" onclick={() => (fDays = WORKDAYS)}>По будням</button>
    </div>
    <div class="actions">
      {#if editing !== 'new'}
        {#if confirmDelete}
          <button class="sp-btn" type="button" style="color: var(--signal-overdue); border-color: currentColor" onclick={() => { ondelete(editing); editing = null; }}>Удалить вместе с историей</button>
        {:else}
          <button class="sp-btn sp-btn-ghost" type="button" onclick={() => (confirmDelete = true)}>Удалить</button>
        {/if}
      {/if}
      <span style="flex: 1"></span>
      <button class="sp-btn sp-btn-ghost" type="button" onclick={() => (editing = null)}>Отмена</button>
      <button class="sp-btn sp-btn-primary" type="submit" disabled={!fName.trim() || !fDays.length}>{editing === 'new' ? 'Добавить' : 'Сохранить'}</button>
    </div>
  </form>
{/snippet}

<section class="today-hero habits-hero">
  <div>
    <p class="date">{dateLine}</p>
    <h1>{headline}</h1>
  </div>
  <dl class="stats">
    <div><dt>Сегодня отмечено</dt><dd>{doneToday} из {rows.length}</dd></div>
    <div><dt>Серий идёт</dt><dd>{active}</dd></div>
    {#if top && top.s.streak > 0}
      <div><dt>Самая длинная сейчас</dt><dd class="gold">✦ {top.s.streak} {top.unit} · {top.h.name}</dd></div>
    {/if}
  </dl>
</section>

<div class="habits-page">
  <div class="habits-bar">
    <button class="sp-btn sp-btn-primary" type="button" onclick={() => openForm()}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>Новая привычка
    </button>
  </div>
  {#if editing === 'new'}<div class="habit">{@render form()}</div>{/if}

  <div class="habits-grid">
    {#each rows as r (r.h.id)}
      <article class="habit">
        {#if editing === r.h.id}
          {@render form()}
        {:else}
          <header>
            <div style="flex: 1 1 200px; min-width: 0">
              <h2><button class="name" type="button" title="Изменить" onclick={() => openForm(r.h)}>{r.h.name}</button></h2>
              <p>{scheduleLabel(r.h.days)}</p>
            </div>
            <button type="button" class="sp-mark" aria-pressed={r.s.todayDone} onclick={() => ontoggle(r.h)}>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>{r.s.todayDone ? 'Сделано сегодня' : 'Отметить сегодня'}
            </button>
          </header>

          <div class="habit-body">
            <div style="flex: 1 1 180px; min-width: 0">
              <div class="streak">
                <span class="num" class:zero={r.s.streak === 0} class:hot={r.s.streak >= 7}>{r.s.streak}</span>
                <span class="unit">{r.unit} подряд</span>
              </div>
              {#if r.record}<p class="record">✦ Новый рекорд</p>{/if}
              <p class="note">{r.note}</p>
            </div>

            <figure class="heat" aria-label="Отметки за 13 недель: {r.h.name}">
              <div class="months">
                {#each r.s.months as m (m.col)}<span style="grid-column: {m.col + 2} / span 3">{m.name}</span>{/each}
              </div>
              <div style="display: flex; gap: 4px">
                <div class="wd"><span>пн</span><span></span><span>ср</span><span></span><span>пт</span><span></span><span>вс</span></div>
                <div class="hm">
                  {#each r.s.cells as c (c.date)}<span class="c {c.state}" class:now={c.today} title={cellTitle(c)}></span>{/each}
                </div>
              </div>
            </figure>
          </div>
        {/if}
      </article>
    {:else}
      {#if editing !== 'new'}<p class="empty">Привычек пока нет. Добавь первую — она появится в Google Tasks в списке «Привычки».</p>{/if}
    {/each}
  </div>

  <div class="legend">
    <span><i class="c done"></i>сделано</span>
    <span><i class="c miss"></i>пропуск</span>
    <span><i class="c rest"></i>не по расписанию</span>
    <span><i class="c today"></i>сегодня</span>
    <span class="tail">Привычки живут в Google Tasks, серии считает Спутник.</span>
  </div>
</div>
