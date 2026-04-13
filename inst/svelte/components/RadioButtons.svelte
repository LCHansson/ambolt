<script>
  // RadioButtons — Radio button group (single selection from multiple options)
  //
  // Shiny equivalent: radioButtons(inputId, label, choices, selected)
  //
  // Supports two variants:
  //   "default"    — standard radio circles with labels
  //   "button-bar" — large toggle buttons in a horizontal bar
  //                   (Elektrifieringskollen-style vehicle class selector)
  //
  // Props:
  //   id      — unique identifier
  //   label   — group label
  //   choices — array of strings or { value, label } objects
  //   value   — bind:value for two-way binding (single selected value)
  //   variant — "default" | "button-bar"
  //   icons   — optional object mapping choice values to HTML/SVG strings
  //             (rendered above the label in button-bar variant)

  let { id = '', label = '', choices = [], value = $bindable(''), variant = 'default', icons = {} } = $props();

  let normalizedChoices = $derived(
    choices.map(c => typeof c === 'string' ? { value: c, label: c } : c)
  );
</script>

{#if variant === 'button-bar'}
  <div class="ambolt-radio-bar" data-input-id={id}>
    {#if label}<div class="bar-label">{label}</div>{/if}
    <div class="bar-buttons">
      {#each normalizedChoices as choice}
        <button
          class="bar-button"
          class:active={value === choice.value}
          class:has-icon={icons[choice.value]}
          onclick={() => value = choice.value}
          type="button"
        >
          {#if icons[choice.value]}
            <span class="bar-icon">{@html icons[choice.value]}</span>
          {/if}
          <span class="bar-text">{choice.label}</span>
        </button>
      {/each}
    </div>
  </div>
{:else}
  <fieldset class="ambolt-radio-buttons" data-input-id={id}>
    <legend>{label}</legend>
    {#each normalizedChoices as choice}
      <label>
        <input
          type="radio"
          name={id}
          value={choice.value}
          checked={value === choice.value}
          onchange={() => value = choice.value}
        />
        {choice.label}
      </label>
    {/each}
  </fieldset>
{/if}

<style>
  /* Default variant — standard radio circles */
  .ambolt-radio-buttons {
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
  .ambolt-radio-buttons label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: var(--ambolt-label-font-size, 0.95rem);
    cursor: pointer;
    padding: 0.15rem 0;
  }
  input[type="radio"] {
    width: 1rem;
    height: 1rem;
    cursor: pointer;
  }

  /* Button-bar variant — large toggle buttons */
  .ambolt-radio-bar {
    margin-bottom: 0.75rem;
  }
  .bar-label {
    font-weight: 500;
    font-size: 0.95rem;
    margin-bottom: 0.4rem;
  }
  .bar-buttons {
    display: flex;
    border: 1px solid var(--ambolt-radio-bar-border, #d1d5db);
    border-radius: var(--ambolt-radio-bar-radius, 6px);
    overflow: hidden;
  }
  .bar-button {
    flex: 1;
    padding: 0.7rem 0.5rem;
    border: none;
    border-right: 1px solid var(--ambolt-radio-bar-border, #d1d5db);
    background: white;
    color: #374151;
    font-size: 0.9rem;
    font-weight: 500;
    cursor: pointer;
    text-align: center;
    transition: background 0.15s, color 0.15s, fill 0.15s;
  }
  .bar-button.has-icon {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
    padding: 0.75rem 0.5rem 0.5rem;
  }
  .bar-button:last-child {
    border-right: none;
  }
  .bar-button:hover:not(.active) {
    background: #f3f4f6;
  }
  .bar-button.active {
    background: var(--ambolt-radio-bar-active, #4f46e5);
    color: white;
    fill: white;
  }
  .bar-icon {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .bar-icon :global(svg) {
    width: 40px;
    height: 28px;
  }
</style>
