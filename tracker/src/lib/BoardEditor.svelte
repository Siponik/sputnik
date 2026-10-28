<script>
  // Редактор доски — общий для шаблона и списка (docs/design-v2.md — «Шаблон и список — раздельно»;
  // макеты design/screens/TemplateEdit.dc.html, ListSettings.dc.html). Вид, колонки (тянуть за ⋮⋮, точка — цвет,
  // лимит, ×, замок у «Готово»), плитки полей и живое превью справа. Режимы отличаются метками и тем, куда сохраняет
  // экран-хозяин: шаблон (Templates.svelte) или один список (ListSettings.svelte). Правки черновика — lib/boardedit.js.
  import { VIEWS, PALETTE, colColor } from './templates.js';
  import * as E from './boardedit.js';
  import { humanDue } from './api.js';
  import { typeLabel } from './meta.js';
  import { fmtMin, spentMin } from './timer.js';

  let {
    mode = 'template', // template | list
    draft = $bindable(), // { view, fields, cols }
    removed = $bindable([]), // удалённые колонки [{ id, name, to, toName, n }] — задачи переедут при сохранении
    count = null, // (colId) → задач в колонке сейчас (у списка видно рядом с колонкой)
    baseCols = null, // у списка — колонки шаблона: новая или переименованная колонка помечена «своя»
    sample = null, // { task, lay, subs } — настоящая задача для превью карточки; null — пример
    sampleFrom = '', // из какого списка задача (подпись под превью)
    onchange = () => {},
    head, top, foot, // снипеты: шапка, блоки над «Видом» (у списка — «Основное»), низ
  } = $props();

  const isList = $derived(mode === 'list');
  const end = $derived(draft.cols.length - 1);
  let note = $state('');
  let hover = $state(''); // поле под курсором — подсвечиваем его кусок в превью
  let pvView = $state(''); // вид превью; '' — как в черновике
  const pv = $derived(pvView || draft.view);
  let showAll = $state(false); // у списка выключенные поля спрятаны под «ещё N полей…»

  const edit = (fn) => { fn(); onchange(); };

  // ---------- колонки: перетаскивание за ⋮⋮ ----------
  let grab = $state(-1); // за какую строку взялись
  let dragFrom = $state(-1);
  let dragTo = $state(-1);
  function dragStart(e, i) {
    if (grab !== i) { e.preventDefault(); return; }
    dragFrom = i; dragTo = i;
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', String(i));
  }
  function dragOver(e, i) {
    if (dragFrom < 0) return;
    e.preventDefault();
    dragTo = Math.min(i, end - 1);
  }
  function drop(e) {
    e.preventDefault();
    if (dragFrom >= 0 && dragTo >= 0 && dragTo !== dragFrom) edit(() => (draft.cols = E.moveCol(draft.cols, dragFrom, dragTo)));
    dragEnd();
  }
  function dragEnd() { dragFrom = -1; dragTo = -1; grab = -1; }
  // с клавиатуры: на ⋮⋮ стрелки вверх / вниз
  function gripKey(e, i) {
    const d = e.key === 'ArrowUp' ? -1 : e.key === 'ArrowDown' ? 1 : 0;
    if (!d) return;
    e.preventDefault();
    const next = E.moveCol(draft.cols, i, i + d);
    if (next === draft.cols) return;
    edit(() => (draft.cols = next));
    requestAnimationFrame(() => document.querySelectorAll('.be-cr .be-grip')[i + d]?.focus());
  }

  const n = (id) => (count ? count(id) ?? 0 : null);
  function addCol() { edit(() => draft.cols.splice(end, 0, E.newCol())); note = ''; }
  function delCol(i) {
    const c = draft.cols[i], k = n(c.id) ?? 0;
    const r = E.dropCol(draft.cols, i, removed, k);
    if (!r) return;
    edit(() => { draft.cols = r.cols; removed = r.removed; });
    const to = r.removed.at(-1).toName;
    note = k
      ? `Колонка «${c.name}» убрана: ${E.tasksWord(k)} ${k === 1 ? 'переедет' : 'переедут'} в «${to}» после сохранения.`
      : `Колонка «${c.name}» убрана — задач в ней не было.`;
  }
  const toggle = (f) => edit(() => (draft.fields = E.toggleField(draft.fields, f)));
  const on = (f) => draft.fields.includes(f);

  const cardFields = E.FIELD_INFO.filter((f) => f.group === 'card');
  const drawerFields = E.FIELD_INFO.filter((f) => f.group === 'drawer');
  const shownCard = $derived(isList && !showAll ? cardFields.filter((f) => on(f.id)) : cardFields);
  const shownDrawer = $derived(isList && !showAll ? drawerFields.filter((f) => on(f.id)) : drawerFields);
  const hiddenN = $derived(E.FIELD_INFO.length - shownCard.length - shownDrawer.length);

  // ---------- превью ----------
  const ex = { title: 'Иконки v2: толще обводка', due: 'сегодня', prio: 1, type: 'work', subs: [2, 4], spent: 75, client: 'Студия «Ёж»', money: '45 000 ₽', prog: [3, 10] };
  const card = $derived.by(() => {
    if (!sample?.task) return ex;
    const t = sample.task, L = sample.lay ?? {}, subs = sample.subs ?? [];
    return {
      title: t.title || 'Без названия', due: t.due ? humanDue(t.due) : 'пт', prio: L.priority ?? 1, type: L.type ?? 'work',
      subs: subs.length ? [subs.filter((s) => s.status === 'completed').length, subs.length] : [2, 4],
      spent: spentMin(L) || 75, client: L.client || ex.client, money: L.money || ex.money,
      prog: subs.length ? [subs.filter((s) => s.status === 'completed').length, subs.length] : ex.prog,
    };
  });
  const stageAt = $derived(Math.min(1, end));
  const pvN = (c, i) => E.previewCount(count ? n(c.id) : null, i, draft.cols.length);
</script>

<div class="be">
  <main class="be-main">
    {@render head?.()}
    {@render top?.()}

    <section class="be-sec" aria-label="Вид">
      <header><p class="be-cap">{isList ? 'Вид' : 'Вид по умолчанию'}</p>{#if !isList}<span>новые списки откроются так; у списка можно сменить</span>{/if}</header>
      <div class="be-seg" role="group" aria-label="Вид">
        {#each VIEWS as v (v.id)}
          <button type="button" aria-pressed={draft.view === v.id} title={v.hint} onclick={() => edit(() => (draft.view = v.id))}>
            <svg class="be-li" viewBox="0 0 24 24" aria-hidden="true">{@html E.VIEW_ICONS[v.id]}</svg>{v.name}
          </button>
        {/each}
      </div>
    </section>

    <section class="be-sec" aria-label="Колонки">
      <header><p class="be-cap">{draft.view === 'pipe' ? 'Этапы' : 'Колонки'} · {draft.cols.length}</p><span>тяни за ⋮⋮ · точка — цвет · {isList ? 'справа — сколько задач сейчас' : 'лимит — сколько задач сразу'}</span></header>
      <div class="be-crs" role="list" ondragover={(e) => e.preventDefault()} ondrop={drop}>
        {#each draft.cols as c, i (c.id)}
          {@const isEnd = i === end}
          {@const own = isList && baseCols && !isEnd && E.colIsOwn(c, baseCols)}
          <div class="be-cr" class:lock={isEnd} class:list={isList} class:chg={own} role="listitem"
            class:drag={dragFrom === i} class:over={dragFrom >= 0 && dragTo === i && dragFrom !== i} class:below={dragFrom >= 0 && dragFrom < dragTo}
            draggable={!isEnd && grab === i} ondragstart={(e) => dragStart(e, i)} ondragover={(e) => dragOver(e, i)} ondragend={dragEnd}>
            {#if isEnd}
              <span class="be-lk" title="Последняя колонка — задача в ней выполнена в Google Tasks. Переименовать можно, удалить и сдвинуть нельзя.">
                <svg class="be-li" viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="11" width="14" height="9" rx="2" /><path d="M8 11V8a4 4 0 0 1 8 0v3" /></svg>
              </span>
            {:else}
              <button type="button" class="be-grip" aria-label="Переставить «{c.name}» — тяни или стрелки ↑↓" title="Тяни, чтобы переставить"
                onpointerdown={() => (grab = i)} onpointerup={() => { if (dragFrom < 0) grab = -1; }} onkeydown={(e) => gripKey(e, i)}>
                <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="9" cy="6" r="1.5" /><circle cx="15" cy="6" r="1.5" /><circle cx="9" cy="12" r="1.5" /><circle cx="15" cy="12" r="1.5" /><circle cx="9" cy="18" r="1.5" /><circle cx="15" cy="18" r="1.5" /></svg>
              </button>
            {/if}
            <button type="button" class="be-dot" aria-label="Цвет колонки: {PALETTE[c.color ?? 0].name} — сменить" title="Сменить цвет" style="--c: {colColor(c)}"
              onclick={() => edit(() => (draft.cols[i] = E.recolor(c)))}></button>
            <span class="be-nm">
              <input type="text" aria-label="Название колонки" size={isEnd ? Math.max(4, c.name.length + 1) : undefined} value={c.name} oninput={(e) => edit(() => (draft.cols[i].name = e.currentTarget.value))} />
              {#if own}<small class="be-own">своя</small>{/if}
              {#if isEnd && !isList}<small class="be-sub">задача выполнена в Google</small>{/if}
            </span>
            {#if isList}<span class="be-cn">{E.tasksWord(n(c.id) ?? 0)}</span>{/if}
            {#if isEnd}
              <span></span><span></span>
            {:else}
              <span class="be-lim" class:on={c.limit > 0}>
                <button type="button" aria-label="Лимит меньше" onclick={() => edit(() => (draft.cols[i] = E.relimit(c, -1)))}>−</button>
                <span>{c.limit ? `до ${c.limit} задач` : 'без лимита'}</span>
                <button type="button" aria-label="Лимит больше" onclick={() => edit(() => (draft.cols[i] = E.relimit(c, 1)))}>+</button>
              </span>
              <button type="button" class="be-x" aria-label="Удалить колонку {c.name}" disabled={draft.cols.length <= 2}
                title={draft.cols.length <= 2 ? 'Минимум 2 колонки' : 'Удалить колонку'} onclick={() => delCol(i)}>×</button>
            {/if}
          </div>
        {/each}
      </div>
      {#if note}<p class="be-note" role="status">{note}</p>{/if}
      <button type="button" class="be-btn ghost sm" onclick={addCol}>＋ Колонка перед «{draft.cols[end].name}»</button>
    </section>

    <section class="be-sec" aria-label="Поля">
      <header><p class="be-cap">Поля</p><span>{isList ? `включено ${draft.fields.length} из ${E.FIELD_INFO.length}` : 'что есть у задач этого шаблона и где видно'}</span></header>
      {#if shownCard.length}
        {#if !isList || showAll}<p class="be-where">На карточке</p>{/if}
        <div class="be-fl">{#each shownCard as f (f.id)}{@render tile(f)}{/each}</div>
      {/if}
      {#if shownDrawer.length}
        <p class="be-where">Своё поле в окне задачи</p>
        <div class="be-fl">{#each shownDrawer as f (f.id)}{@render tile(f)}{/each}</div>
      {/if}
      {#if isList}
        <div class="be-fl">
          <button type="button" class="be-more" onclick={() => (showAll = !showAll)}>{showAll ? 'Свернуть' : `＋ ещё ${hiddenN} ${hiddenN === 1 ? 'поле' : hiddenN < 5 ? 'поля' : 'полей'}…`}</button>
        </div>
      {/if}
    </section>

    {@render foot?.()}
  </main>

  <aside class="be-pv" aria-label="Так будет выглядеть">
    <div class="be-pvh">
      <p class="be-cap">Так будет выглядеть</p>
      <div class="be-seg sm" role="group" aria-label="Вид превью">
        {#each VIEWS as v (v.id)}<button type="button" aria-pressed={pv === v.id} onclick={() => (pvView = v.id === draft.view ? '' : v.id)}>{v.name}</button>{/each}
      </div>
    </div>

    {#if pv === 'kanban'}
      <div class="be-pvb" style="grid-template-columns: repeat({draft.cols.length}, minmax(0, 1fr))">
        {#each draft.cols as c, i (c.id)}
          {@const k = count ? n(c.id) : null}
          <div class="be-pvc"><b class:be-l={c.limit > 0} style="--c: {colColor(c)}" title={c.name}>{c.name} <small>{c.limit ? `${k ?? 0}/${c.limit}` : k ?? ''}</small></b>
            {#each Array.from({ length: pvN(c, i) }) as _, j (j)}<i class="be-sk"></i>{/each}
          </div>
        {/each}
      </div>
    {:else if pv === 'pipe'}
      <div class="be-pvp">
        {#each [0, 1, 2] as r (r)}
          <div><i class="be-sk"></i><span class="be-trk" style="grid-template-columns: repeat({draft.cols.length}, 1fr)">{#each draft.cols as c, j (c.id)}<i style="--c: {colColor(c)}" class:d={j < 2 - r + 1}></i>{/each}</span></div>
        {/each}
      </div>
    {:else if pv === 'stickers'}
      <div class="be-pvs">{#each [0, 1, 2, 3, 4, 5] as k (k)}<i class="be-sk"></i>{/each}</div>
    {:else}
      <div class="be-pvl">
        {#each draft.cols.slice(0, 4) as c (c.id)}<div><i class="be-sk"></i><span style="--c: {colColor(c)}">{c.name}</span></div>{/each}
      </div>
    {/if}

    <p class="be-cap">Карточка</p>
    <div class="be-card" class:be-hp={on('prio')}>
      <div class="be-ct">{#if on('prio')}<span class="be-pr" class:hl={hover === 'prio'}>{'!'.repeat(4 - (card.prio || 1))}</span>{/if}{card.title}</div>
      {#if on('stage')}<span class="be-trk" class:hl={hover === 'stage'} style="grid-template-columns: repeat({draft.cols.length}, 1fr)">{#each draft.cols as c, j (c.id)}<i class:d={j < stageAt} class:c={j === stageAt}></i>{/each}</span>{/if}
      <div class="be-row">
        {#if on('due')}<span class="be-pc soon" class:hl={hover === 'due'}>{card.due}</span>{/if}
        {#if on('type')}<span class="be-pc ty" class:hl={hover === 'type'}>#{typeLabel(card.type) || 'work'}</span>{/if}
        {#if on('subtasks')}<span class="be-pc" class:hl={hover === 'subtasks'}>☑ {card.subs[0]} из {card.subs[1]}</span>{/if}
        {#if on('time')}<span class="be-pc" class:hl={hover === 'time'}>⏱ {fmtMin(card.spent)}</span>{/if}
        {#if on('progress')}<span class="be-pc" class:hl={hover === 'progress'}>{card.prog[0]} из {card.prog[1]}</span>{/if}
        {#if on('client')}<span class="be-pc" class:hl={hover === 'client'}>{card.client}</span>{/if}
        {#if on('money')}<span class="be-pc mo" class:hl={hover === 'money'}>{card.money}</span>{/if}
      </div>
    </div>
    <span class="be-lbl"><i></i>наведи на поле слева — оно подсветится здесь</span>

    <p class="be-cap">Окно задачи · поля{isList ? '' : ' шаблона'}</p>
    <div class="be-drw">
      <div class="be-fr" class:off={!on('due')} class:hl={hover === 'due'}><span>Срок</span><span class="v">{on('due') ? card.due : isList ? 'выключено' : 'выключено в шаблоне'}</span></div>
      <div class="be-fr" class:off={!on('prio')} class:hl={hover === 'prio'}><span>Приоритет</span><span class="v">{on('prio') ? '!!! высокий' : isList ? 'выключено' : 'выключено в шаблоне'}</span></div>
      <div class="be-fr" class:off={!on('client')} class:hl={hover === 'client'}><span>Клиент</span><span class="v">{on('client') ? card.client : isList ? 'выключено' : 'выключено в шаблоне'}</span></div>
      <div class="be-fr" class:off={!on('money')} class:hl={hover === 'money'}><span>Сумма</span><span class="v">{on('money') ? card.money : isList ? 'выключено' : 'выключено в шаблоне'}</span></div>
    </div>

    <p class="be-note">
      <svg class="be-li" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" /><circle cx="12" cy="12" r="3" /></svg>
      {#if isList}
        <span>Превью — <b>задачи этого списка</b>. Удалишь колонку — увидишь, куда уедут её задачи, до сохранения.</span>
      {:else if sample?.task}
        <span>Превью строится из <b>настоящей задачи</b> списка, где этот шаблон используется{sampleFrom ? ` («${sampleFrom}»)` : ''}. Нет задач — из примера.</span>
      {:else}
        <span>Задач с этим шаблоном пока нет — карточка из примера.</span>
      {/if}
    </p>
    {#if isList && removed.length}
      <div class="be-moves">
        {#each removed.filter((r) => r.n) as r (r.id)}<span>«{r.name}» · {E.tasksWord(r.n)} → «{draft.cols.find((c) => c.id === r.to)?.name ?? r.toName}»</span>{/each}
      </div>
    {/if}
  </aside>
</div>

{#snippet tile(f)}
  <button type="button" class="be-f" class:on={on(f.id)} role="switch" aria-checked={on(f.id)} onclick={() => toggle(f.id)}
    onmouseenter={() => (hover = f.id)} onmouseleave={() => (hover = '')} onfocus={() => (hover = f.id)} onblur={() => (hover = '')}>
    <span class="be-fi"><svg class="be-li" viewBox="0 0 24 24" aria-hidden="true">{@html f.icon}</svg></span>
    <span class="be-tx"><b>{f.name}</b><span>{f.what}</span></span>
    <span class="be-sw" aria-hidden="true"></span>
  </button>
{/snippet}
