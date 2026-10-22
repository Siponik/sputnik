<script>
  // Картинка задачи (превью рендера, скрин, референс): показать, поставить, заменить, убрать.
  // Поставить — перетащить файл, вставить Ctrl+V (когда блок в фокусе) или выбрать файл. Клик по картинке — крупно.
  // pv — tasks[id].preview из слоя; onset(file) — загрузить (Promise), onclear() — убрать. off — почему нельзя (общая сфера).
  import { imageFrom, dragHasFile, rejectWhy } from './preview.js';
  import { load } from './previewDrive.js';
  import PreviewView from './PreviewView.svelte';

  let { pv = null, title = '', onset, onclear, off = '' } = $props();

  let full = $state(null); // большая копия с Drive
  let busy = $state(false);
  let err = $state('');
  let over = $state(false);
  let big = $state(false);
  let input = $state(null);

  $effect(() => {
    const file = pv?.file;
    full = null;
    if (!file) return;
    let live = true;
    load(file).then((u) => { if (live) full = u; });
    return () => { live = false; };
  });

  async function take(f) {
    const why = rejectWhy(f);
    if (why) { err = why; return; }
    err = '';
    busy = true;
    try { await onset(f); }
    catch (e) { err = 'Не удалось загрузить: ' + e; }
    finally { busy = false; }
  }
  function drop(e) {
    over = false;
    if (off || busy) return;
    const f = imageFrom(e.dataTransfer);
    if (!f && !dragHasFile(e.dataTransfer)) return;
    e.preventDefault();
    e.stopPropagation();
    take(f);
  }
  function dragover(e) {
    if (off || busy || !dragHasFile(e.dataTransfer)) return;
    e.preventDefault();
    e.stopPropagation();
    e.dataTransfer.dropEffect = 'copy';
    over = true;
  }
  function paste(e) {
    if (off || busy) return;
    const f = imageFrom(e.clipboardData);
    if (!f) return;
    e.preventDefault();
    take(f);
  }
  function pick(e) {
    const f = e.currentTarget.files?.[0];
    e.currentTarget.value = '';
    if (f) take(f);
  }
  const stop = (fn) => (e) => { e.stopPropagation(); fn(e); };
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="pvb" class:over class:has={!!pv?.thumb} ondragover={dragover} ondragleave={() => (over = false)} ondrop={drop} onpaste={paste}>
  {#if pv?.thumb}
    <button type="button" class="pvb-img" title="Открыть крупно" onclick={stop(() => (big = true))}>
      <img src={full ?? pv.thumb} alt="Картинка: {title}" />
      {#if busy}<span class="pvb-busy">Загружаю…</span>{/if}
    </button>
    {#if !off}
      <div class="pvb-act">
        <button type="button" class="sp-btn sp-btn-ghost" disabled={busy} onclick={stop(() => input.click())}>Заменить</button>
        <button type="button" class="sp-btn sp-btn-ghost" disabled={busy} onclick={stop(() => onclear())}>Убрать</button>
        <span class="hint">или перетащи / вставь другую</span>
      </div>
    {/if}
  {:else if off}
    <p class="hint">{off}</p>
  {:else}
    <button type="button" class="pvb-zone" disabled={busy} onclick={stop(() => input.click())}>
      {#if busy}Загружаю…{:else}<b>＋ Картинка</b><span>перетащи файл, вставь Ctrl+V или нажми, чтобы выбрать</span>{/if}
    </button>
  {/if}
  {#if err}<p class="pvb-err" role="alert">{err}</p>{/if}
  <input bind:this={input} type="file" accept="image/png,image/jpeg,image/webp,image/gif,image/bmp" hidden onchange={pick} />
</div>

{#if big && pv?.thumb}
  <PreviewView src={full ?? pv.thumb} {title} onclose={() => (big = false)} />
{/if}
