<script>
  import { GRID_START, GRID_END, HOUR_PX, fromMin, typeColor, nowMin } from './calendar.js';

  let { days, habits, show, free, clock, stripOpen, ontogglestrip, onpick, onopenhabits, onopen, ontoggle, ontogglehabit, oncreate } = $props();

  const hours = Array.from({ length: (GRID_END - GRID_START) / 60 }, (_, i) => GRID_START / 60 + i);
  const gridH = ((GRID_END - GRID_START) / 60) * HOUR_PX;
  const hasAllday = $derived(days.some((d) => d.allday.length));
  const nowTop = $derived.by(() => { clock; const m = nowMin(); return m >= GRID_START && m <= GRID_END ? ((m - GRID_START) / 60) * HOUR_PX : null; });

  const dotClass = (x) => (!x.sched ? 'off' : x.done ? 'done' : x.isToday ? 'now' : 'plan');

  // Клик по пустому месту колонки — новая задача на этот час.
  function slotClick(e, d) {
    const r = e.currentTarget.getBoundingClientRect();
    const min = GRID_START + Math.floor(((e.clientY - r.top) / HOUR_PX) * 2) * 30;
    const s = Math.min(GRID_END - 60, Math.max(GRID_START, min));
    oncreate({ day: d.ymd, s: fromMin(s), e: fromMin(s + 60) });
  }
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
        <div class="adcol" class:sel={d.isSel}>
          {#each d.allday as a (a.id)}
            <div class="ad k-{a.kind}" class:done={a.done} style="--c: {a.type ? typeColor(a.type) : 'var(--ink-soft)'}">
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

  <div class="wk wk-grid">
    <div class="hours" style="height: {gridH}px">
      {#each hours as h, i (h)}<span class="lbl" style="top: {i === 0 ? 2 : i * HOUR_PX - 7}px">{String(h).padStart(2, '0')}:00</span>{/each}
    </div>
    {#each days as d (d.ymd)}
      <div class="col" class:sel={d.isSel} style="height: {gridH}px">
        <button type="button" class="slot" tabindex="-1" aria-label="Новая задача на {d.title}" onclick={(e) => slotClick(e, d)}></button>
        {#each d.blocks as b (b.id)}
          <div class="blk k-{b.kind}" class:done={b.done}
            style="top: {b.top}px; height: {b.height}px; left: calc({(b.col / b.cols) * 100}% + 3px); width: calc({100 / b.cols}% - 6px); --c: {b.type ? typeColor(b.type) : 'var(--ink-soft)'}">
            <div class="bt">
              {#if b.kind === 'task'}
                <button type="button" class="chk" class:on={b.done} aria-label={b.done ? 'Вернуть в работу' : 'Выполнено'} onclick={() => ontoggle(b)}></button>
                <button type="button" class="tx link" onclick={() => onopen(b)} title={b.title}>{b.title}</button>
              {:else}
                <span class="tx" title="{b.title} · {b.cal}">{b.title}</span>
              {/if}
            </div>
            {#if b.s < GRID_START || b.s >= GRID_END}<span class="tm">{fromMin(b.s)} — вне сетки</span>
            {:else if b.height >= 34}<span class="tm">{fromMin(b.s)}–{fromMin(Math.min(b.e, 1440))}</span>{/if}
          </div>
        {/each}
        {#if free && free.day === d.ymd}
          <div class="free" style="top: {((free.s - GRID_START) / 60) * HOUR_PX + 1}px; height: {((free.e - free.s) / 60) * HOUR_PX - 2}px">свободное окно</div>
        {/if}
        {#if d.isToday && nowTop != null}<div class="now" style="top: {nowTop}px"></div>{/if}
      </div>
    {/each}
  </div>
</div>
