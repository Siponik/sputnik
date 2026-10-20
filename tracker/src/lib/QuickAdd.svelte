<script>
  import { fade, pop } from './motion.js';
  import { untrack } from 'svelte';
  import { TYPES, PRIORITIES, autosize } from './meta.js';
  import { whenText } from './when.js';
  import DateTimePicker from './DateTimePicker.svelte';

  // Окно «Создать» (кнопка в шапке, N / Ctrl+N): задача в Google Tasks, событие или день рождения в Google Календаре.
  let { lists, listId = null, day = '', s = '', e = '', dueDays = new Set(), loadEvents = null, oncreate, oncreateevent, oncreatebirthday, onclose } = $props();

  const KINDS = [
    { id: 'task', label: 'Задача', key: '1' },
    { id: 'event', label: 'Событие', key: '2' },
    { id: 'birthday', label: 'День рождения', key: '3' },
  ];

  // Подставленные значения берём один раз, дальше поля живут сами.
  const init = untrack(() => ({ list: listId ?? lists[0]?.id ?? '', day, s, e }));
  let kind = $state('task');
  let title = $state('');
  let list = $state(init.list);
  let due = $state(init.day);
  let slot = $state(init.s ? { s: init.s, e: init.e || init.s } : null); // время — { s, e } или null (весь день)
  let picking = $state(false);
  let type = $state(null);
  let priority = $state(null);
  let notes = $state('');
  let busy = $state(false);

  const wt = $derived(whenText(due, due && kind !== 'birthday' ? slot : null));
  const needDate = $derived(kind !== 'task' && !due);
  const canSubmit = $derived(!!title.trim() && !busy && !needDate && (kind !== 'task' || !!list));

  function applyWhen(r) { picking = false; due = r.day ?? ''; slot = r.slot ?? null; }

  async function submit(ev) {
    ev?.preventDefault();
    if (!canSubmit) return;
    const t = title.trim();
    busy = true;
    const when = due && kind !== 'birthday' ? slot : null;
    let ok;
    if (kind === 'task') {
      const layer = {};
      if (type) layer.type = type;
      if (priority) layer.priority = priority;
      ok = await oncreate({ title: t, listId: list, due, slot: when, layer, notes: notes.trim() });
    } else if (kind === 'event') ok = await oncreateevent({ title: t, day: due, slot: when, notes: notes.trim() });
    else ok = await oncreatebirthday({ name: t, day: due });
    busy = false;
    if (ok) onclose();
  }

  // Esc — закрыть, Ctrl+Enter — создать, Alt+1/2/3 — вид записи.
  function key(ev) {
    if (document.querySelector('.keyhelp, .dtp')) return; // открыто окно «Когда» — Esc закрывает его
    if (ev.key === 'Escape') { ev.preventDefault(); onclose(); }
    else if (ev.key === 'Enter' && (ev.ctrlKey || ev.metaKey)) submit(ev);
    else if (ev.altKey && /^Digit[1-3]$/.test(ev.code)) { ev.preventDefault(); kind = KINDS[ev.code.slice(5) - 1].id; }
  }
</script>

<svelte:window onkeydown={key} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose} transition:fade={{ duration: 180 }}></button>
<form transition:pop class="dialog quick" aria-label="Создать" onsubmit={submit}>
  <h2>Создать</h2>
  <div class="seg2 kinds" role="group" aria-label="Что создаём">
    {#each KINDS as k (k.id)}
      <button type="button" aria-pressed={kind === k.id} title="Alt+{k.key}" onclick={() => (kind = k.id)}>{k.label}</button>
    {/each}
  </div>
  <!-- svelte-ignore a11y_autofocus -->
  <input class="title-input" bind:value={title} autofocus aria-label={kind === 'birthday' ? 'Чей день рождения' : 'Название'}
    placeholder={kind === 'birthday' ? 'Чей? Например «Аня»' : kind === 'event' ? 'Что за событие?' : 'Что сделать?'} />
  {#if kind !== 'birthday'}
    <textarea class="q-notes" bind:value={notes} use:autosize={notes} aria-label="Описание"
      placeholder={kind === 'event' ? 'Описание: где, ссылка на созвон…' : 'Описание: подробности, ссылки, шаги…'}></textarea>
  {/if}

  {#if kind === 'task'}
    <div class="field">
      <label for="q-list">Список</label>
      <select id="q-list" bind:value={list}>
        {#each lists as l (l.id)}<option value={l.id}>{l.title}</option>{/each}
      </select>
    </div>
    <div class="field">
      <span>Тип</span>
      <div class="seg2" role="group" aria-label="Тип">
        <button type="button" aria-pressed={!type} onclick={() => (type = null)}>По списку</button>
        {#each TYPES as t (t.id)}
          <button type="button" aria-pressed={type === t.id} onclick={() => (type = t.id)}><span class="tdot" style="background: var(--type-{t.id})"></span>{t.label}</button>
        {/each}
      </div>
    </div>
    <div class="field">
      <span>Приоритет</span>
      <div class="seg2" role="group" aria-label="Приоритет">
        <button type="button" aria-pressed={!priority} onclick={() => (priority = null)}>Нет</button>
        {#each PRIORITIES as p (p.id)}
          <button type="button" class="pr {p.cls}" aria-pressed={priority === p.id} onclick={() => (priority = p.id)}><b>{p.mark}</b> {p.label}</button>
        {/each}
      </div>
    </div>
  {/if}

  <!-- Дата и время — одно поле, по клику окно «Когда». У дня рождения — только дата. -->
  <div class="field">
    <span>{kind === 'task' ? 'Срок' : 'Дата'}</span>
    <button type="button" class="when-btn" aria-haspopup="dialog" aria-expanded={picking} onclick={() => (picking = true)}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="5" width="16" height="15" rx="2" /><path d="M4 10h16M9 3v4M15 3v4" /></svg>
      <span class:muted={!due}>{wt.date}</span>{#if wt.time && kind !== 'birthday'}<span class="muted">· {wt.time}</span>{/if}
    </button>
  </div>
  <p class="hint">
    {#if kind === 'birthday'}{due ? 'Каждый год в этот день — в Google Календаре, в Спутнике золотом, как дни рождения из контактов.' : 'Выбери дату.'}
    {:else if kind === 'event'}{due ? (slot ? 'Событие в Google Календаре на это время.' : 'Событие на весь день в Google Календаре.') : 'Выбери дату.'}
    {:else if !due}Без срока задача попадёт только на доску.
    {:else if slot}Задача в Google Tasks, в календаре встанет в сетку на это время.
    {:else}Задача в Google Tasks, в календаре — в строке «весь день».{/if}
    Ctrl+Enter — создать.
  </p>
  <div class="actions">
    <button class="sp-btn sp-btn-ghost" type="button" onclick={onclose}>Отмена</button>
    <button class="sp-btn sp-btn-primary" type="submit" disabled={!canSubmit}>Создать</button>
  </div>
</form>

{#if picking}
  <DateTimePicker day={due} slot={kind === 'birthday' ? null : slot} allowTime={kind !== 'birthday'} {title} {dueDays} {loadEvents}
    onapply={applyWhen} onclose={() => (picking = false)} />
{/if}
