<script>
  // Картинка задачи крупно, поверх всего. Esc, клик или «×» — закрыть.
  let { src, title = '', onclose } = $props();
  // Окно — прямо в <body>: внутри раскрытой строки Конвейера position: fixed считался бы от неё.
  const portal = (node) => { document.body.appendChild(node); return { destroy: () => node.remove() }; };
  function key(e) {
    if (e.key !== 'Escape') return;
    e.preventDefault();
    e.stopPropagation();
    onclose();
  }
</script>

<svelte:window onkeydowncapture={key} />

<!-- svelte-ignore a11y_click_events_have_key_events -->
<div class="pvw" role="dialog" aria-modal="true" aria-label="Картинка: {title}" tabindex="-1" use:portal onclick={onclose}>
  <img {src} alt={title} />
  <p>{title}<span>Esc — закрыть</span></p>
  <button type="button" class="pvw-x" aria-label="Закрыть" onclick={onclose}>×</button>
</div>
