<script>
  import { WD_SHORT, MONTH_GEN, fromMin, typeColor } from './calendar.js';

  let { days, month, show, onpick, onopenhabits } = $props();
  const MAX = 3;
</script>

<div class="cal-month">
  <div class="mh">{#each WD_SHORT as w (w)}<span>{w}</span>{/each}</div>
  <div class="mgrid">
    {#each days as d (d.ymd)}
      <div class="cellw" class:weekend={d.weekend || d.holiday} class:out={d.month !== month} class:sel={d.isSel}>
        <button type="button" class="cell" onclick={() => onpick(d.ymd)} aria-label="{d.n} {MONTH_GEN[d.month]}, записей: {d.items.length}">
          <span class="ch">
            <span class="num" class:today={d.isToday}>{d.n === 1 && d.month !== month ? `1 ${MONTH_GEN[d.month].slice(0, 4)}.` : d.n}</span>
            {#if d.holiday}<span class="note">выходной</span>{/if}
          </span>
          {#each d.items.slice(0, MAX) as it (it.id)}
            <span class="it k-{it.kind}" class:done={it.done} class:over={it.overdue} style="--c: {it.type ? typeColor(it.type) : 'var(--ink-soft)'}">
              <span class="mk k-{it.kind}" class:on={it.done}></span>
              <span class="tx">{it.s != null ? fromMin(it.s) + ' ' : ''}{it.title}</span>
            </span>
          {/each}
          {#if d.items.length > MAX}<span class="more">ещё {d.items.length - MAX}</span>{/if}
        </button>
        {#if show.habits && !d.future && d.hSched}
          <button type="button" class="hbar" title="Привычки: {d.hDone} из {d.hSched} — открыть список" aria-label="Привычки: {d.hDone} из {d.hSched} — открыть список" onclick={() => onopenhabits(d.ymd)}>
            <span><span style="width: {Math.round((d.hDone / d.hSched) * 100)}%"></span></span>
          </button>
        {/if}
      </div>
    {/each}
  </div>
</div>
