<script>
  // SelectInput — Framework component for dropdown selection
  //
  // Shiny equivalent: selectInput(inputId, label, choices, selected)
  //
  // Props:
  //   id       — unique identifier (like Shiny's inputId)
  //   label    — display label
  //   choices  — array of { value, label } objects, or array of strings
  //   value    — bind:value for two-way binding (like input${id} in Shiny)
  //   help     — optional help tooltip text (rendered as icon after label)

  import HelpTooltip from './HelpTooltip.svelte';

  let { id = '', label = '', choices = [], value = $bindable(''), help = '' } = $props();

  // Normalize choices: accept either strings or {value, label} objects
  let normalizedChoices = $derived(
    choices.map(c => typeof c === 'string' ? { value: c, label: c } : c)
  );
</script>

<div class="ambolt-select-input" data-input-id={id}>
  <label for={id}>
    {label}
    <HelpTooltip text={help} />
  </label>
  <select {id} bind:value>
    {#each normalizedChoices as choice}
      <option value={choice.value}>{choice.label}</option>
    {/each}
  </select>
</div>

<style>
  .ambolt-select-input {
    margin-bottom: 0.75rem;
  }
  label {
    display: block;
    font-weight: var(--ambolt-label-font-weight, 500);
    margin-bottom: var(--ambolt-label-margin-bottom, 0.25rem);
    font-size: var(--ambolt-label-font-size, 0.95rem);
    color: var(--ambolt-label-color, inherit);
  }
  select {
    font-size: var(--ambolt-input-font-size, 1rem);
    padding: var(--ambolt-input-padding, 0.35rem 0.5rem);
    border: 1px solid var(--ambolt-input-border-color, #d1d5db);
    border-radius: var(--ambolt-input-radius, 4px);
    background: white;
  }
</style>
