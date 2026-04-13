<script>
  // SliderInput — Range slider with displayed value
  //
  // Shiny equivalent: sliderInput(inputId, label, min, max, value, step)
  //
  // Divergence from Shiny: Shiny's sliderInput supports range selection
  // (two handles) via value = c(min, max). This component currently supports
  // single-value selection only. Range selection can be added as a separate
  // component (RangeSliderInput) if needed.
  //
  // Props:
  //   id    — unique identifier
  //   label — display label
  //   value — bind:value for two-way binding (number)
  //   min   — minimum value
  //   max   — maximum value
  //   step  — step increment (default 1)
  //   unit  — optional unit suffix displayed in pill badge (e.g. "kr")
  //   color — optional accent color for pill, thumb, and track fill

  let { id = '', label = '', value = $bindable(0), min = 0, max = 100, step = 1, unit = '', color = '' } = $props();

  let pct = $derived(((value - min) / (max - min)) * 100);
</script>

<div class="ambolt-slider-input" data-input-id={id}
     style:--slider-color={color || null}
     style:--slider-pct="{pct}%">
  <label for={id}>
    {label}
    {#if !unit}
      <span class="value-display">{value}</span>
    {/if}
  </label>
  {#if unit}
    <div class="pill-track">
      <div class="pill" style:left="{pct}%">{value}{unit}</div>
    </div>
  {/if}
  <input type="range" {id} bind:value={value} {min} {max} {step} />
</div>

<style>
  .ambolt-slider-input {
    margin-bottom: 0.75rem;
  }
  label {
    display: block;
    font-weight: var(--ambolt-slider-label-weight, 600);
    margin-bottom: 0;
    font-size: var(--ambolt-slider-label-size, 0.95rem);
    text-align: center;
  }
  .value-display {
    font-weight: 400;
    color: var(--slider-color, #4f46e5);
    margin-left: 0.25rem;
  }

  /* Pill badge above slider */
  .pill-track {
    position: relative;
    height: 1.6rem;
    margin-bottom: 0.15rem;
  }
  .pill {
    position: absolute;
    transform: translateX(-50%);
    background: var(--slider-color, #4f46e5);
    color: white;
    font-size: var(--ambolt-slider-pill-size, 0.75rem);
    font-weight: 600;
    padding: var(--ambolt-slider-pill-padding, 0.1rem 0.4rem);
    border-radius: var(--ambolt-slider-pill-radius, 3px);
    white-space: nowrap;
    line-height: 1.3;
  }

  /* Range input — filled bar can be thicker than unfilled track via
     --ambolt-slider-bar-height (defaults to same as track height) */
  input[type="range"] {
    -webkit-appearance: none;
    appearance: none;
    width: 100%;
    height: var(--ambolt-slider-track-height, 4px);
    border-radius: 2px;
    outline: none;
    cursor: pointer;
    background-color: var(--ambolt-slider-track-bg, #d1d5db);
    background-image: linear-gradient(var(--slider-color, #4f46e5), var(--slider-color, #4f46e5));
    background-size: var(--slider-pct, 50%) var(--ambolt-slider-bar-height, var(--ambolt-slider-track-height, 4px));
    background-repeat: no-repeat;
    background-position: left center;
  }

  /* Thumb — WebKit */
  input[type="range"]::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: var(--ambolt-slider-thumb-size, 20px);
    height: var(--ambolt-slider-thumb-size, 20px);
    border-radius: 50%;
    background: var(--slider-color, #4f46e5);
    border: none;
    cursor: pointer;
    transition: box-shadow 0.15s;
  }
  input[type="range"]:active::-webkit-slider-thumb {
    box-shadow: 0 0 0 6px color-mix(in srgb, var(--slider-color, #4f46e5) 25%, transparent);
  }

  /* Thumb — Firefox */
  input[type="range"]::-moz-range-thumb {
    width: var(--ambolt-slider-thumb-size, 20px);
    height: var(--ambolt-slider-thumb-size, 20px);
    border-radius: 50%;
    background: var(--slider-color, #4f46e5);
    border: none;
    cursor: pointer;
    transition: box-shadow 0.15s;
  }
  input[type="range"]:active::-moz-range-thumb {
    box-shadow: 0 0 0 6px color-mix(in srgb, var(--slider-color, #4f46e5) 25%, transparent);
  }

  /* Firefox track fill */
  input[type="range"]::-moz-range-progress {
    background: var(--slider-color, #4f46e5);
    height: var(--ambolt-slider-track-height, 4px);
    border-radius: 2px;
  }
  input[type="range"]::-moz-range-track {
    background: var(--ambolt-slider-track-bg, #d1d5db);
    height: var(--ambolt-slider-track-height, 4px);
    border-radius: 2px;
  }
</style>
