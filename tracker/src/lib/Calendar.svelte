<script>
  import { onMount, tick } from 'svelte';
  import { ymd, dueToYmd } from './api.js';
  import { stats } from './habits.js';
  import * as cal from './calendar.js';
  import * as keys from './keys.js';
  import { pickNext } from './meta.js';
  import CalWeek from './CalWeek.svelte';
  import CalMonth from './CalMonth.svelte';
  import DateTimePicker from './DateTimePicker.svelte';
  import Coon from './Coon.svelte';

  let { lists, tasksByList, layTasks, log, habits, typeOf, loadEvents, syncAt,
    onopen, ontoggle, ontogglehabit, onschedule, oncreatetask, oncreateevent, oncreatebirthday, reloadKey = 0 } = $props();

  // Вид и фильтры запоминаем на этом компьютере — это удобство, не данные.
  const remember = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} };
  const recall = (k, d) => { try { return JSON.parse(localStorage.getItem(k)) ?? d; } catch { return d; } };

  let clock = $state(Date.now());
  const today = $derived(ymd(new Date(clock)));
  let mode = $state(recall('cal.mode', 'week'));
  let show = $state({ events: true, tasks: true, habits: true, birthdays: true, ...recall('cal.show', {}) });
  let sel = $state(ymd(new Date()));
  let habitsOpen = $state(true);
  let stripOpen = $state(false);
  let events = $state([]);
  let evErr = $state('');
  let planned = $state(null);
  let planning = $state(false);
  let reload = $state(0); // перечитать события после создания своего
  // Форма «＋ Добавить на этот день» в панели дня.
  let cmp = $state({ open: false, title: '', kind: 'task', time: 'all', end: '', listId: '' }); // end — конец из окна «Когда»
  let cmpPick = $state(false);
  function applyCmpWhen(r) {
    cmpPick = false;
    if (r.day) sel = r.day;
    cmp.time = r.slot?.s ?? 'all';
    cmp.end = r.slot?.e ?? '';
  }
  let cmpBusy = $state(false);
  let cmpInput = $state(null);
  // Неделя на широком окне укладывается в экран без прокрутки: сетка занимает оставшуюся высоту.
  let wide = $state(true);
  let gridAvail = $state(0);
  const fit = $derived(mode === 'week' && wide);

  onMount(() => {
    const t = setInterval(() => (clock = Date.now()), 60e3);
    const mq = matchMedia('(min-width: 1100px)');
    const onMq = () => (wide = mq.matches);
    onMq();
    mq.addEventListener('change', onMq);
    return () => { clearInterval(t); mq.removeEventListener('change', onMq); };
  });

  $effect(() => remember('cal.mode', mode));
  $effect(() => remember('cal.show', $state.snapshot(show)));

  const days = $derived(cal.periodDays(sel, mode));
  const selMonth = $derived(cal.parseYmd(sel).getMonth());

  // События за видимый период; перезагружаем при смене периода и после каждой синхронизации.
  $effect(() => {
    syncAt; reload; reloadKey;
    const start = cal.parseYmd(days[0]);
    const end = cal.addDays(cal.parseYmd(days[days.length - 1]), 1);
    let alive = true;
    loadEvents(start, end)
      .then((evs) => { if (alive) { events = evs; evErr = ''; } })
      .catch((e) => { if (alive) evErr = String(e); });
    return () => { alive = false; };
  });

  const evDays = $derived(cal.eventsByDay(events, days));
  const taskDays = $derived(cal.tasksByDay(lists, tasksByList, layTasks, typeOf, days));
  const allItems = $derived(Object.fromEntries(days.map((d) => [d, [...(evDays[d] ?? []), ...(taskDays[d] ?? [])]])));
  const visible = (it) => (it.kind === 'event' ? show.events : it.kind === 'task' ? show.tasks : it.kind === 'birthday' ? show.birthdays : true);
  const ORDER = { holiday: 0, birthday: 1, task: 2, event: 3 };
  const byTime = (a, b) => (a.s ?? -1) - (b.s ?? -1) || ORDER[a.kind] - ORDER[b.kind];

  // Сутки 0–24: часы, где за неделю что-то есть (и текущий, черновик, свободное окно), — полные, остальные сжаты.
  const timedWeek = $derived(days.flatMap((d) => (allItems[d] ?? []).filter((i) => visible(i) && i.s != null)));
  const layout = $derived.by(() => {
    const hot = [];
    if (days.includes(today)) hot.push(Math.floor(cal.nowMin() / 60));
    if (cmp.open && cmp.time !== 'all' && days.includes(sel)) hot.push(+cmp.time.slice(0, 2));
    if (free) for (let h = Math.floor(free.s / 60); h < Math.ceil(free.e / 60); h++) hot.push(h);
    return cal.hourLayout(timedWeek, hot, fit ? gridAvail : 0);
  });

  const dayObjs = $derived(days.map((day) => {
    const items = (allItems[day] ?? []).filter(visible).sort(byTime);
    const hs = habits.map((h) => ({ h, ...cal.habitDay(h, log, day, today) }));
    const sched = hs.filter((x) => x.sched);
    const lbl = cal.dayLabel(day);
    const holiday = (allItems[day] ?? []).find((i) => i.kind === 'holiday')?.title ?? '';
    return {
      ymd: day, ...lbl, items, holiday,
      isToday: day === today, isSel: day === sel, future: day > today, weekend: cal.WD_SHORT.indexOf(lbl.short) >= 5,
      allday: items.filter((i) => i.s == null),
      blocks: mode === 'week' ? cal.layoutBlocks(items, layout.yAt) : [],
      habits: hs, hSched: sched.length, hDone: sched.filter((x) => x.done).length,
    };
  }));
  const selDay = $derived(dayObjs.find((d) => d.ymd === sel) ?? dayObjs[0]);

  // ---------- обзор недели ----------

  const free = $derived(mode === 'week' && show.tasks && !planned ? cal.bestWindow(allItems, days) : null);
  const candidate = $derived.by(() => {
    const open = lists.flatMap((l) => (tasksByList[l.id] ?? [])
      .filter((t) => !t.parent && t.status !== 'completed' && !layTasks?.[t.id]?.slot)
      .map((t) => ({ task: t, listId: l.id })));
    return pickNext(open, layTasks, today); // просроченное → приоритет → срок
  });

  const AT = ['в понедельник', 'во вторник', 'в среду', 'в четверг', 'в пятницу', 'в субботу', 'в воскресенье'];
  const whenAt = (day) => (day === today ? 'сегодня' : cal.whenLabel(day) === 'завтра' ? 'завтра' : AT[cal.WD_SHORT.indexOf(cal.dayLabel(day).short)]);
  const span = (s, e) => `${cal.fromMin(s)}–${cal.fromMin(e)}`;

  const coon = $derived.by(() => {
    if (planned) return { pose: 'flag', text: `Готово: ${whenAt(planned.day)}, ${span(planned.s, planned.e)} — «${planned.title}». Удачного полёта.`, cta: 'Отменить' };
    if (free && candidate) return { pose: 'think', text: `Самое свободное окно — ${whenAt(free.day)}, ${span(free.s, free.e)}. Отдать его под «${candidate.task.title || 'Без названия'}»?`, cta: 'Запланировать' };
    if (free) return { pose: 'think', text: `Самое свободное окно — ${whenAt(free.day)}, ${span(free.s, free.e)}. Поставить туда новую задачу?`, cta: 'Создать задачу' };
    if (!show.tasks) return { pose: 'sleep', text: 'Задачи скрыты фильтром — включи «Задачи», и я найду свободное окно.' };
    if (days[days.length - 1] < today) return { pose: 'sleep', text: 'Эта неделя уже позади. Загляни на следующую — там есть место для планов.' };
    return { pose: 'sleep', text: 'Свободных окон от часа на этой неделе не осталось. Плотно — береги силы.' };
  });

  async function coonAction() {
    if (planning) return;
    if (planned) {
      const p = planned;
      planning = true;
      const cur = (tasksByList[p.listId] ?? []).find((t) => t.id === p.task.id) ?? p.task;
      try { await onschedule(cur, p.listId, p.prev.due ? dueToYmd(p.prev.due) : null, p.prev.slot); planned = null; }
      finally { planning = false; }
      return;
    }
    if (!free) return;
    if (!candidate) return compose(free.day, cal.fromMin(free.s));
    const w = free, c = candidate;
    const prev = { due: c.task.due ?? null, slot: layTasks?.[c.task.id]?.slot ?? null };
    planning = true;
    try {
      const ok = await onschedule(c.task, c.listId, w.day, { s: cal.fromMin(w.s), e: cal.fromMin(w.e) });
      if (ok) planned = { task: c.task, listId: c.listId, title: c.task.title || 'Без названия', day: w.day, s: w.s, e: w.e, prev };
    } finally { planning = false; }
  }
  // Ушли на другую неделю — предложение «Отменить» больше не к месту.
  $effect(() => { days[0]; planned = null; });

  const load = $derived(mode === 'week' ? dayObjs.map((d) => ({ d, min: cal.busyMinutes(allItems[d.ymd] ?? []) })) : []);
  const maxLoad = $derived(Math.max(60, ...load.map((l) => l.min)));
  const loadNote = $derived.by(() => {
    const total = load.reduce((m, l) => m + l.min, 0);
    if (!total) return 'В сетке недели пока пусто — всё время свободно.';
    const peak = load.reduce((a, b) => (b.min > a.min ? b : a));
    return `Занято ${cal.hoursLabel(total)} из 84. Самый плотный день — ${peak.d.short}, ${cal.hoursLabel(peak.min)}.`;
  });

  const upcoming = $derived(mode === 'week'
    ? dayObjs.flatMap((d) => (allItems[d.ymd] ?? []).filter((i) => i.kind === 'task' || i.kind === 'birthday' || i.kind === 'holiday').map((i) => ({ ...i, day: d.ymd })))
        .sort((a, b) => a.day.localeCompare(b.day) || ORDER[a.kind] - ORDER[b.kind])
    : []);

  // ---------- панель дня ----------

  const panelHabits = $derived(selDay.habits.filter((x) => x.sched).map((x) => ({
    ...x,
    meta: x.isToday ? ((s) => (s ? `${s} дн. подряд` : 'серия с нуля'))(stats(x.h, log).streak) : x.future ? 'по плану' : x.done ? 'сделано' : 'пропуск',
  })));
  const habitHead = $derived(selDay.isToday ? 'Привычки на сегодня' : selDay.future ? 'Привычки по плану' : 'Привычки');

  // ---------- навигация ----------

  function pick(day) { if (day !== sel) cmp.open = false; sel = day; }

  // ---------- форма «＋ Добавить на этот день» ----------

  const TIMES = ['all', '10:00', '14:00', '19:00'];
  const cmpTimes = $derived(cmp.time !== 'all' && !TIMES.includes(cmp.time) ? [...TIMES, cmp.time] : TIMES);
  const cmpList = $derived(cmp.listId && lists.some((l) => l.id === cmp.listId) ? cmp.listId : lists[0]?.id ?? '');
  const shortDay = (day) => { const d = cal.parseYmd(day); return `${d.getDate()} ${cal.MONTH_GEN[d.getMonth()].slice(0, 3)}.`; };
  const cmpHint = $derived(cmp.kind === 'event'
    ? 'Событие попадёт в Google Календарь.'
    : cmp.kind === 'birthday' ? 'Каждый год в этот день — в Google Календаре, здесь золотом.'
    : `Задача попадёт в Google Tasks, список «${lists.find((l) => l.id === cmpList)?.title ?? '—'}»${cmp.time === 'all' ? ', со сроком на этот день.' : ', и встанет в сетку на это время.'}`);

  async function compose(day, time = 'all', title = '') {
    sel = day;
    cmp = { ...cmp, open: true, title, time, kind: cmp.kind };
    await tick();
    cmpInput?.focus();
  }
  async function createCmp() {
    const title = cmp.title.trim();
    if (!title || cmpBusy) return;
    cmpBusy = true;
    const slot = cmp.time === 'all' ? null : { s: cmp.time, e: cmp.end && cmp.end > cmp.time ? cmp.end : cal.fromMin(Math.min(cal.toMin(cmp.time) + 60, 1439)) };
    const ok = cmp.kind === 'event' ? await oncreateevent({ title, day: sel, slot })
      : cmp.kind === 'birthday' ? await oncreatebirthday({ name: title, day: sel })
      : await oncreatetask({ title, listId: cmpList, due: sel, slot });
    cmpBusy = false;
    if (!ok) return;
    if (cmp.kind !== 'task') reload++;
    cmp = { ...cmp, open: false, title: '', time: 'all' };
  }
  function cmpKey(e) {
    if (e.key === 'Enter') { e.preventDefault(); createCmp(); }
    else if (e.key === 'Escape') { e.stopPropagation(); cmp.open = false; }
  }
  function openHabits(day) { sel = day; habitsOpen = true; }
  const toggleItem = (it) => ontoggle(it.task, !it.done, it.listId);
  const openItem = (it) => onopen(it.task, it.listId);
  // Клавиши календаря (по физической кнопке — работают и в русской раскладке).
  function key(e) {
    if (keys.typing(e) || !keys.plain(e) || e.shiftKey || keys.overlay()) return;
    if (e.key === 'ArrowLeft') sel = cal.shiftPeriod(sel, mode, -1);
    else if (e.key === 'ArrowRight') sel = cal.shiftPeriod(sel, mode, 1);
    else if (e.code === 'KeyT') sel = today;
    else if (e.code === 'KeyW') mode = 'week';
    else if (e.code === 'KeyM') mode = 'month';
    else if (e.code === 'KeyA') { e.preventDefault(); compose(sel, cmp.time); }
  }

  const FILTERS = [
    { key: 'events', label: 'События' },
    { key: 'tasks', label: 'Задачи' },
    { key: 'habits', label: 'Привычки' },
    { key: 'birthdays', label: 'Дни рождения' },
  ];
</script>

<svelte:window onkeydown={key} />

{#snippet mark(it)}
  <span class="mk k-{it.kind}" class:on={it.done} style="--c: {it.type ? cal.typeColor(it.type) : 'var(--ink-soft)'}"></span>
{/snippet}

<div class="cal" class:fit>
  <header class="cal-bar">
    <div class="tb">
      <h1>{cal.periodTitle(sel, mode)}</h1>
      <span class="arrows">
        <button class="sp-btn sp-btn-ghost" type="button" aria-label="Назад" title="Назад (←)" onclick={() => (sel = cal.shiftPeriod(sel, mode, -1))}>‹</button>
        <button class="sp-btn sp-btn-ghost" type="button" aria-label="Вперёд" title="Вперёд (→)" onclick={() => (sel = cal.shiftPeriod(sel, mode, 1))}>›</button>
      </span>
      <button class="sp-btn" type="button" style="min-height: 30px" onclick={() => (sel = today)}>Сегодня</button>
      {#if evErr}<span class="cal-err" title={evErr}>События не загрузились</span>{/if}
    </div>
    <div class="tb">
      <div class="tb" role="group" aria-label="Что показывать" style="gap: 6px">
        {#each FILTERS as f (f.key)}
          <button type="button" class="chipf" aria-pressed={show[f.key]} onclick={() => (show[f.key] = !show[f.key])}><span class="fm {f.key}"></span>{f.label}</button>
        {/each}
      </div>
      <div class="seg" role="group" aria-label="Вид">
        <button type="button" aria-pressed={mode === 'week'} onclick={() => (mode = 'week')}>Неделя</button>
        <button type="button" aria-pressed={mode === 'month'} onclick={() => (mode = 'month')}>Месяц</button>
      </div>
    </div>
  </header>

  <div class="cal-body">
    <main class="cal-main">
      {#if mode === 'week'}
        <CalWeek days={dayObjs} {habits} {show} {free} {clock} {layout} {stripOpen} {fit} bind:avail={gridAvail}
          draft={cmp.open && cmp.time !== 'all' ? { day: sel, time: cmp.time, title: cmp.title } : null}
          ontogglestrip={() => (stripOpen = !stripOpen)}
          onpick={pick} onopenhabits={openHabits} onopen={openItem} ontoggle={toggleItem} {ontogglehabit}
          oncompose={(day, time) => compose(day, time)} />

        <section class="cal-over" aria-label="Обзор недели">
          <div class="card">
            <p class="cap">Загрузка недели</p>
            <div class="bars">
              {#each load as l (l.d.ymd)}
                <div class="bar" title="{l.d.short}: занято {cal.hoursLabel(l.min)} из 12">
                  <span class="h">{cal.hoursLabel(l.min)}</span>
                  <span class="b" class:today={l.d.isToday} class:weekend={l.d.weekend} style="height: {Math.max(3, Math.round((l.min / maxLoad) * 56))}px"></span>
                  <span class="w" class:today={l.d.isToday}>{l.d.short}</span>
                </div>
              {/each}
            </div>
            <p class="note">{loadNote}</p>
          </div>

          <div class="card">
            <p class="cap">Сроки и даты недели</p>
            {#each upcoming.slice(0, 6) as u (u.id)}
              <div class="up">
                {@render mark(u)}
                {#if u.kind === 'task'}
                  <button type="button" class="tx link k-{u.kind}" class:done={u.done} class:over={u.overdue} onclick={() => openItem(u)}>{u.title}</button>
                {:else}
                  <span class="tx k-{u.kind}">{u.title}</span>
                {/if}
                <span class="when" class:today={u.day === today} class:gold={u.kind === 'birthday'}>{cal.whenLabel(u.day)}</span>
              </div>
            {:else}
              <p class="note" style="margin: 0">На этой неделе сроков и праздников нет.</p>
            {/each}
            {#if upcoming.length > 6}<p class="note">и ещё {upcoming.length - 6}</p>{/if}
          </div>

          <div class="card coon-card">
            <Coon pose={coon.pose} size={104} />
            <div class="coon-text">
              <p class="cap" style="margin: 0">Енот на орбите</p>
              <p class="tip">{coon.text}</p>
              {#if coon.cta}<button class="sp-btn" type="button" style="align-self: flex-start; min-height: 30px" disabled={planning} onclick={coonAction}>{coon.cta}</button>{/if}
            </div>
          </div>
        </section>
      {:else}
        <CalMonth days={dayObjs} month={selMonth} {show} onpick={pick} onopenhabits={openHabits} />
      {/if}
    </main>

    <aside class="cal-day" aria-label="Выбранный день">
      <div>
        <p class="wd">{selDay.weekday}{selDay.isToday ? ' · сегодня' : ''}</p>
        <h2>{selDay.title}</h2>
      </div>

      {#if show.habits && panelHabits.length}
        <div>
          <button type="button" class="hsec" aria-expanded={habitsOpen} onclick={() => (habitsOpen = !habitsOpen)}>
            <span class="hs-main">
              <span class="hs-title">{habitHead}</span>
              <span class="hs-bar"><span style="width: {selDay.future ? 0 : Math.round((selDay.hDone / Math.max(1, selDay.hSched)) * 100)}%"></span></span>
            </span>
            <span class="hs-n">{selDay.future ? `${selDay.hSched} шт.` : `${selDay.hDone} из ${selDay.hSched}`}</span>
            <svg viewBox="0 0 24 24" aria-hidden="true" class:flip={habitsOpen}><path d="M6 9l6 6 6-6" /></svg>
          </button>
          {#if habitsOpen}
            <div class="hlist">
              {#each panelHabits as x (x.h.id)}
                <div class="hrow">
                  <button type="button" class="ring {x.done ? 'done' : x.isToday ? 'now' : x.future ? 'plan' : 'miss'}" disabled={!x.isToday}
                    aria-label="{x.h.name}{x.done ? ' — сделано' : x.isToday ? ' — отметить' : x.future ? ' — по плану' : ' — пропуск'}"
                    onclick={() => ontogglehabit(x.h)}>
                    {#if x.done}<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>{/if}
                  </button>
                  <span class="hn" class:soft={!x.done && !x.isToday}>{#if x.h.time}<span class="htime">{x.h.time}</span> {/if}{x.h.name}</span>
                  <span class="hmeta">{x.meta}</span>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      {/if}

      {#if selDay.allday.length}
        <div>
          <p class="cap">Весь день</p>
          {#each selDay.allday as a (a.id)}
            <div class="ag">
              {#if a.kind === 'task'}
                <input class="sp-check sm" type="checkbox" checked={a.done} aria-label="Выполнено" onchange={() => toggleItem(a)} />
                <button type="button" class="tx link" class:done={a.done} class:over={a.overdue} onclick={() => openItem(a)}>{a.title}<span class="sub">{a.list}</span></button>
              {:else}
                {@render mark(a)}
                <span class="tx k-{a.kind}">{a.title}{#if a.kind === 'event'}<span class="sub">{a.cal}</span>{/if}</span>
              {/if}
            </div>
          {/each}
        </div>
      {/if}

      <div>
        <p class="cap">Расписание</p>
        {#each selDay.items.filter((i) => i.s != null) as a (a.id)}
          <div class="ag">
            <time>{cal.fromMin(a.s)}</time>
            {#if a.kind === 'task'}
              <input class="sp-check sm" type="checkbox" checked={a.done} aria-label="Выполнено" onchange={() => toggleItem(a)} />
              <button type="button" class="tx link" class:done={a.done} onclick={() => openItem(a)}>{a.title}<span class="sub">до {cal.fromMin(Math.min(a.e, 1440))} · {a.list}</span></button>
            {:else}
              {@render mark(a)}
              <span class="tx">{a.title}<span class="sub">до {cal.fromMin(Math.min(a.e, 1440))} · {a.cal}</span></span>
            {/if}
          </div>
        {:else}
          {#if selDay.items.length}
            <p class="note" style="margin: 4px 0 0">По времени ничего нет.</p>
          {:else}
            <div class="free-day">
              <Coon pose="sleep" size={76} />
              <p>Свободный день. Енот советует не забивать его до отказа.</p>
            </div>
          {/if}
        {/each}
      </div>

      {#if cmp.open}
        <div class="cmp" role="group" aria-label="Новая запись">
          <p class="cap" style="margin: 0">Новое · {shortDay(sel)}, {cmp.time === 'all' ? 'весь день' : cmp.time}</p>
          <input bind:this={cmpInput} bind:value={cmp.title} type="text" aria-label="Название" placeholder={cmp.kind === 'birthday' ? 'Чей день рождения?' : 'Что запланировать?'} onkeydown={cmpKey} />
          <div class="seg2" role="group" aria-label="Тип">
            <button type="button" aria-pressed={cmp.kind === 'task'} onclick={() => (cmp.kind = 'task')}>Задача</button>
            <button type="button" aria-pressed={cmp.kind === 'event'} onclick={() => (cmp.kind = 'event')}>Событие</button>
            <button type="button" aria-pressed={cmp.kind === 'birthday'} onclick={() => (cmp.kind = 'birthday')}>День рождения</button>
          </div>
          {#if cmp.kind !== 'birthday'}<div class="seg2" role="group" aria-label="Время">
            {#each cmpTimes as t (t)}<button type="button" aria-pressed={cmp.time === t} onclick={() => { cmp.time = t; cmp.end = ''; }}>{t === 'all' ? 'весь день' : cmp.end && t === cmp.time ? `${t}–${cmp.end}` : t}</button>{/each}
            <button type="button" title="Другой день или точное время" onclick={() => (cmpPick = true)}>Другое время…</button>
          </div>{/if}
          {#if cmp.kind === 'task' && lists.length > 1}
            <select class="cmp-list" aria-label="Список" value={cmpList} onchange={(e) => (cmp.listId = e.currentTarget.value)}>
              {#each lists as l (l.id)}<option value={l.id}>{l.title}</option>{/each}
            </select>
          {/if}
          <p class="cmp-hint">{cmpHint}</p>
          <div style="display: flex; gap: 6px">
            <button class="sp-btn sp-btn-primary" type="button" style="min-height: 32px" disabled={!cmp.title.trim() || cmpBusy || (cmp.kind === 'task' && !cmpList)} onclick={createCmp}>Создать</button>
            <button class="sp-btn sp-btn-ghost" type="button" style="min-height: 32px" onclick={() => (cmp.open = false)}>Отмена</button>
          </div>
        </div>
      {:else}
        <button type="button" class="addday" onclick={() => compose(sel)}>＋ Добавить на {shortDay(sel)}</button>
      {/if}
    </aside>
  </div>
</div>

{#if cmpPick}
  <DateTimePicker day={sel} slot={cmp.time === 'all' ? null : { s: cmp.time, e: cmp.end || cal.fromMin(Math.min(cal.toMin(cmp.time) + 60, 1439)) }}
    title={cmp.title} {loadEvents} onapply={applyCmpWhen} onclose={() => (cmpPick = false)} />
{/if}
