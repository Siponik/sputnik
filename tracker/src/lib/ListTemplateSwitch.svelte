<script>
  // «Взять колонки из другого шаблона» (design/screens/ListTemplateSwitch.dc.html): список переходит на другой шаблон
  // и снова идёт за ним. Куда переедут задачи — сопоставление по названию, иначе по порядку, «Готово» — в последнюю;
  // каждую строку можно поправить. Меняется только этот список. Расчёт — templates.switchPlan.
  import { untrack } from 'svelte';
  import { fade, pop } from './motion.js';
  import Dropdown from './Dropdown.svelte';
  import { colColor, matchCols } from './templates.js';
  import * as E from './boardedit.js';

  // board — boardOf(списка); templates — templatesFrom(слой); count(colId) — задач в колонке сейчас.
  let { list, board, templates, count, onswitch, onclose } = $props();

  let tid = $state(untrack(() => templates.find((t) => t.id !== board.id)?.id ?? templates[0]?.id));
  const next = $derived(templates.find((t) => t.id === tid));
  let manual = $state({}); // правки строк: { старая колонка: новая }
  $effect(() => { tid; untrack(() => (manual = {})); });
  const map = $derived(next ? { ...matchCols(board.cols, next.cols), ...manual } : {});
  const last = $derived(next ? next.cols[next.cols.length - 1] : null);
  const total = $derived(board.cols.reduce((n, c) => n + (count(c.id) ?? 0), 0));
  const fresh = $derived(next ? next.fields.filter((f) => !board.fields.includes(f)).map((f) => E.fieldInfo(f)?.name).filter(Boolean) : []);
  const optsFor = $derived(next ? next.cols.slice(0, -1).map((c) => ({ id: c.id, label: c.name, color: colColor(c) })) : []);

  function go() { onswitch(tid, map); }
</script>

<svelte:window onkeydown={(e) => { if (e.key === 'Escape' && !document.querySelector('.ddm')) { e.preventDefault(); e.stopPropagation(); onclose(); } }} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose} transition:fade={{ duration: 180 }}></button>
<div transition:pop class="dialog be-sw-dlg" role="dialog" aria-label="Взять колонки из шаблона">
  <span class="be-kind l"><svg class="be-li" viewBox="0 0 24 24" aria-hidden="true">{@html E.VIEW_ICONS.list}</svg>Список · {list.title}</span>
  <h2>Взять колонки из шаблона</h2>
  <div class="be-seg" role="group" aria-label="Шаблон">
    {#each templates as t (t.id)}
      <button type="button" aria-pressed={tid === t.id} disabled={t.id === board.id && !board.own} onclick={() => (tid = t.id)}>{t.name}{#if t.id === board.id}<small>сейчас</small>{/if}</button>
    {/each}
  </div>
  {#if next}
    <p class="be-cap">Куда переедут задачи</p>
    <div class="be-map">
      {#each board.cols as c, i (c.id)}
        {@const isEnd = i === board.cols.length - 1}
        <span class="a"><i style="--c: {colColor(c)}"></i>{c.name}<small>{count(c.id) ?? 0}</small></span>
        <svg class="be-li" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
        {#if isEnd}
          <span class="b"><i style="--c: {colColor(last)}"></i>{last.name}<em>последняя</em></span>
        {:else}
          <Dropdown cls="be-ddw" mark="dot" label="Куда переедут задачи из «{c.name}»" value={map[c.id]} options={optsFor} onchange={(v) => (manual = { ...manual, [c.id]: v })} />
        {/if}
      {/each}
    </div>
    <p class="be-note">
      <svg class="be-li" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" /><circle cx="12" cy="12" r="3" /></svg>
      <span>{#if fresh.length}Поля шаблона «{next.name}» — <b>{fresh.join(', ')}</b> — появятся у задач пустыми.{' '}{/if}Тип и приоритет останутся в задачах, даже если новый шаблон их не показывает. Меняется только этот список.</span>
    </p>
  {/if}
  <div class="actions">
    <button class="be-btn ghost" type="button" onclick={onclose}>Отмена</button>
    <button class="be-btn pri" type="button" disabled={!next} onclick={go}>Сменить · {E.tasksWord(total)}</button>
  </div>
</div>
