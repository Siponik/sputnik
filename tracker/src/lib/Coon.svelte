<script module>
  // Енот-космонавт (белый винил). Разметка — готовые SVG из design/mascot, анимации — styles/coon.css.
  import hi from '../../../design/mascot/coon-hi.svg?raw';
  import cheer from '../../../design/mascot/coon-cheer.svg?raw';
  import flag from '../../../design/mascot/coon-flag.svg?raw';
  import think from '../../../design/mascot/coon-think.svg?raw';
  import sleep from '../../../design/mascot/coon-sleep.svg?raw';
  import oops from '../../../design/mascot/coon-oops.svg?raw';
  import face from '../../../design/mascot/coon-face.svg?raw';

  const POSES = { hi, cheer, flag, think, sleep, oops, face };
  export const NAMES = {
    hi: 'Енот машет лапой', cheer: 'Енот радуется', flag: 'Енот с флажком', think: 'Енот думает',
    sleep: 'Енот дремлет', oops: 'Енот растерян', face: 'Енот-космонавт',
  };
  let seq = 0;

  // Стиль из SVG выкидываем (он общий, в coon.css); id градиентов делаем своими для каждого енота,
  // иначе несколько енотов на экране ломают друг другу заливку.
  function prep(svg, n, label) {
    return svg
      .replace(/<style>[\s\S]*?<\/style>/, '')
      .replace(/\bcn\d+-/g, `cn${n}-`)
      // размер — только у корневого <svg>: у деталей (нашивка «С» и т. п.) его не трогаем
      .replace(/<svg\b[^>]*>/, (tag) => tag.replace(/\s(width|height)="\d+"/g, ''))
      .replace(/aria-label="[^"]*"/, `aria-label="${label.replace(/"/g, '&quot;')}"`);
  }
</script>

<script>
  let { pose = 'hi', size = 112, label = '' } = $props();
  const n = ++seq;
  const svg = $derived(prep(POSES[pose] ?? hi, n, label || NAMES[pose] || NAMES.hi));
  // Сон и значок шире или ниже обычного кадра 240×260 — держим тот же масштаб по высоте.
  const ratio = $derived(pose === 'sleep' ? 250 / 260 : pose === 'face' ? 180 / 186 : 240 / 260);
</script>

<span class="coon-host" style="width: {size}px; height: {Math.round(size / ratio)}px">{@html svg}</span>
