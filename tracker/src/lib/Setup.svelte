<script>
  import { onDestroy } from 'svelte';
  import Brand from './Brand.svelte';
  import Coon from './Coon.svelte';
  import WinControls from './WinControls.svelte';
  import { auth, listLists, calendarsAll, isOffline } from './api.js';
  import { plural } from './habits.js';
  import { checkSecretText, isStopped, isScopeLack, loginHint, calDefaultOn } from './authcheck.js';
  import { say as toast } from '../stores/toast.svelte.js';

  // Первый запуск: 1 ключ Google → 2 вход → 3 что показывать (только в первый раз) → готово.
  // firstRun = false — это повторный вход (например, токен истёк): после входа сразу в приложение.
  // hidden — что уже скрыто (когда шаг 3 открыт снова из приложения); oncancel — вернуться без изменений.
  // why — почему снова просим вход (ошибка синхронизации), покажем, если это про доступы.
  let { status, firstRun = true, hidden = null, why = '', onready, onerror = toast, oncancel = null } = $props();

  let hasSecret = $state(false);
  let builtIn = $state(false); // общий ключ встроен в сборку и своего файла нет — свой файл не нужен
  let builtInOk = $state(false); // общий ключ в сборке есть (к нему можно вернуться со своего файла)
  let err = $state(''); // что пошло не так на текущем шаге — показываем прямо в шаге, можно попробовать снова
  let signedIn = $state(false);
  let busy = $state(false);
  let lists = $state(null); // [{ id, name, meta, on }]
  let cals = $state(null);
  let finished = $state(false);
  let offline = $state(''); // текст ошибки сети
  let retryTimer;

  $effect(() => {
    hasSecret = status?.has_secret ?? false;
    signedIn = status?.signed_in ?? false;
    builtIn = status?.built_in ?? false;
    builtInOk = status?.built_in_ok ?? builtIn;
    const lack = status?.missing ?? [];
    if (!signedIn && lack.length) err = loginHint(`Google не дал доступ — ${lack.join(', ')}.`);
    else if (!signedIn && isScopeLack(why)) err = loginHint(why);
  });
  onDestroy(() => clearTimeout(retryTimer));

  const step = $derived(!hasSecret ? 1 : !signedIn ? 2 : 3);
  const title = $derived(finished ? 'Всё готово. Поехали!' : step === 1 ? 'Подключим Google' : step === 2 ? 'Войди в Google' : 'Что показывать в Спутнике?');
  const say = $derived(
    finished ? 'Ура, мы на орбите! Вот три штуки, которые пригодятся.'
    : step === 1 ? 'Привет! Я енот Спутника. Сначала нужен ключ Google — это один файл.'
    : step === 2 ? 'Откроется браузер. Если Google скажет «приложение не проверено» — это нормально: Спутник ещё не прошёл проверку Google.'
    : 'Отметь списки и календари, которые хочешь видеть. Поменять можно потом.');
  const cls = (n) => `step ${step === n && !finished ? 'cur' : step > n || finished ? 'done' : 'wait'}`;
  const num = (n) => `num ${step > n || finished ? 'ok' : step === n ? 'cur' : ''}`;

  // Файл проверяем до отправки: не тот JSON — сразу говорим, что не так, и можно выбрать другой.
  async function pickFile(e) {
    const input = e.currentTarget;
    const file = input.files?.[0];
    if (!file) return;
    err = '';
    try {
      const text = file.size > 64 * 1024 ? '' : await file.text();
      const bad = checkSecretText(text, file.size);
      if (bad) { err = bad; return; }
      await auth.saveSecret(text);
      hasSecret = true;
      builtIn = false;
      signedIn = false;
    } catch (e2) {
      err = String(e2).replace(/^Error:\s*/, '') || 'Не получилось прочитать файл — выбери его ещё раз.';
    } finally {
      input.value = '';
    }
  }

  // Свой ключ не подошёл — возвращаемся к встроенному.
  async function useBuiltIn() {
    err = '';
    try {
      await auth.forgetSecret();
      busy = false;
      hasSecret = true;
      builtIn = true;
      signedIn = false;
    } catch (e2) { err = String(e2); }
  }

  // «Заменить ключ»: если вход ещё ждёт браузер — останавливаем его.
  function replaceKey() {
    if (busy) auth.cancel().catch(() => {});
    busy = false;
    err = '';
    hasSecret = false;
  }

  function cancelLogin() {
    auth.cancel().catch(() => {});
    busy = false;
  }

  async function login() {
    busy = true;
    offline = '';
    err = '';
    try {
      await auth.login();
      signedIn = true;
      if (firstRun) await loadChoices();
      else onready(null);
    } catch (e2) {
      if (isStopped(e2)) return;
      if (isOffline(e2)) offline = String(e2);
      else err = loginHint(e2);
    } finally {
      busy = false;
    }
  }

  // Шаг 3: списки Google Tasks и календари галочками.
  async function loadChoices() {
    clearTimeout(retryTimer);
    offline = '';
    try {
      const [ls, cs] = await Promise.all([listLists(), calendarsAll()]);
      lists = ls.map((l) => ({ id: l.id, name: l.title, meta: /(^|\s)привычки$/i.test(l.title) ? 'привычки' : 'список задач', on: !hidden?.lists.includes(l.id) }));
      cals = cs.map((c) => ({ id: c.id, name: c.summaryOverride || c.summary, meta: c.primary ? 'основной' : /#contacts@/.test(c.id) ? 'дни рождения' : /#holiday@/.test(c.id) ? 'праздники' : 'календарь', on: hidden ? !hidden.cals.includes(c.id) : calDefaultOn(c) }));
    } catch (err) {
      if (!isOffline(err)) { onerror(String(err)); return; }
      offline = String(err);
      retryTimer = setTimeout(loadChoices, 60e3); // «попробую снова через минуту»
    }
  }
  // Пришли сюда уже со входом (ключ и токен есть), но выбор ещё не сделан.
  $effect(() => { if (step === 3 && firstRun && !lists && !offline && !busy) loadChoices(); });

  function retry() { if (step === 3) loadChoices(); else login(); }

  function finish() {
    finished = true;
  }
  function go() {
    onready({
      lists: lists.map((l) => [l.id, !l.on]),
      cals: cals.map((c) => [c.id, !c.on]),
    });
  }
</script>

{#snippet tick(item)}
  <div class="lst">
    <button type="button" class="tick" aria-pressed={item.on} aria-label={item.name} onclick={() => (item.on = !item.on)}>
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
    </button>
    <span class="nm">{item.name}</span><span class="mt">{item.meta}</span>
  </div>
{/snippet}

<div class="setup2">
  <header data-tauri-drag-region>
    <Brand size={26} />
    {#if oncancel}<button class="sp-btn sp-btn-ghost" type="button" style="margin-left: auto; min-height: 30px" onclick={oncancel}>Назад к Спутнику</button>{/if}
    <WinControls />
  </header>

  <main>
    <section class="steps">
      <div>
        <p class="pre">Первый запуск · шаг {Math.min(step, 3)} из 3</p>
        <h1>{title}</h1>
      </div>

      <div class={cls(1)}>
        <span class={num(1)}>1</span>
        <div class="sbody">
          <div class="st">Ключ Google</div>
          {#if step === 1}
            <div class="sd">Спутнику нужен ключ приложения из Google Cloud — файл <b>client_secret.json</b>. Он остаётся только на этом компьютере.</div>
            <ol>
              <li>Google Cloud → проект Sputnik → Clients.</li>
              <li>Клиент типа Desktop app → Download JSON.</li>
              <li>Выбери скачанный файл ниже.</li>
            </ol>
            {#if err}<div class="sd err" role="alert">{err}</div>{/if}
            <div class="row">
              <label class="file sp-btn sp-btn-primary">
                <input type="file" accept=".json,application/json" onchange={pickFile} />
                {err ? 'Выбрать другой файл' : 'Выбрать client_secret.json'}
              </label>
              {#if builtInOk}<button class="sp-btn sp-btn-ghost" type="button" onclick={useBuiltIn}>Вернуть встроенный ключ</button>{/if}
            </div>
          {:else}
            <div class="sd">{builtIn ? 'Ключ уже встроен в Спутник — ничего делать не нужно.' : 'client_secret.json скопирован в настройки. Повторно не спросим.'}</div>
          {/if}
        </div>
      </div>

      <div class={cls(2)}>
        <span class={num(2)}>2</span>
        <div class="sbody">
          <div class="st">Вход в Google</div>
          {#if step === 2}
            <div class="sd">Откроется браузер. Если Google предупредит, что приложение не проверено, нажми «Дополнительно» → «Перейти к Sputnik».</div>
            <ul class="perm" aria-label="Какие доступы попросит Google">
              <li><span class="ok">●</span><span><b>Задачи</b> — читать и создавать: это и есть доска.</span></li>
              <li><span class="ok">●</span><span><b>Календарь</b> — события, дни рождения, свободные окна.</span></li>
              <li><span class="ok">●</span><span><b>Drive</b> — только собственные файлы Спутника и его скрытая папка (так доска и привычки совпадают на всех компьютерах), остальное не видно.</span></li>
              <li><span class="no">●</span><span>Своего сервера нет: всё хранится у тебя и в твоём Google.</span></li>
            </ul>
            <div class="sd">На странице Google отметь <b>все галочки</b> — без любой из них Спутник не заработает.</div>
            {#if err}<div class="sd err" role="alert">{err}</div>{/if}
            <div class="row">
              <button class="sp-btn sp-btn-primary" type="button" onclick={login} disabled={busy}>{busy ? 'Жду вход в браузере…' : err ? 'Открыть вход ещё раз' : 'Открыть вход в браузере'}</button>
              {#if busy}
                <span class="spinner" aria-hidden="true"></span>
                <button class="sp-btn sp-btn-ghost" type="button" onclick={cancelLogin}>Отмена</button>
              {/if}
              <button class="sp-btn sp-btn-ghost" type="button" onclick={replaceKey}>{builtIn ? 'Свой ключ' : 'Заменить ключ'}</button>
              {#if !builtIn && builtInOk}<button class="sp-btn sp-btn-ghost" type="button" onclick={useBuiltIn}>Встроенный ключ</button>{/if}
            </div>
          {:else if step > 2}
            <div class="sd">Готово — ты вошёл.</div>
          {:else}
            <div class="sd">Откроется браузер, Google спросит доступы — объясню какие.</div>
          {/if}
        </div>
      </div>

      <div class={cls(3)}>
        <span class={num(3)}>3</span>
        <div class="sbody">
          <div class="st">Что показывать</div>
          {#if step === 3 && !finished && lists}
            <p class="grp">Списки Google Tasks</p>
            <div class="picks">{#each lists as l (l.id)}{@render tick(l)}{/each}</div>
            <p class="grp">Календари</p>
            {#if !hidden}<div class="sd">Сразу включены основной календарь и праздники — остальные отметь сам.</div>{/if}
            <div class="picks">{#each cals as c (c.id)}{@render tick(c)}{/each}</div>
            <button class="sp-btn sp-btn-primary" type="button" style="margin-top: 10px" disabled={!lists.some((l) => l.on)} onclick={finish}>Поехали</button>
          {:else if step === 3 && !finished && !offline}
            <div class="sd"><span class="spinner" aria-hidden="true"></span> Загружаю списки и календари…</div>
          {:else if finished}
            {@const nl = lists.filter((l) => l.on).length}
            {@const nc = cals.filter((c) => c.on).length}
            <div class="sd">Показываю {nl} {plural(nl, ['список', 'списка', 'списков'])} и {nc} {plural(nc, ['календарь', 'календаря', 'календарей'])}.</div>
          {:else}
            <div class="sd">Списки задач и календари — выберешь после входа.</div>
          {/if}
        </div>
      </div>
    </section>

    <aside class="side-coon">
      {#if offline}
        <p class="bubble err" role="alert">Не достучался до Google — похоже, нет интернета. {step === 3 ? 'Попробую снова через минуту, ничего не потеряется.' : 'Проверь связь и попробуй ещё раз.'}</p>
        <Coon pose="oops" size={220} />
        <button class="sp-btn" type="button" onclick={retry}>Повторить сейчас</button>
      {:else}
        <p class="bubble" aria-live="polite">{say}</p>
        <Coon pose={finished ? 'cheer' : 'hi'} size={220} />
        {#if finished}
          <div class="tips">
            <div class="stip"><span class="kbd">Ctrl+N</span>Новая задача из любого экрана</div>
            <div class="stip"><span class="kbd">чат</span>«Запиши в Спутник…» — из любого чата Claude</div>
            <div class="stip"><span class="kbd">7:45</span>Утренняя сводка в Telegram по будням</div>
          </div>
          <button class="sp-btn sp-btn-primary" type="button" onclick={go}>Открыть Спутник</button>
        {/if}
      {/if}
    </aside>
  </main>
</div>
