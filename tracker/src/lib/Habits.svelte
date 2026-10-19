<script>
  import { stats, plural, scheduleLabel, WEEKDAYS, MILESTONES, nextMilestone, milestonePos } from './habits.js';
  import { ymd } from './api.js';
  import Coon from './Coon.svelte';

  // habits: [{ id, name, days, createdAt }]; log — отметки из слоя; cele — свежая веха { id, text, n }.
  let { habits, log, cele = null, ontoggle, onclosecele, oncreate, onupdate, ondelete } = $props();

  const WEEK = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
  const MONTHS = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  const now = new Date();
  const dateLine = `${WEEK[now.getDay()]} · ${now.getDate()} ${MONTHS[now.getMonth()]} ${now.getFullYear()}`;
  const today = ymd(now);
  const ALL = [0, 1, 2, 3, 4, 5, 6];
  const WORKDAYS = [0, 1, 2, 3, 4];

  const rows = $derived(habits.map((h) => {
    const s = stats(h, log);
    const daily = !h.days?.length || h.days.length === 7;
    const forms = daily ? ['день', 'дня', 'дней'] : ['занятие', 'занятия', 'занятий'];
    const next = nextMilestone(s.streak);
    let note;
    if (s.streak === 0) note = s.best ? `Лучшая серия: ${s.best} ${plural(s.best, forms)}` : 'Отметь сегодня — и серия начнётся.';
    else if (s.streak >= MILESTONES[MILESTONES.length - 1]) note = `Все вехи взяты! Лучшая — ${s.best}.`;
    else note = `До вехи ${next}: ${next - s.streak} ${plural(next - s.streak, forms)} · лучшая ${s.best}`;
    return {
      h, s, forms, unit: plural(s.streak, forms), note,
      short: h.name.split(/[\s,]/)[0],
    };
  }));

  const doneToday = $derived(rows.filter((r) => r.s.todayDone).length);
  const active = $derived(rows.filter((r) => r.s.streak > 0).length);
  const top = $derived(rows.slice().sort((a, b) => b.s.streak - a.s.streak)[0]);
  const headline = $derived.by(() => {
    if (!rows.length) return 'Начни с одной маленькой привычки.';
    if (doneToday === rows.length) return 'Сегодня всё отмечено — серии в безопасности.';
    if (top && top.s.streak >= 7) return `Серии растут: «${top.h.name}» — ${top.s.streak} ${top.unit} подряд.`;
    const left = rows.length - doneToday;
    return `Осталось отметить ${left} ${plural(left, ['привычку', 'привычки', 'привычек'])}.`;
  });
  // Реплика енота: ближайшая веха, которую можно взять сегодня.
  const say = $derived.by(() => {
    if (cele) return 'Флажок поднят! Так держать.';
    if (!rows.length) return 'Привет! Добавь первую привычку — я буду считать серии.';
    if (doneToday === rows.length) return 'Все на сегодня. Енот гордится.';
    const close = rows.filter((r) => !r.s.todayDone && MILESTONES.includes(r.s.streak + 1))[0];
    if (close) return `«${close.short}» — ${close.s.streak} ${close.unit}. Отметь сегодня, и будет веха: ${close.s.streak + 1}!`;
    const left = rows.length - doneToday;
    return `Осталось ${left} на сегодня. Маленький шаг тоже считается.`;
  });

  // Форма новой привычки и редактирования
  let editing = $state(null); // null | 'new' | id
  let fName = $state('');
  let fDays = $state(ALL);
  let fTime = $state(''); // время привычки, «ЧЧ:ММ» или пусто
  let confirmDelete = $state(false);

  function openForm(h = null) {
    editing = h ? h.id : 'new';
    fName = h?.name ?? '';
    fDays = h?.days?.length ? [...h.days] : ALL;
    fTime = h?.time ?? '';
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
    if (editing === 'new') await oncreate(name, days, fTime || null);
    else await onupdate(editing, { name, days, time: fTime || null });
    editing = null;
  }

  function cellTitle(c) {
    const what = { done: 'сделано', miss: 'пропуск', rest: 'не по расписанию', today: 'сегодня', before: 'привычки ещё не было', plan: 'по плану', off: 'выходной, серия сохранена', future: '' }[c.state];
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
    <div class="days">
      <label class="h-time">Время <input type="time" bind:value={fTime} aria-label="Время привычки" /></label>
      {#if fTime}<button type="button" class="sp-btn sp-btn-ghost" style="min-height: 30px" onclick={() => (fTime = '')}>Без времени</button>{:else}<span class="hint-t">необязательно — например, 20:00 для вечернего скетча</span>{/if}
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

{#snippet check()}<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>{/snippet}

<section class="h-hero">
  <div class="in">
    <div class="hh">
      <p class="date">{dateLine}</p>
      <h1>{headline}</h1>
      <dl class="stats">
        <div><dt>Сегодня отмечено</dt><dd>{doneToday} из {rows.length}</dd></div>
        <div><dt>Серий идёт</dt><dd>{active}</dd></div>
        {#if top && top.s.streak > 0}<div><dt>Самая длинная</dt><dd class="gold">✦ {top.s.streak} {top.unit}</dd></div>{/if}
      </dl>
    </div>
    <div class="t-coon">
      <p class="bubble" aria-live="polite">{say}</p>
      <Coon pose={cele ? 'cheer' : 'flag'} size={130} />
    </div>
  </div>
</section>

<div class="habits-page">
  <div class="h-today">
    {#if rows.length}
      <section class="pills" aria-label="Отметить сегодня">
        <span class="cap">Сегодня</span>
        {#each rows as r (r.h.id)}
          <button type="button" class="pill" aria-pressed={r.s.todayDone} onclick={() => ontoggle(r.h)}
            title="{r.h.name}{r.s.todayDone ? ' — сделано' : ' — отметить'}">
            <span class="o">{@render check()}</span>{r.short}
            <small>{r.s.todayDone ? `✦ ${r.s.streak}` : r.h.time ? r.h.time : r.s.streak ? `${r.s.streak} →` : 'старт'}</small>
          </button>
        {/each}
      </section>
    {/if}
    <button class="sp-btn sp-btn-primary" type="button" onclick={() => openForm()}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>Новая привычка
    </button>
  </div>

  {#if cele}
    <div class="cele" role="status">
      <Coon pose="cheer" size={104} />
      <div class="ct">
        <p class="k">Новая веха</p>
        <p class="tt">{cele.text}</p>
        <p class="sub">Уведомление Windows и сообщение бота в Telegram уже в пути. Следующая веха — {nextMilestone(cele.n)}.</p>
      </div>
      <button class="sp-btn sp-btn-primary" type="button" onclick={onclosecele}>Ура!</button>
    </div>
  {/if}

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
              <p>{scheduleLabel(r.h.days)}{r.h.time ? ` · ${r.h.time}` : ''}</p>
            </div>
            <button type="button" class="hmark" aria-pressed={r.s.todayDone} onclick={() => ontoggle(r.h)}>
              {@render check()}{r.s.todayDone ? 'Сделано сегодня' : 'Отметить сегодня'}
            </button>
          </header>

          <div class="habit-body">
            <div style="flex: 1 1 200px; min-width: 0">
              {#if r.s.streak === 0}
                <div class="zero">
                  <Coon pose="sleep" size={72} />
                  <p>Серия на паузе. Отметь сегодня — и енот проснётся.</p>
                </div>
              {:else}
                <div class="streak">
                  <span class="num" class:hot={r.s.streak >= 7}>{r.s.streak}</span>
                  <span class="unit">{r.unit} подряд</span>
                </div>
              {/if}
              <div class="ms-wrap">
                <div class="ms" aria-hidden="true">
                  <span style="width: {milestonePos(r.s.streak)}%"></span>
                  {#each MILESTONES as m (m)}<i class:on={r.s.streak >= m} style="left: {milestonePos(m)}%"></i>{/each}
                </div>
                <div class="ms-l" aria-hidden="true">
                  {#each MILESTONES as m (m)}<span class:on={r.s.streak >= m} style="left: {milestonePos(m)}%">{m}</span>{/each}
                </div>
                <p class="note">{r.note}</p>
              </div>
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
    <span><i class="c plan"></i>по плану</span>
    <span><i class="c before"></i>привычки ещё не было</span>
    <span><i class="c today"></i>сегодня</span>
    <span><i class="dotg"></i>вехи 7 · 21 · 50 · 100 — енот празднует</span>
  </div>
</div>
