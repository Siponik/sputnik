<script>
  import { onMount, tick } from 'svelte';
  import * as keys from './lib/keys.js';
  import KeyHelp from './lib/KeyHelp.svelte';
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
  import { templateOf, isHabitList, HABITS } from './lib/templates.js';
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

  function emptyLayer() { return { version: 1, tasks: {}, lists: {}, habits: {}, log: {}, cals: {}, settings: {} }; }

  // Скрытые на первом запуске списки (lists[id].hidden) на доске и в «Сегодня» не показываем.
  const boardLists = $derived(lists.filter((l) => !isHabitList(l, lay) && !lay.lists?.[l.id]?.hidden));
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
        .map((t) => ({ id: t.id, name: t.title || 'Без названия', days: lay.habits?.[t.id]?.days ?? [], time: lay.habits?.[t.id]?.time ?? null, createdAt: lay.habits?.[t.id]?.createdAt }))
        // привычки со временем — по времени, без времени — после них, в порядке списка
        .sort((a, b) => (a.time ?? '99').localeCompare(b.time ?? '99'))
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
    const items = reminders.collect(boardLists, tasks, lay.tasks, habitList, cheers);
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
      else if (!api.isOffline(e)) say('Не удалось обновить: ' + e);
    } finally {
      sync.busy = false;
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
  function stepView(dir) {
    const i = VIEWS.indexOf(view === 'archive' ? 'board' : view);
    view = VIEWS[(i + dir + VIEWS.length) % VIEWS.length];
  }
  function stepList(dir) {
    const i = boardLists.findIndex((l) => l.id === activeId);
    if (i < 0 || !boardLists.length) return;
    activeId = boardLists[(i + dir + boardLists.length) % boardLists.length].id;
    boardProject = null;
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
    if (digit) { view = VIEWS[digit[1] - 1]; return; }
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
    if (col !== 'done') { touch('tasks', task.id, { status: col }); saveLayer(); }
    const wasDone = task.status === 'completed';
    if (col === 'done' && !wasDone) await toggle(task, true, listId);
    else if (col !== 'done' && wasDone) await toggle(task, false, listId);
  }

  /** Новая задача на доске — сразу в нужную колонку. */
  async function create(title, col = null) {
    if (!activeId) return;
    const listId = activeId;
    try {
      const r = await api.createTask(listId, { title });
      tasks[listId] = [r, ...(tasks[listId] ?? [])];
      if (col && col !== templateFor(listId).cols[0].id) { touch('tasks', r.id, { status: col }); saveLayer(); }
      if (boardProject) { touch('tasks', r.id, { project: boardProject }); saveLayer(); }
    } catch (e) { say('Не удалось создать задачу: ' + e); }
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
    try {
      await api.createEvent(p);
      say(`«${p.title}» — в Google Календаре`);
      calReload++;
      if (p.day === api.ymd(new Date())) events = await api.eventsForDay().catch(() => events);
      return true;
    } catch (e) { say('Не удалось создать событие: ' + e); return false; }
  }

  async function createBirthday(p) {
    try {
      await api.createBirthday(p);
      say(`🎂 ${p.name} — каждый год в Google Календаре`);
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
      if (layer && Object.keys(layer).length) touch('tasks', r.id, layer);
      if (slot) setSlot(r.id, slot);
      else if (layer && Object.keys(layer).length) saveLayer();
      if (!quiet) say(`«${title}» — добавлено${due ? ` на ${whenText(due, slot).date.toLowerCase()}${slot ? `, ${slot.s}` : ''}` : ' на доску'}`);
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
    <nav class="sp-tabs" aria-label="Разделы">
      <Brand />
      <button class="sp-tab" role="tab" aria-selected={view === 'today'} title="Клавиша 1 · Q / E — соседний раздел" onclick={() => (view = 'today')}>Сегодня <span class="n">· {todayCount}</span></button>
      <button class="sp-tab" role="tab" aria-selected={view === 'calendar'} title="Клавиша 2 · Q / E — соседний раздел" onclick={() => (view = 'calendar')}>Календарь</button>
      <button class="sp-tab" role="tab" aria-selected={view === 'board' || view === 'archive'} title="Клавиша 3 · Q / E — соседний раздел" onclick={() => (view = 'board')}>Доска</button>
      <button class="sp-tab" role="tab" aria-selected={view === 'habits'} title="Клавиша 4 · Q / E — соседний раздел" onclick={() => (view = 'habits')}>Привычки{#if habitsLeft}<span class="n"> · {habitsLeft}</span>{/if}</button>
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
        <button class="sp-btn sp-btn-ghost keys-btn" type="button" title="Горячие клавиши (?)" aria-label="Горячие клавиши" onclick={() => (helpOpen = true)}>?</button>
        <button class="sp-btn sp-btn-primary" type="button" style="min-height: 32px" disabled={!boardLists.length} title={boardLists.length ? 'Новая задача, событие или день рождения (N или Ctrl+N)' : 'Сначала создай список на доске'} onclick={() => newTask()}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>Создать
        </button>
      </div>
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
      {#if view === 'board' || view === 'archive'}
      <aside class="side">
        <div>
          <h4>Сферы</h4>
          {#each boardLists as l (l.id)}
            <button class="item" class:on={(view === 'board' || view === 'archive') && l.id === activeId} type="button" onclick={() => { activeId = l.id; boardProject = null; view = 'board'; }}>
              <span>{l.title}</span><span class="n">{openCount(l)}</span>
            </button>
          {:else}
            <p class="empty">Списков пока нет.</p>
          {/each}
          <button class="item add" type="button" onclick={() => (newList = true)}><span>+ Новый список</span></button>
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
          <button type="button" onclick={logout}>Выйти из Google</button>
        </div>
      </aside>
      {/if}

      <div class="main">
        {#if view === 'today'}
          <Today lists={boardLists} tasksByList={tasks} {events} layTasks={lay.tasks} layLists={lay.lists} log={lay.log} {habits}
            {inboxItems} inboxOn={!!inboxSt} {inboxFocus} {typeOf}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            ontoggle={(t, d, listId, quiet) => toggle(t, d, listId, quiet)}
            oncreate={(p, loud = false) => quickCreate(p, !loud)} ontogglehabit={toggleHabit}
            onaccept={acceptInbox} onreject={rejectInbox}
            onregister={(fn) => (quickLine = fn)}
            onhabits={() => (view = 'habits')} oncalendar={() => (view = 'calendar')} />
        {:else if view === 'calendar'}
          <Calendar lists={boardLists} tasksByList={tasks} layTasks={lay.tasks} log={lay.log} {habits} {typeOf}
            loadEvents={api.eventsRange} syncAt={sync.at} reloadKey={calReload} oncreatebirthday={createBirthday}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            ontoggle={(t, d, listId) => toggle(t, d, listId)}
            ontogglehabit={toggleHabit}
            onschedule={schedule}
            oncreatetask={(p) => quickCreate(p)}
            oncreateevent={createEvent} />
        {:else if view === 'habits'}
          <Habits {habits} log={lay.log} {cele} ontoggle={toggleHabit} onclosecele={() => (cele = null)}
            oncreate={createHabit} onupdate={updateHabit} ondelete={deleteHabit} />
        {:else if view === 'archive'}
          <Archive lists={boardLists} tasksByList={tasks} {activeId}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            onrestore={(t, listId) => move(t, templateFor(listId).cols[0].id, listId)}
            onback={() => (view = 'board')} />
        {:else if activeList}
          <Board list={activeList} tasks={tasks[activeId] ?? []} template={templateFor(activeId)} {colOf} {remindOf} {typeOf}
            layTasks={lay.tasks} project={boardProject}
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
      type={lay.tasks?.[openTask.id]?.type ?? null} priority={lay.tasks?.[openTask.id]?.priority ?? null}
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
      oncreate={quickCreate} oncreateevent={createEvent} oncreatebirthday={createBirthday} onclose={() => (quick = null)} />
  {/if}

  {#if helpOpen}
    <KeyHelp onclose={() => (helpOpen = false)} />
  {/if}

  {#if newList}
    <NewList oncreate={createList} onclose={() => (newList = false)} />
  {/if}
{/if}

{#if toast}
  <div class="toast" role="status"><span>{toast}</span><button type="button" onclick={() => (toast = '')}>Скрыть</button></div>
{/if}
