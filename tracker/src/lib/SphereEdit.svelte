<script>
  import { fade, pop } from './motion.js';
  // Поповер «Изменить сферу»: название, цвет, значок, списки сферы, «Удалить сферу». Изменения сразу в слое.
  import { SPHERE_COLORS, SPHERE_ICONS } from './spheres.js';
  import SphereIcon from './SphereIcon.svelte';

  // lists — все списки доски; whereOf(listId) → название сферы, где список сейчас (или '').
  let { sphere, lists, inSphere, whereOf, onchange, ontogglelist, ondelete, onclose } = $props();
  let confirmDel = $state(false);
  let nameInput = $state(null);
  $effect(() => { nameInput?.focus(); });
</script>

<svelte:window onkeydown={(e) => { if (e.key === 'Escape' && !document.querySelector('.keyhelp')) { e.stopPropagation(); onclose(); } }} />

<button class="drawer-back light" type="button" aria-label="Закрыть" onclick={onclose} transition:fade={{ duration: 180 }}></button>
<div transition:pop class="sph-pop dialog" role="dialog" aria-label="Изменить сферу">
  <div class="sp-row">
    <SphereIcon {sphere} size={38} />
    <input bind:this={nameInput} type="text" aria-label="Название сферы" value={sphere.name} oninput={(e) => onchange({ name: e.currentTarget.value })}
      onblur={(e) => { if (!e.currentTarget.value.trim()) onchange({ name: 'Сфера' }); }} />
  </div>
  <div>
    <p class="cap">Цвет</p>
    <div class="sw-row">
      {#each SPHERE_COLORS as c (c.id)}
        <button type="button" class="sw2" aria-label={c.name} title={c.name} aria-pressed={sphere.color === c.id} style="background: {c.v}" onclick={() => onchange({ color: c.id })}></button>
      {/each}
    </div>
  </div>
  <div>
    <p class="cap">Значок</p>
    <div class="ib-row">
      {#each Object.entries(SPHERE_ICONS) as [id, ic] (id)}
        <button type="button" class="ib" aria-label={ic.name} title={ic.name} aria-pressed={sphere.icon === id} onclick={() => onchange({ icon: id })}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d={ic.d} /></svg>
        </button>
      {/each}
    </div>
  </div>
  <div>
    <p class="cap">Списки в сфере</p>
    {#each lists as l (l.id)}
      {@const on = inSphere(l.id)}
      {@const where = whereOf(l.id)}
      <div class="sl-row">
        <button type="button" class="tick2" aria-pressed={on} aria-label={l.title} onclick={() => ontogglelist(l.id, !on)}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
        </button>
        <span class="nm">{l.title}</span>
        {#if !on && where}<span class="where">сейчас в «{where}»</span>{/if}
      </div>
    {:else}
      <p class="hint">Списков пока нет.</p>
    {/each}
    <p class="hint">Список живёт в одной сфере. Сферы — только в Спутнике, Google Tasks их не видит.</p>
  </div>
  <div class="sp-foot">
    {#if confirmDel}
      <span class="hint" style="flex: 1">Удалить сферу? Списки останутся, уйдут в «Без сферы».</span>
      <button type="button" class="sp-btn sp-btn-ghost" onclick={() => (confirmDel = false)}>Нет</button>
      <button type="button" class="sp-btn danger" onclick={ondelete}>Удалить</button>
    {:else}
      <button type="button" class="sp-btn sp-btn-ghost danger" onclick={() => (confirmDel = true)}>Удалить сферу</button>
      <span style="flex: 1"></span>
      <button type="button" class="sp-btn sp-btn-primary" onclick={onclose}>Готово</button>
    {/if}
  </div>
</div>
