<script>
  // Кружок участника общей сферы (docs/design-v2.md, «Участник — кружок»): первая буква, цвет участника.
  // me — свой (обводка clay), не принявший приглашение — бледный с золотой точкой, m = null — «без исполнителя» (пунктир с «+»).
  let { m = null, size = 24, me = false, title = '' } = $props();
</script>

{#if m}
  <span class="sh-av" class:me class:wait={!m.joined} style="--s: {size}px; --ac: {m.color}" title={title || m.name} aria-label={title || m.name}>{m.letter}</span>
{:else}
  <span class="sh-av none" style="--s: {size}px" title={title || 'Без исполнителя'} aria-label={title || 'Без исполнителя'}>+</span>
{/if}
