<script>
  // Панель привычки (design/screens/HabitOpen.dc.html): 480 px справа поверх затемнения; Esc / ✕ — закрыть.
  import * as H from './habits.js';
  import { ymd } from './api.js';
  import { ICONS, iconOf, colorOf } from './habitIcons.js';
  import Coon from './Coon.svelte';
  import { fade, fly } from './motion.js';
  import HabitWin from './HabitWin.svelte';

  let { h, log, i = 0, onclose, ontoggle, onpick, onedit, ondelete, onupdate = null } = $props();

  const now = new Date();
  const today = ymd(now);
  const s = $derived(H.stats(h, log));
  const forms = $derived(H.unitForms(h));
  const g = $derived(H.goalN(h));
  const n = $derived(g ? H.countOn(log, h, today) : 0);
  const next = $derived(H.nextMilestone(s.streak));
  const left = $derived(next - s.streak);
  const mdate = $derived(H.milestoneDate(h, log, s.streak, now));
  const allDone = $derived(s.streak >= H.MILESTONES[H.MILESTONES.length - 1]);

  let mo = $state(0);
  const m = $derived(new Date(now.getFullYear(), now.getMonth() + mo, 1));
  const grid = $derived(H.monthRow(h, log, m.getFullYear(), m.getMonth(), now));
  const lead = $derived(H.dow(m));
  const pctNow = $derived(H.monthRow(h, log, now.getFullYear(), now.getMonth(), now).pct);
  const total = $derived(H.totalDone(h, log));
  const since = $derived.by(() => {
    if (!h.createdAt) return null;
    const [y, mm, d] = h.createdAt.slice(0, 10).split('-').map(Number);
    return `${d} ${H.MONTH_GEN[mm - 1]}${y !== now.getFullYear() ? ' ' + y : ''}`;
  });
  const at = $derived(H.remindAt(h));
  const win = $derived(H.habitWin(h));
  const remLine = $derived.by(() => {
    if (!at) return null;
    const where = [h.remind?.tg !== false ? 'в Telegram' : '', h.remind?.win ? 'в Windows' : ''].filter(Boolean);
    return where.length ? { at, where: where.join(' и ') } : null;
  });

  function key(e) { if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); onclose(); } }
</script>

<svelte:window onkeydown={key} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose} transition:fade={{ duration: 160 }}></button>
<aside class="hb-drw" role="dialog" aria-modal="true" aria-label="Привычка «{h.name}»" transition:fly={{ x: 40, duration: 220 }}>
  <div class="dh">
    <span class="hb-ic" style="--hc: {colorOf(h, i)}; width: 48px; height: 48px; border-radius: 14px"><svg class="li" viewBox="0 0 24 24" aria-hidden="true">{@html ICONS[iconOf(h, i)]}</svg></span>
    <div class="t"><b>{h.name}</b><span>{H.scheduleLine(h)}</span></div>
    <button type="button" class="hb-btn" onclick={onedit}>Изменить</button>
    <button type="button" class="hb-ib" aria-label="Закрыть" title="Закрыть · Esc" onclick={onclose}><svg class="li" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18" /></svg></button>
  </div>

  <div class="dbig">
    <div class="n">
      <b class:z={!s.streak}>{s.streak ? `✦ ${s.streak}` : '0'}</b>
      <span>{H.plural(s.streak, forms)} подряд{s.streak && s.streak >= s.best ? ' — лучшая серия' : s.best ? ` · лучшая — ${s.best}` : ''}</span>
    </div>
    {#if g && !s.todayDone}
      <button type="button" class="hb-chk q" style="width: 52px; height: 52px" title="{n} из {g}" aria-label="Плюс один" onclick={() => ontoggle(h)}>+1</button>
    {:else}
      <button type="button" class="hb-chk" style="width: 52px; height: 52px" aria-pressed={s.todayDone} aria-label={s.todayDone ? 'Снять отметку' : 'Отметить сегодня'} onclick={() => ontoggle(h)}><svg class="li" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg></button>
    {/if}
  </div>

  <div>
    <div class="hb-trk" aria-hidden="true">
      <div class="ln"><i style="width: {H.milestonePos(s.streak)}%"></i></div>
      {#each H.MILESTONES as ms (ms)}
        <span class="mk" class:on={s.streak >= ms} class:nx={ms === next && !allDone} style="left: {H.milestonePos(ms)}%"></span>
        <span class="lb" class:on={s.streak >= ms} style="left: {H.milestonePos(ms)}%">{ms}</span>
      {/each}
      {#if s.streak > 0 && !allDone}<span class="me" style="left: {H.milestonePos(s.streak)}%"><Coon pose="flag" size={30} /></span>{/if}
    </div>
    <p class="dnext">
      {#if allDone}Все вехи взяты! Лучшая серия — {s.best}.
      {:else}До вехи <b>{next}</b> — {left} {H.plural(left, forms)}{mdate ? `, это ${mdate}` : ''}.{/if}
    </p>
  </div>

  <section class="mon">
    <h3>
      <button type="button" class="nb" aria-label="Предыдущий месяц" onclick={() => mo--}>‹</button>
      {H.MONTH_NAMES[m.getMonth()]}{m.getFullYear() !== now.getFullYear() ? ` ${m.getFullYear()}` : ''}
      <button type="button" class="nb" aria-label="Следующий месяц" disabled={mo >= 0} onclick={() => mo++}>›</button>
      <span>{grid.sched ? `${grid.done} из ${grid.sched} · ` : ''}клик по дню — отметить</span>
    </h3>
    <div class="hb-mg">
      {#each H.WEEKDAYS as w (w)}<span class="wd">{w}</span>{/each}
      {#each Array(lead) as _, k (k)}<i class="e"></i>{/each}
      {#each grid.cells as c (c.day)}
        <button type="button" class="hc {c.st}" class:t={c.today} disabled={c.st === 'f'} aria-label="{c.n} {H.MONTH_GEN[m.getMonth()]}" onclick={(e) => onpick(h, c.day, e)}>{c.n}</button>
      {/each}
    </div>
  </section>

  <div class="hb-kp">
    <div><b>{pctNow === null ? '—' : pctNow + '%'}</b><span>за {H.MONTH_NAMES[now.getMonth()].toLowerCase()}</span></div>
    <div><b>{total}</b><span>{H.plural(total, ['раз', 'раза', 'раз'])} всего</span></div>
    <div><b>{s.best}</b><span>лучшая серия{since ? `, с ${since}` : ''}</span></div>
  </div>

  {#if win && onupdate}
    <div class="hb-rem hb-win"><svg class="li" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8" /><path d="M12 8v4l2.5 2.5" /></svg>
      <span>{H.partName(h)}</span><HabitWin {win} onchange={(w) => onupdate(H.winFields(w))} /></div>
  {/if}
  {#if remLine}
    <div class="hb-rem"><svg class="li" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20h4" /></svg>
      <span>Напомнит в <b>{remLine.at}</b> {remLine.where}, если не отмечено до {win.e}</span></div>
  {/if}

  <div class="dft"><button type="button" class="hb-del" onclick={ondelete}>Удалить вместе с историей</button></div>
</aside>
