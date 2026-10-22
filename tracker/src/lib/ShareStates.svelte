<script>
  // Состояния общей сферы (docs/design-v2.md, «Общие сферы» 6; макет design/screens/ShareStates.dc.html).
  // kind: 'invite' — плашка «X зовёт тебя в сферу» (Принять / Отказаться), 'unseen' — «Аня ещё не видит N изменений»,
  // 'lost' — экран «Нет доступа к сфере» (Попросить доступ / Убрать из колонки).
  import Coon from './Coon.svelte';
  import { plural } from './habits.js';
  let { kind, invite = null, unseen = null, sphere = '', onaccept, ondecline, onask, onforget } = $props();
  let busy = $state(false);
  async function run(fn) { if (busy) return; busy = true; try { await fn(); } finally { busy = false; } }
</script>

{#if kind === 'invite'}
  <div class="sh-st inv" role="region" aria-label="Приглашение в сферу «{invite.name}»">
    <Coon pose="hi" size={64} />
    <div class="tx">
      <b>{invite.owner?.name ?? 'Участник'} зовёт тебя в сферу «{invite.name}»</b>
      <span>{invite.lists} {plural(invite.lists, ['список', 'списка', 'списков'])} · {invite.tasks} {plural(invite.tasks, ['задача', 'задачи', 'задач'])}{invite.people.length ? ` · участники: ${invite.people.map((p) => p.name).join(', ')}` : ''}</span>
    </div>
    <div class="bt">
      <button type="button" class="sh-btn pri sm" disabled={busy} onclick={() => run(onaccept)}>{busy ? 'Минутку…' : 'Принять'}</button>
      <button type="button" class="sh-btn ghost sm" disabled={busy} onclick={() => run(ondecline)}>Отказаться</button>
    </div>
  </div>
{:else if kind === 'unseen'}
  <div class="sh-st uns" role="status">
    <Coon pose="think" size={40} />
    <p><b>{unseen.m.name} ещё не видит {unseen.n} {plural(unseen.n, ['изменение', 'изменения', 'изменений'])}.</b> Они дойдут, когда Спутник участника обменяется со сферой (обычно до 2 минут; если компьютер выключен — при запуске).</p>
  </div>
{:else if kind === 'lost'}
  <div class="page sh-lost">
    <Coon pose="oops" size={120} />
    <h2>Нет доступа к сфере «{sphere}»</h2>
    <p>Владелец перестал делиться сферой или убрал тебя из участников. Твои отметки и заметки по этим задачам сохранились на этом компьютере.</p>
    <div class="bt">
      <button type="button" class="sh-btn" onclick={onask}>Попросить доступ</button>
      <button type="button" class="sh-btn pri" disabled={busy} onclick={() => run(onforget)}>Убрать из колонки</button>
    </div>
    <small>«Попросить доступ» копирует письмо владельцу</small>
  </div>
{/if}
