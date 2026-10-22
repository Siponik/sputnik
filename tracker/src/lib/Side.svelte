<script>
  // Левая колонка доски 0.6 (docs/design-v2.md — «Левая колонка доски» и «Доработки 21.10»). Три части:
  // прокрутка (сферы и списки, фильтр, проекты) · совет енота прибит к низу · док «Шаблоны · Архив · Показывать».
  // Закреплена (settings.sidePin) — 248 px рядом с доской; откреплена — полоса 64 px, при наведении колонка
  // выезжает поверх доски (150 мс / уход 300 мс, логика — shell.slider).
  import { tick, untrack } from 'svelte';
  import SphereIcon from './SphereIcon.svelte';
  import Coon from './Coon.svelte';
  import { sphereColor, iconPath } from './spheres.js';
  import * as shell from './shell.js';
  import { level } from './motion.js';

  let {
    spheres, listsOf, noSphere, count, viewOf, activeId = null, current = 'board', activeSphere = null,
    folded = () => false, projects = [], project = null, tips = [], tipsOn = true, pinned = true, hold = false,
    onlist, onsphere, onfold, onmenu, onadd, onproject, ontemplates, onarchive, onshow, onpin, ontip, ontiphide, onregister,
  } = $props();

  const VIEW_ICONS = {
    kanban: '<rect x="4" y="4" width="5" height="16" rx="1"/><rect x="11" y="4" width="5" height="10" rx="1"/>',
    pipe: '<path d="M4 7h16M4 12h16M4 17h16"/>',
    stickers: '<rect x="4" y="4" width="7" height="7" rx="1"/><rect x="13" y="4" width="7" height="7" rx="1"/><rect x="4" y="13" width="7" height="7" rx="1"/>',
    list: '<path d="M5 6h14M5 12h14M5 18h9"/>',
  };
  const VIEW_NAMES = { kanban: 'Канбан', pipe: 'Конвейер', stickers: 'Стикеры', list: 'Список' };

  // ---------- выезд откреплённой колонки ----------
  let over = $state(false);
  const sl = shell.slider({ set: (v) => (over = v) });
  let filterFocus = $state(false);
  $effect(() => { sl.hold(hold || filterFocus || dragging); });
  $effect(() => { if (pinned) sl.hide(); });
  let dragging = $state(false);
  const instant = () => sl.instant(level() === 'off');

  // ---------- фильтр «Список…» ----------
  let q = $state('');
  let filterEl = $state(null);
  const allLists = $derived(spheres.reduce((n, sp) => n + listsOf(sp.id).length, 0) + noSphere.length);
  const showFilter = $derived(allLists > 6 || !!q);
  const shown = $derived(shell.filterSide(q, spheres, listsOf, noSphere));
  function filterKey(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (shown.first) pick(shown.first.id);
      else if (shown.firstSphere) { onsphere(shown.firstSphere.id); done(); }
    } else if (e.key === 'Escape') {
      e.preventDefault(); e.stopPropagation();
      if (q) q = ''; else { filterEl?.blur(); if (!pinned) sl.hide(); }
    }
  }
  function done() { q = ''; if (!pinned) sl.hide(); }
  function pick(id) { onlist(id); done(); }

  // ---------- совет енота ----------
  let tipI = $state(0);
  let tipDir = $state(1);
  const tip = $derived(tips.length ? tips[tipI % tips.length] : null);
  $effect(() => { tips.length; untrack(() => { if (tipI >= tips.length) tipI = 0; }); });
  function nextTip() { tipDir = 1; tipI = (tipI + 1) % Math.max(1, tips.length); }

  // Для клавиш App: [ ] и Ctrl+Shift+L временно выдвигают откреплённую колонку, Esc — убирает.
  $effect(() => {
    onregister?.({
      peek() { if (!pinned) { instant(); sl.peek(); } },
      hide() { if (!pinned && over) { sl.hide(); return true; } return false; },
      async focusFilter() { if (!pinned) sl.show(); q = q || ''; await tick(); (filterEl ?? null)?.focus(); return !!filterEl; },
    });
  });

  const activeSphereOfList = $derived(spheres.find((sp) => listsOf(sp.id).some((l) => l.id === activeId))?.id ?? null);
</script>

<svelte:window ondragstart={() => (dragging = true)} ondragend={() => (dragging = false)} ondrop={() => (dragging = false)} />

{#snippet pinBtn(cls = '')}
  <button type="button" class="sd-pin {cls}" class:on={pinned} aria-pressed={pinned}
    title={pinned ? 'Открепить: колонка спрячется и будет выезжать при наведении · Ctrl+B' : 'Закрепить колонку · Ctrl+B'} onclick={onpin}>
    <svg viewBox="0 0 24 24" aria-hidden="true" style="fill: {pinned ? 'currentColor' : 'none'}"><path d="M9 4h6l-1 5 3 3v2H7v-2l3-3zM12 14v6" /></svg>
  </button>
{/snippet}

{#snippet dock(short = false)}
  <nav class="sd-dock" aria-label="Доска: разделы">
    <button type="button" title="Шаблоны досок" aria-current={current === 'templates'} onclick={() => { ontemplates(); done(); }}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="4" width="16" height="16" rx="3" /><path d="M4 10h16M10 10v10" /></svg>{#if !short}Шаблоны{/if}
    </button>
    <button type="button" title="Архив · F" aria-current={current === 'archive'} onclick={() => { onarchive(); done(); }}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="5" width="18" height="4" rx="1" /><path d="M5 9v10h14V9M10 13h4" /></svg>{#if !short}Архив{/if}
    </button>
    <button type="button" title="Что показывать — списки и календари" onclick={() => { onshow(); done(); }}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" /><circle cx="12" cy="12" r="3" /></svg>{#if !short}Показывать{/if}
    </button>
  </nav>
{/snippet}

{#snippet listRow(l)}
  {@const v = viewOf(l.id)}
  <button class="sd-lst" class:on={(current === 'board' || current === 'archive') && l.id === activeId} type="button"
    title="{l.title} · {VIEW_NAMES[v] ?? ''}" onclick={() => pick(l.id)}
    oncontextmenu={(e) => onmenu(e, 'list', l.id)} onkeydown={(e) => { if ((e.shiftKey && e.key === 'F10') || e.key === 'ContextMenu') onmenu(e, 'list', l.id); }}>
    <svg viewBox="0 0 24 24" aria-hidden="true">{@html VIEW_ICONS[v] ?? VIEW_ICONS.kanban}</svg><span class="lt">{l.title}</span><span class="n">{count(l)}</span>
  </button>
{/snippet}

{#snippet full()}
  <div class="sd-scroll">
    <div class="sd-h4">Сферы
      <span class="tools">
        <button type="button" title="Новый список или сфера" aria-label="Новый список или сфера" aria-haspopup="menu" onclick={onadd}>＋</button>
        {@render pinBtn()}
      </span>
    </div>
    {#if showFilter}
      <label class="sd-flt">
        <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="M20 20l-4.5-4.5" /></svg>
        <input bind:this={filterEl} bind:value={q} placeholder="Список…" aria-label="Найти список (Ctrl+Shift+L)" onkeydown={filterKey}
          onfocus={() => (filterFocus = true)} onblur={() => (filterFocus = false)} />
        <kbd title="[ ] — соседний список">[ ]</kbd>
      </label>
    {/if}
    {#each shown.spheres as { sp, lists } (sp.id)}
      {@const fold = !q && folded(sp.id)}
      <div class="sd-sph-row">
        <button type="button" class="sd-sph" aria-current={current === 'sphere' && activeSphere === sp.id} onclick={() => { onsphere(sp.id); done(); }}
          oncontextmenu={(e) => onmenu(e, 'sphere', sp.id)} onkeydown={(e) => { if ((e.shiftKey && e.key === 'F10') || e.key === 'ContextMenu') onmenu(e, 'sphere', sp.id); }}>
          <SphereIcon sphere={sp} size={22} /><span class="sn">{sp.name}{#if sp.shared}<span class="sd-shared" title="Общая сфера" aria-label="общая"><svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14c2 .8 3 3 3 6" /></svg></span>{/if}</span><span class="n">{listsOf(sp.id).reduce((n, l) => n + count(l), 0)}</span>
        </button>
        <button type="button" class="sd-chev" aria-label={fold ? 'Развернуть сферу' : 'Свернуть сферу'} aria-expanded={!fold} title={fold ? 'Развернуть' : 'Свернуть'} onclick={() => onfold(sp.id, !fold)}>
          <svg viewBox="0 0 24 24" aria-hidden="true" class:closed={fold}><path d="M6 9l6 6 6-6" /></svg>
        </button>
      </div>
      {#if !fold}{#each lists as l (l.id)}{@render listRow(l)}{/each}{/if}
    {/each}
    {#if shown.noSphere.length}
      {#if spheres.length}<p class="sd-h4 sd-sub">Без сферы</p>{/if}
      {#each shown.noSphere as l (l.id)}{@render listRow(l)}{/each}
    {/if}
    {#if q && !shown.spheres.length && !shown.noSphere.length}<p class="sd-empty">Ничего не нашлось.</p>{/if}
    {#if !allLists}<p class="sd-empty">Списков пока нет — «＋» справа от «Сферы».</p>{/if}
    {#if projects.length && current === 'board' && !q}
      <p class="sd-h4 sd-sub">Проекты</p>
      {#each projects as [p, n] (p)}
        <button class="sd-lst prj" class:on={project === p} type="button" aria-pressed={project === p} onclick={() => onproject(project === p ? null : p)}>
          <span class="lt">{p}</span><span class="n">{n}</span>
        </button>
      {/each}
    {/if}
  </div>
  {#if tip && tipsOn}
    <div class="sd-tip" role="note">
      <Coon pose="think" size={44} />
      {#key tip.id + tipI}
        <p class="tx" style="--dx: {tipDir * 8}px">
          <b>{tips.length > 1 ? `Совет · ${tipI % tips.length + 1} из ${tips.length}` : "Совет"}</b>{tip.text}
          {#if tip.act}<button type="button" class="act" onclick={() => { ontip(tip); if (!pinned) sl.hide(); }}>{tip.act} →</button>{/if}
        </p>
      {/key}
      <div class="nx">
        {#if tips.length > 1}<button type="button" title="Следующий совет" aria-label="Следующий совет" onclick={nextTip}>›</button>{/if}
        <button type="button" title="Скрыть советы до завтра" aria-label="Скрыть советы до завтра" onclick={ontiphide}>×</button>
      </div>
    </div>
  {/if}
  {@render dock()}
{/snippet}

{#if pinned}
  <aside class="sd" aria-label="Списки">{@render full()}</aside>
{:else}
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <aside class="sd rail" aria-label="Списки, свёрнуто" onmouseenter={() => { instant(); sl.enter(); }} onmouseleave={() => sl.leave()}>
    <div class="sd-scroll">
      {@render pinBtn('exp')}
      {#each spheres as sp (sp.id)}
        <button type="button" class="sd-rb" class:on={sp.id === activeSphereOfList || (current === 'sphere' && activeSphere === sp.id)}
          style="--sc: {sphereColor(sp)}" title={sp.name} aria-label={sp.name} onclick={() => onsphere(sp.id)}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d={iconPath(sp)} /></svg>
          <span class="n">{listsOf(sp.id).reduce((n, l) => n + count(l), 0)}</span>
        </button>
      {/each}
      {#if noSphere.length}
        {#if spheres.length}<span class="sd-rsep"></span>{/if}
        {#each noSphere.slice(0, 4) as l (l.id)}
          <button type="button" class="sd-rb plain" class:on={l.id === activeId} title={l.title} aria-label={l.title} onclick={() => onlist(l.id)}>
            <svg viewBox="0 0 24 24" aria-hidden="true">{@html VIEW_ICONS[viewOf(l.id)] ?? VIEW_ICONS.kanban}</svg>
          </button>
        {/each}
      {/if}
    </div>
    {#if tipsOn}
      <button type="button" class="sd-coon" title="Совет енота" aria-label="Совет енота" onclick={() => sl.show()}>
        <Coon pose="face" size={40} />{#if tip}<b></b>{/if}
      </button>
    {/if}
    {@render dock(true)}
  </aside>
  {#if over}
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <aside class="sd over" aria-label="Списки" onmouseenter={() => sl.enter()} onmouseleave={() => sl.leave()}
     >{@render full()}</aside>
  {/if}
{/if}
