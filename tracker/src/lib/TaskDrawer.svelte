<script>
  // Окно задачи v2 (docs/design-v2.md, «Окно задачи v2 и выпадающие списки»; макеты design/screens/TaskPanel*.dc.html):
  // сверху «Куда» (перенос в другой список), ⋯ и ✕; название крупно; серая плашка с главными полями чипами
  // (исполнитель, колонка/этап, проект, приоритет, клиент и сумма, срок с напоминаниями); подзадачи; заметка;
  // «▸ Ещё» — повтор, цвет, картинка; подвал «Сохранено в Google Tasks» и «Удалить».
  import PreviewBox from './PreviewBox.svelte';
  import Avatar from './Avatar.svelte';
  import WhoPick from './WhoPick.svelte';
  import ListPick from './ListPick.svelte';
  import Popover from './Popover.svelte';
  import SphereIcon from './SphereIcon.svelte';
  import Dropdown from './Dropdown.svelte';
  import DateTimePicker from './DateTimePicker.svelte';
  import { memberOf } from './sharedcore.js';
  import { untrack, tick } from 'svelte';
  import { fly, fade, expand } from './motion.js';
  import { dueToYmd, ymdToDue, ymd } from './api.js';
  import { BEFORE, DEFAULT_TIME, LEADS } from './reminders.js';
  import { TYPES, PRIORITIES, autosize } from './meta.js';
  import { whenText } from './when.js';
  import { REPEATS, nextDue } from './repeat.js';
  import { colColor } from './templates.js';
  import { spheresFrom, sphereOf } from './spheres.js';
  import { projectsOf } from './route.js';
  import { colCounts, stageMode, leadChip, customChip, splitRemind, joinRemind, moreFilled } from './taskpanel.js';
  import { layer, touch, save as saveLayer } from '../stores/layer.svelte.js';
  import { board } from '../stores/tasks.svelte.js';

  // type / priority / repeat … — из слоя (tasks[id]); onlayer(patch) пишет туда же.
  // dueDays / loadEvents — для окна «Когда»: точки занятости в месяце и события выбранного дня.
  // lists — списки для «Куда», view — вид доски (pipe — дорожка этапов и «Проект»).
  // onsave(patch) → true/false (для подвала «Сохранено / Не сохранилось»), onmove(listId) — в другой список.
  let { task, list, lists = [], view = 'kanban', subs, status, cols, remind = null, slot = null, type = null, priority = null, repeat = null,
    dueDays = new Set(), loadEvents = null,
    pick = false, // сразу открыть окно «Когда» (клавиша D, кнопка срока на карточке)
    fields = [], client = '', money = '', // поля шаблона: «Клиент» и «Сумма» показываются, если включены в шаблоне
    share = null, onwho = null, // общая сфера: { people, me, who, change } — исполнитель и последнее чужое изменение
    onclose, onsave, onstatus, ondelete, ontoggle, onaddsub, onsubedit, onsubdelete, onremind, onslot, onlayer,
    onmove = null, onduplicate = null,
    preview = null, previewOff = '', onpreview, onpreviewclear } = $props();

  const lay = $derived(layer.data);
  const L = $derived(lay.tasks?.[task.id] ?? {});

  // ---------- «Куда» ----------
  const sphere = $derived.by(() => { const id = sphereOf(list?.id, lay); return id ? spheresFrom(lay).find((s) => s.id === id) : null; });
  let destBtn = $state(null);
  let picking2 = $state(false); // выбор списка
  function moveTo(id) {
    picking2 = false;
    if (id && id !== list?.id) onmove?.(id);
  }

  // ---------- меню ⋯ ----------
  let menuBtn = $state(null);
  let menuOpen = $state(false);
  function menuAct(fn) { menuOpen = false; fn(); }

  // ---------- название, заметка ----------
  let title = $state('');
  let notes = $state('');
  let subDraft = $state('');
  let confirmDelete = $state(false);
  let more = $state(false);
  let loadedId = '';
  // Подхватываем поля, когда открыли другую задачу или она обновилась из Google.
  $effect(() => {
    if (task.id !== loadedId) {
      loadedId = task.id;
      confirmDelete = false;
      title = task.title ?? '';
      notes = task.notes ?? '';
      failed = null;
      more = untrack(() => !!lay.settings?.taskMore?.v || moreFilled(L));
    }
  });
  function toggleMore() {
    more = !more;
    touch('settings', 'taskMore', { v: more });
    saveLayer();
  }

  // ---------- подвал: «Сохранено в Google Tasks / Сохраняю… / Не сохранилось · Повторить» ----------
  let saving = $state(0);
  let failed = $state(null);
  async function put(patch) {
    saving += 1;
    failed = null;
    const ok = await onsave(patch);
    saving -= 1;
    if (ok === false) failed = patch;
  }
  function saveTitle() {
    const t = title.replace(/\s*\n\s*/g, ' ').trim();
    if (t && t !== task.title) put({ title: t });
    else if (!t) title = task.title ?? '';
  }
  function saveNotes() {
    if (notes !== (task.notes ?? '')) put({ notes });
  }
  async function addSub(e) {
    e.preventDefault();
    const t = subDraft.trim();
    if (!t) return;
    subDraft = '';
    await onaddsub(t);
  }
  function close() { saveTitle(); saveNotes(); onclose(); }

  // ---------- колонка / этап ----------
  const mode = $derived(stageMode(view, cols));
  const counts = $derived(colCounts(board.tasks[list?.id] ?? [], cols, lay.tasks));
  const curIdx = $derived(cols.findIndex((c) => c.id === status));
  const limText = (c) => (c.limit ? `${counts[c.id] ?? 0}/${c.limit}` : null);
  const stageOpts = $derived(cols.map((c) => ({ id: c.id, label: c.name, color: colColor(c), count: limText(c), warn: c.limit && (counts[c.id] ?? 0) >= c.limit })));

  // ---------- проект (Конвейер) ----------
  const project = $derived(L.project ?? '');
  const projectOpts = $derived([{ id: '', label: 'Без проекта' },
    ...[...new Set([...projectsOf(board.tasks[list?.id] ?? [], lay.tasks), ...(project ? [project] : [])])].map((p) => ({ id: p, label: p }))]);

  // ---------- срок и напоминания ----------
  let picking = $state(untrack(() => pick));
  const due = $derived(dueToYmd(task.due));
  const wt = $derived(whenText(due, due ? slot : null));
  const rem = $derived(splitRemind(remind));
  const leadOpts = LEADS.map((l) => ({ id: l.min, label: l.name }));
  function applyWhen(r) {
    picking = false;
    const d = r.day ?? '';
    // Время задачи живёт в слое Спутника: в Google Tasks у срока нет часов.
    if (d !== dueToYmd(task.due)) put({ due: ymdToDue(d) });
    if (JSON.stringify(r.slot ?? null) !== JSON.stringify(slot ?? null)) onslot(r.slot ?? null);
    if (r.remind !== undefined) onremind(r.remind);
  }
  const setLeads = (v) => onremind(joinRemind(v, rem.custom));
  const setCustom = (c) => onremind(joinRemind(rem.leads, c));
  // «В своё время…»: за N дней в ЧЧ:ММ или точная дата — правится в маленьком окне у чипа.
  let ownBtn = $state(null);
  let ownOpen = $state(false);
  const ownOpts = [...BEFORE.map((b) => ({ id: `b${b.days}`, label: `${b.name} в…` })), { id: 'at', label: 'Точная дата и время' }];
  const ownKind = $derived(!rem.custom ? '' : rem.custom.kind === 'at' ? 'at' : `b${rem.custom.days ?? 0}`);
  async function addOwn() {
    if (!rem.custom) setCustom({ kind: 'before', days: 1, time: DEFAULT_TIME });
    await tick();
    ownOpen = true;
  }
  function pickOwn(v) {
    if (v === 'at') {
      const day = dueToYmd(task.due) || ymd(new Date(Date.now() + 864e5));
      return setCustom({ kind: 'at', at: rem.custom?.kind === 'at' ? rem.custom.at : `${day}T${DEFAULT_TIME}` });
    }
    setCustom({ kind: 'before', days: Number(v.slice(1)), time: rem.custom?.time ?? DEFAULT_TIME });
  }

  // ---------- «Ещё»: повтор и цвет ----------
  const nextDay = $derived(repeat?.every ? nextDue(repeat, due, ymd(new Date())) : null);
  const repeatOpts = $derived([{ id: '', label: 'Нет' }, ...REPEATS.map((r) => ({ id: r.id, label: r.label,
    hint: r.id === repeat?.every && nextDay ? `следующая — ${whenText(nextDay, null).date.toLowerCase()}` : undefined }))]);
  const COLOR_NAMES = { work: 'Работа', creative: 'Творчество', study: 'Учёба', personal: 'Личное' };

  // ---------- исполнитель (общая сфера) ----------
  let whoBtn = $state(null);
  let whoOpen = $state(false);
  const whoM = $derived(share ? memberOf(share.people, share.who) : null);
  const typingIn = (e) => /^(INPUT|TEXTAREA|SELECT)$/.test(e.target?.tagName ?? '') || e.target?.isContentEditable || !!e.target?.closest?.('.ddb');

  // Esc / Ctrl+Enter — сохранить и закрыть; Alt+←/→ — соседний этап; Alt+1/2/3/0 — приоритет; I — исполнитель.
  function key(e) {
    if (whoOpen || picking2 || menuOpen || ownOpen) return; // Esc и цифры — у открытого поповера
    if (share && e.code === 'KeyI' && !e.altKey && !e.ctrlKey && !e.metaKey && !e.shiftKey && !typingIn(e)) { e.preventDefault(); whoOpen = true; return; }
    if (document.querySelector('.keyhelp, .dtp, .pvw, .ddm')) return; // открыто окно поверх — Esc закроет его, а не задачу
    if (e.key === 'Escape' || (e.key === 'Enter' && (e.ctrlKey || e.metaKey))) { e.preventDefault(); close(); return; }
    if (!e.altKey || e.ctrlKey || e.metaKey) return;
    if (e.key === 'ArrowRight' && curIdx < cols.length - 1) { e.preventDefault(); onstatus(cols[curIdx + 1].id); }
    else if (e.key === 'ArrowLeft' && curIdx > 0) { e.preventDefault(); onstatus(cols[curIdx - 1].id); }
    else {
      const d = /^Digit([0-3])$/.exec(e.code);
      if (d) { e.preventDefault(); onlayer({ priority: Number(d[1]) || null }); }
    }
  }
  const icon = { cal: 'M4 5h16v15H4zM4 10h16M9 3v4M15 3v4', bell: 'M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 20a2 2 0 0 0 4 0',
    x: 'M6 6l12 12M18 6L6 18', plus: 'M12 5v14M5 12h14', dots: 'M5 12h.01M12 12h.01M19 12h.01', chev: 'M6 9l6 6 6-6',
    right: 'M9 6l6 6-6 6', trash: 'M5 7h14M10 7V4h4v3M7 7l1 13h8l1-13', copy: 'M8 8h11v11H8zM5 16V5h11', move: 'M4 12h14M13 6l6 6-6 6',
    check: 'M5 12l5 5 9-10' };
</script>

<svelte:window onkeydown={key} />

{#snippet ico(d, cls = '')}<svg class="tp-i {cls}" viewBox="0 0 24 24" aria-hidden="true"><path d={d} /></svg>{/snippet}

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={close} in:fade={{ duration: 180 }} out:fade={{ duration: 180, out: true }}></button>
<aside class="drawer tp" aria-label="Задача" in:fly={{ x: 24, duration: 260 }} out:fly={{ x: 24, duration: 260, out: true }}>
  <div class="scroll">
    <div class="tp-top">
      <button bind:this={destBtn} type="button" class="tp-dest" aria-haspopup="listbox" aria-expanded={picking2} title="Перенести в другой список"
        disabled={!onmove} onclick={() => (picking2 = !picking2)}>
        {#if sphere}<SphereIcon {sphere} size={28} />{:else}<span class="tp-nosph">{@render ico('M4 6h16M4 12h16M4 18h10')}</span>{/if}
        <span class="tp-dn"><b>{list?.title ?? '—'}</b>{#if sphere}<small>{' · ' + sphere.name}</small>{/if}</span>
        {#if onmove}{@render ico(icon.chev, 'chev')}{/if}
      </button>
      <span class="tp-sp"></span>
      <button bind:this={menuBtn} type="button" class="tp-ib" aria-label="Ещё действия" aria-haspopup="menu" aria-expanded={menuOpen} onclick={() => (menuOpen = !menuOpen)}>{@render ico(icon.dots, 'dots')}</button>
      <button type="button" class="tp-ib" aria-label="Закрыть" title="Закрыть (Esc)" onclick={close}>{@render ico(icon.x)}</button>
    </div>

    <textarea class="tp-ttl" rows="1" bind:value={title} use:autosize={title} aria-label="Название" placeholder="Без названия" onblur={saveTitle}
      onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); e.currentTarget.blur(); } }}></textarea>
    {#if share?.change}<p class="tp-chg">{share.change}</p>{/if}

    <div class="tp-blk">
      {#if share}
        <div class="tp-rw"><span>Исполнитель</span>
          <div class="tp-chips">
            <button bind:this={whoBtn} type="button" class="tp-c tp-who" class:mine={share.who && share.who === share.me} title="Сменить · I" onclick={() => (whoOpen = true)}>
              <Avatar m={whoM} size={20} me={!!share.who && share.who === share.me} />{whoM ? (share.who === share.me ? 'Я' : whoM.name) : 'Без исполнителя'}</button>
          </div>
        </div>
        {#if whoOpen}
          <WhoPick anchor={whoBtn} people={share.people} me={share.me} cur={share.who} counts={share.counts ?? {}}
            onpick={(w) => { whoOpen = false; onwho(w); whoBtn?.focus(); }} onclose={() => (whoOpen = false)} />
        {/if}
      {/if}

      <div class="tp-rw"><span>{mode === 'chips' ? 'Колонка' : 'Этап'}</span>
        {#if mode === 'track'}
          <div class="tp-track" role="group" aria-label="Этап">
            {#each cols as c, i (c.id)}
              <button type="button" class:past={i < curIdx} aria-pressed={c.id === status} title={c.name} onclick={() => onstatus(c.id)}>{c.name}</button>
            {/each}
          </div>
        {:else if mode === 'chips'}
          <div class="tp-chips" role="group" aria-label="Колонка">
            {#each cols as c (c.id)}
              <button type="button" class="tp-c col" style="--tc: {colColor(c)}" aria-pressed={c.id === status} onclick={() => onstatus(c.id)}>
                <i></i>{c.name}{#if c.limit}<span class="lim" class:full={(counts[c.id] ?? 0) >= c.limit}>{limText(c)}</span>{/if}</button>
            {/each}
          </div>
        {:else}
          <div class="tp-chips"><Dropdown small mark="bar" label="Этап" value={status} options={stageOpts} onchange={onstatus} /></div>
        {/if}
      </div>

      {#if view === 'pipe'}
        <div class="tp-rw"><span>Проект</span>
          <div class="tp-chips"><Dropdown small label="Проект" search={projectOpts.length > 6} searchPlaceholder="Найти проект…" placeholder="Без проекта"
            value={project} options={projectOpts} oncreate={(q) => onlayer({ project: q })} createLabel={(q) => `Новый проект «${q}»`}
            emptyText={(q) => `Нет проекта «${q}»`} onchange={(v) => onlayer({ project: v || null })} /></div>
        </div>
      {/if}

      <div class="tp-rw"><span>Приоритет</span>
        <div class="tp-chips" role="group" aria-label="Приоритет">
          {#each PRIORITIES as p (p.id)}
            <button type="button" class="tp-c {p.cls}" aria-pressed={priority === p.id} title="Alt+{p.id}" onclick={() => onlayer({ priority: p.id })}><b>{p.mark}</b> {p.label.toLowerCase()}</button>
          {/each}
          <button type="button" class="tp-c" aria-pressed={!priority} title="Без приоритета · Alt+0" onclick={() => onlayer({ priority: null })}>—</button>
        </div>
      </div>

      {#if fields.includes('client')}
        <div class="tp-rw"><label for="f-client">Клиент</label>
          <input id="f-client" class="tp-in" value={client} placeholder="Кто заказал" onchange={(e) => onlayer({ client: e.currentTarget.value.trim() })} />
        </div>
      {/if}
      {#if fields.includes('money')}
        <div class="tp-rw"><label for="f-money">Сумма, ₽</label>
          <input id="f-money" class="tp-in short" type="number" min="0" step="100" value={money} placeholder="0" onchange={(e) => onlayer({ money: e.currentTarget.value ? Number(e.currentTarget.value) : null })} />
        </div>
      {/if}

      <div class="tp-rw"><span>Срок</span>
        <div class="tp-chips">
          <button type="button" class="tp-c when" class:empty={!due} aria-haspopup="dialog" aria-expanded={picking} title="Срок и время · D" onclick={() => (picking = true)}>
            {@render ico(icon.cal)}{due ? wt.date.toLowerCase() : 'без срока'}{#if due && slot && wt.time}{' · ' + wt.time}{/if}</button>
          {#each rem.leads as m (m)}
            <span class="tp-c when rem">{@render ico(icon.bell)}{leadChip(m)}
              <button type="button" class="x" aria-label="Убрать напоминание «{leadChip(m)}»" onclick={() => setLeads(rem.leads.filter((x) => x !== m))}>{@render ico(icon.x)}</button></span>
          {/each}
          {#if rem.custom}
            <span class="tp-c when rem" bind:this={ownBtn}>
              <button type="button" class="own" title="Изменить" onclick={() => (ownOpen = true)}>{@render ico(icon.bell)}{customChip(rem.custom)}</button>
              <button type="button" class="x" aria-label="Убрать напоминание в своё время" onclick={() => setCustom(null)}>{@render ico(icon.x)}</button></span>
          {/if}
          <Dropdown multi bcls="tp-add" label="Напомнить" title="Добавить напоминание" value={rem.leads} options={leadOpts} onchange={setLeads}
            extras={rem.custom ? [] : [{ label: 'В своё время…', onpick: addOwn }]}>
            {@render ico(icon.plus)}
          </Dropdown>
        </div>
      </div>
      {#if remind && !due && rem.custom?.kind !== 'at'}<p class="tp-hint">Поставь срок — без него напоминание «до начала» не придёт.</p>{/if}
    </div>

    <section class="tp-subs">
      <p class="tp-lbl">Подзадачи{#if subs.length}<span>{subs.filter((s) => s.status === 'completed').length} из {subs.length}</span>{/if}</p>
      <!-- Подзадачу можно переименовать прямо в строке (Enter или уход из поля — сохранить, Esc — отменить) и удалить. -->
      {#each subs as s (s.id)}
        <div class="tp-sb" class:done={s.status === 'completed'}>
          <button type="button" class="bx" role="checkbox" aria-checked={s.status === 'completed'} aria-label="Выполнено" onclick={() => ontoggle(s, s.status !== 'completed')}>{@render ico(icon.check)}</button>
          <input class="sub-title" value={s.title} aria-label="Подзадача"
            onkeydown={(e) => {
              if (e.key === 'Enter') e.currentTarget.blur();
              else if (e.key === 'Escape') { e.stopPropagation(); e.currentTarget.value = s.title; e.currentTarget.blur(); }
            }}
            onblur={(e) => { const v = e.currentTarget.value.trim(); if (!v) e.currentTarget.value = s.title; else if (v !== s.title) onsubedit(s, v); }} />
          <button class="sub-del" type="button" aria-label="Удалить подзадачу «{s.title}»" title="Удалить" onclick={() => onsubdelete(s)}>{@render ico(icon.x)}</button>
        </div>
      {/each}
      <form class="tp-sb tp-new" onsubmit={addSub}>
        <span class="bx dash"></span>
        <input bind:value={subDraft} placeholder="＋ ещё пункт — Enter" aria-label="Добавить подзадачу" />
      </form>
    </section>

    <div class="tp-note">
      <label class="tp-lbl" for="f-notes">Заметка</label>
      <!-- Заметка на всю ширину и растёт вместе с текстом. -->
      <textarea id="f-notes" bind:value={notes} use:autosize={notes} onblur={saveNotes} placeholder="Подробности, ссылки, шаги…"></textarea>
    </div>

    <button type="button" class="tp-more" aria-expanded={more} onclick={toggleMore}>
      {@render ico(icon.right, 'tw')}Ещё{#if !more}<span>повтор · цвет · картинка</span>{/if}
    </button>
    {#if more}
      <div class="tp-blk" transition:expand>
        <div class="tp-rw"><span>Повтор</span>
          <div class="tp-chips"><Dropdown small label="Повтор" value={repeat?.every ?? ''} options={repeatOpts} onchange={(v) => onlayer({ repeat: v ? { every: v } : null })} /></div>
        </div>
        <div class="tp-rw"><span>Цвет</span>
          <div class="tp-chips" role="group" aria-label="Цвет">
            <button type="button" class="tp-c col dot" style="--tc: var(--ink-faint)" aria-pressed={!type} title="Цвет по шаблону списка" onclick={() => onlayer({ type: null })}><i></i>авто</button>
            {#each TYPES as t (t.id)}
              <button type="button" class="tp-c col dot" style="--tc: var(--type-{t.id})" aria-pressed={type === t.id} onclick={() => onlayer({ type: t.id })}><i></i>{COLOR_NAMES[t.id] ?? t.label}</button>
            {/each}
          </div>
        </div>
        <div class="tp-rw top"><span>Картинка</span>
          <PreviewBox pv={preview} {title} off={previewOff} onset={onpreview} onclear={onpreviewclear} />
        </div>
      </div>
    {/if}
  </div>

  <div class="foot tp-ft">
    {#if failed}
      <span class="tp-saved err"><i></i>Не сохранилось · <button type="button" onclick={() => put(failed)}>Повторить</button></span>
    {:else}
      <span class="tp-saved" class:busy={saving > 0}><i></i>{saving > 0 ? 'Сохраняю…' : 'Сохранено в Google Tasks'}</span>
    {/if}
    <span class="tp-k"><kbd>Esc</kbd> закрыть · <kbd>Tab</kbd> по полям</span>
    {#if confirmDelete}
      <button class="sp-btn sp-btn-ghost" type="button" onclick={() => (confirmDelete = false)}>Отмена</button>
      <button class="sp-btn tp-danger" type="button" onclick={ondelete}>Удалить задачу</button>
    {:else}
      <button class="tp-del" type="button" onclick={() => (confirmDelete = true)}>{@render ico(icon.trash)}Удалить</button>
    {/if}
  </div>
</aside>

{#if picking2}
  <ListPick anchor={destBtn} {lists} layer={lay} current={list?.id} onpick={moveTo} onclose={() => (picking2 = false)} />
{/if}
{#if menuOpen}
  <Popover anchor={menuBtn} width={240} label="Действия с задачей" onclose={() => (menuOpen = false)}>
    <div class="tp-menu" role="menu">
      {#if onmove}<button type="button" role="menuitem" class="ddo" onclick={() => menuAct(() => (picking2 = true))}>{@render ico(icon.move)}<span class="t">Перенести в другой список</span></button>{/if}
      {#if onduplicate}<button type="button" role="menuitem" class="ddo" onclick={() => menuAct(onduplicate)}>{@render ico(icon.copy)}<span class="t">Дублировать</span></button>{/if}
      <div class="dds"></div>
      <button type="button" role="menuitem" class="ddo danger" onclick={() => menuAct(() => (confirmDelete = true))}>{@render ico(icon.trash)}<span class="t">Удалить задачу</span></button>
    </div>
  </Popover>
{/if}
{#if ownOpen && rem.custom}
  <Popover anchor={ownBtn} width={280} label="Напомнить в своё время" onclose={() => (ownOpen = false)}>
    <div class="tp-own">
      <p class="tp-lbl">Напомнить в своё время</p>
      <Dropdown small label="Когда" value={ownKind} options={ownOpts} onchange={pickOwn} />
      {#if rem.custom.kind === 'before'}
        <input type="time" class="tp-in" aria-label="Во сколько" value={rem.custom.time ?? DEFAULT_TIME} onchange={(e) => e.currentTarget.value && setCustom({ ...rem.custom, time: e.currentTarget.value })} />
      {:else}
        <input type="datetime-local" class="tp-in" aria-label="Когда напомнить" value={rem.custom.at} onchange={(e) => e.currentTarget.value && setCustom({ ...rem.custom, at: e.currentTarget.value })} />
      {/if}
      <div class="tp-ownft">
        <button type="button" class="sp-btn sp-btn-ghost" onclick={() => { setCustom(null); ownOpen = false; }}>Убрать</button>
        <button type="button" class="sp-btn sp-btn-primary" onclick={() => (ownOpen = false)}>Готово</button>
      </div>
    </div>
  </Popover>
{/if}

{#if picking}
  <DateTimePicker day={dueToYmd(task.due)} {slot} {remind} title={task.title} place="drawer" {dueDays} {loadEvents}
    onapply={applyWhen} onclose={() => (picking = false)} />
{/if}
