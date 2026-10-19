<script>
  import { untrack } from 'svelte';
  import { TYPES, PRIORITIES, autosize } from './meta.js';

  // Окно «Создать» (кнопка в шапке, N / Ctrl+N): задача в Google Tasks, событие или день рождения в Google Календаре.
  let { lists, listId = null, day = '', s = '', e = '', oncreate, oncreateevent, oncreatebirthday, onclose } = $props();

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
  let from = $state(init.s);
  let to = $state(init.e);
  let type = $state(null);
  let priority = $state(null);
  let notes = $state('');
  let busy = $state(false);

  const toMin = (v) => { const [h, m] = v.split(':').map(Number); return h * 60 + m; };
  const bad = $derived(!!from && !!to && toMin(to) <= toMin(from));
  const needDate = $derived(kind !== 'task' && !due);
  const canSubmit = $derived(!!title.trim() && !bad && !busy && !needDate && (kind !== 'task' || !!list));

  // Поставили начало — конец через час, если его нет или он раньше.
  function setFrom(v) {
    from = v;
    if (v && (!to || toMin(to) <= toMin(v))) {
      const m = Math.min(toMin(v) + 60, 23 * 60 + 59);
      to = `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
    }
  }

  async function submit(ev) {
    ev?.preventDefault();
    if (!canSubmit) return;
    const t = title.trim();
    busy = true;
    const slot = due && from ? { s: from, e: to || from } : null;
    let ok;
    if (kind === 'task') {
      const layer = {};
      if (type) layer.type = type;
      if (priority) layer.priority = priority;
      ok = await oncreate({ title: t, listId: list, due, slot, layer, notes: notes.trim() });
    } else if (kind === 'event') ok = await oncreateevent({ title: t, day: due, slot, notes: notes.trim() });
    else ok = await oncreatebirthday({ name: t, day: due });
    busy = false;
    if (ok) onclose();
  }

  // Esc — закрыть, Ctrl+Enter — создать, Alt+1/2/3 — вид записи.
  function key(ev) {
    if (document.querySelector('.keyhelp')) return;
    if (ev.key === 'Escape') { ev.preventDefault(); onclose(); }
    else if (ev.key === 'Enter' && (ev.ctrlKey || ev.metaKey)) submit(ev);
    else if (ev.altKey && /^Digit[1-3]$/.test(ev.code)) { ev.preventDefault(); kind = KINDS[ev.code.slice(5) - 1].id; }
  }
</script>

<svelte:window onkeydown={key} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose}></button>
<form class="dialog quick" aria-label="Создать" onsubmit={submit}>
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

  <div class="field">
    <label for="q-due">{kind === 'task' ? 'Срок' : 'Дата'}</label>
    <input id="q-due" type="date" bind:value={due} />
  </div>
  {#if kind !== 'birthday'}
    <div class="field">
      <label for="q-from">Время</label>
      <div class="time-row">
        <input id="q-from" type="time" value={from} disabled={!due} onchange={(ev) => setFrom(ev.currentTarget.value)} aria-label="Начало" />
        <span>–</span>
        <input type="time" bind:value={to} disabled={!due || !from} aria-label="Конец" />
        {#if from}<button class="sp-btn sp-btn-ghost" type="button" style="min-height: 30px" onclick={() => { from = ''; to = ''; }}>Весь день</button>{/if}
      </div>
    </div>
  {/if}
  <p class="hint">
    {#if bad}Конец должен быть позже начала.
    {:else if kind === 'birthday'}{due ? 'Каждый год в этот день — в Google Календаре, в Спутнике золотом, как дни рождения из контактов.' : 'Выбери дату.'}
    {:else if kind === 'event'}{due ? (from ? 'Событие в Google Календаре на это время.' : 'Событие на весь день в Google Календаре.') : 'Выбери дату.'}
    {:else if !due}Без срока задача попадёт только на доску.
    {:else if from}Задача в Google Tasks, в календаре встанет в сетку на это время.
    {:else}Задача в Google Tasks, в календаре — в строке «весь день».{/if}
    Ctrl+Enter — создать.
  </p>
  <div class="actions">
    <button class="sp-btn sp-btn-ghost" type="button" onclick={onclose}>Отмена</button>
    <button class="sp-btn sp-btn-primary" type="submit" disabled={!canSubmit}>Создать</button>
  </div>
</form>
