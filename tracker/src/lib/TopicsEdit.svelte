<script>
  // «Темы…» из меню шапки вида «Стикеры»: переименовать, цвет (палитра сфер), порядок, удалить (дела уходят в «Разное»), добавить.
  // Сохраняется целиком в слой lists[id].topics.
  import { untrack } from 'svelte';
  import { fade, pop } from './motion.js';
  import { SPHERE_COLORS } from './spheres.js';
  import { topicColor } from './stickers.js';

  let { topics, count = () => 0, onsave, onclose } = $props();
  let rows = $state(untrack(() => topics.map((t) => ({ ...t }))));

  const nextColor = (c) => SPHERE_COLORS[(SPHERE_COLORS.findIndex((x) => x.id === c) + 1) % SPHERE_COLORS.length].id;
  function move(i, d) {
    const j = i + d;
    if (j < 0 || j >= rows.length) return;
    [rows[i], rows[j]] = [rows[j], rows[i]];
  }
  function add() {
    rows.push({ id: 'tp' + Date.now().toString(36), name: '', color: SPHERE_COLORS[rows.length % SPHERE_COLORS.length].id });
  }
  function save(e) {
    e.preventDefault();
    onsave(rows.map((r) => ({ ...r, name: r.name.trim() || 'Тема' })));
  }
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && onclose()} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose} transition:fade={{ duration: 180 }}></button>
<form transition:pop class="dialog tpx" aria-label="Темы списка" onsubmit={save}>
  <h2>Темы</h2>
  <p class="hint">Колонки вида «Стикеры». Клик по квадратику — другой цвет. Удалённая тема — её дела уйдут в «Разное».</p>
  <div class="tpx-rows">
    {#each rows as r, i (r.id)}
      <div class="tpx-row">
        <button type="button" class="tpx-c" style="--tc: {topicColor(r)}" title="Цвет" aria-label="Цвет темы «{r.name}»" onclick={() => (r.color = nextColor(r.color))}></button>
        <input bind:value={r.name} aria-label="Название темы" placeholder="Название" />
        {#if count(r.id)}<span class="muted">{count(r.id)}</span>{/if}
        <button type="button" class="hb" aria-label="Выше" title="Выше" disabled={i === 0} onclick={() => move(i, -1)}>↑</button>
        <button type="button" class="hb" aria-label="Ниже" title="Ниже" disabled={i === rows.length - 1} onclick={() => move(i, 1)}>↓</button>
        <button type="button" class="hb" aria-label="Удалить тему «{r.name}»" title="Удалить" onclick={() => rows.splice(i, 1)}>✕</button>
      </div>
    {/each}
  </div>
  <button type="button" class="sp-btn sp-btn-ghost" onclick={add}>＋ Тема</button>
  <div class="actions">
    <button class="sp-btn sp-btn-ghost" type="button" onclick={onclose}>Отмена</button>
    <button class="sp-btn sp-btn-primary" type="submit">Сохранить</button>
  </div>
</form>
