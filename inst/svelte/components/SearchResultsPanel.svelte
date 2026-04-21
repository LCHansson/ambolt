<script>
  // SearchResultsPanel — Data-driven search results with metadata,
  // source grouping, filtering, and basket integration.
  //
  // Props:
  //   query     — search query string (triggers fetch)
  //   baseUrl   — API base URL (default: window.location.origin)
  //   onSelect  — callback(item) when "Visa direkt" is clicked
  //   onBasket  — callback(item) when "Lägg i korg" is clicked

  import { basket } from './basketStore.svelte.js';

  let {
    query = '',
    baseUrl = '',
    onSelect = () => {},
    onBasket = (item) => basket.add(item),
  } = $props();

  let results = $state([]);
  let loading = $state(false);
  let totalCount = $state(0);
  let suggestLive = $state(false);

  // Client-side filters
  let sourceFilter = $state('all');
  let uniqueSources = $derived([...new Set(results.map(r => r.source))].sort());

  let filtered = $derived.by(() => {
    let r = results;
    if (sourceFilter !== 'all') r = r.filter(x => x.source === sourceFilter);
    return r;
  });

  // Group by source
  let grouped = $derived.by(() => {
    const groups = {};
    for (const item of filtered) {
      const src = item.source || 'Övrigt';
      if (!groups[src]) groups[src] = [];
      groups[src].push(item);
    }
    return Object.entries(groups);
  });

  // Fetch when query changes
  $effect(() => {
    if (!query || query.length < 2) {
      results = [];
      totalCount = 0;
      return;
    }
    loading = true;
    const base = baseUrl || window.location.origin;
    const url = new URL('/api/search', base);
    url.searchParams.set('q', query);

    fetch(url.toString())
      .then(r => r.json())
      .then(data => {
        const rows = Array.isArray(data) ? data : (data.results ?? []);
        results = rows;
        totalCount = rows.length;
        suggestLive = data.suggest_live ?? false;
        sourceFilter = 'all';
      })
      .catch(() => { results = []; totalCount = 0; })
      .finally(() => { loading = false; });
  });

  function handleSelect(item) {
    // Dispatch ambolt:select event for ServerSearchInput
    document.dispatchEvent(new CustomEvent('ambolt:select', {
      detail: { inputId: 'kpi_search', value: item.value, label: item.label }
    }));
    onSelect(item);
  }
</script>

{#if loading}
  <div class="srp-loading">Söker...</div>
{:else if query && results.length === 0}
  <div class="srp-empty">Inga träffar för "{query}".</div>
{:else if results.length > 0}
  <div class="srp">
    <div class="srp-header">
      <span class="srp-count">{totalCount} träffar för "{query}"</span>
      {#if uniqueSources.length > 1}
        <div class="srp-filters">
          <button class="srp-filter-btn" class:active={sourceFilter === 'all'}
                  onclick={() => sourceFilter = 'all'}>Alla</button>
          {#each uniqueSources as src}
            <button class="srp-filter-btn" class:active={sourceFilter === src}
                    onclick={() => sourceFilter = src}>{src}</button>
          {/each}
        </div>
      {/if}
    </div>

    {#each grouped as [source, items]}
      <div class="srp-group">
        <div class="srp-group-label">{source}</div>
        {#each items as item}
          {@const eid = item.entity_id?.includes('\x1f') ? item.entity_id.replace('\x1f', ' / ') : item.entity_id}
          <div class="srp-card">
            <div class="srp-card-header">
              <span class="srp-card-title" title={item.label}>{item.label}</span>
              <span class="srp-card-source">{item.source}</span>
            </div>
            <div class="srp-card-subtitle">
              {#if item.category}<span class="srp-card-category">{item.category}</span>{/if}
              {#if eid}<span class="srp-card-id">{eid}</span>{/if}
            </div>
            {#if item.description}
              <div class="srp-card-desc">{item.description}</div>
            {/if}
            <div class="srp-card-actions">
              <button class="srp-btn srp-btn-primary" onclick={() => handleSelect(item)}>
                Visa direkt
              </button>
              {#if basket.has(item.value)}
                <button class="srp-btn srp-btn-basket srp-in-basket" disabled>
                  I korg ✓
                </button>
              {:else}
                <button class="srp-btn srp-btn-basket" onclick={() => onBasket(item)}>
                  + Lägg i korg
                </button>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    {/each}
  </div>
{/if}

<style>
  .srp {
    padding: 0.5rem 0;
  }
  .srp-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-bottom: 1rem;
  }
  .srp-count {
    font-size: 0.9rem;
    font-weight: 500;
    color: #4A5568;
  }
  .srp-filters {
    display: flex;
    gap: 0.25rem;
  }
  .srp-filter-btn {
    font-size: 0.75rem;
    padding: 0.2rem 0.6rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    background: white;
    color: #4A5568;
    cursor: pointer;
    font-family: inherit;
  }
  .srp-filter-btn.active {
    background: #0B7A75;
    color: white;
    border-color: #0B7A75;
  }
  .srp-group {
    margin-bottom: 1rem;
  }
  .srp-group-label {
    font-size: 0.7rem;
    font-weight: 600;
    color: #A0AEC0;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    padding: 0.3rem 0;
    border-bottom: 1px solid #E2E8F0;
    margin-bottom: 0.5rem;
  }
  .srp-card {
    padding: 0.75rem 1rem;
    border: 1px solid #E2E8F0;
    border-radius: 8px;
    margin-bottom: 0.4rem;
    background: white;
    transition: border-color 0.15s;
  }
  .srp-card:hover {
    border-color: #CCE6E5;
  }
  .srp-card-header {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
  }
  .srp-card-title {
    font-size: 0.95rem;
    font-weight: 600;
    color: #2D3748;
    flex: 1;
    overflow-wrap: break-word;
  }
  .srp-card-source {
    flex-shrink: 0;
    font-size: 0.65rem;
    font-weight: 600;
    color: #0B7A75;
    background: #EBF5F5;
    padding: 0.1rem 0.4rem;
    border-radius: 3px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }
  .srp-card-subtitle {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem 0.6rem;
    align-items: baseline;
    margin-top: 0.2rem;
  }
  .srp-card-category {
    font-size: 0.78rem;
    color: #0B7A75;
  }
  .srp-card-id {
    font-size: 0.72rem;
    color: #A0AEC0;
    font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
  }
  .srp-card-desc {
    font-size: 0.82rem;
    color: #4A5568;
    margin-top: 0.25rem;
    line-height: 1.4;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }
  .srp-card-actions {
    display: flex;
    gap: 0.4rem;
    margin-top: 0.5rem;
    justify-content: flex-end;
  }
  .srp-btn {
    font-size: 0.78rem;
    font-weight: 500;
    padding: 0.3rem 0.7rem;
    border-radius: 4px;
    border: 1px solid;
    cursor: pointer;
    font-family: inherit;
    transition: all 0.15s;
  }
  .srp-btn-primary {
    background: #0B7A75;
    color: white;
    border-color: #0B7A75;
  }
  .srp-btn-primary:hover {
    background: #065956;
    border-color: #065956;
  }
  .srp-btn-basket {
    background: white;
    color: #0B7A75;
    border-color: #CCE6E5;
  }
  .srp-btn-basket:hover:not(:disabled) {
    background: #EBF5F5;
    border-color: #0B7A75;
  }
  .srp-in-basket {
    background: #EBF5F5;
    color: #065956;
    cursor: default;
  }
  .srp-loading, .srp-empty {
    padding: 2rem;
    text-align: center;
    color: #A0AEC0;
    font-style: italic;
  }
</style>
