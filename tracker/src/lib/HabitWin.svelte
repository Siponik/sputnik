<script>
  // Окно привычки «с 06:00» «до 12:00» (habits[id].win): поля-время, принимают «7», «730», «7.30»; «до» может быть 24:00.
  // Окно, Создать и панель привычки — один и тот же вид. onchange({ s, e }) — только когда окно целое (конец позже начала).
  import { normTime, cleanWin } from './habits.js';

  let { win = null, onchange } = $props();

  let s = $state(win?.s ?? '');
  let e = $state(win?.e ?? '');
  // окно поменяли снаружи (выбрали часть дня) — поля следуют
  $effect(() => { s = win?.s ?? ''; e = win?.e ?? ''; });
  const bad = $derived(!cleanWin({ s: normTime(s) ?? s, e: normTime(e, true) ?? e }));

  function commit() {
    const ns = normTime(s) ?? s, ne = normTime(e, true) ?? e;
    s = ns; e = ne;
    const w = cleanWin({ s: ns, e: ne });
    if (w && (w.s !== win?.s || w.e !== win?.e)) onchange(w);
  }
  const key = (ev) => { if (ev.key === 'Enter') commit(); }; // Enter дальше сохраняет окно — окно уже обновлено
</script>

<span class="hw" class:bad>
  <label><span>с</span><input bind:value={s} inputmode="numeric" maxlength="5" aria-label="С" onblur={commit} onkeydown={key} /></label>
  <label><span>до</span><input bind:value={e} inputmode="numeric" maxlength="5" aria-label="До" onblur={commit} onkeydown={key} /></label>
</span>
