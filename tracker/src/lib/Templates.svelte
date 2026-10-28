<script>
  // Экран «Шаблоны досок» (design/screens/TemplateEdit.dc.html): слева шаблоны, в середине редактор, справа живое превью.
  // Шаблон — заготовка доски: правка меняет списки, которые идут за шаблоном; списки «своё» не меняются.
  // Сам редактор — общий с окном списка (BoardEditor.svelte).
  import { untrack } from 'svelte';
  import Dropdown from './Dropdown.svelte';
  import ItemMenu from './ItemMenu.svelte';
  import BoardEditor from './BoardEditor.svelte';
  import { colColor } from './templates.js';
  import * as E from './boardedit.js';

  // templates — templatesFrom(слой); usage(id) → [{ id, title, color }] — списки, которые идут за шаблоном;
  // users(id) → [названия] всех списков с этим шаблоном (и «своих» — для удаления); count(id, colId) → задач в колонке;
  // sample(id) → { task, lay, subs, from } — настоящая задача для превью или null.
  let { templates, usage, users = (id) => usage(id).map((l) => l.title), count, sample = () => null,
    onsave, onreset, oncreate, ondelete, onback, current = null } = $props();

  let sel = $state(untrack(() => current ?? templates[0]?.id)); // открыть шаблон текущего списка
  let draft = $state(null);
  let name = $state('');
  let dirty = $state(false);
  let removed = $state([]);
  let replaceWith = $state('');
  let askDelete = $state(false);
  let menu = $state(null); // { at, id } — правый клик по своему шаблону
  let wantDelete = null; // «Удалить шаблон…» из меню: открыть шаблон и сразу спросить
  let loadedFor = '';

  const curT = $derived(templates.find((t) => t.id === sel) ?? templates[0]);
  function load(t) {
    draft = E.draftOf(t); name = t.name;
    dirty = false; removed = []; askDelete = wantDelete === t.id; wantDelete = null;
    replaceWith = templates.find((x) => x.id !== t.id)?.id ?? '';
    loadedFor = t.id;
  }
  $effect(() => { if (curT && (!draft || loadedFor !== curT.id)) untrack(() => load(curT)); });

  function choose(id) {
    if (id === sel) return;
    if (dirty && !confirm('В шаблоне есть несохранённые изменения. Перейти без сохранения?')) return;
    sel = id;
  }
  const used = $derived(curT ? usage(curT.id) : []);

  function save() {
    onsave(sel, { name: name.trim() || curT.name, ...E.draftOf(draft) }, removed);
    dirty = false; removed = [];
  }
  function reset() { onreset(sel); draft = null; loadedFor = ''; }
  async function create() {
    if (dirty && !confirm('В шаблоне есть несохранённые изменения. Создать новый без сохранения?')) return;
    sel = await oncreate();
  }
  function openMenu(e, t) {
    if (!t.mine) return; // встроенные не удаляются — у них «Вернуть как было»
    e.preventDefault();
    const r = e.currentTarget.getBoundingClientRect();
    menu = { at: e.type === 'contextmenu' && e.clientX ? { x: e.clientX, y: e.clientY } : { x: r.left + 24, y: r.bottom }, id: t.id };
  }
  function menuAction(a, id) {
    if (a === 'open') choose(id);
    else if (a === 'delete') {
      if (id === sel) { askDelete = true; return; }
      wantDelete = id;
      choose(id);
      if (sel !== id) wantDelete = null; // остался на прежнем (несохранённые изменения)
    }
  }
  function remove() {
    if (users(sel).length && !replaceWith) return;
    ondelete(sel, replaceWith);
    sel = templates.find((t) => t.id !== sel)?.id;
    draft = null; loadedFor = '';
  }
  const meta = (t) => {
    const n = usage(t.id).length;
    return `${t.cols.length} ${t.view === 'pipe' ? (t.cols.length < 5 ? 'этапа' : 'этапов') : t.cols.length < 5 ? 'колонки' : 'колонок'} · ${n ? E.listsWord(n) : 'не используется'}`;
  };
  const ex = $derived(curT ? sample(curT.id) : null);
</script>

<div class="be-page">
  <aside class="be-side" aria-label="Шаблоны">
    <button type="button" class="be-back" onclick={onback}>← К доске</button>
    <p class="be-cap">Шаблоны</p>
    {#each templates as t (t.id)}
      <button type="button" class="be-ti" aria-current={sel === t.id} onclick={() => choose(t.id)} title={t.mine ? 'Правый клик — удалить' : undefined}
        oncontextmenu={(e) => openMenu(e, t)} onkeydown={(e) => { if ((e.shiftKey && e.key === 'F10') || e.key === 'ContextMenu') openMenu(e, t); }}>
        <b><svg class="be-li" viewBox="0 0 24 24" aria-hidden="true">{@html E.VIEW_ICONS[t.view] ?? E.VIEW_ICONS.kanban}</svg>{t.name}
          {#if t.changed}<span class="badge">изменён</span>{/if}{#if t.mine}<span class="badge">свой</span>{/if}</b>
        <span class="be-mini">{#each t.cols as c (c.id)}<i style="--c: {colColor(c)}"></i>{/each}</span>
        <small>{meta(t)}</small>
      </button>
    {/each}
    <button type="button" class="be-add" onclick={create}>＋ Свой шаблон</button>
    <p class="be-hint">Новый шаблон начинается с трёх колонок: «Надо → Делаю → Готово». Свой шаблон удаляется правым кликом.</p>
  </aside>

  {#if menu}
    {@const id = menu.id}
    <ItemMenu at={menu.at} label="Действия с шаблоном" items={[{ id: 'open', label: 'Открыть' }, { id: 'delete', label: 'Удалить шаблон…', danger: true, sep: true }]}
      onaction={(a) => menuAction(a, id)} onclose={() => (menu = null)} />
  {/if}

  {#if draft}
    <BoardEditor mode="template" bind:draft bind:removed count={(colId) => count(sel, colId)} sample={ex} sampleFrom={ex?.from ?? ''} onchange={() => (dirty = true)}>
      {#snippet head()}
        <div class="be-head">
          <span class="be-kind t"><svg class="be-li" viewBox="0 0 24 24" aria-hidden="true">{@html E.VIEW_ICONS.kanban}</svg>Шаблон</span>
          <input class="be-name" type="text" aria-label="Название шаблона" value={name} oninput={(e) => { name = e.currentTarget.value; dirty = true; }} />
          {#if curT.changed}<button type="button" class="be-btn ghost sm" onclick={reset}>Вернуть как было</button>{/if}
          {#if curT.mine}<button type="button" class="be-btn ghost sm dng" onclick={() => (askDelete = true)}>Удалить…</button>{/if}
        </div>

        {#if askDelete}
          <div class="be-note" role="alertdialog" aria-label="Удалить шаблон">
            <span style="flex: 1">
              {#if users(sel).length}
                Шаблон используют: {users(sel).join(', ')}. Какой шаблон им дать вместо него?
                <Dropdown small label="Шаблон вместо удаляемого" value={replaceWith} options={templates.filter((t) => t.id !== sel).map((t) => ({ id: t.id, label: t.name }))} onchange={(v) => (replaceWith = v)} />
              {:else}
                Удалить шаблон «{curT.name}»? Им не пользуется ни один список.
              {/if}
            </span>
            <button type="button" class="be-btn ghost sm" onclick={() => (askDelete = false)}>Отмена</button>
            <button type="button" class="be-btn sm dng" onclick={remove}>Удалить</button>
          </div>
        {/if}

        <p class="be-note">
          <svg class="be-li" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" /><circle cx="12" cy="12" r="3" /></svg>
          <span><b>Шаблон — заготовка доски:</b> колонки, вид по умолчанию и поля. Правка меняет списки, которые идут за шаблоном ({used.length}).
            Списки со «своими колонками» не меняются. Чтобы поменять одну доску — «Настроить список» (⋯ у названия доски).</span>
        </p>
      {/snippet}
      {#snippet foot()}
        <footer class="be-foot">
          <div class="be-used">
            {#if used.length}Используется:{#each used as l (l.id)}<span style="--c: {l.color ?? 'var(--ink-faint)'}"><i></i>{l.title}</span>{/each}
            {:else}Пока ни один список не идёт за шаблоном — выбери его при создании списка.{/if}
          </div>
          <span class="sp"></span>
          <button type="button" class="be-btn pri" disabled={!dirty} onclick={save}>{used.length ? `Сохранить · изменит ${E.listsWord(used.length)}` : 'Сохранить шаблон'}</button>
        </footer>
      {/snippet}
    </BoardEditor>
  {/if}
</div>
