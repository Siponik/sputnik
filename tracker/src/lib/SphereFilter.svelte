<script>
  // Фильтр по сфере для «Сегодня» и «Календаря»: компактный выпадающий список (без сфер — не показывается).
  import { sphereColor } from './spheres.js';
  let { spheres, value = '', onchange } = $props();
  const cur = $derived(spheres.find((s) => s.id === value) ?? null);
</script>

{#if spheres.length}
  <label class="sph-sel" class:on={!!cur} style={cur ? `--sc: ${sphereColor(cur)}` : ''} title="Показывать задачи только одной сферы">
    <span class="dot" aria-hidden="true"></span>
    <select aria-label="Сфера" value={value} onchange={(e) => onchange(e.currentTarget.value)}>
      <option value="">Все сферы</option>
      {#each spheres as s (s.id)}<option value={s.id}>{s.name}</option>{/each}
    </select>
    <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 9l6 6 6-6" /></svg>
  </label>
{/if}
