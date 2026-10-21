<script>
  import { WD_SHORT, MONTH_GEN, fromMin, typeColor } from './calendar.js';

  let { days, month, show, onpick, onopenhabits, onmove = null } = $props();

  // Перетаскивание задачи на другой день: время (если было) сохраняется.
  let drag = $state(null); // { it, day }
  let dropDay = $state(null);
  function startDrag(e, it, day) {
    if (!onmove || it.kind !== 'task' || it.done) return e.preventDefault();
    e.stopPropagation();
    drag = { it, day };
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', it.title);
  }
  function over(e, day) {
    if (!drag) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    dropDay = day;
  }
  function put(e, day) {
    if (!drag) return;
    e.preventDefault();
    const { it, day: from } = drag;
    drag = dropDay = null;
    if (day !== from) onmove(it, day, it.s);
  }
  const endDrag = () => (drag = dropDay = null);
  const MAX = 3;
</script>

<div class="cal-month">
  <div class="mh">{#each WD_SHORT as w (w)}<span>{w}</span>{/each}</div>
  <div class="mgrid">
    {#each days as d (d.ymd)}
      <div class="cellw" class:weekend={d.weekend || d.holiday} class:out={d.month !== month} class:sel={d.isSel} class:drop={dropDay === d.ymd}
        ondragover={(e) => over(e, d.ymd)} ondrop={(e) => put(e, d.ymd)} role="group" aria-label="{d.n} {MONTH_GEN[d.month]}">
        <button type="button" class="cell" onclick={() => onpick(d.ymd)} aria-label="{d.n} {MONTH_GEN[d.month]}, записей: {d.items.length}">
          <span class="ch">
            <span class="num" class:today={d.isToday}>{d.n === 1 && d.month !== month ? `1 ${MONTH_GEN[d.month].slice(0, 4)}.` : d.n}</span>
            {#if d.holiday}<span class="note">выходной</span>{/if}
          </span>
          {#each d.items.slice(0, MAX) as it (it.id)}
            <span class="it k-{it.kind}" class:done={it.done} class:over={it.overdue} class:lift={drag?.it.id === it.id}
              draggable={it.kind === 'task' && !it.done && !!onmove} ondragstart={(e) => startDrag(e, it, d.ymd)} ondragend={endDrag} role="presentation"
              style="--c: {it.type ? typeColor(it.type) : 'var(--ink-soft)'}">
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
