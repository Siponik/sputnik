<script>
  // Настройки (0.6): окно 880×720, ⚙ в шапке и Ctrl+, (docs/design-v2.md — «Настройки»). Слева вкладки и «Найти настройку»,
  // справа группы строк «заголовок + пояснение + управление». Всё меняется сразу, без «Сохранить».
  import { onMount, tick } from 'svelte';
  import { fade, pop } from './motion.js';
  import * as shell from './shell.js';
  import { settingsKeys } from './keys.js';
  import { calendarsAll, backupsLast, openPlace } from './api.js';

  let {
    tab: tab0 = 'look', settings = {}, lists = [], hiddenLists = [], hiddenCals = [], sphereName = () => '',
    version = '', upd, sync, offline = false, cloud, rem = null, remind = { task: [], event: [], birthday: [] }, dupes = [], ondedupe = () => {},
    onset, onhidelist, onhidecal, onremind, ontestbot, onlogout, onrefresh, oncloudlogin, oninstall, oncheck, onclose,
  } = $props();

  let tab = $state(tab0);
  let q = $state('');
  const found = $derived(shell.searchSettings(q));
  const hit = $derived(new Set(found.map((r) => r.id)));
  $effect(() => { if (found.length && !found.some((r) => r.tab === tab)) tab = found[0].tab; });
  const cur = $derived(shell.SETTINGS_TABS.find((t) => t.id === tab));

  const v = (k, d) => settings?.[k]?.v ?? d;
  const theme = $derived(v('theme', 'system'));
  const motionV = $derived(v('motion', 'full'));
  const start = $derived(v('start', 'today'));
  const tipsOn = $derived(v('tips', true) !== false);
  const remindHour = $derived(v('remindHour', '10:00'));
  const notifyOn = $derived(v('notify', true) !== false);
  const updPref = $derived(settings?.update ?? {});

  // Календари и почта аккаунта (id основного календаря — это адрес почты) — при открытии.
  let cals = $state(null);
  let email = $state('');
  let backup = $state(null);
  onMount(async () => {
    calendarsAll().then((cs) => {
      cals = cs.map((c) => ({ id: c.id, name: c.summaryOverride || c.summary, meta: c.primary ? 'основной' : /#contacts@/.test(c.id) ? 'из контактов' : /#holiday@/.test(c.id) ? 'праздники' : '', color: c.backgroundColor }));
      email = [cs.find((c) => c.primary)?.id ?? ''].find((x) => x.includes('@')) ?? '';
    }).catch(() => (cals = []));
    backup = await backupsLast();
    await tick();
    navEl?.querySelector('[aria-current="true"]')?.focus();
  });

  const g = $derived(shell.googleLine(sync, offline));
  const c = $derived(shell.cloudLine(cloud));
  const ver = $derived(shell.versionLine(upd));
  const r = $derived(shell.remindLine(rem));
  const notes = $derived(shell.notesOf(upd.found?.notes));
  const backupText = $derived(backup ? `каждый день, хранятся 14 · последняя ${backup === new Date().toISOString().slice(0, 10) ? 'сегодня' : backup.split('-').reverse().join('.')}` : 'каждый день перед первым изменением, хранятся 14');

  // Дубли задач: список групп раскрывается кнопкой, лишние копии отмечены сразу, снять можно.
  let dupOpen = $state(false);
  let dupSkip = $state(new Set());
  const dupExtra = $derived(dupes.flatMap((g) => g.extra.map((t) => ({ listId: g.listId, id: t.id }))));
  const dupPicked = $derived(dupExtra.filter((x) => !dupSkip.has(x.id)));
  const dupToggle = (id) => { const s = new Set(dupSkip); s.has(id) ? s.delete(id) : s.add(id); dupSkip = s; };
  const dupDay = (d) => (d ? d.split('-').reverse().slice(0, 2).join('.') : 'без срока');

  const CHIPS = {
    task: [[0, 'в начало'], [15, '15 мин'], [60, 'за час'], [1440, 'за день']],
    event: [[15, '15 мин'], [60, 'за час'], [1440, 'за день']],
    birthday: [[0, 'в день'], [1440, 'за день'], [10080, 'за неделю']],
  };
  function toggleLead(kind, min) {
    const now = remind[kind] ?? [];
    onremind(kind, now.includes(min) ? now.filter((m) => m !== min) : [...now, min].sort((a, b) => a - b));
  }

  let navEl = $state(null);
  function navKey(e) {
    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
    e.preventDefault();
    tab = shell.stepTab(tab, e.key === 'ArrowDown' ? 1 : -1);
    tick().then(() => navEl?.querySelector('[aria-current="true"]')?.focus());
  }
  function key(e) {
    if (e.key === 'Escape') {
      e.preventDefault(); e.stopPropagation();
      if (q && document.activeElement?.classList.contains('stg-q')) q = ''; else onclose();
    }
  }
  const TAB_ICONS = {
    look: '<circle cx="12" cy="12" r="8"/><path d="M12 4a8 8 0 0 0 0 16z"/>',
    show: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    rem: '<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 20h4"/>',
    sync: '<path d="M7 18h10a4 4 0 0 0 .5-8A6 6 0 0 0 6 9.5 4.3 4.3 0 0 0 7 18z"/>',
    upd: '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
    keys: '<rect x="3" y="7" width="18" height="11" rx="2"/><path d="M7 11h.01M11 11h.01M15 11h.01M8 15h8"/>',
  };
</script>

<svelte:window onkeydowncapture={key} />

{#snippet seg(opts, val, set)}
  <div class="stg-seg" role="group">
    {#each opts as [id, label] (id)}<button type="button" aria-pressed={val === id} onclick={() => set(id)}>{label}</button>{/each}
  </div>
{/snippet}
{#snippet sw(on, set, label)}
  <button type="button" class="stg-sw" role="switch" aria-checked={on} aria-label={label} onclick={() => set(!on)}></button>
{/snippet}
{#snippet tx(id, title, hint, cls = '')}
  <div class="tx"><b>{title}</b>{#if hint}<span data-s={cls}>{hint}</span>{/if}</div>
{/snippet}

<button class="drawer-back stg-back" type="button" aria-label="Закрыть настройки" onclick={onclose} transition:fade={{ duration: 160 }}></button>
<div class="stg-win" role="dialog" aria-modal="true" aria-label="Настройки" transition:pop>
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <nav class="stg-nav" aria-label="Разделы настроек" bind:this={navEl} onkeydown={navKey}>
    <h2>Настройки</h2>
    <label class="stg-srch">
      <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="M20 20l-4.5-4.5" /></svg>
      <input class="stg-q" bind:value={q} placeholder="Найти настройку" aria-label="Найти настройку" />
    </label>
    {#each shell.SETTINGS_TABS as t (t.id)}
      <button type="button" aria-current={tab === t.id} class:dim={q && !found.some((x) => x.tab === t.id)} onclick={() => (tab = t.id)}>
        <svg class="tic" viewBox="0 0 24 24" aria-hidden="true">{@html TAB_ICONS[t.id]}</svg>{t.name}
        {#if t.id === 'upd' && upd.found}<b class="dot" title="Есть новая версия"></b>{/if}
      </button>
    {/each}
    {#if q && !found.length}<p class="stg-none">Такой настройки нет.</p>{/if}
    <div class="ver">Спутник {version}<br />Ctrl + , — открыть настройки<br />? — все клавиши</div>
  </nav>

  <div class="stg-pane">
    <div class="stg-ph"><h3>{cur?.name}</h3><button type="button" class="x" aria-label="Закрыть" title="Закрыть · Esc" onclick={onclose}>×</button></div>
    {#key tab}
    <div class="stg-body" in:fade={{ duration: 140 }}>
      {#if tab === 'look'}
        <div class="stg-grp">
          <div class="it" class:hit={hit.has('theme')}>{@render tx('theme', 'Тема', 'Тёмная — основная. «Как в Windows» переключается вместе с системой.')}
            {@render seg([['system', 'Как в Windows'], ['dark', 'Тёмная'], ['light', 'Светлая']], theme, (x) => onset('theme', { v: x }))}</div>
          <div class="it" class:hit={hit.has('motion')}>{@render tx('motion', 'Анимации', '«Минимум» — только мягкое появление. «Выкл» — всё сразу.')}
            {@render seg([['full', 'Полные'], ['min', 'Минимум'], ['off', 'Выкл']], motionV, (x) => onset('motion', { v: x }))}</div>
          <div class="it prev-row"><div class="stg-prev {motionV}"><span class="card"></span><span>так будут двигаться карточки</span></div></div>
          <div class="it" class:hit={hit.has('start')}>{@render tx('start', 'Открывать при запуске', 'Какой раздел показывать первым')}
            {@render seg([['today', 'Сегодня'], ['board', 'Доска'], ['last', 'Где остановился']], start, (x) => onset('start', { v: x }))}</div>
          <div class="it" class:hit={hit.has('tips')}>{@render tx('tips', 'Енот-советчик', 'Советы внизу колонки доски')}
            {@render sw(tipsOn, (x) => onset('tips', { v: x }), 'Енот-советчик')}</div>
        </div>
      {:else if tab === 'show'}
        <div class="stg-lbl" class:hit={hit.has('lists')}>Списки задач</div>
        <div class="stg-grp">
          {#each lists as l (l.id)}
            {@const on = !hiddenLists.includes(l.id)}
            <div class="li"><i style="--c: {l.color ?? 'var(--ink-faint)'}"></i><span>{l.title}</span><small>{sphereName(l.id)}</small>
              {@render sw(on, (x) => onhidelist(l.id, !x), `Показывать «${l.title}»`)}</div>
          {:else}<div class="li"><span class="muted">Списков пока нет.</span></div>{/each}
        </div>
        <div class="stg-lbl" class:hit={hit.has('cals')}>Календари</div>
        <div class="stg-grp">
          {#if cals === null}<div class="li"><span class="muted">Загружаю…</span></div>{/if}
          {#each cals ?? [] as cl (cl.id)}
            {@const on = !hiddenCals.includes(cl.id)}
            <div class="li"><i style="--c: {cl.color ?? 'var(--type-work)'}"></i><span>{cl.name}</span><small>{cl.meta}</small>
              {@render sw(on, (x) => onhidecal(cl.id, !x), `Показывать «${cl.name}»`)}</div>
          {/each}
        </div>
      {:else if tab === 'rem'}
        <div class="stg-grp">
          <div class="it" class:hit={hit.has('bot')}>{@render tx('bot', 'Telegram-бот', r.cls === 'ok' ? `работает · ${r.text.replace('файл обновлён', 'файл напоминаний обновлён в')}` : r.text, r.cls)}
            <button type="button" class="stg-btn" onclick={ontestbot} title="Пришлёт в Telegram сообщение «проверка связи» в течение минуты">Проверить</button></div>
          <div class="it" class:hit={hit.has('rtask')}>{@render tx('rtask', 'Задачи — по умолчанию', 'ставится новой задаче со сроком')}
            <div class="stg-chips">{#each CHIPS.task as [m, l] (m)}<button type="button" class="c" aria-pressed={remind.task?.includes(m)} onclick={() => toggleLead('task', m)}>{l}</button>{/each}</div></div>
          <div class="it" class:hit={hit.has('revent')}>{@render tx('revent', 'События', '')}
            <div class="stg-chips">{#each CHIPS.event as [m, l] (m)}<button type="button" class="c" aria-pressed={remind.event?.includes(m)} onclick={() => toggleLead('event', m)}>{l}</button>{/each}</div></div>
          <div class="it" class:hit={hit.has('rbday')}>{@render tx('rbday', 'Дни рождения', '')}
            <div class="stg-chips">{#each CHIPS.birthday as [m, l] (m)}<button type="button" class="c" aria-pressed={remind.birthday?.includes(m)} onclick={() => toggleLead('birthday', m)}>{l}</button>{/each}</div></div>
          <div class="it" class:hit={hit.has('rhour')}>{@render tx('rhour', 'Задачи без времени', 'во сколько напоминать, если у задачи только дата')}
            {@render seg([['09:00', '9:00'], ['10:00', '10:00'], ['12:00', '12:00']], remindHour, (x) => onset('remindHour', { v: x }))}</div>
          <div class="it" class:hit={hit.has('notify')}>{@render tx('notify', 'Уведомления Windows', 'вехи привычек; основное — в боте')}
            {@render sw(notifyOn, (x) => onset('notify', { v: x }), 'Уведомления Windows')}</div>
        </div>
      {:else if tab === 'sync'}
        <div class="stg-grp">
          <div class="it" class:hit={hit.has('acct')}><span class="av" aria-hidden="true">{(email || 'G')[0].toUpperCase()}</span>
            {@render tx('acct', 'Google-аккаунт', `${email ? email + ' · ' : ''}задачи, календарь, скрытая папка`)}
            <button type="button" class="stg-btn dng" onclick={onlogout}>Выйти</button></div>
          <div class="it" class:hit={hit.has('google')}>{@render tx('google', 'Google Задачи и Календарь', g.text.replace('раз в 2 минуты', 'автоматически раз в 2 минуты'), g.cls)}
            <button type="button" class="stg-btn" disabled={sync.busy} onclick={onrefresh}>Обновить · R</button></div>
          <div class="it" class:hit={hit.has('cloud')}>{@render tx('cloud', 'Между компьютерами', c.text, c.cls)}
            {#if cloud.state === 'login'}<button type="button" class="stg-btn pri" onclick={oncloudlogin}>Разрешить</button>{/if}</div>
          <div class="it" class:hit={hit.has('dupes')}>{@render tx('dupes', 'Дубли задач', dupExtra.length ? `лишних копий: ${dupExtra.length} — одинаковые название и срок в одном списке` : 'не найдено', dupExtra.length ? 'w' : '')}
            {#if dupExtra.length}<button type="button" class="stg-btn" aria-expanded={dupOpen} onclick={() => (dupOpen = !dupOpen)}>{dupOpen ? 'Скрыть' : 'Показать'}</button>{/if}</div>
          {#if dupOpen && dupExtra.length}
            <div class="stg-dupes">
              {#each dupes as g (g.listId + g.keep.id)}
                <div class="dg"><b>{g.title}</b><span>{g.listName} · {dupDay(g.due)} · оставим одну</span>
                  {#each g.extra as t, i (t.id)}
                    <label><input type="checkbox" checked={!dupSkip.has(t.id)} onchange={() => dupToggle(t.id)} /> копия {i + 2} — удалить</label>
                  {/each}
                </div>
              {/each}
              <button type="button" class="stg-btn dng" disabled={!dupPicked.length} onclick={() => ondedupe(dupPicked)}>Удалить отмеченные ({dupPicked.length})</button>
            </div>
          {/if}
          <div class="it" class:hit={hit.has('backup')}>{@render tx('backup', 'Резервные копии', backupText)}
            <button type="button" class="stg-btn" onclick={() => openPlace('backups').catch(() => {})}>Открыть папку</button></div>
        </div>
      {:else if tab === 'upd'}
        <div class="stg-grp">
          <div class="it" class:hit={hit.has('ver')}>{@render tx('ver', `Спутник ${version}`, upd.found && !upd.busy ? `${ver.text}, данные не пострадают` : ver.text, ver.cls === 'c' ? 'w' : ver.cls)}
            {#if upd.found && !upd.busy}<button type="button" class="stg-btn pri" onclick={oninstall}>Обновить</button>
            {:else if !upd.busy}<button type="button" class="stg-btn" onclick={oncheck}>Проверить</button>{/if}</div>
          {#if upd.found && notes.length}<ul class="stg-notes">{#each notes as n, i (i)}<li>{n}</li>{/each}</ul>{/if}
          <div class="it" class:hit={hit.has('auto')}>{@render tx('auto', 'Проверять самому', 'через 30 секунд после запуска и раз в 6 часов')}
            {@render sw(updPref.auto !== false, (x) => onset('update', { auto: x }), 'Проверять обновления самому')}</div>
          <div class="it" class:hit={hit.has('night')}>{@render tx('night', 'Ставить ночью', 'если компьютер включён — обновится в 3:00 без вопросов')}
            {@render sw(!!updPref.night, (x) => onset('update', { night: x }), 'Ставить обновления ночью')}</div>
          <div class="it" class:hit={hit.has('all')}>{@render tx('all', 'Все версии', 'список изменений на GitHub')}
            <button type="button" class="stg-btn" onclick={() => openPlace('releases').catch(() => {})}>Открыть</button></div>
        </div>
      {:else if tab === 'keys'}
        <div class="stg-kg" class:hit={hit.has('keys')}>
          {#each settingsKeys() as gr (gr.group)}
            <div class="stg-grp">
              <h6>{gr.group}</h6>
              {#each gr.keys as [k, l] (k + l)}<div class="kr">{l}<kbd>{k}</kbd></div>{/each}
            </div>
          {/each}
        </div>
        <p class="stg-foot">Клавиши работают и в русской раскладке. Полный список — по «?» в любом месте.</p>
      {/if}
    </div>
    {/key}
  </div>
</div>
