<script>
  // Выпадающий список Спутника — один компонент вместо системных <select> (docs/design-v2.md,
  // «Выпадающий список — один компонент вместо <select>»; лист design/screens/Dropdowns.dc.html).
  // Виды: простой; с меткой цвета и числом (color/count у пунктов, mark: 'dot' | 'bar'); с поиском и группами
  // (search, groups); несколько сразу (multi — value массив, меню не закрывается); тихий (ghost).
  // Пункт: { id, label, hint?, color?, count?, warn?, kbd?, group?, short?, disabled? }.
  // extras — строки после черты («＋ Новая колонка…»): { label, onpick }; oncreate(q) — «Создать «…»» при поиске.
  // Меню живёт в <body> (не обрезается прокруткой окна), открыто — .ddm на странице, keys.overlay() это видит.
  import { tick } from 'svelte';
  import { fly } from './motion.js';
  import { filterOpts, marks, moveActive, jumpTo, toggleIn, buttonText, placeMenu } from './dropdown.js';

  let { value = null, options = [], onchange, label = '', placeholder = 'Выбрать', id = undefined,
    ghost = false, small = false, disabled = false, mark = null, search = false, searchPlaceholder = 'Найти…',
    groups = null, multi = false, extras = [], oncreate = null, createLabel = (q) => `Создать «${q}»`,
    emptyText = (q) => `Ничего не нашлось по «${q}»`, foot = false, cls = '', title = undefined } = $props();

  const uid = `dd${Math.random().toString(36).slice(2, 8)}`;
  let open = $state(false);
  let q = $state('');
  let act = $state(-1);
  let btn = $state(null);
  let menuEl = $state(null);
  let qEl = $state(null);
  let pos = $state({ left: 0, top: 0, bottom: null, width: 0, up: false, maxH: 360 });

  const selected = $derived(multi ? options.filter((o) => (value ?? []).includes(o.id)) : options.find((o) => o.id === value) ?? null);
  const text = $derived(buttonText(options, value, multi));
  const shown = $derived(search ? filterOpts(options, q) : options);
  const sections = $derived.by(() => {
    if (!groups?.length) return [{ g: null, items: shown }];
    const known = new Set(groups.map((g) => g.id));
    return [...groups.map((g) => ({ g, items: shown.filter((o) => o.group === g.id) })),
      { g: null, items: shown.filter((o) => !known.has(o.group)) }].filter((s) => s.items.length);
  });
  const flat = $derived(sections.flatMap((s) => s.items));
  const isOn = (o) => (multi ? (value ?? []).includes(o.id) : o.id === value);
  const btnColor = $derived(!multi && mark ? selected?.color ?? null : null);
  const btnCount = $derived(!multi ? selected?.count ?? null : null);

  async function show() {
    if (disabled || open) return;
    q = '';
    open = true;
    const i = multi ? -1 : flat.findIndex((o) => o.id === value);
    act = i >= 0 ? i : moveActive(flat, -1, 'ArrowDown');
    await tick();
    place();
    if (search) qEl?.focus();
    scrollAct();
  }
  function hide(focus = true) {
    if (!open) return;
    open = false;
    if (focus) btn?.focus();
  }
  function place() {
    if (!btn || !menuEl) return;
    const r = btn.getBoundingClientRect();
    const w = Math.ceil(menuEl.scrollWidth) + 2;
    pos = placeMenu(r, menuEl.scrollHeight, w, { w: innerWidth, h: innerHeight });
  }
  function pick(o) {
    if (!o || o.disabled) return;
    if (multi) { onchange?.(toggleIn(value, o.id, options)); return; }
    hide();
    if (o.id !== value) onchange?.(o.id);
  }
  function create() {
    const t = q.trim();
    hide();
    oncreate?.(t);
  }
  function scrollAct() {
    tick().then(() => document.getElementById(`${uid}-o${act}`)?.scrollIntoView?.({ block: 'nearest' }));
  }
  const stop = (e) => { e.preventDefault(); e.stopPropagation(); };

  // Клавиши: кнопка (закрыто и открыто без поиска) и поле поиска ведут себя одинаково, кроме букв.
  function key(e) {
    if (!open) {
      if (['Enter', ' ', 'ArrowDown', 'ArrowUp'].includes(e.key) && !e.ctrlKey && !e.altKey && !e.metaKey) { stop(e); show(); }
      return;
    }
    if (e.key === 'Escape') { stop(e); hide(); return; }
    if (e.key === 'Tab') { hide(false); return; }
    if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(e.key) && !(search && (e.key === 'Home' || e.key === 'End'))) {
      stop(e); act = moveActive(flat, act, e.key); scrollAct(); return;
    }
    if (e.key === 'Enter' || (e.key === ' ' && !search)) {
      stop(e);
      if (act >= 0 && flat[act]) pick(flat[act]);
      else if (search && q.trim() && !flat.length && oncreate) create();
      else if (search && flat.length) pick(flat[0]);
      return;
    }
    if (search) {
      if (!q && /^Digit[1-9]$/.test(e.code) && !e.altKey && !e.ctrlKey && !e.shiftKey) { const o = flat[e.code.slice(5) - 1]; if (o) { stop(e); pick(o); } }
      return;
    }
    if (e.key.length === 1 && !e.ctrlKey && !e.altKey && !e.metaKey) { stop(e); act = jumpTo(flat, act, e.key); scrollAct(); }
  }
  // Поиск сбросил список — подсветка на первом найденном.
  $effect(() => { if (open && search) { q; act = moveActive(flat, -1, 'ArrowDown'); } });
  // Высота меню меняется при поиске — пересчитать место.
  $effect(() => { if (open && menuEl) { flat.length; tick().then(place); } });

  function down(e) {
    if (!open) return;
    if (menuEl?.contains(e.target) || btn?.contains(e.target)) return;
    hide(false);
  }
  function scrolled(e) { if (open && !menuEl?.contains(e.target)) hide(false); }
  const portal = (node) => { document.body.appendChild(node); return () => node.remove(); };
</script>

<svelte:window onpointerdown={down} onresize={() => open && hide(false)} onscrollcapture={scrolled} />

<span class="dd {cls}">
  <button bind:this={btn} {id} type="button" class="ddb" class:ghost class:small {disabled} {title}
    aria-haspopup="listbox" aria-expanded={open} aria-label={label || undefined} aria-controls={open ? `${uid}-m` : undefined}
    aria-activedescendant={open && !search && act >= 0 ? `${uid}-o${act}` : undefined}
    onclick={() => (open ? hide() : show())} onkeydown={key}>
    {#if btnColor}<i class="mk" class:bar={mark === 'bar'} style="--mc: {btnColor}"></i>{/if}
    <span class="v" class:ph={!text}>{text || placeholder}</span>
    {#if btnCount != null}<span class="cnt" class:warn={selected?.warn}>{btnCount}</span>{/if}
    <svg class="chev" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 9l6 6 6-6" /></svg>
  </button>
</span>

{#if open}
  <div class="ddm" class:up={pos.up} bind:this={menuEl} {@attach portal} in:fly={{ y: pos.up ? 4 : -4, duration: 120 }}
    style="left: {pos.left}px; {pos.up ? `bottom: ${pos.bottom}px` : `top: ${pos.top}px`}; min-width: {pos.width}px; max-height: {pos.maxH}px">
    {#if search}
      <label class="ddq">
        <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="M20 20l-4.5-4.5" /></svg>
        <input bind:this={qEl} bind:value={q} placeholder={searchPlaceholder} aria-label={searchPlaceholder}
          role="combobox" aria-expanded="true" aria-controls="{uid}-m" aria-activedescendant={act >= 0 ? `${uid}-o${act}` : undefined}
          onkeydown={key} />
      </label>
    {/if}
    <div class="ddl" id="{uid}-m" role="listbox" aria-label={label || undefined} aria-multiselectable={multi || undefined}>
      {#each sections as s (s.g?.id ?? '-')}
        {#if s.g}<div class="ddg" style={s.g.color ? `--mc: ${s.g.color}` : ''}>{#if s.g.color}<i></i>{/if}{s.g.name}</div>{/if}
        {#each s.items as o (o.id)}
          {@const i = flat.indexOf(o)}
          <button type="button" id="{uid}-o{i}" class="ddo" class:two={!!o.hint} class:act={i === act} class:dis={o.disabled}
            role="option" aria-selected={isOn(o)} aria-disabled={o.disabled || undefined} tabindex="-1"
            onpointermove={() => { if (act !== i && !o.disabled) act = i; }} onclick={() => pick(o)}>
            {#if multi}<span class="box" class:on={isOn(o)}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12l5 5 9-10" /></svg></span>{/if}
            {#if o.color && mark}<i class="mk" class:bar={mark === 'bar'} style="--mc: {o.color}"></i>{/if}
            <span class="t">{#each marks(o.label, search ? q : '') as p, k (k)}{#if p.hit}<mark>{p.t}</mark>{:else}{p.t}{/if}{/each}{#if o.hint}<small>{o.hint}</small>{/if}</span>
            {#if o.count != null}<span class="aux" class:warn={o.warn}>{o.count}</span>{/if}
            {#if search && !q && i < 9 && groups?.length}<kbd>{i + 1}</kbd>{:else if o.kbd}<kbd>{o.kbd}</kbd>{/if}
            {#if !multi}<svg class="ok" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12l5 5 9-10" /></svg>{/if}
          </button>
        {/each}
      {/each}
      {#if search && q.trim() && !flat.length}
        <div class="dde">{emptyText(q.trim())}</div>
        {#if oncreate}
          <button type="button" class="ddo act" tabindex="-1" onclick={create}>
            <svg class="plus" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>
            <span class="t">{createLabel(q.trim())}</span><kbd>Enter</kbd>
          </button>
        {/if}
      {/if}
      {#if extras.length}
        <div class="dds"></div>
        {#each extras as x, k (k)}
          <button type="button" class="ddo extra" tabindex="-1" onclick={() => { hide(); x.onpick(); }}>
            <svg class="plus" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg><span class="t">{x.label}</span>
          </button>
        {/each}
      {/if}
    </div>
    {#if foot}
      <div class="ddf"><span><kbd>↑</kbd> <kbd>↓</kbd> выбрать</span><span><kbd>Enter</kbd> ок</span><span><kbd>Esc</kbd> закрыть</span></div>
    {/if}
  </div>
{/if}
