<script>
  import { onMount, tick, flushSync, untrack } from 'svelte';
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
  import EditList from './lib/EditList.svelte';
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
  import ShareStates from './lib/ShareStates.svelte';
  import SphereEdit from './lib/SphereEdit.svelte';
  import SphereFilter from './lib/SphereFilter.svelte';
  import Side from './lib/Side.svelte';
  import Settings from './lib/Settings.svelte';
  import ItemMenu from './lib/ItemMenu.svelte';
  import ConfirmDelete from './lib/ConfirmDelete.svelte';
  import { isDone, logKey, stats, plural, MILESTONES, sortHabits, nextMark, dayMark, unitForms } from './lib/habits.js';
  import * as notify from '@tauri-apps/plugin-notification';
  import * as updater from './lib/updater.js';
  import * as meta from './lib/meta.js';
  import { whenText } from './lib/when.js';
  import * as repeat from './lib/repeat.js';
  import * as fresh from './lib/fresh.js';
  import { findDupes } from './lib/dupes.js';
  import * as stickers from './lib/stickers.js';
  import * as reminders from './lib/reminders.js';
  import * as pictures from './lib/previewDrive.js';
  import * as sharedbot from './lib/sharedbot.js';
  import { typeOfTemplate } from './lib/calendar.js';
  import * as inbox from './lib/inbox.js';
  import * as layerSync from './lib/layer.js';
  import * as shared from './lib/shared.js';
  import * as sh from './lib/sharedcore.js';
  import ShareSphere from './lib/ShareSphere.svelte';
  import * as shell from './lib/shell.js';
  import { accentCss } from './lib/accent.js';
  import StatusPop from './lib/StatusPop.svelte';
  import Popover from './lib/Popover.svelte';
  import Toast from './lib/Toast.svelte';
  import { say, busy as toastBusy } from './stores/toast.svelte.js';
  import * as layerStore from './stores/layer.svelte.js';

  let phase = $state('loading'); // loading | setup | ready
  let authInfo = $state({ has_secret: false, signed_in: false });
  let view = $state('today'); // today | calendar | board | archive | habits | templates | sphere
  let lists = $state([]);
  let activeId = $state(null);
  let tasks = $state({}); // listId → задачи (вместе с подзадачами)
  // Слой Спутника (то, чего нет в Google) — в сторе; lay — его текущий объект (менять поля можно, заменять целиком — нет).
  const lay = $derived(layerStore.layer.data);
  const cloud = $derived(layerStore.layer.cloud);
  const { touch, sync: syncLayer, cloudLogin } = layerStore;
  const saveLayer = layerStore.save;
  let events = $state([]);
  let inboxSt = $state(null); // статус «Входящих от Claude»
  let openRef = $state(null); // { listId, id }
  let newList = $state(false);
  let newListName = $state(''); // название из окна «Создать»
  let quick = $state(null); // окно «Создать»: { day, s, e } — что подставить
  let sync = $state({ busy: false, err: '', at: null });
  let syncFlash = $state(false); // короткая вспышка точки синхронизации по окончании обмена

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

  const habitsRaw = $derived(habitList
    ? (tasks[habitList.id] ?? []).filter((t) => !t.parent && t.status !== 'completed')
        .sort((a, b) => (a.position || '').localeCompare(b.position || ''))
        .map((t) => {
          const m = lay.habits?.[t.id] ?? {};
          return { id: t.id, name: t.title || 'Без названия', days: m.days ?? [], time: m.time ?? null, createdAt: m.createdAt,
            part: m.part ?? null, perWeek: m.perWeek ?? null, goal: m.goal ?? null, icon: m.icon ?? null, color: m.color ?? null, remind: m.remind ?? null, tipHide: m.tipHide ?? null };
        })
    : []);
  // Порядок карточек на «Привычках» (по части дня, внутри — по времени) — его же держат Shift+1…9.
  const habits = $derived(sortHabits(habitsRaw));
  const inboxItems = $derived(inbox.pending(inboxSt, boardLists, tasks, lay.tasks));
  const habitsLeft = $derived(habits.filter((h) => !isDone(lay.log, h.id, api.ymd(new Date()))).length);

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
    const items = [...reminders.collect(boardLists.filter((l) => !l.lost), mineTasks, lay.tasks, habitList, cheers, remindEvents), ...reminders.habitItems(habits, lay.log),
      ...reminders.assignedItems(boardLists, tasks, lay.tasks), ...(botTest ? [botTest] : [])];
    const tgKey = lay.settings?.tgbot?.key;
    const own = ownBot;
    const week = tgKey ? sharedbot.snapshot(boardLists, mineTasks, lay.tasks) : null;
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
      // Общие сферы (календари) — до списков: их списки и задачи api берёт из того, что забрали здесь.
      const shr = await shared.pullAll().catch((e) => { if (api.isOffline(e)) throw e; shareErr = String(e); return null; });
      const ls = await api.listLists();
      const all = await Promise.all(ls.map((l) => api.listTasks(l.id)));
      // Слой с других компьютеров — до того, как показать задачи: иначе новая задача с другого ПК сначала
      // мелькала в «Разное» и без полей, а повтор, уже продолженный там (repeatNext), продолжался второй раз.
      await syncLayer();
      if (shr) shared.applyProfile(lay.settings?.profile).then((n) => { if (n) shareVer++; }).catch(() => {});
      if (shr) applyShared(shr);
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
    await layerStore.load();
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
  // Порядок вкладок — свой из Настройки → Вид (settings.tabs), клавиши 1–4 и Q/E идут по нему же.
  const VIEWS = $derived(shell.tabOrder(lay.settings?.tabs?.v));
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
    ...habits.map((h) => ({ id: 'hab-' + h.id, kind: 'Привычка', name: h.name, view: 'habits', habitId: h.id })),
    ...boardLists.map((l) => ({ id: l.id, kind: 'Список', name: l.title, listId: l.id, n: (tasks[l.id] ?? []).filter((t) => !t.parent && t.status !== 'completed').length })),
  ]);
  function searchGo(p) {
    searchOpen = false;
    if (p.listId) { activeId = p.listId; boardProject = null; go('board'); } else go(p.view);
    if (p.habitId) habitOpen = { id: p.habitId }; // привычка из поиска — сразу её панель
  }
  let habitOpen = $state(null);
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
    if (e.key === 'Escape' && view === 'templates' && !keys.overlay() && !keys.typing(e)) { e.preventDefault(); view = 'board'; return; }
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
      if (phase === 'ready') habitWin();
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
          if (!quiet && !toastBusy()) say(`Повтор: «${task.title}» — снова ${api.humanDue(r.due)}`);
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
      // Общая сфера: кто сделал — кружок на штампе «сделано» у всех.
      if (sh.isSharedId(listId) && !task.parent && (lay.tasks?.[task.id]?.doneBy ?? null) !== (done ? meEmail : null)) { touch('tasks', task.id, { doneBy: done ? meEmail : null }); saveLayer(); }
      return true;
    } catch (e) { say('Не удалось отметить: ' + e); return false; }
  }

  async function move(task, col, listId = activeId) {
    // stageAt[колонка] — когда задача пришла на этап (учёт времени в «Конвейере»).
    const stageAt = { ...(lay.tasks?.[task.id]?.stageAt ?? {}), [col]: Date.now() };
    // Общая сфера, вперёд по этапам: исполнитель ассета становится исполнителем следующего этапа (sh.stagePass).
    const cs = templateFor(listId).cols, from = colOf(task, cs);
    const pass = sh.isSharedId(listId) && together(sphereOf(listId, lay)) && cs.findIndex((c) => c.id === col) > cs.findIndex((c) => c.id === from)
      ? sh.stagePass(lay.tasks?.[task.id], from, col, meEmail) : {};
    if (col !== 'done') touch('tasks', task.id, { status: col, stageAt, ...pass });
    else touch('tasks', task.id, { stageAt, ...pass });
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
    who: (t, w) => setWho(t.id, w),
    // Конвейер: исполнитель этапа; у текущего этапа он же ведёт ассет.
    stageWho: (t, col, w) => {
      const L = lay.tasks?.[t.id];
      touch('tasks', t.id, { ...sh.setStageWho(L, col, w), ...(colOf(t, templateFor(activeId).cols) === col ? { who: w ?? null } : {}) });
      saveLayer();
    },
    order: (ids) => { ids.forEach((id, i) => touch('tasks', id, { ord: i })); saveLayer(); },
    moveList: (t, dest) => moveToList(t, dest, activeId),
    duplicate: (t) => duplicateTask(t, activeId),
    remove: (t) => removeUndo(t, activeId),
    preview: (t, file) => setPreview(t.id, file, t.title),
    previewClear: (t) => clearPreview(t.id, t.title),
    previewOff: () => previewOff(activeId),
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
  // Списки сферы без доступа («нет доступа») в «Сегодня» и календарь не идут.
  const shownLists = $derived((sphereFilter && spheres.some((s) => s.id === sphereFilter) ? sphereLists(sphereFilter) : boardLists).filter((l) => !l.lost));

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
  function toggleListSphere(listId, on) {
    // Общая сфера: список переезжает в её календарь (или из неё — пока нельзя); из общей в обычную — тоже нельзя.
    if (isSharedSphere(activeSphere)) return toggleSharedList(listId, on, activeSphere);
    if (sh.isSharedId(listId)) { say('Список в общей сфере — его нельзя перенести в другую сферу.'); return; }
    touch('lists', listId, { sphere: on ? activeSphere : null }); saveLayer();
  }
  function deleteSphere(id = activeSphere) {
    if (isSharedSphere(id)) { askLeaveSphere(id); return; }
    for (const l of sphereLists(id)) touch('lists', l.id, { sphere: null });
    touch('spheres', id, { removed: true });
    saveLayer();
    sphereEditOpen = false;
    if (sphereFilter === id) sphereFilter = '';
    if (view === 'sphere' && activeSphere === id) view = 'board';
    say('Сфера удалена, списки — в «Без сферы»');
  }
  function newListIn(sid) { newListSphere = sid; newList = true; }

  // ---------- общие сферы (lib/shared.js, lib/sharedcore.js) ----------
  // Сфера в своём Google Календаре, которым владелец делится по почте. Её списки и задачи api.js отдаёт как обычные,
  // а поля слоя (колонка, этап, тема, приоритет…) сводим с записями календаря здесь: забрали — в слой, поменяли слой — в календарь.
  let shareErr = $state('');
  let sharePushTimer;
  layerStore.configure({
    canSync: () => phase === 'ready',
    afterSave: () => { clearTimeout(sharePushTimer); if (shared.calendars().length) sharePushTimer = setTimeout(pushShared, 1500); },
  });
  let sharePushing = null;
  let sharePanel = $state(null); // окно общей сферы: { id, mode: 'make' | 'people' }
  let joinOpen = $state(false);
  // Участники общих сфер живут в кэше shared.js; shareVer — чтобы экран перечитал их после обмена или правки.
  let shareVer = $state(0);
  const meEmail = $derived((shareVer, shared.myEmail()));
  const leaving = new Map(); // почта → таймер «Убрать» (6 с на «Отменить»)
  let hiddenPeople = $state([]); // «sid|почта», убранные, пока идут 6 с на «Отменить»
  /** Участники общей сферы по порядку, с цветами; у личной — пусто. */
  function peopleOf(sid) {
    void shareVer;
    const cal = sh.calOfSphere(sid);
    return cal ? shared.people(cal).filter((p) => !hiddenPeople.includes(`${sid}|${p.email}`)) : [];
  }
  /** Сфера по-настоящему общая (есть кто-то кроме владельца) — для метки «общая» и кружков. */
  const together = (sid) => isSharedSphere(sid) && sh.isTogether(peopleOf(sid));
  const isSharedSphere = (sid) => !!sid && sh.isSharedId(sid);

  /** Записи календарей, которые пришли или поменялись, — в слой; что поменяли здесь, пока их не было, — обратно. */
  function applyShared({ changes, gone }) {
    let changed = false;
    const back = [];
    const put = (sec, key, patch, t) => {
      lay[sec] ??= {};
      const cur = lay[sec][key] ?? {};
      lay[sec][key] = { ...cur, ...patch, t: Math.max(cur.t ?? 0, t || Date.now()) };
      changed = true;
    };
    const given = [], closed = [];
    const me = shared.myEmail();
    const active = new Set(shared.activeCalendars()); // приглашение до «Принять» в слой не попадает
    for (const { cal, k, base, rec } of changes) {
      if (!rec || !active.has(cal)) continue;
      const kind = sh.kindOf(k), t = sh.lastTime(rec);
      // Новую запись (base нет) считаем «отданной мне», только если её завели недавно — иначе при первом входе в сферу
      // посыпались бы уведомления обо всех старых задачах.
      if (sh.assignedToMe(base, rec, me) && (base || Date.now() - t < 15 * 60e3)) given.push({ cal, k, rec });
      if (kind === 'task' && base && base.f.status !== 'completed' && rec.f.status === 'completed' && rec.f.by && rec.f.by !== me && !rec.f.parent) closed.push({ cal, k, rec });
      if (kind === 'task') {
        const { toLayer, toRec } = sh.reconcile(lay.tasks?.[k], base, rec, 'task');
        if (Object.keys(toLayer).length) put('tasks', k, toLayer, t);
        if (Object.keys(toRec).length) back.push([cal, k, toRec]);
      } else if (kind === 'list') {
        const id = sh.listId(k);
        const { toLayer, toRec } = sh.reconcile(lay.lists?.[id], base, rec, 'list');
        if (Object.keys(toLayer).length) put('lists', id, toLayer, t);
        if (Object.keys(toRec).length) back.push([cal, k, toRec]);
      } else if (kind === 'sphere') {
        const { toLayer, toRec } = sh.reconcileSphere(lay.spheres?.[sh.sphereId(cal)], base, rec);
        if (Object.keys(toLayer).length) put('spheres', sh.sphereId(cal), toLayer, t);
        if (Object.keys(toRec).length) back.push([cal, k, toRec]);
      }
    }
    // У каждой сферы, где я участник, — запись в слое, у её списков — эта сфера. Приглашения ждут «Принять».
    for (const cal of shared.activeCalendars()) {
      const sid = sh.sphereId(cal);
      const S = lay.spheres?.[sid];
      if (S?.noAccess) put('spheres', sid, { noAccess: false });
      if (!S || S.removed || S.gone || !S.shared) {
        const rec = shared.sphereRec(cal);
        put('spheres', sid, { name: rec?.f?.name ?? 'Общая сфера', color: rec?.f?.color ?? 'gold', icon: rec?.f?.icon ?? 'users',
          order: S?.order ?? Math.max(0, ...spheres.map((x) => x.order ?? 0)) + 1, removed: false, gone: undefined, shared: { cal } });
      }
      for (const l of shared.lists().filter((x) => x.shared === cal)) if (lay.lists?.[l.id]?.sphere !== sid) put('lists', l.id, { sphere: sid });
    }
    // Доступа к календарю больше нет: сферу удалил владелец или нас убрали. Сфера остаётся бледной с «нет доступа».
    for (const cal of gone) {
      const sid = sh.sphereId(cal);
      if (lay.spheres?.[sid] && !lay.spheres[sid].removed) { put('spheres', sid, { noAccess: true }); say(`Нет доступа к сфере «${lay.spheres[sid].name}»: её удалили или тебя убрали из участников`); }
    }
    for (const g of given) {
      const name = shared.people(g.cal).find((p) => p.email === g.rec.f.by)?.name ?? sh.nameOf(g.rec.f.by);
      put('tasks', g.k, { given: { by: g.rec.f.by, name, at: new Date().toISOString() } });
    }
    if (changed) saveLayer();
    shareVer++;
    if (given.length) tellGiven(given);
    else if (closed.length) {
      // «Оля закрыла «…» · Вернуть» (docs/design-v2.md, «Общие сферы» 7).
      const c = closed[0], lid = sh.listId(c.rec.f.list ?? '');
      const name = shared.people(c.cal).find((p) => p.email === c.rec.f.by)?.name ?? sh.nameOf(c.rec.f.by);
      say(closed.length === 1 ? `${name} · сделано «${c.rec.f.title || 'Без названия'}»` : `Участники закрыли задач: ${closed.length}`,
        closed.length === 1 ? () => { const cur = findTask(lid, c.k); if (cur) toggle(cur, false, lid, true); } : null, 'Вернуть');
    }
    for (const [cal, k, p] of back) shared.patchRec(cal, k, p).catch(() => {});
  }

  /** Тебе отдали задачи: плашка в приложении и уведомление Windows (бот — через файл напоминаний, kind 'assigned'). */
  async function tellGiven(given) {
    const g = given[0], name = lay.tasks?.[g.k]?.given?.name ?? 'Участник';
    const title = g.rec.f.title || 'Без названия';
    const text = given.length === 1 ? `${name} отдаёт тебе «${title}»` : `Тебе отдали задач: ${given.length}`;
    const lid = sh.listId(g.rec.f.list ?? '');
    say(text, given.length === 1 && g.rec.f.list ? () => (openRef = { listId: lid, id: g.k }) : null, 'Открыть');
    if (lay.settings?.notify?.v === false) return;
    try {
      let ok = await notify.isPermissionGranted();
      if (!ok) ok = (await notify.requestPermission()) === 'granted';
      if (ok) notify.sendNotification({ title: 'Спутник · тебе отдали задачу', body: given.length === 1 ? `${name}: ${title}` : text });
    } catch { /* уведомления недоступны — плашка и бот всё равно скажут */ }
  }

  // «Сегодня» и календарь: из общих сфер — только мои и ничьи задачи (docs/design-v2.md, «Общие сферы» 5).
  const mineTasks = $derived((shareVer, sh.forMe(tasks, lay.tasks, meEmail, (lid) => sh.isSharedId(lid) && together(sphereOf(lid, lay)))));

  // ---------- состояния общей сферы (docs/design-v2.md, «Общие сферы» 6) ----------
  const invites = $derived((shareVer, shared.invites()));
  async function acceptInvite(inv) {
    try {
      await shared.accept(inv.cal);
      // Записи календаря уже скачаны, пока висело приглашение, — теперь кладём их в слой целиком.
      applyShared({ changes: Object.values(shared.storeOf(inv.cal)?.recs ?? {}).map((rec) => ({ cal: inv.cal, k: rec.k, base: null, rec })), gone: [] }); await refresh(); say(`Ты в сфере «${inv.name}»`); }
    catch (e) { say('Не удалось принять приглашение: ' + e); }
  }
  async function declineInvite(inv) {
    try { await shared.decline(inv.cal); shareVer++; say(`Приглашение в «${inv.name}» отклонено`); }
    catch (e) { say('Не получилось отказаться: ' + e); }
  }
  /** «Нет доступа» → «Убрать из колонки»: сфера и её списки уходят из колонки на этом компьютере. */
  async function forgetSphere(sid) {
    const cal = sh.calOfSphere(sid), name = lay.spheres?.[sid]?.name ?? '';
    await shared.forget(cal);
    touch('spheres', sid, { removed: true, noAccess: false });
    saveLayer();
    shareVer++;
    if (activeSphere === sid) view = 'board';
    await refresh();
    say(`Сфера «${name}» убрана из колонки`);
  }
  function askAccess(sid) {
    const cal = sh.calOfSphere(sid), owner = shared.people(cal).find((p) => p.owner);
    navigator.clipboard?.writeText(sh.askAccessText(lay.spheres?.[sid]?.name ?? '', owner?.email ?? '')).then(() => say('Письмо владельцу скопировано — вставь его в почту'), () => say('Не удалось скопировать'));
  }
  /** Сколько моих правок ещё не видел самый «отставший» участник сферы (плашка над доской). */
  function unseenOf(sid) {
    void shareVer;
    const cal = sh.calOfSphere(sid);
    if (!cal || !together(sid)) return null;
    const u = sh.unseenBy(shared.storeOf(cal)?.recs, peopleOf(sid), meEmail)[0];
    return u && u.n >= 2 ? u : null;
  }
  /** Задача отдана, а Спутник исполнителя её ещё не забрал — «ждёт Аню». */
  function waitOf(listId, taskId) {
    void shareVer;
    const cal = shared.calOfListId(listId);
    return cal ? sh.waitingFor(shared.storeOf(cal)?.recs?.[taskId], shared.people(cal), meEmail) : null;
  }

  /** Задача из строки «Сегодня» в общую сферу — сразу моя (в «Создать» по умолчанию «Никто»). */
  function mineByDefault(p) {
    if (!p?.listId || !sh.isSharedId(p.listId) || !together(sphereOf(p.listId, lay)) || p.layer?.who !== undefined) return p;
    return { ...p, layer: { ...(p.layer ?? {}), who: meEmail } };
  }

  /** Окно задачи в общей сфере: исполнитель, последнее чужое изменение, счётчики для выбора. */
  const drawerShare = $derived.by(() => {
    void shareVer;
    if (!openTask || !openRef || !sh.isSharedId(openRef.listId)) return null;
    const sid = sphereOf(openRef.listId, lay);
    if (!together(sid)) return null;
    const cal = shared.calOfListId(openRef.listId), people = peopleOf(sid), me = shared.myEmail();
    const rec = shared.storeOf(cal)?.recs?.[openTask.id];
    const cols = templateFor(openRef.listId).cols;
    return { people, me, who: sh.whoOf(lay.tasks?.[openTask.id]),
      change: sh.changeText(sh.editOf(rec), people, me, (c) => cols.find((x) => x.id === c)?.name ?? c),
      counts: sh.whoCounts(tasks[openRef.listId] ?? [], lay.tasks) };
  });
  // «Отдано тебе» гаснет, когда задачу открыли.
  $effect(() => { if (openTask && lay.tasks?.[openTask.id]?.given) untrack(() => { touch('tasks', openTask.id, { given: null }); saveLayer(); }); });

  /** Исполнитель задачи общей сферы (w — почта или null). «Отдано мне» снимается: сам выбрал. */
  function setWho(id, w) {
    touch('tasks', id, { who: w ?? null, ...(lay.tasks?.[id]?.given ? { given: null } : {}) });
    saveLayer();
  }

  // ---------- картинка задачи (lib/preview.js, lib/previewDrive.js) ----------
  /** Почему у задачи этого списка нельзя поставить картинку ('' — можно). */
  const previewOff = (listId) => (sh.isSharedId(listId) ? 'В общей сфере картинки пока не ставятся — их не увидят другие участники.' : '');
  /** Поставить или заменить картинку: маленькая копия — в слой, большая — на Drive. Старый файл убираем. */
  async function setPreview(id, file, title) {
    const old = lay.tasks?.[id]?.preview ?? null;
    const p = await pictures.make(file, title);
    touch('tasks', id, { preview: p });
    saveLayer();
    if (old?.file) pictures.remove(old.file);
  }
  /** Убрать картинку; «Отменить» 6 с — потом файл уходит и с Drive. */
  function clearPreview(id, title) {
    const old = lay.tasks?.[id]?.preview ?? null;
    if (!old) return;
    touch('tasks', id, { preview: null });
    saveLayer();
    let undone = false;
    say(`Картинка убрана: «${title || 'Без названия'}»`, () => { undone = true; touch('tasks', id, { preview: old }); saveLayer(); });
    setTimeout(() => { if (!undone && old.file && !lay.tasks?.[id]?.preview) pictures.remove(old.file); }, 7000);
  }

  /** Правки слоя общих задач, списков и сфер — в их календари. */
  async function pushShared() {
    if (sharePushing) { await sharePushing; }
    sharePushing = (async () => {
      for (const cal of shared.activeCalendars()) {
        const recs = shared.storeOf(cal)?.recs ?? {};
        for (const rec of Object.values(recs)) {
          const kind = sh.kindOf(rec.k);
          const L = kind === 'task' ? lay.tasks?.[rec.k] : kind === 'list' ? lay.lists?.[sh.listId(rec.k)] : lay.spheres?.[sh.sphereId(cal)];
          if (!L) continue;
          const { toRec } = kind === 'sphere' ? sh.reconcileSphere(L, rec, rec) : sh.reconcile(L, rec, rec, kind);
          if (!Object.keys(toRec).length) continue;
          try { await shared.patchRec(cal, rec.k, toRec); shareErr = ''; }
          catch (e) { shareErr = String(e); if (!api.isOffline(e)) say('Не удалось передать правку в общую сферу: ' + e); return; }
        }
      }
    })();
    try { await sharePushing; } finally { sharePushing = null; shareVer++; }
  }

  /** Раз в 30 с — изменения общих сфер (дёшево: Google отдаёт только новое). */
  async function shareTick() {
    if (phase !== 'ready' || sync.busy || !shared.calendars().length || document.hidden) return;
    const t0 = Date.now();
    const before = Object.fromEntries(Object.entries(tasks).map(([id, ts]) => [id, new Set(ts.map((t) => t.id))]));
    let r;
    try { r = await shared.pullAll({ discover: false }); shareErr = ''; } catch (e) { shareErr = String(e); return; }
    if (!r.changes.length && !r.gone.length) return;
    applyShared(r);
    const shl = shared.lists();
    lists = [...lists.filter((l) => !sh.isSharedId(l.id)), ...shl];
    for (const l of shl) tasks[l.id] = fresh.keepLocal(shared.tasks(l.id), tasks[l.id], before[l.id], touchedAt, t0);
    for (const id of Object.keys(tasks)) if (sh.isSharedId(id) && !shl.some((l) => l.id === id)) delete tasks[id];
  }
  onMount(() => { const h = setInterval(shareTick, 30e3); return () => clearInterval(h); });

  /** Перенести списки обычной сферы в общий календарь: задачи с подзадачами и полями слоя, потом удалить их из Google Tasks. */
  async function moveListsToShared(cal, sid, ls) {
    const def = await api.defaultListId().catch(() => null);
    for (const l of ls) {
      if (l.id === def) { say(`«${l.title}» — основной список Google Tasks, его перенести нельзя. Убери его из сферы и попробуй снова.`); return false; }
    }
    for (const l of ls) {
      say(`Переношу «${l.title}» в общую сферу…`);
      const L = lay.lists?.[l.id] ?? {};
      const { t: _t, gone: _g, hidden: _h, sphere: _s, ...listLayer } = L;
      const nl = await shared.createList(cal, l.title, listLayer);
      const all = tasks[l.id] ?? (await api.listTasks(l.id));
      const own = (id) => { const T = lay.tasks?.[id] ?? {}; return Object.fromEntries(['remind', 'spent', 'timer', 'inbox', 'pulled'].filter((k) => T[k] != null).map((k) => [k, T[k]])); };
      const shareable = (id) => Object.fromEntries(Object.entries(sh.sharedOf(lay.tasks?.[id], 'task')).map(([k, v]) => [k.slice(1), v]));
      const ids = new Map();
      const body = (x) => ({ title: x.title, notes: x.notes ?? '', ...(x.due ? { due: x.due } : {}), status: x.status, ...(x.completed ? { completed: x.completed } : {}) });
      // По порядку Google: первые сверху остаются сверху.
      const byPos = (a, b) => (b.position || '').localeCompare(a.position || '');
      for (const x of all.filter((x) => !x.parent).sort(byPos)) {
        const r = await shared.createTask(nl.id, body(x), null, shareable(x.id));
        ids.set(x.id, r.id);
        lay.tasks ??= {};
        lay.tasks[r.id] = { ...sh.layerOf(shared.storeOf(cal).recs[r.id]), ...own(x.id), t: Date.now() };
      }
      for (const x of all.filter((x) => x.parent && ids.has(x.parent)).sort(byPos)) {
        const r = await shared.createTask(nl.id, body(x), ids.get(x.parent), shareable(x.id));
        lay.tasks[r.id] = { ...sh.layerOf(shared.storeOf(cal).recs[r.id]), ...own(x.id), t: Date.now() };
      }
      lay.lists[nl.id] = { ...listLayer, sphere: sid, t: Date.now() };
      await api.deleteList(l.id);
      layerSync.forgetList(lay, l.id, all.map((x) => x.id));
      lists = [...lists.filter((x) => x.id !== l.id), nl];
      delete tasks[l.id];
      tasks[nl.id] = shared.tasks(nl.id);
      if (activeId === l.id) activeId = nl.id;
    }
    return true;
  }

  /** «Сделать общей» из окна (ShareSphere, mode 'make'): календарь, перенос списков, приглашения. */
  async function makeShared(id, emails = []) {
    const sp = spheres.find((s) => s.id === id);
    if (!sp) return;
    sharePanel = null;
    const ls = sphereLists(id);
    try {
      say(`Создаю общую сферу «${sp.name}»…`);
      const cal = await shared.createSphere({ name: sp.name, color: sp.color, icon: sp.icon });
      const sid = sh.sphereId(cal);
      touch('spheres', sid, { name: sp.name, color: sp.color, icon: sp.icon, order: sp.order, removed: false, shared: { cal } });
      touch('spheres', id, { removed: true });
      if (activeSphere === id) activeSphere = sid;
      if (sphereFilter === id) sphereFilter = sid;
      const ok = await moveListsToShared(cal, sid, ls);
      await saveLayer();
      for (const e of emails) await shared.invite(cal, e).catch((err) => say(`Не удалось позвать ${e}: ${err}`));
      shareVer++;
      if (ok) say(emails.length ? `Сфера «${sp.name}» теперь общая · позвали: ${emails.length}` : `Сфера «${sp.name}» теперь общая`, () => (sharePanel = { id: sid, mode: 'people' }), 'Участники');
    } catch (e) { saveLayer(); say('Не удалось сделать сферу общей: ' + e); }
  }

  /** Список — в общую сферу (с переносом) или из неё (пока нельзя). */
  async function toggleSharedList(listId, on, sid) {
    if (!on) { say('Вынести список из общей сферы пока нельзя — его можно удалить или перенести задачи в другой список.'); return; }
    const l = boardLists.find((x) => x.id === listId);
    if (!l) return;
    if (sh.isSharedId(listId)) { say('Список уже в другой общей сфере.'); return; }
    askDel = {
      title: `Перенести «${l.title}» в общую сферу?`,
      text: 'Его задачи переедут из Google Tasks в общий календарь сферы — их увидят все участники.',
      note: 'В приложении Google Tasks и на телефоне этого списка больше не будет.',
      yes: 'Перенести',
      danger: false,
      run: async () => {
        try { if (await moveListsToShared(sh.calOfSphere(sid), sid, [l])) say(`«${l.title}» — в общей сфере`); }
        catch (e) { say('Не удалось перенести список: ' + e); }
        saveLayer();
      },
    };
  }

  function askLeaveSphere(id) {
    const sp = spheres.find((s) => s.id === id);
    const cal = sh.calOfSphere(id);
    if (!sp || !cal) return;
    const owner = shared.isOwner(cal);
    askDel = {
      title: owner ? `Удалить общую сферу «${sp.name}»?` : `Выйти из сферы «${sp.name}»?`,
      text: owner ? 'Она удалится у всех участников вместе со списками и задачами.' : 'Сфера пропадёт из твоего Спутника, у остальных останется. Вернуться можно, если владелец позовёт снова.',
      note: owner ? 'Вернуть будет нельзя.' : '',
      yes: owner ? 'Удалить у всех' : 'Выйти',
      run: async () => {
        try { await shared.removeSphere(cal); }
        catch (e) { say((owner ? 'Не удалось удалить сферу: ' : 'Не удалось выйти: ') + e); return; }
        const gone = lists.filter((l) => l.shared === cal);
        for (const l of gone) { layerSync.forgetList(lay, l.id, (tasks[l.id] ?? []).map((t) => t.id)); delete tasks[l.id]; }
        lists = lists.filter((l) => l.shared !== cal);
        touch('spheres', id, { removed: true });
        saveLayer();
        if (view === 'sphere' && activeSphere === id) view = 'board';
        if (gone.some((l) => l.id === activeId)) activeId = boardLists[0]?.id ?? null;
        say(owner ? 'Общая сфера удалена' : 'Ты вышел из сферы');
      },
    };
  }

  /** «Как меня видят» (окно «Участники»): имя, цвет, фото — одно на все общие сферы, хранится в настройках слоя. */
  async function saveProfile(p) {
    const f = sh.profileFields(p);
    touch('settings', 'profile', f);
    saveLayer();
    try { await shared.applyProfile(f); shareVer++; say('Готово: так тебя видят во всех общих сферах'); }
    catch (e) { say('Не удалось обновить профиль в сферах: ' + e); }
  }

  async function inviteTo(sid, emails) {
    const cal = sh.calOfSphere(sid);
    let n = 0;
    for (const e of emails) {
      try { await shared.invite(cal, e); n++; } catch (err) { say(`Не удалось позвать ${e}: ${err}`); }
      shareVer++;
    }
    if (n) say(n === 1 ? `Позвали ${emails[0]} — Google пришлёт письмо` : `Позвали ${n} ${plural(n, ['человека', 'человек', 'человек'])} — Google пришлёт письма`);
  }

  /** «Убрать» / «Отозвать» — без вопроса, но 6 с на «Отменить» (docs/design-v2.md, «Общие сферы» 1). */
  function removePerson(sid, p) {
    const key = `${sid}|${p.email}`;
    hiddenPeople = [...hiddenPeople, key];
    const timer = setTimeout(async () => {
      leaving.delete(key);
      try { await shared.removeMember(sh.calOfSphere(sid), p.email); }
      catch (e) { say('Не удалось убрать: ' + e); }
      hiddenPeople = hiddenPeople.filter((x) => x !== key);
      shareVer++;
    }, 6000);
    leaving.set(key, timer);
    say(p.joined ? `${p.name} больше не в сфере` : `Приглашение ${p.email} отозвано`, () => {
      clearTimeout(leaving.get(key));
      leaving.delete(key);
      hiddenPeople = hiddenPeople.filter((x) => x !== key);
    });
  }

  function askStopSharing(sid) {
    const sp = spheres.find((s) => s.id === sid);
    const n = peopleOf(sid).filter((p) => !p.owner).length;
    askDel = {
      title: `Перестать делиться «${sp?.name ?? ''}»?`,
      text: `${n} ${plural(n, ['человек потеряет', 'человека потеряют', 'человек потеряют'])} доступ к сфере. У тебя всё останется как есть.`,
      note: 'Позвать снова можно в любой момент.',
      yes: 'Перестать делиться',
      run: async () => {
        try { await shared.stopSharing(sh.calOfSphere(sid)); say('Больше никто, кроме тебя, не видит эту сферу'); }
        catch (e) { say('Не удалось: ' + e); }
        shareVer++;
        sharePanel = null;
      },
    };
  }

  async function copyInvite(sid) {
    const sp = spheres.find((s) => s.id === sid);
    try { await navigator.clipboard.writeText(shared.inviteText(sh.calOfSphere(sid), sp?.name ?? '')); say('Приглашение скопировано — отправь его в любой мессенджер'); }
    catch { say('Не удалось скопировать'); }
  }

  async function joinSphere(code) {
    try {
      await shared.join(code);
      joinOpen = false;
      await refresh();
      const sid = sh.sphereId(code.trim());
      if (lay.spheres?.[sid]) { openSphere(sid); say(`Ты в сфере «${lay.spheres[sid].name}»`); }
    } catch (e) { say('Не удалось присоединиться: ' + (/404|403/.test(String(e)) ? 'нет доступа — попроси владельца позвать тебя по почте' : e)); }
  }

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
    if (sideMenu.kind === 'add') return [{ id: 'list', label: 'Новый список' }, { id: 'sphere', label: 'Новая сфера' }, { id: 'join', label: 'Войти в общую сферу…' }];
    if (sideMenu.kind === 'sphere') {
      const cal = sh.calOfSphere(sideMenu.id);
      if (cal) return [
        { id: 'open', label: 'Открыть сферу' },
        { id: 'edit', label: 'Изменить сферу' },
        { id: 'people', label: 'Участники…' },
        shared.isOwner(cal) ? { id: 'leave', label: 'Удалить у всех…', danger: true, sep: true } : { id: 'leave', label: 'Выйти из сферы…', danger: true, sep: true },
      ];
      return [
        { id: 'open', label: 'Открыть сферу' },
        { id: 'edit', label: 'Изменить сферу' },
        { id: 'share', label: 'Сделать общей…' },
        { id: 'delete', label: 'Удалить сферу…', danger: true, sep: true },
      ];
    }
    return [
      { id: 'open', label: 'Открыть доску' },
      { id: 'edit', label: 'Изменить список' },
      ...(sphereOf(sideMenu.id, lay) && !sh.isSharedId(sideMenu.id) ? [{ id: 'unsphere', label: 'Убрать из сферы' }] : []),
      { id: 'delete', label: 'Удалить список…', danger: true, sep: true },
    ];
  });

  function sideAction(a) {
    const { kind, id } = sideMenu;
    if (kind === 'add') {
      if (a === 'list') newListIn(null); else if (a === 'join') joinOpen = true; else createSphere();
    } else if (kind === 'sphere') {
      if (a === 'open') openSphere(id);
      else if (a === 'edit') { openSphere(id); sphereEditOpen = true; }
      else if (a === 'delete') askDeleteSphere(id);
      else if (a === 'share') sharePanel = { id, mode: 'make' };
      else if (a === 'people') sharePanel = { id, mode: 'people' };
      else if (a === 'leave') askLeaveSphere(id);
    } else {
      if (a === 'open') openList(id);
      else if (a === 'edit') listEdit = id;
      else if (a === 'unsphere') { touch('lists', id, { sphere: null }); saveLayer(); say('Список — в «Без сферы»'); }
      else if (a === 'delete') askDeleteList(id);
    }
  }

  // «Изменить список»: название, сфера и вид доски. Шаблон здесь не трогаем — он правится в «Шаблонах досок».
  let listEdit = $state(null);
  async function applyListEdit(id, { title, sphere, view: v }) {
    const l = lists.find((x) => x.id === id);
    if (!l) return;
    if (title && title !== l.title) {
      try {
        if (!sh.isSharedId(id)) await api.renameList(id, title);
        lists = lists.map((x) => (x.id === id ? { ...x, title } : x));
      } catch (e) { say('Не удалось переименовать: ' + e); return; }
    }
    if (!sh.isSharedId(id)) touch('lists', id, { sphere: sphere ?? null });
    touch('lists', id, { view: v });
    saveLayer();
    listEdit = null;
    say('Список изменён');
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
    if (sh.isSharedId(id)) {
      const n = (tasks[id] ?? []).filter((t) => !t.parent).length;
      askDel = { title: `Удалить список «${l.title}»?`, text: `Это список общей сферы: он удалится у всех участников${n ? ` вместе с задачами (${n})` : ''}.`, note: 'Вернуть будет нельзя.', yes: 'Удалить у всех', run: () => deleteList(id) };
      return;
    }
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
      const l = isSharedSphere(newListSphere) ? await shared.createList(sh.calOfSphere(newListSphere), title, { template }) : await api.createList(title);
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

  // Поля Спутника, которые прислал чат или бот, переносим в свой слой один раз: сферы, шаблон/вид/темы списков, поля задач.
  function pullInboxLayer() {
    const { spheres: sps, lists: lps, tasks: patches } = inbox.pullPatches(inboxSt, lay);
    for (const [id, rec] of sps) touch('spheres', id, rec);
    for (const [id, patch] of lps) touch('lists', id, patch);
    for (const [id, patch] of patches) {
      // Задачи из бота и чатов Claude тоже получают напоминание по умолчанию.
      if (remindDefault && !lay.tasks?.[id]?.remind) patch.remind = remindDefault;
      touch('tasks', id, patch);
    }
    if (sps.length || lps.length || patches.length) saveLayer();
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

  // Отметка сегодня; у привычки с целью на день (goal) — «+1», по достижении цели — сделано.
  function toggleHabit(h) {
    const day = api.ymd(new Date());
    const was = isDone(lay.log, h.id, day);
    touch('log', logKey(h.id, day), nextMark(lay.log, h, day));
    const done = isDone(lay.log, h.id, day);
    if (done === was) { saveLayer(); return; } // «+1», цель ещё не набрана
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

  // Привычки с «Напомнить: Windows» (habits[id].remind.win): уведомление, если к своему времени не отмечено.
  // Что уже показано сегодня — localStorage hb.win (у каждого компьютера своё).
  async function habitWin() {
    let sent = [];
    try { sent = JSON.parse(localStorage.getItem('hb.win') || '[]'); } catch {}
    const due = reminders.habitWinDue(habits, lay.log, sent);
    if (!due.length) return;
    const today = api.ymd(new Date());
    sent = [...sent.filter((k) => k.endsWith('|' + today)), ...due.map((h) => `${h.id}|${today}`)];
    try { localStorage.setItem('hb.win', JSON.stringify(sent)); } catch {}
    try {
      let ok = await notify.isPermissionGranted();
      if (!ok) ok = (await notify.requestPermission()) === 'granted';
      if (ok) for (const h of due) notify.sendNotification({ title: 'Спутник · привычка', body: `Пора: ${h.name}. Отметь, когда сделаешь — серия ждёт.` });
    } catch { /* уведомления недоступны */ }
  }

  // Отметка задним числом (меню дня в «Месяце» и в панели привычки): done | miss | skip («не считать»).
  function setHabitDay(h, day, state) {
    touch('log', logKey(h.id, day), dayMark(h, state));
    if (state === 'done' && day === api.ymd(new Date())) {
      const n = stats(h, lay.log).streak;
      if (MILESTONES.includes(n) && lay.habits?.[h.id]?.cheer?.key !== `${n}|${day}`) celebrate(h, n, day);
    }
    saveLayer();
  }

  // Веха серии (7 · 21 · 50 · 100): праздник на экране, уведомление Windows и сообщение бота (через файл напоминаний).
  let cele = $state(null); // { id, name, n }
  async function celebrate(h, n, day) {
    const text = `${h.name} — ${n} ${plural(n, unitForms(h))} подряд!`;
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

  // Поля окна привычки: name и всё, что живёт в слое habits[id] (days, time, part, perWeek, goal, icon, color, remind, tipHide).
  const HABIT_FIELDS = ['days', 'time', 'part', 'perWeek', 'goal', 'icon', 'color', 'remind', 'tipHide'];
  const habitPatch = (f) => Object.fromEntries(HABIT_FIELDS.filter((k) => k in f).map((k) => [k, f[k]]));
  async function createHabit(f) {
    const name = f.name;
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
      touch('habits', t.id, { ...habitPatch(f), createdAt: api.ymd(new Date()) });
      saveLayer();
    } catch (e) { say('Не удалось добавить привычку: ' + e); }
  }

  async function updateHabit(id, f) {
    const name = f.name;
    touch('habits', id, habitPatch(f));
    saveLayer();
    const t = (tasks[habitList.id] ?? []).find((x) => x.id === id);
    if (t && name && t.title !== name) {
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
    layerStore.reset();
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
  // Акцент: settings.accent.v = набор или свой «#RRGGBB» → <style id="sp-accent"> поверх токенов (lib/accent.js).
  // Пока слой грузится — цвет с прошлого запуска (localStorage sp.accent), чтобы не мигала глина.
  let accentLast = null;
  try { accentLast = localStorage.getItem('sp.accent'); } catch {}
  const accentPref = $derived(phase === 'loading' ? accentLast : lay.settings?.accent?.v ?? null);
  $effect(() => {
    const css = accentCss(accentPref);
    if (phase !== 'loading') try { accentPref ? localStorage.setItem('sp.accent', accentPref) : localStorage.removeItem('sp.accent'); } catch {}
    let el = document.getElementById('sp-accent');
    if (!css) { el?.remove(); return; }
    if (!el) { el = document.createElement('style'); el.id = 'sp-accent'; document.head.appendChild(el); }
    el.textContent = css;
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
        {#each VIEWS as id, i (id)}
          {@const tab = shell.VIEW_TABS.find((t) => t.id === id)}
          <button class="hd-tab" role="tab" aria-selected={section(view) === id} title="Клавиша {i + 1} · Q / E — соседний раздел" onclick={() => go(id)}>{tab.name}{#if id === 'today' && todayCount}<span class="cnt hot" title="На сегодня и просрочено">{todayCount}</span>{:else if id === 'habits' && habitsLeft}<span class="cnt" title="Осталось отметить сегодня">{habitsLeft}</span>{/if}</button>
        {/each}
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
        <Side {spheres} listsOf={sphereLists} {peopleOf} {together} me={meEmail} noSphere={noSphereLists} count={openCount} viewOf={viewFor} {activeId}
          current={view} {activeSphere} folded={(id) => !!lay.settings?.sphereFold?.[id]}
          tips={view === 'board' && activeList ? boardTips : []} tipsOn={tipsOn}
          pinned={sidePinned} hold={!!sideMenu}
          onlist={openList} onsphere={openSphere} onfold={foldSphere} onmenu={openSideMenu} onadd={openAddMenu}
          ontemplates={() => (view = 'templates')} onarchive={() => (view = 'archive')}
          onshow={() => openSettings('show')} onpin={togglePin} ontip={runTip} ontiphide={hideTips}
          onregister={(api) => (sideApi = api)} />
      {/if}

      <div class="main">
        {#snippet sphFilter()}<SphereFilter {spheres} value={sphereFilter} onchange={(v) => (sphereFilter = v)} />{/snippet}
        {#if (view === 'today' || view === 'board') && invites.length}
          <div class="sh-invs">{#each invites as inv (inv.cal)}<ShareStates kind="invite" invite={inv} onaccept={() => acceptInvite(inv)} ondecline={() => declineInvite(inv)} />{/each}</div>
        {/if}
        {#if view === 'today'}
          <Today lists={shownLists} tasksByList={mineTasks} {events} layTasks={lay.tasks} layer={lay} log={lay.log} {habits}
            {inboxItems} inboxOn={!!inboxSt} {inboxFocus} {typeOf}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            ontoggle={(t, d, listId, quiet) => toggle(t, d, listId, quiet)}
            oncreate={(p, loud = false) => quickCreate(mineByDefault(p), !loud)} onreschedule={rescheduleMany} ontogglehabit={toggleHabit}
            onaccept={acceptInbox} onreject={rejectInbox}
            onregister={(fn) => (quickLine = fn)} onlearn={learnRoute} onfull={(line) => { if (boardLists.length) quick = { line }; }}
            onhabits={() => (view = 'habits')} oncalendar={() => (view = 'calendar')} filter={sphFilter} />
        {:else if view === 'calendar'}
          <Calendar lists={shownLists} tasksByList={mineTasks} layTasks={lay.tasks} log={lay.log} {habits} {typeOf}
            loadEvents={api.eventsRange} syncAt={sync.at} reloadKey={calReload} oncreatebirthday={createBirthday}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            ontoggle={(t, d, listId) => toggle(t, d, listId)}
            ontogglehabit={toggleHabit}
            onschedule={schedule}
            oncreatetask={(p) => quickCreate(p)}
            oncreateevent={createEvent} filter={sphFilter} />
        {:else if view === 'habits'}
          <Habits {habits} log={lay.log} {cele} open={habitOpen} onopened={() => (habitOpen = null)} onregister={(fn) => (habitForm = fn)} ontoggle={toggleHabit} onday={setHabitDay} onclosecele={() => (cele = null)}
            oncreate={createHabit} onupdate={updateHabit} ondelete={deleteHabit} />
        {:else if view === 'templates'}
          <Templates templates={allTemplates} usage={templateUsage} count={templateCount} current={activeList ? templateFor(activeId).id : null}
            onsave={saveTemplate} onreset={resetTemplate} oncreate={createTemplate} ondelete={deleteTemplate} onback={() => (view = 'board')} />
        {:else if view === 'sphere' && curSphere?.noAccess}
          <ShareStates kind="lost" sphere={curSphere.name} onask={() => askAccess(curSphere.id)} onforget={() => forgetSphere(curSphere.id)} />
        {:else if view === 'sphere' && curSphere}
          <SphereView sphere={curSphere} lists={sphereLists(curSphere.id)} tasksByList={tasks} {templateFor} {colOf}
            people={together(curSphere.id) ? peopleOf(curSphere.id) : []} me={meEmail} layTasks={lay.tasks}
            onshare={() => (sharePanel = { id: curSphere.id, mode: isSharedSphere(curSphere.id) ? 'people' : 'make' })}
            onedit={() => (sphereEditOpen = true)} onaddlist={() => newListIn(curSphere.id)}
            onopenlist={openList} onopentask={(t, listId) => (openRef = { listId, id: t.id })} />
        {:else if view === 'archive'}
          <Archive lists={boardLists} tasksByList={tasks} {activeId} jar={(listId) => viewFor(listId) === 'stickers'}
            onopen={(t, listId) => (openRef = { listId, id: t.id })}
            onrestore={(t, listId) => move(t, templateFor(listId).cols[0].id, listId)}
            onback={() => (view = 'board')} />
        {:else if activeList?.lost || lay.spheres?.[sphereOf(activeId, lay)]?.noAccess}
          <ShareStates kind="lost" sphere={lay.spheres?.[sphereOf(activeId, lay)]?.name ?? activeList.title}
            onask={() => askAccess(sphereOf(activeId, lay))} onforget={() => forgetSphere(sphereOf(activeId, lay))} />
        {:else if activeList}
          {#key activeId}
          <div class="board-swap" in:motion.fade={{ duration: 160 }}>
          {#if unseenOf(sphereOf(activeId, lay))}<ShareStates kind="unseen" unseen={unseenOf(sphereOf(activeId, lay))} />{/if}
          <Board list={activeList} tasks={tasks[activeId] ?? []} template={templateFor(activeId)} {colOf} {remindOf} {typeOf}
            view={viewFor(activeId)} onview={(v) => { touch('lists', activeId, { view: v }); saveLayer(); }}
            ontoggle={(t, d) => toggle(t, d, activeId, true)}
            onaddsub={(t, title, stage) => addSubTo(activeId, t, title, stage)}
            act={boardAct} layList={lay.lists?.[activeId] ?? {}} lists={boardLists.filter((l) => l.id !== activeId)} sphereName={spheres.find((s) => s.id === sphereOf(activeId, lay))?.name ?? ''}
            share={together(sphereOf(activeId, lay)) ? { people: peopleOf(sphereOf(activeId, lay)), me: meEmail, owner: shared.isOwner(sh.calOfSphere(sphereOf(activeId, lay))),
              oninvite: () => (sharePanel = { id: sphereOf(activeId, lay), mode: 'people' }),
              mode: lay.settings?.whoFilter?.[activeId] ?? 'all', waitOf: (id) => waitOf(activeId, id), onmode: (m) => { touch('settings', 'whoFilter', { [activeId]: m }); saveLayer(); } } : null} fold={boardFold} onfold={foldCol}
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
      preview={lay.tasks?.[openTask.id]?.preview ?? null} previewOff={previewOff(openRef.listId)}
      onpreview={(f) => setPreview(openTask.id, f, openTask.title)} onpreviewclear={() => clearPreview(openTask.id, openTask.title)}
      share={drawerShare} onwho={(w) => setWho(openTask.id, w)}
      spent={worktime.spentMin(lay.tasks?.[openTask.id], nowTick)} running={runId === openTask.id}
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
      peopleOf={(lid) => { const sid = sphereOf(lid, lay); return sh.isSharedId(lid) && together(sid) ? peopleOf(sid) : []; }} me={meEmail}
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
  {#if sharePanel && spheres.some((x) => x.id === sharePanel.id)}
    {@const sid = sharePanel.id}
    <ShareSphere mode={sharePanel.mode} sphere={spheres.find((x) => x.id === sid)} people={peopleOf(sid)} me={meEmail}
      owner={sharePanel.mode === 'make' || shared.isOwner(sh.calOfSphere(sid))} listNames={sphereLists(sid).map((l) => l.title)}
      onmake={(emails) => makeShared(sid, emails)} oninvite={(emails) => inviteTo(sid, emails)} onremove={(p) => removePerson(sid, p)}
      profile={lay.settings?.profile} onprofile={saveProfile} onstop={() => askStopSharing(sid)} onleave={() => { sharePanel = null; askLeaveSphere(sid); }} oncopy={() => copyInvite(sid)}
      onclose={() => (sharePanel = null)} />
  {/if}
  {#if joinOpen}
    <ShareSphere mode="join" onjoin={joinSphere} onclose={() => (joinOpen = false)} />
  {/if}

  {#if askDel}
    <ConfirmDelete title={askDel.title} text={askDel.text} note={askDel.note} yes={askDel.yes} danger={askDel.danger ?? true} onconfirm={confirmDel} onclose={() => (askDel = null)} />
  {/if}

  {#if listEdit}
    {@const el = lists.find((x) => x.id === listEdit)}
    {#if el}
      <EditList list={el} sphere={sphereOf(el.id, lay) ?? null} {spheres} view={viewFor(el.id)} shared={sh.isSharedId(el.id)} onsave={(p) => applyListEdit(el.id, p)} onclose={() => (listEdit = null)} />
    {/if}
  {/if}

  {#if newList}
    <NewList templates={allTemplates} name={newListName} oncreate={createList} onclose={() => { newList = false; newListSphere = null; newListName = ''; }} />
  {/if}
{/if}

<Toast />
