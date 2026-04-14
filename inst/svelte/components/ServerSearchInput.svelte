<script>
  // ServerSearchInput — Server-backed typeahead search
  //
  // Fetches suggestions from a server endpoint as the user types.
  // Unlike SearchSelect (which filters a client-side choices array),
  // this component sends each keystroke (debounced) to the server.
  //
  // Props:
  //   endpoint    — API URL to fetch suggestions from (appends ?q=<search>)
  //   value       — selected item object (bindable): { value, label, description, source }
  //   placeholder — input placeholder text
  //   id          — field id for form integration
  //   debounce    — debounce delay in ms (default 200)
  //   baseUrl     — API base URL (defaults to current page origin)

  let {
    endpoint = '',
    value = $bindable(''),
    placeholder = 'Sök...',
    id = '',
    debounce = 200,
    baseUrl = '',
    valueField = 'value'
  } = $props();

  let search = $state('');
  let results = $state([]);
  let open = $state(false);
  let loading = $state(false);
  let inputEl;
  let containerEl;
  let debounceTimer;
  let activeIndex = $state(-1);
  let priming = $state(false);

  async function fetchResults(query) {
    if (!query || query.length < 2) {
      results = [];
      return;
    }

    loading = true;
    try {
      const base = baseUrl || window.location.origin;
      const url = new URL(endpoint, base);
      url.searchParams.set('q', query);
      const res = await fetch(url.toString());
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();

      if (data.status === 'priming') {
        priming = true;
        results = [];
      } else {
        priming = false;
        results = Array.isArray(data) ? data : (data.results || []);
      }
    } catch (err) {
      results = [];
    } finally {
      loading = false;
    }
  }

  function onInput() {
    activeIndex = -1;
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => fetchResults(search), debounce);
  }

  // Store the full selected item for display, but bind value to just the ID field
  let selectedItem = $state(null);

  function select(item) {
    selectedItem = item;
    value = item[valueField] || '';
    search = item.label || item.title || '';
    open = false;
    results = [];
  }

  function clear() {
    selectedItem = null;
    value = '';
    search = '';
    results = [];
    inputEl?.focus();
  }

  function handleKeydown(e) {
    if (e.key === 'Escape') {
      open = false;
      inputEl?.blur();
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (results.length > 0) {
        activeIndex = Math.min(activeIndex + 1, results.length - 1);
      }
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      activeIndex = Math.max(activeIndex - 1, -1);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (activeIndex >= 0 && activeIndex < results.length) {
        select(results[activeIndex]);
      }
    }
  }

  function handleFocus() {
    open = true;
    if (search.length >= 2 && results.length === 0) {
      fetchResults(search);
    }
  }

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

<div class="server-search" bind:this={containerEl}>
  <div class="server-search-input-wrapper">
    <input
      bind:this={inputEl}
      type="text"
      {id}
      bind:value={search}
      {placeholder}
      oninput={onInput}
      onfocus={handleFocus}
      onkeydown={handleKeydown}
      autocomplete="off"
    />
    {#if value !== ''}
      <button type="button" class="clear-btn" onclick={clear}>&times;</button>
    {/if}
  </div>

  {#if open}
    <div class="server-search-dropdown">
      {#if priming}
        <div class="server-search-status">
          Indexerar statistik, var god vänta...
        </div>
      {:else if loading}
        <div class="server-search-status">Söker...</div>
      {:else if search.length < 2}
        <div class="server-search-status">Skriv minst 2 tecken</div>
      {:else if results.length === 0}
        <div class="server-search-status">Inga träffar</div>
      {:else}
        {#each results.slice(0, 50) as item, i}
          <button
            type="button"
            class="server-search-option"
            class:active={i === activeIndex}
            onmousedown={(e) => { e.preventDefault(); select(item); }}
            onmouseenter={() => activeIndex = i}
          >
            <span class="option-label">{item.label || item.title}</span>
            {#if item.description}
              <span class="option-desc">{item.description}</span>
            {/if}
            {#if item.source}
              <span class="option-source">{item.source}</span>
            {/if}
          </button>
        {/each}
        {#if results.length > 50}
          <div class="server-search-more">
            ... och {results.length - 50} fler
          </div>
        {/if}
      {/if}
    </div>
  {/if}
</div>

<style>
  .server-search {
    position: relative;
    width: 100%;
  }
  .server-search-input-wrapper {
    position: relative;
    display: flex;
    align-items: center;
  }
  .server-search-input-wrapper input {
    width: 100%;
    padding: 0.5rem 2rem 0.5rem 0.75rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 1rem;
    font-family: inherit;
    background: white;
    transition: border-color 0.15s;
  }
  .server-search-input-wrapper input:focus {
    border-color: var(--ambolt-primary, #0B7A75);
    outline: none;
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--ambolt-primary, #0B7A75) 20%, transparent);
  }
  .clear-btn {
    position: absolute;
    right: 0.5rem;
    border: none;
    background: none;
    color: #6b7280;
    cursor: pointer;
    font-size: 1.2rem;
    line-height: 1;
    padding: 0.2rem;
  }
  .clear-btn:hover {
    color: #dc2626;
  }
  .server-search-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    z-index: 100;
    background: white;
    border: 1px solid #d1d5db;
    border-top: none;
    border-radius: 0 0 6px 6px;
    max-height: 320px;
    overflow-y: auto;
    box-shadow: 0 4px 12px -2px rgb(0 0 0 / 0.12);
  }
  .server-search-status {
    padding: 0.6rem 0.75rem;
    font-size: 0.85rem;
    color: #6b7280;
    font-style: italic;
  }
  .server-search-option {
    display: flex;
    flex-direction: column;
    width: 100%;
    text-align: left;
    padding: 0.5rem 0.75rem;
    border: none;
    background: none;
    font-family: inherit;
    cursor: pointer;
    gap: 0.15rem;
    border-bottom: 1px solid #f3f4f6;
  }
  .server-search-option:hover,
  .server-search-option.active {
    background: #f3f4f6;
  }
  .option-label {
    font-size: 0.9rem;
    color: #1f2937;
    font-weight: 500;
  }
  .option-desc {
    font-size: 0.78rem;
    color: #6b7280;
    line-height: 1.3;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .option-source {
    display: inline-block;
    font-size: 0.7rem;
    color: #0B7A75;
    background: #EBF5F5;
    padding: 0.1rem 0.4rem;
    border-radius: 3px;
    margin-top: 0.15rem;
    align-self: flex-start;
    text-transform: uppercase;
    font-weight: 600;
    letter-spacing: 0.03em;
  }
  .server-search-more {
    padding: 0.4rem 0.75rem;
    font-size: 0.78rem;
    color: #6b7280;
    font-style: italic;
  }
</style>
