<script>
  import Avatar from './Avatar.svelte';
  // Стопка кружков участников внахлёст (7 px); больше max — «+N».
  let { people = [], size = 18, me = '', max = 3, title = '' } = $props();
  const shown = $derived(people.slice(0, max));
  const rest = $derived(people.length - shown.length);
</script>

<span class="sh-stack" style="--s: {size}px" title={title || people.map((p) => p.name).join(', ')}>
  {#each shown as p (p.email)}<Avatar m={p} {size} me={p.email === me} title={p.name} />{/each}
  {#if rest > 0}<span class="sh-av more" style="--s: {size}px">+{rest}</span>{/if}
</span>
