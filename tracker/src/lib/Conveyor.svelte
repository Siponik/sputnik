<script>
  // Вид «Конвейер» и «Галерея» (design/screens/Conveyor.dc.html, docs/design-v2.md — «Канбан и Конвейер»).
  // Строка = задача (ассет), дорожка этапов = колонки шаблона без последней («Готово»). Этап — слой tasks[id].status,
  // дата входа в этап — tasks[id].stageAt[этап]. Подзадачи этапа — вложенные задачи Google Tasks с tasks[sub].stage.
  // Клик по строке — раскрыть/свернуть (раскрыта одна), окно задачи — Enter или «Открыть полностью ↗».
  // Превью ассета — tasks[id].preview (lib/preview.js): перетащить картинку на строку, Ctrl+V на выбранной строке или в раскрытой строке.
  import { tick } from 'svelte';
  import { dueToYmd, humanDue, ymd, dueState } from './api.js';
  import { plural } from './habits.js';
  import { startOfWeek, addDays } from './calendar.js';
  import { PRIORITIES, priorityOf } from './meta.js';
  import * as keys from './keys.js';
  import { expand } from './motion.js';
  import { imageFrom, dragHasFile, rejectWhy } from './preview.js';
  import PreviewBox from './PreviewBox.svelte';
  import Avatar from './Avatar.svelte';
  import WhoPick from './WhoPick.svelte';
  import { memberOf, whoOf, whoCounts, stageCrew, nextHint, passText } from './sharedcore.js';

  // act — действия из App (как на канбане); onmenu(t, anchor, expand, rename) — меню задачи доски.
  // share — общая сфера (docs/design-v2.md, «Общие сферы» 8): кто ведёт ассет (tasks[id].who) и исполнители этапов (stageWho).
  let { list, tasks, cols, colOf, layTasks, layList = {}, share = null, visible = () => true, gallery = false, remindOf = () => '',
    act, ontoggle, onaddsub, onmenu } = $props();
  const me = $derived(share?.me ?? '');
  const people = $derived(share?.people ?? []);
  const byPeople = $derived(!!share && layList?.cvGroup === 'people');
  const mOf = (email) => memberOf(people, email);
  const counts = $derived(share ? whoCounts(tasks, layTasks) : {});
  let whoPick = $state(null); // { t, col (null — кто ведёт ассет), anchor }
  function pickWho(t, col, anchor) { sel = t.id; whoPick = { t, col, anchor }; }
  function applyWho(w) {
    const { t, col } = whoPick;
    whoPick = null;
    if (col) act.stageWho(t, col, w); else act.who(t, w);
    focusRow(t.id);
  }

  const stages = $derived(cols.slice(0, -1));
  const endCol = $derived(cols[cols.length - 1]);
  const top = $derived(tasks.filter((t) => !t.parent && visible(t)));
  const subsOf = (id) => tasks.filter((t) => t.parent === id).sort((a, b) => (a.position || '').localeCompare(b.position || ''));
  const weekEnd = ymd(addDays(startOfWeek(new Date()), 6));
  const PC = { 1: 'var(--clay)', 2: 'var(--gold)', 3: 'var(--ink-faint)' };

  let filter = $state(''); // этап, по которому отфильтрованы строки
  let openId = $state('');
  let sel = $state('');

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
    if (byPeople) {
      // «По людям»: по тому, кто ведёт ассет; я первым, «Ничьи» последней.
      const order = [...people.filter((p) => p.email === me), ...people.filter((p) => p.email !== me)];
      const known = new Set(order.map((p) => p.email));
      const sorted = (rs) => rs.sort((a, b) => cols.findIndex((c) => c.id === stageOf(b)) - cols.findIndex((c) => c.id === stageOf(a)) || (a.position || '').localeCompare(b.position || ''));
      const out = order.map((p) => ({ title: p.email === me ? 'Я' : p.name, m: p, rows: sorted(rows.filter((t) => whoOf(layTasks?.[t.id]) === p.email)) })).filter((g) => g.rows.length);
      const none = rows.filter((t) => !known.has(whoOf(layTasks?.[t.id])));
      if (none.length) out.push({ title: 'Ничьи', m: null, rows: sorted(none) });
      return out;
    }
    const g = {};
    for (const t of rows) (g[layTasks?.[t.id]?.project || ''] ??= []).push(t);
    const order = Object.keys(g).sort((a, b) => (!a) - (!b) || a.localeCompare(b, 'ru'));
    return order.map((p) => ({ title: p || 'Без проекта', rows: g[p].sort((a, b) => cols.findIndex((c) => c.id === stageOf(b)) - cols.findIndex((c) => c.id === stageOf(a)) || (a.position || '').localeCompare(b.position || '')) }));
  });
  const flat = $derived(groups.flatMap((g) => g.rows));
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
  const prevOf = (t) => { const i = cols.findIndex((c) => c.id === stageOf(t)); return i > 0 ? cols[i - 1] : null; };
  const initials = (s) => (s || '?').split(/[\s·:—-]+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
  const dueCls = (t) => (t.status === 'completed' || !t.due ? '' : dueState(t) === 'overdue' ? 'late' : dueToYmd(t.due) <= ymd(addDays(new Date(), 2)) ? 'soon' : '');

  /** Подзадачи текущего этапа и подзадачи других этапов / без этапа. */
  function checks(t) {
    const st = stageOf(t);
    const subs = subsOf(t.id);
    return { stage: subs.filter((s) => layTasks?.[s.id]?.stage === st), other: subs.filter((s) => layTasks?.[s.id]?.stage !== st) };
  }
  /** Время по этапам: от входа в этап до входа в следующий (последний — до сейчас). */
  function timeline(t) {
    const at = layTasks?.[t.id]?.stageAt ?? {};
    const pts = cols.filter((c) => at[c.id]).map((c) => ({ c, at: at[c.id] })).sort((a, b) => a.at - b.at);
    const items = pts.map((p, i) => {
      const to = i < pts.length - 1 ? pts[i + 1].at : (t.status === 'completed' ? p.at : Date.now());
      return { c: p.c, d: (to - p.at) / 864e5, cur: i === pts.length - 1 && t.status !== 'completed' };
    }).filter((x) => x.c.id !== endCol.id);
    const max = Math.max(1 / 24, ...items.map((x) => x.d));
    const total = items.reduce((n, x) => n + x.d, 0);
    const fmt = (d) => (d < 1 ? `${Math.max(1, Math.round(d * 24))} ч` : `${Math.round(d)} дн.`);
    return { items: items.map((x) => ({ ...x, w: Math.max(4, Math.round((x.d / max) * 100)), v: fmt(x.d) })), total: total ? `всего ${fmt(total)}` : '' };
  }

  // ---------- раскрытие и выбор ----------
  async function toggleOpen(t) {
    sel = t.id;
    openId = openId === t.id ? '' : t.id;
    otherOpen = false;
    subDraft = '';
    if (openId) {
      await tick();
      document.querySelector(`.cvr[data-id="${t.id}"]`)?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }
  }
  async function focusRow(id) {
    sel = id;
    await tick();
    const el = document.querySelector(`.cvr[data-id="${id}"]`);
    el?.focus({ preventScroll: true });
    el?.scrollIntoView({ block: 'nearest' });
  }

  // Переименование: двойной клик по названию или F2.
  let editId = $state('');
  let editDraft = $state('');
  function startEdit(t) { editId = t.id; editDraft = t.title || ''; }
  function finishEdit(t, keep = true) {
    if (editId !== t.id) return;
    const title = editDraft.trim();
    editId = '';
    if (keep && title && title !== t.title) act.rename(t, title);
  }
  const focusSel = (el) => { el.focus(); el.select(); };
  const menuFor = (t, el, expand = '') => { sel = t.id; onmenu?.(t, el, expand, startEdit); };

  // Клавиши Конвейера: ↑↓ строки, →/← раскрыть/свернуть, Space — следующая, 1–7 — этап, плюс общие клавиши карточки.
  function onKey(e) {
    if (gallery || editId || whoPick || keys.typing(e) || keys.overlay()) return;
    const handled = () => { e.preventDefault(); e.stopPropagation(); };
    const t = flat.find((x) => x.id === sel) ?? null;
    const i = t ? flat.indexOf(t) : -1;
    if (!t) {
      if ((e.key === 'ArrowDown' || e.key === 'ArrowUp') && keys.plain(e) && flat.length) { handled(); focusRow(flat[0].id); }
      return;
    }
    if (e.altKey && !e.ctrlKey) {
      if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
        const to = e.key === 'ArrowRight' ? nextOf(t) : prevOf(t);
        handled();
        if (to) act.stage(t, to.id);
        return;
      }
      const d = /^Digit([0-3])$/.exec(e.code);
      if (d) { handled(); act.priority(t, d[1] === '0' ? null : Number(d[1])); }
      return;
    }
    if (e.ctrlKey && !e.altKey && e.code === 'KeyD') { handled(); act.duplicate(t); return; }
    // I — исполнитель текущего этапа, Shift+I — кто ведёт ассет.
    if (share && e.code === 'KeyI' && !e.ctrlKey && !e.altKey && !e.metaKey && !whoPick) {
      handled();
      const row = document.querySelector(`.cvr[data-id="${t.id}"]`);
      pickWho(t, e.shiftKey || t.status === 'completed' ? null : stageOf(t), row?.querySelector('.cv-who') ?? row);
      return;
    }
    if ((e.shiftKey && e.key === 'F10') || e.key === 'ContextMenu') { handled(); menuFor(t, document.querySelector(`.cvr[data-id="${t.id}"]`)); return; }
    if (!keys.plain(e)) return;
    const n = /^Digit([1-9])$/.exec(e.code);
    if (n && !e.shiftKey) {
      handled();
      const c = stages[Number(n[1]) - 1];
      if (c) act.stage(t, c.id);
      return;
    }
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      handled();
      const nx = flat[i + (e.key === 'ArrowDown' ? 1 : -1)];
      if (nx) focusRow(nx.id);
    } else if (e.key === 'ArrowRight') { handled(); if (openId !== t.id) toggleOpen(t); }
    else if (e.key === 'ArrowLeft') { handled(); if (openId === t.id) toggleOpen(t); }
    else if (e.key === ' ') {
      handled();
      const nx = flat[i + 1];
      if (nx) { openId = ''; focusRow(nx.id).then(() => toggleOpen(nx)); }
    } else if (e.key === 'Enter') { handled(); act.open(t); }
    else if (e.key === 'F2') { handled(); startEdit(t); }
    else if (e.code === 'KeyD' && !e.shiftKey) { handled(); act.open(t, true); }
    else if (e.code === 'KeyM' && !e.shiftKey) { handled(); menuFor(t, document.querySelector(`.cvr[data-id="${t.id}"]`), 'list'); }
    else if (e.key === 'Delete') { handled(); const nx = flat[i + 1] ?? flat[i - 1]; act.remove(t); sel = nx?.id ?? ''; }
    else if (e.key === 'Escape') {
      handled();
      if (openId) openId = ''; else sel = '';
    }
  }

  // ---------- раскрытая строка ----------
  let subDraft = $state('');
  let subInput = $state(null);
  let otherOpen = $state(false);
  let noteEdit = $state('');
  let noteDraft = $state('');
  async function addSub(t) {
    const title = subDraft.trim();
    if (!title) return;
    subDraft = '';
    await onaddsub(t, title, stageOf(t));
    await tick();
    subInput?.focus();
  }
  function saveNote(t) {
    if (noteEdit !== t.id) return;
    noteEdit = '';
    if ((noteDraft ?? '') !== (t.notes ?? '')) act.notes(t, noteDraft);
  }
  const stop = (fn) => (e) => { e.stopPropagation(); fn(e); };

  // ---------- картинка ассета (lib/PreviewBox.svelte) ----------
  // Перетащить картинку на строку или карточку галереи, либо Ctrl+V на выбранной строке — поставить превью.
  let dropId = $state('');
  async function putPreview(t, f) {
    if (act.previewOff?.()) return;
    const why = rejectWhy(f);
    if (why) return;
    sel = t.id;
    try { await act.preview(t, f); } catch {}
  }
  function rowDragOver(e, t) {
    if (!dragHasFile(e.dataTransfer) || act.previewOff?.()) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy';
    dropId = t.id;
  }
  function rowDrop(e, t) {
    if (!dragHasFile(e.dataTransfer)) return;
    e.preventDefault();
    dropId = '';
    const f = imageFrom(e.dataTransfer);
    if (f) putPreview(t, f);
  }
  function onPaste(e) {
    if (gallery || !sel || keys.typing(e) || keys.overlay() || e.target?.closest?.('.pvb')) return;
    const t = flat.find((x) => x.id === sel);
    const f = t && imageFrom(e.clipboardData);
    if (!f) return;
    e.preventDefault();
    putPreview(t, f);
  }
</script>

<svelte:window onkeydowncapture={onKey} onpaste={onPaste} />

<section class="dist" aria-label="Сколько задач на каждом этапе — нажми, чтобы отфильтровать" style="grid-template-columns: repeat({cols.length}, minmax(0, 1fr))">
  {#each dist as d (d.c.id)}
    <button type="button" aria-pressed={filter === d.c.id} onclick={() => (filter = filter === d.c.id ? '' : d.c.id)}>
      <span>{d.c.name}</span><b>{d.n}</b><i><span style="width: {Math.round((d.n / maxN) * 100)}%"></span></i>
    </button>
  {/each}
</section>
<div class="cv-sumrow">
  <p class="cv-sum">{summary}{filter ? ` · фильтр: «${cols.find((c) => c.id === filter)?.name}»` : ''}</p>
  {#if share && !gallery}
    <div class="sh-seg" role="group" aria-label="Группировка">
      <button type="button" aria-pressed={!byPeople} onclick={() => act.set({ cvGroup: 'project' })}>По проектам</button>
      <button type="button" aria-pressed={byPeople} onclick={() => act.set({ cvGroup: 'people' })}>По людям</button>
    </div>
  {/if}
</div>

{#if !gallery}
  <div class="cv">
    {#each groups as g (g.title)}
      {#if byPeople}<p class="grp">{#if g.m !== undefined}<Avatar m={g.m} size={18} me={g.m?.email === me} />{/if}{g.title}</p>
      {:else if groups.length > 1 || g.title !== 'Без проекта'}<p class="grp">{g.title}</p>{/if}
      {#each g.rows as t (t.id)}
        {@const st = stageOf(t)}
        {@const si = stages.findIndex((c) => c.id === st)}
        {@const done = t.status === 'completed'}
        {@const nx = nextOf(t)}
        {@const pv = prevOf(t)}
        {@const ch = checks(t)}
        {@const chDone = ch.stage.filter((s) => s.status === 'completed').length}
        {@const allChecked = ch.stage.length > 0 && chDone === ch.stage.length}
        {@const dn = daysOn(t)}
        {@const pr = priorityOf(layTasks?.[t.id]?.priority)}
        {@const isOpen = openId === t.id}
        {@const L = layTasks?.[t.id] ?? {}}
        {@const lead = share ? mOf(whoOf(L)) : null}
        {@const nxWho = share && nx && !done ? (L.stageWho?.[nx.id] ?? null) : null}
        {@const nxM = nxWho && nxWho !== whoOf(L) ? mOf(nxWho) : null}
        {@const given = share && L.given && whoOf(L) === me ? L.given : null}
        <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_tabindex, a11y_no_static_element_interactions -->
        <div class="cvr" class:open={isOpen} class:sel={sel === t.id} data-id={t.id} tabindex="0"
          aria-label="{t.title || 'Без названия'}, этап {done ? endCol.name : stages[si]?.name}"
          onfocus={() => (sel = t.id)}
          onclick={() => { if (editId !== t.id) toggleOpen(t); }}
          class:drop={dropId === t.id} ondragover={(e) => rowDragOver(e, t)} ondragleave={() => (dropId = '')} ondrop={(e) => rowDrop(e, t)}
          oncontextmenu={(e) => { e.preventDefault(); menuFor(t, e.currentTarget); }}>
          <button type="button" class="car" aria-expanded={isOpen} aria-label="{isOpen ? 'Свернуть' : 'Раскрыть'} {t.title}" onclick={stop(() => toggleOpen(t))}>
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
          </button>
          <div class="name">
            {#if L.preview?.thumb}<img class="thumb" src={L.preview.thumb} alt="" />{:else}<span class="thumb">{initials(t.title)}</span>{/if}
            {#if editId === t.id}
              <input class="ren" use:focusSel bind:value={editDraft} aria-label="Название" onclick={(e) => e.stopPropagation()}
                onkeydown={(e) => { e.stopPropagation(); if (e.key === 'Enter') { e.preventDefault(); finishEdit(t); } else if (e.key === 'Escape') { e.preventDefault(); finishEdit(t, false); } }}
                onblur={() => finishEdit(t)} />
            {:else}
              <span class="nm" title="Двойной клик или F2 — переименовать" ondblclick={stop(() => startEdit(t))}>
                <b>{t.title || 'Без названия'}</b>
                <small>{layTasks?.[t.id]?.project ? `${layTasks[t.id].project} · ` : ''}{subsOf(t.id).length ? `подзадач ${subsOf(t.id).filter((s) => s.status === 'completed').length} из ${subsOf(t.id).length}` : 'нажми, чтобы раскрыть'}</small>
                {#if given}<span class="sh-given"><Avatar m={mOf(given.by)} size={14} />передано тебе · от {given.name}</span>{/if}
              </span>
            {/if}
            {#if pr && !done}<span class="pip" title="Приоритет: {pr.label.toLowerCase()}" style="background: {PC[pr.id]}"></span>{/if}
          </div>
          <div>
            <div class="track" role="group" aria-label="Этапы" style="grid-template-columns: repeat({stages.length}, minmax(0, 1fr))">
              {#each stages as c, i (c.id)}
                {@const sw = share && (done || i !== si) ? L.stageWho?.[c.id] : null}
                <button type="button" class="st" class:done={done || i < si} class:now={!done && i === si} class:nxo={!!nxM && nx?.id === c.id}
                  style={nxM && nx?.id === c.id ? `--nc: ${nxM.color}` : ''}
                  title="{i + 1} · {c.name}{!done && i === si ? ' — сейчас' : ''}{sw ? ` · ${mOf(sw).name}` : ''}" onclick={stop(() => act.stage(t, c.id))}>{c.name}{#if sw}<span class="sw"><Avatar m={mOf(sw)} size={16} me={sw === me} /></span>{/if}</button>
              {/each}
            </div>
            <div class="days" class:slow={!done && dn != null && dn >= 7}>
              {done ? 'готово' : dn == null ? 'время на этапе пока не считалось' : `на этапе ${dn} ${plural(dn, ['день', 'дня', 'дней'])}${dn >= 7 ? ' — дольше обычного' : ''}`}
            </div>
          </div>
          <span class="due {dueCls(t)}">{t.due ? (dueCls(t) === 'late' ? 'просрочено' : humanDue(t.due)) : share ? 'без срока' : '—'}</span>
          {#if share}
            <button type="button" class="sh-who cv-who" title="{lead ? `Ведёт: ${lead.name}` : 'Никто не ведёт'} · Shift+I" aria-label={lead ? `Ведёт ${lead.name}, сменить` : 'Выбрать, кто ведёт'}
              onclick={stop((e) => pickWho(t, null, e.currentTarget))}><Avatar m={lead} size={30} me={!!lead && lead.email === me} /></button>
          {/if}
          {#if !done && nx}
            <button type="button" class="adv nx" class:ready={allChecked} title="Alt+→{nxM ? ` · уйдёт: ${nxM.name}` : ''}" onclick={stop(() => act.stage(t, nx.id))}>{nx.name} →{#if nxM}<Avatar m={nxM} size={18} />{/if}</button>
          {:else}
            <span class="fin">✓ {endCol.name.toLowerCase()}</span>
          {/if}
        </div>
        {#if isOpen}
          {@const tl = timeline(t)}
          <div class="pn" role="region" in:expand out:expand={{ out: true }} aria-label="Подробности: {t.title}">
            {#if share}
              <div class="cv-crew">
                <section>
                  <div class="pn-h"><h4>Кто на этапах</h4><span>ассет ведёт: {lead ? (lead.email === me ? 'ты' : lead.name) : 'никто'}</span></div>
                  {#each stageCrew(L, stages, done ? '' : st) as r, i (r.col.id)}
                    {@const m = mOf(r.who)}
                    <div class="cw" class:cur={!done && r.col.id === st}>
                      <span class="cn">{r.col.name}</span>
                      <button type="button" class="cwb" title="Кто делает «{r.col.name}»{!done && r.col.id === st ? ' · I' : ''}" onclick={(e) => pickWho(t, r.col.id, e.currentTarget)}>
                        <Avatar {m} size={22} me={r.who === me} />{m ? (r.who === me ? 'Я' : m.name) : 'по ходу дела'}<i aria-hidden="true">▾</i></button>
                      <span class="cd">{done || i < si ? (L.stageAt?.[stages[i + 1]?.id ?? endCol.id] ? `✓ ${new Date(L.stageAt[stages[i + 1]?.id ?? endCol.id]).toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' })}` : '✓') : !done && i === si && dn != null ? `${dn} ${plural(dn, ['день', 'дня', 'дней'])}` : ''}</span>
                    </div>
                  {/each}
                </section>
                <section>
                  <div class="pn-h"><h4>Как передаётся</h4></div>
                  {#each [...(Array.isArray(L.passes) ? L.passes : [])].reverse().slice(0, 5) as p (p.at)}
                    <div class="cv-ps"><Avatar m={mOf(p.by)} size={18} me={p.by === me} /><span class="tx">{passText(p, people, me, (c) => cols.find((x) => x.id === c)?.name ?? c)}</span><em>{new Date(p.at).toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' })}</em></div>
                  {:else}<p class="hint">Пока никто не передавал. При «Этап →» ассет сам уйдёт к исполнителю следующего этапа.</p>{/each}
                  {#if !done && nx}<div class="cv-ps cv-nx"><Avatar m={nxWho ? mOf(nxWho) : lead} size={18} /><span class="tx">Дальше: «{nx.name}» — {nextHint(L, nx.id, me, people)}</span></div>{/if}
                </section>
              </div>
            {/if}
            <section>
              <div class="pn-h"><h4>{done ? 'Подзадачи' : `Этап «${stages[si]?.name ?? endCol.name}»`}</h4>{#if ch.stage.length}<span>{chDone} из {ch.stage.length}</span>{/if}</div>
              {#if ch.stage.length}<div class="bar" aria-hidden="true"><i style="width: {Math.round((chDone / ch.stage.length) * 100)}%"></i></div>{/if}
              <div>
                {#each ch.stage as s (s.id)}
                  <div class="ck"><button type="button" class="bx" aria-pressed={s.status === 'completed'} aria-label={s.title} onclick={() => ontoggle(s, s.status !== 'completed')}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg></button><span class:off={s.status === 'completed'}>{s.title}</span></div>
                {/each}
              </div>
              {#if !done}
                <label class="addl"><span aria-hidden="true">＋</span>
                  <input bind:this={subInput} bind:value={subDraft} placeholder="Подзадача этапа… Enter — добавить" aria-label="Новая подзадача этапа"
                    onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addSub(t); } else if (e.key === 'Escape') { e.stopPropagation(); subInput.blur(); } }} />
                </label>
              {/if}
              {#if allChecked && nx}<p class="ready-note">Этап закрыт — можно дальше: «{nx.name} →» или Alt+→</p>{/if}
              {#if ch.other.length}
                <button type="button" class="oth" aria-expanded={otherOpen} onclick={() => (otherOpen = !otherOpen)}>{otherOpen ? '▾' : '▸'} Подзадачи других этапов · {ch.other.length}</button>
                {#if otherOpen}
                  {#each ch.other as s (s.id)}
                    {@const sc = cols.find((c) => c.id === layTasks?.[s.id]?.stage)}
                    <div class="ck small"><button type="button" class="bx" aria-pressed={s.status === 'completed'} aria-label={s.title} onclick={() => ontoggle(s, s.status !== 'completed')}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg></button><span class:off={s.status === 'completed'}>{s.title}</span><em>{sc?.name ?? 'без этапа'}</em></div>
                  {/each}
                {/if}
              {/if}
            </section>
            <section>
              <div class="pn-h"><h4>Детали</h4></div>
              <div class="kv">
                <span>Срок</span><button type="button" class="pill" title="D" onclick={() => act.open(t, true)}>📅 {t.due ? humanDue(t.due) : 'без срока'}</button>
                <span>Приоритет</span>
                <div class="pr" role="group" aria-label="Приоритет">
                  {#each PRIORITIES as p (p.id)}<button type="button" aria-pressed={pr?.id === p.id} title={p.label} onclick={() => act.priority(t, p.id)}>{p.mark}</button>{/each}
                  <button type="button" aria-pressed={!pr} title="Без приоритета" onclick={() => act.priority(t, null)}>—</button>
                </div>
                <span>Проект</span><button type="button" class="pill" onclick={() => act.open(t)}>{layTasks?.[t.id]?.project || 'без проекта'}</button>
                <span>Напомнить</span><button type="button" class="pill" onclick={() => act.open(t)}>🔔 {remindOf(t) || 'нет'}</button>
              </div>
              {#if noteEdit === t.id}
                <!-- svelte-ignore a11y_autofocus -->
                <textarea class="note" rows="3" bind:value={noteDraft} autofocus aria-label="Заметка" onblur={() => saveNote(t)}
                  onkeydown={(e) => { if (e.key === 'Escape') { e.stopPropagation(); noteEdit = ''; } else if (e.key === 'Enter' && e.ctrlKey) { e.preventDefault(); saveNote(t); } }}></textarea>
              {:else}
                <button type="button" class="note" class:muted={!t.notes} title="Клик — редактировать" onclick={() => { noteEdit = t.id; noteDraft = t.notes ?? ''; }}>{t.notes || 'Заметка — клик, чтобы написать'}</button>
              {/if}
            </section>
            <section>
              <div class="pn-h"><h4>Время по этапам</h4><span>{tl.total}</span></div>
              <div class="hs">
                {#each tl.items as h (h.c.id)}<div><span>{h.c.name}</span><i class:cur={h.cur} style="width: {h.w}%"></i><b>{h.v}</b></div>{:else}<p class="hint">Время начнёт считаться со следующей смены этапа.</p>{/each}
              </div>
              <div class="pn-h pv-h"><h4>Превью</h4></div>
              <PreviewBox pv={L.preview ?? null} title={t.title} off={act.previewOff?.() ?? ''} onset={(f) => act.preview(t, f)} onclear={() => act.previewClear(t)} />
            </section>
            <div class="foot">
              {#if pv && !done}<button type="button" class="sp-btn" style="min-height: 30px" onclick={() => act.stage(t, pv.id)}>← {pv.name}</button>{/if}
              {#if share && nx && !done}
                <button type="button" class="sp-btn sp-btn-primary" style="min-height: 30px" onclick={() => act.stage(t, nx.id)}>{nx.name} →</button>
                <span class="keys">{nextHint(L, nx.id, me, people)}</span>
              {/if}
              <button type="button" class="sp-btn sp-btn-ghost" style="min-height: 30px" onclick={() => act.open(t)}>Открыть полностью ↗</button>
              <span style="flex: 1"></span>
              {#if share}<span class="keys"><kbd>I</kbd> исполнитель этапа · <kbd>Shift+I</kbd> ведёт ассет ·</span>{/if}
              <span class="keys"><kbd>Esc</kbd> свернуть · <kbd>Space</kbd> следующий · <kbd>Enter</kbd> окно задачи</span>
            </div>
          </div>
        {/if}
      {/each}
    {:else}
      <p class="empty">{filter ? 'На этом этапе сейчас ничего нет.' : 'Пока пусто — добавь первую задачу кнопкой «Создать».'}</p>
    {/each}
  </div>
  <footer class="kb-hint"><span><kbd>клик</kbd>раскрыть строку</span><span><kbd>2×клик</kbd>по названию — переименовать</span><span><kbd>↑↓</kbd>по строкам</span><span><kbd>→ / ←</kbd>раскрыть / свернуть</span><span><kbd>Alt+←→</kbd>этап</span><span><kbd>1–{stages.length}</kbd>этап по номеру</span><span><kbd>Enter</kbd>окно задачи</span></footer>
{:else}
  <div class="gal">
    {#each rows as t (t.id)}
      {@const st = stageOf(t)}
      {@const si = stages.findIndex((c) => c.id === st)}
      {@const done = t.status === 'completed'}
      {@const dn = daysOn(t)}
      {@const gp = layTasks?.[t.id]?.preview}
      <button type="button" class="gc" class:drop={dropId === t.id} onclick={() => act.open(t)} oncontextmenu={(e) => { e.preventDefault(); menuFor(t, e.currentTarget); }}
        ondragover={(e) => rowDragOver(e, t)} ondragleave={() => (dropId = '')} ondrop={(e) => rowDrop(e, t)}>
        {#if gp?.thumb}<img class="pv" src={gp.thumb} alt="" />{:else}<span class="pv">{initials(t.title)}</span>{/if}
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

{#if whoPick && share}
  <WhoPick anchor={whoPick?.anchor} {people} {me} {counts}
    cur={whoPick?.col ? (layTasks?.[whoPick.t.id]?.stageWho?.[whoPick.col] ?? (stageOf(whoPick.t) === whoPick.col ? whoOf(layTasks?.[whoPick.t.id]) : null)) : whoOf(layTasks?.[whoPick?.t.id])}
    onpick={applyWho} onclose={() => (whoPick = null)} />
{/if}
