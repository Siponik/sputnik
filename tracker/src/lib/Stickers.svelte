<script>
  import SharedTag from './SharedTag.svelte';
  import ShareBits from './ShareBits.svelte';
  // Вид «Стикеры» — простые дела без этапов (design/screens/Stickers.dc.html, docs/design-v2.md — «Простые дела: вид «Стикеры»»).
  // Колонки по темам списка или по срокам (G). Стикер: клик — окно задачи, кружок — сделано (штамп, через 2 с в «баночку»),
  // 2×клик по названию / F2 — переименовать, правый клик / Shift+F10 — меню. Логика раскладки — lib/stickers.js.
  import { tick, untrack } from 'svelte';
  import CardMenu from './CardMenu.svelte';
  import TopicsEdit from './TopicsEdit.svelte';
  import * as keys from './keys.js';
  import * as stk from './stickers.js';
  import { ymd } from './api.js';
  import { fromMin, toMin } from './calendar.js';
  import { stickerCrossfade, toJar, pop, rectsOf, flipFrom } from './motion.js';

  // layList — запись списка в слое (topics, group, sort); cols — колонки шаблона (для метки промежуточного этапа).
  // act — действия App (open, rename, priority, order, moveList, duplicate, remove, done, topic, pin, when, add, topics, set).
  // tabs — переключатель вида из доски; headLine — «Сфера · шаблон … » над названием.
  let { list, tasks, layList = {}, layTasks, cols = [], remindOf = () => '', act, lists = [], tabs, headLine = '', share = null, sphereName = '',
    onedittemplate, onarchive } = $props();

  const [send, receive] = stickerCrossfade();

  const today = $derived(ymd(new Date()));
  const topics = $derived(stk.topicsOf(layList));
  const group = $derived(layList?.group === 'when' ? 'when' : 'topic');
  const sort = $derived(layList?.sort === 'due' ? 'due' : 'pin');

  // Только что сделанные: висят со штампом 2 с, потом улетают в баночку.
  let stamped = $state(new Set());
  const top = $derived(tasks.filter((t) => !t.parent));
  const shown = $derived(top.filter((t) => t.status !== 'completed' || stamped.has(t.id)));
  const allLanes = $derived(stk.lanes(shown, { group, topics, layTasks, today, sort }));
  // По темам пустые темы спрятаны (кнопки «＋ в тему» под стеной); lanes — то, что на экране.
  const vis = $derived(stk.visibleLanes(allLanes, { group, keep: adding }));
  const lanes = $derived(vis.shown);
  const jarN = $derived(stk.jarCount(top.filter((t) => !stamped.has(t.id))));
  const firstCol = $derived(cols[0]?.id);
  const stageName = (t) => {
    const s = layTasks?.[t.id]?.status;
    return s && s !== firstCol && s !== 'done' ? cols.find((c) => c.id === s)?.name ?? '' : '';
  };
  const laneOf = (t) => lanes.find((l) => l.items.some((x) => x.id === t.id));

  let jarEl = $state(null);
  const timers = new Map();
  const unstamp = (id) => { stamped = new Set([...stamped].filter((x) => x !== id)); };
  // Сделано: штамп держится 2 с и до ответа Google — иначе при медленной сети стикер на миг возвращался открытым.
  // Второй клик в первые 0,6 с (двойной клик) отметку не снимает: стикер улетал в баночку и тут же возвращался.
  const markedAt = new Map();
  function done(t) {
    if (stamped.has(t.id) || t.status === 'completed') {
      if (Date.now() - (markedAt.get(t.id) ?? 0) < 600) return;
      clearTimeout(timers.get(t.id));
      timers.delete(t.id);
      unstamp(t.id);
      act.done(t, false);
      return;
    }
    stamped = new Set([...stamped, t.id]);
    markedAt.set(t.id, Date.now());
    let undone = false;
    const sent = act.done(t, true, () => { // «Отменить» на плашке
      undone = true;
      clearTimeout(timers.get(t.id));
      timers.delete(t.id);
      unstamp(t.id);
    });
    const wait = new Promise((r) => timers.set(t.id, setTimeout(r, 2000)));
    Promise.all([sent, wait]).then(() => {
      timers.delete(t.id);
      if (!undone) unstamp(t.id);
    });
  }
  $effect(() => () => timers.forEach((x) => clearTimeout(x)));
  // Уход: сделанный — в баночку, остальное — перелёт в новую колонку.
  function leave(node, params, opts) {
    if (node.dataset.done === '1') return toJar(node, { el: jarEl });
    return send(node, params, opts);
  }

  // ---------- выбор, переименование, меню ----------
  let sel = $state('');
  let editing = $state('');
  // Окно задачи — только по клику на название; ждём чуть-чуть, чтобы двойной клик успел стать переименованием.
  let openT;
  function titleClick(e, t) {
    e.stopPropagation();
    sel = t.id;
    clearTimeout(openT);
    if (e.detail > 1) return;
    openT = setTimeout(() => act.open(t), 220);
  }
  let menu = $state(null);
  const selTask = $derived(shown.find((t) => t.id === sel) ?? null);
  const stickerEl = (id) => document.querySelector(`.stk[data-id="${id}"]`);
  // autofocus не всегда успевает: фокус остаётся на стикере после двойного клика
  async function startEdit(id) {
    editing = id;
    await tick();
    stickerEl(id)?.querySelector('.t-edit')?.focus();
  }
  async function focusSticker(id) {
    sel = id;
    await tick();
    stickerEl(id)?.focus();
  }
  function openMenu(t, anchor, x = null) {
    sel = t.id;
    const r = anchor?.getBoundingClientRect?.();
    menu = { task: t, at: x ?? (r ? { x: r.right - 236, y: r.top + 30 } : { x: innerWidth / 2 - 118, y: innerHeight / 3 }) };
  }
  function menuAction(name, arg) {
    const t = menu?.task;
    if (!t) return;
    if (name === 'open') act.open(t);
    else if (name === 'rename') startEdit(t.id);
    else if (name === 'due') act.open(t, true);
    else if (name === 'priority') act.priority(t, arg);
    else if (name === 'list') act.moveList(t, arg);
    else if (name === 'duplicate') act.duplicate(t);
    else if (name === 'delete') act.remove(t);
    else if (name === 'pin') act.pin(t);
    else if (name === 'topic') act.topic(t, arg);
  }
  function renameKey(e, t) {
    if (e.key === 'Enter') { e.preventDefault(); finishRename(t, e.currentTarget.value); }
    else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); editing = ''; focusSticker(t.id); }
  }
  function finishRename(t, v) {
    const title = v.trim();
    editing = '';
    if (title && title !== t.title) act.rename(t, title);
    focusSticker(t.id);
  }

  /** Сдвинуть стикер на позицию в колонке: ord всей колонке. */
  function reorder(t, lane, index) {
    const ids = lane.items.map((x) => x.id).filter((id) => id !== t.id);
    ids.splice(Math.max(0, Math.min(index, ids.length)), 0, t.id);
    act.order(ids);
  }
  /** В другую колонку: сменить тему или срок. */
  function moveTo(t, laneId) {
    if (group === 'topic') act.topic(t, laneId || null);
    else act.when(t, laneId);
  }

  // Смена раскладки — без Svelte-переходов (с |global старые колонки ждали улёта стикеров и оставались на экране
  // вперемешку с новыми), перелёт стикеров — FLIP из motion.js.
  let wallEl = $state(null);
  async function flipGroup() {
    const before = rectsOf(wallEl);
    adding = null;
    act.set({ group: group === 'when' ? 'topic' : 'when' });
    await tick();
    flipFrom(wallEl, before);
  }

  // ---------- клавиши ----------
  function onKey(e) {
    if (menu || editing || topicsOpen || keys.typing(e) || keys.overlay()) return;
    const handled = () => { e.preventDefault(); e.stopPropagation(); };
    if (keys.plain(e) && !e.shiftKey && e.code === 'KeyG') { handled(); flipGroup(); return; }
    const arrows = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'];
    if (!selTask) {
      if (arrows.includes(e.key) && !e.altKey && !e.ctrlKey) {
        const first = lanes.map((l) => l.items[0]).find(Boolean);
        if (first) { handled(); focusSticker(first.id); }
      }
      if (keys.plain(e) && !e.shiftKey && e.code === 'KeyN' && lanes.length) { handled(); startAdd(lanes[0].id); }
      return;
    }
    const t = selTask;
    const lane = laneOf(t);
    if (!lane) return;
    const li = lanes.indexOf(lane);
    const idx = lane.items.findIndex((x) => x.id === t.id);
    if (e.altKey && !e.ctrlKey) {
      if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
        handled();
        const to = lanes[li + (e.key === 'ArrowRight' ? 1 : -1)];
        if (to) { moveTo(t, to.id); tick().then(() => focusSticker(t.id)); }
        return;
      }
      if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
        handled();
        reorder(t, lane, idx + (e.key === 'ArrowUp' ? -1 : 1));
        tick().then(() => focusSticker(t.id));
        return;
      }
      const d = /^Digit([0-3])$/.exec(e.code);
      if (d) { handled(); act.priority(t, d[1] === '0' ? null : Number(d[1])); }
      return;
    }
    if ((e.shiftKey && e.key === 'F10') || e.key === 'ContextMenu') { handled(); openMenu(t, stickerEl(t.id)); return; }
    if (e.ctrlKey && !e.altKey && e.code === 'KeyD') { handled(); act.duplicate(t); return; }
    if (!keys.plain(e)) return;
    if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
      handled();
      const n = lane.items[idx + (e.key === 'ArrowUp' ? -1 : 1)];
      if (n) focusSticker(n.id);
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
      handled();
      for (let i = li + (e.key === 'ArrowRight' ? 1 : -1); i >= 0 && i < lanes.length; i += e.key === 'ArrowRight' ? 1 : -1) {
        const items = lanes[i].items;
        if (items.length) { focusSticker(items[Math.min(idx, items.length - 1)].id); break; }
      }
    } else if (e.key === ' ' || e.code === 'Space') { handled(); done(t); }
    else if (e.key === 'Enter') { handled(); act.open(t); }
    else if (e.key === 'F2') { handled(); startEdit(t.id); }
    else if (e.code === 'KeyP' && !e.shiftKey) { handled(); act.pin(t); }
    else if (e.code === 'KeyN' && !e.shiftKey) { handled(); startAdd(lane.id); }
    else if (e.code === 'KeyD' && !e.shiftKey) { handled(); act.open(t, true); }
    else if (e.code === 'KeyM' && !e.shiftKey) { handled(); openMenu(t, stickerEl(t.id)); }
    else if (e.key === 'Delete') {
      handled();
      const n = lane.items[idx + 1] ?? lane.items[idx - 1];
      act.remove(t);
      if (n) focusSticker(n.id); else sel = '';
    } else if (e.key === 'Escape') { handled(); sel = ''; document.activeElement?.blur?.(); }
  }

  // ---------- перетаскивание ----------
  let dragId = $state('');
  let drop = $state(null); // { lane, index }
  function dragStart(e, t) {
    dragId = t.id;
    sel = t.id;
    e.dataTransfer.setData('text/plain', t.id);
    e.dataTransfer.effectAllowed = 'move';
    const el = e.currentTarget;
    el.classList.add('lift');
    setTimeout(() => el.classList.remove('lift'), 0);
  }
  function dragEnd() { dragId = ''; drop = null; }
  function dragOver(e, laneId) {
    if (!dragId) return;
    e.preventDefault();
    const els = [...e.currentTarget.querySelectorAll('.stk:not(.ghost)')];
    let index = els.length;
    for (let i = 0; i < els.length; i++) {
      const r = els[i].getBoundingClientRect();
      if (e.clientY < r.top + r.height / 2 || (e.clientY < r.bottom && e.clientX < r.left + r.width / 2)) { index = i; break; }
    }
    if (drop?.lane !== laneId || drop?.index !== index) drop = { lane: laneId, index };
  }
  function dragLeave(e, laneId) {
    if (drop?.lane === laneId && !e.currentTarget.contains(e.relatedTarget)) drop = null;
  }
  function dropOn(e, lane) {
    e.preventDefault();
    const t = shown.find((x) => x.id === dragId);
    const index = drop?.index ?? lane.items.length;
    dragEnd();
    if (!t) return;
    if (laneOf(t)?.id !== lane.id) moveTo(t, lane.id);
    reorder(t, lane, index);
  }

  // ---------- новый стикер ----------
  // null — новый стикер не пишут; '' — пишут в «Разное» (у этой колонки id пустой).
  let adding = $state(null);
  let draft = $state('');
  let addEl = $state(null);
  async function startAdd(laneId) {
    adding = laneId;
    draft = '';
    await tick();
    addEl?.focus();
  }
  async function commit(lane) {
    const p = stk.parseSticker(draft, topics, new Date());
    if (!p.title) return;
    draft = '';
    const topic = p.topic ?? (group === 'topic' ? lane.id || null : null);
    const due = p.day ?? (group === 'when' ? stk.newDue(lane.id, today) : p.time ? today : null);
    // В конец своей колонки (#тема или «в пятницу» могут увести в другую): колонке — порядок, новому — следующий номер.
    const dest = allLanes.find((l) => l.id === (group === 'topic' ? topic ?? '' : stk.bucket(due ?? '', today))) ?? lane;
    if (dest.items.some((x) => typeof layTasks?.[x.id]?.ord !== 'number')) act.order(dest.items.map((x) => x.id));
    const layer = { ord: Math.max(dest.items.length, ...dest.items.map((x) => (layTasks?.[x.id]?.ord ?? 0) + 1)) };
    if (topic) layer.topic = topic;
    if (p.priority) layer.priority = p.priority;
    if (p.repeat) layer.repeat = p.repeat;
    const slot = p.time ? { s: p.time, e: fromMin(Math.min(toMin(p.time) + 60, 1439)) } : null;
    await act.add({ title: p.title, due, slot, layer });
    addEl?.focus();
  }
  function addKey(e, lane) {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); commit(lane); }
    else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); adding = null; draft = ''; }
  }

  // ---------- меню шапки и темы ----------
  let headMenu = $state(false);
  let topicsOpen = $state(false);
  const SORTS = [{ id: 'pin', name: 'Закреплённые сверху' }, { id: 'due', name: 'Срочные сверху' }];
  const tiltOf = (id) => untrack(() => stk.tilt(id));
</script>

<svelte:window onkeydowncapture={onKey} />

<header class="bd-head">
  <div class="bd-title">
    <p>{#if share && sphereName}<span class="bd-path">{sphereName}<SharedTag small /></span>{' · '}{headLine.slice(sphereName.length + 3)}{:else}{headLine}{/if} · вид «Стикеры» · <button type="button" class="link" title="Колонки и вид шаблона" onclick={onedittemplate}>настроить</button></p>
    <h1>{list?.title ?? 'Дела'}{#if share}<ShareBits {share} />{/if}</h1>
  </div>
  <div class="tb">
    <button type="button" class="grpsw" title="Разложить по-другому · G" aria-label={group === 'when' ? 'Сейчас по срокам. Разложить по темам' : 'Сейчас по темам. Разложить по срокам'} onclick={flipGroup}>
      <span class:on={group === 'topic'}><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="4" width="6" height="16" rx="2" /><rect x="14" y="4" width="6" height="10" rx="2" /></svg>По темам</span>
      <span class:on={group === 'when'}><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8" /><path d="M12 8v4l3 2" /></svg>По срокам</span>
    </button>
    {#if group === 'topic'}
      <span class="tb-sep" aria-hidden="true"></span>
      {#each SORTS as s (s.id)}<button type="button" class="fb" aria-pressed={sort === s.id} onclick={() => act.set({ sort: s.id })}>{s.name}</button>{/each}
    {/if}
    <span class="tb-sep" aria-hidden="true"></span>
    {@render tabs()}
    <div class="stk-more">
      <button type="button" class="hb" aria-label="Ещё" title="Ещё" aria-expanded={headMenu} onclick={() => (headMenu = !headMenu)}>
        <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="5" cy="12" r="1.4" /><circle cx="12" cy="12" r="1.4" /><circle cx="19" cy="12" r="1.4" /></svg>
      </button>
      {#if headMenu}
        <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
        <div class="cm-back" onclick={() => (headMenu = false)}></div>
        <div class="cmenu stk-hm" role="menu" transition:pop style="transform-origin: top right">
          <button type="button" role="menuitem" onclick={() => { headMenu = false; topicsOpen = true; }}>Темы…</button>
          <button type="button" role="menuitem" onclick={() => { headMenu = false; onarchive(); }}>Баночка — сделанное</button>
        </div>
      {/if}
    </div>
  </div>
</header>

<div class="wall" class:when={group === 'when'} style="--lanes: {Math.max(5, lanes.length + (vis.hidden.length ? 1 : 0))}" bind:this={wallEl}>
  {#each lanes as lane, li (group + lane.id)}
    <section class="lane" class:drop={drop?.lane === lane.id} style="--tc: {lane.c}" aria-label={lane.name}
      ondragover={(e) => dragOver(e, lane.id)} ondragleave={(e) => dragLeave(e, lane.id)} ondrop={(e) => dropOn(e, lane)}>
      <header class="lh" class:big={group === 'when'}>
        {#if group === 'topic'}<i></i>{/if}{lane.name}<b>{lane.items.filter((t) => t.status !== 'completed').length}</b>
        {#if lane.sub}<span class="lh-sub">{lane.sub}</span>{/if}
      </header>
      <div class="stack">
        {#each lane.items as t, k (t.id)}
          {@const L = layTasks?.[t.id] ?? {}}
          {@const tp = stk.topicOfTask(t, layTasks, topics)}
          {@const isDone = t.status === 'completed' || stamped.has(t.id)}
          {@const dl = stk.dueLabel(t.due ? t.due.slice(0, 10) : '', today, L.slot, group === 'when' && lane.id === 'today')}
          {@const stage = stageName(t)}
          {@const note = (t.notes ?? '').split('\n')[0]}
          {#if drop?.lane === lane.id && drop.index === k && dragId !== t.id}<div class="stk-ph" aria-hidden="true"></div>{/if}
          <!-- svelte-ignore a11y_no_noninteractive_tabindex, a11y_no_noninteractive_element_interactions, a11y_click_events_have_key_events -->
          <article class="stk" class:pin={L.pin && !isDone} class:done={isDone} class:sel={sel === t.id} class:ghost={dragId === t.id}
            data-id={t.id} data-done={isDone ? '1' : '0'} tabindex="0" draggable={editing !== t.id}
            style="--tc: {tp ? stk.topicColor(tp) : stk.MISC.c}; --rot: {tiltOf(t.id)}deg"
            aria-label="{t.title || 'Без названия'}{tp ? `, ${tp.name}` : ''}{isDone ? ', сделано' : ''}"
            in:receive={{ key: t.id, delay: k * 12 }} out:leave={{ key: t.id }}
            onclick={() => (sel = t.id)}
            onfocus={() => (sel = t.id)}
            oncontextmenu={(e) => { e.preventDefault(); openMenu(t, null, { x: e.clientX, y: e.clientY }); }}
            ondragstart={(e) => dragStart(e, t)} ondragend={dragEnd}>
            {#if L.pin && !isDone}<span class="pinmark" title="Закреплено" aria-hidden="true"></span>{/if}
            {#if group === 'when'}<span class="tagl"><i></i>{tp?.name ?? stk.MISC.name}</span>{/if}
            {#if editing === t.id}
              <!-- svelte-ignore a11y_autofocus -->
              <input class="t-edit" value={t.title} aria-label="Название" autofocus onclick={(e) => e.stopPropagation()}
                onkeydown={(e) => renameKey(e, t)} onblur={(e) => finishRename(t, e.currentTarget.value)} />
            {:else}
              <!-- svelte-ignore a11y_no_static_element_interactions, a11y_click_events_have_key_events -->
              <div class="t" onclick={(e) => titleClick(e, t)} ondblclick={(e) => { e.stopPropagation(); clearTimeout(openT); startEdit(t.id); }}>{t.title || 'Без названия'}</div>
            {/if}
            {#if note}<p class="d">{note}</p>{/if}
            <div class="ft">
              {#if stage}<span class="stg" title="Этап из канбана">{stage}</span>{/if}
              {#if dl.text}<span class="due {dl.cls}">{dl.text}</span>{/if}
              {#if L.repeat?.every}<span class="due" title="Повторяется">↻</span>{/if}
              {#if remindOf(t) && !isDone}<span class="due" title="Напоминание: {remindOf(t)}">🔔</span>{/if}
              <button type="button" class="ck" aria-pressed={isDone} aria-label={isDone ? 'Вернуть' : 'Сделано'} title={isDone ? 'Вернуть' : 'Сделано'}
                onclick={(e) => { e.stopPropagation(); done(t); }}>
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
              </button>
            </div>
            {#if isDone}<span class="stamp" aria-hidden="true">сделано</span>{/if}
          </article>
        {/each}
        {#if drop?.lane === lane.id && drop.index >= lane.items.filter((t) => t.id !== dragId).length}<div class="stk-ph" aria-hidden="true"></div>{/if}
        {#if adding === lane.id}
          <div class="stk-new open">
            <textarea bind:this={addEl} bind:value={draft} rows="2" aria-label="Новый стикер в «{lane.name}»" placeholder="Что сделать?"
              onkeydown={(e) => addKey(e, lane)} onblur={() => { if (!draft.trim()) adding = null; }}></textarea>
            <span class="stk-new-hint">Enter — приклеить · Esc — отмена</span>
          </div>
        {:else}
          <button type="button" class="stk-new" onclick={() => startAdd(lane.id)}>＋ Новый стикер</button>
        {/if}
      </div>
    </section>
  {/each}
  {#if vis.hidden.length}
    <section class="lane lane-more" aria-label="Пустые темы">
      <header class="lh">Пустые темы</header>
      <div class="more-chips">
        {#each vis.hidden as h (h.id)}
          <button type="button" class="more-chip" style="--tc: {h.c}" title="Новый стикер в «{h.name}»" onclick={() => startAdd(h.id)}><i></i>＋ {h.name}</button>
        {/each}
      </div>
    </section>
  {/if}
</div>

<footer class="kb-hint stk-hint" aria-label="Подсказка по клавишам">
  <span><kbd>клик по кружку</kbd>сделано — штамп, через 2 с в баночку</span><span><kbd>клик по стикеру</kbd>открыть</span><span><kbd>G</kbd>по темам ⇄ по срокам</span><span><kbd>перетащить</kbd>в другую тему или срок</span><span><kbd>P</kbd>закрепить сверху</span><span><kbd>N</kbd>новый стикер в выбранную тему</span><span><kbd>?</kbd>все клавиши</span>
</footer>

<button type="button" class="basket" aria-label="Сделано за неделю: {jarN}. Открыть баночку" onclick={onarchive}>
  <span class="jar" bind:this={jarEl}>{#key jarN}<span class="num-roll">{jarN}</span>{/key}</span>
  <span>Сделано за неделю<small>открыть баночку</small></span>
</button>

{#if menu}
  {@const mt = shown.find((t) => t.id === menu.task.id) ?? menu.task}
  <CardMenu at={menu.at} priority={layTasks?.[mt.id]?.priority ?? null} {lists} pinned={!!layTasks?.[mt.id]?.pin}
    {topics} topic={layTasks?.[mt.id]?.topic ?? ''}
    onaction={menuAction} onclose={() => { const id = menu?.task.id; menu = null; if (id) focusSticker(id); }} />
{/if}

{#if topicsOpen}
  <TopicsEdit {topics} count={(id) => top.filter((t) => t.status !== 'completed' && (layTasks?.[t.id]?.topic ?? '') === id).length}
    onsave={(next) => { act.topics(next); topicsOpen = false; }} onclose={() => (topicsOpen = false)} />
{/if}
