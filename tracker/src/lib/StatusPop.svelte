<script>
  // «Состояние» (шапка 0.6): Google, между компьютерами, версия, напоминания в Telegram. Одна строка — значок, заголовок,
  // статус (бирюзовый — всё хорошо, золотой — нужно действие, красный — ошибка) и кнопка справа.
  import Popover from './Popover.svelte';
  import * as shell from './shell.js';
  import { sync, refresh, offline } from '../stores/sync.svelte.js';
  import { layer, cloudLogin } from '../stores/layer.svelte.js';
  import { upd, check, install } from '../stores/update.svelte.js';

  let { anchor, rem = null, onsettings, onclose } = $props();
  const cloud = $derived(layer.cloud);
  const version = $derived(upd.version);
  const notes = $derived(shell.notesOf(upd.found?.notes));
  const g = $derived(shell.googleLine(sync, offline()));
  const c = $derived(shell.cloudLine(cloud));
  const v = $derived(shell.versionLine(upd));
  const r = $derived(shell.remindLine(rem));
  const col = (cls, ok = 'var(--signal-done)') => (cls === 'e' ? 'var(--signal-overdue)' : cls === 'w' ? 'var(--gold)' : cls === 'c' ? 'var(--clay)' : ok);
</script>

<Popover {anchor} label="Состояние" {onclose}>
  <h5>Состояние</h5>
  <div class="st-row" style="--c: {col(g.cls)}">
    <span class="ic"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5" /></svg></span>
    <div class="tx"><b>Google Задачи и Календарь</b><span data-s={g.cls}>{g.text}</span></div>
    <button type="button" class="st-mini" disabled={sync.busy} onclick={refresh}>Обновить · R</button>
  </div>
  <div class="st-row" style="--c: {col(c.cls)}">
    <span class="ic"><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="11" height="8" rx="1.5" /><rect x="10" y="12" width="11" height="8" rx="1.5" /></svg></span>
    <div class="tx"><b>Между компьютерами</b><span data-s={c.cls}>{c.text}</span></div>
    {#if cloud.state === 'login'}<button type="button" class="st-mini pri" onclick={() => { onclose(); cloudLogin(); }}>Войти</button>{/if}
  </div>
  <div class="st-row" style="--c: {col(v.cls, 'var(--signal-done)')}">
    <span class="ic"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v12M7 10l5 5 5-5M5 21h14" /></svg></span>
    <div class="tx"><b>Спутник {version}</b><span data-s={v.cls}>{v.text}</span></div>
    {#if upd.found && !upd.busy}<button type="button" class="st-mini pri" onclick={() => { onclose(); install(); }}>Обновить</button>
    {:else if !upd.busy}<button type="button" class="st-mini" onclick={() => check(true)}>Проверить</button>{/if}
  </div>
  {#if upd.busy}<div class="st-bar"><i style="width: {Math.round((upd.progress || 0) * 100)}%"></i></div>{/if}
  {#if upd.found && notes.length}<ul class="st-notes">{#each notes as n, i (i)}<li>{n}</li>{/each}</ul>{/if}
  <div class="st-row" style="--c: {col(r.cls, 'var(--type-work)')}">
    <span class="ic"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 4L3 11l6 2 2 6 3-4 5 4z" /></svg></span>
    <div class="tx"><b>Напоминания в Telegram</b><span data-s={r.cls}>{r.text}</span></div>
  </div>
  <hr />
  <button type="button" class="st-lnk" onclick={onsettings}>⚙ Все настройки<kbd>Ctrl ,</kbd></button>
</Popover>
