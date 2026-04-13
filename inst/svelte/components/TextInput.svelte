<script>
  // TextInput — Single-line text input
  //
  // Shiny equivalent: textInput(inputId, label, value, placeholder)
  //
  // Props:
  //   id          — unique identifier
  //   label       — display label
  //   value       — bind:value for two-way binding
  //   placeholder — placeholder text when empty

  let { id = '', label = '', value = $bindable(''), placeholder = '' } = $props();
</script>

<div class="ambolt-text-input" data-input-id={id}>
  <label for={id}>{label}</label>
  <input type="text" {id} bind:value {placeholder} />
</div>

<style>
  .ambolt-text-input {
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
    width: 100%;
    box-sizing: border-box;
  }
</style>
