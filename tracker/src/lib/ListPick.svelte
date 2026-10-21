<script>
  // Выбор списка поповером («Сегодня»: золотой чип «→ список» и чип у входящих от Claude). Как окно выбора в «Создать»:
  // поиск, группы по сферам, угаданный сверху, цифры 1–9, ↑/↓ и Enter. Esc и клик мимо — закрыть (Popover).
  import { tick } from 'svelte';
  import Popover from './Popover.svelte';
  import { spheresFrom, sphereOf, sphereColor } from './spheres.js';
  import { viewOf } from './route.js';
  import { VIEWS } from './templates.js';

  let { anchor, lists, layer = {}, current = null, guess = null, onpick, onclose } = $props();

  const VIEW_NAME = Object.fromEntries(VIEWS.map((v) => [v.id, v.name]));
  const spheres = $derived(spheresFrom(layer));
  const colorOf = (id) => { const sp = spheres.find((x) => x.id === sphereOf(id, layer)); return sp ? sphereColor(sp) : 'var(--ink-faint)'; };
  let q = $state('');
  let sel = $state(-1);
  let qInput = $state(null);
  $effect(() => { tick().then(() => qInput?.focus()); });

  const groups = $derived.by(() => {
    const k = q.trim().toLowerCase().replace(/ё/g, 'е');
    const hit = (l) => !k || l.title.toLowerCase().replace(/ё/g, 'е').includes(k);
    return [...spheres.map((sp) => ({ sp, items: lists.filter((l) => sphereOf(l.id, layer) === sp.id && hit(l)) })),
      { sp: null, items: lists.filter((l) => !sphereOf(l.id, layer) && hit(l)) }].filter((g) => g.items.length);
  });
  const flat = $derived(groups.flatMap((g) => g.items));
  const sug = $derived(!q && guess ? lists.find((l) => l.id === guess) : null);

  function key(ev) {
    let done = true;
    if (ev.key === 'ArrowDown') sel = Math.min(flat.length - 1, sel + 1);
    else if (ev.key === 'ArrowUp') sel = Math.max(-1, sel - 1);
    else if (ev.key === 'Enter') { const l = sel < 0 ? (q.trim() ? flat[0] : sug ?? flat[0]) : flat[sel]; if (l) onpick(l.id); }
    else if (!q && /^Digit[1-9]$/.test(ev.code) && !ev.altKey) { const l = flat[ev.code.slice(5) - 1]; if (l) onpick(l.id); }
    else done = false;
    if (done) { ev.preventDefault(); ev.stopPropagation(); }
  }
</script>

<Popover {anchor} width={340} label="Куда положить" {onclose}>
  <div class="lp" role="listbox" aria-label="Куда положить" tabindex="-1">
    <div class="cr-srch"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="M20 20l-4.5-4.5" /></svg>
      <input bind:this={qInput} bind:value={q} placeholder="Найти список…" aria-label="Найти список" onkeydown={key} /></div>
    {#if sug}
      <button type="button" class="cr-it sug" class:on={sel === -1} style="--sc: {colorOf(sug.id)}" onclick={() => onpick(sug.id)}>
        <i class="lp-sq"></i><span class="cr-itn">{sug.title}<small>{VIEW_NAME[viewOf(sug.id, layer)] ?? 'Канбан'}</small></span>
        <span class="cr-itwhy">✦ угадано</span>
      </button>
    {/if}
    {#each groups as g (g.sp?.id ?? '-')}
      <div class="cr-grp" style="--sc: {g.sp ? sphereColor(g.sp) : 'var(--ink-faint)'}"><i></i>{g.sp?.name ?? 'Без сферы'}</div>
      {#each g.items as l (l.id)}
        {@const n = flat.indexOf(l)}
        <button type="button" class="cr-it" class:on={sel === n} class:cur={l.id === current} style="--sc: {colorOf(l.id)}" onclick={() => onpick(l.id)}>
          <i class="lp-sq"></i><span class="cr-itn">{l.title}<small>{VIEW_NAME[viewOf(l.id, layer)] ?? 'Канбан'}</small></span>
          {#if n < 9}<kbd>{n + 1}</kbd>{/if}
        </button>
      {/each}
    {/each}
  </div>
</Popover>
