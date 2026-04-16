<script>
  // MultiSelect — Multi-select dropdown with searchable options
  //
  // Similar to SearchSelect (which already exists) but with explicit
  // value/text choice format and tag-pill UI for selected items.
  // Bound value is an array of selected codes.
  //
  // Props:
  //   id          — field id
  //   label       — display label
  //   value       — bindable array of selected codes
  //   choices     — array of { code, text } options
  //   placeholder — search placeholder

  let {
    id = '',
    label = '',
    value = $bindable([]),
    choices = [],
    placeholder = 'Sök...'
  } = $props();

  let search = $state('');
  let open = $state(false);
  let inputEl;
  let containerEl;

  let selectedSet = $derived(new Set(value));

  let filtered = $derived.by(() => {
    const q = search.toLowerCase();
    return choices.filter(c =>
      !selectedSet.has(c.code) &&
      (q === '' || c.text.toLowerCase().includes(q) ||
       c.code.toLowerCase().includes(q))
    );
  });

  function labelFor(code) {
    const c = choices.find(x => x.code === code);
    return c ? c.text : code;
  }

  function add(choice) {
    value = [...value, choice.code];
    search = '';
    inputEl?.focus();
  }

  function remove(code) {
    value = value.filter(v => v !== code);
  }

  function handleKeydown(e) {
    if (e.key === 'Backspace' && search === '' && value.length > 0) {
      value = value.slice(0, -1);
    } else if (e.key === 'Escape') {
      open = false;
      inputEl?.blur();
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (filtered.length > 0) add(filtered[0]);
    }
  }

  function handleClickOutside(e) {
    if (containerEl && !containerEl.contains(e.target)) open = false;
  }

  $effect(() => {
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  });
</script>

<div class="multi-select" {id} bind:this={containerEl}>
  {#if label}
    <div class="multi-select-label">{label}</div>
  {/if}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="multi-select-input" onclick={() => inputEl?.focus()}>
    {#each value as code}
      <span class="multi-select-tag">
        {labelFor(code)}
        <button type="button" class="tag-remove" onclick={() => remove(code)}>&times;</button>
      </span>
    {/each}
    <input
      bind:this={inputEl}
      type="text"
      bind:value={search}
      {placeholder}
      onfocus={() => open = true}
      onkeydown={handleKeydown}
      autocomplete="off"
    />
  </div>

  {#if open && filtered.length > 0}
    <div class="multi-select-dropdown">
      {#each filtered.slice(0, 50) as choice}
        <button
          type="button"
          class="multi-select-option"
          onmousedown={(e) => { e.preventDefault(); add(choice); }}
        >
          {choice.text}
        </button>
      {/each}
      {#if filtered.length > 50}
        <div class="multi-select-more">
          ... och {filtered.length - 50} fler
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .multi-select {
    position: relative;
    width: 100%;
  }
  .multi-select-label {
    font-size: 0.85rem;
    color: #4A5568;
    margin-bottom: 0.4rem;
  }
  .multi-select-input {
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem;
    padding: 0.3rem 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    background: white;
    cursor: text;
    min-height: 2.2rem;
    align-items: center;
  }
  .multi-select-input:focus-within {
    border-color: var(--ambolt-primary, #0B7A75);
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--ambolt-primary, #0B7A75) 20%, transparent);
  }
  .multi-select-input input {
    border: none;
    outline: none;
    flex: 1;
    min-width: 80px;
    font-size: 0.9rem;
    font-family: inherit;
    background: transparent;
  }
  .multi-select-tag {
    display: inline-flex;
    align-items: center;
    gap: 0.2rem;
    background: #EBF5F5;
    color: #065956;
    border-radius: 3px;
    padding: 0.1rem 0.45rem;
    font-size: 0.82rem;
    line-height: 1.4;
  }
  .tag-remove {
    border: none;
    background: none;
    color: #6b7280;
    cursor: pointer;
    padding: 0 0.1rem;
    font-size: 1rem;
    line-height: 1;
    font-weight: bold;
  }
  .tag-remove:hover { color: #dc2626; }
  .multi-select-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    z-index: 100;
    background: white;
    border: 1px solid #d1d5db;
    border-top: none;
    border-radius: 0 0 6px 6px;
    max-height: 240px;
    overflow-y: auto;
    box-shadow: 0 4px 12px -2px rgb(0 0 0 / 0.12);
  }
  .multi-select-option {
    display: block;
    width: 100%;
    text-align: left;
    padding: 0.4rem 0.6rem;
    border: none;
    background: none;
    font-size: 0.88rem;
    font-family: inherit;
    cursor: pointer;
    color: #2D3748;
    border-bottom: 1px solid #f3f4f6;
  }
  .multi-select-option:hover { background: #f3f4f6; }
  .multi-select-more {
    padding: 0.4rem 0.6rem;
    font-size: 0.78rem;
    color: #6b7280;
    font-style: italic;
  }
</style>
