<script>
  import { fade, pop } from './motion.js';
  import { VIEWS } from './templates.js';

  // Изменить список: название, сфера, вид доски. Шаблон колонок здесь не меняется — только в «Шаблонах досок».
  let { list, sphere, spheres, view, shared = false, onsave, onclose } = $props();
  let title = $state(list.title);
  let sph = $state(sphere);
  let vw = $state(view);
  let busy = $state(false);

  async function submit(e) {
    e.preventDefault();
    const t = title.trim();
    if (!t || busy) return;
    busy = true;
    try { await onsave({ title: t, sphere: sph, view: vw }); } finally { busy = false; }
  }
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && onclose()} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose} transition:fade={{ duration: 180 }}></button>
<form transition:pop class="dialog" aria-label="Изменить список" onsubmit={submit}>
  <h2>Изменить список</h2>
  <div class="field">
    <label for="el-title">Название</label>
    <input id="el-title" bind:value={title} disabled={shared} />
  </div>
  {#if !shared}
    <div class="field">
      <span class="cap">Сфера</span>
      <div class="stg-chips" style="max-width: none; justify-content: flex-start">
        <button type="button" class="c" aria-pressed={!sph} onclick={() => (sph = null)}>Без сферы</button>
        {#each spheres as s (s.id)}
          <button type="button" class="c" aria-pressed={sph === s.id} onclick={() => (sph = s.id)}>{s.name}</button>
        {/each}
      </div>
    </div>
  {/if}
  <div class="field">
    <span class="cap">Вид доски</span>
    <div class="stg-chips" style="max-width: none; justify-content: flex-start">
      {#each VIEWS as v (v.id)}
        <button type="button" class="c" aria-pressed={vw === v.id} title={v.hint} onclick={() => (vw = v.id)}>{v.name}</button>
      {/each}
    </div>
  </div>
  <p class="hint">Колонки и правила досок меняются в «Шаблонах досок», здесь — только сам список.</p>
  <div class="actions">
    <button class="sp-btn sp-btn-ghost" type="button" onclick={onclose}>Отмена</button>
    <button class="sp-btn sp-btn-primary" type="submit" disabled={busy || !title.trim()}>{busy ? 'Сохраняю…' : 'Сохранить'}</button>
  </div>
</form>
