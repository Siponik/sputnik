<script>
  import { onMount } from 'svelte';
  import { dueToYmd, ymd, humanDue } from './api.js';
  import { stats, plural, isDone, goalN, countOn, unitForms } from './habits.js';
  import { habitDay, fromMin, toMin, nowMin, MONTH_GEN } from './calendar.js';
  import Coon from './Coon.svelte';
  import ListPick from './ListPick.svelte';
  import { priorityOf, priorityRank, pickNext } from './meta.js';
  import { parseLine, route, learn } from './route.js';
  import { spheresFrom, sphereOf, sphereColor } from './spheres.js';
  import { understood, taskFrom } from './today.js';

  // layer — весь слой (для «Куда» и цвета сфер); onfull(text) — Shift+Enter, полное окно «Создать» с этим текстом;
  // onlearn — ручной выбор списка учит «Куда» (как в «Создать»); onaccept(items) — у пункта может быть dest (другой список).
  let { lists, tasksByList, events, layTasks, layer = {}, log, habits, inboxItems, inboxOn, inboxFocus, typeOf,
    onopen, ontoggle, oncreate, onreschedule = null, ontogglehabit, onaccept, onreject, onregister, onhabits, oncalendar,
    onfull = null, onlearn = null, filter = null } = $props();

  let clock = $state(Date.now());
  onMount(() => {
    const t = setInterval(() => (clock = Date.now()), 30e3);
    // Ctrl+N на этом экране — фокус в строку быстрого добавления.
    onregister?.(() => { input?.focus(); return !!input; });
    return () => { clearInterval(t); onregister?.(null); };
  });
  const today = $derived(ymd(new Date(clock)));
  const now = $derived((clock, nowMin()));

  const WEEK = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
  const dateLine = $derived.by(() => { const d = new Date(clock); return `${WEEK[d.getDay()]} · ${d.getDate()} ${MONTH_GEN[d.getMonth()]} ${d.getFullYear()}`; });

  // ---------- задачи ----------

  let fresh = $state(new Set()); // созданные в этом сеансе — метка «новая»

  const all = $derived(lists.flatMap((l) => (tasksByList[l.id] ?? []).filter((t) => !t.parent).map((t) => ({ task: t, list: l }))));
  const doneToday = (t) => t.status === 'completed' && t.completed && ymd(new Date(t.completed)) === today;
  const overdue = $derived(all.filter((x) => x.task.due && dueToYmd(x.task.due) < today && (x.task.status !== 'completed' || doneToday(x.task))));
  const dueToday = $derived(all.filter((x) => x.task.due && dueToYmd(x.task.due) === today && (x.task.status !== 'completed' || doneToday(x.task)))
    .sort((a, b) => priorityRank(layTasks?.[a.task.id]?.priority) - priorityRank(layTasks?.[b.task.id]?.priority)
      || (layTasks?.[a.task.id]?.slot?.s ?? '99').localeCompare(layTasks?.[b.task.id]?.slot?.s ?? '99')));
  const isOn = (x) => x.task.status === 'completed';
  const lateLeft = $derived(overdue.filter((x) => !isOn(x)).length);
  const total = $derived(overdue.length + dueToday.length);
  const doneN = $derived([...overdue, ...dueToday].filter(isOn).length);
  const left = $derived(total - doneN);

  // Метка у задачи — список (квадратик цвета сферы), как в «Создать».
  const spheres = $derived(spheresFrom(layer));
  const colorOf = (id) => { const sp = spheres.find((x) => x.id === sphereOf(id, layer)); return sp ? sphereColor(sp) : 'var(--ink-faint)'; };
  const titleOf = (id) => lists.find((l) => l.id === id)?.title ?? '';
  function meta(x) {
    const slot = layTasks?.[x.task.id]?.slot;
    if (slot?.s) return slot.s;
    if (dueToYmd(x.task.due) < today) return `с ${humanDue(x.task.due).replace(/^\S+, /, '')}`;
    return '';
  }

  // ---------- «Дальше» ----------

  const timed = $derived.by(() => {
    const out = [];
    for (const e of events) {
      if (!e.start?.dateTime) continue;
      const a = new Date(e.start.dateTime), b = new Date(e.end?.dateTime ?? e.start.dateTime);
      if (ymd(a) !== today) continue;
      out.push({ id: 'e' + e.id, kind: 'event', title: e.summary || 'Без названия', s: a.getHours() * 60 + a.getMinutes(), e: ymd(b) === today ? b.getHours() * 60 + b.getMinutes() : 1440 });
    }
    for (const x of dueToday) {
      const slot = layTasks?.[x.task.id]?.slot;
      if (!slot?.s) continue;
      out.push({ id: x.task.id, kind: 'task', title: x.task.title || 'Без названия', s: toMin(slot.s), e: toMin(slot.e || slot.s), done: isOn(x), type: typeOf(x.list.id, x.task.id) });
    }
    return out.sort((a, b) => a.s - b.s);
  });
  const next = $derived(timed.find((t) => t.s > now && !t.done) ?? null);
  const nextWhen = $derived.by(() => {
    if (!next) return '';
    return `через ${dur(next.s - now)}`;
  });
  // Сколько ещё занято в расписании до конца дня: события и задачи со временем,
  // пересечения считаются один раз, прошедшее и выполненное — не в счёт.
  const busyLeft = $derived.by(() => {
    let sum = 0, edge = now;
    for (const t of timed) {
      if (t.done || t.e <= edge) continue;
      sum += t.e - Math.max(t.s, edge);
      edge = t.e;
    }
    return sum;
  });
  // 45 мин · 2 ч · 1 ч 20 мин
  function dur(m) {
    const h = Math.floor(m / 60);
    return h ? `${h} ч${m % 60 ? ` ${m % 60} мин` : ''}` : `${m} мин`;
  }

  // ---------- привычки ----------

  const todays = $derived(habits.filter((h) => habitDay(h, log, today, today).sched));
  const hDone = $derived(todays.filter((h) => isDone(log, h.id, today)).length);

  // ---------- заголовок и енот ----------

  const allDone = $derived(total > 0 && left === 0);
  // С чего начать: просроченное → приоритет → срок (как совет енота на доске).
  const firstOpen = $derived(pickNext([...dueToday, ...overdue].filter((x) => !isOn(x)), layTasks, today));
  const at = $derived(next ? `, ${next.title.charAt(0).toLowerCase() + next.title.slice(1)} в ${fromMin(next.s)}` : '');
  const headline = $derived(
    total === 0 ? 'День свободен — можно взяться за большое.'
    : allDone ? 'Всё на сегодня сделано. Енот гордится.'
    : doneN === 0 ? `${left} ${plural(left, ['дело', 'дела', 'дел'])} до вечера${at}.`
    : `Осталось ${left} ${plural(left, ['дело', 'дела', 'дел'])}${at}.`);
  const hLeft = $derived(todays.length - hDone);
  const say = $derived(
    total === 0 ? (todays.length && hLeft ? `Задач нет — самое время для привычек: осталось ${hLeft}.` : 'Привет! Задач на сегодня нет. Можно взять что-то с доски.')
    : allDone ? (hLeft ? `Ура! Дела закрыты. Осталось ${hLeft} ${plural(hLeft, ['привычка', 'привычки', 'привычек'])} — и свободен.` : 'Идеальный день! Даже все привычки. Можно на орбиту — отдыхать.')
    : !dueToday.some((x) => !isOn(x)) ? `Остались просроченные — «${firstOpen.task.title}». Может, перенести на завтра?`
    : doneN === 0 ? `Привет! Начнём с малого: «${firstOpen.task.title}».`
    : `Хороший темп. Дальше — «${firstOpen.task.title}».`);

  // ---------- отметка и «Отменить» ----------

  let last = $state(null);
  let lastTimer;
  async function tick(x) {
    const done = !isOn(x);
    const ok = await ontoggle(x.task, done, x.list.id, true);
    if (!ok) return;
    clearTimeout(lastTimer);
    last = done ? x : null;
    if (done) lastTimer = setTimeout(() => (last = null), 5000);
  }
  async function undo() {
    const x = last;
    last = null;
    clearTimeout(lastTimer);
    const cur = (tasksByList[x.list.id] ?? []).find((t) => t.id === x.task.id) ?? x.task;
    await ontoggle(cur, false, x.list.id, true);
  }

  // ---------- умная строка (как в «Создать»: route.parseLine + route.route) ----------

  let input = $state(null);
  let draft = $state('');
  let adding = $state(false);
  let manual = $state(null); // список, выбранный вручную (клик по золотому чипу)
  let pickFor = $state(null); // { anchor, kind: 'line' | 'inbox', m? } — открытый выбор списка
  let destEl = $state(null);
  const parsed = $derived(parseLine(draft, { today: new Date(clock) }));
  const routeSrc = $derived([parsed.at ? `@${parsed.at}` : '', parsed.tag ? `#${parsed.tag}` : '', parsed.rest].join(' ').trim());
  const ranked = $derived(routeSrc ? route(routeSrc, { lists, layer, tasks: tasksByList }) : []);
  const dest = $derived(manual ?? ranked[0]?.listId ?? lists[0]?.id);
  const why = $derived(manual ? 'выбрано вручную' : ranked.find((r) => r.listId === dest)?.why ?? '');
  const chips = $derived(understood(parsed, today));
  $effect(() => { if (!draft.trim()) manual = null; });

  async function add() {
    if (!parsed.title || adding || !lists.length) return;
    adding = true;
    const t = taskFrom(parsed, today, dest, ranked[0]);
    const id = await oncreate(t, t.due !== today); // не на сегодня — App покажет, куда ушла
    adding = false;
    if (!id) return;
    if (manual && manual !== ranked[0]?.listId) onlearn?.(learn(layer?.settings?.route, t.title, dest));
    draft = ''; fresh = new Set([...fresh, id]); input?.focus();
  }
  function lineKey(e) {
    if (e.key === 'Escape') { draft = ''; return; }
    if (e.key === 'Enter' && e.shiftKey && onfull) {
      // То же нажатие не должно дойти до окна «Создать» (там Shift+Enter — «создать и ещё»): окно открываем после него.
      e.preventDefault(); e.stopPropagation();
      const t = draft; draft = '';
      setTimeout(() => onfull(t));
      return;
    }
    if (e.altKey && e.code === 'KeyL' && parsed.title) { e.preventDefault(); pickFor = { anchor: destEl, kind: 'line' }; }
  }

  // ---------- входящие от Claude: куда ляжет ----------

  let inboxDest = $state({}); // id задачи → список, выбранный вручную
  const guessOf = (m) => route(`${m.task.title ?? ''} ${m.task.notes ?? ''}`, { lists, layer, tasks: tasksByList, current: m.listId })[0]?.listId ?? m.listId;
  const destOf = (m) => inboxDest[m.task.id] ?? guessOf(m);
  const withDest = (items) => items.map((m) => ({ ...m, dest: destOf(m) }));
  function picked(id) {
    const p = pickFor;
    pickFor = null;
    if (p?.kind === 'inbox') inboxDest = { ...inboxDest, [p.m.task.id]: id };
    else { manual = id; input?.focus(); }
  }

  // ---------- расписание дня ----------

  const allday = $derived(events.filter((e) => e.start?.date));
  const range = $derived.by(() => {
    const hNow = Math.floor(now / 60);
    let a = Math.min(hNow, ...timed.map((t) => Math.floor(t.s / 60)));
    let b = Math.max(hNow + 2, ...timed.map((t) => Math.ceil(t.e / 60)));
    a = Math.max(0, Math.min(a, b - 6));
    return { a, b: Math.min(24, Math.max(b, a + 6)) };
  });
  const HOUR = 48;
  const ypx = (m) => ((m - range.a * 60) / 60) * HOUR;
  const lastEnd = $derived(timed.length ? Math.max(...timed.map((t) => t.e)) : 0);
  const freeEvening = $derived(!timed.some((t) => t.e > now && !t.done));

  // «Входящие» — прокрутить к блоку, когда нажали значок в шапке.
  let inboxEl = $state(null);
  $effect(() => { if (inboxFocus && inboxEl) inboxEl.scrollIntoView({ behavior: 'smooth', block: 'center' }); });
</script>

{#snippet taskRow(x)}
  {@const m = meta(x)}
  <div class="trow">
    <button type="button" class="tick" aria-pressed={isOn(x)} aria-label="{x.task.title}{isOn(x) ? ' — выполнено' : ' — отметить'}" onclick={() => tick(x)}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
    </button>
    <button type="button" class="ttl" class:off={isOn(x)} onclick={() => onopen(x.task, x.list.id)}>{x.task.title || 'Без названия'}</button>
    {#if fresh.has(x.task.id)}<span class="new">новая</span>{/if}
    {#if priorityOf(layTasks?.[x.task.id]?.priority) && !isOn(x)}{@const pr = priorityOf(layTasks?.[x.task.id]?.priority)}<span class="prio {pr.cls}" title="Приоритет: {pr.label.toLowerCase()}">{pr.mark}</span>{/if}
    <span class="t-lst" style="--sc: {colorOf(x.list.id)}"><i></i>{x.list.title}</span>
    {#if m}<span class="meta" class:late={dueToYmd(x.task.due) < today && !isOn(x)}>{m}</span>{/if}
  </div>
{/snippet}

<div class="t-page">
  <section class="t-hero">
    <div class="in">
      <div class="t-head">
        <div class="t-top"><p class="date">{dateLine}</p>{@render filter?.()}</div>
        <h1>{headline}</h1>
        <div class="meters">
          <div>
            <div class="ml"><span>Задачи</span><span>{doneN} из {total}</span></div>
            <div class="meter"><span style="width: {total ? Math.round((doneN / total) * 100) : 0}%; background: var(--signal-done)"></span></div>
          </div>
          {#if todays.length}
            <div>
              <div class="ml"><span>Привычки</span><span>{hDone} из {todays.length}</span></div>
              <div class="meter"><span style="width: {Math.round((hDone / todays.length) * 100)}%; background: var(--gold)"></span></div>
            </div>
          {/if}
        </div>
        <div class="next">
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8.5" /><path d="M12 7.5V12l3 2" /></svg>
          {#if next}Дальше: <b>{next.title}</b> · {nextWhen}{:else}Дальше: <b>свободный вечер</b> · в расписании пусто{/if}
          {#if next && busyLeft >= 30}<span class="busy" title="Сколько ещё занято в расписании до конца дня">· занято ещё {dur(busyLeft)}</span>{/if}
        </div>
      </div>
      <div class="t-coon">
        <p class="bubble" aria-live="polite">{say}</p>
        <Coon pose={allDone ? 'cheer' : 'hi'} size={140} />
      </div>
    </div>
  </section>

  <div class="t-body">
    <main>
      <div>
        <form class="qa" onsubmit={(e) => { e.preventDefault(); add(); }}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>
          <input bind:this={input} bind:value={draft} type="text" aria-label="Новая задача"
            placeholder="Пиши как в окне «Создать»… например «скетч таверны 17:00»" onkeydown={lineKey} />
          <button class="sp-btn sp-btn-primary" type="submit" disabled={!parsed.title || adding || !lists.length}>Добавить</button>
        </form>
        <div class="qa-got">
          {#if parsed.title}
            <span class="lbl">Понял:</span>
            {#each chips as c (c.kind)}<span class="qa-c">{c.text}</span>{/each}
            <button type="button" class="qa-c qa-dest" bind:this={destEl} style="--sc: {colorOf(dest)}" title="Сменить список · Alt+L" aria-haspopup="listbox"
              aria-expanded={pickFor?.kind === 'line'} onclick={() => (pickFor = pickFor ? null : { anchor: destEl, kind: 'line' })}>
              <i></i><span class="tx">→ {titleOf(dest)}</span>{#if why}<small>✦ {why}</small>{/if}
            </button>
          {:else}
            <span class="lbl">Дата, время, !!!, #тип и @список распознаются сами. Из любого чата Claude: «запиши в Спутник…»</span>
          {/if}
          <span class="qa-keys">{onfull ? "Enter — добавить · Shift+Enter — открыть полное окно" : "Enter — добавить"}</span>
        </div>
      </div>

      {#if overdue.length}
        <section>
          <div class="t-sechead">
            <h2 class:over={lateLeft}>{lateLeft ? `Просрочено · ${lateLeft}` : 'Просрочено · разобрано'}</h2>
            {#if lateLeft && onreschedule}
              <button type="button" class="t-move" title="Поставить срок «сегодня» всем просроченным (можно отменить)"
                onclick={() => onreschedule(overdue.filter((x) => !isOn(x)), today)}>Всё на сегодня</button>
            {/if}
          </div>
          <div class:box={lateLeft}>{#each overdue as x (x.task.id)}{@render taskRow(x)}{/each}</div>
        </section>
      {/if}
      <section>
        <h2>Сегодня · {dueToday.length}</h2>
        {#each dueToday as x (x.task.id)}{@render taskRow(x)}{:else}<p class="empty">На сегодня задач со сроком нет. Добавь строкой выше или возьми с доски.</p>{/each}
      </section>

      {#if habits.length}
        <section>
          <h2><button type="button" class="h-link" onclick={onhabits}>Привычки →</button></h2>
          <div class="hpills">
            {#each todays as h (h.id)}
              {@const d = isDone(log, h.id, today)}
              {@const s = stats(h, log).streak}
              {@const g = goalN(h)}
              {@const n = g ? countOn(log, h, today) : 0}
              <!-- У привычки с количеством клик = «+1», рядом — сколько набрано: «5/8». -->
              <button type="button" class="hpill" aria-pressed={d} title="{d ? 'Сделано' : g ? `Плюс один: ${n + 1} из ${g} ${h.goal.unit ?? ''}` : 'Отметить'}{h.time ? ` · ${h.time}` : ''}{s ? ` · ${s} ${plural(s, unitForms(h))} подряд` : ''}" onclick={() => ontogglehabit(h)}>
                <span class="hring" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg></span>
                <span class="hn">{h.name}</span>
                {#if g && !d}<span class="hs">{n}/{g}</span>{:else}<span class="hs" class:gold={s}>{s ? `✦ ${s}` : 'старт'}</span>{/if}
              </button>
            {:else}
              <p class="empty">Сегодня привычек по расписанию нет.</p>
            {/each}
          </div>
        </section>
      {/if}

      {#if inboxOn || inboxItems.length}
        <section class="inbox" aria-label="Входящие от Claude" bind:this={inboxEl}>
          <div class="ih">
            <h2>Входящие от Claude · {inboxItems.length}</h2>
            <span class="ih-r">
              <span class="src">из чатов Claude</span>
              {#if inboxItems.length > 1}<button class="sp-btn sp-btn-ghost" type="button" style="min-height: 28px" onclick={() => onaccept(withDest(inboxItems))}>Принять все</button>{/if}
            </span>
          </div>
          {#each inboxItems as m (m.task.id)}
            {@const to = destOf(m)}
            <div class="im">
              <div class="im-t">
                <button type="button" class="im-title" title={m.task.title} onclick={() => onopen(m.task, m.listId)}>{m.task.title || 'Без названия'}</button>
                <div class="im-sub" title={m.task.notes ?? ''}>{[m.task.notes?.split('\n')[0], m.from].filter(Boolean).join(' · ') || `список «${m.list}»`}</div>
              </div>
              <button type="button" class="qa-c qa-dest" style="--sc: {colorOf(to)}" title="Куда ляжет — сменить" aria-haspopup="listbox"
                onclick={(e) => (pickFor = { anchor: e.currentTarget, kind: 'inbox', m })}><i></i><span class="tx">→ {titleOf(to)}</span></button>
              <span class="qa-c">{m.task.due ? humanDue(m.task.due) : 'без срока'}</span>
              <button class="im-b ok" type="button" aria-label="Принять «{m.task.title}»" title="Принять" onclick={() => onaccept(withDest([m]))}>
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg></button>
              <button class="im-b" type="button" aria-label="Отклонить «{m.task.title}»" title="Отклонить" onclick={() => onreject(m)}>
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18" /></svg></button>
            </div>
          {:else}
            <p class="empty" style="padding: 0">Всё разобрано. Принятое уже на доске во «Входящих».</p>
          {/each}
        </section>
      {/if}
    </main>

    <aside aria-label="Календарь на сегодня">
      <h2><button type="button" class="h-link" onclick={oncalendar}>Календарь →</button></h2>
      {#each allday as e (e.id + (e.calendar ?? ''))}
        <div class="t-allday">{e.summary || 'Без названия'} <span>· весь день</span></div>
      {/each}
      <div class="sched" style="height: {(range.b - range.a) * HOUR}px">
        <div class="hrs">{#each Array.from({ length: range.b - range.a }, (_, i) => range.a + i) as h (h)}<span style="top: {(h - range.a) * HOUR}px">{String(h).padStart(2, '0')}:00</span>{/each}</div>
        <div class="lane">
          {#each timed as t (t.id)}
            <div class="sb" class:task={t.kind === 'task'} class:done={t.done} style="top: {ypx(t.s) + 1}px; height: {Math.max(30, ypx(t.e) - ypx(t.s) - 2)}px; --c: var(--type-{t.type ?? 'work'})">
              <span class="st">{t.title}</span> <span class="sw">{t.kind === 'task' ? 'задача · ' : ''}{fromMin(t.s)}–{fromMin(Math.min(t.e, 1439))}</span>
            </div>
          {/each}
          <div class="nowl" style="top: {ypx(now)}px"></div>
        </div>
      </div>
      {#if freeEvening}
        <div class="t-free">
          <Coon pose="sleep" size={80} />
          <p>{timed.length && lastEnd > 0 ? `После ${fromMin(Math.min(lastEnd, 1439))} ничего нет.` : 'В расписании сегодня пусто.'} Енот советует отдохнуть — серии подождут до завтра.</p>
        </div>
      {/if}
    </aside>
  </div>
</div>

{#if pickFor}
  <ListPick anchor={pickFor.anchor} {lists} {layer} current={pickFor.kind === 'inbox' ? destOf(pickFor.m) : dest}
    guess={pickFor.kind === 'inbox' ? guessOf(pickFor.m) : ranked[0]?.listId} onpick={picked} onclose={() => (pickFor = null)} />
{/if}

{#if last}
  <div class="toast" role="status"><span>Готово: «{last.task.title}»</span><button type="button" onclick={undo}>Отменить</button></div>
{/if}
