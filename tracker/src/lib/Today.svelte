<script>
  import { onMount } from 'svelte';
  import { dueToYmd, ymd, humanDue } from './api.js';
  import { stats, plural, isDone } from './habits.js';
  import { habitDay, fromMin, toMin, nowMin, MONTH_GEN } from './calendar.js';
  import { templateOf } from './templates.js';
  import Coon from './Coon.svelte';
  import { priorityOf, priorityRank, pickNext, TYPES } from './meta.js';
  import { parseWhen, whenText } from './when.js';

  let { lists, tasksByList, events, layTasks, layLists, log, habits, inboxItems, inboxOn, inboxFocus, typeOf,
    onopen, ontoggle, oncreate, ontogglehabit, onaccept, onreject, onregister, onhabits, oncalendar, filter = null } = $props();

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

  const TYPE_LABEL = Object.fromEntries(TYPES.map((t) => [t.id, t.label])); // work, asset, study, personal
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

  function chip(x) {
    const tags = layTasks?.[x.task.id]?.tags ?? [];
    const type = typeOf(x.list.id, x.task.id);
    return { cls: `sp-chip-${type}`, label: tags.includes('client') || tags.includes('клиент') ? 'client' : TYPE_LABEL[type] ?? 'task' };
  }
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
    const m = next.s - now;
    return `через ${Math.floor(m / 60) ? Math.floor(m / 60) + ' ч ' : ''}${m % 60} мин`;
  });

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

  // ---------- быстрое добавление ----------

  let input = $state(null);
  let draft = $state('');
  let adding = $state(false);
  // #тег → тип задачи и какой шаблон списка ей подходит. Теги латиницей, строчными;
  // старые русские (#ассет …) тоже понимаем, чтобы привычка писать их ничего не ломала.
  const TAGS = {
    asset: { type: 'creative', tpl: 'asset3d' }, work: { type: 'work', tpl: 'work' }, client: { type: 'work', tpl: 'work', tag: 'client' },
    study: { type: 'study', tpl: 'study' }, personal: { type: 'personal', tpl: 'personal' },
  };
  const OLD_TAGS = { 'ассет': 'asset', 'работа': 'work', 'клиент': 'client', 'учёба': 'study', 'учеба': 'study', 'личное': 'personal' };

  /** «скетч таверны 17:00 #asset» → { title, time, kind } */
  function parse(raw) {
    let txt = ` ${raw} `;
    // !!! — высокий приоритет, !! — средний, ! — низкий.
    let priority = null;
    const pm = txt.match(/\s(!{1,3})(?=\s)/);
    if (pm) { priority = 4 - pm[1].length; txt = txt.replace(pm[0], ' '); }
    let kind = null;
    const tg = txt.match(/#([^\s#]+)/);
    if (tg) { const k = tg[1].toLowerCase(); kind = TAGS[OLD_TAGS[k] ?? k] ?? null; txt = txt.replace(tg[0], ' '); }
    // Дата и время словами — общий разбор (тот же, что в окне «Когда»): «в пятницу 17:00», «завтра», «25 окт».
    const w = parseWhen(txt, new Date(clock));
    txt = w.rest;
    return { title: txt && txt[0].toUpperCase() + txt.slice(1), time: w.time ?? '', day: w.day, kind, priority };
  }
  const preview = $derived(draft.trim() ? parse(draft) : null);

  function listFor(kind) {
    const byTpl = kind && lists.find((l) => (layLists?.[l.id]?.template ?? 'work') === kind.tpl);
    return (byTpl ?? lists.find((l) => templateOf(layLists?.[l.id]?.template).id !== 'asset3d') ?? lists[0])?.id;
  }

  async function add() {
    const p = parse(draft);
    if (!p.title || adding || !lists.length) return;
    adding = true;
    const layer = {};
    if (p.kind) { layer.type = p.kind.type; if (p.kind.tag) layer.tags = [p.kind.tag]; }
    if (p.priority) layer.priority = p.priority;
    const id = await oncreate({ title: p.title, listId: listFor(p.kind), due: p.day ?? today, slot: p.time ? { s: p.time, e: fromMin(Math.min(toMin(p.time) + 60, 1439)) } : null, layer }, !!p.day && p.day !== today); // не на сегодня — App покажет, куда ушла
    adding = false;
    if (id) { draft = ''; fresh = new Set([...fresh, id]); input?.focus(); }
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
  {@const c = chip(x)}
  {@const m = meta(x)}
  <div class="trow">
    <button type="button" class="tick" aria-pressed={isOn(x)} aria-label="{x.task.title}{isOn(x) ? ' — выполнено' : ' — отметить'}" onclick={() => tick(x)}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
    </button>
    <button type="button" class="ttl" class:off={isOn(x)} onclick={() => onopen(x.task, x.list.id)}>{x.task.title || 'Без названия'}</button>
    {#if fresh.has(x.task.id)}<span class="new">новая</span>{/if}
    {#if priorityOf(layTasks?.[x.task.id]?.priority) && !isOn(x)}{@const pr = priorityOf(layTasks?.[x.task.id]?.priority)}<span class="prio {pr.cls}" title="Приоритет: {pr.label.toLowerCase()}">{pr.mark}</span>{/if}
    <span class="sp-chip {c.cls}"><span class="dot"></span>{c.label}</span>
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
          <input bind:this={input} bind:value={draft} type="text" aria-label="Новая задача на сегодня"
            placeholder="Новая задача… например «скетч таверны 17:00 #asset»" onkeydown={(e) => e.key === 'Escape' && (draft = '')} />
          <button class="sp-btn sp-btn-primary" type="submit" disabled={!preview?.title || adding || !lists.length}>Добавить</button>
        </form>
        <p class="qa-hint">
          {#if preview?.title}
            Добавлю «{preview.title}» {preview.day && preview.day !== today ? `на ${whenText(preview.day, null).date.toLowerCase()}` : 'на сегодня'}{preview.time ? ` в ${preview.time}` : ''}{preview.kind ? ` · ${TYPE_LABEL[preview.kind.type]}` : ''}{preview.priority ? ` · приоритет ${priorityOf(preview.priority).label.toLowerCase()}` : ''}
            → список «{lists.find((l) => l.id === listFor(preview.kind))?.title}».
          {:else}
            Дата, время, #тип и приоритет распознаются сами: «завтра», «в пятницу», «25 окт», 17:00, #asset #work #client #study #personal, !!! / !! / !. Из любого чата Claude тоже можно: «запиши в Спутник…» — задача появится здесь.
          {/if}
        </p>
      </div>

      {#if overdue.length}
        <section>
          <h2 class:over={lateLeft}>{lateLeft ? `Просрочено · ${lateLeft}` : 'Просрочено · разобрано'}</h2>
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
          {#each todays as h (h.id)}
            {@const d = isDone(log, h.id, today)}
            {@const s = stats(h, log).streak}
            <div class="trow">
              <button type="button" class="hring" aria-pressed={d} aria-label="{h.name}{d ? ' — сделано' : ' — отметить'}" onclick={() => ontogglehabit(h)}>
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
              </button>
              <span class="ttl" style="font-weight: 500">{h.name}</span>{#if h.time}<span class="meta">{h.time}</span>{/if}
              <span class="meta" class:gold={s}>{s ? `✦ ${s} ${plural(s, ['день', 'дня', 'дней'])} подряд` : 'начни серию'}</span>
            </div>
          {:else}
            <p class="empty">Сегодня привычек по расписанию нет.</p>
          {/each}
        </section>
      {/if}

      {#if inboxOn || inboxItems.length}
        <section class="inbox" aria-label="Входящие от Claude" bind:this={inboxEl}>
          <div class="ih">
            <h2>Входящие от Claude · {inboxItems.length}</h2>
            <span class="ih-r">
              <span class="src">из чатов Claude</span>
              {#if inboxItems.length > 1}<button class="sp-btn sp-btn-ghost" type="button" style="min-height: 28px" onclick={() => onaccept(inboxItems)}>Принять все</button>{/if}
            </span>
          </div>
          {#each inboxItems as m (m.task.id)}
            {@const c = chip({ task: m.task, list: { id: m.listId } })}
            <div class="im">
              <div class="im-t">
                <button type="button" class="im-title" onclick={() => onopen(m.task, m.listId)}>{m.task.title || 'Без названия'}</button>
                <div class="im-sub">{m.from ? `${m.from} · ` : ''}список «{m.list}»</div>
              </div>
              <span class="sp-chip {c.cls}"><span class="dot"></span>{c.label}</span>
              <span class="sp-chip">{m.task.due ? humanDue(m.task.due) : 'без срока'}</span>
              <button class="sp-btn" type="button" onclick={() => onaccept([m])}>Принять</button>
              <button class="sp-btn sp-btn-ghost" type="button" onclick={() => onreject(m)}>Отклонить</button>
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

{#if last}
  <div class="toast" role="status"><span>Готово: «{last.task.title}»</span><button type="button" onclick={undo}>Отменить</button></div>
{/if}
