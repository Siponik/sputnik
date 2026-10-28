<script>
  import { fade, pop } from './motion.js';
  import { untrack, tick } from 'svelte';
  import { ymd } from './api.js';
  import { TYPES, PRIORITIES, autosize } from './meta.js';
  import { REPEATS } from './repeat.js';
  import { boardOf, colColor, VIEWS } from './templates.js';
  import { topicsOf, topicColor, plusDays } from './stickers.js';
  import { spheresFrom, sphereOf, sphereColor } from './spheres.js';
  import { leadName, leadsText, fireAt } from './reminders.js';
  import { parseLine, route, learn, viewOf, projectsOf } from './route.js';
  import * as cr from './create.js';
  import DateTimePicker from './DateTimePicker.svelte';
  import RemindChips from './RemindChips.svelte';
  import Coon from './Coon.svelte';
  import Avatar from './Avatar.svelte';
  import { memberByWord } from './sharedcore.js';

  // Окно «Создать» v2 (docs/design-v2.md — «Окно «Создать» v2», макеты design/screens/Create.dc.html и CreateMore.dc.html):
  // умная строка → «Куда» (lib/route.js) → поля по виду доски → превью справа. Событие и день рождения — в Google Календаре.
  // Вызовы как у прежнего окна: кнопка «Новая задача», N / Ctrl+N; listId — открытая доска, from — колонка/тема/проект места вызова.
  let {
    lists, listId = null, from = {}, day = '', s = '', e = '', line = '',
    layer = {}, tasksByList = {},
    dueDays = new Set(), loadEvents = null, loadCalendars = null,
    remindDefaults = { task: [], event: [], birthday: [] }, onremindDefault = null,
    peopleOf = () => [], me = '', // общая сфера: участники списка (пусто — сфера личная или в ней никого, кроме владельца)
    oncreate, oncreateevent, oncreatebirthday, onlearn = null, onnewlist = null, onclose,
  } = $props();

  const today = ymd(new Date());
  const KINDS = [
    { id: 'task', label: 'Задача', key: '1' },
    { id: 'event', label: 'Событие', key: '2' },
    { id: 'birthday', label: 'День рождения', key: '3' },
  ];
  const VIEW_NAME = Object.fromEntries(VIEWS.map((v) => [v.id, v.name]));
  // Тип для цвета по шаблону списка — как в App (typeOf).
  const TPL_TYPE = { work: 'work', client: 'work', asset3d: 'creative', personal: 'personal', study: 'study' };
  const TYPE_TAG = { asset: 'creative', work: 'work', client: 'work', study: 'study', personal: 'personal', 'ассет': 'creative', 'работа': 'work', 'клиент': 'work', 'учеба': 'study', 'учёба': 'study', 'личное': 'personal' };

  // ---------- состояние ----------
  const init = untrack(() => ({ list: listId, day, s, e, from: { ...from }, rem: { ...remindDefaults }, line }));
  let kind = $state('task');
  let text = $state(init.line); // Shift+Enter в строке «Сегодня» — текст оттуда
  let off = $state({}); // куски, возвращённые в текст крестиком: when, prio, at, tag, topic, project
  let manualList = $state(null);
  let manualTopic = $state(init.from.topic ?? null);
  let manualCol = $state(init.from.col ?? null);
  let manualProject = $state(init.from.project ?? null);
  let manualPrio = $state(undefined);
  let whenSet = $state(init.day ? { day: init.day, slot: init.s ? { s: init.s, e: init.e || cr.addMin(init.s, 60) } : null } : null);
  let stage = $state(null);
  let pin = $state(false);
  let subs = $state([]);
  let subDraft = $state('');
  let notes = $state('');
  let repeat = $state(undefined);
  let type = $state(null);
  let client = $state('');
  let money = $state('');
  let moreOpen = $state(false);
  let remOpen = $state(false);
  let rems = $state(init.rem);
  let newProject = $state(null); // строка ввода «＋ Новый проект»
  let picking = $state(false);
  let pickOpen = $state(false);
  let busy = $state(false);
  // событие и день рождения
  let calId = $state('primary');
  let cals = $state([]);
  let place = $state('');
  let year = $state('');
  let gift = $state(true);
  let dayEvents = $state([]);

  // ---------- умная строка ----------
  const topicNames = $derived(lists.filter((l) => viewOf(l.id, layer) === 'stickers').flatMap((l) => topicsOf(layer?.lists?.[l.id]).map((t) => t.name.toLowerCase())));
  const knownTag = (t) => !!t && (TYPE_TAG[t.toLowerCase()] || topicNames.some((n) => n.startsWith(t.toLowerCase().replace(/ё/g, 'е'))));
  const parsed = $derived.by(() => {
    const p = parseLine(text, { today: new Date(), off });
    return p.tag && !knownTag(p.tag) ? parseLine(text, { today: new Date(), off: { ...off, tag: true } }) : p;
  });

  // «@аня» — участник какой-нибудь общей сферы, а не список: в «Куда» не идёт, ставит исполнителя.
  const allPeople = $derived.by(() => {
    const seen = new Map();
    for (const l of lists) for (const p of peopleOf(l.id)) if (!seen.has(p.email)) seen.set(p.email, p);
    return [...seen.values()];
  });
  const atWho = $derived(parsed.at ? memberByWord(allPeople, parsed.at) : null);

  // Пересчёт «Куда» — с задержкой 150 мс после ввода.
  const routeSrc = $derived([parsed.at && !atWho ? `@${parsed.at}` : '', parsed.tag ? `#${parsed.tag}` : '', parsed.rest].join(' '));
  let routeText = $state(untrack(() => routeSrc));
  $effect(() => {
    const v = routeSrc;
    const id = setTimeout(() => (routeText = v), 150);
    return () => clearTimeout(id);
  });
  const ranked = $derived(route(routeText, { lists, layer, tasks: tasksByList, current: init.list }));
  const dest = $derived(manualList ?? ranked[0]?.listId ?? init.list ?? lists[0]?.id);
  const destList = $derived(lists.find((l) => l.id === dest));
  const destR = $derived(ranked.find((r) => r.listId === dest) ?? {});
  const why = $derived(manualList ? 'выбрано вручную' : destR.why ?? 'текущая доска');
  const alts = $derived(ranked.filter((r) => r.listId !== dest).slice(0, 2).map((r) => lists.find((l) => l.id === r.listId)).filter(Boolean));
  const view = $derived(viewOf(dest, layer));
  // «Кто делает» (только в общей сфере): undefined — не выбирали руками; по умолчанию — @имя из строки или «Никто».
  const destPeople = $derived(peopleOf(dest));
  let manualWho = $state(undefined);
  const who = $derived(!destPeople.length ? null : manualWho !== undefined ? manualWho
    : atWho && destPeople.some((p) => p.email === atWho.email) ? atWho.email : null);
  const whoRows = $derived([...destPeople.filter((p) => p.email === me), ...destPeople.filter((p) => p.email !== me)]);
  const tpl = $derived(boardOf(dest, layer));
  const spheres = $derived(spheresFrom(layer));
  const sphereFor = (id) => spheres.find((x) => x.id === sphereOf(id, layer)) ?? null;
  const colorOf = (id) => { const sp = sphereFor(id); return sp ? sphereColor(sp) : 'var(--ink-faint)'; };
  const destTasks = $derived(tasksByList[dest] ?? []);
  const layTasks = $derived(layer?.tasks ?? {});

  // Название: без «для таверны», если таверна стала проектом.
  const projectAuto = $derived(view === 'pipe' && !off.project && !manualProject ? destR.project ?? null : null);
  const title = $derived.by(() => {
    let t = parsed.title;
    if (projectAuto && destR.projectWord) t = t.replace(new RegExp(`\\s+(для|в|во)\\s+${destR.projectWord}(?=\\s|$)`, 'i'), '').trim();
    return t;
  });

  // Тема стикера: вручную → #тема → угаданная → место вызова.
  const topics = $derived(view === 'stickers' ? topicsOf(layer?.lists?.[dest]) : []);
  const tagTopic = $derived(parsed.tag ? topics.find((t) => t.name.toLowerCase().replace(/ё/g, 'е').startsWith(parsed.tag.toLowerCase().replace(/ё/g, 'е'))) ?? null : null);
  const autoTopic = $derived(!off.topic && !tagTopic && destR.topic && topics.some((t) => t.id === destR.topic) ? destR.topic : null);
  // manualTopic: '' — тему сняли руками, «Разное».
  const topic = $derived(manualTopic === '' ? null : manualTopic && topics.some((t) => t.id === manualTopic) ? manualTopic : tagTopic?.id ?? autoTopic);
  const topicObj = $derived(topics.find((t) => t.id === topic) ?? null);

  // Срок: выбран кнопками / в окне «Когда» — главнее текста.
  const due = $derived(whenSet ? whenSet.day : parsed.day);
  const slot = $derived(whenSet ? whenSet.slot : parsed.time ? { s: parsed.time, e: cr.addMin(parsed.time, 60) } : null);
  const dueDay = $derived(due ?? (slot ? today : null));
  const priority = $derived(manualPrio !== undefined ? manualPrio : parsed.priority);
  const repeatRule = $derived(repeat !== undefined ? repeat : parsed.repeat);
  const autoType = $derived(TPL_TYPE[tpl.id] ?? 'work');
  const tagType = $derived(parsed.tag && !tagTopic ? TYPE_TAG[parsed.tag.toLowerCase()] ?? null : null);

  // Колонка канбана (кроме последней «Готово»), этап конвейера.
  const cols = $derived(tpl.cols.filter((c) => c.id !== 'done'));
  const col = $derived(cols.some((c) => c.id === manualCol) ? manualCol : cols[0]?.id);
  const colObj = $derived(cols.find((c) => c.id === col));
  const stageId = $derived(cols.some((c) => c.id === stage) ? stage : cols[0]?.id);
  const projects = $derived(view === 'pipe' ? projectsOf(destTasks, layTasks) : []);
  const project = $derived(manualProject ?? projectAuto);
  const checklist = $derived(view === 'pipe' ? cr.stageChecklist(destTasks, layTasks) : []);
  const remind = $derived(rems[kind] ?? []);
  const sameMins = (a, b) => a.length === b.length && a.every((x) => b.includes(x));
  const isDefault = $derived(sameMins(remind, remindDefaults[kind] ?? []));

  // ---------- «Понял:» ----------
  const toks = $derived.by(() => {
    const out = [];
    if (parsed.day || parsed.time) out.push({ k: 'when', l: [parsed.day ? cr.shortDay(parsed.day) : 'сегодня', parsed.time].filter(Boolean).join(' · ') });
    if (parsed.repeat) out.push({ k: 'repeat', l: REPEATS.find((r) => r.id === parsed.repeat.every)?.short ?? '' });
    if (parsed.priority) { const p = PRIORITIES.find((x) => x.id === parsed.priority); out.push({ k: 'prio', l: `${p.mark} ${p.label.toLowerCase()}`, c: parsed.priority === 1 ? 'var(--clay)' : parsed.priority === 2 ? 'var(--gold)' : 'var(--ink-faint)' }); }
    if (parsed.at && atWho) out.push({ k: 'at', l: destPeople.some((p) => p.email === atWho.email) ? `делает: ${atWho.email === me ? 'я' : atWho.name}` : `@${parsed.at} — не в этой сфере` });
    else if (parsed.at) out.push({ k: 'at', l: destR.why?.startsWith('указано @') ? `список: ${destList?.title}` : `@${parsed.at} — нет такого списка` });
    if (tagTopic) out.push({ k: 'tag', l: `тема: ${tagTopic.name}`, c: topicColor(tagTopic) });
    else if (tagType) out.push({ k: 'tag', l: `тип: ${TYPES.find((t) => t.id === tagType)?.label}`, c: `var(--type-${tagType})` });
    if (kind === 'task' && autoTopic && !manualTopic) { const t = topics.find((x) => x.id === autoTopic); out.push({ k: 'topic', l: `тема: ${t.name}`, c: topicColor(t), auto: true, title: `Тема угадана ${destR.topicWhy ?? ''}` }); }
    if (kind === 'task' && projectAuto) out.push({ k: 'project', l: `проект: ${projectAuto}`, c: 'var(--clay)', auto: true, title: `По слову «${destR.projectWord}»` });
    return out;
  });
  function dropTok(k) { off = { ...off, [k]: true }; }

  // Подсветка распознанного прямо в тексте: зеркало под прозрачным полем.
  const segs = $derived.by(() => {
    const out = [];
    let i = 0;
    for (const m of parsed.marks) {
      if (m.from > i) out.push({ t: text.slice(i, m.from) });
      out.push({ t: text.slice(m.from, m.to), k: m.kind });
      i = m.to;
    }
    out.push({ t: text.slice(i) });
    return out;
  });
  let input = $state(null);
  let mirror = $state(null);
  const syncScroll = () => { if (mirror && input) mirror.scrollLeft = input.scrollLeft; };

  // ---------- выбор ----------
  function pickList(id) { manualList = id; pickOpen = false; input?.focus(); }
  function setWhen(day, slot = null) { whenSet = { day, slot }; }
  function applyWhen(r) { picking = false; whenSet = { day: r.day ?? null, slot: r.slot ?? null }; }
  function addSub() { const t = subDraft.trim(); if (t) subs = [...subs, t]; subDraft = ''; }

  // Стикер: «Когда».
  const whenChip = $derived(cr.whenChip(dueDay, today));
  const weekLabel = $derived(whenChip === 'week' ? `На неделе · ${cr.weekday(dueDay)}` : 'На неделе');
  // Короткие напоминания у стикера и события, остальное — «Ещё…».
  const quickLeads = $derived(kind === 'event' ? [15, 60] : [60, 1440]);
  const remLabel = (min) => (kind === 'task' && min === 1440 && !slot ? 'За день · в 10:00' : leadName(min, kind));
  function setRemind(v) { rems = { ...rems, [kind]: v }; }

  // ---------- событие ----------
  const DURS = [[15, '15 мин'], [30, '30 мин'], [45, '45 мин'], [60, '1 ч'], [120, '2 ч']];
  const evDur = $derived(slot ? cr.toMin(slot.e) - cr.toMin(slot.s) : 0);
  function setDur(min) {
    const d = dueDay ?? today;
    if (!min) { setWhen(d, null); return; }
    const s = slot?.s ?? cr.fromMin(Math.min(Math.ceil((new Date().getHours() * 60 + new Date().getMinutes()) / 60) * 60, 1380));
    setWhen(d, { s, e: cr.addMin(s, min) });
  }
  $effect(() => {
    if (kind !== 'event' || !loadCalendars || cals.length) return;
    loadCalendars().then((all) => {
      cals = (all ?? []).filter((c) => ['owner', 'writer'].includes(c.accessRole) && !/#(contacts|holiday)@/.test(c.id));
      const p = cals.find((c) => c.primary);
      if (p) calId = p.id;
    }).catch(() => {});
  });
  $effect(() => {
    if (kind !== 'event' || !loadEvents || !dueDay) return;
    const d = dueDay;
    const [y, m, dd] = d.split('-').map(Number);
    loadEvents(new Date(y, m - 1, dd), new Date(y, m - 1, dd + 1)).then((r) => { if (d === dueDay) dayEvents = r ?? []; }).catch(() => {});
  });
  const free = $derived(kind === 'event' && dueDay ? cr.freeCheck(dayEvents, dueDay, slot) : null);

  // ---------- день рождения ----------
  // «Подарок …» — в список со стикерами, где больше всего дел (личный), иначе в список шаблона «Личное».
  const openN = (id) => (tasksByList[id] ?? []).filter((t) => !t.parent && t.status !== 'completed').length;
  const giftList = $derived(lists.filter((l) => viewOf(l.id, layer) === 'stickers').sort((a, b) => openN(b.id) - openN(a.id))[0]
    ?? lists.find((l) => boardOf(l.id, layer).id === 'personal') ?? null);
  const bday = $derived(dueDay ? cr.nextBirthday(dueDay, today) : null);
  const age = $derived(bday ? cr.ageAt(year, bday, today) : null);
  const giftTitle = $derived(`Подарок ${cr.dative(title || 'имениннику')}`);

  // ---------- превью и подсказка енота ----------
  const prioCls = (p) => (p === 1 ? 'p1' : p === 2 ? 'p2' : p === 3 ? 'p3' : '');
  const pvWhen = $derived(cr.dueShort(dueDay, today, slot));
  const remRules = $derived(remind.length ? (remind.length === 1 ? { kind: 'lead', min: remind[0] } : remind.map((min) => ({ kind: 'lead', min }))) : null);
  const remShort = $derived(remind.length ? leadsText(remind, kind).replace(/^за /, 'за ') : '');
  const fire = $derived.by(() => {
    if (!remind.length || !dueDay) return null;
    const ds = remind.map((min) => fireAt({ kind: 'lead', min }, { due: `${dueDay}T00:00:00.000Z` }, slot)).filter((d) => d && d > new Date()).sort((a, b) => a - b);
    return ds[0] ?? null;
  });
  const WDA = ['в воскресенье', 'в понедельник', 'во вторник', 'в среду', 'в четверг', 'в пятницу', 'в субботу'];
  const fireText = $derived.by(() => {
    if (!fire) return '';
    const d = ymd(fire), hm = `${String(fire.getHours()).padStart(2, '0')}:${String(fire.getMinutes()).padStart(2, '0')}`;
    const when = d === today ? 'сегодня' : d === plusDays(today, 1) ? 'завтра' : cr.plus(today, 7) > d ? WDA[fire.getDay()] : cr.shortDay(d);
    return `Напомню в Telegram ${when} в ${hm}.`;
  });
  const colN = (c) => cr.colCount(destTasks, layTasks, c.id, tpl.cols[0].id);
  const tip = $derived.by(() => {
    if (view === 'stickers') return `У стикеров нет этапов — только тема и «когда». ${fireText || (dueDay ? '' : 'Без срока стикер ляжет в «Когда-нибудь».')}`.trim();
    if (view === 'pipe') {
      const st = cols.find((c) => c.id === stageId)?.name ?? '';
      return checklist.length
        ? `Чек-лист этапа «${st}» возьмётся из прошлого ассета — его можно поправить в окне задачи.`
        : `Ассет начнёт с этапа «${st}». Подзадачи этапа добавишь в строке Конвейера.`;
    }
    if (view === 'kanban') {
      const lim = cols.find((c) => c.limit && colN(c) >= c.limit - 1);
      const first = `Новые задачи ложатся во «${cols[0].name}».`;
      if (colObj?.limit && colN(colObj) + 1 > colObj.limit) return `«${colObj.name}» уже ${colN(colObj)} из ${colObj.limit} — задача будет сверх лимита.`;
      if (lim) return `${col === cols[0].id ? first + ' ' : ''}«${lim.name}» уже ${colN(lim)} из ${lim.limit} — если положить туда, будет на пределе.`;
      return fireText || first;
    }
    return fireText || 'Срок и подзадачи-уроки — как в канбане, только без колонок.';
  });
  const lands = $derived.by(() => {
    const n = destList?.title ?? '';
    if (view === 'stickers') return [`Доска «${n}», тема `, topicObj?.name ?? 'Разное', `, в раскладке по срокам — «${{ today: 'Сегодня', week: 'На неделе', later: 'Когда-нибудь', date: 'Когда-нибудь' }[whenChip]}».`];
    if (view === 'pipe') return [`Конвейер «${n}», группа `, project ?? 'без проекта', `, этап «${cols.find((c) => c.id === stageId)?.name ?? ''}».`];
    if (view === 'kanban') return [`Доска «${n}», колонка `, colObj?.name ?? '', ' — сверху.'];
    return [`Список «${n}»`, '', subs.length ? `, ${subs.length} ${subs.length === 1 ? 'подзадача' : 'подзадачи'}.` : '.'];
  });

  // ---------- создать ----------
  const canSubmit = $derived(!!title && !busy && (kind === 'task' ? !!dest : !!dueDay));

  async function submit(more = false) {
    if (!canSubmit) return;
    busy = true;
    let ok;
    try {
      if (kind === 'task') ok = await createTask();
      else if (kind === 'event') ok = await oncreateevent({ title, day: dueDay, slot, notes: notes.trim(), remind, calendarId: calId, location: place.trim() });
      else {
        ok = await oncreatebirthday({ name: title, day: dueDay, remind, year: Number(year) || null });
        if (ok && gift && giftList) {
          const g = cr.plus(bday, -7);
          const giftTopic = topicsOf(layer?.lists?.[giftList.id]).find((t) => t.id === 'buy')?.id;
          await oncreate({ title: giftTitle, listId: giftList.id, due: g < today ? today : g, slot: null, layer: giftTopic && viewOf(giftList.id, layer) === 'stickers' ? { topic: giftTopic } : {} }, true);
        }
      }
    } finally { busy = false; }
    if (!ok) return;
    if (!more) { onclose(); return; }
    // «Создать и ещё»: Куда, тема/колонка и «Когда» остаются.
    if (kind === 'task') { manualList = dest; if (topic) manualTopic = topic; manualCol = col; if (project) manualProject = project; }
    whenSet = { day: due ?? null, slot };
    text = ''; subs = []; subDraft = ''; notes = ''; off = {}; client = ''; money = ''; place = ''; year = '';
    await tick();
    input?.focus();
  }

  async function createTask() {
    const lay = {};
    const t = type ?? tagType;
    if (t) lay.type = t;
    if (priority) lay.priority = priority;
    if (repeatRule) lay.repeat = repeatRule;
    lay.remind = remRules;
    if (who) lay.who = who;
    let subList = subs.map((x) => ({ title: x }));
    if (view === 'stickers') { if (topic) lay.topic = topic; if (pin) lay.pin = true; }
    if (view === 'kanban' || view === 'list') {
      if (col !== tpl.cols[0].id) lay.status = col;
      lay.ord = cr.topOrd(destTasks, layTasks, col, tpl.cols[0].id);
      if (tpl.fields?.includes('client') && client.trim()) lay.client = client.trim();
      if (tpl.fields?.includes('money') && money.trim()) lay.money = money.trim();
    }
    if (view === 'pipe') {
      if (project) lay.project = project;
      if (stageId !== tpl.cols[0].id) lay.status = stageId;
      lay.stageAt = { [stageId]: Date.now() };
      subList = [...checklist, ...subList];
    }
    const id = await oncreate({ title, listId: dest, due: dueDay ?? '', slot: dueDay ? slot : null, layer: lay, notes: notes.trim(), subs: subList });
    // Обучение: список или тему выбрали руками — запоминаем слова названия.
    if (id && onlearn && (manualList || (manualTopic && manualTopic !== autoTopic))) onlearn(learn(layer?.settings?.route, title, dest, view === 'stickers' ? topic : null));
    return id;
  }

  // ---------- клавиши ----------
  function key(ev) {
    if (document.querySelector('.keyhelp, .dtp')) return; // открыто окно «Когда» — Esc закрывает его
    if (ev.key === 'Escape') { ev.preventDefault(); if (pickOpen) { pickOpen = false; input?.focus(); } else onclose(); return; }
    if (pickOpen) return; // клавиши окна выбора — в нём самом
    if (ev.altKey && /^Digit[1-3]$/.test(ev.code)) { ev.preventDefault(); kind = KINDS[ev.code.slice(5) - 1].id; return; }
    if (ev.altKey && ev.code === 'KeyL' && kind === 'task') { ev.preventDefault(); pickOpen = true; return; }
    if (ev.key === 'Enter' && !ev.isComposing) {
      const el = ev.target;
      if (el?.classList?.contains('cr-subin')) { ev.preventDefault(); if (subDraft.trim()) addSub(); else if (ev.ctrlKey || ev.metaKey) submit(); return; }
      if (el?.classList?.contains('cr-newproj')) { ev.preventDefault(); if (newProject?.trim()) { manualProject = newProject.trim(); newProject = null; } return; }
      if (el?.tagName === 'TEXTAREA' && !(ev.ctrlKey || ev.metaKey)) return;
      if (el?.tagName === 'BUTTON' && !(ev.ctrlKey || ev.metaKey || ev.shiftKey)) return;
      ev.preventDefault();
      submit(ev.shiftKey);
    }
  }

  // ---------- окно выбора «Куда» ----------
  let q = $state('');
  let sel = $state(0);
  let qInput = $state(null);
  const pickItems = $derived.by(() => {
    const k = q.trim().toLowerCase().replace(/ё/g, 'е');
    const hit = (l) => !k || l.title.toLowerCase().replace(/ё/g, 'е').includes(k);
    const groups = [...spheres.map((sp) => ({ sp, items: lists.filter((l) => sphereOf(l.id, layer) === sp.id && hit(l)) })),
      { sp: null, items: lists.filter((l) => !sphereOf(l.id, layer) && hit(l)) }].filter((g) => g.items.length);
    return groups;
  });
  const flat = $derived(pickItems.flatMap((g) => g.items));
  const guess = $derived(lists.find((l) => l.id === ranked[0]?.listId));
  const summary = (l) => {
    const v = viewOf(l.id, layer), ts = (tasksByList[l.id] ?? []).filter((t) => !t.parent);
    const open = ts.filter((t) => t.status !== 'completed').length;
    if (v === 'pipe') return `Конвейер · ${open} ${open === 1 ? 'ассет' : open < 5 && open ? 'ассета' : 'ассетов'}`;
    if (v === 'stickers') return `Стикеры · ${open} дел`;
    if (v === 'list') return `Список · ${ts.length - open} из ${ts.length}`;
    return `Канбан · ${open} открытых`;
  };
  // Окно выбора — поверх всего (position: fixed) под карточкой «Куда», чтобы не обрезалось краем окна «Создать».
  let destEl = $state(null);
  let pickPos = $state('');
  $effect(() => {
    if (!pickOpen) return;
    q = ''; sel = -1;
    const r = destEl?.getBoundingClientRect();
    if (r) pickPos = `left: ${r.left}px; top: ${r.bottom + 6}px; width: ${r.width}px; max-height: ${Math.max(220, innerHeight - r.bottom - 22)}px`;
    tick().then(() => qInput?.focus());
  });
  // Клавиши окна выбора не доходят до окна «Создать» (иначе Enter выбрал бы список и сразу создал задачу).
  function pickKey(ev) {
    let done = true;
    if (ev.key === 'ArrowDown') sel = Math.min(flat.length - 1, sel + 1);
    else if (ev.key === 'ArrowUp') sel = Math.max(-1, sel - 1);
    else if (ev.key === 'Enter') { const l = sel < 0 ? (q.trim() ? flat[0] : guess) : flat[sel]; if (l) pickList(l.id); }
    else if (!q && /^Digit[1-9]$/.test(ev.code) && !ev.altKey) { const l = flat[ev.code.slice(5) - 1]; if (l) pickList(l.id); }
    else if (ev.key === 'Escape' || (ev.altKey && ev.code === 'KeyL')) { pickOpen = false; input?.focus(); }
    else done = false;
    if (done) { ev.preventDefault(); ev.stopPropagation(); }
  }
</script>

<svelte:window onkeydown={key} />

{#snippet viewIcon(v)}
  {#if v === 'stickers'}<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="4" width="7" height="7" rx="1.5" /><rect x="13" y="4" width="7" height="7" rx="1.5" /><rect x="4" y="13" width="7" height="7" rx="1.5" /><rect x="13" y="13" width="7" height="7" rx="1.5" /></svg>
  {:else if v === 'pipe'}<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /><circle cx="9" cy="7" r="1.6" /><circle cx="14" cy="12" r="1.6" /><circle cx="7" cy="17" r="1.6" /></svg>
  {:else if v === 'list'}<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 6h14M5 12h14M5 18h9" /></svg>
  {:else}<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="4" width="5" height="16" rx="1.5" /><rect x="10.5" y="4" width="5" height="11" rx="1.5" /><rect x="17" y="4" width="3.5" height="7" rx="1.2" /></svg>{/if}
{/snippet}

{#snippet remindRow()}
  <div class="cr-row"><span>Напомнить</span>
    <div class="cr-chips">
      <button type="button" class="cr-c" class:gold={kind === 'birthday'} aria-pressed={!remind.length} onclick={() => setRemind([])}>Нет</button>
      {#each kind === 'birthday' ? [0, 1440, 4320, 10080, 43200] : quickLeads as min (min)}
        <button type="button" class="cr-c" class:gold={kind === 'birthday'} aria-pressed={remind.includes(min)}
          onclick={() => setRemind(remind.includes(min) ? remind.filter((m) => m !== min) : [...remind, min].sort((a, b) => b - a))}>{kind === 'birthday' && min === 10080 && gift ? 'За неделю — подарок' : remLabel(min)}</button>
      {/each}
      {#if kind !== 'birthday'}<button type="button" class="cr-c" aria-expanded={remOpen} onclick={() => (remOpen = !remOpen)}>Ещё…</button>{/if}
    </div>
  </div>
  {#if remOpen && kind !== 'birthday'}
    <div class="cr-row"><span></span>
      <div class="cr-remall">
        <RemindChips value={remind} {kind} onchange={setRemind} />
        {#if isDefault}<span class="cr-muted">по умолчанию</span>
        {:else if onremindDefault}<button type="button" class="cr-link" onclick={() => onremindDefault(kind, remind)}>Сделать по умолчанию</button>{/if}
      </div>
    </div>
  {/if}
{/snippet}

{#snippet subsRow(label)}
  <div class="cr-row top"><span>{label}</span>
    <div class="cr-subs">
      {#each subs as x, i (i)}<div class="cr-sub"><i></i><span>{x}</span><button type="button" class="cr-subx" aria-label="Убрать пункт" onclick={() => (subs = subs.filter((_, j) => j !== i))}>×</button></div>{/each}
      <input class="cr-subin" bind:value={subDraft} placeholder="＋ ещё пункт — Enter" aria-label="Новая подзадача" />
    </div>
  </div>
{/snippet}

{#snippet dueRow()}
  <div class="cr-row"><span>Срок</span>
    <div class="cr-chips">
      <button type="button" class="cr-c" aria-pressed={!!dueDay} aria-haspopup="dialog" onclick={() => (picking = true)}>📅 {dueDay ? `${cr.dueShort(dueDay, today)}${slot ? ` · ${slot.s}–${slot.e}` : ''}` : 'выбрать'}</button>
      {#if dueDay}<button type="button" class="cr-c" aria-pressed={!!remind.length} aria-expanded={remOpen} onclick={() => (remOpen = !remOpen)}>🔔 {remind.length ? remShort : 'без напоминания'}</button>{/if}
    </div>
  </div>
  {#if remOpen && dueDay}
    <div class="cr-row"><span></span>
      <div class="cr-remall">
        <RemindChips value={remind} {kind} onchange={setRemind} />
        {#if isDefault}<span class="cr-muted">по умолчанию</span>
        {:else if onremindDefault}<button type="button" class="cr-link" onclick={() => onremindDefault(kind, remind)}>Сделать по умолчанию</button>{/if}
      </div>
    </div>
  {/if}
{/snippet}

{#snippet prioRow(short)}
  <div class="cr-row"><span>Приоритет</span>
    <div class="cr-chips">
      {#each PRIORITIES as p (p.id)}
        <button type="button" class="cr-c {p.cls}" aria-pressed={priority === p.id} onclick={() => (manualPrio = p.id)}><b>{p.mark}</b>{short ? '' : ` ${p.label}`}</button>
      {/each}
      <button type="button" class="cr-c" aria-pressed={!priority} onclick={() => (manualPrio = null)}>{short ? '—' : 'Нет'}</button>
    </div>
  </div>
{/snippet}

<button class="drawer-back cr-back" type="button" aria-label="Закрыть" onclick={onclose} transition:fade={{ duration: 180 }}></button>
<form transition:pop class="cr-win" class:narrow={kind !== 'task'} aria-label="Создать" onsubmit={(ev) => { ev.preventDefault(); submit(); }}>
  <div class="cr-main">
    <div class="cr-top">
      <div class="cr-kinds" role="group" aria-label="Что создаём">
        {#each KINDS as k (k.id)}
          <button type="button" aria-pressed={kind === k.id} class:gold={k.id === 'birthday'} title="Alt+{k.key}" onclick={() => { kind = k.id; input?.focus(); }}>
            {#if k.id === 'task'}<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8" /><path d="M8.5 12.5l2.5 2.5 4.5-5" /></svg>
            {:else if k.id === 'event'}<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="5" width="16" height="15" rx="3" /><path d="M4 10h16M9 3v4M15 3v4" /></svg>
            {:else}<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 20h14M6 20v-7h12v7M12 13V9M12 6.5c-1-1 0-2.5 0-2.5s1 1.5 0 2.5" /></svg>{/if}
            {k.label}
          </button>
        {/each}
      </div>
      <button type="button" class="cr-x" aria-label="Закрыть" onclick={onclose}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18" /></svg></button>
    </div>

    <!-- Умная строка: пишешь как человеку, распознанное подсвечивается, под полем — «Понял:» -->
    <div class="cr-smart" class:gold={kind === 'birthday'}>
      <div class="cr-line">
        <div class="cr-mirror" aria-hidden="true" bind:this={mirror}>{#each segs as g, i (i)}{#if g.k}<mark class="cr-m {g.k}">{g.t}</mark>{:else}{g.t}{/if}{/each}&#8203;</div>
        <!-- svelte-ignore a11y_autofocus -->
        <input class="cr-input" bind:this={input} bind:value={text} autofocus onscroll={syncScroll} oninput={syncScroll} spellcheck="false" autocomplete="off"
          aria-label={kind === 'birthday' ? 'Чей день рождения' : 'Что сделать'}
          placeholder={kind === 'birthday' ? 'Чей? Например «Аня 12 марта»' : kind === 'event' ? 'Что за событие? «созвон завтра 14:00»' : 'Что сделать? «купить лампочки в субботу»'} />
      </div>
      {#if toks.length}
        <div class="cr-got"><span>Понял:</span>
          {#each toks as t (t.k)}
            <span class="cr-tok" class:auto={t.auto} style="--tc: {t.c ?? 'transparent'}" title={t.title ?? 'Распознано в тексте'} in:pop={{ start: 0.9 }}>{#if t.c}<i></i>{/if}{t.l}<button type="button" aria-label="Убрать: {t.l}" onclick={() => dropTok(t.k)}>×</button></span>
          {/each}
        </div>
      {/if}
    </div>

    {#if kind === 'task'}
      <div class="cr-where">
        <div class="cr-lbl">Куда <span>— {manualList ? 'выбрано вручную' : 'угадано по словам, можно поменять'}</span></div>
        <div class="cr-destwrap">
          <button type="button" class="cr-dest" bind:this={destEl} style="--sc: {colorOf(dest)}" aria-haspopup="listbox" aria-expanded={pickOpen} title="Alt+L" onclick={() => (pickOpen = !pickOpen)}>
            <span class="cr-sw">{@render viewIcon(view)}</span>
            <span class="cr-n"><b>{destList?.title ?? '—'}</b><small>{sphereFor(dest)?.name ?? 'Без сферы'} · вид «{VIEW_NAME[view] ?? 'Канбан'}»</small></span>
            <span class="cr-why">✦ {why}</span>
            <svg class="cr-chev" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 9l6 6 6-6" /></svg>
          </button>
          {#if pickOpen}
            <button type="button" class="cr-pickback" aria-label="Закрыть выбор списка" onclick={() => (pickOpen = false)}></button>
            <div class="cr-pick" style={pickPos} role="listbox" aria-label="Куда положить" tabindex="-1" transition:pop>
              <div class="cr-srch"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="M20 20l-4.5-4.5" /></svg>
                <input bind:this={qInput} bind:value={q} placeholder="Найти список…" aria-label="Найти список" onkeydown={pickKey} /><kbd>Alt+L</kbd></div>
              {#if guess && !q}
                <button type="button" class="cr-it sug" class:on={sel === -1} style="--sc: {colorOf(guess.id)}" onclick={() => pickList(guess.id)}>
                  <span class="cr-v">{@render viewIcon(viewOf(guess.id, layer))}</span>
                  <span class="cr-itn">{guess.title}<small>{VIEW_NAME[viewOf(guess.id, layer)]}{ranked[0]?.topic ? ` · тема «${topicsOf(layer?.lists?.[guess.id]).find((t) => t.id === ranked[0].topic)?.name ?? ''}»` : ''}</small></span>
                  <span class="cr-itwhy">✦ угадано</span>
                </button>
              {/if}
              {#each pickItems as g (g.sp?.id ?? '-')}
                <div class="cr-grp" style="--sc: {g.sp ? sphereColor(g.sp) : 'var(--ink-faint)'}"><i></i>{g.sp?.name ?? 'Без сферы'}</div>
                {#each g.items as l (l.id)}
                  {@const n = flat.indexOf(l)}
                  <button type="button" class="cr-it" class:on={sel === n} class:cur={l.id === dest} style="--sc: {colorOf(l.id)}" onclick={() => pickList(l.id)}>
                    <span class="cr-v">{@render viewIcon(viewOf(l.id, layer))}</span>
                    <span class="cr-itn">{l.title}<small>{summary(l)}</small></span>
                    {#if n < 9}<kbd>{n + 1}</kbd>{/if}
                  </button>
                {/each}
              {/each}
              {#if onnewlist}
                <button type="button" class="cr-newl" onclick={() => onnewlist(q.trim() || title)}>＋ Новый список{q.trim() || title ? ` «${(q.trim() || title).slice(0, 24)}${(q.trim() || title).length > 24 ? '…' : ''}»` : ''} — откроет выбор шаблона</button>
              {/if}
            </div>
          {/if}
        </div>
        {#if alts.length}
          <div class="cr-alts"><span>или:</span>
            {#each alts as l (l.id)}<button type="button" class="cr-alt" style="--sc: {colorOf(l.id)}" onclick={() => pickList(l.id)}><i></i>{l.title}</button>{/each}
          </div>
        {/if}
      </div>

      {#key view}
      <div class="cr-block" aria-label="Для {view}" in:fade={{ duration: 140 }}>
        <div class="cr-lbl">{view === 'stickers' ? 'Для стикера' : view === 'pipe' ? 'Для конвейера' : view === 'list' ? 'Для списка' : 'Для канбана'}</div>
        {#if destPeople.length}
          <div class="cr-row"><span>Кто делает</span>
            <div class="cr-chips">
              {#each whoRows as p (p.email)}
                <button type="button" class="cr-c cr-who" aria-pressed={who === p.email} onclick={() => (manualWho = p.email)}><Avatar m={p} size={20} me={p.email === me} />{p.email === me ? 'Я' : p.name}</button>
              {/each}
              <button type="button" class="cr-c cr-who" aria-pressed={!who} onclick={() => (manualWho = null)}><Avatar m={null} size={20} />Никто</button>
            </div>
          </div>
        {/if}
        {#if view === 'stickers'}
          <div class="cr-row"><span>Тема</span>
            <div class="cr-chips">
              {#each topics as t (t.id)}
                <button type="button" class="cr-c" style="--tc: {topicColor(t)}" aria-pressed={topic === t.id} onclick={() => (manualTopic = topic === t.id ? '' : t.id)}><i></i>{t.name}</button>
              {/each}
            </div>
          </div>
          <div class="cr-row"><span>Когда</span>
            <div class="cr-chips">
              <button type="button" class="cr-c" aria-pressed={whenChip === 'today'} onclick={() => setWhen(today, slot)}>Сегодня</button>
              <button type="button" class="cr-c" aria-pressed={whenChip === 'week'} onclick={() => setWhen(whenChip === 'week' ? dueDay : plusDays(today, 1), slot)}>{weekLabel}</button>
              <button type="button" class="cr-c" aria-pressed={whenChip === 'later'} onclick={() => setWhen(null, null)}>Когда-нибудь</button>
              <button type="button" class="cr-c" aria-pressed={whenChip === 'date'} aria-haspopup="dialog" onclick={() => (picking = true)}>📅 {whenChip === 'date' ? cr.shortDay(dueDay) : 'Дата…'}</button>
            </div>
          </div>
          {@render remindRow()}
          <div class="cr-row"><span></span><button type="button" class="cr-pin" aria-pressed={pin} onclick={() => (pin = !pin)}><u></u>Закрепить сверху</button></div>
        {:else if view === 'pipe'}
          <div class="cr-row"><span>Проект</span>
            <div class="cr-chips">
              {#each [...new Set([...projects, ...(project && !projects.includes(project) ? [project] : [])])] as p (p)}
                <button type="button" class="cr-c" aria-pressed={project === p} onclick={() => { manualProject = project === p ? null : p; if (project !== p) off = { ...off, project: true }; }}>{p}</button>
              {/each}
              {#if newProject === null}
                <button type="button" class="cr-c" onclick={() => (newProject = '')}>＋ Новый проект</button>
              {:else}
                <!-- svelte-ignore a11y_autofocus -->
                <input class="cr-newproj" bind:value={newProject} autofocus placeholder="Название проекта — Enter" aria-label="Новый проект"
                  onblur={() => { if (newProject?.trim()) manualProject = newProject.trim(); newProject = null; }} />
              {/if}
            </div>
          </div>
          <div class="cr-row"><span>Начать с</span>
            <div class="cr-track">
              {#each cols as c (c.id)}<button type="button" aria-pressed={stageId === c.id} title={c.name} onclick={() => (stage = c.id)}>{c.name}</button>{/each}
            </div>
          </div>
          <div class="cr-row"><span>Срок</span>
            <div class="cr-chips">
              <button type="button" class="cr-c" aria-pressed={!!dueDay && dueDay !== plusDays(today, 7) && dueDay !== plusDays(today, 14)} onclick={() => (picking = true)}>📅 {dueDay && dueDay !== plusDays(today, 7) && dueDay !== plusDays(today, 14) ? cr.dueShort(dueDay, today, slot) : 'выбрать'}</button>
              <button type="button" class="cr-c" aria-pressed={dueDay === plusDays(today, 7)} onclick={() => setWhen(plusDays(today, 7))}>через неделю</button>
              <button type="button" class="cr-c" aria-pressed={dueDay === plusDays(today, 14)} onclick={() => setWhen(plusDays(today, 14))}>через 2 недели</button>
            </div>
          </div>
          {@render prioRow(true)}
        {:else}
          {#if view === 'kanban'}
            <div class="cr-row"><span>Колонка</span>
              <div class="cr-chips">
                {#each cols as c (c.id)}
                  <button type="button" class="cr-c col" style="--tc: {colColor(c)}" aria-pressed={col === c.id} onclick={() => (manualCol = c.id)}><i></i>{c.name}{#if c.limit}<span class="cr-lim" class:full={colN(c) >= c.limit}>{colN(c)}/{c.limit}</span>{/if}</button>
                {/each}
              </div>
            </div>
            {@render prioRow(false)}
          {/if}
          {@render dueRow()}
          {#if tpl.fields?.includes('client')}
            <div class="cr-row"><span>Клиент</span><input class="cr-fld" bind:value={client} placeholder="Кто заказал" aria-label="Клиент" /></div>
          {/if}
          {#if tpl.fields?.includes('money')}
            <div class="cr-row"><span>Сумма</span><input class="cr-fld" bind:value={money} placeholder="Например 15 000 ₽" aria-label="Сумма" /></div>
          {/if}
          {@render subsRow(view === 'list' ? 'Уроки' : 'Подзадачи')}
        {/if}
      </div>
      {/key}

      <button type="button" class="cr-more" aria-expanded={moreOpen} onclick={() => (moreOpen = !moreOpen)}>{moreOpen ? '▾' : '▸'} Ещё <span>заметка · повтор{view === 'stickers' ? ' · приоритет' : ''} · тип для цвета (авто: {TYPES.find((t) => t.id === autoType)?.label})</span></button>
      {#if moreOpen}
        <div class="cr-block more">
          <textarea class="cr-notes" bind:value={notes} use:autosize={notes} aria-label="Заметка" placeholder="Заметка: подробности, ссылки…"></textarea>
          <div class="cr-row"><span>Повтор</span>
            <div class="cr-chips">
              <button type="button" class="cr-c" aria-pressed={!repeatRule} onclick={() => (repeat = null)}>Нет</button>
              {#each REPEATS as r (r.id)}<button type="button" class="cr-c" aria-pressed={repeatRule?.every === r.id} onclick={() => (repeat = { every: r.id })}>{r.label}</button>{/each}
            </div>
          </div>
          {#if view === 'stickers'}{@render prioRow(false)}{/if}
          <div class="cr-row"><span>Тип</span>
            <div class="cr-chips">
              <button type="button" class="cr-c" aria-pressed={!type && !tagType} onclick={() => (type = null)}>Авто: {TYPES.find((t) => t.id === autoType)?.label}</button>
              {#each TYPES as t (t.id)}<button type="button" class="cr-c" style="--tc: var(--type-{t.id})" aria-pressed={(type ?? tagType) === t.id} onclick={() => (type = t.id)}><i></i>{t.label}</button>{/each}
            </div>
          </div>
        </div>
      {/if}
    {:else}
      <!-- Событие и день рождения: дата крупной строкой, поля, превью «В календаре:» -->
      <button type="button" class="cr-big" class:gold={kind === 'birthday'} aria-haspopup="dialog" onclick={() => (picking = true)}>
        {#if kind === 'event'}<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="5" width="16" height="15" rx="3" /><path d="M4 10h16M9 3v4M15 3v4" /></svg>
        {:else}<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 20h14M6 20v-7h12v7M12 13V9" /></svg>{/if}
        {#if !dueDay}<span class="cr-muted">Выбери дату — или напиши её в строке: «завтра 14:00»</span>
        {:else if kind === 'event'}{cr.longDay(dueDay)}{slot ? ` · ${slot.s}–${slot.e}` : ' · весь день'}
        {:else}{cr.dayMonth(dueDay)} · каждый год{/if}
        <small>изменить</small>
      </button>
      {#if kind === 'event'}
        <div class="cr-row"><span>Длится</span>
          <div class="cr-chips">
            {#each DURS as [m, l] (m)}<button type="button" class="cr-c" aria-pressed={!!slot && evDur === m} onclick={() => setDur(m)}>{l}</button>{/each}
            <button type="button" class="cr-c" aria-pressed={!slot} onclick={() => setDur(0)}>весь день</button>
          </div>
        </div>
        {#if cals.length > 1}
          <div class="cr-row"><span>Календарь</span>
            <div class="cr-chips">
              {#each cals as c (c.id)}<button type="button" class="cr-c" style="--tc: {c.backgroundColor ?? 'var(--type-work)'}" aria-pressed={calId === c.id} onclick={() => (calId = c.id)}><i></i>{c.primary ? 'Основной' : c.summaryOverride || c.summary}</button>{/each}
            </div>
          </div>
        {/if}
        <div class="cr-row"><span>Где</span><input class="cr-fld" bind:value={place} placeholder="Ссылка на созвон или адрес" aria-label="Где" /></div>
        {@render remindRow()}
        {#if dueDay}
          <div class="cr-pv">В календаре:
            <div class="cr-ev"><b>{title || 'Событие'}</b><small>{slot ? `${slot.s}–${slot.e}` : 'весь день'}{#if free?.clash}<em> · пересекается с «{free.clash}»</em>{:else if free?.until} · свободно до {free.until}{:else if free?.free} · дальше свободно{/if}</small></div>
          </div>
        {/if}
      {:else}
        <div class="cr-row"><span>Год</span><input class="cr-fld" bind:value={year} inputmode="numeric" maxlength="4" aria-label="Год рождения"
          placeholder={bday ? `${Number(bday.slice(0, 4)) - 30} — необязательно, тогда напишу «исполнится 30»` : 'Год рождения — необязательно'} /></div>
        {@render remindRow()}
        {#if giftList}
          <div class="cr-row"><span>Задача</span>
            <div class="cr-chips"><button type="button" class="cr-c" aria-pressed={gift} onclick={() => (gift = !gift)}>＋ «{giftTitle}» в «{giftList.title}» за неделю</button></div>
          </div>
        {/if}
        {#if bday}
          <div class="cr-pv">В календаре:<div class="cr-bd">🎂 <b>{title || 'Имя'}</b>{age ? ` — ${cr.years(age)}` : ''} · {cr.weekday(bday)}, {cr.dayMonth(bday)}</div></div>
        {/if}
      {/if}
    {/if}

    <div class="cr-foot">
      {#if kind === 'task'}
        <span class="cr-keys"><kbd>Enter</kbd> создать · <kbd>Shift+Enter</kbd> создать и ещё · <kbd>Tab</kbd> по полям · <kbd>Alt+L</kbd> список</span>
        <button type="button" class="sp-btn sp-btn-ghost" disabled={!canSubmit} onclick={() => submit(true)}>Создать и ещё</button>
        <button type="submit" class="sp-btn sp-btn-primary" disabled={!canSubmit}>Создать</button>
      {:else}
        <span class="cr-keys"><kbd>Enter — создать</kbd></span>
        <button type="button" class="sp-btn sp-btn-ghost" onclick={onclose}>Отмена</button>
        <button type="submit" class="sp-btn sp-btn-primary" class:gold={kind === 'birthday'} disabled={!canSubmit}>{kind === 'event' ? 'Создать событие' : 'Добавить'}</button>
      {/if}
    </div>
  </div>

  {#if kind === 'task'}
    <aside class="cr-side" aria-label="Так будет выглядеть">
      <h4>Так будет выглядеть</h4>
      <div class="cr-stage">
        {#key view}
        <div class="cr-pvwrap" in:fade={{ duration: 160 }}>
          {#if view === 'stickers'}
            <div class="cr-pvst" style="--tc: {topicObj ? topicColor(topicObj) : 'var(--ink-faint)'}">
              <div class="t">{title || 'Новое дело'}</div>
              <div class="f"><span>{pvWhen}</span>{#if pin}<span class="cr-pinmark" title="Закреплено">📌</span>{/if}<i></i></div>
            </div>
          {:else if view === 'pipe'}
            <div class="cr-pvcv">
              <div class="h"><span class="th">{cr.initials(title)}</span><div><b>{title || 'Новый ассет'}</b><small>{project ?? 'без проекта'} · новый</small></div></div>
              <div class="tr">{#each cols as c (c.id)}<span class:c={c.id === stageId}></span>{/each}</div>
              <span class="st"><b>{cols.find((c) => c.id === stageId)?.name}</b> · с сегодня{dueDay ? ` · срок ${cr.dueShort(dueDay, today)}` : ''}</span>
            </div>
          {:else}
            <div class="cr-pvkc {prioCls(priority)}">
              <div class="t">{title || 'Новая задача'}</div>
              {#if dueDay || subs.length || remind.length}
                <div class="mt">
                  {#if dueDay}<span class:soon={dueDay <= plusDays(today, 1)}>{pvWhen}</span>{/if}
                  {#if subs.length}<span>☑ 0 из {subs.length}</span>{/if}
                  {#if remind.length && dueDay}<span>🔔 {remShort}</span>{/if}
                </div>
              {/if}
            </div>
          {/if}
        </div>
        {/key}
      </div>
      <p class="cr-lands">{lands[0]}<b>{lands[1]}</b>{lands[2]}</p>
      <div class="cr-tip"><Coon pose="think" size={54} label="Енот думает" /><p>{tip}</p></div>
    </aside>
  {/if}
</form>

{#if picking}
  <DateTimePicker day={dueDay ?? ''} slot={kind === 'birthday' ? null : slot} allowTime={kind !== 'birthday'} {title} {dueDays} {loadEvents}
    onapply={applyWhen} onclose={() => (picking = false)} />
{/if}
