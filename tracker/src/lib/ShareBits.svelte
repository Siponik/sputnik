<script>
  import AvStack from './AvStack.svelte';
  // Рядом с названием доски общей сферы: кружки участников и «＋ Пригласить» (только владельцу).
  // share — { people, me, owner, oninvite } из App.
  let { share } = $props();
</script>

<span class="bd-share">
  <AvStack people={share.people} size={24} me={share.me} max={4} />
  {#if share.owner}<button type="button" class="sh-btn" onclick={share.oninvite}>＋ Пригласить</button>
  {:else}<button type="button" class="sh-btn ghost" title="Кто в сфере" onclick={share.oninvite}>Участники</button>{/if}
</span>
