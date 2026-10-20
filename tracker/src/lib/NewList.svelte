<script>
  import { BUILTIN, VIEWS } from './templates.js';

  // templates — встроенные (с правками) и свои шаблоны (templatesFrom).
  // BLANK — «Пустой шаблон»: App создаёт свой шаблон «Надо → Делаю → Готово» и сразу открывает его настройку.
  let { templates = BUILTIN, oncreate, onclose } = $props();
  const BLANK = '__blank';
  const TEMPLATES = $derived(templates);
  const viewName = (t) => VIEWS.find((v) => v.id === t.view)?.name ?? 'Канбан';

  let tpl = $state(BUILTIN[0].id);
  let title = $state(BUILTIN[0].title ?? '');
  let touched = false;
  let busy = $state(false);

  function pick(t) {
    tpl = t.id;
    if (!touched) title = t.title ?? '';
  }

  async function submit(e) {
    e.preventDefault();
    const name = title.trim();
    if (!name || busy) return;
    busy = true;
    try { await oncreate(name, tpl); } finally { busy = false; }
  }
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && onclose()} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose}></button>
<form class="dialog" aria-label="Новый список" onsubmit={submit}>
  <h2>Новый список</h2>
  <div class="field">
    <label for="nl-title">Название</label>
    <input id="nl-title" bind:value={title} oninput={() => (touched = true)} />
  </div>
  <div class="tpls" role="radiogroup" aria-label="Шаблон">
    {#each TEMPLATES as t (t.id)}
      <button type="button" class="tpl-card" role="radio" aria-checked={tpl === t.id} onclick={() => pick(t)}>
        <b>{t.name}<small>{viewName(t)}</small></b>
        <span class="cols">{t.cols.map((c) => c.name).join(' → ')}</span>
      </button>
    {/each}
    <button type="button" class="tpl-card blank" role="radio" aria-checked={tpl === BLANK} onclick={() => (tpl = BLANK)}>
      <b>＋ Пустой шаблон<small>свой</small></b>
      <span class="cols">Надо → Делаю → Готово · после создания откроется настройка колонок</span>
    </button>
  </div>
  <p class="hint">Список появится в Google Tasks, шаблон помнит только Спутник.</p>
  <div class="actions">
    <button class="sp-btn sp-btn-ghost" type="button" onclick={onclose}>Отмена</button>
    <button class="sp-btn sp-btn-primary" type="submit" disabled={busy || !title.trim()}>{busy ? 'Создаю…' : 'Создать список'}</button>
  </div>
</form>
