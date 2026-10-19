<script>
  import { dueToYmd, ymdToDue } from './api.js';

  let { task, list, subs, status, onclose, onsave, onstatus, ondelete, ontoggle, onaddsub } = $props();

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
    if (e.key === 'Escape') onclose();
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
      <input class="sp-check" type="checkbox" style="margin-top: 9px" checked={task.status === 'completed'} aria-label="Выполнено" onchange={(e) => ontoggle(task, e.currentTarget.checked)} />
      <input class="title-input" bind:value={title} onblur={saveTitle} onkeydown={(e) => e.key === 'Enter' && e.currentTarget.blur()} aria-label="Название" />
    </div>

    <div class="field">
      <label for="f-status">Статус</label>
      <select id="f-status" value={status} onchange={(e) => onstatus(e.currentTarget.value)}>
        <option value="inbox">Входящие</option>
        <option value="doing">В работе</option>
        <option value="review">На ревью</option>
        <option value="done">Готово</option>
      </select>
    </div>
    <div class="field">
      <label for="f-due">Срок</label>
      <input id="f-due" type="date" bind:value={due} onchange={saveDue} />
    </div>
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
