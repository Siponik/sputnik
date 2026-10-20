<script>
  import { onMount, tick, flushSync } from 'svelte';
  import * as motion from './lib/motion.js';
  import * as keys from './lib/keys.js';
  import KeyHelp from './lib/KeyHelp.svelte';
  import WinControls from './lib/WinControls.svelte';
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
  import Coon from './lib/Coon.svelte';
  import * as api from './lib/api.js';
  import { templateOf, templatesFrom, isBuiltin, blankTemplate, shortName, isHabitList, HABITS } from './lib/templates.js';
  import Templates from './lib/Templates.svelte';
  import { spheresFrom, sphereOf, SPHERE_COLORS, SPHERE_ICONS } from './lib/spheres.js';
  import SphereIcon from './lib/SphereIcon.svelte';
  import SphereView from './lib/SphereView.svelte';
  import SphereEdit from './lib/SphereEdit.svelte';
  import SphereFilter from './lib/SphereFilter.svelte';
  import { isDone, logKey, stats, plural, MILESTONES } from './lib/habits.js';
  import * as notify from '@tauri-apps/plugin-notification';
  import * as updater from './lib/updater.js';
  import * as meta from './lib/meta.js';
  import { whenText } from './lib/when.js';
  import * as reminders from './lib/reminders.js';
  import { typeOfTemplate } from './lib/calendar.js';
  import * as inbox from './lib/inbox.js';

  let phase = $state('loading'); // loading | setup | ready
  let authInfo = $state({ has_secret: false, signed_in: false });
  let view = $state('today'); // today | calendar | board | archive | habits | templates | sphere
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
  let syncFlash = $state(false); // короткая вспышка точки синхронизации по окончании обмена
  let toastTimer;

  function emptyLayer() { return { version: 1, tasks: {}, lists: {}, habits: {}, log: {}, cals: {}, settings: {}, templates: {}, templatesEdit: {}, spheres: {} }; }

  // Скрытые на первом запуске списки (lists[id].hidden) на доске и в «Сегодня» не показываем.
  const boardLists = $derived(lists.filter((l) => !isHabitList(l, lay) && !lay.lists?.[l.id]?.hidden));
  const habitList = $derived(lists.find((l) => isHabitList(l, lay)) ?? null);
  const activeList = $derived(boardLists.find((l) => l.id === activeId));
  const templateFor = (listId) => templateOf(lay.lists?.[listId]?.template, lay);
  // Вид доски списка: свой (lists[id].view) или вид шаблона по умолчанию.
  const viewFor = (listId) => lay.lists?.[listId]?.view ?? templateFor(listId).view ?? 'kanban';
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
        .map((t) => ({ id: t.id, name: t.title || 'Без названия', days: lay.habits?.[t.id]?.days ?? [], time: lay.habits?.[t.id]?.time ?? null, createdAt: lay.habits?.[t.id]?.createdAt }))
        // привычки со временем — по времени, без времени — после них, в порядке списка
        .sort((a, b) => (a.time ?? '99').localeCompare(b.time ?? '99'))
    : []);
  const inboxItems = $derived(inbox.pending(inboxSt, boardLists, tasks, lay.tasks));
  const habitsLeft = $derived(habits.filter((h) => !isDone(lay.log, h.id, api.ymd(new Date()))).length);

  // Плашка внизу; undo — кнопка «Отменить» (перенос этапа, удаление). Таймер 6 с, на наведении — пауза.
  let toastUndo = $state(null);
  let toastN = $state(0); // номер плашки — заново запускает полоску-таймер
  let toastLeft = 0, toastStart = 0;
  function say(msg, undo = null) {
    toast = msg;
    toastUndo = undo;
    toastN++;
    toastLeft = 6000;
    resumeToast();
  }
  function resumeToast() {
    clearTimeout(toastTimer);
    toastStart = Date.now();
    toastTimer = setTimeout(() => { toast = ''; toastUndo = null; }, toastLeft);
  }
  function pauseToast() { clearTimeout(toastTimer); toastLeft = Math.max(800, toastLeft - (Date.now() - toastStart)); }
  function undoToast() { const fn = toastUndo; toast = ''; toastUndo = null; fn?.(); }

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

  const remindOf = (task) => reminders.remindLabel(lay.tasks?.[task.id]?.remind, task, lay.tasks?.[task.id]?.slot);

  // Напоминания по умолчанию: settings.remind = { task, event, birthday } — минуты до начала. Без срока они молчат,
  // а когда срок появится — сработает за N минут до него (или до времени задачи).
  const remindDefault = $derived(reminders.defaultRule(lay.settings));
  const remindDefaults = $derived({ task: reminders.defaultMins(lay.settings, 'task'), event: reminders.defaultMins(lay.settings, 'event'), birthday: reminders.defaultMins(lay.settings, 'birthday') });
  function setRemindDefault(kind, mins) {
    touch('settings', 'remind', { [kind]: mins });
    saveLayer();
  }
  // События и дни рождения с напоминаниями Спутника — читаем при каждой синхронизации.
  let remindEvents = $state([]);
  const loadRemindEvents = async () => { remindEvents = await api.remindEvents().catch(() => remindEvents); };

  function setRemind(r) {
    touch('tasks', openRef.id, { remind: r });
    saveLayer();
  }

  // Любое изменение задач или напоминаний — через 3 с обновляем файл для облака (если список поменялся).
  let publishTimer;
  let publishWarned = false;
  $effect(() => {
    if (phase !== 'ready' || !sync.at) return;
    const items = [...reminders.collect(boardLists, tasks, lay.tasks, habitList, cheers, remindEvents), ...reminders.habitItems(habits, lay.log)];
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
      await loadRemindEvents();
      pullInboxLayer();
      sync.at = new Date();
    } catch (e) {
      sync.err = String(e);
      if (/войдите|sign in|invalid_grant/i.test(sync.err)) { phase = 'setup'; authInfo = await api.auth.status(); }
      else if (!api.isOffline(e)) say('Не удалось обновить: ' + e);
    } finally {
      sync.busy = false;
      if (!sync.err) { syncFlash = true; setTimeout(() => (syncFlash = false), 650); }
    }
  }

  async function start() {
    lay = { ...emptyLayer(), ...(await api.layer.read().catch(() => ({}))) };
    api.setHiddenCalendars(Object.keys(lay.cals ?? {}).filter((id) => lay.cals[id]?.hidden));
    authInfo = await api.auth.status();
    if (!authInfo.has_secret || !authInfo.signed_in) { phase = 'setup'; return; }
    phase = 'ready';
    await refresh();
  }

  // Первый запуск закончен: запоминаем, что показывать (choices = null — это был повторный вход).
  async function setupDone(choices) {
    if (choices) {
      for (const [id, hide] of choices.lists) if (hide || lay.lists?.[id]?.hidden) touch('lists', id, { hidden: hide });
      for (const [id, hide] of choices.cals) if (hide || lay.cals?.[id]?.hidden) touch('cals', id, { hidden: hide });
      touch('settings', 'setup', { done: true });
      await saveLayer();
    }
    choosing = false;
    await start();
  }
  // «Что показывать» из левой колонки — тот же шаг 3 первого запуска.
  let choosing = $state(false);
  const hiddenNow = $derived({
    lists: Object.keys(lay.lists ?? {}).filter((id) => lay.lists[id]?.hidden),
    cals: Object.keys(lay.cals ?? {}).filter((id) => lay.cals[id]?.hidden),
  });

  // ---------- обновление из приложения ----------

  let version = $state('');
  let upd = $state({ found: null, busy: false, progress: 0, err: '', note: '', later: false });
  async function checkUpdate(manual = false) {
    if (upd.busy) return;
    upd.err = '';
    upd.note = manual ? 'Проверяю…' : '';
    try {
      upd.found = await updater.findUpdate();
      upd.later = false;
      upd.note = manual && !upd.found ? 'У тебя последняя версия.' : '';
    } catch (e) {
      upd.note = '';
      if (manual) upd.err = 'Не удалось проверить обновления: ' + e;
    }
  }
  async function installUpdate() {
    upd.busy = true;
    upd.err = '';
    try { await updater.install(upd.found, (p) => (upd.progress = p)); }
    catch (e) { upd.err = 'Не удалось обновиться: ' + e; upd.busy = false; }
  }

  // Нет связи с Google — енот oops и повтор через минуту.
  const offline = $derived(phase === 'ready' && !!sync.err && api.isOffline(sync.err));
  let retryTimer;
  $effect(() => {
    clearTimeout(retryTimer);
    if (offline) retryTimer = setTimeout(refresh, 60e3);
  });

  // ---------- быстрое добавление: кнопка «Создать» и Ctrl+N ----------

  // Экран может сам принять быстрое добавление (на «Сегодня» — строка сверху), иначе открываем окно «Создать».
  let quickLine = null;
  // fromKey — нажали N / Ctrl+N: на «Сегодня» это строка быстрого добавления. Кнопка «Создать» всегда открывает окно.
  function newTask(fromKey = false) {
    if (!boardLists.length || openRef || newList) return;
    if (fromKey && quickLine?.()) return;
    quick = {};
  }
  // Горячие клавиши (список — lib/keys.js и окно «?»).
  const VIEWS = ['today', 'calendar', 'board', 'habits'];
  let helpOpen = $state(false);
  const section = (v) => (['archive', 'templates', 'sphere'].includes(v) ? 'board' : v);
  /** Смена раздела (вкладки, 1–4, Q/E): через View Transitions — новый экран приходит со стороны направления. */
  function go(v) {
    if (v === view) return;
    const d = VIEWS.indexOf(section(v)) - VIEWS.indexOf(section(view));
    if (!d) { view = v; return; }
    motion.viewTransition(() => flushSync(() => (view = v)), d);
  }
  function stepView(dir) {
    const i = VIEWS.indexOf(section(view));
    go(VIEWS[(i + dir + VIEWS.length) % VIEWS.length]);
  }
  // [ / ] — по спискам в том порядке, как они стоят в левой колонке: сферы по порядку, потом «Без сферы».
  // Списки свёрнутых сфер пропускаем (их не видно), кроме открытого сейчас.
  function stepList(dir) {
    const order = [
      ...spheres.flatMap((sp) => sphereLists(sp.id).filter((l) => !lay.settings?.sphereFold?.[sp.id] || l.id === activeId)),
      ...noSphereLists,
    ];
    if (!order.length) return;
    const i = order.findIndex((l) => l.id === activeId);
    const to = i < 0 ? (dir > 0 ? 0 : order.length - 1) : (i + dir + order.length) % order.length;
    activeId = order[to].id;
    boardProject = null;
    tick().then(() => document.querySelector('.side .lst.on')?.scrollIntoView({ block: 'nearest' }));
  }
  async function hotkey(e) {
    if (phase !== 'ready' || choosing) return;
    if ((e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === 'KeyN') { e.preventDefault(); newTask(true); return; }
    if (!keys.plain(e) || keys.typing(e) || helpOpen) return;
    if (e.key === '?' || (e.shiftKey && e.code === 'Slash')) { e.preventDefault(); helpOpen = true; return; }
    if (keys.overlay()) return;
    if (e.shiftKey) {
      // Shift+1…9 на «Привычках» — отметить привычку по порядку.
      const n = /^Digit([1-9])$/.exec(e.code);
      if (n && view === 'habits' && habits[n[1] - 1]) { e.preventDefault(); toggleHabit(habits[n[1] - 1]); }
      return;
    }
    const digit = /^Digit([1-4])$/.exec(e.code);
    if (digit) { go(VIEWS[digit[1] - 1]); return; }
    switch (e.code) {
      case 'KeyQ': stepView(-1); break;
      case 'KeyE': stepView(1); break;
      case 'KeyN': e.preventDefault(); newTask(true); break;
      case 'KeyR': refresh(); break;
      case 'BracketLeft': if (view === 'board' || view === 'archive') stepList(-1); break;
      case 'BracketRight': if (view === 'board' || view === 'archive') stepList(1); break;
      case 'KeyF':
        if (view === 'board' || view === 'archive') {
          e.preventDefault();
          view = 'archive';
          await tick();
          document.querySelector('.search')?.focus();
        }
        break;
    }
  }

  let inboxFocus = $state(0); // просьба «Сегодня» прокрутить к входящим
  function openInbox() { view = 'today'; inboxFocus++; }

  onMount(() => {
    start();
    updater.currentVersion().then((v) => (version = v));
    // Обновления: через полминуты после запуска и дальше раз в 6 часов.
    const updFirst = setTimeout(() => checkUpdate(), 30e3);
    const updTimer = setInterval(() => checkUpdate(), 6 * 3600e3);
    const timer = setInterval(() => { if (phase === 'ready') refresh(); }, 120000);
    const onFocus = () => { if (phase === 'ready' && (!sync.at || Date.now() - sync.at > 30000)) refresh(); };
    window.addEventListener('focus', onFocus);
    return () => { clearInterval(timer); clearTimeout(updFirst); clearInterval(updTimer); window.removeEventListener('focus', onFocus); };
  });

  function replace(listId, updated) {
    tasks[listId] = (tasks[listId] ?? []).map((t) => (t.id === updated.id ? updated : t));
  }

  async function toggle(task, done, listId = openRef?.listId ?? activeId, quiet = false) {
    try {
      const r = await api.completeTask(listId, task.id, done);
      replace(listId, r);
      if (done && !task.parent && !quiet) say(`«${task.title}» выполнено`);
      return true;
    } catch (e) { say('Не удалось отметить: ' + e); return false; }
  }

  async function move(task, col, listId = activeId) {
    // stageAt[колонка] — когда задача пришла на этап (учёт времени в «Конвейере»).
    const stageAt = { ...(lay.tasks?.[task.id]?.stageAt ?? {}), [col]: Date.now() };
    if (col !== 'done') touch('tasks', task.id, { status: col, stageAt });
    else touch('tasks', task.id, { stageAt });
    saveLayer();
    const wasDone = task.status === 'completed';
    if (col === 'done' && !wasDone) await toggle(task, true, listId);
    else if (col !== 'done' && wasDone) await toggle(task, false, listId);
  }

  /** Новая задача на доске — сразу в нужную колонку. */
  async function create(title, col = null, ord = null) {
    if (!activeId) return;
    const listId = activeId;
    try {
      const r = await api.createTask(listId, { title });
      tasks[listId] = [r, ...(tasks[listId] ?? [])];
      if (remindDefault) { touch('tasks', r.id, { remind: remindDefault }); saveLayer(); }
      if (col && col !== templateFor(listId).cols[0].id) { touch('tasks', r.id, { status: col }); saveLayer(); }
      if (boardProject) { touch('tasks', r.id, { project: boardProject }); saveLayer(); }
      if (ord != null) { touch('tasks', r.id, { ord }); saveLayer(); }
    } catch (e) { say('Не удалось создать задачу: ' + e); }
  }

  // ---------- анимации: settings.motion = full | min | off ----------
  const motionPref = $derived(lay.settings?.motion?.v ?? 'full');
  $effect(() => motion.setMotion(motionPref));
  function cycleMotion() {
    const i = motion.LEVELS.findIndex((l) => l.id === motionPref);
    touch('settings', 'motion', { v: motion.LEVELS[(i + 1) % motion.LEVELS.length].id });
    saveLayer();
  }

  // ---------- действия над задачей на доске (меню ⋯, правый клик, клавиши) ----------

  const colName = (listId, col) => templateFor(listId).cols.find((c) => c.id === col)?.name ?? col;
  const findTask = (listId, id) => (tasks[listId] ?? []).find((t) => t.id === id);
  /** Перенос этапа с плашкой «… → Этап · Отменить». */
  async function stageUndo(t, col, listId = activeId) {
    const prev = colOf(t, templateFor(listId).cols);
    if (prev === col) return;
    await move(t, col, listId);
    say(`«${t.title || 'Без названия'}» → ${colName(listId, col)}`, () => { const cur = findTask(listId, t.id); if (cur) move(cur, prev, listId); });
  }
  const pendingDel = new Map(); // id → таймер удаления (6 с на «Отменить»)
  function removeUndo(t, listId = activeId) {
    const before = tasks[listId] ?? [];
    tasks[listId] = before.filter((x) => x.id !== t.id && x.parent !== t.id);
    if (openRef?.id === t.id) openRef = null;
    const timer = setTimeout(async () => {
      pendingDel.delete(t.id);
      try { await api.deleteTask(listId, t.id); }
      catch (e) { tasks[listId] = before; say('Не удалось удалить: ' + e); }
    }, 6000);
    pendingDel.set(t.id, timer);
    say(`«${t.title || 'Без названия'}» удалена`, () => {
      clearTimeout(pendingDel.get(t.id));
      pendingDel.delete(t.id);
      const back = before.filter((x) => x.id === t.id || x.parent === t.id);
      tasks[listId] = [...back, ...(tasks[listId] ?? []).filter((x) => !back.some((b) => b.id === x.id))];
    });
  }
  async function duplicateTask(t, listId = activeId) {
    try {
      const r = await api.createTask(listId, { title: t.title, notes: t.notes, due: t.due });
      tasks[listId] = [r, ...(tasks[listId] ?? [])];
      const L = lay.tasks?.[t.id] ?? {};
      const copy = Object.fromEntries(['type', 'priority', 'status', 'project', 'slot', 'client', 'money'].filter((k) => L[k] != null).map((k) => [k, L[k]]));
      if (Object.keys(copy).length) { touch('tasks', r.id, copy); saveLayer(); }
      say(`Копия «${t.title}» создана`);
    } catch (e) { say('Не удалось дублировать: ' + e); }
  }
  async function moveToList(t, dest, listId = activeId) {
    try {
      await api.moveTask(listId, t.id, dest);
      const [a, b] = await Promise.all([api.listTasks(listId), api.listTasks(dest)]);
      tasks[listId] = a; tasks[dest] = b;
      say(`«${t.title}» → список «${lists.find((l) => l.id === dest)?.title ?? ''}»`);
    } catch (e) { say('Не удалось перенести в другой список: ' + e); }
  }
  const boardAct = {
    open: (t, pick = false) => (openRef = { listId: activeId, id: t.id, pick }),
    rename: (t, title) => renameTask(activeId, t, title),
    notes: async (t, notes) => { try { replace(activeId, await api.patchTask(activeId, t.id, { notes })); } catch (e) { say('Не удалось сохранить заметку: ' + e); } },
    stage: (t, col) => stageUndo(t, col, activeId),
    priority: (t, n) => { touch('tasks', t.id, { priority: n }); saveLayer(); },
    order: (ids) => { ids.forEach((id, i) => touch('tasks', id, { ord: i })); saveLayer(); },
    moveList: (t, dest) => moveToList(t, dest, activeId),
    duplicate: (t) => duplicateTask(t, activeId),
    remove: (t) => removeUndo(t, activeId),
  };
  const boardFold = $derived(lay.settings?.fold?.[activeId] ?? {});
  function foldCol(col, v) {
    const all = lay.settings?.fold ?? {};
    touch('settings', 'fold', { ...all, [activeId]: { ...(all[activeId] ?? {}), [col]: v } });
    saveLayer();
  }

  // ---------- доска: проекты и совет енота ----------

  let boardProject = $state(null);
  const projects = $derived.by(() => {
    const n = {};
    for (const t of tasks[activeId] ?? []) {
      const p = !t.parent && t.status !== 'completed' && lay.tasks?.[t.id]?.project;
      if (p) n[p] = (n[p] ?? 0) + 1;
    }
    return Object.entries(n).sort((a, b) => a[0].localeCompare(b[0], 'ru'));
  });
  // «Начни с …» — первая открытая задача по сроку (без срока — в конце).
  const boardTip = $derived.by(() => {
    const open = (tasks[activeId] ?? []).filter((t) => !t.parent && t.status !== 'completed');
    if (!open.length) return 'Всё разобрано. Новые задачи — кнопкой «+ Добавить задачу» в колонке.';
    // Сначала просроченное, потом приоритет, потом срок (meta.pickNext).
    const today = api.ymd(new Date());
    const first = meta.pickNext(open.map((task) => ({ task })), lay.tasks, today).task;
    const why = meta.nextReason(first, lay.tasks, today, api.humanDue);
    const head = `Начни с «${first.title || 'Без названия'}»${why ? ` — ${why}` : ''}`;
    return `${head}${head.endsWith('.') ? '' : '.'} Остальное подождёт.`; // «18 окт.» уже с точкой
  });

  // ---------- шаблоны досок ----------

  const allTemplates = $derived(templatesFrom(lay));
  const templateUsage = (tid) => boardLists.filter((l) => templateFor(l.id).id === tid).map((l) => l.title);
  /** Открытых задач в колонке шаблона по всем его спискам. */
  function templateCount(tid, colId) {
    let n = 0;
    for (const l of boardLists) {
      const t = templateFor(l.id);
      if (t.id !== tid) continue;
      for (const x of tasks[l.id] ?? []) if (!x.parent && x.status !== 'completed' && colOf(x, t.cols) === colId) n++;
      if (colId === 'done') n += (tasks[l.id] ?? []).filter((x) => !x.parent && x.status === 'completed').length;
    }
    return n;
  }
  /** Сохранить шаблон; removed — удалённые колонки: их задачи переезжают в соседнюю. */
  function saveTemplate(id, draft, removed = []) {
    const moves = Object.fromEntries(removed.map((r) => [r.id, r.to]));
    for (const l of boardLists) {
      if (templateFor(l.id).id !== id) continue;
      for (const t of tasks[l.id] ?? []) {
        let s = lay.tasks?.[t.id]?.status, guard = 0;
        if (!s || !moves[s]) continue;
        while (moves[s] && guard++ < 20) s = moves[s];
        touch('tasks', t.id, { status: s });
      }
    }
    if (isBuiltin(id)) touch('templatesEdit', id, { ...draft, removed: false });
    else touch('templates', id, { ...draft, removed: false });
    saveLayer();
    say(`Шаблон «${draft.name}» сохранён`);
  }
  function resetTemplate(id) { touch('templatesEdit', id, { removed: true }); saveLayer(); say('Шаблон возвращён как был'); }
  function createTemplate() {
    const id = 'tpl' + Date.now().toString(36);
    touch('templates', id, blankTemplate('Свой шаблон'));
    saveLayer();
    return id;
  }
  function deleteTemplate(id, replacement) {
    for (const l of boardLists) if (templateFor(l.id).id === id) touch('lists', l.id, { template: replacement });
    touch('templates', id, { removed: true });
    saveLayer();
    say('Шаблон удалён');
  }

  // ---------- сферы ----------

  let activeSphere = $state(null);
  let sphereEditOpen = $state(false);
  let newListSphere = $state(null); // «＋ Список в сферу» — какую сферу поставить новому списку
  let sphereFilter = $state(''); // чип над «Сегодня» и «Календарём»: '' — все сферы
  const spheres = $derived(spheresFrom(lay));
  const noSphereLists = $derived(boardLists.filter((l) => !sphereOf(l.id, lay)));
  const curSphere = $derived(spheres.find((s) => s.id === activeSphere) ?? null);
  const sphereLists = (sid) => boardLists.filter((l) => sphereOf(l.id, lay) === sid);
  // Списки для «Сегодня» и «Календаря» с учётом чипа сферы.
  const shownLists = $derived(sphereFilter && spheres.some((s) => s.id === sphereFilter) ? sphereLists(sphereFilter) : boardLists);

  function openList(id) { activeId = id; boardProject = null; view = 'board'; }
  function openSphere(id) { activeSphere = id; view = 'sphere'; }
  function foldSphere(id, folded) { touch('settings', 'sphereFold', { ...(lay.settings?.sphereFold ?? {}), [id]: folded }); saveLayer(); }
  function createSphere() {
    const id = 'sph' + Date.now().toString(36);
    const n = spheres.length;
    const icons = Object.keys(SPHERE_ICONS);
    touch('spheres', id, { name: 'Новая сфера', color: SPHERE_COLORS[n % SPHERE_COLORS.length].id, icon: icons[(n + 7) % icons.length], order: Math.max(0, ...spheres.map((s) => s.order ?? 0)) + 1, removed: false });
    saveLayer();
    activeSphere = id;
    view = 'sphere';
    sphereEditOpen = true;
  }
  function updateSphere(patch) { if (!activeSphere) return; touch('spheres', activeSphere, patch); saveLayer(); }
  function toggleListSphere(listId, on) { touch('lists', listId, { sphere: on ? activeSphere : null }); saveLayer(); }
  function deleteSphere() {
    const id = activeSphere;
    for (const l of sphereLists(id)) touch('lists', l.id, { sphere: null });
    touch('spheres', id, { removed: true });
    saveLayer();
    sphereEditOpen = false;
    if (sphereFilter === id) sphereFilter = '';
    view = 'board';
    say('Сфера удалена, списки — в «Без сферы»');
  }
  function newListIn(sid) { newListSphere = sid; newList = true; }

  async function createList(title, template) {
    // «Пустой шаблон» в окне «Новый список»: свой шаблон с именем списка, после создания — его настройка.
    const blank = template === '__blank';
    if (blank) { template = 'tpl' + Date.now().toString(36); touch('templates', template, blankTemplate(title)); }
    try {
      const l = await api.createList(title);
      touch('lists', l.id, newListSphere ? { template, sphere: newListSphere } : { template });
      newListSphere = null;
      saveLayer();
      lists = [...lists, l];
      tasks[l.id] = [];
      activeId = l.id;
      view = blank ? 'templates' : 'board';
      newList = false;
    } catch (e) { say('Не удалось создать список: ' + e); }
  }


  async function save(patch) {
    const { listId, id } = openRef;
    try { replace(listId, await api.patchTask(listId, id, patch)); }
    catch (e) { say('Не удалось сохранить: ' + e); }
  }

  async function renameTask(listId, t, title) {
    try { replace(listId, await api.patchTask(listId, t.id, { title })); }
    catch (e) { say('Не удалось переименовать: ' + e); }
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

  /** Подзадача из «Конвейера»: вложенная задача Google Tasks, помеченная этапом в слое. */
  async function addSubTo(listId, parent, title, stage) {
    try {
      const r = await api.createTask(listId, { title }, parent.id);
      tasks[listId] = [...(tasks[listId] ?? []), r];
      if (stage) { touch('tasks', r.id, { stage }); saveLayer(); }
    } catch (e) { say('Не удалось добавить подзадачу: ' + e); }
  }

  async function addSub(title) {
    const { listId, id } = openRef;
    try {
      const r = await api.createTask(listId, { title }, id);
      tasks[listId] = [...(tasks[listId] ?? []), r];
    } catch (e) { say('Не удалось добавить подзадачу: ' + e); }
  }

  async function editSub(sub, title) {
    const { listId } = openRef;
    try { replace(listId, await api.patchTask(listId, sub.id, { title })); }
    catch (e) { say('Не удалось переименовать подзадачу: ' + e); }
  }

  async function deleteSub(sub) {
    const { listId } = openRef;
    try {
      await api.deleteTask(listId, sub.id);
      tasks[listId] = (tasks[listId] ?? []).filter((t) => t.id !== sub.id);
    } catch (e) { say('Не удалось удалить подзадачу: ' + e); }
  }

  // ---------- входящие от Claude ----------

  // Поля Спутника (тип, проект, теги…), которые прислал чат, переносим в свой слой один раз.
  function pullInboxLayer() {
    const patches = inbox.layerPatches(inboxSt, lay.tasks);
    for (const [id, patch] of patches) {
      // Задачи из бота и чатов Claude тоже получают напоминание по умолчанию.
      if (remindDefault && !lay.tasks?.[id]?.remind) patch.remind = remindDefault;
      touch('tasks', id, patch);
    }
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

  /** Дни со сроками открытых задач (кроме этой) — золотые точки в окне «Когда». */
  function dueDaysExcept(taskId = null) {
    const out = new Set();
    for (const l of boardLists) for (const t of tasks[l.id] ?? []) if (t.id !== taskId && !t.parent && t.due && t.status !== 'completed') out.add(api.dueToYmd(t.due));
    return out;
  }

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

  async function createEvent(p) {
    if (p.remind === undefined) p = { ...p, remind: remindDefaults.event }; // форма календаря — напоминания по умолчанию
    try {
      await api.createEvent(p);
      say(`«${p.title}» — в Google Календаре${p.remind?.length && p.day ? ` · 🔔 ${reminders.leadsText(p.remind, 'event')}` : ''}`);
      loadRemindEvents();
      calReload++;
      if (p.day === api.ymd(new Date())) events = await api.eventsForDay().catch(() => events);
      return true;
    } catch (e) { say('Не удалось создать событие: ' + e); return false; }
  }

  async function createBirthday(p) {
    if (p.remind === undefined) p = { ...p, remind: remindDefaults.birthday };
    try {
      await api.createBirthday(p);
      say(`🎂 ${p.name} — каждый год в Google Календаре${p.remind?.length ? ` · 🔔 ${reminders.leadsText(p.remind, 'birthday')}` : ''}`);
      loadRemindEvents();
      calReload++;
      return true;
    } catch (e) { say('Не удалось добавить день рождения: ' + e); return false; }
  }
  let calReload = $state(0); // календарю — перечитать события

  /** Новая задача; layer — поля Спутника (тип, теги). Возвращает id или false. */
  async function quickCreate({ title, listId, due, slot, layer = null, notes = '' }, quiet = false) {
    try {
      const r = await api.createTask(listId, { title, ...(notes ? { notes } : {}), ...(due ? { due: api.ymdToDue(due) } : {}) });
      tasks[listId] = [r, ...(tasks[listId] ?? [])];
      // remind в layer — выбор в окне «Создать» (null — без напоминания); нет поля — напоминание по умолчанию.
      layer = { ...(layer ?? {}) };
      if (layer.remind === undefined) layer.remind = remindDefault;
      if (!layer.remind) delete layer.remind;
      if (Object.keys(layer).length) touch('tasks', r.id, layer);
      if (slot) setSlot(r.id, slot);
      else if (layer && Object.keys(layer).length) saveLayer();
      const leads = reminders.rulesOf(layer.remind).filter((r) => r.kind === 'lead').map((r) => r.min);
      const bell = leads.length && due ? ` · 🔔 ${reminders.leadsText(leads)}` : '';
      if (!quiet) say(`«${title}» — добавлено${due ? ` на ${whenText(due, slot).date.toLowerCase()}${slot ? `, ${slot.s}` : ''}` : ' на доску'}${bell}`);
      return r.id;
    } catch (e) { say('Не удалось создать задачу: ' + e); return false; }
  }

  // ---------- привычки ----------

  function toggleHabit(h) {
    const day = api.ymd(new Date());
    const done = !isDone(lay.log, h.id, day);
    touch('log', logKey(h.id, day), { done, rest: false });
    if (done) {
      const n = stats(h, lay.log).streak;
      if (MILESTONES.includes(n) && lay.habits?.[h.id]?.cheer?.key !== `${n}|${day}`) celebrate(h, n, day);
    } else if (cele?.id === h.id) cele = null;
    saveLayer();
  }

  // Веха серии (7 · 21 · 50 · 100): праздник на экране, уведомление Windows и сообщение бота (через файл напоминаний).
  let cele = $state(null); // { id, name, n }
  async function celebrate(h, n, day) {
    const forms = !h.days?.length || h.days.length === 7 ? ['день', 'дня', 'дней'] : ['занятие', 'занятия', 'занятий'];
    const text = `${h.name} — ${n} ${plural(n, forms)} подряд!`;
    cele = { id: h.id, name: h.name, n, text };
    touch('habits', h.id, { cheer: { key: `${n}|${day}`, n, text, at: new Date().toISOString() } });
    if (view !== 'habits') say(`🎉 Новая веха: ${text}`);
    try {
      let ok = await notify.isPermissionGranted();
      if (!ok) ok = (await notify.requestPermission()) === 'granted';
      if (ok) notify.sendNotification({ title: 'Спутник · новая веха', body: `🎉 ${text} Енот празднует.` });
    } catch { /* уведомления недоступны — праздник на экране и в боте всё равно будет */ }
  }
  const cheers = $derived(habits.flatMap((h) => {
    const c = lay.habits?.[h.id]?.cheer;
    return c?.at && Date.now() - new Date(c.at).getTime() < 864e5 ? [{ habit: h, ...c }] : [];
  }));

  async function createHabit(name, days, time = null) {
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
      touch('habits', t.id, { days, time, createdAt: api.ymd(new Date()) });
      saveLayer();
    } catch (e) { say('Не удалось добавить привычку: ' + e); }
  }

  async function updateHabit(id, { name, days, time = null }) {
    touch('habits', id, { days, time });
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
  <Setup status={authInfo} firstRun={!lay.settings?.setup?.done} onready={setupDone} onerror={say} />
{:else if choosing}
  <Setup status={authInfo} firstRun hidden={hiddenNow} onready={setupDone} onerror={say} oncancel={() => (choosing = false)} />
{:else}
  <div class="shell">
    <!-- Шапка — она же полоса окна: тянуть за пустое место, двойной клик — развернуть. -->
    <nav class="sp-tabs" aria-label="Разделы" data-tauri-drag-region>
      <Brand />
      <button class="sp-tab" role="tab" aria-selected={view === 'today'} title="Клавиша 1 · Q / E — соседний раздел" onclick={() => go('today')}>Сегодня <span class="n">· {todayCount}</span>{#if view === 'today'}<span class="ink"></span>{/if}</button>
      <button class="sp-tab" role="tab" aria-selected={view === 'calendar'} title="Клавиша 2 · Q / E — соседний раздел" onclick={() => go('calendar')}>Календарь{#if view === 'calendar'}<span class="ink"></span>{/if}</button>
      <button class="sp-tab" role="tab" aria-selected={['board', 'archive', 'templates', 'sphere'].includes(view)} title="Клавиша 3 · Q / E — соседний раздел" onclick={() => go('board')}>Доска{#if section(view) === 'board'}<span class="ink"></span>{/if}</button>
      <button class="sp-tab" role="tab" aria-selected={view === 'habits'} title="Клавиша 4 · Q / E — соседний раздел" onclick={() => go('habits')}>Привычки{#if habitsLeft}<span class="n"> · {habitsLeft}</span>{/if}{#if view === 'habits'}<span class="ink"></span>{/if}</button>
      <div class="right" data-tauri-drag-region>
        <button class="sync" class:busy={sync.busy} class:flash={syncFlash} class:err={!!sync.err} type="button" onclick={refresh} title="Обновить сейчас">
          <span class="dot"></span>{syncLabel}
        </button>
        {#if inboxItems.length}
          <button class="sp-btn sp-btn-ghost inbox-btn" type="button" title="Входящие от Claude — разобрать на «Сегодня»"
            aria-label="Входящие от Claude, {inboxItems.length}" onclick={openInbox}>
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 13h4l2 3h4l2-3h4M5 5h14l1 8v6H4v-6z" /></svg>
            <span class="n">{inboxItems.length}</span>
          </button>
        {/if}
        <button class="sp-btn sp-btn-ghost keys-btn" type="button" title="Горячие клавиши (?)" aria-label="Горячие клавиши" onclick={() => (helpOpen = true)}>?</button>
        <button class="sp-btn sp-btn-primary" type="button" style="min-height: 32px" disabled={!boardLists.length} title={boardLists.length ? 'Новая задача, событие или день рождения (N или Ctrl+N)' : 'Сначала создай список на доске'} onclick={() => newTask()}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>Создать
        </button>
      </div>
      <WinControls />
    </nav>

    {#if (upd.found && !upd.later) || upd.err}
      <div class="upd" role="status">
        {#if upd.err}
          <p class="err">{upd.err}</p>
          <button class="sp-btn sp-btn-ghost" type="button" style="min-height: 30px" onclick={() => (upd.err = '')}>Скрыть</button>
        {:else if upd.busy}
          <p><b>Ставлю Спутник {upd.found.version}…</b> Окно установки закроется само, приложение перезапустится.</p>
          <span class="upd-bar"><span style="width: {Math.round(upd.progress * 100)}%"></span></span>
        {:else}
          <p><b>Вышла версия {upd.found.version}.</b> Обновление займёт меньше минуты, данные никуда не денутся.</p>
          <button class="sp-btn sp-btn-primary" type="button" style="min-height: 30px" onclick={installUpdate}>Обновить</button>
          <button class="sp-btn sp-btn-ghost" type="button" style="min-height: 30px" onclick={() => (upd.later = true)}>Позже</button>
        {/if}
      </div>
    {/if}

    {#if offline}
      <div class="offline" role="alert">
        <Coon pose="oops" size={48} />
        <p><b>Нет связи с Google.</b> Попробую снова через минуту — ничего не потеряется, отметки сохранены на этом компьютере.</p>
        <button class="sp-btn" type="button" style="min-height: 30px" disabled={sync.busy} onclick={refresh}>Повторить сейчас</button>
      </div>
    {/if}

    <div class="body">
      {#if view === 'board' || view === 'archive' || view === 'sphere'}
      <aside class="side">
        <!-- Сферы: значок, название, открытых задач; внутри — списки с меткой шаблона. Без сферы — внизу. -->
        <div class="sph-side">
          <h4>Сферы</h4>
          {#snippet listRow(l)}
            <button class="lst" class:on={(view === 'board' || view === 'archive') && l.id === activeId} type="button" onclick={() => openList(l.id)}>
              <span class="lt">{l.title}</span><span class="n">{openCount(l)}</span>
            </button>
          {/snippet}
          {#each spheres as sp (sp.id)}
            {@const folded = !!lay.settings?.sphereFold?.[sp.id]}
            {@const sl = boardLists.filter((l) => sphereOf(l.id, lay) === sp.id)}
            <div class="sph-row">
              <button type="button" class="chev" aria-label={folded ? 'Развернуть сферу' : 'Свернуть сферу'} aria-expanded={!folded} onclick={() => foldSphere(sp.id, !folded)}>
                <svg viewBox="0 0 24 24" aria-hidden="true" class:closed={folded}><path d="M6 9l6 6 6-6" /></svg>
              </button>
              <button type="button" class="sph" aria-current={view === 'sphere' && activeSphere === sp.id} onclick={() => openSphere(sp.id)}>
                <SphereIcon sphere={sp} size={26} /><span class="sn">{sp.name}</span><span class="n">{sl.reduce((n, l) => n + openCount(l), 0)}</span>
              </button>
            </div>
            {#if !folded}{#each sl as l (l.id)}{@render listRow(l)}{/each}{/if}
          {/each}
          {#if noSphereLists.length}
            {#if spheres.length}<p class="nos">Без сферы</p>{/if}
            {#each noSphereLists as l (l.id)}{@render listRow(l)}{/each}
          {/if}
          {#if !boardLists.length}<p class="empty">Списков пока нет.</p>{/if}
          <div class="side-add">
            <button class="item add" type="button" onclick={() => newListIn(null)}><span>+ Новый список</span></button>
            <button class="item add" type="button" onclick={createSphere}><span>＋ Сфера</span></button>
          </div>
        </div>
        {#if projects.length && view === 'board'}
          <div>
            <h4>Проекты</h4>
            {#each projects as [p, n] (p)}
              <button class="item" class:on={boardProject === p} type="button" aria-pressed={boardProject === p} onclick={() => (boardProject = boardProject === p ? null : p)}>
                <span>{p}</span><span class="n">{n}</span>
              </button>
            {/each}
          </div>
        {/if}
        <div class="side-nav">
          <button type="button" class="lst" onclick={() => (view = 'templates')}>Шаблоны досок →</button>
          <button type="button" class="lst" class:on={view === 'archive'} onclick={() => (view = 'archive')}>Архив</button>
        </div>
        {#if view === 'board' && activeList}
          <div class="side-tip">
            <Coon pose="think" size={96} />
            <p>{boardTip}</p>
          </div>
        {/if}
        <div class="foot">
          <span>Спутник {version}</span>
          <button type="button" disabled={upd.busy} onclick={() => checkUpdate(true)}>Проверить обновления</button>
          {#if upd.note}<span>{upd.note}</span>{/if}
          <button type="button" onclick={() => (choosing = true)}>Что показывать</button>
          <button type="button" title="Анимации интерфейса: полные / минимум / выкл" onclick={cycleMotion}>Анимации: {motion.LEVELS.find((l) => l.id === motionPref)?.name}</button>
          <button type="button" onclick={logout}>Выйти из Google</button>
        </div>
      </aside>
      {/if}

      <div class="main">
        {#snippet sphFilter()}<SphereFilter {spheres} value={sphereFilter} onchange={(v) => (sphereFilter = v)} />{/snippet}
        {#if view === 'today'}
          <Today lists={shownLists} tasksByList={tasks} {events} layTasks={lay.tasks} layLists={lay.lists} log={lay.log} {habits}
            {inboxItems} inboxOn={!!inboxSt} {inboxFocus} {typeOf}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            ontoggle={(t, d, listId, quiet) => toggle(t, d, listId, quiet)}
            oncreate={(p, loud = false) => quickCreate(p, !loud)} ontogglehabit={toggleHabit}
            onaccept={acceptInbox} onreject={rejectInbox}
            onregister={(fn) => (quickLine = fn)}
            onhabits={() => (view = 'habits')} oncalendar={() => (view = 'calendar')} filter={sphFilter} />
        {:else if view === 'calendar'}
          <Calendar lists={shownLists} tasksByList={tasks} layTasks={lay.tasks} log={lay.log} {habits} {typeOf}
            loadEvents={api.eventsRange} syncAt={sync.at} reloadKey={calReload} oncreatebirthday={createBirthday}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            ontoggle={(t, d, listId) => toggle(t, d, listId)}
            ontogglehabit={toggleHabit}
            onschedule={schedule}
            oncreatetask={(p) => quickCreate(p)}
            oncreateevent={createEvent} filter={sphFilter} />
        {:else if view === 'habits'}
          <Habits {habits} log={lay.log} {cele} ontoggle={toggleHabit} onclosecele={() => (cele = null)}
            oncreate={createHabit} onupdate={updateHabit} ondelete={deleteHabit} />
        {:else if view === 'templates'}
          <Templates templates={allTemplates} usage={templateUsage} count={templateCount} current={activeList ? templateFor(activeId).id : null}
            onsave={saveTemplate} onreset={resetTemplate} oncreate={createTemplate} ondelete={deleteTemplate} onback={() => (view = 'board')} />
        {:else if view === 'sphere' && curSphere}
          <SphereView sphere={curSphere} lists={sphereLists(curSphere.id)} tasksByList={tasks} {templateFor} {colOf}
            onedit={() => (sphereEditOpen = true)} onaddlist={() => newListIn(curSphere.id)}
            onopenlist={openList} onopentask={(t, listId) => (openRef = { listId, id: t.id })} />
        {:else if view === 'archive'}
          <Archive lists={boardLists} tasksByList={tasks} {activeId}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            onrestore={(t, listId) => move(t, templateFor(listId).cols[0].id, listId)}
            onback={() => (view = 'board')} />
        {:else if activeList}
          {#key activeId}
          <div class="board-swap" in:motion.fade={{ duration: 160 }}>
          <Board list={activeList} tasks={tasks[activeId] ?? []} template={templateFor(activeId)} {colOf} {remindOf} {typeOf}
            view={viewFor(activeId)} onview={(v) => { touch('lists', activeId, { view: v }); saveLayer(); }}
            ontoggle={(t, d) => toggle(t, d, activeId, true)}
            onaddsub={(t, title, stage) => addSubTo(activeId, t, title, stage)}
            act={boardAct} lists={boardLists.filter((l) => l.id !== activeId)} sphereName={spheres.find((s) => s.id === sphereOf(activeId, lay))?.name ?? ''} fold={boardFold} onfold={foldCol}
            onedittemplate={() => (view = 'templates')}
            layTasks={lay.tasks} project={boardProject}
            oncreate={create}
            onarchive={() => (view = 'archive')} />
          </div>
          {/key}
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
      type={lay.tasks?.[openTask.id]?.type ?? null} priority={lay.tasks?.[openTask.id]?.priority ?? null}
      pick={!!openRef.pick} fields={templateFor(openRef.listId).fields} client={lay.tasks?.[openTask.id]?.client ?? ''} money={lay.tasks?.[openTask.id]?.money ?? ''}
      onlayer={(p) => { touch('tasks', openTask.id, p); saveLayer(); }}
      dueDays={dueDaysExcept(openTask.id)} loadEvents={api.eventsRange}
      onclose={() => (openRef = null)}
      onsave={save}
      onstatus={(s) => move(openTask, s, openRef.listId)}
      ondelete={remove}
      ontoggle={(t, d) => toggle(t, d, openRef.listId)}
      onaddsub={addSub} onsubedit={editSub} onsubdelete={deleteSub} />
  {/if}

  {#if quick}
    <QuickAdd lists={boardLists} listId={boardLists.some((l) => l.id === activeId) ? activeId : null}
      day={quick.day ?? ''} s={quick.s ?? ''} e={quick.e ?? ''}
      dueDays={dueDaysExcept()} loadEvents={api.eventsRange}
      {remindDefaults} onremindDefault={setRemindDefault}
      oncreate={quickCreate} oncreateevent={createEvent} oncreatebirthday={createBirthday} onclose={() => (quick = null)} />
  {/if}

  {#if helpOpen}
    <KeyHelp onclose={() => (helpOpen = false)} />
  {/if}

  {#if sphereEditOpen && curSphere && view === 'sphere'}
    <SphereEdit sphere={curSphere} lists={boardLists} inSphere={(id) => sphereOf(id, lay) === curSphere.id}
      whereOf={(id) => spheres.find((s) => s.id === sphereOf(id, lay))?.name ?? ''}
      onchange={updateSphere} ontogglelist={toggleListSphere} ondelete={deleteSphere} onclose={() => (sphereEditOpen = false)} />
  {/if}

  {#if newList}
    <NewList templates={allTemplates} oncreate={createList} onclose={() => { newList = false; newListSphere = null; }} />
  {/if}
{/if}

{#if toast}
  <div class="toast" role="status" onmouseenter={pauseToast} onmouseleave={resumeToast}>
    {#key toastN}<span class="timer" aria-hidden="true"></span>{/key}
    <span>{toast}</span>
    {#if toastUndo}<button type="button" class="undo" onclick={undoToast}>Отменить</button>{/if}
    <button type="button" onclick={() => { toast = ''; toastUndo = null; }}>Скрыть</button>
  </div>
{/if}
