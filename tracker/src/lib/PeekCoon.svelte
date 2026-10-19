<script module>
  // Скетч-енот для пустых колонок доски (design/mascot/peek, правила — docs/design-v2.md, «Пустые колонки»).
  // Плоский, одним цветом (currentColor), «дырки» — var(--bg). Анимации — design/mascot/peek/peek.css.
  import bottom from '../../../design/mascot/peek/peek-bottom.svg?raw';
  import side from '../../../design/mascot/peek/peek-side.svg?raw';
  import tail from '../../../design/mascot/peek/tail.svg?raw';

  const SPRITES = { bottom, side, tail };
  let seq = 0;
  // id фильтра и штриховки свои у каждого енота, иначе один ломает другого.
  // Размер убираем только у корневого <svg> — у маски и штриховки внутри он нужен.
  const prep = (svg, n) => svg.replace(/PKID/g, `pk${n}`).replace(/<svg\b[^>]*>/, (tag) => tag.replace(/\s(width|height)="\d+"/g, ''));

  const hash = (s) => { let h = 2166136261; for (const ch of s) { h ^= ch.codePointAt(0); h = Math.imul(h, 16777619); } return h >>> 0; };

  /** Вариант енота для колонки: где сидит, у какого края и насколько сдвинут. Один и тот же для одной колонки,
   *  разный у соседних. place — по номеру колонки (чередуются), край и сдвиг — по ключу колонки. */
  export function peekVariant(key, index) {
    const place = ['bottom', 'side', 'tail'][index % 3];
    const h = hash(key);
    const pick = (arr, shift) => arr[(h >>> shift) % arr.length];
    if (place === 'bottom') return { place, edge: pick(['bottom', 'top'], 0), pos: pick([28, 50, 70, 38, 62], 3) }; // % вдоль края
    if (place === 'side') return { place, edge: pick(['right', 'left'], 0), pos: pick([34, 50, 66, 42, 58], 3) };  // % по высоте
    return { place, edge: pick(['left', 'right'], 0), pos: pick([26, 44, 60], 3) };                                // px от края
  }
</script>

<script>
  /** place: bottom — выглядывает (снизу или сверху), side — подглядывает (слева или справа), tail — хвост сверху.
   *  edge — край, pos — сдвиг вдоль края (см. peekVariant). */
  let { place = 'bottom', edge = '', pos = 50 } = $props();
  const n = ++seq;
  const svg = $derived(prep(SPRITES[place] ?? bottom, n));
  const style = $derived(
    place === 'bottom' ? `left: ${pos}%` :
    place === 'side' ? `top: ${pos}%` :
    edge === 'right' ? `right: ${pos}px` : `left: ${pos}px`);
</script>

<span class="peek peek-{place} on-{edge || (place === 'bottom' ? 'bottom' : place === 'side' ? 'right' : 'left')}" {style} aria-hidden="true">{@html svg}</span>
