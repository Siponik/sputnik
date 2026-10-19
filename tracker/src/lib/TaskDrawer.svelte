<script>
  import { dueToYmd, ymdToDue, ymd } from './api.js';
  import { BEFORE, DEFAULT_TIME, remindLabel } from './reminders.js';

  let { task, list, subs, status, cols, remind = null, slot = null, onclose, onsave, onstatus, ondelete, ontoggle, onaddsub, onremind, onslot } = $props();

  // Время задачи живёт в слое Спутника: в Google Tasks у срока нет часов.
  const toMin = (v) => { const [h, m] = v.split(':').map(Number); return h * 60 + m; };
  const fromMin = (m) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
  function setSlotFrom(v) {
    if (!v) return onslot(null);
    const len = slot ? Math.max(15, toMin(slot.e) - toMin(slot.s)) : 60;
    onslot({ s: v, e: fromMin(Math.min(toMin(v) + len, 23 * 60 + 59)) });
  }
  function setSlotTo(v) {
    if (v && toMin(v) > toMin(slot.s)) onslot({ ...slot, e: v });
  }

  const remindKind = $derived(!remind ? '' : remind.kind === 'at' ? 'at' : `b${remind.days ?? 0}`);
  const remindWhen = $derived(remindLabel(remind, task));

  function pickRemind(v) {
    if (!v) return onremind(null);
    if (v === 'at') {
      const day = dueToYmd(task.due) || ymd(new Date(Date.now() + 864e5));
      return onremind({ kind: 'at', at: remind?.kind === 'at' ? remind.at : `${day}T${DEFAULT_TIME}` });
    }
    onremind({ kind: 'before', days: Number(v.slice(1)), time: remind?.time ?? DEFAULT_TIME });
  }

  let title = $state('');
  let notes = $state('');
  let due = $state('');
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
      due = dueToYmd(task.due);
    }
  });

  function saveTitle() {
    const t = title.trim();
    if (t && t !== task.title) onsave({ title: t });
  }
  function saveNotes() {
    if (notes !== (task.notes ?? '')) onsave({ notes });
  }
  function saveDue() {
    if (due !== dueToYmd(task.due)) onsave({ due: ymdToDue(due) });
  }
  async function addSub(e) {
    e.preventDefault();
    const t = subDraft.trim();
    if (!t) return;
    subDraft = '';
    await onaddsub(t);
  }
  function key(e) {
    if (e.key === 'Escape') { saveTitle(); saveNotes(); onclose(); }
  }
</script>

<svelte:window onkeydown={key} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose}></button>
<aside class="drawer" aria-label="Задача">
  <div class="scroll">
    <div class="top">
      <span>{list?.title}</span>
      <button class="sp-btn sp-btn-ghost" type="button" aria-label="Закрыть" style="min-height: 32px; padding: 0 8px" onclick={onclose}>
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
      <label for="f-due">Срок</label>
      <input id="f-due" type="date" bind:value={due} onchange={saveDue} />
    </div>
    <div class="field">
      <label for="f-from">Время</label>
      <div class="time-row">
        <input id="f-from" type="time" value={slot?.s ?? ''} disabled={!due} aria-label="Начало" onchange={(e) => setSlotFrom(e.currentTarget.value)} />
        <span>–</span>
        <input type="time" value={slot?.e ?? ''} disabled={!due || !slot} aria-label="Конец" onchange={(e) => setSlotTo(e.currentTarget.value)} />
        {#if slot}<button class="sp-btn sp-btn-ghost" type="button" style="min-height: 30px" onclick={() => onslot(null)}>Весь день</button>{/if}
      </div>
    </div>
    {#if !due}<p class="remind-hint">Поставь срок — тогда можно выбрать время, и задача встанет в сетку календаря.</p>{/if}
    <div class="field">
      <label for="f-remind">Напоминание</label>
      <div class="remind">
        <select id="f-remind" value={remindKind} onchange={(e) => pickRemind(e.currentTarget.value)}>
          <option value="">Нет</option>
          {#each BEFORE as b (b.days)}<option value="b{b.days}">{b.name}</option>{/each}
          <option value="at">Точная дата и время</option>
        </select>
        {#if remind?.kind === 'before'}
          <input type="time" aria-label="Во сколько" value={remind.time ?? DEFAULT_TIME} onchange={(e) => e.currentTarget.value && onremind({ ...remind, time: e.currentTarget.value })} />
        {:else if remind?.kind === 'at'}
          <input type="datetime-local" aria-label="Когда напомнить" value={remind.at} onchange={(e) => e.currentTarget.value && onremind({ ...remind, at: e.currentTarget.value })} />
        {/if}
      </div>
    </div>
    {#if remind}
      <p class="remind-hint">
        {#if remind.kind === 'before' && !task.due}Поставь срок — без него напомнить «до срока» не выйдет.
        {:else if remindWhen}Напомню в Telegram: {remindWhen}{/if}
      </p>
    {/if}
    <div class="field top">
      <label for="f-notes">Заметка</label>
      <textarea id="f-notes" bind:value={notes} onblur={saveNotes} placeholder="Подробности, ссылки"></textarea>
    </div>

    <section class="subs">
      <h3><span>Подзадачи</span><span>{subs.filter((s) => s.status === 'completed').length}/{subs.length}</span></h3>
      {#each subs as s (s.id)}
        <label class="sub" class:done={s.status === 'completed'}>
          <input class="sp-check" type="checkbox" checked={s.status === 'completed'} onchange={(e) => ontoggle(s, e.currentTarget.checked)} />
          <span>{s.title}</span>
        </label>
      {/each}
      <form class="add-row" style="margin-top: 6px" onsubmit={addSub}>
        <input bind:value={subDraft} placeholder="Добавить подзадачу" aria-label="Добавить подзадачу" />
        <button class="sp-btn" type="submit" aria-label="Добавить">+</button>
      </form>
    </section>
  </div>

  <div class="foot">
    <span class="hint">Изменения сразу уходят в Google Tasks</span>
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
