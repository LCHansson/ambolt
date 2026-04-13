<script>
  // CheckboxGroupInput — Group of checkboxes (multiple selection)
  //
  // Shiny equivalent: checkboxGroupInput(inputId, label, choices, selected)
  //
  // Divergence from Shiny: returns an array of selected values rather than
  // a character vector. Same data, different container — natural for JS.
  //
  // Props:
  //   id       — unique identifier
  //   label    — group label
  //   choices  — array of strings or { value, label } objects
  //   selected — bind:selected for two-way binding (array of selected values)

  let { id = '', label = '', choices = [], selected = $bindable([]) } = $props();

  let normalizedChoices = $derived(
    choices.map(c => typeof c === 'string' ? { value: c, label: c } : c)
  );

  function toggleValue(val) {
    if (selected.includes(val)) {
      selected = selected.filter(v => v !== val);
    } else {
      selected = [...selected, val];
    }
  }
</script>

<fieldset class="ambolt-checkbox-group" data-input-id={id}>
  <legend>{label}</legend>
  {#each normalizedChoices as choice}
    <label>
      <input
        type="checkbox"
        value={choice.value}
        checked={selected.includes(choice.value)}
        onchange={() => toggleValue(choice.value)}
      />
      {choice.label}
    </label>
  {/each}
</fieldset>

<style>
  .ambolt-checkbox-group {
    margin-bottom: 0.75rem;
    border: 1px solid var(--ambolt-input-border-color, #d1d5db);
    border-radius: var(--ambolt-input-radius, 4px);
    padding: 0.5rem 0.75rem;
  }
  legend {
    font-weight: var(--ambolt-label-font-weight, 500);
    font-size: var(--ambolt-label-font-size, 0.95rem);
    color: var(--ambolt-label-color, inherit);
    padding: 0 0.25rem;
  }
  label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: var(--ambolt-label-font-size, 0.95rem);
    cursor: pointer;
    padding: 0.15rem 0;
  }
  input[type="checkbox"] {
    width: 1rem;
    height: 1rem;
    cursor: pointer;
  }
</style>
