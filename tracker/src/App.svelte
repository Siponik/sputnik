<script>
  import { onMount, tick, flushSync } from 'svelte';
  import * as motion from './lib/motion.js';
  import * as keys from './lib/keys.js';
  import KeyHelp from './lib/KeyHelp.svelte';
  import Search from './lib/Search.svelte';
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
  import Create from './lib/Create.svelte';
  import Coon from './lib/Coon.svelte';
  import * as worktime from './lib/timer.js';
  import * as api from './lib/api.js';
  import { templateOf, templatesFrom, isBuiltin, blankTemplate, shortName, isHabitList, HABITS } from './lib/templates.js';
  import Templates from './lib/Templates.svelte';
  import { spheresFrom, sphereOf, sphereColor, SPHERE_COLORS, SPHERE_ICONS } from './lib/spheres.js';
  import SphereIcon from './lib/SphereIcon.svelte';
  import SphereView from './lib/SphereView.svelte';
  import SphereEdit from './lib/SphereEdit.svelte';
  import SphereFilter from './lib/SphereFilter.svelte';
  import Side from './lib/Side.svelte';
  import Settings from './lib/Settings.svelte';
  import ItemMenu from './lib/ItemMenu.svelte';
  import ConfirmDelete from './lib/ConfirmDelete.svelte';
  import { isDone, logKey, stats, plural, MILESTONES } from './lib/habits.js';
  import * as notify from '@tauri-apps/plugin-notification';
  import * as updater from './lib/updater.js';
  import * as meta from './lib/meta.js';
  import { whenText } from './lib/when.js';
  import * as repeat from './lib/repeat.js';
  import * as fresh from './lib/fresh.js';
  import { findDupes } from './lib/dupes.js';
  import * as stickers from './lib/stickers.js';
  import * as reminders from './lib/reminders.js';
  import * as sharedbot from './lib/sharedbot.js';
  import { typeOfTemplate } from './lib/calendar.js';
  import * as inbox from './lib/inbox.js';
  import * as layerSync from './lib/layer.js';
  import * as shell from './lib/shell.js';
  import StatusPop from './lib/StatusPop.svelte';
  import Popover from './lib/Popover.svelte';

  let phase = $state('loading'); // loading | setup | ready
  let authInfo = $state({ has_secret: false, signed_in: false });
  let view = $state('today'); // today | calendar | board | archive | habits | templates | sphere
  let lists = $state([]);
  let activeId = $state(null);
  let tasks = $state({}); // listId → задачи (вместе с подзадачами)
  let lay = $state(layerSync.emptyLayer()); // слой Спутника: то, чего нет в Google
  let events = $state([]);
  let inboxSt = $state(null); // статус «Входящих от Claude»
  let openRef = $state(null); // { listId, id }
  let newList = $state(false);
  let newListName = $state(''); // название из окна «Создать»
  let quick = $state(null); // окно «Создать»: { day, s, e } — что подставить
  let sync = $state({ busy: false, err: '', at: null });
  let toast = $state('');
  let toastLabel = $state('Отменить');
  let syncFlash = $state(false); // короткая вспышка точки синхронизации по окончании обмена
  let toastTimer;

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
  /** Плашка внизу; undo — действие кнопки (по умолчанию «Отменить», label — другая подпись, например «Открыть»). */
  function say(msg, undo = null, label = 'Отменить') {
    toast = msg;
    toastUndo = undo;
    toastLabel = label;
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
  let remStat = $state({ at: null, n: 0, err: '' }); // файл напоминаний — для «Состояния»
  const ownBot = $derived(shell.ownBot(lay.settings, inboxSt)); // свой бот на Apps Script — только у владельца
  const remView = $derived(ownBot.on ? remStat : { shared: true, linked: !!lay.settings?.tgbot?.key, err: tgStat.err });
  let publishWarned = false;
  $effect(() => {
    if (phase !== 'ready' || !sync.at) return;
    const items = [...reminders.collect(boardLists, tasks, lay.tasks, habitList, cheers, remindEvents), ...reminders.habitItems(habits, lay.log), ...(botTest ? [botTest] : [])];
    const tgKey = lay.settings?.tgbot?.key;
    const own = ownBot;
    const week = tgKey ? sharedbot.snapshot(boardLists, tasks, lay.tasks) : null;
    clearTimeout(publishTimer);
    publishTimer = setTimeout(() => {
      // Общий бот (lib/sharedbot.js) — те же напоминания, кроме проверки личного бота, и задачи на неделю для /today.
      if (tgKey) sharedbot.push(tgKey, items.filter((x) => x.kind !== 'test'), week).then(() => (tgStat = { ...tgStat, err: '' }))
        .catch((e) => (tgStat = { ...tgStat, err: String(e.message ?? e), unlinked: !!e.unlinked }));
      // Файл на Drive читает только свой бот владельца (Apps Script). Выключили — один раз очищаем файл, чтобы скрипт замолчал.
      if (!own.on && !remStat.at) return;
      reminders.publish(own.on ? items : [], { task: remindDefaults.task }).then((wrote) => {
        if (wrote || !remStat.at) remStat = { at: new Date(), n: items.length, err: '' };
      }).catch((e) => {
        remStat = { ...remStat, err: 'не удалось передать: ' + e };
        // Нет связи — об этом уже говорит полоса под шапкой; ошибку видно в «Состоянии».
        if (!publishWarned && !api.isOffline(String(e))) { publishWarned = true; say('Не удалось передать напоминания на Google Drive: ' + e); }
      });
    }, 3000);
  });

  async function saveLayer() {
    try { await api.layer.write($state.snapshot(lay)); } catch (e) { say('Не удалось сохранить: ' + e); }
    clearTimeout(cloudTimer);
    cloudTimer = setTimeout(syncLayer, 4000);
  }

  // ---------- слой между компьютерами (lib/layer.js) ----------
  // Копия слоя — в скрытой папке приложения на Google Drive. Сливаем при каждой синхронизации (раз в 2 мин и по фокусу)
  // и через 4 с после изменения. state: idle | busy | ok | login (нет права — войти заново) | err.
  let cloud = $state({ state: 'idle', at: null, err: '' });
  let cloudTimer;
  let cloudRun = null, cloudAgain = false;
  async function syncLayer() {
    if (phase !== 'ready' || cloud.state === 'login') return;
    if (cloudRun) { cloudAgain = true; return cloudRun; }
    cloudRun = (async () => {
      cloud.state = 'busy';
      try {
        const remote = await layerSync.pull();
        // Сливаем с тем, что на экране сейчас: правки, сделанные, пока шёл запрос, не теряются.
        const { merged, localChanged, remoteChanged } = layerSync.merge($state.snapshot(lay), remote);
        if (localChanged) {
          lay = merged;
          api.setHiddenCalendars(Object.keys(lay.cals ?? {}).filter((id) => lay.cals[id]?.hidden));
          await api.layer.write(merged).catch((e) => say('Не удалось сохранить: ' + e));
        }
        if (remoteChanged) await layerSync.push(merged);
        cloud = { state: 'ok', at: new Date(), err: '' };
      } catch (e) {
        if (layerSync.needsLogin(e)) {
          cloud = { state: 'login', at: null, err: String(e) };
          say('Чтобы доска, привычки и настройки совпадали на всех компьютерах, войди в Google заново: «Состояние» в шапке → «Войти».');
        } else cloud = { ...cloud, state: 'err', err: String(e) };
      } finally {
        cloudRun = null;
        if (cloudAgain) { cloudAgain = false; setTimeout(syncLayer, 0); }
      }
    })();
    return cloudRun;
  }
  // Вход с новым правом drive.appdata (кто входил до синхронизации).
  async function cloudLogin() {
    try {
      await api.auth.login();
      cloud = { state: 'idle', at: null, err: '' };
      await syncLayer();
      if (cloud.state === 'ok') say('Готово: слой Спутника теперь общий для всех компьютеров.');
    } catch (e) { say('Не удалось войти: ' + e); }
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
      const t0 = Date.now();
      const before = Object.fromEntries(Object.entries(tasks).map(([id, ts]) => [id, new Set(ts.map((t) => t.id))]));
      const ls = await api.listLists();
      const all = await Promise.all(ls.map((l) => api.listTasks(l.id)));
      // Слой с других компьютеров — до того, как показать задачи: иначе новая задача с другого ПК сначала
      // мелькала в «Разное» и без полей, а повтор, уже продолженный там (repeatNext), продолжался второй раз.
      await syncLayer();
      lists = ls;
      // Правки, сделанные пока шёл ответ (отметка, создание, удаление), ответ не затирает.
      tasks = Object.fromEntries(ls.map((l, i) => [l.id, fresh.keepLocal(all[i], tasks[l.id], before[l.id], touchedAt, t0)]));
      if (!activeId || !boardLists.some((l) => l.id === activeId)) activeId = boardLists[0]?.id ?? null;
      // Первый обмен слоем (выше) — до того, как трекер сам что-то в него допишет (дата начала привычек, поля
      // из «Входящих»): иначе на втором компьютере свежие, но пустые записи перебили бы настоящие с первого.
      ensureHabitMeta();
      events = await api.eventsForDay().catch(() => []);
      inboxSt = await api.inboxStatus().catch(() => inboxSt);
      await loadRemindEvents();
      pullInboxLayer();
      await rollRepeats();
      await pullTg();
      sync.at = new Date();
      syncLayer();
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
    lay = { ...layerSync.emptyLayer(), ...(await api.layer.read().catch(() => ({}))) };
    api.setHiddenCalendars(Object.keys(lay.cals ?? {}).filter((id) => lay.cals[id]?.hidden));
    authInfo = await api.auth.status();
    if (!authInfo.has_secret || !authInfo.signed_in) { phase = 'setup'; return; }
    let last = null;
    try { last = localStorage.getItem('sp.lastView'); } catch {}
    if (phase !== 'ready') view = shell.startView(lay.settings?.start?.v, last);
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
  let upd = $state({ found: null, busy: false, progress: 0, err: '', fail: '', note: '', checkedAt: null });
  async function checkUpdate(manual = false) {
    if (upd.busy) return;
    upd.err = '';
    upd.note = manual ? 'Проверяю…' : '';
    try {
      upd.found = await updater.findUpdate(!!lay.settings?.update?.beta); // бета-канал — только у владельца
      upd.checkedAt = new Date();
      upd.note = manual && !upd.found ? 'У тебя последняя версия.' : '';
    } catch (e) {
      upd.note = '';
      if (manual) upd.err = 'Не удалось проверить обновления: ' + e;
    }
  }
  async function installUpdate() {
    if (!upd.found || upd.busy) return;
    upd.busy = true;
    upd.err = ''; upd.fail = '';
    upd.progress = 0;
    try { await updater.install(upd.found, (p) => (upd.progress = p)); }
    catch (e) { upd.fail = 'Не удалось обновиться: ' + e; upd.busy = false; }
  }
  // Чип «✦ Версия …» в шапке: «Вечером» — напомнить в 20:00, «Пропустить» — не показывать для этой версии
  // (точка «версия» в «Состоянии» остаётся). settings.update = { skip, remindAt, auto, night }.
  const updPref = $derived(lay.settings?.update ?? {});
  let nowMin = $state(Date.now()); // раз в минуту: «Вечером» наступило, ночная установка
  const updChip = $derived(upd.busy || shell.showUpdChip(upd.found, updPref, nowMin));
  let updOpen = $state(false);
  let updBtn = $state(null);
  function updLater() { touch('settings', 'update', { remindAt: shell.eveningAt() }); saveLayer(); updOpen = false; say('Напомню про обновление вечером, в 20:00'); }
  function updSkip() { touch('settings', 'update', { skip: upd.found.version, remindAt: null }); saveLayer(); updOpen = false; say(`Версию ${upd.found.version} пропускаю — поставить можно в «Состоянии»`); }

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
  let habitForm = null; // «Создать» на «Привычках» — форма новой привычки (Habits регистрирует)
  function newTask(fromKey = false) {
    if (openRef || newList) return;
    if (view === 'habits' && habitForm) { habitForm(); return; }
    if (!boardLists.length) return;
    if (fromKey && quickLine?.()) return;
    quick = {};
  }
  // Горячие клавиши (список — lib/keys.js и окно «?»).
  const VIEWS = ['today', 'calendar', 'board', 'habits'];
  let helpOpen = $state(false);
  // Поиск Ctrl+K: задачи всех списков и быстрый переход по разделам и спискам.
  let searchOpen = $state(false);
  const searchPlaces = $derived([
    { id: 'today', kind: 'Раздел', name: 'Сегодня', view: 'today', alias: ['today'] },
    { id: 'calendar', kind: 'Раздел', name: 'Календарь', view: 'calendar', alias: ['calendar', 'неделя', 'месяц'] },
    { id: 'board', kind: 'Раздел', name: 'Доска', view: 'board', alias: ['board', 'канбан'] },
    { id: 'habits', kind: 'Раздел', name: 'Привычки', view: 'habits', alias: ['habits'] },
    { id: 'archive', kind: 'Раздел', name: 'Архив', view: 'archive' },
    { id: 'templates', kind: 'Раздел', name: 'Шаблоны досок', view: 'templates' },
    ...boardLists.map((l) => ({ id: l.id, kind: 'Список', name: l.title, listId: l.id, n: (tasks[l.id] ?? []).filter((t) => !t.parent && t.status !== 'completed').length })),
  ]);
  function searchGo(p) {
    searchOpen = false;
    if (p.listId) { activeId = p.listId; boardProject = null; go('board'); } else go(p.view);
  }
  function searchOpenTask(listId, id) { searchOpen = false; openRef = { listId, id }; }
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
    tick().then(() => document.querySelector('.sd .sd-lst.on')?.scrollIntoView({ block: 'nearest' }));
  }
  async function hotkey(e) {
    if (phase !== 'ready' || choosing) return;
    if ((e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === 'KeyN') { e.preventDefault(); newTask(true); return; }
    if ((e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === 'Comma') { e.preventDefault(); if (settingsTab) settingsTab = null; else if (!keys.overlay()) openSettings(); return; }
    const onBoard = view === 'board' || view === 'archive' || view === 'sphere' || view === 'templates';
    if ((e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === 'KeyB' && onBoard) { e.preventDefault(); togglePin(); return; }
    if ((e.ctrlKey || e.metaKey) && !e.altKey && e.shiftKey && e.code === 'KeyL' && onBoard) { e.preventDefault(); sideApi?.focusFilter(); return; }
    if (e.key === 'Escape' && onBoard && !keys.overlay() && sideApi?.hide()) { e.preventDefault(); return; }
    if ((e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === 'KeyK') { e.preventDefault(); if (!keys.overlay() && !helpOpen) searchOpen = true; return; }
    if (!keys.plain(e) || keys.typing(e) || helpOpen) return;
    if (e.key === '?' || (e.shiftKey && e.code === 'Slash')) { e.preventDefault(); helpOpen = true; return; }
    if (keys.overlay()) return;
    if (e.code === 'Slash' && !e.shiftKey) { e.preventDefault(); searchOpen = true; return; }
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
      case 'BracketLeft': if (view === 'board' || view === 'archive') { sideApi?.peek(); stepList(-1); } break;
      case 'BracketRight': if (view === 'board' || view === 'archive') { sideApi?.peek(); stepList(1); } break;
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
    // «Проверять самому» (settings.update.auto) выключено — только вручную.
    const autoCheck = () => { if (lay.settings?.update?.auto !== false) checkUpdate(); };
    const updFirst = setTimeout(autoCheck, import.meta.env.MODE === 'demo' ? 1500 : 30e3); // в демо — сразу
    const updTimer = setInterval(autoCheck, 6 * 3600e3);
    // «Ставить ночью»: компьютер не спит в 3:00 и есть версия — ставим.
    const minTimer = setInterval(() => {
      nowMin = Date.now();
      if (upd.found && !upd.busy && shell.nightNow(lay.settings?.update)) installUpdate();
    }, 60e3);
    const timer = setInterval(() => { if (phase === 'ready') refresh(); }, 120000);
    const onFocus = () => { if (phase === 'ready' && (!sync.at || Date.now() - sync.at > 30000)) refresh(); };
    window.addEventListener('focus', onFocus);
    return () => { clearInterval(timer); clearTimeout(updFirst); clearInterval(updTimer); clearInterval(minTimer); window.removeEventListener('focus', onFocus); };
  });

  // Когда трекер сам менял задачу — чтобы ответ синхронизации, запрошенный раньше, её не откатил (lib/fresh.js).
  const touchedAt = new Map();
  function replace(listId, updated) {
    touchedAt.set(updated.id, Date.now());
    tasks[listId] = (tasks[listId] ?? []).map((t) => (t.id === updated.id ? updated : t));
  }

  // ---------- повтор: выполненная задача с правилом → следующая с новым сроком ----------
  let rolling = false;
  async function rollRepeats(quiet = false) {
    if (rolling) return;
    rolling = true;
    try {
      const todo = repeat.dueRepeats(lists.filter((l) => !isHabitList(l, lay)), tasks, lay.tasks);
      for (const { listId, task, rule } of todo) {
        const day = repeat.nextDue(rule, api.dueToYmd(task.due), api.ymd(new Date()));
        if (!day) continue;
        try {
          // Копию мог уже сделать другой компьютер — тогда только ссылаемся на неё (иначе на двух ПК задачи двоились).
          const have = repeat.existingNext(tasks[listId], task, day);
          if (have) { touch('tasks', task.id, { repeatNext: have.id, repeatAt: Date.now() }); saveLayer(); continue; }
          const r = await api.createTask(listId, { title: task.title, notes: task.notes ?? '', due: api.ymdToDue(day) });
          tasks[listId] = [r, ...(tasks[listId] ?? [])];
          const L = lay.tasks?.[task.id] ?? {};
          touch('tasks', r.id, Object.fromEntries(repeat.CARRY.filter((k) => L[k] != null).map((k) => [k, L[k]])));
          touch('tasks', task.id, { repeatNext: r.id, repeatAt: Date.now() });
          saveLayer();
          if (!quiet && !toastUndo) say(`Повтор: «${task.title}» — снова ${api.humanDue(r.due)}`);
        } catch (e) { say('Не удалось создать следующую повторяющуюся задачу: ' + e); break; }
      }
    } finally { rolling = false; }
  }

  // Отметку сняли сразу после выполнения («Отменить») — следующую копию убираем, пока её не трогали (10 мин).
  async function unrollRepeat(task, listId) {
    const L = lay.tasks?.[task.id];
    if (!L?.repeatNext || Date.now() - (L.repeatAt ?? 0) > 10 * 60e3) return;
    const next = (tasks[listId] ?? []).find((x) => x.id === L.repeatNext);
    touch('tasks', task.id, { repeatNext: null, repeatAt: null });
    saveLayer();
    if (!next || next.status === 'completed') return;
    tasks[listId] = tasks[listId].filter((x) => x.id !== next.id);
    await api.deleteTask(listId, next.id).catch(() => {});
  }

  async function toggle(task, done, listId = openRef?.listId ?? activeId, quiet = false) {
    try {
      const r = await api.completeTask(listId, task.id, done);
      replace(listId, r);
      if (done && lay.tasks?.[task.id]?.repeat?.every) rollRepeats(quiet);
      if (!done) unrollRepeat(task, listId);
      if (done && !task.parent && !quiet) say(`«${task.title}» выполнено`);
      if (done && lay.tasks?.[task.id]?.timer?.start) { touch('tasks', task.id, worktime.stopPatch(lay.tasks[task.id])); saveLayer(); } // выполнено — таймер стоп
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

  // ---------- учёт времени: один таймер на задачу, в слое (tasks[id].timer / spent) ----------
  const runId = $derived(worktime.runningId(lay.tasks));
  const runRef = $derived.by(() => {
    if (!runId) return null;
    for (const l of lists) { const t = (tasks[l.id] ?? []).find((x) => x.id === runId); if (t) return { task: t, listId: l.id }; }
    return null;
  });
  let nowTick = $state(Date.now());
  $effect(() => {
    if (!runId) return;
    nowTick = Date.now();
    const id = setInterval(() => (nowTick = Date.now()), 1000);
    return () => clearInterval(id);
  });
  function toggleTimer(id) {
    for (const [tid, patch] of worktime.toggle(lay.tasks, id)) touch('tasks', tid, patch);
    saveLayer();
  }

  // ---------- анимации: settings.motion = full | min | off ----------
  const motionPref = $derived(lay.settings?.motion?.v ?? 'full');
  $effect(() => motion.setMotion(motionPref));

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
      const r = await api.moveTask(listId, t.id, dest);
      // Если Google выдал задаче в новом списке другой id — переносим её поля Спутника (статус, тип, время…).
      if (r?.id && r.id !== t.id && lay.tasks?.[t.id]) {
        const { t: _, ...rest } = lay.tasks[t.id];
        touch('tasks', r.id, rest);
        saveLayer();
      }
      const [a, b] = await Promise.all([api.listTasks(listId), api.listTasks(dest)]);
      tasks[listId] = a; tasks[dest] = b;
      say(`«${t.title}» → список «${lists.find((l) => l.id === dest)?.title ?? ''}»`);
      return r?.id ?? t.id;
    } catch (e) { say('Не удалось перенести в другой список: ' + e); return null; }
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
    // ---------- стикеры (lib/Stickers.svelte) ----------
    done: (t, d, onundo) => doneUndo(t, d, activeId, onundo),
    pin: (t) => { touch('tasks', t.id, { pin: !lay.tasks?.[t.id]?.pin }); saveLayer(); },
    topic: (t, id) => topicUndo(t, id, activeId),
    when: (t, target) => whenUndo(t, target, activeId),
    add: ({ title, due, slot, layer }) => quickCreate({ title, listId: activeId, due, slot, layer }, true),
    topics: (topics) => { touch('lists', activeId, { topics }); saveLayer(); },
    set: (patch) => { touch('lists', activeId, patch); saveLayer(); },
  };
  /** Стикер сделан / возвращён: плашка «Сделано: «…» · Отменить». */
  async function doneUndo(t, d, listId, onundo) {
    const ok = await toggle(t, d, listId, true);
    if (!ok || !d) return ok;
    say(`Сделано: «${t.title || 'Без названия'}»`, () => { onundo?.(); const cur = findTask(listId, t.id); if (cur) toggle(cur, false, listId, true); });
    return true;
  }
  function topicUndo(t, id, listId) {
    const prev = lay.tasks?.[t.id]?.topic ?? null;
    if (prev === id) return;
    touch('tasks', t.id, { topic: id });
    saveLayer();
    const name = stickers.topicsOf(lay.lists?.[listId]).find((x) => x.id === id)?.name ?? stickers.MISC.name;
    say(`«${t.title || 'Без названия'}» → ${name}`, () => { touch('tasks', t.id, { topic: prev }); saveLayer(); });
  }
  /** Перенос по срокам: сегодня / на неделе / когда-нибудь. Время (slot) и напоминания идут за сроком. */
  async function whenUndo(t, target, listId) {
    const today = api.ymd(new Date());
    const cur = api.dueToYmd(t.due) || null;
    const next = stickers.whenDue(target, cur, today);
    if (next === cur) return;
    try { replace(listId, await api.patchTask(listId, t.id, { due: api.ymdToDue(next) })); }
    catch (e) { say('Не удалось перенести: ' + e); return; }
    const where = { today: 'сегодня', week: next ? api.humanDue(api.ymdToDue(next)) : 'на неделе', later: 'когда-нибудь' }[target];
    say(`«${t.title || 'Без названия'}» → ${where}`, async () => {
      try { replace(listId, await api.patchTask(listId, t.id, { due: api.ymdToDue(cur) })); } catch (e) { say('Не удалось вернуть срок: ' + e); }
    });
  }
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
  // Советы енота (2–3 для текущей доски): «Начни с …», лимит колонки, разбор входящих. Ссылка под советом — делает то, что
  // предлагает енот. «×» — скрыть до завтра (settings.tipHide), совсем — Настройки → Вид → «Енот-советчик» (settings.tips).
  const boardTips = $derived.by(() => {
    const open = (tasks[activeId] ?? []).filter((t) => !t.parent && t.status !== 'completed');
    const cols = templateFor(activeId).cols;
    const today = api.ymd(new Date());
    // Сначала просроченное, потом приоритет, потом срок (meta.pickNext).
    const task = open.length ? meta.pickNext(open.map((t) => ({ task: t })), lay.tasks, today).task : null;
    const first = task ? { task, why: meta.nextReason(task, lay.tasks, today, api.humanDue) } : null;
    return shell.boardTips({ open, cols, colOf: (t) => colOf(t, cols), first });
  });
  const tipsOn = $derived(lay.settings?.tips?.v !== false && lay.settings?.tipHide?.v !== api.ymd(new Date(nowMin)));
  function hideTips() { touch('settings', 'tipHide', { v: api.ymd(new Date()) }); saveLayer(); say('Советы спрятаны до завтра', () => { touch('settings', 'tipHide', { v: null }); saveLayer(); }); }
  async function runTip(t) {
    if (t.kind === 'task') openRef = { listId: activeId, id: t.ref };
    else if (t.kind === 'new') newTask();
    else if (t.kind === 'col') {
      const name = templateFor(activeId).cols.find((c) => c.id === t.ref)?.name;
      const el = [...document.querySelectorAll('.bcol, .colz')].find((x) => x.getAttribute('aria-label') === name || x.getAttribute('aria-label') === `Развернуть колонку ${name}`);
      el?.scrollIntoView({ behavior: motion.level() === 'full' ? 'smooth' : 'auto', block: 'nearest', inline: 'center' });
      el?.animate?.([{ boxShadow: '0 0 0 2px var(--clay)' }, { boxShadow: '0 0 0 2px transparent' }], { duration: 900 });
    }
  }

  // ---------- левая колонка: закреплена / откреплена (settings.sidePin), Ctrl+B ----------
  const sidePinned = $derived(lay.settings?.sidePin?.v !== false);
  let sideApi = null;
  function togglePin() {
    touch('settings', 'sidePin', { v: !sidePinned });
    saveLayer();
  }

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
    // и скрытым спискам тоже, иначе после «показать» они молча получили бы «Работу»
    for (const l of lists) if (!isHabitList(l, lay) && templateFor(l.id).id === id) touch('lists', l.id, { template: replacement });
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
  function deleteSphere(id = activeSphere) {
    for (const l of sphereLists(id)) touch('lists', l.id, { sphere: null });
    touch('spheres', id, { removed: true });
    saveLayer();
    sphereEditOpen = false;
    if (sphereFilter === id) sphereFilter = '';
    if (view === 'sphere' && activeSphere === id) view = 'board';
    say('Сфера удалена, списки — в «Без сферы»');
  }
  function newListIn(sid) { newListSphere = sid; newList = true; }

  // ---------- меню левой колонки (правый клик по списку или сфере) и удаление ----------

  let sideMenu = $state(null); // { at, kind: 'list' | 'sphere', id }
  let askDel = $state(null); // { title, text, note, yes, run } — окно подтверждения

  function openSideMenu(e, kind, id) {
    e.preventDefault();
    const r = e.currentTarget.getBoundingClientRect();
    // правый клик — у курсора, Shift+F10 / клавиша меню — у строки
    const at = e.type === 'contextmenu' && e.clientX ? { x: e.clientX, y: e.clientY } : { x: r.left + 24, y: r.bottom };
    sideMenu = { at, kind, id };
  }

  // «＋» в заголовке «Сферы»: новый список или новая сфера.
  function openAddMenu(e) {
    const r = e.currentTarget.getBoundingClientRect();
    sideMenu = { at: { x: r.left, y: r.bottom + 4 }, kind: 'add', id: null };
  }
  const sideItems = $derived.by(() => {
    if (!sideMenu) return [];
    if (sideMenu.kind === 'add') return [{ id: 'list', label: 'Новый список' }, { id: 'sphere', label: 'Новая сфера' }];
    if (sideMenu.kind === 'sphere') return [
      { id: 'open', label: 'Открыть сферу' },
      { id: 'edit', label: 'Изменить сферу' },
      { id: 'delete', label: 'Удалить сферу…', danger: true, sep: true },
    ];
    return [
      { id: 'open', label: 'Открыть доску' },
      ...(sphereOf(sideMenu.id, lay) ? [{ id: 'unsphere', label: 'Убрать из сферы' }] : []),
      { id: 'delete', label: 'Удалить список…', danger: true, sep: true },
    ];
  });

  function sideAction(a) {
    const { kind, id } = sideMenu;
    if (kind === 'add') {
      if (a === 'list') newListIn(null); else createSphere();
    } else if (kind === 'sphere') {
      if (a === 'open') openSphere(id);
      else if (a === 'edit') { openSphere(id); sphereEditOpen = true; }
      else if (a === 'delete') askDeleteSphere(id);
    } else {
      if (a === 'open') openList(id);
      else if (a === 'unsphere') { touch('lists', id, { sphere: null }); saveLayer(); say('Список — в «Без сферы»'); }
      else if (a === 'delete') askDeleteList(id);
    }
  }

  function askDeleteSphere(id) {
    const sp = spheres.find((s) => s.id === id);
    if (!sp) return;
    const n = sphereLists(id).length;
    askDel = {
      title: `Удалить сферу «${sp.name}»?`,
      text: n ? `${n} ${plural(n, ['список останется', 'списка останутся', 'списков останутся'])} и ${n === 1 ? 'уйдёт' : 'уйдут'} в «Без сферы» — задачи не пострадают.` : 'В сфере нет списков.',
      note: 'Вернуть сферу будет нельзя — только создать заново.',
      yes: 'Удалить сферу',
      run: () => deleteSphere(id),
    };
  }

  async function askDeleteList(id) {
    const l = boardLists.find((x) => x.id === id);
    if (!l) return;
    // Основной список Google Tasks («Мои задачи») Google удалить не даёт — скажем заранее.
    try { if ((await api.defaultListId()) === id) { say(`«${l.title}» — основной список Google Tasks, его удалить нельзя. Можно скрыть: «Что показывать» внизу колонки.`); return; } }
    catch { /* не узнали — попробуем, Google сам откажет */ }
    const all = (tasks[id] ?? []).filter((t) => !t.parent);
    const open = all.filter((t) => t.status !== 'completed').length;
    askDel = {
      title: `Удалить список «${l.title}»?`,
      text: all.length
        ? `Он удалится из Google Tasks вместе со всеми задачами: ${all.length} ${plural(all.length, ['задача', 'задачи', 'задач'])}${open ? `, из них открытых — ${open}` : ''}. На телефоне тоже пропадёт.`
        : 'Он пустой. Удалится из Google Tasks — на телефоне тоже пропадёт.',
      note: 'Вернуть будет нельзя. Если список просто мешает — его можно скрыть: «Что показывать» внизу колонки.',
      yes: 'Удалить список',
      run: () => deleteList(id),
    };
  }

  async function deleteList(id) {
    const l = lists.find((x) => x.id === id);
    try { await api.deleteList(id); }
    catch (e) { say('Не удалось удалить список: ' + e); return; }
    const ids = (tasks[id] ?? []).map((t) => t.id);
    lists = lists.filter((x) => x.id !== id);
    delete tasks[id];
    // Надгробия, а не delete: иначе другой компьютер при слиянии вернул бы записи списка и его задач.
    layerSync.forgetList(lay, id, ids);
    saveLayer();
    if (openRef?.listId === id) openRef = null;
    if (activeId === id) { activeId = boardLists[0]?.id ?? null; boardProject = null; }
    say(`Список «${l?.title ?? ''}» удалён`);
  }

  // Дубли задач (Настройки → Синхронизация): найти, показать, удалить отмеченные — только после подтверждения.
  const dupeGroups = $derived(findDupes(tasks, lists.filter((l) => !isHabitList(l, lay)), lay.tasks));
  function askDedupe(items) {
    if (!items.length) return;
    settingsTab = null;
    askDel = {
      title: `Удалить ${items.length} ${plural(items.length, ['лишнюю копию', 'лишние копии', 'лишних копий'])}?`,
      text: 'Они удалятся из Google Tasks. У каждой задачи останется одна — та, у которой больше полей Спутника.',
      note: 'Вернуть удалённые будет нельзя.',
      yes: 'Удалить',
      run: async () => {
        let n = 0;
        for (const { listId, id } of items) {
          try { await api.deleteTask(listId, id); tasks[listId] = (tasks[listId] ?? []).filter((x) => x.id !== id); n++; }
          catch (e) { say('Не удалось удалить: ' + e); break; }
        }
        if (n) say(`Удалено лишних копий: ${n}`);
      },
    };
  }

  async function confirmDel() {
    const run = askDel?.run;
    await run?.();
    askDel = null;
  }

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
      newListName = '';
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

  /** Принять входящие; dest — другой список, чем выбрал Claude («→ список» на «Сегодня»): сначала перенос. */
  async function acceptInbox(items) {
    for (const x of items) {
      let id = x.task.id;
      if (x.dest && x.dest !== x.listId) id = (await moveToList(x.task, x.dest, x.listId)) ?? id;
      touch('tasks', x.task.id, { inbox: 'accepted' });
      if (id !== x.task.id) touch('tasks', id, { inbox: 'accepted' });
    }
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
  async function quickCreate({ title, listId, due, slot, layer = null, notes = '', subs = [] }, quiet = false) {
    try {
      const r = await api.createTask(listId, { title, ...(notes ? { notes } : {}), ...(due ? { due: api.ymdToDue(due) } : {}) });
      tasks[listId] = [r, ...(tasks[listId] ?? [])];
      // Подзадачи (окно «Создать»): Google ставит новую подзадачу первой — создаём с конца, чтобы порядок сохранился.
      for (const sb of [...subs].reverse()) {
        try {
          const c = await api.createTask(listId, { title: sb.title }, r.id);
          tasks[listId] = [...(tasks[listId] ?? []), c];
          if (sb.stage) touch('tasks', c.id, { stage: sb.stage });
        } catch (e) { say('Не все подзадачи добавились: ' + e); break; }
      }
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

  /** Окно «Создать»: задача создаётся тихо, потом — плашка «Создано в «…» · Открыть». */
  async function createFromWindow(p, quiet = false) {
    const id = await quickCreate(p, true);
    if (id && !quiet) {
      const l = lists.find((x) => x.id === p.listId);
      say(`Создано в «${l?.title ?? ''}»`, () => { openRef = { listId: p.listId, id }; }, 'Открыть');
    }
    return id;
  }
  /** Окно «Создать» выучило слова (ручной выбор списка или темы) — settings.route. */
  function learnRoute(patch) {
    touch('settings', 'route', patch);
    saveLayer();
  }

  /** Новый срок сразу нескольким задачам (на «Сегодня» — «Всё на сегодня»), с «Отменить». items — [{ task, list }]. */
  async function rescheduleMany(items, day) {
    const prev = items.map((x) => ({ listId: x.list.id, id: x.task.id, due: x.task.due ?? null }));
    const setDue = async (listId, id, due) => replace(listId, await api.patchTask(listId, id, { due }));
    let n = 0;
    try {
      for (const p of prev) { await setDue(p.listId, p.id, api.ymdToDue(day)); n++; }
    } catch (e) { say('Перенесено не всё: ' + e); return; }
    say(`Перенесено на ${whenText(day, null).date.split(',')[0].toLowerCase()}: ${n}`, async () => {
      try { for (const p of prev) await setDue(p.listId, p.id, p.due); }
      catch (e) { say('Не удалось вернуть сроки: ' + e); }
    });
  }

  // ---------- привычки ----------

  function toggleHabit(h) {
    const day = api.ymd(new Date());
    const done = !isDone(lay.log, h.id, day);
    touch('log', logKey(h.id, day), { done, rest: false });
    if (done) {
      const n = stats(h, lay.log).streak;
      if (MILESTONES.includes(n) && lay.habits?.[h.id]?.cheer?.key !== `${n}|${day}`) celebrate(h, n, day);
    } else {
      if (cele?.id === h.id) cele = null;
      // Отметку сняли — снимаем и сегодняшнюю веху, иначе бот всё равно поздравил бы (файл напоминаний, cheers).
      const c = lay.habits?.[h.id]?.cheer;
      if (c?.key?.endsWith(`|${day}`)) touch('habits', h.id, { cheer: null });
    }
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
    if (lay.settings?.notify?.v === false) return; // Настройки → Напоминания → «Уведомления Windows» выключены
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
      // «Надгробия», а не delete: иначе другой компьютер при слиянии вернул бы записи обратно.
      const t = Date.now();
      lay.habits[id] = { gone: true, t };
      for (const k of Object.keys(lay.log)) if (k.startsWith(id + '|')) lay.log[k] = { gone: true, t };
      saveLayer();
      say('Привычка удалена');
    } catch (e) { say('Не удалось удалить привычку: ' + e); }
  }

  async function logout() {
    await api.auth.logout().catch(() => {});
    lists = []; tasks = {}; events = []; openRef = null;
    layerSync.reset(); cloud = { state: 'idle', at: null, err: '' };
    authInfo = await api.auth.status();
    phase = 'setup';
  }

  // «Состояние» в шапке: три точки (Google, между компьютерами, версия) и время последней синхронизации.
  let statOpen = $state(false);
  let statBtn = $state(null);
  // ---------- Настройки (⚙ в шапке, Ctrl+,): всё из старого низа левой колонки ----------
  let settingsTab = $state(null); // null — окно закрыто
  function openSettings(tab = 'look') { statOpen = false; updOpen = false; settingsTab = tab; }
  function setPref(key, patch) {
    touch('settings', key, patch);
    saveLayer();
    if (key === 'update' && 'beta' in patch) { upd.found = null; checkUpdate(true); } // канал сменился — проверить сразу
  }
  function hideList(id, hide) { touch('lists', id, { hidden: hide }); saveLayer(); }
  async function hideCal(id, hide) {
    touch('cals', id, { hidden: hide });
    saveLayer();
    api.setHiddenCalendars(Object.keys(lay.cals ?? {}).filter((x) => lay.cals[x]?.hidden));
    calReload++;
    events = await api.eventsForDay().catch(() => events);
  }
  // ---------- общий Telegram-бот (lib/sharedbot.js) ----------
  let tgStat = $state({ at: null, err: '', unlinked: false });
  /** Что человек написал боту: новые задачи и «✓ Готово» под напоминаниями. Не вышло — останется до следующего раза. */
  async function pullTg() {
    const key = lay.settings?.tgbot?.key;
    if (!key) return;
    try {
      const r = await sharedbot.inbox(key);
      const ok = [];
      let added = 0;
      for (const x of r.items ?? []) {
        if (x.type === 'add') {
          const t = sharedbot.fromText(x.text, { lists: boardLists, layer: lay, tasks });
          if (t) { if (!(await quickCreate(t, true))) continue; added++; }
        } else if (x.type === 'done') {
          const task = (tasks[x.listId] ?? []).find((y) => y.id === x.taskId);
          if (task && task.status !== 'completed' && !(await toggle(task, true, x.listId, true))) continue;
        }
        ok.push(x.id);
      }
      if (ok.length) await sharedbot.ack(key, ok);
      if (added) say(added === 1 ? 'Из Telegram — новая задача' : `Из Telegram — новых задач: ${added}`);
      tgStat = { at: new Date(), err: '', unlinked: false };
    } catch (e) { tgStat = { ...tgStat, err: String(e.message ?? e), unlinked: !!e.unlinked }; }
  }
  /** Код из бота → привязка. Ошибку показывает «Настройки» (поэтому бросаем дальше). */
  async function tgLink(code) {
    const key = lay.settings?.tgbot?.key ?? sharedbot.newKey();
    const r = await sharedbot.link(code, key);
    sharedbot.forget();
    touch('settings', 'tgbot', { key, name: r.name ?? '', at: Date.now() });
    saveLayer();
    tgStat = { at: new Date(), err: '', unlinked: false };
    say('Telegram подключён ✓ — напоминания придут туда');
  }
  async function tgTest() {
    try { await sharedbot.test(lay.settings?.tgbot?.key); say('Отправил проверку — загляни в Telegram'); }
    catch (e) { say('Бот не ответил: ' + (e.message ?? e)); }
  }
  async function tgUnlink() {
    await sharedbot.unlink(lay.settings?.tgbot?.key).catch(() => {});
    touch('settings', 'tgbot', { key: null, name: '', at: null });
    saveLayer();
    say('Telegram отключён');
  }
  // «Проверить» бота: пункт test в файле напоминаний — Code.gs пришлёт его в Telegram в течение минуты.
  let botTest = $state(null);
  function testBot() {
    botTest = { key: 'test-' + Date.now(), kind: 'test', title: 'Спутник: проверка связи — напоминания доходят ✓', fireAt: new Date().toISOString() };
    say('Отправил проверку — сообщение придёт в Telegram в течение пары минут');
  }
  // Тема: settings.theme = system | dark | light → data-theme на <html> («как в Windows» — без атрибута).
  const themePref = $derived(lay.settings?.theme?.v ?? 'system');
  $effect(() => {
    const el = document.documentElement;
    if (themePref === 'dark' || themePref === 'light') el.setAttribute('data-theme', themePref);
    else if (lay.settings?.theme) el.removeAttribute('data-theme');
  });
  // «Задачи без времени — во сколько» (settings.remindHour).
  $effect(() => reminders.setDefaultTime(lay.settings?.remindHour?.v ?? '10:00'));
  // «Где остановился» — последний раздел на этом компьютере (не в слое: у каждого компьютера свой).
  $effect(() => { const v = section(view); try { localStorage.setItem('sp.lastView', v); } catch {} });
  const stat = $derived(shell.statusDots({ sync, offline, cloud, upd }));
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
    <!-- Шапка 0.6 — она же полоса окна: тянуть за пустое место, двойной клик — развернуть. Ничего не переносится. -->
    <header class="sp-hd" data-tauri-drag-region>
      <Brand />
      <nav class="hd-tabs" aria-label="Разделы" style="display: contents">
        <button class="hd-tab" role="tab" aria-selected={view === 'today'} title="Клавиша 1 · Q / E — соседний раздел" onclick={() => go('today')}>Сегодня{#if todayCount}<span class="cnt hot" title="На сегодня и просрочено">{todayCount}</span>{/if}</button>
        <button class="hd-tab" role="tab" aria-selected={view === 'calendar'} title="Клавиша 2 · Q / E — соседний раздел" onclick={() => go('calendar')}>Календарь</button>
        <button class="hd-tab" role="tab" aria-selected={section(view) === 'board'} title="Клавиша 3 · Q / E — соседний раздел" onclick={() => go('board')}>Доска</button>
        <button class="hd-tab" role="tab" aria-selected={view === 'habits'} title="Клавиша 4 · Q / E — соседний раздел" onclick={() => go('habits')}>Привычки{#if habitsLeft}<span class="cnt" title="Осталось отметить сегодня">{habitsLeft}</span>{/if}</button>
      </nav>
      <span class="hd-sp" data-tauri-drag-region></span>
      {#if updChip}
        <button class="hd-upd" bind:this={updBtn} type="button" aria-expanded={updOpen} aria-haspopup="dialog" transition:motion.pop
          title={upd.busy ? 'Ставлю обновление' : 'Что нового — и обновить'} onclick={() => (updOpen = !updOpen)}>
          {#if upd.busy}Обновляю · {Math.round(upd.progress * 100)}%<span class="pr" style="width: {Math.round(upd.progress * 100)}%"></span>
          {:else}✦ Версия {upd.found.version}{/if}
        </button>
      {/if}
      {#if runRef}
        <span class="timer-pill" role="status">
          <button type="button" class="tp-open" title="Открыть задачу «{runRef.task.title || 'Без названия'}»" onclick={() => (openRef = { listId: runRef.listId, id: runRef.task.id })}>
            <span class="tp-dot" aria-hidden="true"></span><b>{worktime.clock(nowTick - lay.tasks[runId].timer.start)}</b><span class="tp-t">{runRef.task.title || 'Без названия'}</span>
          </button>
          <button type="button" class="tp-stop" title="Остановить таймер" aria-label="Остановить таймер" onclick={() => toggleTimer(runId)}>
            <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="7" width="10" height="10" rx="1.5" /></svg>
          </button>
        </span>
      {/if}
      <button class="hd-find" type="button" title="Поиск по задачам и разделам (Ctrl+K или /)" aria-label="Найти" onclick={() => (searchOpen = true)}>
        <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.5" /><path d="M16 16l4.5 4.5" /></svg><span class="lbl">Найти</span><kbd>Ctrl K</kbd>
      </button>
      <button class="hd-stat" bind:this={statBtn} type="button" aria-expanded={statOpen} aria-haspopup="dialog" title="Состояние: Google, компьютеры, версия"
        onclick={() => (statOpen = !statOpen)}>
        <span class="st-dots" aria-hidden="true">{#each stat.dots as d, i (i)}<i class={d.c} class:busy={d.busy || (i === 0 && syncFlash)}></i>{/each}</span><span class="lbl">{stat.label}</span>
      </button>
      {#if inboxItems.length}
        <button class="hd-ib" type="button" title="Входящие от Claude · {inboxItems.length} — разобрать на «Сегодня»"
          aria-label="Входящие от Claude, {inboxItems.length}" onclick={openInbox}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 13h4l2 3h4l2-3h4M5 5h14l1 8v6H4v-6z" /></svg><span class="b">{inboxItems.length}</span>
        </button>
      {/if}
      <button class="hd-ib" type="button" aria-expanded={!!settingsTab} title="Настройки · Ctrl+," aria-label="Настройки" onclick={() => openSettings()}>
        <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3h0a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8v0a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" /></svg>
        {#if upd.found}<span class="b dot" aria-hidden="true"></span>{/if}
      </button>
      <button class="hd-create" type="button" disabled={view !== 'habits' && !boardLists.length}
        title={view === 'habits' ? 'Новая привычка' : boardLists.length ? 'Новая задача, событие или день рождения (N или Ctrl+N)' : 'Сначала создай список на доске'}
        onclick={() => newTask()}>
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>Создать
      </button>
      <WinControls />
    </header>

    {#if upd.fail}
      <div class="upd" role="alert">
        <p class="err">{upd.fail}</p>
        <button class="st-mini" type="button" onclick={installUpdate}>Ещё раз</button>
        <button class="st-mini ghost" type="button" onclick={() => (upd.fail = '')}>Скрыть</button>
      </div>
    {/if}

    {#if offline}
      <div class="offline1" role="alert">
        <Coon pose="oops" size={34} />
        <p><b>Нет связи с Google.</b> Повторю через минуту — всё, что сделаешь сейчас, сохранится и уйдёт само.</p>
        <button class="st-mini" type="button" disabled={sync.busy} onclick={refresh}>Повторить</button>
      </div>
    {/if}

    <div class="body">
      {#if view === 'board' || view === 'archive' || view === 'sphere' || view === 'templates'}
        <Side {spheres} listsOf={sphereLists} noSphere={noSphereLists} count={openCount} viewOf={viewFor} {activeId}
          current={view} {activeSphere} folded={(id) => !!lay.settings?.sphereFold?.[id]}
          {projects} project={boardProject} tips={view === 'board' && activeList ? boardTips : []} tipsOn={tipsOn}
          pinned={sidePinned} hold={!!sideMenu}
          onlist={openList} onsphere={openSphere} onfold={foldSphere} onmenu={openSideMenu} onadd={openAddMenu}
          onproject={(p) => (boardProject = p)} ontemplates={() => (view = 'templates')} onarchive={() => (view = 'archive')}
          onshow={() => openSettings('show')} onpin={togglePin} ontip={runTip} ontiphide={hideTips}
          onregister={(api) => (sideApi = api)} />
      {/if}

      <div class="main">
        {#snippet sphFilter()}<SphereFilter {spheres} value={sphereFilter} onchange={(v) => (sphereFilter = v)} />{/snippet}
        {#if view === 'today'}
          <Today lists={shownLists} tasksByList={tasks} {events} layTasks={lay.tasks} layer={lay} log={lay.log} {habits}
            {inboxItems} inboxOn={!!inboxSt} {inboxFocus} {typeOf}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            ontoggle={(t, d, listId, quiet) => toggle(t, d, listId, quiet)}
            oncreate={(p, loud = false) => quickCreate(p, !loud)} onreschedule={rescheduleMany} ontogglehabit={toggleHabit}
            onaccept={acceptInbox} onreject={rejectInbox}
            onregister={(fn) => (quickLine = fn)} onlearn={learnRoute} onfull={(line) => { if (boardLists.length) quick = { line }; }}
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
          <Habits {habits} log={lay.log} {cele} onregister={(fn) => (habitForm = fn)} ontoggle={toggleHabit} onclosecele={() => (cele = null)}
            oncreate={createHabit} onupdate={updateHabit} ondelete={deleteHabit} />
        {:else if view === 'templates'}
          <Templates templates={allTemplates} usage={templateUsage} count={templateCount} current={activeList ? templateFor(activeId).id : null}
            onsave={saveTemplate} onreset={resetTemplate} oncreate={createTemplate} ondelete={deleteTemplate} onback={() => (view = 'board')} />
        {:else if view === 'sphere' && curSphere}
          <SphereView sphere={curSphere} lists={sphereLists(curSphere.id)} tasksByList={tasks} {templateFor} {colOf}
            onedit={() => (sphereEditOpen = true)} onaddlist={() => newListIn(curSphere.id)}
            onopenlist={openList} onopentask={(t, listId) => (openRef = { listId, id: t.id })} />
        {:else if view === 'archive'}
          <Archive lists={boardLists} tasksByList={tasks} {activeId} jar={(listId) => viewFor(listId) === 'stickers'}
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
            act={boardAct} layList={lay.lists?.[activeId] ?? {}} lists={boardLists.filter((l) => l.id !== activeId)} sphereName={spheres.find((s) => s.id === sphereOf(activeId, lay))?.name ?? ''} fold={boardFold} onfold={foldCol}
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
      repeat={lay.tasks?.[openTask.id]?.repeat ?? null}
      pick={!!openRef.pick} fields={templateFor(openRef.listId).fields} client={lay.tasks?.[openTask.id]?.client ?? ''} money={lay.tasks?.[openTask.id]?.money ?? ''}
      onlayer={(p) => { touch('tasks', openTask.id, p); saveLayer(); }}
      spent={worktime.spentMin(lay.tasks?.[openTask.id], nowTick)} running={runId === openTask.id} ontimer={() => toggleTimer(openTask.id)}
      dueDays={dueDaysExcept(openTask.id)} loadEvents={api.eventsRange}
      onclose={() => (openRef = null)}
      onsave={save}
      onstatus={(s) => move(openTask, s, openRef.listId)}
      ondelete={remove}
      ontoggle={(t, d) => toggle(t, d, openRef.listId)}
      onaddsub={addSub} onsubedit={editSub} onsubdelete={deleteSub} />
  {/if}

  {#if quick}
    <!-- Окно «Создать» v2: с доски «Куда» по умолчанию — эта доска; из других разделов — по словам. -->
    <Create lists={boardLists} listId={view === 'board' && boardLists.some((l) => l.id === activeId) ? activeId : null}
      from={view === 'board' && boardProject ? { project: boardProject } : {}}
      day={quick.day ?? ''} s={quick.s ?? ''} e={quick.e ?? ''} line={quick.line ?? ''}
      layer={lay} tasksByList={tasks}
      dueDays={dueDaysExcept()} loadEvents={api.eventsRange} loadCalendars={api.calendarsAll}
      {remindDefaults} onremindDefault={setRemindDefault}
      oncreate={createFromWindow} oncreateevent={createEvent} oncreatebirthday={createBirthday}
      onlearn={learnRoute} onnewlist={(name) => { quick = null; newListName = name; newList = true; }}
      onclose={() => (quick = null)} />
  {/if}

  {#if updOpen && updChip}
    <Popover anchor={updBtn} width={344} label="Обновление" onclose={() => (updOpen = false)}>
      <h5>{upd.busy ? `Ставлю ${upd.found.version}` : `Что нового в ${upd.found.version}`}</h5>
      {#if shell.notesOf(upd.found.notes).length}
        <ul class="st-notes" style="margin-left: 10px">{#each shell.notesOf(upd.found.notes) as n, i (i)}<li>{n}</li>{/each}</ul>
      {/if}
      {#if upd.busy}
        <div class="st-bar" style="margin-left: 10px"><i style="width: {Math.round(upd.progress * 100)}%"></i></div>
        <p class="upd-note">Скачиваю… окно установки закроется само, Спутник перезапустится. Данные не пострадают.</p>
      {:else}
        <div class="upd-acts">
          <button type="button" class="st-mini pri" onclick={installUpdate}>Обновить сейчас</button>
          <button type="button" class="st-mini" onclick={updLater}>Вечером</button>
          <button type="button" class="st-mini ghost" onclick={updSkip}>Пропустить</button>
        </div>
      {/if}
    </Popover>
  {/if}
  {#if statOpen}
    <StatusPop anchor={statBtn} {sync} {offline} {cloud} {upd} {version} rem={remView} notes={shell.notesOf(upd.found?.notes)}
      onrefresh={refresh} onlogin={() => { statOpen = false; cloudLogin(); }} oncheck={() => checkUpdate(true)}
      oninstall={() => { statOpen = false; installUpdate(); }} onsettings={() => { statOpen = false; openSettings(); }}
      onclose={() => (statOpen = false)} />
  {/if}
  {#if settingsTab}
    <Settings tab={settingsTab} settings={lay.settings ?? {}} lists={lists.filter((l) => !isHabitList(l, lay)).map((l) => ({ ...l, color: sphereOf(l.id, lay) ? sphereColor(spheres.find((x) => x.id === sphereOf(l.id, lay))) : null }))}
      hiddenLists={hiddenNow.lists} hiddenCals={hiddenNow.cals} sphereName={(id) => spheres.find((x) => x.id === sphereOf(id, lay))?.name ?? (id === lists[0]?.id ? 'основной список Google' : '')}
      {version} {upd} {sync} {offline} {cloud} rem={remStat} {ownBot} remind={remindDefaults} dupes={dupeGroups} ondedupe={askDedupe}
      onset={setPref} onhidelist={hideList} onhidecal={hideCal} onremind={setRemindDefault} ontestbot={testBot}
      tgbot={lay.settings?.tgbot} {tgStat} ontglink={tgLink} ontgtest={tgTest} ontgunlink={tgUnlink}
      onlogout={() => { settingsTab = null; logout(); }} onrefresh={refresh} oncloudlogin={cloudLogin}
      oninstall={installUpdate} oncheck={() => checkUpdate(true)} onclose={() => (settingsTab = null)} />
  {/if}
  {#if searchOpen}
    <Search lists={boardLists} {tasks} places={searchPlaces} onopen={searchOpenTask} ongo={searchGo} onclose={() => (searchOpen = false)} />
  {/if}
  {#if helpOpen}
    <KeyHelp onclose={() => (helpOpen = false)} />
  {/if}

  {#if sphereEditOpen && curSphere && view === 'sphere'}
    <SphereEdit sphere={curSphere} lists={boardLists} inSphere={(id) => sphereOf(id, lay) === curSphere.id}
      whereOf={(id) => spheres.find((s) => s.id === sphereOf(id, lay))?.name ?? ''}
      onchange={updateSphere} ontogglelist={toggleListSphere} ondelete={() => deleteSphere()} onclose={() => (sphereEditOpen = false)} />
  {/if}

  {#if sideMenu}
    <ItemMenu at={sideMenu.at} label={sideMenu.kind === 'sphere' ? 'Действия со сферой' : sideMenu.kind === 'add' ? 'Создать' : 'Действия со списком'} items={sideItems}
      onaction={sideAction} onclose={() => (sideMenu = null)} />
  {/if}
  {#if askDel}
    <ConfirmDelete title={askDel.title} text={askDel.text} note={askDel.note} yes={askDel.yes} onconfirm={confirmDel} onclose={() => (askDel = null)} />
  {/if}

  {#if newList}
    <NewList templates={allTemplates} name={newListName} oncreate={createList} onclose={() => { newList = false; newListSphere = null; newListName = ''; }} />
  {/if}
{/if}

{#if toast}
  <div class="toast" role="status" onmouseenter={pauseToast} onmouseleave={resumeToast}>
    {#key toastN}<span class="timer" aria-hidden="true"></span>{/key}
    <span>{toast}</span>
    {#if toastUndo}<button type="button" class="undo" onclick={undoToast}>{toastLabel}</button>{/if}
    <button type="button" onclick={() => { toast = ''; toastUndo = null; }}>Скрыть</button>
  </div>
{/if}
