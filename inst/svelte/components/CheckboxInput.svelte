<script>
  // CheckboxInput — Single checkbox (boolean toggle)
  //
  // Shiny equivalent: checkboxInput(inputId, label, value)
  //
  // Props:
  //   id      — unique identifier
  //   label   — display label (shown next to the checkbox)
  //   checked — bind:checked for two-way binding (boolean)

  let { id = '', label = '', checked = $bindable(false) } = $props();
</script>

<div class="ambolt-checkbox-input" data-input-id={id}>
  <label>
    <input type="checkbox" {id} bind:checked />
    {label}
  </label>
</div>

<style>
  .ambolt-checkbox-input {
    margin-bottom: 0.75rem;
  }
  label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: var(--ambolt-label-font-weight, 500);
    font-size: var(--ambolt-label-font-size, 0.95rem);
    color: var(--ambolt-label-color, inherit);
    cursor: pointer;
  }
  input[type="checkbox"] {
    width: 1.1rem;
    height: 1.1rem;
    cursor: pointer;
  }
</style>
