<script>
  // Окно списка «Настроить список» (design/screens/ListSettings.dc.html, docs/design-v2.md — «Шаблон и список — раздельно»).
  // Тот же редактор, что у шаблона (BoardEditor), но сохраняет только в этот список: изменённый список («своё») от шаблона
  // отвязан, «Вернуть как в шаблоне» снова его привязывает. Плюс «Основное»: сфера, порядок, «Сегодня»/сводка/бот, архив.
  import { untrack } from 'svelte';
  import BoardEditor from './BoardEditor.svelte';
  import Dropdown from './Dropdown.svelte';
  import SphereIcon from './SphereIcon.svelte';
  import { colColor, SORTS, sortOf, archiveDays } from './templates.js';
  import * as E from './boardedit.js';
  import ListTemplateSwitch from './ListTemplateSwitch.svelte';

  // groups — [{ sphere | null, lists: [{ id, title, own, n, view }] }] для левой колонки; board — boardOf(списка);
  // layList — lists[id] в слое; spheres — [{ id, name }]; count(colId) — задач в колонке; sample — задача для превью.
  let { list, board, layList = {}, groups = [], spheres = [], sphere = null, shared = false, count, sample = null,
    templates = [], onpick, onback, onsave, onreset, onswitch, onastemplate, ondelete } = $props();
  let switching = $state(false); // окно «Взять колонки из другого шаблона»

  let draft = $state(null);
  let removed = $state([]);
  let title = $state('');
  let sph = $state(null);
  let sort = $state('own');
  let quiet = $state(false);
  let archive = $state(3);
  let dirtyBoard = $state(false);
  let asTpl = $state(null); // «Сохранить как новый шаблон…» — название
  let loadedFor = $state(''); // сброс в '' — перечитать из слоя

  function load() {
    draft = E.draftOf(board); removed = []; dirtyBoard = false;
    title = list.title; sph = sphere; sort = sortOf(layList); quiet = !!layList.quiet; archive = archiveDays(layList);
    asTpl = null; loadedFor = list.id;
  }
  $effect(() => { if (list && loadedFor !== list.id) untrack(load); });

  const basics = $derived(draft ? [
    ...(title.trim() && title.trim() !== list.title ? ['название'] : []),
    ...(!shared && (sph ?? null) !== (sphere ?? null) ? ['сфера'] : []),
    ...(sort !== sortOf(layList) ? ['порядок'] : []),
    ...(quiet !== !!layList.quiet ? ['«Сегодня»'] : []),
    ...(archive !== archiveDays(layList) ? ['архив'] : []),
  ] : []);
  const boardChanges = $derived(draft && dirtyBoard ? E.changes(board, draft) : []);
  const changed = $derived([...basics, ...boardChanges]);

  function pick(id) {
    if (id === list.id) return;
    if (changed.length && !confirm('В списке есть несохранённые изменения. Перейти без сохранения?')) return;
    onpick(id);
  }
  function back() {
    if (changed.length && !confirm('В списке есть несохранённые изменения. Закрыть без сохранения?')) return;
    onback();
  }
  async function save() {
    if (!changed.length) return;
    await onsave({ title: title.trim() || list.title, sphere: sph ?? null, sort, quiet, archive, draft: boardChanges.length ? E.draftOf(draft) : null, removed });
    loadedFor = ''; // перечитать из слоя
  }
  function reset() {
    if (dirtyBoard && !confirm('Несохранённые изменения колонок и полей пропадут. Вернуть список как в шаблоне?')) return;
    onreset(); loadedFor = '';
  }
  function makeTpl() {
    const n = asTpl?.trim();
    if (!n) return;
    onastemplate(n, E.draftOf(draft));
    asTpl = null; loadedFor = '';
  }
  const sphereOpts = $derived([{ id: '', label: 'Без сферы' }, ...spheres.map((s) => ({ id: s.id, label: s.name }))]);

  function onKey(e) {
    if (e.key === 'Escape' && !e.defaultPrevented && !document.querySelector('.ddm, .cmenu') && !(e.target instanceof HTMLInputElement && e.target.closest('.be-nm, .be-head'))) {
      e.preventDefault(); back();
    }
    if ((e.ctrlKey || e.metaKey) && e.key === 's') { e.preventDefault(); save(); }
  }
</script>

<svelte:window onkeydown={onKey} />

<div class="be-page">
  <aside class="be-side" aria-label="Списки">
    <button type="button" class="be-back" onclick={back}>← К доске</button>
    <p class="be-cap">Списки</p>
    {#each groups as g (g.sphere?.id ?? '_')}
      {#if g.lists.length}
        <div class="be-sph">{#if g.sphere}<SphereIcon sphere={g.sphere} size={20} />{g.sphere.name}{:else}Без сферы{/if}</div>
        {#each g.lists as l (l.id)}
          <button type="button" class="be-li2" aria-current={l.id === list.id} onclick={() => pick(l.id)}>
            <svg class="be-li" viewBox="0 0 24 24" aria-hidden="true">{@html E.VIEW_ICONS[l.view] ?? E.VIEW_ICONS.kanban}</svg>
            <span class="lt">{l.title}</span>
            {#if l.own}<span class="own">своё</span>{:else}<b>{l.n || ''}</b>{/if}
          </button>
        {/each}
      {/if}
    {/each}
    <p class="be-hint">«своё» — список изменён и больше не следует за шаблоном.</p>
  </aside>

  {#if draft}
    <BoardEditor mode="list" bind:draft bind:removed {count} baseCols={board.base.cols} {sample} onchange={() => (dirtyBoard = true)}>
      {#snippet head()}
        <div class="be-head">
          <span class="be-kind l"><svg class="be-li" viewBox="0 0 24 24" aria-hidden="true">{@html E.VIEW_ICONS.list}</svg>Список</span>
          <input class="be-name" type="text" aria-label="Название списка" bind:value={title} />
          {#if ondelete}<button type="button" class="be-btn ghost sm dng" onclick={ondelete}>Удалить…</button>{/if}
        </div>
        <div class="be-base">
          <span class="be-mini">{#each board.base.cols as c (c.id)}<i style="--c: {colColor(c)}"></i>{/each}</span>
          <span class="tx">
            {#if board.own}
              Создан из шаблона <b>«{board.base.name}»</b>. Колонки и поля здесь <b>свои</b> — шаблон и другие списки их не трогают.
            {:else}
              Идёт за шаблоном <b>«{board.base.name}»</b>. Изменишь здесь — поменяется <b>только этот список</b>, шаблон и другие списки не тронутся.
            {/if}
          </span>
          <span class="acts">
            {#if board.own}<button type="button" class="be-btn sm" onclick={reset}>Вернуть как в шаблоне</button>{/if}
            {#if onswitch}<button type="button" class="be-btn ghost sm" onclick={() => { if (!dirtyBoard || confirm('Несохранённые изменения колонок и полей пропадут. Продолжить?')) switching = true; }}>Колонки из другого шаблона…</button>{/if}
          </span>
        </div>
      {/snippet}
      {#snippet top()}
        <section class="be-sec" aria-label="Основное">
          <header><p class="be-cap">Основное</p></header>
          <div class="be-grid2">
            <div class="be-mr"><span>Сфера</span>
              {#if shared}<span>общая сфера — меняется в её настройках</span>
              {:else}<Dropdown small label="Сфера" value={sph ?? ''} options={sphereOpts} onchange={(v) => (sph = v || null)} />{/if}
            </div>
            <div class="be-mr"><span>Порядок</span>
              <div class="be-seg inline" role="group" aria-label="Порядок задач">
                {#each SORTS as s (s.id)}<button type="button" aria-pressed={sort === s.id} onclick={() => (sort = s.id)}>{s.name}</button>{/each}
              </div>
            </div>
            <div class="be-mr"><span>Показывать</span>
              <button type="button" class="be-tgl" role="switch" aria-checked={!quiet} aria-label="Показывать в «Сегодня», сводке и боте" onclick={() => (quiet = !quiet)}></button>
              <span>«Сегодня», сводка, бот</span>
            </div>
            <div class="be-mr"><span>В архив</span>
              <div class="be-seg inline" role="group" aria-label="Когда сделанное уходит в архив">
                {#each [[0, 'сразу'], [3, '3 дня'], [7, 'неделя']] as [d, nm] (d)}<button type="button" aria-pressed={archive === d} onclick={() => (archive = d)}>{nm}</button>{/each}
              </div>
            </div>
          </div>
        </section>
      {/snippet}
      {#snippet foot()}
        <footer class="be-foot">
          {#if asTpl !== null}
            <input class="be-name sm" type="text" placeholder="Название шаблона" aria-label="Название нового шаблона" bind:value={asTpl}
              onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); makeTpl(); } else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); asTpl = null; } }} />
            <button type="button" class="be-btn sm" disabled={!asTpl.trim()} onclick={makeTpl}>Создать шаблон</button>
            <button type="button" class="be-btn ghost sm" onclick={() => (asTpl = null)}>Отмена</button>
          {:else}
            <button type="button" class="be-btn ghost" title="Новый шаблон из этой доски — список будет идти за ним" onclick={() => (asTpl = `${list.title}`)}>
              <svg class="be-li" viewBox="0 0 24 24" aria-hidden="true">{@html E.VIEW_ICONS.kanban}</svg>Сохранить как новый шаблон…</button>
          {/if}
          <span class="sp"></span>
          {#if changed.length}<small>изменения: {changed.join(', ')}</small>{/if}
          <button type="button" class="be-btn blue" disabled={!changed.length} onclick={save} title="Ctrl+S">Сохранить · только этот список</button>
        </footer>
      {/snippet}
    </BoardEditor>
  {/if}
</div>

{#if switching}
  <ListTemplateSwitch {list} {board} {templates} {count} onclose={() => (switching = false)}
    onswitch={(tid, map) => { switching = false; onswitch(tid, map); loadedFor = ''; }} />
{/if}
