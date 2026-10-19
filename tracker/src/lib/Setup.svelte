<script>
  import Brand from './Brand.svelte';
  import { auth } from './api.js';

  let { status, onready, onerror } = $props();
  let busy = $state(false);
  let hasSecret = $state(false);

  $effect(() => { hasSecret = status?.has_secret ?? false; });

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
    try {
      await auth.login();
      onready();
    } catch (err) {
      onerror(String(err));
    } finally {
      busy = false;
    }
  }
</script>

<div class="setup">
  <div class="card">
    <Brand size={28} />
    {#if !hasSecret}
      <h1>Подключим Google</h1>
      <p>Спутнику нужен ключ приложения из Google Cloud — файл <b>client_secret.json</b>. Он остаётся только на этом компьютере.</p>
      <ol>
        <li>Google Cloud → проект Sputnik → Clients.</li>
        <li>Клиент типа Desktop app → Download JSON.</li>
        <li>Выберите скачанный файл ниже.</li>
      </ol>
      <label class="file sp-btn sp-btn-primary">
        <input type="file" accept=".json,application/json" onchange={pickFile} />
        Выбрать client_secret.json
      </label>
    {:else}
      <h1>Войдите в Google</h1>
      <p>Откроется браузер. Если Google предупредит, что приложение не проверено, нажмите «Дополнительно» → «Перейти к Sputnik».</p>
      <div style="display: flex; align-items: center; gap: 12px">
        <button class="sp-btn sp-btn-primary" type="button" onclick={login} disabled={busy}>
          {busy ? 'Жду вход в браузере…' : 'Войти через Google'}
        </button>
        {#if busy}<span class="spinner" aria-hidden="true"></span>{/if}
      </div>
      <button class="sp-btn sp-btn-ghost" type="button" style="align-self: flex-start" onclick={() => (hasSecret = false)}>Заменить ключ</button>
    {/if}
  </div>
</div>
