<script>
  import { fade, pop } from './motion.js';
  // Подтверждение необратимого удаления. Фокус — на «Отмена», чтобы случайный Enter ничего не удалил.
  // onconfirm может быть async: пока идёт, кнопки заняты; окно закрывает App.
  let { title, text = '', note = '', yes = 'Удалить', onconfirm, onclose } = $props();
  let busy = $state(false);
  let cancel = $state(null);
  $effect(() => { cancel?.focus(); });

  async function go() {
    if (busy) return;
    busy = true;
    try { await onconfirm(); } finally { busy = false; }
  }
</script>

<svelte:window onkeydowncapture={(e) => { if (e.key === 'Escape' && !busy) { e.preventDefault(); e.stopPropagation(); onclose(); } }} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={() => !busy && onclose()} transition:fade={{ duration: 180 }}></button>
<div transition:pop class="dialog del-ask" role="alertdialog" aria-modal="true" aria-labelledby="del-t" aria-describedby="del-d">
  <h2 id="del-t">{title}</h2>
  {#if text}<p id="del-d">{text}</p>{/if}
  {#if note}<p class="hint">{note}</p>{/if}
  <div class="actions">
    <button bind:this={cancel} class="sp-btn sp-btn-ghost" type="button" disabled={busy} onclick={onclose}>Отмена</button>
    <button class="sp-btn danger" type="button" disabled={busy} onclick={go}>{busy ? 'Удаляю…' : yes}</button>
  </div>
</div>
