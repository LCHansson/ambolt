<script>
  // ActionButton — Button that triggers an action
  //
  // Shiny equivalent: actionButton(inputId, label, icon)
  //
  // Divergence from Shiny: Shiny's actionButton increments a counter each
  // click (input$btn becomes 1, 2, 3...) and you use observeEvent(input$btn, ...).
  // Here, the button calls an `onclick` handler directly — more natural in JS.
  //
  // Why: The counter pattern exists in Shiny because reactivity needs a value
  // change to trigger. In our architecture, we can just call a function.
  //
  // Props:
  //   id       — unique identifier
  //   label    — button text
  //   onclick  — function to call when clicked
  //   variant  — "default" | "primary" | "danger" (styling)
  //   disabled — when true, button is greyed out and unclickable

  let { id = '', label = '', onclick = () => {}, variant = 'default', disabled = false } = $props();
</script>

<button
  class="ambolt-action-button {variant}"
  class:disabled
  data-input-id={id}
  {id}
  {onclick}
  {disabled}
>
  {label}
</button>

<style>
  .ambolt-action-button {
    font-size: var(--ambolt-input-font-size, 1rem);
    padding: 0.5rem 1rem;
    border: 1px solid var(--ambolt-input-border-color, #d1d5db);
    border-radius: var(--ambolt-input-radius, 4px);
    cursor: pointer;
    margin-bottom: 0.75rem;
    transition: background 0.15s;
  }
  .default {
    background: white;
    color: #374151;
  }
  .default:hover {
    background: #f3f4f6;
  }
  .primary {
    background: var(--ambolt-primary-bg, #4f46e5);
    color: var(--ambolt-primary-color, white);
    border-color: var(--ambolt-primary-bg, #4f46e5);
  }
  .primary:hover {
    background: var(--ambolt-primary-hover-bg, #4338ca);
  }
  .danger {
    background: #dc2626;
    color: white;
    border-color: #dc2626;
  }
  .danger:hover {
    background: #b91c1c;
  }
  .disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
