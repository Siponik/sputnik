<script>
  // Название доски: двойной клик — переименовать на месте (Enter — сохранить, Esc — отмена),
  // «⋯» рядом — меню списка: «Настроить список» (Ctrl+.), «Переименовать», «Шаблон …».
  import ItemMenu from './ItemMenu.svelte';

  let { title, tplName = '', children, onrename, onsettings, onedittemplate } = $props();
  let editing = $state(false);
  let val = $state('');
  let menu = $state(null);

  function start() { if (!onrename) return; val = title; editing = true; }
  function done(save) {
    if (!editing) return;
    editing = false;
    const t = val.trim();
    if (save && t && t !== title) onrename(t);
  }
  function openMenu(e) {
    const r = e.currentTarget.getBoundingClientRect();
    menu = { x: r.left, y: r.bottom + 4 };
  }
  const items = $derived([
    { id: 'settings', label: 'Настроить список…', kbd: 'Ctrl+.' },
    ...(onrename ? [{ id: 'rename', label: 'Переименовать' }] : []),
    ...(onedittemplate ? [{ id: 'template', label: `Шаблон «${tplName}»…`, sep: true }] : []),
  ]);
  function act(a) {
    if (a === 'settings') onsettings?.();
    else if (a === 'rename') start();
    else if (a === 'template') onedittemplate?.();
  }
  const focus = (el) => { el.focus(); el.select(); };
</script>

<h1 class="bd-h1">
  {#if editing}
    <input class="bd-rn" aria-label="Название списка" bind:value={val} use:focus onblur={() => done(true)}
      onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); done(true); } else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); done(false); } }} />
  {:else}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <span class="bd-nm" ondblclick={start} title={onrename ? 'Двойной клик — переименовать' : undefined}>{title}</span>
  {/if}
  {@render children?.()}
  <button type="button" class="bd-more" aria-label="Действия со списком" title="Настроить список · Ctrl+." aria-haspopup="menu" onclick={openMenu}>⋯</button>
</h1>
{#if menu}
  <ItemMenu at={menu} label="Действия со списком" {items} onaction={act} onclose={() => (menu = null)} />
{/if}
