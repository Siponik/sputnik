<script>
  import { toast, pause, resume, act, hide } from '../stores/toast.svelte.js';
</script>

{#if toast.msg}
  <div class="toast" role="status" onmouseenter={pause} onmouseleave={resume}>
    {#key toast.n}<span class="timer" aria-hidden="true"></span>{/key}
    <span>{toast.msg}</span>
    {#if toast.undo}<button type="button" class="undo" onclick={act}>{toast.label}</button>{/if}
    <button type="button" onclick={hide}>Скрыть</button>
  </div>
{/if}
