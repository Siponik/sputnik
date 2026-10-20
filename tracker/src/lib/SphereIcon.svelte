<script>
  // Плитка значка сферы: штриховой значок цветом сферы на 16 % того же цвета.
  import { iconPath, iconStyle } from './spheres.js';
  let { sphere, size = 26 } = $props();
</script>

<span class="sph-ico" style="{iconStyle(sphere)}; width: {size}px; height: {size}px; border-radius: {Math.round(size * 0.3)}px" aria-hidden="true">
  <svg viewBox="0 0 24 24" style="width: {Math.round(size * 0.58)}px; height: {Math.round(size * 0.58)}px"><path d={iconPath(sphere)} /></svg>
</span>
