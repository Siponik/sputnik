<script>
  // Окно «Создать»: задача в любой список, со сроком и, если нужно, со временем.
  let { lists, listId = null, day = '', s = '', e = '', oncreate, onclose } = $props();

  import { untrack } from 'svelte';

  // Подставленные значения берём один раз, дальше поля живут сами.
  const init = untrack(() => ({ list: listId ?? lists[0]?.id ?? '', day, s, e }));
  let title = $state('');
  let list = $state(init.list);
  let due = $state(init.day);
  let from = $state(init.s);
  let to = $state(init.e);
  let busy = $state(false);

  const toMin = (v) => { const [h, m] = v.split(':').map(Number); return h * 60 + m; };
  const bad = $derived(!!from && !!to && toMin(to) <= toMin(from));

  // Поставили начало — конец через час, если его нет или он раньше.
  function setFrom(v) {
    from = v;
    if (v && (!to || toMin(to) <= toMin(v))) {
      const m = Math.min(toMin(v) + 60, 23 * 60 + 59);
      to = `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
    }
  }

  async function submit(ev) {
    ev.preventDefault();
    const t = title.trim();
    if (!t || !list || bad || busy) return;
    busy = true;
    const ok = await oncreate({ title: t, listId: list, due, slot: due && from ? { s: from, e: to || from } : null });
    busy = false;
    if (ok) onclose();
  }
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && onclose()} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose}></button>
<form class="dialog quick" aria-label="Новая задача" onsubmit={submit}>
  <h2>Новая задача</h2>
  <!-- svelte-ignore a11y_autofocus -->
  <input class="title-input" bind:value={title} placeholder="Что сделать?" aria-label="Название" autofocus />
  <div class="field">
    <label for="q-list">Список</label>
    <select id="q-list" bind:value={list}>
      {#each lists as l (l.id)}<option value={l.id}>{l.title}</option>{/each}
    </select>
  </div>
  <div class="field">
    <label for="q-due">Срок</label>
    <input id="q-due" type="date" bind:value={due} />
  </div>
  <div class="field">
    <label for="q-from">Время</label>
    <div class="time-row">
      <input id="q-from" type="time" value={from} disabled={!due} onchange={(e) => setFrom(e.currentTarget.value)} aria-label="Начало" />
      <span>–</span>
      <input type="time" bind:value={to} disabled={!due || !from} aria-label="Конец" />
      {#if from}<button class="sp-btn sp-btn-ghost" type="button" style="min-height: 30px" onclick={() => { from = ''; to = ''; }}>Весь день</button>{/if}
    </div>
  </div>
  <p class="hint">
    {#if !due}Без срока задача попадёт только на доску.
    {:else if bad}Конец должен быть позже начала.
    {:else if from}В календаре встанет в сетку на это время.
    {:else}В календаре будет в строке «весь день».{/if}
  </p>
  <div class="actions">
    <button class="sp-btn sp-btn-ghost" type="button" onclick={onclose}>Отмена</button>
    <button class="sp-btn sp-btn-primary" type="submit" disabled={!title.trim() || !list || bad || busy}>Создать</button>
  </div>
</form>
