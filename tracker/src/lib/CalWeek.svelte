<script>
  import { fromMin, toMin, typeColor, nowMin } from './calendar.js';

  // layout — высоты часов (calendar.hourLayout): занятые 40 px, пустые сжаты; draft — черновик { day, time } из формы панели дня.
  let { days, habits, show, free, clock, layout, draft = null, stripOpen, fit = false, avail = $bindable(0), ontogglestrip, onpick, onopenhabits, onopen, ontoggle, ontogglehabit, oncompose, onmove = null } = $props();

  const hasAllday = $derived(days.some((d) => d.allday.length));
  const nowTop = $derived((clock, layout.yAt(nowMin())));
  const slots = $derived(Array.from({ length: 24 }, (_, h) => ({ h, top: layout.Y[h], ht: layout.HT[h], t: String(h).padStart(2, '0') + ':00' })));

  // Перетаскивание задачи: в сетку — новый день и время (длительность сохраняется), в «весь день» — день без времени.
  let drag = $state(null); // { it, dur }
  let drop = $state(null); // { day, s } — куда встанет; s = null — «весь день»
  const len = (it) => (it.s != null ? Math.max(15, it.e - it.s) : 60);
  function startDrag(e, it) {
    if (!onmove || it.done) return e.preventDefault();
    drag = { it, dur: len(it) };
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', it.title);
  }
  // Минута под курсором по раскладке часов (обратное к layout.yAt), с шагом 15 минут.
  function minAt(e) {
    const y = e.clientY - e.currentTarget.getBoundingClientRect().top;
    let h = 0;
    while (h < 23 && layout.Y[h + 1] <= y) h++;
    const m = h * 60 + Math.max(0, Math.min(1, (y - layout.Y[h]) / layout.HT[h])) * 60;
    return Math.min(1440 - drag.dur, Math.max(0, Math.round(m / 15) * 15));
  }
  function over(e, day, grid) {
    if (!drag) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    drop = { day, s: grid ? minAt(e) : null };
  }
  function put(e) {
    if (!drag || !drop) return;
    e.preventDefault();
    const { it } = drag, { day, s } = drop;
    drag = drop = null;
    if (day !== it.day || s !== it.s) onmove(it, day, s);
  }
  const endDrag = () => (drag = drop = null);

  const dotClass = (x) => (!x.sched ? 'off' : x.done ? 'done' : x.isToday ? 'now' : 'plan');
</script>

<div class="cal-week">
  <div class="wk wk-head">
    <span></span>
    {#each days as d (d.ymd)}
      <button type="button" class="dh" class:sel={d.isSel} onclick={() => onpick(d.ymd)} aria-label="{d.weekday}, {d.title}">
        <span class="w">{d.short}</span>
        <span class="num" class:today={d.isToday} class:weekend={d.weekend}>{d.n}</span>
        {#if d.holiday}<span class="hol" title={d.holiday}>выходной</span>{/if}
      </button>
    {/each}
  </div>

  {#if show.habits && habits.length}
    <div class="wk-habits">
      <div class="wk" style="min-height: 34px">
        <button type="button" class="hstrip" aria-expanded={stripOpen} onclick={ontogglestrip} title="Показать все привычки недели">
          привычки
          <svg viewBox="0 0 24 24" aria-hidden="true" class:flip={stripOpen}><path d="M6 9l6 6 6-6" /></svg>
        </button>
        {#each days as d (d.ymd)}
          <button type="button" class="dotbtn" class:sel={d.isSel} onclick={() => onopenhabits(d.ymd)}
            aria-label="Привычки на {d.title}: {d.hSched}{d.future ? '' : `, сделано ${d.hDone}`} — показать список">
            {#each d.habits as x (x.h.id)}<span class="hd {dotClass(x)}"></span>{/each}
            <span class="cnt">{d.future || !d.hSched ? '' : `${d.hDone}/${d.hSched}`}</span>
          </button>
        {/each}
      </div>
      {#if stripOpen}
        <div class="hgrid">
          {#each habits as h, i (h.id)}
            <div class="wk" style="min-height: 30px; align-items: center">
              <span class="hname" title={h.name}>{h.name}</span>
              {#each days as d (d.ymd)}
                {@const x = d.habits[i]}
                <span class="hcell" class:sel={d.isSel}>
                  <button type="button" class="ring {dotClass(x)}" disabled={!(x.isToday && x.sched)} onclick={() => ontogglehabit(h)}
                    aria-label="{h.name}, {d.title}: {!x.sched ? 'не по расписанию' : x.done ? 'сделано' : x.isToday ? 'отметить' : x.future ? 'по плану' : 'пропуск'}">
                    {#if x.done}<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>{/if}
                  </button>
                </span>
              {/each}
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}

  {#if hasAllday}
    <div class="wk wk-allday">
      <span class="lbl" style="padding-top: 10px">весь день</span>
      {#each days as d (d.ymd)}
        <div class="adcol" class:sel={d.isSel} class:drop={drop && drop.day === d.ymd && drop.s === null}
          ondragover={(e) => over(e, d.ymd, false)} ondrop={put} role="group" aria-label="Весь день, {d.title}">
          {#each d.allday as a (a.id)}
            <div class="ad k-{a.kind}" class:done={a.done} class:lift={drag?.it.id === a.id}
              draggable={a.kind === 'task' && !a.done && !!onmove} ondragstart={(e) => startDrag(e, { ...a, day: d.ymd })} ondragend={endDrag}
              style="--c: {a.type ? typeColor(a.type) : 'var(--ink-soft)'}">
              {#if a.kind === 'task'}
                <button type="button" class="chk" class:on={a.done} aria-label={a.done ? 'Вернуть в работу' : 'Выполнено'} onclick={() => ontoggle(a)}></button>
                <button type="button" class="tx link" class:over={a.overdue} onclick={() => onopen(a)} title={a.title}>{a.title}</button>
              {:else}
                <span class="tx" title="{a.title} · {a.cal}">{a.title}</span>
              {/if}
            </div>
          {/each}
        </div>
      {/each}
    </div>
  {/if}

  <!-- В режиме fit обёртка занимает остаток высоты; её высоту календарь отдаёт в hourLayout. -->
  <div class="wk-fit" class:on={fit} bind:clientHeight={avail}>
  <div class="wk wk-grid">
    <div class="hours" style="height: {layout.height}px">
      {#each layout.labels as l (l.key)}<span class="lbl" class:small={l.small} style="top: {l.top}px">{l.text}</span>{/each}
    </div>
    {#each days as d (d.ymd)}
      <div class="col" class:sel={d.isSel} style="height: {layout.height}px"
        ondragover={(e) => over(e, d.ymd, true)} ondrop={put} role="group" aria-label={d.title}>
        {#each layout.bands as bd (bd.top)}<div class="band" style="top: {bd.top}px; height: {bd.h}px"></div>{/each}
        {#each layout.lines as y (y)}<div class="hline" style="top: {y}px"></div>{/each}
        {#each slots as sl (sl.h)}
          <button type="button" class="slot" data-t={sl.ht > 20 ? '+ ' + sl.t : ''} tabindex="-1" aria-label="Добавить на {d.title}, {sl.t}"
            style="top: {sl.top}px; height: {sl.ht}px" onclick={() => oncompose(d.ymd, sl.t)}></button>
        {/each}
        {#each d.blocks as b (b.id)}
          <div class="blk k-{b.kind}" class:done={b.done} class:lift={drag?.it.id === b.id}
            draggable={b.kind === 'task' && !b.done && !!onmove} ondragstart={(e) => startDrag(e, { ...b, day: d.ymd })} ondragend={endDrag}
            style="top: {b.top}px; height: {b.height}px; left: calc({(b.col / b.cols) * 100}% + 3px); width: calc({100 / b.cols}% - 6px); --c: {b.type ? typeColor(b.type) : 'var(--ink-soft)'}">
            <div class="bt">
              {#if b.kind === 'task'}
                <button type="button" class="chk" class:on={b.done} aria-label={b.done ? 'Вернуть в работу' : 'Выполнено'} onclick={() => ontoggle(b)}></button>
                <button type="button" class="tx link" onclick={() => onopen(b)} title={b.title}>{b.title}</button>
              {:else}
                <span class="tx" title="{b.title} · {b.cal}">{b.title}</span>
              {/if}
            </div>
            {#if b.height >= 34}<span class="tm">{fromMin(b.s)}–{fromMin(Math.min(b.e, 1440))}</span>{/if}
          </div>
        {/each}
        {#if free && free.day === d.ymd}
          <div class="free" style="top: {layout.yAt(free.s) + 1}px; height: {layout.yAt(free.e) - layout.yAt(free.s) - 2}px">свободное окно</div>
        {/if}
        {#if draft && draft.day === d.ymd && draft.time}
          <div class="ghost" style="top: {layout.yAt(toMin(draft.time)) + 1}px; height: 38px">{draft.title || 'Новое · ' + draft.time}</div>
        {/if}
        {#if drop && drop.day === d.ymd && drop.s !== null}
          <div class="ghost" style="top: {layout.yAt(drop.s) + 1}px; height: {Math.max(18, layout.yAt(drop.s + drag.dur) - layout.yAt(drop.s) - 2)}px">{fromMin(drop.s)}–{fromMin(drop.s + drag.dur)} · {drag.it.title}</div>
        {/if}
        {#if d.isToday}<div class="now" style="top: {nowTop}px"></div>{/if}
      </div>
    {/each}
  </div>
  </div>
</div>
