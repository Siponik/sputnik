<script>
  import { onMount } from 'svelte';
  import Brand from './lib/Brand.svelte';
  import Setup from './lib/Setup.svelte';
  import Board from './lib/Board.svelte';
  import Today from './lib/Today.svelte';
  import TaskDrawer from './lib/TaskDrawer.svelte';
  import * as api from './lib/api.js';

  let phase = $state('loading'); // loading | setup | ready
  let authInfo = $state({ has_secret: false, signed_in: false });
  let view = $state('today');
  let lists = $state([]);
  let activeId = $state(null);
  let tasks = $state({}); // listId → задачи (вместе с подзадачами)
  let lay = $state({ tasks: {} }); // слой Спутника: то, чего нет в Google
  let events = $state([]);
  let openRef = $state(null); // { listId, id }
  let sync = $state({ busy: false, err: '', at: null });
  let toast = $state('');
  let toastTimer;

  const activeList = $derived(lists.find((l) => l.id === activeId));
  const openTask = $derived(openRef ? (tasks[openRef.listId] ?? []).find((t) => t.id === openRef.id) : null);
  const openSubs = $derived(openTask ? (tasks[openRef.listId] ?? []).filter((t) => t.parent === openTask.id).sort((a, b) => (a.position || '').localeCompare(b.position || '')) : []);
  const openCount = (l) => (tasks[l.id] ?? []).filter((t) => !t.parent && t.status !== 'completed').length;
  const todayCount = $derived.by(() => {
    const t = api.ymd(new Date());
    return lists.reduce((n, l) => n + (tasks[l.id] ?? []).filter((x) => !x.parent && x.status !== 'completed' && x.due && api.dueToYmd(x.due) <= t).length, 0);
  });

  function say(msg) {
    toast = msg;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (toast = ''), 6000);
  }

  function statusOf(task) {
    if (task.status === 'completed') return 'done';
    const s = lay.tasks?.[task.id]?.status;
    return s && s !== 'done' ? s : 'inbox';
  }

  async function saveLayer() {
    try { await api.layer.write($state.snapshot(lay)); } catch (e) { say('Не удалось сохранить статусы: ' + e); }
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
      if (!activeId || !ls.some((l) => l.id === activeId)) activeId = ls[0]?.id ?? null;
      events = await api.eventsForDay().catch(() => []);
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
    lay = await api.layer.read().catch(() => ({ tasks: {} }));
    if (!lay.tasks) lay.tasks = {};
    await refresh();
  }

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
    lay.tasks[task.id] = { ...(lay.tasks[task.id] ?? {}), status: col === 'done' ? 'inbox' : col };
    saveLayer();
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

  async function logout() {
    await api.auth.logout().catch(() => {});
    lists = []; tasks = {}; events = []; openRef = null;
    authInfo = await api.auth.status();
    phase = 'setup';
  }

  const syncLabel = $derived(sync.busy ? 'Синхронизация…' : sync.err ? 'Нет связи с Google' : sync.at ? `Синхронизировано · ${sync.at.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}` : 'Ещё не синхронизировано');
</script>

{#if phase === 'loading'}
  <div class="setup"><span class="spinner" aria-label="Загрузка"></span></div>
{:else if phase === 'setup'}
  <Setup status={authInfo} onready={start} onerror={say} />
{:else}
  <div class="shell">
    <nav class="sp-tabs" aria-label="Разделы">
      <Brand />
      <button class="sp-tab" role="tab" aria-selected={view === 'today'} onclick={() => (view = 'today')}>Сегодня <span class="n">· {todayCount}</span></button>
      <button class="sp-tab" role="tab" aria-selected={view === 'board'} onclick={() => (view = 'board')}>Доска</button>
      <button class="sp-tab" role="tab" aria-selected={false} disabled title="Скоро" style="opacity: .5; cursor: default">Привычки</button>
      <div class="right">
        <button class="sync" class:busy={sync.busy} class:err={!!sync.err} type="button" onclick={refresh} title="Обновить сейчас">
          <span class="dot"></span>{syncLabel}
        </button>
      </div>
    </nav>

    <div class="body">
      <aside class="side">
        <div>
          <h4>Списки</h4>
          {#each lists as l (l.id)}
            <button class="item" class:on={view === 'board' && l.id === activeId} type="button" onclick={() => { activeId = l.id; view = 'board'; }}>
              <span>{l.title}</span><span class="n">{openCount(l)}</span>
            </button>
          {:else}
            <p class="empty">Списков пока нет.</p>
          {/each}
        </div>
        <div class="foot">
          <span>Спутник 0.1</span>
          <button type="button" onclick={logout}>Выйти из Google</button>
        </div>
      </aside>

      <div class="main">
        {#if view === 'today'}
          <Today {lists} tasksByList={tasks} {events} {statusOf} onopen={(t, listId) => (openRef = { listId, id: t.id })} ontoggle={(t, d, listId) => toggle(t, d, listId)} />
        {:else if activeList}
          <Board list={activeList} tasks={tasks[activeId] ?? []} {statusOf}
            onopen={(t) => (openRef = { listId: activeId, id: t.id })}
            ontoggle={(t, d) => toggle(t, d, activeId)}
            onmove={(t, col) => move(t, col, activeId)}
            oncreate={create} />
        {/if}
      </div>
    </div>
  </div>

  {#if openTask}
    <TaskDrawer task={openTask} list={lists.find((l) => l.id === openRef.listId)} subs={openSubs} status={statusOf(openTask)}
      onclose={() => (openRef = null)}
      onsave={save}
      onstatus={(s) => move(openTask, s, openRef.listId)}
      ondelete={remove}
      ontoggle={(t, d) => toggle(t, d, openRef.listId)}
      onaddsub={addSub} />
  {/if}
{/if}

{#if toast}
  <div class="toast" role="status"><span>{toast}</span><button type="button" onclick={() => (toast = '')}>Скрыть</button></div>
{/if}
