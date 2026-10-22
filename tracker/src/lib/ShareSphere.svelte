<script>
  import { fade, pop } from './motion.js';
  import { parseEmails, nameOf, seenText, MEMBER_COLORS, NAME_MAX, PIC_MAX } from './sharedcore.js';
  import { iconPath, sphereColor } from './spheres.js';
  import Avatar from './Avatar.svelte';
  import SharedTag from './SharedTag.svelte';

  // Окно общей сферы (docs/design-v2.md, «Общие сферы» 1; макет design/screens/ShareInvite.dc.html).
  // mode: 'make' — «Сделать «…» общей» (первый раз), 'people' — участники (владелец зовёт и убирает, участник — только видит
  // и может выйти), 'join' — войти по коду. Сами действия — в App (oninvite, onremove…), окно только собирает ввод.
  let { mode = 'people', sphere = null, owner = false, people = [], me = '', listNames = [],
    onmake, oninvite, onremove, onstop, onleave, oncopy, onjoin, onclose, profile = null, onprofile } = $props();

  let chips = $state([]); // почты, уже ставшие чипами
  let text = $state('');
  let code = $state('');
  let busy = $state(false);
  let err = $state('');
  let input = $state(null);
  $effect(() => { input?.focus(); });

  const others = $derived(people.filter((p) => p.email !== me));
  const mine = $derived(people.find((p) => p.email === me) ?? null);
  // Чип ещё не участника: цвет — следующий по порядку.
  const chipColor = (i) => MEMBER_COLORS[(people.length + i) % MEMBER_COLORS.length];

  /** Текст поля → чипы (Enter, запятая, пробел, потеря фокуса). Неверная почта остаётся в поле. */
  function commit() {
    const { ok, bad } = parseEmails(text);
    const known = new Set([...chips, ...people.map((p) => p.email)]);
    chips = [...chips, ...ok.filter((e) => !known.has(e))];
    text = bad.join(' ');
    err = bad.length ? `Не похоже на почту: ${bad.join(', ')}` : '';
    return !bad.length;
  }
  function key(e) {
    if (e.key === 'Enter' || e.key === ',' || e.key === ';' || (e.key === ' ' && text.includes('@'))) {
      e.preventDefault();
      if (e.key === 'Enter' && !text.trim() && chips.length && mode === 'people') { send(); return; }
      commit();
    } else if (e.key === 'Backspace' && !text && chips.length) chips = chips.slice(0, -1);
  }
  async function send() {
    if (!commit() || busy) return;
    if (mode === 'people' && !chips.length) return;
    busy = true;
    try {
      if (mode === 'make') await onmake([...chips]);
      else { await oninvite([...chips]); chips = []; }
    } catch (e) { err = String(e); }
    finally { busy = false; }
  }
  async function run(fn) {
    if (busy) return;
    busy = true;
    try { await fn(); } catch (e) { err = String(e); } finally { busy = false; }
  }
  async function join(e) {
    e.preventDefault();
    if (!code.trim() || busy) return;
    run(() => onjoin(code.trim()));
  }

  // «Как меня видят»: имя, цвет, фото — одни на все общие сферы (App.saveProfile).
  let prof = $state(null); // черновик { name, color, pic } или null — редактор закрыт
  let picIn = $state(null);
  function openProf() {
    const i = MEMBER_COLORS.indexOf(mine?.color);
    prof = { name: profile?.name ?? '', color: Number.isInteger(profile?.color) ? profile.color : (i >= 0 ? i : 0), pic: profile?.pic ?? null };
    err = '';
  }
  /** Фото → квадрат 64×64 JPEG: помещается в запись участника (описание события Google). */
  function pickPic(e) {
    const file = e.currentTarget.files?.[0];
    e.currentTarget.value = '';
    if (!file) return;
    const url = URL.createObjectURL(file), img = new Image();
    img.onload = () => {
      const c = document.createElement('canvas'); c.width = c.height = 64;
      const side = Math.min(img.width, img.height);
      c.getContext('2d').drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, 64, 64);
      URL.revokeObjectURL(url);
      let d = c.toDataURL('image/jpeg', 0.82);
      if (d.length > PIC_MAX) d = c.toDataURL('image/jpeg', 0.55);
      if (d.length > PIC_MAX) { err = 'Не получилось уменьшить фото — попробуй другое'; return; }
      prof = { ...prof, pic: d }; err = '';
    };
    img.onerror = () => { URL.revokeObjectURL(url); err = 'Это не похоже на картинку'; };
    img.src = url;
  }
  const preview = $derived(prof && mine ? { ...mine, name: prof.name.trim() || nameOf(me), letter: (prof.name.trim() || nameOf(me))[0].toUpperCase(), color: MEMBER_COLORS[prof.color], pic: prof.pic } : null);
  async function saveProf() { await run(() => onprofile(prof)); if (!err) prof = null; }

  const subline = (p) => (p.joined
    ? `${p.email}${p.seen ? ` · последний раз ${seenText(p.seen)}` : ''}`
    : `приглашение отправлено ${p.invited ? seenText(p.invited).replace(/ в \d+:\d+$/, '') : ''} · ещё не принял`);
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && !busy && onclose()} />

{#snippet icon(size)}
  <span class="sph-ic" style="--sc: {sphereColor(sphere)}; width: {size}px; height: {size}px; border-radius: {size > 28 ? 9 : 8}px; display: inline-grid; place-items: center; color: {sphereColor(sphere)}; background: color-mix(in srgb, {sphereColor(sphere)} 16%, transparent); flex: none">
    <svg viewBox="0 0 24 24" width={size * .55} height={size * .55} fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d={iconPath(sphere)} /></svg>
  </span>
{/snippet}

{#snippet editBtn()}
  {#if onprofile && !prof}<button class="sh-btn sm ghost" type="button" onclick={openProf}>Изменить</button>{/if}
{/snippet}

{#snippet field()}
  <div class="sh-inv">
    <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
    <div class="sh-in" onclick={() => input?.focus()}>
      {#each chips as c, i (c)}
        <span class="sh-chip"><Avatar m={{ email: c, name: nameOf(c), letter: c[0].toUpperCase(), color: chipColor(i), joined: true }} size={18} />{c}
          <button type="button" aria-label="Убрать {c}" onclick={() => (chips = chips.filter((x) => x !== c))}>×</button></span>
      {/each}
      <input bind:this={input} bind:value={text} onkeydown={key} onblur={() => text.trim() && commit()} aria-label="Почты Google"
        placeholder={chips.length ? '' : 'Почта Google, можно несколько через запятую'} autocomplete="off" spellcheck="false" />
    </div>
    {#if mode === 'make'}
      <button class="sh-btn" type="button" disabled={busy || !text.trim()} onclick={commit}>Пригласить</button>
    {:else}
      <button class="sh-btn" type="button" disabled={busy || (!text.trim() && !chips.length)} onclick={send}>{busy ? 'Зову…' : 'Пригласить'}</button>
    {/if}
  </div>
  {#if err}<p class="sh-err">{err}</p>{/if}
{/snippet}

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={() => !busy && onclose()} transition:fade={{ duration: 180 }}></button>

{#if mode === 'join'}
  <form transition:pop class="dialog sh-dlg" aria-label="Войти в общую сферу" onsubmit={join}>
    <h2 class="sm">Войти в общую сферу</h2>
    <p class="sh-s">Тебя позвали по почте? Открой ссылку из письма Google — сфера появится сама через минуту. Или вставь код, который прислал владелец.</p>
    <div class="sh-code"><input bind:this={input} bind:value={code} placeholder="…@group.calendar.google.com" aria-label="Код сферы" autocomplete="off" spellcheck="false" /></div>
    {#if err}<p class="sh-err">{err}</p>{/if}
    <div class="sh-ft"><span class="sp"></span>
      <button class="sh-btn ghost" type="button" onclick={onclose}>Отмена</button>
      <button class="sh-btn pri" type="submit" disabled={busy || !code.trim()}>{busy ? 'Вхожу…' : 'Войти'}</button>
    </div>
  </form>
{:else if mode === 'make'}
  <div transition:pop class="dialog sh-dlg" role="dialog" aria-modal="true" aria-labelledby="sh-t">
    <h2 id="sh-t">{@render icon(30)}Сделать «{sphere?.name}» общей</h2>
    <p class="sh-s">Пригласи людей по почте Google — они увидят списки этой сферы в своём Спутнике и смогут брать задачи.</p>
    {@render field()}
    <p class="sh-lbl">Что увидят участники</p>
    <div class="sh-what">
      <div><b>Общее</b>{listNames.length ? `Списки сферы ${listNames.map((n) => `«${n}»`).join(' и ')}` : 'Списки этой сферы'}, задачи, этапы, исполнители, сроки, заметки.</div>
      <div><b>Только твоё</b>Другие сферы, привычки, календарь, напоминания и настройки — их никто не видит.</div>
    </div>
    <p class="sh-note">Задачи сферы переедут из Google Tasks в Спутник: в приложении Google Tasks и на телефоне их не будет. Напоминания останутся.</p>
    <div class="sh-ft"><span class="hint">Приглашение придёт письмом от Google и в Спутнике</span><span class="sp"></span>
      <button class="sh-btn ghost" type="button" disabled={busy} onclick={onclose}>Отмена</button>
      <button class="sh-btn pri" type="button" disabled={busy} onclick={send}>{busy ? 'Минутку…' : 'Сделать общей'}</button>
    </div>
  </div>
{:else}
  <div transition:pop class="dialog sh-dlg" role="dialog" aria-modal="true" aria-labelledby="sh-t">
    <h2 id="sh-t" class:sm={!owner}>{@render icon(owner ? 30 : 26)}{sphere?.name} <SharedTag /></h2>
    {#if owner}
      {@render field()}
      <p class="sh-lbl">Участники · {people.length}</p>
    {/if}
    <div class="sh-mem">
      {#if owner && mine}
        <div class="sh-mr"><Avatar m={preview ?? mine} size={34} me /><div class="tx"><b>Ты · {mine.name}</b><span>{me}</span></div><span class="sh-role own">★ Владелец</span>{@render editBtn()}</div>
      {:else if mine}
        <div class="sh-mr"><Avatar m={preview ?? mine} size={34} me /><div class="tx"><b>{mine.name} · ты</b><span>участник</span></div><span class="sh-role">Участник</span>{@render editBtn()}</div>
      {/if}
      {#if prof && mine}
        <div class="sh-prof">
          <p class="sh-lbl">Как тебя видят в общих сферах</p>
          <div class="sh-pr-row">
            <Avatar m={preview} size={48} me />
            <input class="sh-pr-name" bind:value={prof.name} maxlength={NAME_MAX} placeholder={nameOf(me)} aria-label="Имя" />
          </div>
          <div class="sh-pr-row">
            <span class="sh-pr-l">Цвет</span>
            {#each MEMBER_COLORS as c, i (c)}
              <button type="button" class="sh-sw" class:on={prof.color === i} style="--c: {c}" aria-label="Цвет {i + 1}" aria-pressed={prof.color === i} onclick={() => (prof = { ...prof, color: i })}></button>
            {/each}
          </div>
          <div class="sh-pr-row">
            <span class="sh-pr-l">Фото</span>
            <button type="button" class="sh-btn sm ghost" onclick={() => picIn?.click()}>{prof.pic ? 'Другое фото…' : 'Выбрать фото…'}</button>
            {#if prof.pic}<button type="button" class="sh-btn sm ghost" onclick={() => (prof = { ...prof, pic: null })}>Убрать фото</button>{/if}
            <input bind:this={picIn} type="file" accept="image/png,image/jpeg,image/webp" hidden onchange={pickPic} />
          </div>
          {#if err}<p class="sh-err">{err}</p>{/if}
          <p class="sh-note">Одно на все общие сферы. Участники увидят новое имя и кружок через минуту-две.</p>
          <div class="sh-ft"><span class="sp"></span>
            <button type="button" class="sh-btn sm ghost" disabled={busy} onclick={() => { prof = null; err = ''; }}>Отмена</button>
            <button type="button" class="sh-btn sm pri" disabled={busy} onclick={saveProf}>{busy ? 'Сохраняю…' : 'Сохранить'}</button>
          </div>
        </div>
      {/if}
      {#each others as p (p.email)}
        <div class="sh-mr">
          <Avatar m={p} size={34} />
          <div class="tx">
            <b>{p.joined ? p.name : p.email}</b>
            {#if p.owner}<span>{p.invited ? `пригласил ${seenText(p.invited).replace(/ в \d+:\d+$/, '')}` : 'владелец'}</span>
            {:else}<span class:w={!p.joined}>{owner ? subline(p) : p.joined ? 'участник' : 'ещё не принял приглашение'}</span>{/if}
          </div>
          <span class="sh-role" class:own={p.owner}>{p.owner ? '★ Владелец' : 'Участник'}</span>
          {#if owner && !p.owner}<button class="sh-btn sm ghost" type="button" disabled={busy} onclick={() => run(() => onremove(p))}>{p.joined ? 'Убрать' : 'Отозвать'}</button>{/if}
        </div>
      {/each}
    </div>
    {#if owner}
      <div class="sh-ft">
        <button class="sh-btn sm ghost" type="button" onclick={oncopy}>Скопировать ссылку-приглашение</button><span class="sp"></span>
        {#if others.length}<button class="sh-btn dng sm" type="button" disabled={busy} onclick={onstop}>Перестать делиться</button>{/if}
        <button class="sh-btn pri sm" type="button" onclick={onclose}>Готово</button>
      </div>
    {:else}
      <div class="sh-ft"><span class="hint">Приглашать может только владелец</span><span class="sp"></span>
        <button class="sh-btn dng sm" type="button" onclick={onleave}>Выйти из сферы</button>
      </div>
    {/if}
  </div>
{/if}
