<script>
  import { onDestroy } from 'svelte';
  import Brand from './Brand.svelte';
  import Coon from './Coon.svelte';
  import WinControls from './WinControls.svelte';
  import { auth, listLists, calendarsAll, isOffline } from './api.js';
  import { plural } from './habits.js';

  // Первый запуск: 1 ключ Google → 2 вход → 3 что показывать (только в первый раз) → готово.
  // firstRun = false — это повторный вход (например, токен истёк): после входа сразу в приложение.
  // hidden — что уже скрыто (когда шаг 3 открыт снова из приложения); oncancel — вернуться без изменений.
  let { status, firstRun = true, hidden = { lists: [], cals: [] }, onready, onerror, oncancel = null } = $props();

  let hasSecret = $state(false);
  let signedIn = $state(false);
  let busy = $state(false);
  let lists = $state(null); // [{ id, name, meta, on }]
  let cals = $state(null);
  let finished = $state(false);
  let offline = $state(''); // текст ошибки сети
  let retryTimer;

  $effect(() => { hasSecret = status?.has_secret ?? false; signedIn = status?.signed_in ?? false; });
  onDestroy(() => clearTimeout(retryTimer));

  const step = $derived(!hasSecret ? 1 : !signedIn ? 2 : 3);
  const title = $derived(finished ? 'Всё готово. Поехали!' : step === 1 ? 'Подключим Google' : step === 2 ? 'Войди в Google' : 'Что показывать в Спутнике?');
  const say = $derived(
    finished ? 'Ура, мы на орбите! Вот три штуки, которые пригодятся.'
    : step === 1 ? 'Привет! Я енот Спутника. Сначала нужен ключ Google — это один файл.'
    : step === 2 ? 'Откроется браузер. Если Google скажет «приложение не проверено» — это нормально: оно твоё.'
    : 'Отметь списки и календари, которые хочешь видеть. Поменять можно потом.');
  const cls = (n) => `step ${step === n && !finished ? 'cur' : step > n || finished ? 'done' : 'wait'}`;
  const num = (n) => `num ${step > n || finished ? 'ok' : step === n ? 'cur' : ''}`;

  async function pickFile(e) {
    const input = e.currentTarget;
    const file = input.files?.[0];
    if (!file) return;
    try {
      await auth.saveSecret(await file.text());
      hasSecret = true;
    } catch (err) {
      onerror(String(err));
    } finally {
      input.value = '';
    }
  }

  async function login() {
    busy = true;
    offline = '';
    try {
      await auth.login();
      signedIn = true;
      if (firstRun) await loadChoices();
      else onready(null);
    } catch (err) {
      if (isOffline(err)) offline = String(err);
      else onerror(String(err));
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
      lists = ls.map((l) => ({ id: l.id, name: l.title, meta: /(^|\s)привычки$/i.test(l.title) ? 'привычки' : 'список задач', on: !hidden.lists.includes(l.id) }));
      cals = cs.map((c) => ({ id: c.id, name: c.summaryOverride || c.summary, meta: c.primary ? 'основной' : /#contacts@/.test(c.id) ? 'дни рождения' : /#holiday@/.test(c.id) ? 'праздники' : 'календарь', on: c.selected !== false && !hidden.cals.includes(c.id) }));
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
            <label class="file sp-btn sp-btn-primary">
              <input type="file" accept=".json,application/json" onchange={pickFile} />
              Выбрать client_secret.json
            </label>
          {:else}
            <div class="sd">client_secret.json скопирован в настройки. Повторно не спросим.</div>
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
            <div class="row">
              <button class="sp-btn sp-btn-primary" type="button" onclick={login} disabled={busy}>{busy ? 'Жду вход в браузере…' : 'Открыть вход в браузере'}</button>
              {#if busy}<span class="spinner" aria-hidden="true"></span>{/if}
              <button class="sp-btn sp-btn-ghost" type="button" onclick={() => (hasSecret = false)}>Заменить ключ</button>
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
            {#each lists as l (l.id)}{@render tick(l)}{/each}
            <p class="grp">Календари</p>
            {#each cals as c (c.id)}{@render tick(c)}{/each}
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
