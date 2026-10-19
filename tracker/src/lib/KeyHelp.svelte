<script>
  import { HOTKEYS } from './keys.js';
  let { onclose } = $props();
</script>

<svelte:window onkeydown={(e) => { if (e.key === 'Escape' || e.key === '?') { e.preventDefault(); onclose(); } }} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose}></button>
<div class="dialog keyhelp" role="dialog" aria-label="Горячие клавиши">
  <h2>Горячие клавиши</h2>
  <p class="hint">Работают и в русской раскладке. Одиночные клавиши не срабатывают, пока курсор стоит в поле ввода.</p>
  <div class="kh-grid">
    {#each HOTKEYS as g (g.group)}
      <section>
        <h3>{g.group}</h3>
        {#each g.keys as [k, what] (k)}
          <div class="kh-row"><span class="kbd">{k}</span><span>{what}</span></div>
        {/each}
      </section>
    {/each}
  </div>
  <div class="actions"><button class="sp-btn sp-btn-primary" type="button" onclick={onclose}>Понятно</button></div>
</div>
