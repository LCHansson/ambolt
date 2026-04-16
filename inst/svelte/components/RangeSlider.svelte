<script>
  // RangeSlider — Two-handle numeric range slider
  //
  // Bound value is a length-2 array: [from, to]. Both handles are draggable
  // and constrained so from <= to. Designed for time periods but works for
  // any numeric range.
  //
  // Props:
  //   id          — field id
  //   label       — display label above the slider
  //   value       — bindable [from, to] array
  //   min, max    — overall range bounds
  //   step        — step size (default 1)

  let {
    id = '',
    label = '',
    value = $bindable([0, 100]),
    min = 0,
    max = 100,
    step = 1
  } = $props();

  let trackEl;
  let dragging = $state(null);  // 'from' | 'to' | null

  // Ensure value is always a valid [from, to] tuple within bounds
  function clamp(v) {
    return Math.max(min, Math.min(max, v));
  }
  function snap(v) {
    return Math.round((v - min) / step) * step + min;
  }

  let from = $derived(value?.[0] ?? min);
  let to = $derived(value?.[1] ?? max);

  function pctFor(v) {
    return ((v - min) / (max - min)) * 100;
  }

  function valueAtClientX(clientX) {
    if (!trackEl) return min;
    const rect = trackEl.getBoundingClientRect();
    const pct = (clientX - rect.left) / rect.width;
    const raw = min + pct * (max - min);
    return clamp(snap(raw));
  }

  function onPointerDown(handle, evt) {
    dragging = handle;
    evt.preventDefault();
    document.addEventListener('pointermove', onPointerMove);
    document.addEventListener('pointerup', onPointerUp);
  }

  function onPointerMove(evt) {
    if (!dragging) return;
    const v = valueAtClientX(evt.clientX);
    if (dragging === 'from') {
      value = [Math.min(v, to), to];
    } else {
      value = [from, Math.max(v, from)];
    }
  }

  function onPointerUp() {
    dragging = null;
    document.removeEventListener('pointermove', onPointerMove);
    document.removeEventListener('pointerup', onPointerUp);
  }

  // Click on track: move nearest handle to that point
  function onTrackClick(evt) {
    const v = valueAtClientX(evt.clientX);
    const distFrom = Math.abs(v - from);
    const distTo = Math.abs(v - to);
    if (distFrom <= distTo) {
      value = [Math.min(v, to), to];
    } else {
      value = [from, Math.max(v, from)];
    }
  }
</script>

<div class="range-slider" {id}>
  {#if label}
    <div class="range-slider-label">
      {label}: <strong>{from} – {to}</strong>
    </div>
  {/if}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div class="range-slider-track" bind:this={trackEl} onclick={onTrackClick}>
    <div class="range-slider-rail"></div>
    <div class="range-slider-fill"
         style:left="{pctFor(from)}%"
         style:width="{pctFor(to) - pctFor(from)}%"></div>
    <div class="range-slider-handle"
         style:left="{pctFor(from)}%"
         class:dragging={dragging === 'from'}
         onpointerdown={(e) => onPointerDown('from', e)}
         role="slider"
         tabindex="0"
         aria-valuemin={min}
         aria-valuemax={to}
         aria-valuenow={from}></div>
    <div class="range-slider-handle"
         style:left="{pctFor(to)}%"
         class:dragging={dragging === 'to'}
         onpointerdown={(e) => onPointerDown('to', e)}
         role="slider"
         tabindex="0"
         aria-valuemin={from}
         aria-valuemax={max}
         aria-valuenow={to}></div>
  </div>
  <div class="range-slider-bounds">
    <span>{min}</span>
    <span>{max}</span>
  </div>
</div>

<style>
  .range-slider {
    width: 100%;
    padding: 0.3rem 0;
  }
  .range-slider-label {
    font-size: 0.85rem;
    color: #4A5568;
    margin-bottom: 0.4rem;
  }
  .range-slider-track {
    position: relative;
    height: 28px;
    cursor: pointer;
    user-select: none;
    margin: 0 0.5rem;
  }
  .range-slider-rail {
    position: absolute;
    top: 50%;
    left: 0;
    right: 0;
    height: 4px;
    background: #E2E8F0;
    border-radius: 2px;
    transform: translateY(-50%);
  }
  .range-slider-fill {
    position: absolute;
    top: 50%;
    height: 4px;
    background: var(--ambolt-primary, #0B7A75);
    border-radius: 2px;
    transform: translateY(-50%);
  }
  .range-slider-handle {
    position: absolute;
    top: 50%;
    width: 16px;
    height: 16px;
    background: white;
    border: 2px solid var(--ambolt-primary, #0B7A75);
    border-radius: 50%;
    transform: translate(-50%, -50%);
    cursor: grab;
    transition: transform 0.1s;
    touch-action: none;
  }
  .range-slider-handle:hover,
  .range-slider-handle.dragging {
    transform: translate(-50%, -50%) scale(1.2);
    cursor: grabbing;
  }
  .range-slider-bounds {
    display: flex;
    justify-content: space-between;
    font-size: 0.7rem;
    color: #A0AEC0;
    margin-top: 0.3rem;
    padding: 0 0.5rem;
  }
</style>
