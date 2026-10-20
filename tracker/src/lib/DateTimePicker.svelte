<script>
  // Окно «Когда» (design/screens/DateTime.dc.html, docs/design-v2.md — «Выбор даты и времени»):
  // строка словами, быстрые кнопки, месяц с точками занятости, время по расписанию дня, длительность, «Весь день»,
  // напоминание, «Без срока». Время задачи — слой tasks[id].slot = { s, e }; длительность = e − s.
  import { onMount, tick, untrack } from 'svelte';
  import { ymd } from './api.js';
  import { parseWhen } from './when.js';
  import { DEFAULT_TIME } from './reminders.js';

  let {
    day = '', slot = null, remind = undefined, // remind: правило из слоя или undefined — не показывать напоминание
    allowTime = true, title = '', place = 'center',
    dueDays = new Set(), // дни со сроками других задач — золотая точка
    loadEvents = null,   // (start, end) → события Google за период: серая точка и плашки в расписании дня
    onapply, onclose,
  } = $props();

  const MON = ['январь', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'];
  const MONG = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  const WDF = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
  const WDS = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  const START = 8 * 60, END = 22 * 60, ROW = 22; // лента 8:00–22:00 шагом 30 минут
  const DURS = [[30, '30 мин'], [60, '1 ч'], [120, '2 ч'], [180, '3 ч']];

  const pad = (n) => String(n).padStart(2, '0');
  const toMin = (s) => { const [h, m] = s.split(':').map(Number); return h * 60 + m; };
  const fromMin = (m) => `${pad(Math.floor(m / 60) % 24)}:${pad(m % 60)}`;
  const parse = (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
  const add = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
  const dow = (d) => (d.getDay() + 6) % 7;
  const today = ymd(new Date());
  const todayD = parse(today);

  // ---------- состояние (из переданных значений — один раз, дальше окно живёт само) ----------
  const init = untrack(() => ({ day, slot, remind, allowTime }));
  let sel = $state(init.day || '');
  let time = $state(init.slot?.s ?? '');
  let dur = $state(init.slot?.s && init.slot?.e ? Math.max(15, toMin(init.slot.e) - toMin(init.slot.s)) : 60);
  let allDay = $state(!init.allowTime || !init.slot?.s);
  let nl = $state('');
  const remindKind = (r) => (!r ? 'none' : r.kind === 'before' && r.days === 1 && (r.time ?? DEFAULT_TIME) === '10:00' ? 'd1' : r.kind === 'at' && r.hour1 ? 'h1' : 'keep');
  let rem = $state(init.remind === undefined ? 'keep' : remindKind(init.remind));
  const viewInit = parse(init.day || today);
  let vy = $state(viewInit.getFullYear());
  let vm = $state(viewInit.getMonth());

  // ---------- занятость месяца ----------
  let events = $state([]);
  const cells = $derived.by(() => {
    const first = new Date(vy, vm, 1);
    const start = add(first, -dow(first));
    return Array.from({ length: 42 }, (_, i) => add(start, i));
  });
  $effect(() => {
    if (!loadEvents) return;
    const a = cells[0], b = add(cells[41], 1);
    let alive = true;
    loadEvents(a, b).then((ev) => { if (alive) events = ev; }).catch(() => {});
    return () => { alive = false; };
  });
  // По дням: [{ s, e, title }] для расписания и признак «есть дела» для точки.
  const busyByDay = $derived.by(() => {
    const out = {};
    for (const e of events) {
      if (e.kind === 'holiday') continue;
      if (e.start?.date) { // на весь день: точка «есть дела», в расписании не рисуем; end.date — следующий день после последнего
        const end = e.end?.date > e.start.date ? e.end.date : ymd(add(parse(e.start.date), 1));
        for (let d = parse(e.start.date); ymd(d) < end; d = add(d, 1)) (out[ymd(d)] ??= []).push(null);
        continue;
      }
      if (!e.start?.dateTime) continue;
      const a = new Date(e.start.dateTime), b = new Date(e.end?.dateTime ?? e.start.dateTime);
      if (ymd(a) !== ymd(b)) { (out[ymd(a)] ??= []).push({ s: a.getHours() * 60 + a.getMinutes(), e: 1440, title: e.summary || 'Событие' }); continue; }
      (out[ymd(a)] ??= []).push({ s: a.getHours() * 60 + a.getMinutes(), e: b.getHours() * 60 + b.getMinutes(), title: e.summary || 'Событие' });
    }
    return out;
  });
  const dayBusy = $derived((busyByDay[sel] ?? []).filter(Boolean));

  // ---------- быстрые кнопки ----------
  const nextDow = (i) => add(todayD, ((i - dow(todayD) + 7) % 7) || 7);
  const QUICK = [
    ['Сегодня', todayD], ['Завтра', add(todayD, 1)], ['Пятница', nextDow(4)], ['Пн', nextDow(0)], ['Через неделю', add(todayD, 7)],
  ].map(([l, d]) => ({ l, day: ymd(d), hint: `${d.getDate()} ${MONG[d.getMonth()].slice(0, 3)}` }));

  function pickDay(d) {
    sel = d;
    const x = parse(d);
    vy = x.getFullYear(); vm = x.getMonth();
  }

  // ---------- время ----------
  const rows = Array.from({ length: (END - START) / 30 }, (_, i) => START + i * 30);
  const yAt = (min) => ((min - START) / 30) * ROW;
  const ps = $derived(!allDay && time ? toMin(time) : null);
  const pe = $derived(ps != null ? ps + dur : null);
  const clash = $derived(ps == null ? null : dayBusy.find((b) => b.s < pe && ps < b.e) ?? null);
  const freeAfter = $derived.by(() => {
    if (!clash) return null;
    for (let s = ps; s + dur <= 24 * 60; s += 30) if (!dayBusy.some((b) => b.s < s + dur && s < b.e)) return fromMin(s);
    return null;
  });
  // «Весь день» включили — время очищается; выключили — ждём, пока выберут время в расписании.
  function toggleAllDay() {
    allDay = !allDay;
    if (allDay) time = '';
    else scrollToTime();
  }
  function pickTime(min) { time = fromMin(min); allDay = false; if (!sel) sel = today; }
  function setMinutes(mm) { const h = time ? time.split(':')[0] : '10'; time = `${h}:${mm}`; allDay = false; if (!sel) sel = today; }

  let lane = $state(null);
  async function scrollToTime() {
    await tick();
    if (lane) lane.scrollTop = Math.max(0, yAt(ps ?? (dayBusy[0]?.s ?? 10 * 60)) - 60);
  }
  onMount(() => { scrollToTime(); input?.focus(); });

  // ---------- строка словами ----------
  let input = $state(null);
  function onNl(v) {
    nl = v;
    const p = parseWhen(v);
    if (p.day) pickDay(p.day);
    if (p.allDay) allDay = true;
    if (p.time && allowTime) { time = p.time; allDay = false; if (!p.day && !sel) sel = today; scrollToTime(); }
  }

  // ---------- итог и применение ----------
  const label = (d) => {
    if (!d) return 'без срока';
    const x = parse(d);
    const rel = d === today ? 'сегодня' : d === ymd(add(todayD, 1)) ? 'завтра' : WDS[dow(x)];
    return `${rel}, ${x.getDate()} ${MONG[x.getMonth()].slice(0, 3)}`;
  };
  const summary = $derived(`${label(sel)}${sel && ps != null ? ` · ${time}–${fromMin(pe)}` : ''}`);
  const dayTitle = $derived(sel ? (() => { const x = parse(sel); const w = WDF[dow(x)]; return `${w[0].toUpperCase()}${w.slice(1)}, ${x.getDate()} ${MONG[x.getMonth()]}`; })() : 'Без срока');

  function apply() {
    const out = { day: sel || null, slot: sel && ps != null ? { s: time, e: fromMin(Math.min(pe, 23 * 60 + 59)) } : null };
    if (remind !== undefined && rem !== 'keep') {
      out.remind = rem === 'none' || !sel ? null
        : rem === 'd1' ? { kind: 'before', days: 1, time: '10:00' }
        : out.slot ? { kind: 'at', at: `${sel}T${fromMin(Math.max(0, toMin(out.slot.s) - 60))}`, hour1: true } : null;
    }
    onapply(out);
  }
  // Без срока: снимаем дату и время; напоминание не трогаем (правило «за N дней до срока» без срока просто молчит).
  function clear() { onapply({ day: null, slot: null }); }

  function key(e) {
    if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); onclose(); }
    else if (e.key === 'Enter' && (e.target === input || e.ctrlKey)) { e.preventDefault(); apply(); }
  }
</script>

<svelte:window onkeydown={key} />

<button class="dtp-back" type="button" aria-label="Закрыть выбор даты" onclick={onclose}></button>
<div class="dtp dtp-{place}" role="dialog" aria-label="Когда">
  <div class="nl">
    <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.5" /><path d="M16 16l4 4" /></svg>
    <input bind:this={input} value={nl} oninput={(e) => onNl(e.currentTarget.value)} aria-label="Когда, словами"
      placeholder={allowTime ? 'Напиши: «завтра 15:00», «в пятницу», «через 2 дня 10:30»' : 'Напиши: «завтра», «в пятницу», «25 окт»'} />
    <span class="parsed">{summary}</span>
  </div>

  <div class="quick" role="group" aria-label="Быстрый выбор">
    {#each QUICK as q (q.l)}
      <button type="button" class="qb" aria-pressed={sel === q.day} onclick={() => pickDay(q.day)}>{q.l}<small>{q.hint}</small></button>
    {/each}
  </div>

  <div class="dtp-body">
    <div class="dtp-month">
      <div class="mt">
        <span>{MON[vm][0].toUpperCase() + MON[vm].slice(1)} {vy}</span>
        <button type="button" class="sp-btn sp-btn-ghost" aria-label="Предыдущий месяц" onclick={() => { if (vm === 0) { vm = 11; vy--; } else vm--; }}>‹</button>
        <button type="button" class="sp-btn sp-btn-ghost" aria-label="Следующий месяц" onclick={() => { if (vm === 11) { vm = 0; vy++; } else vm++; }}>›</button>
      </div>
      <div class="mgrid2">
        {#each WDS as w (w)}<span class="wd2">{w}</span>{/each}
        {#each cells as c, i (ymd(c))}
          {@const k = ymd(c)}
          {@const busy = !!busyByDay[k]?.length}
          {@const due = dueDays.has(k)}
          <button type="button" class="dc" class:out={c.getMonth() !== vm} class:past={k < today} class:we={i % 7 >= 5} class:today={k === today}
            aria-pressed={sel === k} aria-label="{c.getDate()} {MONG[c.getMonth()]}{busy ? ', есть дела' : ''}{due ? ', срок другой задачи' : ''}"
            onclick={() => pickDay(k)}>
            {c.getDate()}{#if (busy || due) && sel !== k}<i class:gold={due}></i>{/if}
          </button>
        {/each}
      </div>
      <div class="dlegend"><span><i></i>есть дела</span><span><i class="gold"></i>срок другой задачи</span></div>
    </div>

    <div class="dtp-day">
      <div class="dt">
        <span>{dayTitle}</span>
        {#if allowTime}
          <span class="lbl2">Весь день</span>
          <button type="button" class="sw" aria-label="Весь день, без времени" aria-pressed={allDay} onclick={toggleAllDay}></button>
        {/if}
      </div>
      {#if allowTime}
        <!-- Расписание видно всегда; при «Весь день» приглушено, клик по времени выключает «Весь день». -->
        <div class="tl" class:dim={allDay || ps == null} bind:this={lane} aria-label="Расписание дня — выбери свободное время">
          <div class="tl-in" style="height: {yAt(END)}px">
            {#each rows as m (m)}
              <button type="button" class="tr" class:hour={m % 60 === 0} data-t={fromMin(m)} aria-label="Выбрать {fromMin(m)}" style="top: {yAt(m)}px" onclick={() => pickTime(m)}>
                {#if m % 60 === 0}<b>{fromMin(m)}</b>{/if}
              </button>
            {/each}
            {#each dayBusy as b, i (i)}
              <div class="ev2" style="top: {yAt(Math.max(START, b.s)) + 1}px; height: {Math.max(18, yAt(Math.min(END, b.e)) - yAt(Math.max(START, b.s)) - 2)}px">{fromMin(b.s)} {b.title}</div>
            {/each}
            {#if ps != null && sel}
              <div class="pick" class:clash style="top: {yAt(Math.max(START, ps)) + 1}px; height: {Math.max(18, (dur / 30) * ROW - 2)}px">{time}–{fromMin(pe)}{title ? ` · ${title}` : ''}</div>
            {/if}
          </div>
        </div>
        <div class="mins" class:dim={allDay || ps == null} role="group" aria-label="Минуты">
          {#each ['00', '15', '30', '45'] as mm (mm)}<button type="button" aria-pressed={time.endsWith(':' + mm)} onclick={() => setMinutes(mm)}>:{mm}</button>{/each}
        </div>
        <div class="durs" class:dim={allDay || ps == null}>
          <span>Длится</span>
          {#each DURS as [m, l] (m)}<button type="button" class="qb" aria-pressed={dur === m} onclick={() => (dur = m)}>{l}</button>{/each}
        </div>
        {#if allDay || ps == null}<p class="time-hint">{!sel ? 'Срок не выбран — задача останется на доске без даты. Нажми на день или время.' : 'Весь день, без времени. Нажми на время в расписании, чтобы назначить его.'}</p>{/if}
        {#if clash}<p class="clash-t">Пересекается с «{clash.title}»{freeAfter ? `. Свободно с ${freeAfter}.` : '.'}</p>{/if}
      {:else}
        <div class="allday-note">
          {#if !sel}Дата не выбрана — выбери день в календаре слева.{:else}Каждый год в этот день.{/if}
        </div>
      {/if}
    </div>
  </div>

  <div class="dtp-foot">
    {#if remind !== undefined}
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z" /><path d="M10 20a2 2 0 0 0 4 0" /></svg>
      <button type="button" class="qb" aria-pressed={rem === 'none'} onclick={() => (rem = 'none')}>Без напоминания</button>
      <button type="button" class="qb" aria-pressed={rem === 'h1'} disabled={ps == null} title={ps == null ? 'Сначала выбери время' : 'Сообщение в Telegram за час до начала'} onclick={() => (rem = 'h1')}>За час</button>
      <button type="button" class="qb" aria-pressed={rem === 'd1'} onclick={() => (rem = 'd1')}>Накануне в 10:00</button>
      {#if rem === 'keep'}<span class="keep">своё напоминание сохранится</span>{/if}
    {/if}
    <span style="flex: 1"></span>
    <button type="button" class="sp-btn sp-btn-ghost" style="min-height: 32px" onclick={clear}>Без срока</button>
    <button type="button" class="sp-btn sp-btn-primary" style="min-height: 32px" onclick={apply}>Готово</button>
  </div>
</div>
