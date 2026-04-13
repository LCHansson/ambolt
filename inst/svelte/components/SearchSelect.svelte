<script>
  // SearchSelect — Searchable multi-select dropdown
  //
  // Similar to Shiny's selectizeInput: type to filter, selected items
  // appear as removable tag pills, dropdown shows filtered options.
  //
  // Props:
  //   choices    — array of { value, label }
  //   value      — array of selected values (bindable)
  //   placeholder — input placeholder text
  //   id         — field id for form integration

  let {
    choices = [],
    value = $bindable([]),
    placeholder = 'Sök...',
    id = ''
  } = $props();

  let search = $state('');
  let open = $state(false);
  let inputEl;
  let containerEl;

  // Filter choices: exclude already selected, match search text
  let filtered = $derived.by(() => {
    const selected = new Set(value);
    const q = search.toLowerCase();
    return choices.filter(c =>
      !selected.has(c.value) &&
      (q === '' || c.label.toLowerCase().includes(q))
    );
  });

  // Lookup label for a selected value
  function labelFor(val) {
    const c = choices.find(c => c.value === val);
    return c ? c.label : val;
  }

  function select(choice) {
    value = [...value, choice.value];
    search = '';
    inputEl?.focus();
  }

  function remove(val) {
    value = value.filter(v => v !== val);
  }

  function handleKeydown(e) {
    if (e.key === 'Backspace' && search === '' && value.length > 0) {
      // Remove last tag on backspace in empty search
      value = value.slice(0, -1);
    } else if (e.key === 'Escape') {
      open = false;
      inputEl?.blur();
    } else if (e.key === 'Enter') {
      e.preventDefault();
      // Select first filtered option
      const opts = filtered;
      if (opts.length > 0) {
        select(opts[0]);
      }
    }
  }

  function handleFocus() {
    open = true;
  }

  // Close dropdown when clicking outside
  function handleClickOutside(e) {
    if (containerEl && !containerEl.contains(e.target)) {
      open = false;
    }
  }

  $effect(() => {
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  });
</script>

<div class="search-select" bind:this={containerEl}>
  <!-- Selected tags + search input -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div class="search-select-input" role="combobox" aria-controls="search-select-list" aria-expanded="false" tabindex="-1" onclick={() => inputEl?.focus()}>
    {#each value as val}
      <span class="search-select-tag">
        {labelFor(val)}
        <button type="button" class="tag-remove" onclick={() => remove(val)}>&times;</button>
      </span>
    {/each}
    <input
      bind:this={inputEl}
      type="text"
      {id}
      bind:value={search}
      {placeholder}
      onfocus={handleFocus}
      onkeydown={handleKeydown}
      autocomplete="off"
    />
  </div>

  <!-- Dropdown -->
  {#if open && filtered.length > 0}
    <div class="search-select-dropdown">
      {#each filtered.slice(0, 50) as choice}
        <button
          type="button"
          class="search-select-option"
          onmousedown={(e) => { e.preventDefault(); select(choice); }}
        >
          {choice.label}
        </button>
      {/each}
      {#if filtered.length > 50}
        <div class="search-select-more">
          ... och {filtered.length - 50} fler (sök för att filtrera)
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .search-select {
    position: relative;
    width: 100%;
  }
  .search-select-input {
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem;
    padding: 0.3rem 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    background: white;
    cursor: text;
    min-height: 2.2rem;
    align-items: center;
  }
  .search-select-input:focus-within {
    border-color: var(--ambolt-primary, #4f46e5);
    outline: none;
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--ambolt-primary, #4f46e5) 20%, transparent);
  }
  .search-select-input input {
    border: none;
    outline: none;
    flex: 1;
    min-width: 60px;
    font-size: 0.95rem;
    font-family: inherit;
    padding: 0.1rem 0;
    background: transparent;
  }
  .search-select-tag {
    display: inline-flex;
    align-items: center;
    gap: 0.2rem;
    background: #e5e7eb;
    color: #374151;
    border-radius: 3px;
    padding: 0.1rem 0.4rem;
    font-size: 0.82rem;
    line-height: 1.4;
    white-space: nowrap;
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
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
  .tag-remove:hover {
    color: #dc2626;
  }
  .search-select-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    z-index: 100;
    background: white;
    border: 1px solid #d1d5db;
    border-top: none;
    border-radius: 0 0 4px 4px;
    max-height: 200px;
    overflow-y: auto;
    box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
  }
  .search-select-option {
    display: block;
    width: 100%;
    text-align: left;
    padding: 0.4rem 0.6rem;
    border: none;
    background: none;
    font-size: 0.9rem;
    font-family: inherit;
    cursor: pointer;
    color: #374151;
  }
  .search-select-option:hover {
    background: #f3f4f6;
  }
  .search-select-more {
    padding: 0.3rem 0.6rem;
    font-size: 0.8rem;
    color: #6b7280;
    font-style: italic;
  }
</style>
