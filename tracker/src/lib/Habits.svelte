<script>
  // «Привычки: карточки» (утверждено 23.10, docs/design-v2.md; макеты design/screens/Habits*.dc.html).
  // Одна главная зона — сетка карточек; «сделано» везде одним золотым; подробности — в панели по клику на название.
  import * as H from './habits.js';
  import { ymd } from './api.js';
  import { ICONS, iconOf, colorOf, PRESETS } from './habitIcons.js';
  import Coon from './Coon.svelte';
  import HabitPanel from './HabitPanel.svelte';
  import HabitEdit from './HabitEdit.svelte';
  import ConfirmDelete from './ConfirmDelete.svelte';
  import { fade, pop } from './motion.js';

  // habits: [{ id, name, days, time, end, part, perWeek, goal, icon, color, remind, tipHide, createdAt }]; log — отметки из слоя;
  // cele — свежая веха { id, text, n }.
  let { habits, log, cele = null, open = null, onopened, ontoggle, onday, onclosecele, oncreate, onupdate, ondelete, onregister } = $props();

  const WEEK = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
  const now = new Date();
  const today = ymd(now);
  const partNow = now.getHours() < 12 ? 'утро' : now.getHours() < 18 ? 'день' : 'вечер';
  const dateLine = `${WEEK[now.getDay()]}, ${now.getDate()} ${H.MONTH_GEN[now.getMonth()]} · ${partNow}`;

  // Фильтр «часть дня» и «Сегодня | Месяц» запоминаются на этом компьютере.
  const ls = (k, d) => { try { return localStorage.getItem(k) ?? d; } catch { return d; } };
  let part = $state(ls('hb.part', 'all'));
  let mode = $state(ls('hb.mode', 'today'));
  $effect(() => { try { localStorage.setItem('hb.part', part); localStorage.setItem('hb.mode', mode); } catch {} });

  const sorted = $derived(H.sortHabits(habits));
  const idx = $derived(new Map(habits.map((h, i) => [h.id, i])));
  const counts = $derived(Object.fromEntries(H.PARTS.map((p) => [p.id, sorted.filter((h) => H.partOf(h) === p.id).length])));
  $effect(() => { if (part !== 'all' && !counts[part]) part = 'all'; });
  const shown = $derived(part === 'all' ? sorted : sorted.filter((h) => H.partOf(h) === part));

  const rows = $derived(shown.map((h) => {
    const s = H.stats(h, log);
    const g = H.goalN(h);
    return {
      h, s, g, n: g ? H.countOn(log, h, today) : 0,
      icon: ICONS[iconOf(h, idx.get(h.id))], color: colorOf(h, idx.get(h.id)),
      dots: H.last7(h, log, now), line: H.cardLine(h, log, now),
      unit: H.plural(s.streak, H.unitForms(h)), brk: H.broken(h, log, now),
    };
  }));

  const todayList = $derived(habits.filter((h) => H.scheduledOn(h, log, today) || H.isDone(log, h.id, today)));
  const doneToday = $derived(todayList.filter((h) => H.isDone(log, h.id, today)).length);
  const tip = $derived(H.habitTip(habits, log, now));

  // Реплика енота: ближайшая веха самой длинной серии, иначе — сколько осталось на сегодня.
  const say = $derived.by(() => {
    if (cele) return 'Флажок поднят! Так держать.';
    if (todayList.length && doneToday === todayList.length) return 'Все на сегодня. Енот гордится.';
    const top = habits.map((h) => ({ h, s: H.stats(h, log) })).filter((x) => x.s.streak > 0).sort((a, b) => b.s.streak - a.s.streak)[0];
    if (top && top.s.streak < H.MILESTONES[H.MILESTONES.length - 1]) {
      const left = H.nextMilestone(top.s.streak) - top.s.streak;
      const short = top.h.name.split(/[\s,]/)[0];
      return `${short} — ${top.s.streak} ${H.plural(top.s.streak, H.unitForms(top.h))}! До вехи ${H.nextMilestone(top.s.streak)} ${H.plural(left, ['остался', 'осталось', 'осталось'])} ${left}.`;
    }
    const left = todayList.length - doneToday;
    return left ? `Осталось ${left} на сегодня. Маленький шаг тоже считается.` : 'Сегодня по расписанию ничего — отдыхай.';
  });

  // Месяц: один на экран, вперёд дальше текущего не листаем.
  let mo = $state(0);
  const mDate = $derived(new Date(now.getFullYear(), now.getMonth() + mo, 1));
  const mRows = $derived(shown.map((h) => ({ h, icon: ICONS[iconOf(h, idx.get(h.id))], color: colorOf(h, idx.get(h.id)), r: H.monthRow(h, log, mDate.getFullYear(), mDate.getMonth(), now) })));
  const mDays = $derived(Array.from({ length: new Date(mDate.getFullYear(), mDate.getMonth() + 1, 0).getDate() }, (_, i) => {
    const d = new Date(mDate.getFullYear(), mDate.getMonth(), i + 1);
    return { n: i + 1, wd: H.WEEKDAYS[H.dow(d)], today: ymd(d) === today };
  }));
  const sum = $derived(H.monthSummary(shown, log, mDate.getFullYear(), mDate.getMonth(), now));
  const sumText = $derived.by(() => {
    if (sum.pct === null) return null;
    const prevName = H.MONTH_NAMES[(mDate.getMonth() + 11) % 12].toLowerCase();
    const prevIn = prevName.endsWith('ь') || prevName.endsWith('й') ? prevName.slice(0, -1) + 'е' : prevName + 'е';
    const bits = [];
    if (sum.prev !== null) bits.push(`в ${prevIn} было ${sum.prev}%`);
    const clean = sum.clean.map((x, i) => (i ? x.toLowerCase() : x));
    return { head: `${H.MONTH_NAMES[mDate.getMonth()]} — ${sum.pct}%`, rest: [bits[0], clean.length ? `${clean.slice(0, 2).join(' и ')} — без единого пропуска` : '', sum.weak ? `Слабее всего ${sum.weak}` : ''].filter(Boolean) };
  });

  // Панель привычки, окно привычки, удаление.
  let openId = $state(null);
  // Привычка из поиска Ctrl+K: App передаёт { id } — открыть её панель (новый объект — даже ту же второй раз).
  $effect(() => { if (open?.id) { openId = open.id; mode = 'today'; onopened?.(); } });
  const openH = $derived(habits.find((h) => h.id === openId) ?? null);
  let edit = $state(null); // null | { habit } | { preset }
  let delId = $state(null);
  function openForm(h = null, preset = null) { edit = { habit: h, preset }; }
  $effect(() => { onregister?.(() => openForm()); return () => onregister?.(null); });

  async function save(fields) {
    if (edit?.habit) await onupdate(edit.habit.id, fields);
    else await oncreate(fields);
    edit = null;
  }
  function moveTip() {
    if (!tip) return;
    onupdate(tip.habit.id, { name: tip.habit.name, ...H.winFields(H.moveWin(tip.habit, tip.time)), part: H.partOf({ time: tip.time }) });
  }
  function hideTip() {
    if (!tip) return;
    const d = new Date(); d.setDate(d.getDate() + 7);
    onupdate(tip.habit.id, { name: tip.habit.name, tipHide: ymd(d) });
  }

  // Меню прошлого дня: Сделано (Space) / Пропуск (X) / Не считать (O).
  let menu = $state(null); // { h, day, x, y }
  function pickDay(h, day, e) {
    if (day > today) return;
    const r = e.currentTarget.getBoundingClientRect();
    menu = { h, day, x: Math.min(r.left, window.innerWidth - 250), y: Math.min(r.bottom + 6, window.innerHeight - 150) };
  }
  function setDay(state) {
    if (!menu) return;
    onday(menu.h, menu.day, state);
    menu = null;
  }
  function menuKey(e) {
    if (!menu) return;
    const k = { Space: 'done', KeyX: 'miss', KeyO: 'skip' }[e.code];
    if (k) { e.preventDefault(); e.stopPropagation(); setDay(k); }
    else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); menu = null; }
  }
  const dayTitle = (s) => { const [, m, d] = s.split('-').map(Number); return `${d} ${H.MONTH_GEN[m - 1]}`; };
  const DOT_TITLE = { d: 'сделано', p: 'частично', m: 'пропуск', k: 'не считать', o: 'не по расписанию', w: 'свободный день', f: '' };
</script>

<svelte:window onkeydowncapture={menuKey} />

{#snippet check()}<svg class="li" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>{/snippet}
{#snippet plus(cls = 'li')}<svg class={cls} viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>{/snippet}
{#snippet hic(r, size = 40)}<span class="hb-ic" style="--hc: {r.color}; width: {size}px; height: {size}px"><svg class="li" viewBox="0 0 24 24" aria-hidden="true">{@html r.icon}</svg></span>{/snippet}
{#snippet mark(r, size = 44)}
  {#if r.g && !r.s.todayDone}
    <button type="button" class="hb-chk q" style="width: {size}px; height: {size}px" title="Плюс один: {r.n + 1} из {r.g}" aria-label="Плюс один: {r.h.name}" onclick={() => ontoggle(r.h)}>+1</button>
  {:else}
    <button type="button" class="hb-chk" style="width: {size}px; height: {size}px" aria-pressed={r.s.todayDone} aria-label="{r.s.todayDone ? 'Снять отметку' : 'Отметить'}: {r.h.name}" onclick={() => ontoggle(r.h)}>{@render check()}</button>
  {/if}
{/snippet}

<div class="hb-page">
  <header class="hb-top">
    <div class="l">
      <p>{dateLine}</p>
      <h1>Привычки</h1>
    </div>
    {#if habits.length && mode === 'today'}
      <div class="hb-hello"><Coon pose={cele ? 'cheer' : 'flag'} size={56} /><p class="bub" aria-live="polite">{say}</p></div>
    {:else}<span class="sp"></span>{/if}
    {#if habits.length}<span class="hb-prog"><b>{doneToday}</b> из {todayList.length} сегодня</span>{/if}
    <button type="button" class="hb-btn" onclick={() => openForm()}>{@render plus()}Привычка</button>
  </header>

  {#if !habits.length}
    <section class="hb-empty">
      <Coon pose="hi" size={140} />
      <h3>Начни с одной маленькой привычки</h3>
      <p>Я буду считать серии и праздновать 7, 21, 50 и 100 дней. Напомню в Telegram, если забудешь.</p>
      <div class="hb-tpls">
        {#each PRESETS as p, i (p.name)}
          <button type="button" class="hb-tpl" onclick={() => openForm(null, p)}>
            {@render hic({ color: colorOf(p, i), icon: ICONS[p.icon] }, 38)}<span><b>{p.name}</b><small>{p.sub}</small></span>
          </button>
        {/each}
        <button type="button" class="hb-tpl own" onclick={() => openForm()}>
          <span class="hb-ic" style="--hc: var(--ink-faint); width: 38px; height: 38px">{@render plus()}</span><span><b>Своя привычка</b><small>с нуля</small></span>
        </button>
      </div>
    </section>
  {:else}
    <div class="hb-bar">
      <div class="chips" role="group" aria-label="Часть дня">
        <button type="button" class="hb-fchip" aria-pressed={part === 'all'} onclick={() => (part = 'all')}>Все · {habits.length}</button>
        {#each H.PARTS as p (p.id)}
          {#if counts[p.id]}<button type="button" class="hb-fchip" aria-pressed={part === p.id} onclick={() => (part = p.id)}>{p.name} · {counts[p.id]}</button>{/if}
        {/each}
      </div>
      <div class="hb-seg" role="group" aria-label="Вид">
        <button type="button" aria-pressed={mode === 'today'} onclick={() => (mode = 'today')}>Сегодня</button>
        <button type="button" aria-pressed={mode === 'month'} onclick={() => (mode = 'month')}>Месяц</button>
      </div>
    </div>

    {#if mode === 'today'}
      <div class="hb-grid">
        {#each rows as r (r.h.id)}
          {#if cele?.id === r.h.id}
            <article class="hb-card cele" role="status">
              {#each [['#E0A04A', 8, 12, 20], ['#6FB6CF', 22, 6, -30], ['#D9774F', 40, 16, 45], ['#B79BE6', 64, 8, -15], ['#8FBF7F', 80, 14, 30], ['#E0A04A', 92, 5, -40]] as [c, x, y, rot], i (i)}
                <i class="conf" style="background: {c}; left: {x}%; top: {y}%; --r: {rot}deg"></i>
              {/each}
              <div class="row">
                <Coon pose="cheer" size={84} />
                <div class="tx">
                  <small>Новая веха · {cele.n}</small>
                  <h3>{cele.text}</h3>
                  <p>{H.milestoneDate(r.h, log, cele.n, now) ? `Следующая веха — ${H.nextMilestone(cele.n)}, ${H.milestoneDate(r.h, log, cele.n, now)}.` : `Следующая веха — ${H.nextMilestone(cele.n)}.`}</p>
                </div>
              </div>
              <div class="hf"><span></span><button type="button" class="hb-btn pri" onclick={onclosecele}>Ура!</button></div>
            </article>
          {:else if r.brk && !r.s.todayDone}
            <article class="hb-card brk">
              <div class="hh">{@render hic(r)}<div class="t"><button type="button" class="nm" onclick={() => (openId = r.h.id)}>{r.h.name}</button><span>{r.line}</span></div></div>
              <div class="row">
                <Coon pose="sleep" size={64} />
                <div><div class="hb-st"><b class="z">0</b></div><p>Серия прервалась — было {r.brk.was} {H.plural(r.brk.was, H.unitForms(r.h))}.{#if r.s.best > r.brk.was} Лучшая, {r.s.best}, никуда не делась.{/if}</p></div>
              </div>
              <div class="hf">
                <button type="button" class="hb-btn gh" onclick={() => openForm(r.h)}>Перенести время</button>
                <button type="button" class="hb-btn pri" onclick={() => ontoggle(r.h)}>{r.g ? '+1 · начать заново' : 'Начать заново сегодня'}</button>
              </div>
            </article>
          {:else}
            <article class="hb-card" class:done={r.s.todayDone}>
              <div class="hh">
                {@render hic(r)}
                <div class="t"><button type="button" class="nm" title="Подробнее" onclick={() => (openId = r.h.id)}>{r.h.name}</button><span class:warn={!r.s.streak && r.s.best > 0}>{r.line}{!r.s.streak && r.s.best > 0 ? ' · начни заново' : ''}</span></div>
                {@render mark(r)}
              </div>
              <div class="hm">
                <div class="hb-st">
                  {#if r.s.streak}<b class="g">✦ {r.s.streak}</b><span>{r.unit} подряд</span>
                  {:else}<b class="z">0</b><span>{r.s.best ? `лучшая ${r.s.best}` : 'отметь — и серия начнётся'}</span>{/if}
                </div>
                <div class="hb-d7" aria-label="Последние 7 дней">
                  {#each r.dots as d (d.day)}<span class:td={d.today}>{d.wd}</span>{/each}
                  {#each r.dots as d (d.day)}<i class="{d.st}" class:t={d.today} title="{dayTitle(d.day)}{DOT_TITLE[d.st] ? ' · ' + DOT_TITLE[d.st] : ''}"></i>{/each}
                </div>
              </div>
              {#if r.g}<div class="hb-qbar" title="{r.n} из {r.g} {r.h.goal.unit ?? ''}"><i style="width: {Math.min(100, (r.n / r.g) * 100)}%"></i></div>{/if}
            </article>
          {/if}
        {/each}
        <button type="button" class="hb-newc" onclick={() => openForm()}>{@render plus()}Новая привычка</button>
        {#if tip && part === 'all'}
          <div class="hb-tip" transition:fade>
            <Coon pose="think" size={92} />
            <div class="tx">
              <b>«{tip.habit.name}» {tip.misses >= 3 ? 'сорвалось три раза подряд' : 'срывается'}</b>
              <p>В {tip.habit.time} получается плохо. Может, перенести на {tip.time} — сразу после «{tip.anchor.name}»? Она держится хорошо, они потянут друг друга.</p>
              <div class="bt"><button type="button" class="hb-btn pri" onclick={moveTip}>Перенести на {tip.time}</button><button type="button" class="hb-btn gh" onclick={hideTip}>Не сейчас</button></div>
            </div>
          </div>
        {/if}
      </div>
    {:else}
      <section class="hb-mcard">
        <div class="mh">
          <h3>{H.MONTH_NAMES[mDate.getMonth()]}{mDate.getFullYear() !== now.getFullYear() ? ` ${mDate.getFullYear()}` : ''}</h3>
          <button type="button" class="nb" aria-label="Предыдущий месяц" onclick={() => mo--}>‹</button>
          <button type="button" class="nb" aria-label="Следующий месяц" disabled={mo >= 0} onclick={() => mo++}>›</button>
        </div>
        <div class="hb-mx" style="--nd: {mDays.length}">
          <span></span>
          {#each mDays as d (d.n)}<span class="wd" class:td={d.today}>{d.wd}<b>{d.n}</b></span>{/each}
          <span class="wd">месяц</span>
          {#each mRows as m (m.h.id)}
            <span class="nm">{@render hic(m, 30)}<button type="button" class="nmb" onclick={() => (openId = m.h.id)}>{m.h.name}</button></span>
            {#each m.r.cells as c (c.day)}
              <button type="button" class="hc {c.st}" class:t={c.today} disabled={c.st === 'f'} title="{dayTitle(c.day)}{DOT_TITLE[c.st] ? ' · ' + DOT_TITLE[c.st] : ''}" aria-label="{m.h.name}, {dayTitle(c.day)}{DOT_TITLE[c.st] ? ': ' + DOT_TITLE[c.st] : ''}" onclick={(e) => pickDay(m.h, c.day, e)}></button>
            {/each}
            <span class="pc">{m.r.pct === null ? '—' : m.r.pct + '%'}</span>
          {/each}
        </div>
        <p class="mfoot">Клик по прошлому дню — отметить задним числом: сделано, пропуск или «не считать».</p>
      </section>
      {#if sumText}
        <div class="hb-msum"><Coon pose="cheer" size={64} /><p><b>{sumText.head}</b>{sumText.rest.length ? ', ' + sumText.rest.join('. ') + '.' : '.'}</p></div>
      {/if}
    {/if}
  {/if}
</div>

{#if menu}
  <button class="drawer-back hb-menu-back" type="button" aria-label="Закрыть меню" onclick={() => (menu = null)}></button>
  <div class="cmenu hb-menu" role="menu" style="left: {menu.x}px; top: {menu.y}px" transition:pop>
    <p class="mt">{menu.h.name} · {dayTitle(menu.day)}</p>
    <button type="button" role="menuitem" onclick={() => setDay('done')}><i class="d"></i>Сделано<kbd>Space</kbd></button>
    <button type="button" role="menuitem" onclick={() => setDay('miss')}><i class="m"></i>Пропуск<kbd>X</kbd></button>
    <button type="button" role="menuitem" onclick={() => setDay('skip')}><i class="k"></i>Не считать — болел, уезжал<kbd>O</kbd></button>
  </div>
{/if}

{#if openH && !edit}
  <HabitPanel h={openH} {log} i={idx.get(openH.id)} onclose={() => (openId = null)} {ontoggle} onpick={pickDay}
    onedit={() => openForm(openH)} ondelete={() => (delId = openH.id)} onupdate={(f) => onupdate(openH.id, f)} />
{/if}

{#if edit}
  <HabitEdit habit={edit.habit} preset={edit.preset} i={edit.habit ? idx.get(edit.habit.id) : habits.length} onsave={save} onclose={() => (edit = null)} />
{/if}

{#if delId}
  <ConfirmDelete title="Удалить привычку?" text="«{habits.find((h) => h.id === delId)?.name}» уйдёт из списка «Привычки» вместе со всей историей отметок и серий."
    onconfirm={async () => { await ondelete(delId); delId = null; openId = null; }} onclose={() => (delId = null)} />
{/if}
