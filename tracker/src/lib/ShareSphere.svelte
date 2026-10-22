<script>
  import { fade, pop } from './motion.js';
  import * as shared from './shared.js';

  // Окно общей сферы. mode 'people' — участники (владелец зовёт по почте и убирает), 'join' — войти по коду.
  // Пока простое: окончательный вид — по макету (docs/shared-sphere.md, «Какие макеты нужны»).
  let { mode = 'people', sphere = null, cal = '', onjoin, onclose, say } = $props();

  const owner = $derived(cal ? shared.isOwner(cal) : false);
  const ownerMail = $derived(cal ? shared.sphereRec(cal)?.f?.owner ?? '' : '');
  let people = $state(null); // null — ещё не загрузили
  let email = $state('');
  let code = $state('');
  let busy = $state(false);
  let err = $state('');

  async function load() {
    if (!owner) return;
    try { people = await shared.members(cal); err = ''; }
    catch (e) { people = []; err = 'Не удалось получить участников: ' + e; }
  }
  $effect(() => { if (mode === 'people' && cal) load(); });

  const okMail = (s) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s.trim());

  async function add(e) {
    e.preventDefault();
    if (!okMail(email) || busy) return;
    busy = true;
    try { await shared.invite(cal, email); say?.(`Позвали ${email.trim()} — Google пришлёт письмо`); email = ''; await load(); }
    catch (e2) { err = 'Не удалось позвать: ' + e2; }
    finally { busy = false; }
  }
  async function drop(p) {
    busy = true;
    try { await shared.removeMember(cal, p.id); await load(); }
    catch (e) { err = 'Не удалось убрать: ' + e; }
    finally { busy = false; }
  }
  async function copy() {
    try { await navigator.clipboard.writeText(cal); say?.('Код скопирован'); } catch { say?.('Не удалось скопировать — выдели код и нажми Ctrl+C'); }
  }
  async function join(e) {
    e.preventDefault();
    if (!code.trim() || busy) return;
    busy = true;
    try { await onjoin(code.trim()); } finally { busy = false; }
  }
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && !busy && onclose()} />

<button class="drawer-back" type="button" aria-label="Закрыть" onclick={() => !busy && onclose()} transition:fade={{ duration: 180 }}></button>
{#if mode === 'join'}
  <form transition:pop class="dialog shr" aria-label="Войти в общую сферу" onsubmit={join}>
    <h2>Войти в общую сферу</h2>
    <p class="hint">Владелец сферы позвал тебя по почте и прислал код? Вставь его сюда. Если ты уже открыл ссылку из письма Google, сфера появится сама через минуту.</p>
    <div class="field">
      <label for="shr-code">Код сферы</label>
      <input id="shr-code" bind:value={code} placeholder="…@group.calendar.google.com" autocomplete="off" spellcheck="false" />
    </div>
    <div class="actions">
      <button class="sp-btn sp-btn-ghost" type="button" onclick={onclose}>Отмена</button>
      <button class="sp-btn sp-btn-primary" type="submit" disabled={busy || !code.trim()}>{busy ? 'Вхожу…' : 'Войти'}</button>
    </div>
  </form>
{:else}
  <div transition:pop class="dialog shr" role="dialog" aria-modal="true" aria-label="Участники сферы">
    <h2>Участники · {sphere?.name ?? ''}</h2>
    {#if owner}
      <form class="shr-add" onsubmit={add}>
        <input type="email" bind:value={email} placeholder="Почта Google человека" aria-label="Почта" autocomplete="off" />
        <button class="sp-btn sp-btn-primary" type="submit" disabled={busy || !okMail(email)}>Позвать</button>
      </form>
      <ul class="shr-list">
        <li><span class="shr-who">{shared.myEmail() || 'Ты'}</span><span class="shr-role">владелец</span></li>
        {#if people === null}<li class="hint">Загружаю…</li>{/if}
        {#each people ?? [] as p (p.id)}
          <li><span class="shr-who">{p.email}</span><span class="shr-role">{p.role === 'reader' ? 'только смотрит' : 'участник'}</span>
            <button class="sp-btn sp-btn-ghost shr-x" type="button" disabled={busy} onclick={() => drop(p)}>Убрать</button></li>
        {/each}
      </ul>
      <p class="hint">Google пришлёт человеку письмо со ссылкой. Если письмо потерялось — отправь ему код, он вставит его в «＋ → Войти в общую сферу». У него тоже должен стоять Спутник.</p>
      <div class="shr-code"><code>{cal}</code><button class="sp-btn sp-btn-ghost" type="button" onclick={copy}>Скопировать код</button></div>
    {:else}
      <ul class="shr-list">
        {#if ownerMail}<li><span class="shr-who">{ownerMail}</span><span class="shr-role">владелец</span></li>{/if}
        <li><span class="shr-who">{shared.myEmail() || 'Ты'}</span><span class="shr-role">участник</span></li>
      </ul>
      <p class="hint">Звать и убирать людей может только владелец сферы.</p>
    {/if}
    {#if err}<p class="shr-err">{err}</p>{/if}
    <div class="actions">
      <button class="sp-btn sp-btn-ghost" type="button" onclick={onclose}>Готово</button>
    </div>
  </div>
{/if}
