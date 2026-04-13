<script>
  // NumericInput — Number input with optional min/max/step
  //
  // Shiny equivalent: numericInput(inputId, label, value, min, max, step)
  //
  // Props:
  //   id    — unique identifier
  //   label — display label
  //   value — bind:value for two-way binding (number)
  //   min   — minimum value (optional)
  //   max   — maximum value (optional)
  //   step  — step increment (default 1)
  //   help  — optional help tooltip text (rendered as icon after label)

  import HelpTooltip from './HelpTooltip.svelte';

  let { id = '', label = '', value = $bindable(0), min = undefined, max = undefined, step = 1, help = '' } = $props();
</script>

<div class="ambolt-numeric-input" data-input-id={id}>
  <label for={id}>
    {label}
    <HelpTooltip text={help} />
  </label>
  <input type="number" {id} bind:value {min} {max} {step} />
</div>

<style>
  .ambolt-numeric-input {
    margin-bottom: 0.75rem;
  }
  label {
    display: block;
    font-weight: var(--ambolt-label-font-weight, 500);
    margin-bottom: var(--ambolt-label-margin-bottom, 0.25rem);
    font-size: var(--ambolt-label-font-size, 0.95rem);
    color: var(--ambolt-label-color, inherit);
  }
  input {
    font-size: var(--ambolt-input-font-size, 1rem);
    padding: var(--ambolt-input-padding, 0.35rem 0.5rem);
    border: 1px solid var(--ambolt-input-border-color, #d1d5db);
    border-radius: var(--ambolt-input-radius, 4px);
    width: 120px;
  }
</style>
