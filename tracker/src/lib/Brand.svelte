<script>
  let { size = 26 } = $props();
</script>

<span class="sp-brand" style="font-size: {Math.round(size * 0.66)}px; line-height: {size}px">
  <svg viewBox="0 0 512 512" aria-hidden="true" style="width: {size}px; height: {size}px">
    <path class="arc" d="M370.9 159.6 A150 150 0 1 0 370.9 352.4" />
    <circle class="core" cx="256" cy="256" r="62" />
    <circle class="sat" cx="370.9" cy="159.6" r="42" />
  </svg>
  Спутник
</span>
