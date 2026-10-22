<script>
  // Выбор исполнителя в общей сфере (docs/design-v2.md, «Общие сферы» 4): поиск «Кому отдать…», «Я», участники,
  // «Без исполнителя». Цифры 1–9 и 0 (пока поиск пуст), ↑/↓ и Enter. Esc и клик мимо — закрыть (Popover).
  import { tick } from 'svelte';
  import Popover from './Popover.svelte';
  import Avatar from './Avatar.svelte';
  import { whoOptions } from './sharedcore.js';

  // cur — почта нынешнего исполнителя (null — никого); counts — открытых задач у каждого (whoCounts).
  let { anchor, people = [], me = '', cur = null, counts = {}, onpick, onclose } = $props();
  let q = $state('');
  let sel = $state(0);
  let qInput = $state(null);
  $effect(() => { tick().then(() => qInput?.focus()); });
  const rows = $derived(whoOptions(people, me, q, counts));
  $effect(() => { q; sel = 0; });

  function key(ev) {
    let done = true;
    if (ev.key === 'ArrowDown') sel = Math.min(rows.length - 1, sel + 1);
    else if (ev.key === 'ArrowUp') sel = Math.max(0, sel - 1);
    else if (ev.key === 'Enter') { const r = rows[sel]; if (r) onpick(r.email); }
    else if (!q && /^Digit[0-9]$/.test(ev.code) && !ev.altKey && !ev.ctrlKey) {
      const r = rows.find((x) => x.key === ev.code.slice(5));
      if (r) onpick(r.email);
    } else done = false;
    if (done) { ev.preventDefault(); ev.stopPropagation(); }
  }
</script>

<Popover {anchor} width={300} label="Исполнитель" {onclose}>
  <div class="sh-pick" role="listbox" aria-label="Исполнитель" tabindex="-1">
    <input class="sh-pq" bind:this={qInput} bind:value={q} placeholder="Кому отдать…" aria-label="Кому отдать" onkeydown={key} autocomplete="off" spellcheck="false" />
    {#each rows as r, i (r.email ?? '-')}
      <button type="button" class="sh-po" class:on={sel === i} role="option" aria-selected={r.email === cur} onpointerenter={() => (sel = i)} onclick={() => onpick(r.email)}>
        <Avatar m={r.m} size={24} me={r.email === me} />
        <span class="nm">{r.label}</span>
        {#if r.email === cur}<span class="ck" aria-label="сейчас">✓</span>
        {:else if r.note}<span class="nt">{r.note}</span>
        {:else}<span class="ct">{r.n}</span>{/if}
        {#if r.key}<kbd>{r.key}</kbd>{/if}
      </button>
    {/each}
    {#if !rows.length}<p class="sh-pe">Никого не нашлось</p>{/if}
  </div>
</Popover>
