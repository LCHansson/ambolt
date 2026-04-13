<script>
  // NumericInputWithUnit — Number input with a unit label on the right
  //
  // Shiny equivalent: Custom numericInputWithUnit() used in Elektrifieringskollen
  // Wraps a standard numeric input with a unit indicator (kr, mil, kWh, etc.)
  //
  // Props:
  //   id    — unique identifier
  //   label — display label
  //   value — bind:value for two-way binding (number)
  //   min   — minimum value (optional)
  //   max   — maximum value (optional)
  //   step  — step increment (default 1)
  //   unit  — unit label displayed to the right of the input (e.g., "kr", "mil")
  //   help  — optional help tooltip text (rendered as icon after label)

  import HelpTooltip from './HelpTooltip.svelte';

  let { id = '', label = '', value = $bindable(0), min = undefined, max = undefined, step = 1, unit = '', help = '' } = $props();
</script>

<div class="ambolt-numeric-with-unit" data-input-id={id}>
  <label for={id}>
    {label}
    <HelpTooltip text={help} />
  </label>
  <div class="input-row">
    <input type="number" {id} bind:value {min} {max} {step} />
    {#if unit}
      <span class="unit">{unit}</span>
    {/if}
  </div>
</div>

<style>
  .ambolt-numeric-with-unit {
    margin-bottom: 0.75rem;
  }
  label {
    display: block;
    font-weight: var(--ambolt-label-font-weight, 500);
    margin-bottom: var(--ambolt-label-margin-bottom, 0.25rem);
    font-size: var(--ambolt-label-font-size, 0.95rem);
    color: var(--ambolt-label-color, inherit);
  }
  .input-row {
    display: flex;
    align-items: stretch;
  }
  input {
    font-size: var(--ambolt-input-font-size, 1rem);
    padding: var(--ambolt-input-padding, 0.35rem 0.5rem);
    border: 1px solid var(--ambolt-input-border-color, #d1d5db);
    border-radius: var(--ambolt-input-radius, 4px) 0 0 var(--ambolt-input-radius, 4px);
    width: 120px;
    flex: 1;
  }
  .unit {
    display: flex;
    align-items: center;
    padding: 0 0.6rem;
    background: #f3f4f6;
    border: 1px solid var(--ambolt-input-border-color, #d1d5db);
    border-left: none;
    border-radius: 0 var(--ambolt-input-radius, 4px) var(--ambolt-input-radius, 4px) 0;
    font-size: 0.9rem;
    color: #6b7280;
    white-space: nowrap;
  }
  /* When there's no unit, give input full border-radius */
  .input-row:not(:has(.unit)) input {
    border-radius: var(--ambolt-input-radius, 4px);
  }
</style>
