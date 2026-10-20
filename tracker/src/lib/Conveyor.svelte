<script>
  // Вид «Конвейер» и «Галерея» (design/screens/Assets.dc.html): строка = задача (ассет), дорожка этапов = колонки шаблона
  // без последней («Готово»). Этап — слой tasks[id].status, дата входа в этап — tasks[id].stageAt[этап].
  // Подзадачи этапа — вложенные задачи Google Tasks, помеченные этапом в слое (tasks[sub].stage).
  import { tick } from 'svelte';
  import { dueToYmd, humanDue, ymd } from './api.js';
  import { plural } from './habits.js';
  import { startOfWeek, addDays } from './calendar.js';

  let { list, tasks, cols, colOf, layTasks, visible = () => true, gallery = false, project = null,
    onopen, onmove, ontoggle, onaddsub, onsetstage } = $props();

  const stages = $derived(cols.slice(0, -1));
  const endCol = $derived(cols[cols.length - 1]);
  const top = $derived(tasks.filter((t) => !t.parent && visible(t)));
  const subsOf = (id) => tasks.filter((t) => t.parent === id).sort((a, b) => (a.position || '').localeCompare(b.position || ''));
  const today = ymd(new Date());
  const weekEnd = ymd(addDays(startOfWeek(new Date()), 6));

  let filter = $state(''); // этап, по которому отфильтрованы строки
  let openId = $state('');

  const stageOf = (t) => colOf(t, cols);
  const daysOn = (t) => {
    const at = layTasks?.[t.id]?.stageAt?.[stageOf(t)];
    return at ? Math.max(0, Math.floor((Date.now() - at) / 864e5)) : null;
  };
  // Счётчики по этапам (и «Готово») — клик фильтрует строки.
  const dist = $derived(cols.map((c) => ({ c, n: top.filter((t) => stageOf(t) === c.id).length })));
  const maxN = $derived(Math.max(1, ...dist.map((d) => d.n)));
  const rows = $derived(top.filter((t) => (filter ? stageOf(t) === filter : stageOf(t) !== endCol.id || t.status !== 'completed' || Date.now() - new Date(t.completed).getTime() < 3 * 864e5)));
  // Группировка по проекту (tasks[id].project): сначала проекты по алфавиту, потом «Без проекта».
  const groups = $derived.by(() => {
    const g = {};
    for (const t of rows) (g[layTasks?.[t.id]?.project || ''] ??= []).push(t);
    const order = Object.keys(g).sort((a, b) => (!a) - (!b) || a.localeCompare(b, 'ru'));
    return order.map((p) => ({ title: p || 'Без проекта', rows: g[p].sort((a, b) => cols.findIndex((c) => c.id === stageOf(b)) - cols.findIndex((c) => c.id === stageOf(a)) || (a.position || '').localeCompare(b.position || '')) }));
  });
  const summary = $derived.by(() => {
    const inWork = top.filter((t) => t.status !== 'completed').length;
    const busiest = dist.filter((d) => d.c.id !== endCol.id).reduce((a, b) => (b.n > a.n ? b : a), { n: 0 });
    const week = top.filter((t) => t.status !== 'completed' && t.due && dueToYmd(t.due) <= weekEnd).length;
    return [
      `${inWork} ${plural(inWork, ['ассет', 'ассета', 'ассетов'])} в работе`,
      busiest.n ? `больше всего на этапе «${busiest.c.name}»` : '',
      week ? `${week} ${plural(week, ['срок', 'срока', 'сроков'])} на этой неделе` : '',
    ].filter(Boolean).join(' · ');
  });

  const nextOf = (t) => { const i = cols.findIndex((c) => c.id === stageOf(t)); return i >= 0 && i < cols.length - 1 ? cols[i + 1] : null; };
  const initials = (s) => (s || '?').split(/[\s·:—-]+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
  const dueCls = (t) => (t.due && dueToYmd(t.due) <= ymd(addDays(new Date(), 2)) && t.status !== 'completed' ? 'soon' : '');

  /** Подзадачи текущего этапа и «общие» (без этапа). */
  function checks(t) {
    const st = stageOf(t);
    const subs = subsOf(t.id);
    return { stage: subs.filter((s) => layTasks?.[s.id]?.stage === st), common: subs.filter((s) => !layTasks?.[s.id]?.stage) };
  }
  /** Время по этапам: от входа в этап до входа в следующий (последний — до сейчас). */
  function timeline(t) {
    const at = layTasks?.[t.id]?.stageAt ?? {};
    const pts = cols.filter((c) => at[c.id]).map((c) => ({ c, at: at[c.id] })).sort((a, b) => a.at - b.at);
    return pts.map((p, i) => {
      const to = i < pts.length - 1 ? pts[i + 1].at : (t.status === 'completed' ? p.at : Date.now());
      const d = (to - p.at) / 864e5;
      return { name: p.c.name, v: p.c.id === endCol.id ? 'готово' : d < 1 ? `${Math.max(1, Math.round(d * 24))} ч` : `${Math.round(d)} ${plural(Math.round(d), ['день', 'дня', 'дней'])}` };
    });
  }

  let subDraft = $state('');
  let subInput = $state(null);
  async function addSub(t) {
    const title = subDraft.trim();
    if (!title) return;
    subDraft = '';
    await onaddsub(t, title, stageOf(t));
    await tick();
    subInput?.focus();
  }
</script>

<section class="dist" aria-label="Сколько задач на каждом этапе — нажми, чтобы отфильтровать" style="grid-template-columns: repeat({cols.length}, minmax(0, 1fr))">
  {#each dist as d (d.c.id)}
    <button type="button" aria-pressed={filter === d.c.id} onclick={() => (filter = filter === d.c.id ? '' : d.c.id)}>
      <span>{d.c.name}</span><b>{d.n}</b><i><span style="width: {Math.round((d.n / maxN) * 100)}%"></span></i>
    </button>
  {/each}
</section>
<p class="cv-sum">{summary}{filter ? ` · фильтр: «${cols.find((c) => c.id === filter)?.name}»` : ''}</p>

{#if !gallery}
  <div class="cv">
    <div class="cv-head"><span>{list.title.includes('3D') || stages.length >= 6 ? 'Ассет' : 'Задача'}</span><span>Этапы</span><span>Срок</span><span></span></div>
    {#each groups as g (g.title)}
      {#if groups.length > 1 || g.title !== 'Без проекта'}<p class="grp">{g.title}</p>{/if}
      {#each g.rows as t (t.id)}
        {@const st = stageOf(t)}
        {@const si = stages.findIndex((c) => c.id === st)}
        {@const done = t.status === 'completed'}
        {@const nx = nextOf(t)}
        {@const ch = checks(t)}
        {@const allChecked = ch.stage.length > 0 && ch.stage.every((s) => s.status === 'completed')}
        {@const dn = daysOn(t)}
        <div class="cvr" class:open={openId === t.id}>
          <button type="button" class="name" aria-expanded={openId === t.id} onclick={() => (openId = openId === t.id ? '' : t.id)}>
            <span class="thumb">{initials(t.title)}</span>
            <span class="nm"><b>{t.title || 'Без названия'}</b><small>{layTasks?.[t.id]?.project ? `${layTasks[t.id].project} · ` : ''}{subsOf(t.id).length ? `подзадач ${subsOf(t.id).filter((s) => s.status === 'completed').length}/${subsOf(t.id).length}` : 'нажми, чтобы раскрыть'}</small></span>
          </button>
          <div>
            <div class="track" role="group" aria-label="Этапы: {done ? 'готово' : stages[si]?.name}" style="grid-template-columns: repeat({stages.length}, minmax(0, 1fr))">
              {#each stages as c, i (c.id)}
                <button type="button" class="st" class:done={done || i < si} class:now={!done && i === si} title="Поставить на этап «{c.name}»" onclick={() => onsetstage(t, c.id)}>{c.name}</button>
              {/each}
            </div>
            <div class="days" class:slow={!done && dn != null && dn >= 7}>
              {done ? 'готово' : dn == null ? 'время на этапе пока не считалось' : `на этапе ${dn} ${plural(dn, ['день', 'дня', 'дней'])}${dn >= 7 ? ' — дольше обычного' : ''}`}
            </div>
          </div>
          <span class="due {dueCls(t)}">{t.due ? humanDue(t.due) : '—'}</span>
          {#if !done && nx}
            <button type="button" class="adv" class:ready={allChecked} onclick={() => onmove(t, nx.id)}>{nx.id === endCol.id ? endCol.name : nx.name} →</button>
          {:else}
            <span class="fin">✓ {endCol.name.toLowerCase()}</span>
          {/if}
        </div>
        {#if openId === t.id}
          <div class="detail">
            <div>
              <p class="cap">{done ? 'Подзадачи' : `Этап «${stages[si]?.name ?? endCol.name}» · подзадачи`}</p>
              {#each ch.stage as s (s.id)}
                <div class="chk"><button type="button" class="box" aria-pressed={s.status === 'completed'} aria-label={s.title} onclick={() => ontoggle(s, s.status !== 'completed')}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg></button><span class:off={s.status === 'completed'}>{s.title}</span></div>
              {/each}
              {#if ch.common.length}
                <p class="cap sub">Без этапа</p>
                {#each ch.common as s (s.id)}
                  <div class="chk"><button type="button" class="box" aria-pressed={s.status === 'completed'} aria-label={s.title} onclick={() => ontoggle(s, s.status !== 'completed')}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg></button><span class:off={s.status === 'completed'}>{s.title}</span></div>
                {/each}
              {/if}
              {#if !done}
                <form class="add-sub" onsubmit={(e) => { e.preventDefault(); addSub(t); }}>
                  <input bind:this={subInput} bind:value={subDraft} placeholder="Подзадача этапа «{stages[si]?.name}»" aria-label="Новая подзадача этапа" />
                  <button class="sp-btn" type="submit" disabled={!subDraft.trim()}>+</button>
                </form>
              {/if}
              <p class="hint">Подзадачи — вложенные задачи в Google Tasks: видны и на телефоне. Когда все задачи этапа отмечены, кнопка следующего этапа загорается.</p>
            </div>
            <div class="side2">
              <p class="cap">Время по этапам</p>
              <div class="tl2">
                {#each timeline(t) as x (x.name)}<div><span>{x.name}</span><span>{x.v}</span></div>{:else}<p class="hint">Время начнёт считаться со следующей смены этапа.</p>{/each}
              </div>
              <button type="button" class="sp-btn sp-btn-ghost" style="align-self: flex-start; min-height: 30px" onclick={() => onopen(t)}>Открыть задачу</button>
              <p class="hint">Превью рендера появится, когда освободится место на Google Drive.</p>
            </div>
          </div>
        {/if}
      {/each}
    {:else}
      <p class="empty">{filter ? 'На этом этапе сейчас ничего нет.' : 'Пока пусто — добавь первую задачу кнопкой «Создать».'}</p>
    {/each}
  </div>
{:else}
  <div class="gal">
    {#each rows as t (t.id)}
      {@const st = stageOf(t)}
      {@const si = stages.findIndex((c) => c.id === st)}
      {@const done = t.status === 'completed'}
      {@const dn = daysOn(t)}
      <button type="button" class="gc" onclick={() => onopen(t)}>
        <span class="pv">{initials(t.title)}</span>
        <span class="gb">
          <span class="gt"><b>{t.title || 'Без названия'}</b><span class="due {dueCls(t)}">{t.due ? humanDue(t.due) : ''}</span></span>
          <span class="mini2" style="grid-template-columns: repeat({stages.length}, 1fr)">{#each stages as c, i (c.id)}<i class:done={done || i < si} class:now={!done && i === si}></i>{/each}</span>
          <small>{done ? endCol.name : stages[si]?.name}{!done && dn != null ? ` · ${dn} дн.` : ''}</small>
        </span>
      </button>
    {:else}
      <p class="empty">{filter ? 'На этом этапе сейчас ничего нет.' : 'Пока пусто.'}</p>
    {/each}
  </div>
{/if}
