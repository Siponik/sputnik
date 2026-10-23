<script>
  import SharedTag from './SharedTag.svelte';
  import ShareBits from './ShareBits.svelte';
  import WhoPick from './WhoPick.svelte';
  import { memberOf, whoOf, whoCounts, whoTally, assignedMatch } from './sharedcore.js';
  import Avatar from './Avatar.svelte';
  // Доска списка (design/screens/Kanban.dc.html, docs/design-v2.md — «Канбан и Конвейер: вид и взаимодействие»).
  // Одна выбранная карточка (обводка clay): клик по названию — окно задачи, по карточке — выбрать, двойной клик / F2 — переименовать, правый клик — меню.
  import { tick } from 'svelte';
  import TaskCard from './TaskCard.svelte';
  import CardMenu from './CardMenu.svelte';
  import PeekCoon, { peekVariant } from './PeekCoon.svelte';
  import { ymd, dueToYmd, dueState } from './api.js';
  import { isArchived, ARCHIVE_AFTER_DAYS, colColor } from './templates.js';
  import Conveyor from './Conveyor.svelte';
  import ListView from './ListView.svelte';
  import Stickers from './Stickers.svelte';
  import { startOfWeek, addDays } from './calendar.js';
  import { priorityRank } from './meta.js';
  import * as keys from './keys.js';
  import { flip } from 'svelte/animate';
  import { cardCrossfade, flipMs } from './motion.js';

  // Перенос в соседнюю колонку — карточка «перелетает» (send/receive), остальные съезжают на места (flip).
  const [send, receive] = cardCrossfade();

  // view — kanban | pipe | gallery | list (свой вид списка или вид шаблона); onview — сменить вид этого списка.
  // act — действия над задачей из App: open(t, pick), rename, stage (с «Отменить»), priority, order(ids), moveList,
  // duplicate, remove (с «Отменить»). fold — свёрнутые колонки этого списка { colId: true }, onfold(colId, v).
  // lists — другие списки (для «В другой список»).
  // layList — запись списка в слое (для «Стикеров»: темы, раскладка).
  let { list, tasks, template, colOf, typeOf, layTasks, layList = {}, project = null, remindOf = () => '', view = 'kanban',
    act, lists = [], fold = {}, onfold, sphereName = '', share = null,
    oncreate, onarchive, onview, ontoggle, onaddsub, onedittemplate } = $props();

  // Три основных вида; «Список» — только у списка, где он выбран (в редакторе шаблонов).
  const VIEW_TABS = $derived([
    { id: 'kanban', name: 'Канбан' }, { id: 'pipe', name: 'Конвейер' },
    ...(template.view === 'pipe' || template.fields.includes('stage') ? [{ id: 'gallery', name: 'Галерея' }] : []),
    { id: 'stickers', name: 'Стикеры' },
    ...(view === 'list' ? [{ id: 'list', name: 'Список' }] : []),
  ]);
  const fields = $derived(template.fields ?? []);
  const FILTERS = [
    { k: '', label: 'Все' }, { k: 'prio', label: '!!! Важное' }, { k: 'week', label: 'На этой неделе' }, { k: 'late', label: 'Просрочено' },
  ];
  // Что говорит пустая колонка. Скетч-енот меняет место от колонки к колонке: снизу, сбоку, хвост сверху.
  const EMPTY = {
    inbox: 'Входящие разобраны. Можно выдохнуть.',
    doing: 'Ничего в работе. Возьми задачу из входящих.',
    review: 'На ревью пусто. Енот ждёт новую работу.',
    done: 'Пока ничего не готово.',
  };

  let filter = $state('');
  let showDone = $state(false);
  let composing = $state(''); // id колонки, где открыта форма
  let composeTop = $state(false); // форма из «＋» в шапке — задача встанет в начало колонки
  let draft = $state('');
  let composeInput = $state(null);

  const cols = $derived(template.cols);
  const endId = $derived(cols[cols.length - 1].id);
  const top = $derived(tasks.filter((t) => !t.parent));
  const live = $derived(top.filter((t) => !isArchived(t)));
  const archived = $derived(top.length - live.length);
  const open = $derived(top.filter((t) => t.status !== 'completed'));
  const weekA = ymd(startOfWeek(new Date())), weekB = ymd(addDays(startOfWeek(new Date()), 6));
  const weekDue = $derived(open.filter((t) => t.due && dueToYmd(t.due) >= weekA && dueToYmd(t.due) <= weekB).length);
  // Общая сфера: «Все / Мои / Без исполнителя» (share.mode, запоминается для доски в App).
  const whoMode = $derived(share?.mode ?? 'all');
  const whoN = $derived(share ? whoTally(tasks, layTasks, share.me) : null);
  const meM = $derived(share ? memberOf(share.people, share.me) : null);
  function passes(t) {
    if (project && layTasks?.[t.id]?.project !== project) return false;
    if (share && !t.parent && !assignedMatch(layTasks?.[t.id], share.me, whoMode)) return false;
    if (filter === 'prio') return layTasks?.[t.id]?.priority === 1;
    if (filter === 'week') return !!t.due && dueToYmd(t.due) <= weekB && t.status !== 'completed';
    if (filter === 'late') return dueState(t) === 'overdue' && t.status !== 'completed';
    return true;
  }
  const visible = (t) => passes(t);

  const subsOf = (id) => tasks.filter((t) => t.parent === id);
  const byPos = (a, b) => (a.position || '').localeCompare(b.position || '');
  // Порядок в колонке: свой (tasks[id].ord, Alt+↑↓ и перетаскивание), иначе — приоритет, потом порядок Google.
  function column(id) {
    const items = live.filter((t) => colOf(t, cols) === id && passes(t));
    if (id === endId) return items.sort((a, b) => (b.completed || '').localeCompare(a.completed || ''));
    const base = items.sort((a, b) => priorityRank(layTasks?.[a.id]?.priority) - priorityRank(layTasks?.[b.id]?.priority) || byPos(a, b));
    const key = new Map(base.map((t, i) => [t.id, layTasks?.[t.id]?.ord ?? i - 0.5]));
    return [...base].sort((a, b) => key.get(a.id) - key.get(b.id));
  }
  const columns = $derived(Object.fromEntries(cols.map((c) => [c.id, column(c.id)])));
  const nextOf = (colId) => { const i = cols.findIndex((c) => c.id === colId); return i >= 0 && i < cols.length - 1 ? cols[i + 1] : null; };
  const prevOf = (colId) => { const i = cols.findIndex((c) => c.id === colId); return i > 0 ? cols[i - 1] : null; };
  const shownIn = (colId) => { const it = columns[colId] ?? []; return colId === endId && !showDone ? it.slice(0, 2) : it; };

  // ---------- выбор, переименование, меню ----------
  let sel = $state('');
  let editing = $state('');
  let menu = $state(null); // { task, at: {x,y}, expand }
  const selTask = $derived(top.find((t) => t.id === sel) ?? null);
  async function focusCard(id) {
    sel = id;
    await tick();
    document.querySelector(`.kc[data-id="${id}"]`)?.focus({ preventScroll: false });
  }
  function openMenu(t, anchor, expand = '', rename = null) {
    sel = t.id;
    const r = anchor?.getBoundingClientRect?.();
    menu = { task: t, at: r ? { x: r.right - 236, y: r.top + 34 } : { x: innerWidth / 2 - 118, y: innerHeight / 3 }, expand, rename };
  }
  function menuAction(name, arg) {
    const t = menu?.task;
    if (!t) return;
    if (name === 'open') act.open(t);
    else if (name === 'rename') { if (menu.rename) menu.rename(t); else editing = t.id; }
    else if (name === 'due') act.open(t, true);
    else if (name === 'priority') act.priority(t, arg);
    else if (name === 'stage') act.stage(t, arg);
    else if (name === 'list') act.moveList(t, arg);
    else if (name === 'duplicate') act.duplicate(t);
    else if (name === 'delete') act.remove(t);
  }
  /** Сдвинуть задачу на позицию в колонке (Alt+↑↓, перетаскивание): записываем ord всей колонке. */
  function reorder(t, colId, index) {
    const ids = (columns[colId] ?? []).map((x) => x.id).filter((id) => id !== t.id);
    ids.splice(Math.max(0, Math.min(index, ids.length)), 0, t.id);
    act.order(ids);
  }

  // Исполнитель в общей сфере: кружок на карточке и клавиша I открывают выбор (WhoPick).
  let whoPick = $state(null); // { t, anchor }
  const assigneeOf = (t) => (share ? memberOf(share.people, whoOf(layTasks?.[t.id])) : undefined);
  const counts = $derived(share ? whoCounts(tasks, layTasks) : {});
  function pickWho(t, anchor) { if (share) whoPick = { t, anchor }; }

  // Клавиши доски (канбан): стрелки, Enter, F2, Alt+…, D, M, Ctrl+D, Del, Esc, Shift+F10.
  // Ловим на фазе погружения, чтобы цифры и стрелки не уходили в общие клавиши приложения.
  function onKey(e) {
    // Shift+A / Shift+M / Shift+U — «Все / Мои / Без исполнителя» (только общая сфера, на любом виде доски).
    if (share && e.shiftKey && !e.ctrlKey && !e.altKey && !e.metaKey && !menu && !whoPick && !editing && !keys.typing(e) && !keys.overlay()) {
      const m = { KeyA: 'all', KeyM: 'mine', KeyU: 'none' }[e.code];
      if (m) { e.preventDefault(); e.stopPropagation(); share.onmode(m); return; }
    }
    if (view !== 'kanban' || menu || whoPick || editing || keys.typing(e) || keys.overlay()) return;
    const handled = () => { e.preventDefault(); e.stopPropagation(); };
    const arrows = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'];
    if (!selTask) {
      if (arrows.includes(e.key) && !e.altKey && !e.ctrlKey) {
        const first = cols.map((c) => shownIn(c.id)[0]).find(Boolean);
        if (first) { handled(); focusCard(first.id); }
      }
      return;
    }
    const t = selTask;
    const cid = colOf(t, cols);
    const colItems = shownIn(cid);
    const idx = colItems.findIndex((x) => x.id === t.id);
    if (e.altKey && !e.ctrlKey) {
      if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
        const to = e.key === 'ArrowRight' ? nextOf(cid) : prevOf(cid);
        handled();
        if (to) { act.stage(t, to.id); tick().then(() => focusCard(t.id)); }
        return;
      }
      if ((e.key === 'ArrowUp' || e.key === 'ArrowDown') && cid !== endId) {
        handled();
        reorder(t, cid, idx + (e.key === 'ArrowUp' ? -1 : 1));
        tick().then(() => focusCard(t.id));
        return;
      }
      const d = /^Digit([0-3])$/.exec(e.code);
      if (d) { handled(); act.priority(t, d[1] === '0' ? null : Number(d[1])); return; }
      return;
    }
    if (e.ctrlKey && !e.altKey && e.code === 'KeyD') { handled(); act.duplicate(t); return; }
    if ((e.shiftKey && e.key === 'F10') || e.key === 'ContextMenu') { handled(); openMenu(t, document.querySelector(`.kc[data-id="${t.id}"]`)); return; }
    if (!keys.plain(e)) return;
    if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
      handled();
      const n = colItems[idx + (e.key === 'ArrowUp' ? -1 : 1)];
      if (n) focusCard(n.id);
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
      handled();
      let ci = cols.findIndex((c) => c.id === cid);
      for (;;) {
        ci += e.key === 'ArrowRight' ? 1 : -1;
        if (ci < 0 || ci >= cols.length) break;
        if (fold[cols[ci].id]) continue;
        const items = shownIn(cols[ci].id);
        if (items.length) { focusCard(items[Math.min(idx, items.length - 1)].id); break; }
      }
    } else if (e.key === 'Enter') { handled(); act.open(t); }
    else if (e.key === 'F2') { handled(); editing = t.id; }
    else if (e.code === 'KeyD' && !e.shiftKey) { handled(); act.open(t, true); }
    else if (e.code === 'KeyI' && !e.shiftKey && share) { handled(); pickWho(t, document.querySelector(`.kc[data-id="${t.id}"] .sh-who`)); }
    else if (e.code === 'KeyM' && !e.shiftKey) { handled(); openMenu(t, document.querySelector(`.kc[data-id="${t.id}"]`), 'list'); }
    else if (e.key === 'Delete') {
      handled();
      const n = colItems[idx + 1] ?? colItems[idx - 1];
      act.remove(t);
      if (n) focusCard(n.id); else sel = '';
    } else if (e.key === 'Escape') { handled(); sel = ''; document.activeElement?.blur?.(); }
  }

  // ---------- перетаскивание: место вставки, порядок внутри колонки ----------
  let dragId = $state('');
  let drop = $state(null); // { col, index }
  function dragStart(e, t) {
    dragId = t.id;
    sel = t.id;
    e.dataTransfer.setData('text/plain', t.id);
    e.dataTransfer.effectAllowed = 'move';
    const el = e.currentTarget;
    el.classList.add('lift'); // «поднятая» карточка попадает в картинку перетаскивания
    setTimeout(() => el.classList.remove('lift'), 0);
  }
  function dragEnd() { dragId = ''; drop = null; }
  function dragOver(e, colId) {
    if (!dragId) return;
    e.preventDefault();
    const cards = [...e.currentTarget.querySelectorAll('.kc:not(.ghost)')];
    let index = cards.length;
    for (let i = 0; i < cards.length; i++) {
      const r = cards[i].getBoundingClientRect();
      if (e.clientY < r.top + r.height / 2) { index = i; break; }
    }
    if (drop?.col !== colId || drop?.index !== index) drop = { col: colId, index };
  }
  function dropOn(e, colId) {
    e.preventDefault();
    const t = top.find((x) => x.id === dragId);
    const index = drop?.index ?? 0;
    dragEnd();
    if (!t) return;
    if (colOf(t, cols) !== colId) act.stage(t, colId);
    if (colId !== endId) reorder(t, colId, index);
  }
  function dragLeave(e, colId) {
    if (drop?.col === colId && !e.currentTarget.contains(e.relatedTarget)) drop = null;
  }

  // ---------- новая задача в колонке ----------
  async function startAdd(colId, atTop = false) {
    if (fold[colId]) onfold(colId, false);
    composing = colId;
    composeTop = atTop;
    draft = '';
    await tick();
    composeInput?.focus();
  }
  async function commit() {
    const title = draft.trim();
    if (!title) return;
    const col = composing;
    const items = columns[col] ?? [];
    const ords = items.map((t, i) => layTasks?.[t.id]?.ord ?? i);
    const ord = composeTop ? Math.min(0, ...ords) - 1 : Math.max(0, ...ords) + 1;
    draft = '';
    await oncreate(title, col, ord);
    composeInput?.focus();
  }
  function composeKey(e) {
    if (e.key === 'Enter') { e.preventDefault(); commit(); }
    else if (e.key === 'Escape') { e.stopPropagation(); composing = ''; draft = ''; }
  }
</script>

<svelte:window onkeydowncapture={onKey} />

{#if whoPick && share}
  <WhoPick anchor={whoPick?.anchor} people={share?.people ?? []} me={share?.me ?? ''} cur={whoOf(layTasks?.[whoPick?.t.id])} {counts}
    onpick={(w) => { const t = whoPick.t; whoPick = null; act.who(t, w); focusCard(t.id); }} onclose={() => (whoPick = null)} />
{/if}

{#snippet compose()}
  <div class="compose">
    <input bind:this={composeInput} bind:value={draft} type="text" aria-label="Название задачи" placeholder="Что сделать?" onkeydown={composeKey} />
    <div class="ca">
      <button class="sp-btn sp-btn-primary" type="button" style="min-height: 30px" disabled={!draft.trim()} onclick={commit}>Добавить</button>
      <button class="sp-btn sp-btn-ghost" type="button" style="min-height: 30px" onclick={() => { composing = ''; draft = ''; }}>Отмена</button>
    </div>
  </div>
{/snippet}

{#snippet viewTabs()}
  <div class="seg3" role="group" aria-label="Вид доски">
    {#each VIEW_TABS as v (v.id)}<button type="button" aria-pressed={view === v.id} onclick={() => onview(v.id)}>{v.name}</button>{/each}
  </div>
{/snippet}

{#if view === 'stickers'}
<div class="page bd stk-page">
  <Stickers {list} {tasks} {layList} {layTasks} cols={template.cols} {remindOf} {act} {lists} tabs={viewTabs} {share} {sphereName}
    headLine="{sphereName ? `${sphereName} · ` : ''}шаблон «{template.name}»" {onedittemplate} {onarchive} />
</div>
{:else}
<div class="page bd">
  <!-- Шапка по design/screens/Kanban.dc.html: сфера · шаблон над названием, справа фильтры и вид. -->
  <header class="bd-head">
    <div class="bd-title">
      <p>{#if sphereName}<span class="bd-path">{sphereName}{#if share}<SharedTag small />{/if}</span>{' · '}{/if}шаблон «{template.name}»{view === 'pipe' ? ' · Конвейер' : ''}{project ? ` · проект «${project}»` : ''}
        · <button type="button" class="link" title="Колонки, цвета, лимиты и поля шаблона" onclick={onedittemplate}>настроить</button></p>
      <h1>{list?.title ?? 'Задачи'}{#if share}<ShareBits {share} />{/if}</h1>
    </div>
    <div class="tb" role="group" aria-label="Фильтры">
      {#if share}
        <div class="sh-seg" role="group" aria-label="Чьи задачи">
          <button type="button" aria-pressed={whoMode === 'all'} title="Все · Shift+A" onclick={() => share.onmode('all')}>Все<small>{whoN.all}</small></button>
          <button type="button" aria-pressed={whoMode === 'mine'} title="Мои · Shift+M" onclick={() => share.onmode('mine')}><Avatar m={meM} size={18} me />Мои<small>{whoN.mine}</small></button>
          <button type="button" aria-pressed={whoMode === 'none'} title="Без исполнителя · Shift+U" onclick={() => share.onmode('none')}><Avatar m={null} size={18} />Без исполнителя<small>{whoN.none}</small></button>
        </div>
        <span class="tb-sep" aria-hidden="true"></span>
      {/if}
      {#each FILTERS as f (f.k)}
        <button type="button" class="fb" aria-pressed={filter === f.k} onclick={() => (filter = f.k)}>{f.label}</button>
      {/each}
      <span class="tb-sep" aria-hidden="true"></span>
      <!-- Шаблон списка выбирается только при создании (« + Новый список»), здесь не меняется. Вид — меняется. -->
      {@render viewTabs()}
    </div>
  </header>

  {#if view === 'pipe' || view === 'gallery'}
    <Conveyor {list} {tasks} {cols} {colOf} {layTasks} {layList} {share} {visible} gallery={view === 'gallery'} {act} {ontoggle} {onaddsub} {remindOf}
      onmenu={openMenu} />
  {:else if view === 'list'}
    <ListView {tasks} {cols} {colOf} {layTasks} {fields} {visible} onopen={(t) => act.open(t)} onmove={(t, c) => act.stage(t, c)} onmenu={openMenu} />
  {:else}
  <div class="board kb">
    {#each cols as col, i (col.id)}
      {@const items = columns[col.id] ?? []}
      {@const isDoneCol = col.id === endId}
      {@const shown = shownIn(col.id)}
      {@const next = nextOf(col.id)}
      {@const n = items.length}
      {@const empty = EMPTY[col.id] ?? (i === 0 ? `${col.name}: всё разобрано. Можно выдохнуть.` : `${col.name}: пока пусто.`)}
      {@const pk = peekVariant(`${list.id}|${col.id}`, i)}
      {#if fold[col.id]}
        <button type="button" class="colz" style="--cc: {colColor(col)}" aria-label="Развернуть колонку {col.name}" title="Развернуть"
          ondragover={(e) => { if (dragId) { e.preventDefault(); } }} ondrop={(e) => { drop = { col: col.id, index: 0 }; dropOn(e, col.id); }}
          onclick={() => onfold(col.id, false)}><b>{n}</b><span>{col.name}</span></button>
      {:else}
      <section
        class="bcol"
        class:drop={drop?.col === col.id}
        aria-label={col.name}
        style="--cc: {colColor(col)}"
        ondragover={(e) => dragOver(e, col.id)}
        ondragleave={(e) => dragLeave(e, col.id)}
        ondrop={(e) => dropOn(e, col.id)}
      >
        <header class="ch">
          <h3>{col.name}</h3>{#key n}<span class="n num-roll">{n}</span>{/key}
          {#if col.limit}<span class="lim" class:full={n === col.limit} class:over={n > col.limit} title="Лимит колонки (из шаблона)">{n} / {col.limit}</span>{/if}
          <span style="flex: 1"></span>
          {#if !isDoneCol}
            <button type="button" class="hb" aria-label="Новая задача в начало колонки {col.name}" title="Новая задача сверху" onclick={() => startAdd(col.id, true)}>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>
            </button>
          {/if}
          <button type="button" class="hb" aria-label="Свернуть колонку {col.name}" title="Свернуть" onclick={() => onfold(col.id, true)}>
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M15 6l-6 6 6 6" /></svg>
          </button>
        </header>
        {#if col.limit && n > col.limit}
          <p class="wip-warn">Больше лимита: закончи одну задачу, прежде чем брать новую.</p>
        {/if}
        {#if composing === col.id && composeTop}{@render compose()}{/if}

        {#each shown as task, k (task.id)}
          <div class="kw" animate:flip={{ duration: flipMs() }} in:receive={{ key: task.id }} out:send={{ key: task.id }}>
          {#if drop?.col === col.id && drop.index === k && dragId !== task.id}<div class="ph" aria-hidden="true"></div>{/if}
          <TaskCard {task} subs={subsOf(task.id)} remind={remindOf(task)} type={typeOf(list.id, task.id)} priority={layTasks?.[task.id]?.priority} {fields} extra={layTasks?.[task.id]}
            next={isDoneCol ? null : next} selected={sel === task.id} editing={editing === task.id} ghost={dragId === task.id}
            onopen={(t) => act.open(t)} onadvance={(t) => act.stage(t, next.id)} ondue={(t) => act.open(t, true)}
            onmenu={(t, el) => openMenu(t, el)} onselect={(t) => (sel = t.id)}
            assignee={assigneeOf(task)} mine={!!share && whoOf(layTasks?.[task.id]) === share.me} onwho={pickWho} wait={share?.waitOf?.(task.id) ?? null}
            onstartedit={(t) => (editing = t.id)} onendedit={() => (editing = '')} onrename={(t, title) => act.rename(t, title)}
            ondragstart={dragStart} ondragend={dragEnd} />
          </div>
        {/each}
        {#if drop?.col === col.id && drop.index >= shown.filter((t) => t.id !== dragId).length}<div class="ph" aria-hidden="true"></div>{/if}

        {#if !items.length && composing !== col.id && drop?.col !== col.id}
          <div class="bempty at-{pk.place}-{pk.edge}"><PeekCoon {...pk} /><span>{empty}</span></div>
        {/if}
        {#if isDoneCol && items.length > 2}
          <button class="more" type="button" onclick={() => (showDone = !showDone)}>{showDone ? 'Свернуть' : `Ещё ${items.length - 2} →`}</button>
        {/if}
        {#if isDoneCol && archived}
          <button class="col-foot" type="button" onclick={onarchive}>Старше {ARCHIVE_AFTER_DAYS} дней — в архиве · {archived}</button>
        {/if}

        {#if !isDoneCol}
          {#if composing === col.id && !composeTop}
            {@render compose()}
          {:else}
            <button class="add" type="button" onclick={() => startAdd(col.id)}>＋ Добавить задачу</button>
          {/if}
        {/if}
      </section>
      {/if}
    {/each}
  </div>
  <footer class="kb-hint" aria-label="Подсказка по клавишам">
    <span><kbd>клик</kbd>по названию — открыть задачу</span><span><kbd>2×клик</kbd>по названию — переименовать</span><span><kbd>↑↓←→</kbd>ходить по карточкам</span><span><kbd>Alt+←→</kbd>этап</span><span><kbd>Alt+↑↓</kbd>порядок</span><span><kbd>Alt+1/2/3</kbd>приоритет</span><span><kbd>D</kbd>срок</span><span><kbd>?</kbd>все клавиши</span>
  </footer>
  {/if}
</div>
{/if}

{#if menu}
  {@const mt = top.find((t) => t.id === menu.task.id) ?? menu.task}
  <CardMenu at={menu.at} {cols} cur={colOf(mt, cols)} priority={layTasks?.[mt.id]?.priority ?? null} {lists} expand={menu.expand}
    onaction={menuAction} onclose={() => { const id = menu?.task.id; menu = null; if (id && view === 'kanban') focusCard(id); }} />
{/if}
