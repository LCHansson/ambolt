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
    valueField = 'value',
    // Bindable search query string. Set when the user presses Enter
    // without selecting from the dropdown — signals "show results page".
    // Empty string when no active search. Reset when the user selects
    // an item (→ value is set) or clears the input.
    searchQuery = $bindable(''),
    // Optional live-search fallback ("nödutgång"). When the main endpoint
    // signals `suggest_live: true` (or returns zero hits) and at least
    // one source is listed, the dropdown renders buttons that query the
    // live endpoint for that source and merge the results back in.
    // liveEndpoint example: '/api/search/live' — the component appends
    // ?source=X&q=Y automatically.
    liveEndpoint = '',
    liveSources = []  // e.g. [{id: 'scb', label: 'SCB'}, {id: 'trafa', label: 'Trafa'}]
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
  let suggestLive = $state(false);
  let liveLoading = $state('');   // id of currently-querying source, or ''
  let liveMessage = $state('');

  async function fetchResults(query) {
    if (!query || query.length < 2) {
      results = [];
      suggestLive = false;
      liveMessage = '';
      return;
    }

    loading = true;
    liveMessage = '';
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
        suggestLive = false;
      } else if (data.status === 'empty') {
        priming = false;
        results = [];
        suggestLive = false;
        liveMessage = data.message || '';
      } else {
        priming = false;
        results = Array.isArray(data) ? data : (data.results || []);
        // An array response has no meta fields, so no suggest_live hint;
        // an object response may carry it explicitly.
        suggestLive = !Array.isArray(data) && !!data.suggest_live;
      }
    } catch (err) {
      results = [];
      suggestLive = false;
    } finally {
      loading = false;
    }
  }

  async function fetchLive(sourceId) {
    if (!liveEndpoint || !search || search.length < 2) return;
    liveLoading = sourceId;
    try {
      const base = baseUrl || window.location.origin;
      const url = new URL(liveEndpoint, base);
      url.searchParams.set('source', sourceId);
      url.searchParams.set('q', search);
      const res = await fetch(url.toString());
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();

      if (data.status === 'error') {
        liveMessage = data.message || 'Live-sök misslyckades.';
      } else {
        const newRows = Array.isArray(data) ? data : (data.results || []);
        if (newRows.length === 0) {
          liveMessage = `Inga ytterligare tr\u00e4ffar hos ${sourceId.toUpperCase()}.`;
        } else {
          // Merge by value, live rows appended at the end
          const seen = new Set(results.map(r => r.value));
          const merged = [...results];
          for (const r of newRows) {
            if (!seen.has(r.value)) { merged.push(r); seen.add(r.value); }
          }
          results = merged;
          // Once we've surfaced live results we no longer need to
          // nag the user — drop the suggestion banner.
          suggestLive = false;
          liveMessage = '';
        }
      }
    } catch (err) {
      liveMessage = `Live-s\u00f6k fel: ${err.message}`;
    } finally {
      liveLoading = '';
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
    searchQuery = '';  // clear results-mode when selecting
    search = item.label || item.title || '';
    open = false;
    results = [];
  }

  function clear() {
    selectedItem = null;
    value = '';
    searchQuery = '';
    search = '';
    results = [];
    inputEl?.focus();
  }

  function submitSearch() {
    // Enter without dropdown selection → "results mode"
    if (search.length >= 2) {
      searchQuery = search;
      value = '';  // ensure we're NOT in explorer mode
      selectedItem = null;
      open = false;
    }
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
        // User highlighted a dropdown row → select it (→ explorer)
        select(results[activeIndex]);
      } else {
        // No dropdown highlight → submit search (→ results page)
        submitSearch();
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

  // Programmatic selection bridge: result cards (or any external code) can
  // select an item by dispatching a CustomEvent on the document. This
  // avoids fragile DOM manipulation of the search input.
  //   document.dispatchEvent(new CustomEvent('ambolt:select', {
  //     detail: { inputId: 'kpi_search', value: 'kolada:N03700', label: 'Befolkning totalt' }
  //   }))
  $effect(() => {
    function handleExternalSelect(e) {
      const d = e.detail;
      if (d && d.inputId === id && d.value) {
        select({ [valueField]: d.value, label: d.label || d.value });
      }
    }
    document.addEventListener('ambolt:select', handleExternalSelect);
    return () => document.removeEventListener('ambolt:select', handleExternalSelect);
  });
</script>

<div class="server-search"
     bind:this={containerEl}
     data-mode={value !== '' ? 'explorer' : (searchQuery !== '' ? 'results' : 'landing')}>
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
      {:else if liveMessage && results.length === 0}
        <div class="server-search-status">{liveMessage}</div>
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
            title={item.description || ''}
          >
            <div class="option-row">
              <span class="option-label">{item.label || item.title}</span>
              {#if item.source}
                <span class="option-source">{item.source}</span>
              {/if}
            </div>
            {#if item.description}
              <span class="option-desc">{item.description}</span>
            {/if}
          </button>
        {/each}
        {#if results.length > 50}
          <div class="server-search-more">
            ... och {results.length - 50} fler
          </div>
        {/if}
      {/if}

      <!-- Nödutgång: live-search buttons when results are thin -->
      {#if !loading && !priming && search.length >= 2
           && liveEndpoint && liveSources.length > 0
           && (suggestLive || results.length === 0)}
        <div class="server-search-live-panel">
          <div class="server-search-live-label">
            {results.length === 0 ? 'Inga lokala tr\u00e4ffar. S\u00f6k vidare hos:' : 'F\u00e5 lokala tr\u00e4ffar. S\u00f6k vidare hos:'}
          </div>
          <div class="server-search-live-buttons">
            {#each liveSources as src}
              <button
                type="button"
                class="server-search-live-btn"
                onmousedown={(e) => { e.preventDefault(); fetchLive(src.id); }}
                disabled={liveLoading !== ''}
              >
                {liveLoading === src.id ? 'S\u00f6ker...' : src.label}
              </button>
            {/each}
          </div>
          {#if liveMessage && results.length > 0}
            <div class="server-search-live-msg">{liveMessage}</div>
          {/if}
        </div>
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
    padding: 0.35rem 0.6rem;
    border: none;
    background: none;
    font-family: inherit;
    cursor: pointer;
    gap: 0.1rem;
    border-bottom: 1px solid #f3f4f6;
  }
  .server-search-option:hover,
  .server-search-option.active {
    background: #f3f4f6;
  }
  .option-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    width: 100%;
    min-width: 0;
  }
  .option-label {
    font-size: 0.88rem;
    color: #1f2937;
    font-weight: 500;
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .option-desc {
    font-size: 0.75rem;
    color: #6b7280;
    line-height: 1.25;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .option-source {
    flex-shrink: 0;
    font-size: 0.65rem;
    color: #0B7A75;
    background: #EBF5F5;
    padding: 0.05rem 0.35rem;
    border-radius: 3px;
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
  .server-search-live-panel {
    padding: 0.5rem 0.75rem;
    background: #FFF7ED;
    border-top: 1px solid #FED7AA;
  }
  .server-search-live-label {
    font-size: 0.78rem;
    color: #92400E;
    margin-bottom: 0.35rem;
  }
  .server-search-live-buttons {
    display: flex;
    gap: 0.35rem;
    flex-wrap: wrap;
  }
  .server-search-live-btn {
    font-size: 0.78rem;
    font-weight: 600;
    padding: 0.25rem 0.6rem;
    border: 1px solid #F59E0B;
    background: #FEF3C7;
    color: #92400E;
    border-radius: 4px;
    cursor: pointer;
    font-family: inherit;
  }
  .server-search-live-btn:hover:not(:disabled) {
    background: #FDE68A;
  }
  .server-search-live-btn:disabled {
    cursor: wait;
    opacity: 0.7;
  }
  .server-search-live-msg {
    margin-top: 0.35rem;
    font-size: 0.75rem;
    color: #92400E;
    font-style: italic;
  }
</style>
