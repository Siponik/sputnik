<script>
  import { leadsFor } from './reminders.js';

  // Напоминания кнопками: можно выбрать несколько («за день» и «за час»). value — минуты до начала.
  // kind — task | event | birthday (у дня рождения свой набор: в день, за день, за 3 дня…).
  let { value = [], kind = 'task', onchange } = $props();

  const opts = $derived(leadsFor(kind));
  function toggle(min) {
    onchange(value.includes(min) ? value.filter((m) => m !== min) : [...value, min].sort((a, b) => b - a));
  }
</script>

<div class="seg2 remind-chips" role="group" aria-label="Напоминания">
  <button type="button" aria-pressed={!value.length} onclick={() => onchange([])}>Нет</button>
  {#each opts as o (o.min)}
    <button type="button" aria-pressed={value.includes(o.min)} onclick={() => toggle(o.min)}>{o.name}</button>
  {/each}
</div>
