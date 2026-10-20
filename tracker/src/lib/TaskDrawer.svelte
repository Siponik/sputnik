<script>
  import { untrack } from 'svelte';
  import { fly, fade, pop } from './motion.js';
  import { dueToYmd, ymdToDue, ymd } from './api.js';
  import { BEFORE, DEFAULT_TIME, remindLabel, rulesOf } from './reminders.js';
  import RemindChips from './RemindChips.svelte';
  import { TYPES, PRIORITIES, autosize } from './meta.js';
  import { whenText } from './when.js';
  import DateTimePicker from './DateTimePicker.svelte';

  // type / priority — из слоя (tasks[id]); onlayer(patch) пишет туда же.
  // dueDays / loadEvents — для окна «Когда»: точки занятости в месяце и события выбранного дня.
  let { task, list, subs, status, cols, remind = null, slot = null, type = null, priority = null,
    dueDays = new Set(), loadEvents = null,
    pick = false, // сразу открыть окно «Когда» (клавиша D, кнопка срока на карточке)
    fields = [], client = '', money = '', // поля шаблона: «Клиент» и «Сумма» показываются, если включены в шаблоне
    onclose, onsave, onstatus, ondelete, ontoggle, onaddsub, onsubedit, onsubdelete, onremind, onslot, onlayer } = $props();

  // Напоминания: несколько «до начала» (кнопки) и одно «в своё время» (за N дней в ЧЧ:ММ или точная дата).
  const leads = $derived(rulesOf(remind).filter((r) => r.kind === 'lead').map((r) => r.min));
  const custom = $derived(rulesOf(remind).find((r) => r.kind !== 'lead') ?? null);
  const remindKind = $derived(!custom ? '' : custom.kind === 'at' ? 'at' : `b${custom.days ?? 0}`);
  const remindWhen = $derived(remindLabel(remind, task, slot));

  function saveRemind(mins, own) {
    const all = [...mins.map((min) => ({ kind: 'lead', min })), ...(own ? [own] : [])];
    onremind(!all.length ? null : all.length === 1 ? all[0] : all);
  }
  function pickRemind(v) {
    if (!v) return saveRemind(leads, null);
    if (v === 'at') {
      const day = dueToYmd(task.due) || ymd(new Date(Date.now() + 864e5));
      return saveRemind(leads, { kind: 'at', at: custom?.kind === 'at' ? custom.at : `${day}T${DEFAULT_TIME}` });
    }
    saveRemind(leads, { kind: 'before', days: Number(v.slice(1)), time: custom?.time ?? DEFAULT_TIME });
  }

  let title = $state('');
  let notes = $state('');
  let subDraft = $state('');
  let confirmDelete = $state(false);
  let loadedId = '';

  // Подхватываем поля, когда открыли другую задачу или она обновилась из Google.
  $effect(() => {
    if (task.id !== loadedId) {
      loadedId = task.id;
      confirmDelete = false;
      title = task.title ?? '';
      notes = task.notes ?? '';
    }
  });

  function saveTitle() {
    const t = title.trim();
    if (t && t !== task.title) onsave({ title: t });
  }
  function saveNotes() {
    if (notes !== (task.notes ?? '')) onsave({ notes });
  }
  async function addSub(e) {
    e.preventDefault();
    const t = subDraft.trim();
    if (!t) return;
    subDraft = '';
    await onaddsub(t);
  }
  function close() { saveTitle(); saveNotes(); onclose(); }
  // Esc / Ctrl+Enter — сохранить и закрыть; Alt+←/→ — соседний этап; Alt+1/2/3/0 — приоритет.
  // ---------- срок и время: окно «Когда» ----------
  let picking = $state(untrack(() => pick));
  const due = $derived(dueToYmd(task.due));
  const wt = $derived(whenText(due, due ? slot : null));
  function applyWhen(r) {
    picking = false;
    const d = r.day ?? '';
    // Время задачи живёт в слое Спутника: в Google Tasks у срока нет часов.
    if (d !== dueToYmd(task.due)) onsave({ due: ymdToDue(d) });
    if (JSON.stringify(r.slot ?? null) !== JSON.stringify(slot ?? null)) onslot(r.slot ?? null);
    if (r.remind !== undefined) onremind(r.remind);
  }

  function key(e) {
    if (document.querySelector('.keyhelp, .dtp')) return; // открыто окно поверх — Esc закроет его, а не задачу
    if (e.key === 'Escape' || (e.key === 'Enter' && (e.ctrlKey || e.metaKey))) { e.preventDefault(); close(); return; }
    if (!e.altKey || e.ctrlKey || e.metaKey) return;
    const i = cols.findIndex((c) => c.id === status);
    if (e.key === 'ArrowRight' && i < cols.length - 1) { e.preventDefault(); onstatus(cols[i + 1].id); }
    else if (e.key === 'ArrowLeft' && i > 0) { e.preventDefault(); onstatus(cols[i - 1].id); }
    else {
      const d = /^Digit([0-3])$/.exec(e.code);
      if (d) { e.preventDefault(); onlayer({ priority: Number(d[1]) || null }); }
    }
  }
</script>

<svelte:window onkeydown={key} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={close} in:fade={{ duration: 180 }} out:fade={{ duration: 180, out: true }}></button>
<aside class="drawer" aria-label="Задача" in:fly={{ x: 24, duration: 260 }} out:fly={{ x: 24, duration: 260, out: true }}>
  <div class="scroll">
    <div class="top">
      <span>{list?.title}</span>
      <button class="sp-btn sp-btn-ghost" type="button" aria-label="Закрыть" style="min-height: 32px; padding: 0 8px" title="Закрыть (Esc)" onclick={close}>
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18" /></svg>
      </button>
    </div>

    <div style="display: flex; align-items: flex-start; gap: 12px">
      <input class="title-input" bind:value={title} onblur={saveTitle} onkeydown={(e) => e.key === 'Enter' && e.currentTarget.blur()} aria-label="Название" />
    </div>

    <div class="field">
      <label for="f-status">{cols.length > 4 ? 'Этап' : 'Статус'}</label>
      <select id="f-status" value={status} onchange={(e) => onstatus(e.currentTarget.value)}>
        {#each cols as c (c.id)}<option value={c.id}>{c.name}</option>{/each}
      </select>
    </div>
    <div class="field">
      <span>Приоритет</span>
      <div class="seg2" role="group" aria-label="Приоритет">
        <button type="button" aria-pressed={!priority} onclick={() => onlayer({ priority: null })}>Нет</button>
        {#each PRIORITIES as p (p.id)}
          <button type="button" class="pr {p.cls}" aria-pressed={priority === p.id} title="Alt+{p.id}" onclick={() => onlayer({ priority: p.id })}>
            <b>{p.mark}</b> {p.label}
          </button>
        {/each}
      </div>
    </div>
    <div class="field">
      <span>Тип</span>
      <div class="seg2" role="group" aria-label="Тип">
        <button type="button" aria-pressed={!type} title="Цвет по шаблону списка" onclick={() => onlayer({ type: null })}>По списку</button>
        {#each TYPES as t (t.id)}
          <button type="button" aria-pressed={type === t.id} onclick={() => onlayer({ type: t.id })}><span class="tdot" style="background: var(--type-{t.id})"></span>{t.label}</button>
        {/each}
      </div>
    </div>
    {#if fields.includes('client')}
      <div class="field">
        <label for="f-client">Клиент</label>
        <input id="f-client" value={client} placeholder="Кто заказал" onchange={(e) => onlayer({ client: e.currentTarget.value.trim() })} />
      </div>
    {/if}
    {#if fields.includes('money')}
      <div class="field">
        <label for="f-money">Сумма, ₽</label>
        <input id="f-money" type="number" min="0" step="100" value={money} placeholder="0" onchange={(e) => onlayer({ money: e.currentTarget.value ? Number(e.currentTarget.value) : null })} />
      </div>
    {/if}
    <!-- Срок и время — одно поле, по клику окно «Когда» (DateTimePicker) слева от окна задачи. -->
    <div class="field">
      <span>Срок</span>
      <button type="button" class="when-btn" aria-haspopup="dialog" aria-expanded={picking} onclick={() => (picking = true)}>
        <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="5" width="16" height="15" rx="2" /><path d="M4 10h16M9 3v4M15 3v4" /></svg>
        <span class:muted={!due}>{wt.date}</span>{#if wt.time}<span class="muted">· {wt.time}</span>{/if}
      </button>
    </div>
    <p class="remind-hint">
      {#if !due}Без срока задача только на доске.
      {:else if slot}Срок — в Google Tasks, время — в Спутнике: задача встанет в сетку календаря на это время.
      {:else}Срок попадёт в Google Tasks, в календаре — строка «весь день».{/if}
    </p>
    <div class="field">
      <span>Напомнить</span>
      <RemindChips value={leads} onchange={(v) => saveRemind(v, custom)} />
    </div>
    <div class="field">
      <label for="f-remind">Ещё в своё время</label>
      <div class="remind">
        <select id="f-remind" value={remindKind} onchange={(e) => pickRemind(e.currentTarget.value)}>
          <option value="">Нет</option>
          {#each BEFORE as b (b.days)}<option value="b{b.days}">{b.name} в…</option>{/each}
          <option value="at">Точная дата и время</option>
        </select>
        {#if custom?.kind === 'before'}
          <input type="time" aria-label="Во сколько" value={custom.time ?? DEFAULT_TIME} onchange={(e) => e.currentTarget.value && saveRemind(leads, { ...custom, time: e.currentTarget.value })} />
        {:else if custom?.kind === 'at'}
          <input type="datetime-local" aria-label="Когда напомнить" value={custom.at} onchange={(e) => e.currentTarget.value && saveRemind(leads, { ...custom, at: e.currentTarget.value })} />
        {/if}
      </div>
    </div>
    {#if remind}
      <p class="remind-hint">
        {#if !task.due && custom?.kind !== 'at'}Поставь срок — без него напомнить «до срока» не выйдет.
        {:else if remindWhen}Ближайшее напоминание в Telegram: {remindWhen}{/if}
      </p>
    {/if}
    <!-- Заметка на всю ширину и растёт вместе с текстом. -->
    <div class="notes">
      <label for="f-notes">Заметка</label>
      <textarea id="f-notes" bind:value={notes} use:autosize={notes} onblur={saveNotes} placeholder="Подробности, ссылки, список шагов…"></textarea>
    </div>

    <section class="subs">
      <h3><span>Подзадачи</span><span>{subs.filter((s) => s.status === 'completed').length}/{subs.length}</span></h3>
      <!-- Подзадачу можно переименовать прямо в строке (Enter или уход из поля — сохранить, Esc — отменить) и удалить. -->
      {#each subs as s (s.id)}
        <div class="sub" class:done={s.status === 'completed'}>
          <input class="sp-check" type="checkbox" checked={s.status === 'completed'} aria-label="Выполнено" onchange={(e) => ontoggle(s, e.currentTarget.checked)} />
          <input class="sub-title" value={s.title} aria-label="Подзадача"
            onkeydown={(e) => {
              if (e.key === 'Enter') e.currentTarget.blur();
              else if (e.key === 'Escape') { e.stopPropagation(); e.currentTarget.value = s.title; e.currentTarget.blur(); }
            }}
            onblur={(e) => { const v = e.currentTarget.value.trim(); if (!v) e.currentTarget.value = s.title; else if (v !== s.title) onsubedit(s, v); }} />
          <button class="sub-del" type="button" aria-label="Удалить подзадачу «{s.title}»" title="Удалить" onclick={() => onsubdelete(s)}>
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18" /></svg>
          </button>
        </div>
      {/each}
      <form class="add-row" style="margin-top: 6px" onsubmit={addSub}>
        <input bind:value={subDraft} placeholder="Добавить подзадачу" aria-label="Добавить подзадачу" />
        <button class="sp-btn" type="submit" aria-label="Добавить">+</button>
      </form>
    </section>
  </div>

  <div class="foot">
    <span class="hint">Изменения сразу уходят в Google Tasks · Esc — закрыть</span>
    <div style="display: flex; gap: 8px">
      {#if confirmDelete}
        <button class="sp-btn sp-btn-ghost" type="button" onclick={() => (confirmDelete = false)}>Отмена</button>
        <button class="sp-btn" type="button" style="color: var(--signal-overdue); border-color: currentColor" onclick={ondelete}>Удалить задачу</button>
      {:else}
        <button class="sp-btn sp-btn-ghost" type="button" onclick={() => (confirmDelete = true)}>Удалить</button>
      {/if}
    </div>
  </div>
</aside>

{#if picking}
  <DateTimePicker day={dueToYmd(task.due)} {slot} {remind} title={task.title} place="drawer" {dueDays} {loadEvents}
    onapply={applyWhen} onclose={() => (picking = false)} />
{/if}
