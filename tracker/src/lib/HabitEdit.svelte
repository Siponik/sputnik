<script>
  // Окно привычки (design/screens/HabitEdit.dc.html): «＋ Привычка», «Создать» на экране привычек, «Изменить» в панели.
  // Значок и цвет, как часто, цель на день, когда, напомнить; превью «Так будет». Enter — сохранить, Esc — отмена.
  import * as H from './habits.js';
  import { ICONS, ICON_IDS, COLORS, COLOR_IDS, iconOf, UNITS } from './habitIcons.js';
  import { fade, pop } from './motion.js';

  let { habit = null, preset = null, i = 0, onsave, onclose } = $props();

  const src = habit ?? preset ?? {};
  const COLOR_KEYS = COLOR_IDS;
  let name = $state(src.name ?? '');
  let icon = $state(iconOf(src, i));
  let color = $state(COLORS[src.color] ? src.color : COLOR_KEYS[i % COLOR_KEYS.length]);
  let freq = $state(src.perWeek > 0 ? 'week' : src.days?.length && src.days.length < 7 ? 'days' : 'daily');
  let days = $state(src.days?.length ? [...src.days] : [0, 1, 2, 3, 4]);
  let perWeek = $state(src.perWeek > 0 ? src.perWeek : 3);
  let goalOn = $state(H.goalN(src) > 0);
  let goalN = $state(H.goalN(src) || 8);
  let unit = $state(src.goal?.unit || 'раз');
  let when = $state(src.time ? 'time' : H.partOf(src));
  let time = $state(src.time ?? '');
  let tg = $state(src.remind?.tg !== false);
  let win = $state(!!src.remind?.win);
  let busy = $state(false);
  let nameEl = $state(null);
  $effect(() => { nameEl?.focus(); });

  const fields = $derived({
    name: name.trim(),
    icon, color,
    days: freq === 'days' ? [...days].sort() : [],
    perWeek: freq === 'week' ? perWeek : null,
    goal: goalOn && goalN > 1 ? { n: goalN, unit } : null,
    part: when === 'time' ? H.partOf({ time }) : when,
    time: when === 'time' && /^\d{1,2}:\d{2}$/.test(time) ? time : null,
    remind: { tg, win },
  });
  const ok = $derived(!!fields.name && (freq !== 'days' || days.length > 0) && (when !== 'time' || !!fields.time));
  const at = $derived(H.remindAt(fields));
  const prevLine = $derived(H.cardLine({ ...fields, id: '_' }, {}, new Date()));

  async function submit(e) {
    e?.preventDefault();
    if (!ok || busy) return;
    busy = true;
    try { await onsave(fields); } finally { busy = false; }
  }
  function toggleDay(d) { days = days.includes(d) ? days.filter((x) => x !== d) : [...days, d]; }
  function key(e) {
    if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); onclose(); }
  }
</script>

<svelte:window onkeydowncapture={key} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={onclose} transition:fade={{ duration: 160 }}></button>
<form class="hb-dlg" role="dialog" aria-modal="true" aria-label={habit ? 'Привычка' : 'Новая привычка'} onsubmit={submit} transition:pop style="--hc: {COLORS[color]}">
  <h2>{habit ? 'Привычка' : 'Новая привычка'}
    <button type="button" class="hb-ib" aria-label="Закрыть" title="Закрыть · Esc" onclick={onclose}><svg class="li" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18" /></svg></button></h2>

  <div class="nmr">
    <span class="icb" aria-hidden="true"><svg class="li" viewBox="0 0 24 24">{@html ICONS[icon]}</svg></span>
    <input bind:this={nameEl} bind:value={name} placeholder="Например: скетч 15 минут" aria-label="Название" />
  </div>

  <div class="fr"><span>Значок и цвет</span>
    <div>
      <div class="icg" role="group" aria-label="Значок">
        {#each ICON_IDS as id (id)}<button type="button" aria-pressed={icon === id} aria-label="Значок" onclick={() => (icon = id)}><svg class="li" viewBox="0 0 24 24" aria-hidden="true">{@html ICONS[id]}</svg></button>{/each}
      </div>
      <div class="cols" role="group" aria-label="Цвет">
        {#each COLOR_KEYS as c (c)}<button type="button" style="--c: {COLORS[c]}" aria-pressed={color === c} aria-label="Цвет" onclick={() => (color = c)}></button>{/each}
      </div>
    </div>
  </div>

  <div class="fr"><span>Как часто</span>
    <div>
      <div class="ops">
        <button type="button" class="op" aria-pressed={freq === 'daily'} onclick={() => (freq = 'daily')}>Каждый день</button>
        <button type="button" class="op" aria-pressed={freq === 'days'} onclick={() => (freq = 'days')}>По дням недели</button>
        <button type="button" class="op" aria-pressed={freq === 'week'} onclick={() => (freq = 'week')}>N раз в неделю</button>
      </div>
      {#if freq === 'days'}
        <div class="ops" style="margin-top: 8px" role="group" aria-label="Дни">
          {#each H.WEEKDAYS as w, d (w)}<button type="button" class="op day" aria-pressed={days.includes(d)} onclick={() => toggleDay(d)}>{w}</button>{/each}
        </div>
      {:else if freq === 'week'}
        <div class="ops" style="margin-top: 8px">
          <span class="num"><button type="button" aria-label="Меньше" onclick={() => (perWeek = Math.max(1, perWeek - 1))}>−</button>{perWeek}<button type="button" aria-label="Больше" onclick={() => (perWeek = Math.min(6, perWeek + 1))}>+</button></span>
          <span class="hint" style="margin: 0">{H.plural(perWeek, ['раз', 'раза', 'раз'])} в неделю — серия считается в неделях, свободные дни не пропуск</span>
        </div>
      {/if}
    </div>
  </div>

  <div class="fr"><span>Цель на день</span>
    <div>
      <div class="ops">
        <button type="button" class="op" aria-pressed={!goalOn} onclick={() => (goalOn = false)}>Просто отметка</button>
        <button type="button" class="op" aria-pressed={goalOn} onclick={() => (goalOn = true)}>Количество</button>
        {#if goalOn}
          <span class="num"><button type="button" aria-label="Меньше" onclick={() => (goalN = Math.max(2, goalN - 1))}>−</button>{goalN}<button type="button" aria-label="Больше" onclick={() => (goalN = Math.min(99, goalN + 1))}>+</button></span>
          <select class="op" bind:value={unit} aria-label="Чего">{#each UNITS as u (u)}<option value={u}>{u}</option>{/each}</select>
        {/if}
      </div>
      {#if goalOn}<p class="hint">На карточке будет «+1», а не галочка.</p>{/if}
    </div>
  </div>

  <div class="fr"><span>Когда</span>
    <div class="ops">
      {#each H.PARTS as p (p.id)}<button type="button" class="op" aria-pressed={when === p.id} onclick={() => (when = p.id)}>{p.name}</button>{/each}
      {#if when === 'time'}
        <input class="op tm" type="time" bind:value={time} aria-label="Точное время" />
      {:else}
        <button type="button" class="op" aria-pressed="false" onclick={() => { when = 'time'; time ||= '21:00'; }}>Точное время…</button>
      {/if}
    </div>
  </div>

  <div class="fr"><span>Напомнить</span>
    <div>
      <div class="ops">
        <button type="button" class="op" aria-pressed={tg} onclick={() => (tg = !tg)}><svg class="li" viewBox="0 0 24 24" aria-hidden="true"><path d="M3.5 11.5L20 5l-3 14-5-4-3 3v-5l8-7" /></svg>Telegram</button>
        <button type="button" class="op" aria-pressed={win} onclick={() => (win = !win)}><svg class="li" viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="5" width="18" height="12" rx="2" /><path d="M8 20h8" /></svg>Windows</button>
      </div>
      <p class="hint">{at ? (tg || win ? `в ${at}, если к этому времени не отмечено` : 'не напоминать') : 'когда угодно — без напоминания; выбери часть дня или время'}</p>
    </div>
  </div>

  <div class="prv"><small>Так будет</small>
    <div class="hb-card mini">
      <div class="hh">
        <span class="hb-ic" style="width: 40px; height: 40px"><svg class="li" viewBox="0 0 24 24" aria-hidden="true">{@html ICONS[icon]}</svg></span>
        <div class="t"><b>{fields.name || 'Название'}</b><span>{prevLine}</span></div>
        {#if fields.goal}<span class="hb-chk q" style="width: 40px; height: 40px">+1</span>{:else}<span class="hb-chk" style="width: 40px; height: 40px"></span>{/if}
      </div>
    </div>
  </div>

  <div class="ft">
    <span class="nt">Хранится в Google Tasks, список «Привычки»</span>
    <button type="button" class="hb-btn gh" onclick={onclose}>Отмена</button>
    <button type="submit" class="hb-btn pri" disabled={!ok || busy}>{habit ? 'Сохранить' : 'Добавить'} · Enter</button>
  </div>
</form>
