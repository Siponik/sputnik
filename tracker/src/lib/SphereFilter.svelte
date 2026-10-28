<script>
  // Фильтр по сфере для «Сегодня» и «Календаря»: тихий выпадающий список (без сфер — не показывается).
  import { sphereColor } from './spheres.js';
  import Dropdown from './Dropdown.svelte';
  let { spheres, value = '', onchange } = $props();
  const options = $derived([{ id: '', label: 'Все сферы' }, ...spheres.map((s) => ({ id: s.id, label: s.name, color: sphereColor(s) }))]);
</script>

{#if spheres.length}
  <Dropdown ghost small mark="dot" label="Сфера" title="Показывать задачи только одной сферы" cls="sph-sel"
    value={spheres.some((s) => s.id === value) ? value : ''} {options} {onchange} />
{/if}
