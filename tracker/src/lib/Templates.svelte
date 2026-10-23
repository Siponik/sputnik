<script>
  // Экран «Шаблоны досок» (design/screens/Templates.dc.html): слева шаблоны, справа редактор выбранного.
  import { untrack } from 'svelte';
  import { PALETTE, VIEWS, FIELDS, colColor, isBuiltin } from './templates.js';
  import ItemMenu from './ItemMenu.svelte';

  // templates — templatesFrom(слой); usage(id) → [названия списков]; count(id, colId) → открытых задач в колонке.
  let { templates, usage, count, onsave, onreset, oncreate, ondelete, onback, current = null } = $props();

  let sel = $state(untrack(() => current ?? templates[0]?.id)); // открыть шаблон текущего списка
  let draft = $state(null);
  let dirty = $state(false);
  let note = $state('');
  let removed = $state([]); // [{ id, name, to, toName, n }] — удалённые колонки (задачи переедут при сохранении)
  let replaceWith = $state('');
  let askDelete = $state(false);
  let menu = $state(null); // { at, id } — правый клик по своему шаблону
  let wantDelete = null; // «Удалить шаблон…» из меню: открыть шаблон и сразу спросить

  const curT = $derived(templates.find((t) => t.id === sel) ?? templates[0]);
  function load(t) {
    draft = { name: t.name, view: t.view, fields: [...t.fields], cols: t.cols.map((c) => ({ ...c })) };
    dirty = false; note = ''; removed = []; askDelete = wantDelete === t.id; wantDelete = null;
    replaceWith = templates.find((x) => x.id !== t.id)?.id ?? '';
  }
  $effect(() => { if (curT && (!draft || draft._for !== curT.id)) { load(curT); draft._for = curT.id; } });

  function choose(id) {
    if (id === sel) return;
    if (dirty && !confirm('В шаблоне есть несохранённые изменения. Перейти без сохранения?')) return;
    sel = id;
  }
  const edit = (fn) => { fn(); dirty = true; };
  const end = $derived(draft ? draft.cols.length - 1 : 0);

  function move(i, d) { edit(() => { const c = draft.cols; [c[i], c[i + d]] = [c[i + d], c[i]]; }); }
  function recolor(i) { edit(() => { draft.cols[i].color = ((draft.cols[i].color ?? 0) + 1) % PALETTE.length; }); }
  function limit(i, d) { edit(() => { draft.cols[i].limit = Math.max(0, Math.min(20, (draft.cols[i].limit ?? 0) + d)); }); }
  function addCol() {
    edit(() => draft.cols.splice(end, 0, { id: 'c' + Date.now().toString(36), name: 'Новая колонка', color: 0, limit: 0 }));
  }
  function delCol(i) {
    if (draft.cols.length <= 2 || i === end) return;
    const c = draft.cols[i];
    const to = draft.cols[i > 0 ? i - 1 : i + 1];
    const n = count(sel, c.id);
    edit(() => {
      draft.cols.splice(i, 1);
      // если в удалённую колонку уже переезжали задачи — теперь они едут дальше
      removed = removed.map((r) => (r.to === c.id ? { ...r, to: to.id, toName: to.name } : r)).concat([{ id: c.id, name: c.name, to: to.id, toName: to.name, n }]);
    });
    note = n
      ? `Колонка «${c.name}» удалена. ${n} ${n === 1 ? 'задача переедет' : n < 5 ? 'задачи переедут' : 'задач переедут'} в «${to.name}» после сохранения.${isBuiltin(sel) ? ' Передумаешь — «Вернуть как было».' : ''}`
      : `Колонка «${c.name}» удалена — задач в ней не было.`;
  }
  function toggleField(f) { edit(() => { draft.fields = draft.fields.includes(f) ? draft.fields.filter((x) => x !== f) : [...draft.fields, f]; }); }

  function save() {
    const name = draft.name.trim() || curT.name;
    onsave(sel, { name, view: draft.view, fields: draft.fields, cols: draft.cols.map(({ id, name, color, limit }) => ({ id, name: name.trim() || 'Без названия', color, limit })) }, removed);
    dirty = false; removed = []; note = 'Шаблон сохранён.';
  }
  function reset() { onreset(sel); draft = null; }
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
    if (usage(sel).length && !replaceWith) return;
    ondelete(sel, replaceWith);
    sel = templates.find((t) => t.id !== sel)?.id;
    draft = null;
  }
  const meta = (t) => `${t.cols.length} ${t.cols.length < 5 ? 'колонки' : 'колонок'} · ${usage(t.id).length} ${(() => { const n = usage(t.id).length; return n === 1 ? 'список' : n >= 2 && n <= 4 ? 'списка' : 'списков'; })()}`;
</script>

<div class="tpl-screen">
  <aside class="tpl-list" aria-label="Шаблоны">
    <div class="tl-head">
      <button type="button" class="sp-btn sp-btn-ghost back" onclick={onback}>← К доске</button>
      <p class="cap">Шаблоны досок</p>
    </div>
    {#each templates as t (t.id)}
      <button type="button" class="ti" aria-current={sel === t.id} onclick={() => choose(t.id)} title={t.mine ? 'Правый клик — удалить' : undefined}
        oncontextmenu={(e) => openMenu(e, t)} onkeydown={(e) => { if ((e.shiftKey && e.key === 'F10') || e.key === 'ContextMenu') openMenu(e, t); }}>
        <b>{t.name}{#if t.changed}<span class="badge">изменён</span>{/if}{#if t.mine}<span class="badge mine">свой</span>{/if}</b>
        <span class="mini">{#each t.cols as c, i (c.id)}<i class:end={i === t.cols.length - 1}></i>{/each}</span>
        <small>{meta(t)}</small>
      </button>
    {/each}
    <button type="button" class="sp-btn add-tpl" onclick={create}>＋ Свой шаблон</button>
    <p class="hint">Новый шаблон начинается с трёх колонок: «Надо → Делаю → Готово». Свой шаблон удаляется правым кликом.</p>
  </aside>

  {#if menu}
    {@const id = menu.id}
    <ItemMenu at={menu.at} label="Действия с шаблоном" items={[{ id: 'open', label: 'Открыть' }, { id: 'delete', label: 'Удалить шаблон…', danger: true, sep: true }]}
      onaction={(a) => menuAction(a, id)} onclose={() => (menu = null)} />
  {/if}

  {#if draft}
    <main class="tpl-ed">
      <header class="ed-head">
        <div class="ed-name">
          <label class="cap" for="tp-name">Название</label>
          <input id="tp-name" class="in big" type="text" value={draft.name} oninput={(e) => edit(() => (draft.name = e.currentTarget.value))} />
        </div>
        {#if curT.changed}<button type="button" class="sp-btn sp-btn-ghost" onclick={reset}>Вернуть как было</button>{/if}
        {#if curT.mine}<button type="button" class="sp-btn sp-btn-ghost danger" onclick={() => (askDelete = true)}>Удалить шаблон</button>{/if}
      </header>

      {#if askDelete}
        <div class="warn">
          {#if usage(sel).length}
            Шаблон используют: {usage(sel).join(', ')}. Какой шаблон им дать вместо него?
            <select class="in small" bind:value={replaceWith}>
              {#each templates.filter((t) => t.id !== sel) as t (t.id)}<option value={t.id}>{t.name}</option>{/each}
            </select>
          {:else}
            Удалить шаблон «{curT.name}»? Им не пользуется ни один список.
          {/if}
          <span class="wa">
            <button type="button" class="sp-btn sp-btn-ghost" onclick={() => (askDelete = false)}>Отмена</button>
            <button type="button" class="sp-btn danger" onclick={remove}>Удалить</button>
          </span>
        </div>
      {/if}

      <div class="ed-view">
        <div>
          <p class="cap">Вид по умолчанию</p>
          <div class="seg3" role="group" aria-label="Вид по умолчанию">
            {#each VIEWS as v (v.id)}<button type="button" aria-pressed={draft.view === v.id} onclick={() => edit(() => (draft.view = v.id))}>{v.name}</button>{/each}
          </div>
        </div>
        <p class="vh">{VIEWS.find((v) => v.id === draft.view)?.hint}</p>
      </div>

      <section aria-label="Колонки">
        <div class="cols-head"><p class="cap">Колонки · {draft.cols.length}</p><span>порядок ▲▼ · цвет — клик по точке · лимит — сколько задач может быть в колонке сразу</span></div>
        <div class="crs">
          {#each draft.cols as c, i (c.id)}
            {@const isEnd = i === end}
            <div class="cr" class:lock={isEnd}>
              <span class="mv">
                <button type="button" aria-label="Выше" disabled={i === 0 || isEnd} onclick={() => move(i, -1)}>▲</button>
                <button type="button" aria-label="Ниже" disabled={i >= end - 1 || isEnd} onclick={() => move(i, 1)}>▼</button>
              </span>
              <button type="button" class="dot" aria-label="Цвет колонки: {PALETTE[c.color ?? 0].name} — сменить" title="Сменить цвет" style="background: {colColor(c)}" onclick={() => recolor(i)}></button>
              <input class="in" type="text" aria-label="Название колонки" value={c.name} oninput={(e) => edit(() => (draft.cols[i].name = e.currentTarget.value))} />
              <span class="lim">
                {#if !isEnd}
                  <button type="button" aria-label="Меньше" onclick={() => limit(i, -1)}>−</button>
                  <span>{c.limit ? `до ${c.limit}` : 'без лимита'}</span>
                  <button type="button" aria-label="Больше" onclick={() => limit(i, 1)}>+</button>
                {/if}
              </span>
              <span class="cnt">{count(sel, c.id) || ''}</span>
              {#if isEnd}
                <span class="lk" title="Последняя колонка — задача в ней выполнена в Google Tasks. Переименовать можно, удалить и сдвинуть нельзя.">
                  <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="11" width="14" height="9" rx="2" /><path d="M8 11V8a4 4 0 0 1 8 0v3" /></svg>
                </span>
              {:else}
                <button type="button" class="x" aria-label="Удалить колонку {c.name}" disabled={draft.cols.length <= 2} title={draft.cols.length <= 2 ? 'Минимум 2 колонки' : 'Удалить колонку'} onclick={() => delCol(i)}>×</button>
              {/if}
            </div>
          {/each}
          {#if note}<div class="warn" role="status">{note}</div>{/if}
          <button type="button" class="sp-btn sp-btn-ghost" style="align-self: flex-start" onclick={addCol}>＋ Колонка перед «{draft.cols[end].name}»</button>
          <p class="hint">Последняя колонка закреплена: задача в ней выполнена в Google Tasks. Её можно переименовать, но нельзя удалить или сдвинуть.</p>
        </div>
      </section>

      <section aria-label="Что показывать на карточке">
        <p class="cap">На карточке</p>
        <div class="tgs">{#each FIELDS as f (f.id)}<button type="button" class="tg" aria-pressed={draft.fields.includes(f.id)} onclick={() => toggleField(f.id)}>{f.name}</button>{/each}</div>
      </section>

      <section aria-label="Предпросмотр">
        <p class="cap">Предпросмотр доски</p>
        <div class="tpl-pv">
          {#each draft.cols as c, i (c.id)}
            <div style="--pc: {colColor(c)}"><b>{c.name}</b>{#each Array.from({ length: Math.min(3, count(sel, c.id) || (i === 0 ? 2 : 1)) }) as _, k (k)}<i></i>{/each}</div>
          {/each}
        </div>
      </section>

      <footer class="ed-foot">
        <span>{usage(sel).length ? `Используется: ${usage(sel).join(', ')}` : 'Пока не используется — выбери его при создании списка.'}{dirty ? ' · есть несохранённые изменения' : ''}</span>
        <button type="button" class="sp-btn sp-btn-primary" disabled={!dirty} onclick={save}>Сохранить шаблон</button>
      </footer>
    </main>
  {/if}
</div>
