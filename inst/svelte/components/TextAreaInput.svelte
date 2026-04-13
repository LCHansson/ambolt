<script>
  // TextAreaInput — Multi-line text input
  //
  // Shiny equivalent: textAreaInput(inputId, label, value, placeholder, rows, cols)
  //
  // Props:
  //   id          — unique identifier
  //   label       — display label
  //   value       — bind:value for two-way binding
  //   placeholder — placeholder text
  //   rows        — number of visible text lines (default 4)

  let { id = '', label = '', value = $bindable(''), placeholder = '', rows = 4 } = $props();
</script>

<div class="ambolt-textarea-input" data-input-id={id}>
  <label for={id}>{label}</label>
  <textarea {id} bind:value {placeholder} {rows}></textarea>
</div>

<style>
  .ambolt-textarea-input {
    margin-bottom: 0.75rem;
  }
  label {
    display: block;
    font-weight: var(--ambolt-label-font-weight, 500);
    margin-bottom: var(--ambolt-label-margin-bottom, 0.25rem);
    font-size: var(--ambolt-label-font-size, 0.95rem);
    color: var(--ambolt-label-color, inherit);
  }
  textarea {
    font-size: var(--ambolt-input-font-size, 1rem);
    padding: var(--ambolt-input-padding, 0.35rem 0.5rem);
    border: 1px solid var(--ambolt-input-border-color, #d1d5db);
    border-radius: var(--ambolt-input-radius, 4px);
    width: 100%;
    box-sizing: border-box;
    font-family: inherit;
    resize: vertical;
  }
</style>
