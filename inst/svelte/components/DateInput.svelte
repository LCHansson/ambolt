<script>
  // DateInput — Date picker
  //
  // Shiny equivalent: dateInput(inputId, label, value, min, max)
  //
  // Divergence from Shiny: uses the browser's native date picker rather than
  // Shiny's JavaScript-based datepicker. This is simpler, more accessible,
  // and mobile-friendly. The value is a string in "YYYY-MM-DD" format.
  //
  // Props:
  //   id    — unique identifier
  //   label — display label
  //   value — bind:value for two-way binding (string, "YYYY-MM-DD")
  //   min   — earliest selectable date (optional, "YYYY-MM-DD")
  //   max   — latest selectable date (optional, "YYYY-MM-DD")

  let { id = '', label = '', value = $bindable(''), min = undefined, max = undefined } = $props();
</script>

<div class="ambolt-date-input" data-input-id={id}>
  <label for={id}>{label}</label>
  <input type="date" {id} bind:value {min} {max} />
</div>

<style>
  .ambolt-date-input {
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
  }
</style>
