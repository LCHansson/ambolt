<script>
  // DateRangeInput — Two date pickers for selecting a date range
  //
  // Shiny equivalent: dateRangeInput(inputId, label, start, end, min, max)
  //
  // Divergence from Shiny: Shiny returns a single input with two values.
  // This component uses two separate bindable props (start, end) which is
  // more explicit. The R endpoint receives both as query parameters.
  //
  // Props:
  //   id    — unique identifier
  //   label — display label
  //   start — bind:start for two-way binding (string, "YYYY-MM-DD")
  //   end   — bind:end for two-way binding (string, "YYYY-MM-DD")
  //   min   — earliest selectable date (optional)
  //   max   — latest selectable date (optional)

  let { id = '', label = '', start = $bindable(''), end = $bindable(''), min = undefined, max = undefined } = $props();
</script>

<div class="ambolt-daterange-input" data-input-id={id}>
  <label for="{id}-start">{label}</label>
  <div class="range-fields">
    <input type="date" id="{id}-start" bind:value={start} {min} max={end || max} />
    <span class="separator">to</span>
    <input type="date" id="{id}-end" bind:value={end} min={start || min} {max} />
  </div>
</div>

<style>
  .ambolt-daterange-input {
    margin-bottom: 0.75rem;
  }
  label {
    display: block;
    font-weight: var(--ambolt-label-font-weight, 500);
    margin-bottom: var(--ambolt-label-margin-bottom, 0.25rem);
    font-size: var(--ambolt-label-font-size, 0.95rem);
    color: var(--ambolt-label-color, inherit);
  }
  .range-fields {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .separator {
    color: #6b7280;
    font-size: 0.9rem;
  }
  input {
    font-size: var(--ambolt-input-font-size, 1rem);
    padding: var(--ambolt-input-padding, 0.35rem 0.5rem);
    border: 1px solid var(--ambolt-input-border-color, #d1d5db);
    border-radius: var(--ambolt-input-radius, 4px);
  }
</style>
