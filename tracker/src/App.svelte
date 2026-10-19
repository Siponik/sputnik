<script>
  import { onMount } from 'svelte';
  import Brand from './lib/Brand.svelte';
  import Setup from './lib/Setup.svelte';
  import Board from './lib/Board.svelte';
  import Archive from './lib/Archive.svelte';
  import Today from './lib/Today.svelte';
  import Habits from './lib/Habits.svelte';
  import NewList from './lib/NewList.svelte';
  import TaskDrawer from './lib/TaskDrawer.svelte';
  import Calendar from './lib/Calendar.svelte';
  import QuickAdd from './lib/QuickAdd.svelte';
  import * as api from './lib/api.js';
  import { templateOf, isHabitList, HABITS } from './lib/templates.js';
  import { isDone, logKey } from './lib/habits.js';
  import * as reminders from './lib/reminders.js';
  import { typeOfTemplate } from './lib/calendar.js';
  import * as inbox from './lib/inbox.js';

  let phase = $state('loading'); // loading | setup | ready
  let authInfo = $state({ has_secret: false, signed_in: false });
  let view = $state('today'); // today | calendar | board | archive | habits
  let lists = $state([]);
  let activeId = $state(null);
  let tasks = $state({}); // listId → задачи (вместе с подзадачами)
  let lay = $state(emptyLayer()); // слой Спутника: то, чего нет в Google
  let events = $state([]);
  let inboxSt = $state(null); // статус «Входящих от Claude»
  let openRef = $state(null); // { listId, id }
  let newList = $state(false);
  let quick = $state(null); // окно «Создать»: { day, s, e } — что подставить
  let sync = $state({ busy: false, err: '', at: null });
  let toast = $state('');
  let toastTimer;

  function emptyLayer() { return { version: 1, tasks: {}, lists: {}, habits: {}, log: {} }; }

  const boardLists = $derived(lists.filter((l) => !isHabitList(l, lay)));
  const habitList = $derived(lists.find((l) => isHabitList(l, lay)) ?? null);
  const activeList = $derived(boardLists.find((l) => l.id === activeId));
  const templateFor = (listId) => templateOf(lay.lists?.[listId]?.template);
  const openTask = $derived(openRef ? (tasks[openRef.listId] ?? []).find((t) => t.id === openRef.id) : null);
  const openSubs = $derived(openTask ? (tasks[openRef.listId] ?? []).filter((t) => t.parent === openTask.id).sort((a, b) => (a.position || '').localeCompare(b.position || '')) : []);
  const openCount = (l) => (tasks[l.id] ?? []).filter((t) => !t.parent && t.status !== 'completed').length;
  const todayCount = $derived.by(() => {
    const t = api.ymd(new Date());
    return boardLists.reduce((n, l) => n + (tasks[l.id] ?? []).filter((x) => !x.parent && x.status !== 'completed' && x.due && api.dueToYmd(x.due) <= t).length, 0);
  });

  const habits = $derived(habitList
    ? (tasks[habitList.id] ?? []).filter((t) => !t.parent && t.status !== 'completed')
        .sort((a, b) => (a.position || '').localeCompare(b.position || ''))
        .map((t) => ({ id: t.id, name: t.title || 'Без названия', days: lay.habits?.[t.id]?.days ?? [], createdAt: lay.habits?.[t.id]?.createdAt }))
    : []);
  const inboxItems = $derived(inbox.pending(inboxSt, boardLists, tasks, lay.tasks));
  const habitsLeft = $derived(habits.filter((h) => !isDone(lay.log, h.id, api.ymd(new Date()))).length);

  function say(msg) {
    toast = msg;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (toast = ''), 6000);
  }

  // Каждая запись слоя несёт t — время изменения, по нему слой потом сливается между компьютерами.
  function touch(section, key, patch) {
    lay[section] ??= {};
    lay[section][key] = { ...(lay[section][key] ?? {}), ...patch, t: Date.now() };
  }

  /** Колонка задачи на доске с данными колонками. */
  function colOf(task, cols) {
    if (task.status === 'completed') return 'done';
    const s = lay.tasks?.[task.id]?.status;
    return s && s !== 'done' && cols.some((c) => c.id === s) ? s : cols[0].id;
  }
  function statusOf(task) {
    if (task.status === 'completed') return 'done';
    return lay.tasks?.[task.id]?.status || 'inbox';
  }

  // ---------- напоминания ----------

  const remindOf = (task) => reminders.remindLabel(lay.tasks?.[task.id]?.remind, task);

  function setRemind(r) {
    touch('tasks', openRef.id, { remind: r });
    saveLayer();
  }

  // Любое изменение задач или напоминаний — через 3 с обновляем файл для облака (если список поменялся).
  let publishTimer;
  let publishWarned = false;
  $effect(() => {
    if (phase !== 'ready' || !sync.at) return;
    const items = reminders.collect(boardLists, tasks, lay.tasks);
    clearTimeout(publishTimer);
    publishTimer = setTimeout(() => {
      reminders.publish(items).catch((e) => {
        if (!publishWarned) { publishWarned = true; say('Не удалось передать напоминания на Google Drive: ' + e); }
      });
    }, 3000);
  });

  async function saveLayer() {
    try { await api.layer.write($state.snapshot(lay)); } catch (e) { say('Не удалось сохранить: ' + e); }
  }

  // Привычкам без записи в слое ставим дату начала — сегодня, чтобы старые дни не считались пропусками.
  function ensureHabitMeta() {
    if (!habitList) return;
    let changed = false;
    for (const t of tasks[habitList.id] ?? []) {
      if (!t.parent && !lay.habits?.[t.id]?.createdAt) { touch('habits', t.id, { createdAt: api.ymd(new Date()) }); changed = true; }
    }
    if (changed) saveLayer();
  }

  async function refresh() {
    if (sync.busy) return;
    sync.busy = true;
    sync.err = '';
    try {
      const ls = await api.listLists();
      const all = await Promise.all(ls.map((l) => api.listTasks(l.id)));
      lists = ls;
      tasks = Object.fromEntries(ls.map((l, i) => [l.id, all[i]]));
      if (!activeId || !boardLists.some((l) => l.id === activeId)) activeId = boardLists[0]?.id ?? null;
      ensureHabitMeta();
      events = await api.eventsForDay().catch(() => []);
      inboxSt = await api.inboxStatus().catch(() => inboxSt);
      pullInboxLayer();
      sync.at = new Date();
    } catch (e) {
      sync.err = String(e);
      if (/войдите|sign in|invalid_grant/i.test(sync.err)) { phase = 'setup'; authInfo = await api.auth.status(); }
      else say('Не удалось обновить: ' + e);
    } finally {
      sync.busy = false;
    }
  }

  async function start() {
    authInfo = await api.auth.status();
    if (!authInfo.has_secret || !authInfo.signed_in) { phase = 'setup'; return; }
    phase = 'ready';
    lay = { ...emptyLayer(), ...(await api.layer.read().catch(() => ({}))) };
    await refresh();
  }

  // ---------- быстрое добавление: кнопка «Создать» и Ctrl+N ----------

  // Экран может сам принять быстрое добавление (на «Сегодня» — строка сверху), иначе открываем окно «Создать».
  let quickLine = null;
  function newTask() {
    if (!boardLists.length || openRef || newList) return;
    if (quickLine?.()) return;
    quick = {};
  }
  function hotkey(e) {
    if (phase !== 'ready') return;
    if ((e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && (e.code === 'KeyN')) { e.preventDefault(); newTask(); }
  }

  let inboxFocus = $state(0); // просьба «Сегодня» прокрутить к входящим
  function openInbox() { view = 'today'; inboxFocus++; }

  onMount(() => {
    start();
    const timer = setInterval(() => { if (phase === 'ready') refresh(); }, 120000);
    const onFocus = () => { if (phase === 'ready' && (!sync.at || Date.now() - sync.at > 30000)) refresh(); };
    window.addEventListener('focus', onFocus);
    return () => { clearInterval(timer); window.removeEventListener('focus', onFocus); };
  });

  function replace(listId, updated) {
    tasks[listId] = (tasks[listId] ?? []).map((t) => (t.id === updated.id ? updated : t));
  }

  async function toggle(task, done, listId = openRef?.listId ?? activeId) {
    try {
      const r = await api.completeTask(listId, task.id, done);
      replace(listId, r);
      if (done && !task.parent) say(`«${task.title}» выполнено`);
    } catch (e) { say('Не удалось отметить: ' + e); }
  }

  async function move(task, col, listId = activeId) {
    if (col !== 'done') { touch('tasks', task.id, { status: col }); saveLayer(); }
    const wasDone = task.status === 'completed';
    if (col === 'done' && !wasDone) await toggle(task, true, listId);
    else if (col !== 'done' && wasDone) await toggle(task, false, listId);
  }

  async function create(title) {
    if (!activeId) return;
    try {
      const r = await api.createTask(activeId, { title });
      tasks[activeId] = [r, ...(tasks[activeId] ?? [])];
    } catch (e) { say('Не удалось создать задачу: ' + e); }
  }

  async function createList(title, template) {
    try {
      const l = await api.createList(title);
      touch('lists', l.id, { template });
      saveLayer();
      lists = [...lists, l];
      tasks[l.id] = [];
      activeId = l.id;
      view = 'board';
      newList = false;
    } catch (e) { say('Не удалось создать список: ' + e); }
  }

  function setTemplate(template) {
    touch('lists', activeId, { template });
    saveLayer();
  }

  async function save(patch) {
    const { listId, id } = openRef;
    try { replace(listId, await api.patchTask(listId, id, patch)); }
    catch (e) { say('Не удалось сохранить: ' + e); }
  }

  async function remove() {
    const { listId, id } = openRef;
    try {
      await api.deleteTask(listId, id);
      tasks[listId] = (tasks[listId] ?? []).filter((t) => t.id !== id && t.parent !== id);
      openRef = null;
      say('Задача удалена');
    } catch (e) { say('Не удалось удалить: ' + e); }
  }

  async function addSub(title) {
    const { listId, id } = openRef;
    try {
      const r = await api.createTask(listId, { title }, id);
      tasks[listId] = [...(tasks[listId] ?? []), r];
    } catch (e) { say('Не удалось добавить подзадачу: ' + e); }
  }

  // ---------- входящие от Claude ----------

  // Поля Спутника (тип, проект, теги…), которые прислал чат, переносим в свой слой один раз.
  function pullInboxLayer() {
    const patches = inbox.layerPatches(inboxSt, lay.tasks);
    for (const [id, patch] of patches) touch('tasks', id, patch);
    if (patches.length) saveLayer();
  }

  function acceptInbox(items) {
    for (const x of items) touch('tasks', x.task.id, { inbox: 'accepted' });
    saveLayer();
    say(items.length > 1 ? `Принято задач: ${items.length}` : `«${items[0].task.title}» — принято`);
  }

  async function rejectInbox(x) {
    try {
      await api.deleteTask(x.listId, x.task.id);
      tasks[x.listId] = (tasks[x.listId] ?? []).filter((t) => t.id !== x.task.id && t.parent !== x.task.id);
      touch('tasks', x.task.id, { inbox: 'rejected' });
      saveLayer();
      say(`«${x.task.title}» — отклонено и удалено`);
    } catch (e) { say('Не удалось отклонить: ' + e); }
  }

  // ---------- календарь ----------

  // Цвет задачи: свой тип из слоя (например, пришёл из чата), иначе — по шаблону списка.
  const typeOf = (listId, taskId) => lay.tasks?.[taskId]?.type ?? typeOfTemplate(lay.lists?.[listId]?.template);

  function setSlot(taskId, slot) {
    touch('tasks', taskId, { slot });
    saveLayer();
  }

  /** Ставит задаче день и время (или убирает их: day = null, slot = null). */
  async function schedule(task, listId, day, slot) {
    try {
      if (api.dueToYmd(task.due) !== (day ?? '')) replace(listId, await api.patchTask(listId, task.id, { due: api.ymdToDue(day) }));
      setSlot(task.id, slot);
      return true;
    } catch (e) { say('Не удалось запланировать: ' + e); return false; }
  }

  async function quickCreate({ title, listId, due, slot }) {
    try {
      const r = await api.createTask(listId, { title, ...(due ? { due: api.ymdToDue(due) } : {}) });
      tasks[listId] = [r, ...(tasks[listId] ?? [])];
      if (slot) setSlot(r.id, slot);
      say(`«${title}» — добавлено${due ? '' : ' на доску'}`);
      return true;
    } catch (e) { say('Не удалось создать задачу: ' + e); return false; }
  }

  // ---------- привычки ----------

  function toggleHabit(h) {
    const day = api.ymd(new Date());
    touch('log', logKey(h.id, day), { done: !isDone(lay.log, h.id, day) });
    saveLayer();
  }

  async function createHabit(name, days) {
    try {
      let l = habitList;
      if (!l) {
        l = await api.createList('Привычки');
        touch('lists', l.id, { template: HABITS });
        lists = [...lists, l];
        tasks[l.id] = [];
      }
      const t = await api.createTask(l.id, { title: name });
      tasks[l.id] = [...(tasks[l.id] ?? []), t];
      touch('habits', t.id, { days, createdAt: api.ymd(new Date()) });
      saveLayer();
    } catch (e) { say('Не удалось добавить привычку: ' + e); }
  }

  async function updateHabit(id, { name, days }) {
    touch('habits', id, { days });
    saveLayer();
    const t = (tasks[habitList.id] ?? []).find((x) => x.id === id);
    if (t && t.title !== name) {
      try { replace(habitList.id, await api.patchTask(habitList.id, id, { title: name })); }
      catch (e) { say('Не удалось переименовать: ' + e); }
    }
  }

  async function deleteHabit(id) {
    try {
      await api.deleteTask(habitList.id, id);
      tasks[habitList.id] = (tasks[habitList.id] ?? []).filter((t) => t.id !== id);
      delete lay.habits[id];
      for (const k of Object.keys(lay.log)) if (k.startsWith(id + '|')) delete lay.log[k];
      saveLayer();
      say('Привычка удалена');
    } catch (e) { say('Не удалось удалить привычку: ' + e); }
  }

  async function logout() {
    await api.auth.logout().catch(() => {});
    lists = []; tasks = {}; events = []; openRef = null;
    authInfo = await api.auth.status();
    phase = 'setup';
  }

  const syncLabel = $derived(sync.busy ? 'Синхронизация…' : sync.err ? 'Нет связи с Google' : sync.at ? `Синхронизировано · ${sync.at.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}` : 'Ещё не синхронизировано');
</script>

<svelte:window onkeydown={hotkey} />

{#if phase === 'loading'}
  <div class="setup"><span class="spinner" aria-label="Загрузка"></span></div>
{:else if phase === 'setup'}
  <Setup status={authInfo} onready={start} onerror={say} />
{:else}
  <div class="shell">
    <nav class="sp-tabs" aria-label="Разделы">
      <Brand />
      <button class="sp-tab" role="tab" aria-selected={view === 'today'} onclick={() => (view = 'today')}>Сегодня <span class="n">· {todayCount}</span></button>
      <button class="sp-tab" role="tab" aria-selected={view === 'calendar'} onclick={() => (view = 'calendar')}>Календарь</button>
      <button class="sp-tab" role="tab" aria-selected={view === 'board' || view === 'archive'} onclick={() => (view = 'board')}>Доска</button>
      <button class="sp-tab" role="tab" aria-selected={view === 'habits'} onclick={() => (view = 'habits')}>Привычки{#if habitsLeft}<span class="n"> · {habitsLeft}</span>{/if}</button>
      <div class="right">
        <button class="sync" class:busy={sync.busy} class:err={!!sync.err} type="button" onclick={refresh} title="Обновить сейчас">
          <span class="dot"></span>{syncLabel}
        </button>
        {#if inboxItems.length}
          <button class="sp-btn sp-btn-ghost inbox-btn" type="button" title="Входящие от Claude — разобрать на «Сегодня»"
            aria-label="Входящие от Claude, {inboxItems.length}" onclick={openInbox}>
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 13h4l2 3h4l2-3h4M5 5h14l1 8v6H4v-6z" /></svg>
            <span class="n">{inboxItems.length}</span>
          </button>
        {/if}
        <button class="sp-btn sp-btn-primary" type="button" style="min-height: 32px" disabled={!boardLists.length} title={boardLists.length ? 'Новая задача (Ctrl+N)' : 'Сначала создай список на доске'} onclick={newTask}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>Создать
        </button>
      </div>
    </nav>

    <div class="body">
      {#if view === 'board' || view === 'archive'}
      <aside class="side">
        <div>
          <h4>Списки</h4>
          {#each boardLists as l (l.id)}
            <button class="item" class:on={(view === 'board' || view === 'archive') && l.id === activeId} type="button" onclick={() => { activeId = l.id; view = 'board'; }}>
              <span>{l.title}</span><span class="n">{openCount(l)}</span>
            </button>
          {:else}
            <p class="empty">Списков пока нет.</p>
          {/each}
          <button class="item add" type="button" onclick={() => (newList = true)}><span>+ Новый список</span></button>
        </div>
        <div class="foot">
          <span>Спутник 0.2</span>
          <button type="button" onclick={logout}>Выйти из Google</button>
        </div>
      </aside>
      {/if}

      <div class="main">
        {#if view === 'today'}
          <Today lists={boardLists} tasksByList={tasks} {events} {statusOf} onopen={(t, listId) => (openRef = { listId, id: t.id })} ontoggle={(t, d, listId) => toggle(t, d, listId)} />
        {:else if view === 'calendar'}
          <Calendar lists={boardLists} tasksByList={tasks} layTasks={lay.tasks} log={lay.log} {habits} {typeOf}
            loadEvents={api.eventsRange} syncAt={sync.at}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            ontoggle={(t, d, listId) => toggle(t, d, listId)}
            ontogglehabit={toggleHabit}
            onschedule={schedule}
            oncreate={(p) => (quick = p)} />
        {:else if view === 'habits'}
          <Habits {habits} log={lay.log} ontoggle={toggleHabit} oncreate={createHabit} onupdate={updateHabit} ondelete={deleteHabit} />
        {:else if view === 'archive'}
          <Archive lists={boardLists} tasksByList={tasks} {activeId}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            onrestore={(t, listId) => move(t, templateFor(listId).cols[0].id, listId)}
            onback={() => (view = 'board')} />
        {:else if activeList}
          <Board list={activeList} tasks={tasks[activeId] ?? []} template={templateFor(activeId)} {colOf} {remindOf}
            onopen={(t) => (openRef = { listId: activeId, id: t.id })}
            onmove={(t, col) => move(t, col, activeId)}
            oncreate={create}
            onarchive={() => (view = 'archive')}
            ontemplate={setTemplate} />
        {:else}
          <div class="page"><p class="empty">Создай первый список — слева «+ Новый список».</p></div>
        {/if}
      </div>
    </div>
  </div>

  {#if openTask}
    {@const cols = templateFor(openRef.listId).cols}
    <TaskDrawer task={openTask} list={lists.find((l) => l.id === openRef.listId)} subs={openSubs} status={colOf(openTask, cols)} {cols}
      remind={lay.tasks?.[openTask.id]?.remind ?? null} onremind={setRemind}
      slot={lay.tasks?.[openTask.id]?.slot ?? null} onslot={(s) => setSlot(openTask.id, s)}
      onclose={() => (openRef = null)}
      onsave={save}
      onstatus={(s) => move(openTask, s, openRef.listId)}
      ondelete={remove}
      ontoggle={(t, d) => toggle(t, d, openRef.listId)}
      onaddsub={addSub} />
  {/if}

  {#if quick}
    <QuickAdd lists={boardLists} listId={boardLists.some((l) => l.id === activeId) ? activeId : null}
      day={quick.day ?? ''} s={quick.s ?? ''} e={quick.e ?? ''}
      oncreate={quickCreate} onclose={() => (quick = null)} />
  {/if}

  {#if newList}
    <NewList oncreate={createList} onclose={() => (newList = false)} />
  {/if}
{/if}

{#if toast}
  <div class="toast" role="status"><span>{toast}</span><button type="button" onclick={() => (toast = '')}>Скрыть</button></div>
{/if}
