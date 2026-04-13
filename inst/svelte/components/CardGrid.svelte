<script>
  // CardGrid — Interactive card grid for ambolt apps
  //
  // Shiny equivalent: No direct equivalent. Like DataTable but renders cards
  // instead of rows. Supports endpoint fetching, client-side filtering,
  // search, pagination, and rich card content.
  //
  // Props:
  //   endpoint    — API URL path for data fetching (JSON array)
  //   params      — query parameters for the endpoint
  //   baseUrl     — API base URL (defaults to current page origin)
  //   card        — field mappings: { title, subtitle, badge, badge_label,
  //                 footer, border_color, badge_color }
  //   fields      — array of { key, icon, link, badge, badge_color_key, label }
  //                 for structured card content below title/subtitle
  //   onclick     — callback (item) => void for card clicks
  //   searchable  — show search input (default false)
  //   pageSize    — items per page (0 = show all, default 50)
  //   filters     — array of { key, label, choices: [{value, label}] }
  //   refreshEvent — event name that triggers a re-fetch
  //   minWidth    — minimum card width in pixels (default 260)

  import { createFetchState } from './fetchData.svelte.js';
  import { events } from './eventBus.svelte.js';
  import { postData } from './mutations.js';

  let {
    id = '',
    endpoint = '',
    params = {},
    baseUrl = '',
    card = {},
    fields = [],
    onclick = undefined,
    searchable = false,
    pageSize = 0,
    filters = [],
    refreshEvent = '',
    minWidth = 260,
    favorite = null,  // { key: 'is_favorite', id_key: 'id', endpoint: '/api/contacts/favorite/{id}' }
    contactAction = null,  // { event: 'ambolt:contact-action', nameKey: 'name', partyKey: 'party', modalTemplate: 'interactions/create?contact_id={id}&type={type}' }
    labels = {},  // { search: 'Sök...', noResults: 'Inga resultat', showing: 'av' }
    class: className = ''
  } = $props();

  const fetch_state = createFetchState(
    () => ({ endpoint, params, baseUrl }),
    'json'
  );

  // Re-fetch when a named event fires
  $effect(() => {
    if (!refreshEvent) return;
    const handler = () => fetch_state.refetch();
    events.on(refreshEvent, handler);
    return () => events.off(refreshEvent, handler);
  });

  // Filter chip dropdown state
  let openFilter = $state(null);
  $effect(() => {
    function closeFilters(e) { if (!e.target.closest('.filter-chip')) openFilter = null; }
    document.addEventListener('click', closeFilters);
    return () => document.removeEventListener('click', closeFilters);
  });

  // Handle both array-of-objects and R's column-oriented JSON format
  let allItems = $derived.by(() => {
    const raw = fetch_state.data;
    if (!raw) return [];
    if (Array.isArray(raw)) return raw;
    // Column-oriented: {col1: [...], col2: [...]} → [{col1: v1, col2: v2}, ...]
    const keys = Object.keys(raw);
    if (keys.length === 0) return [];
    const firstCol = raw[keys[0]];
    if (!Array.isArray(firstCol)) return [];
    const len = firstCol.length;
    const rows = [];
    for (let i = 0; i < len; i++) {
      const row = {};
      for (const k of keys) {
        row[k] = raw[k]?.[i] ?? null;
      }
      rows.push(row);
    }
    return rows;
  });
  let clickable = $derived(onclick != null);

  // ── Filter state ──
  let filterValues = $state({});
  let searchQuery = $state('');
  let displayCount = $state(50);
  // Sync with pageSize prop
  $effect(() => { if (pageSize > 0) displayCount = pageSize; });

  // Reset pagination when filters/search change
  $effect(() => {
    void searchQuery;
    void filterValues;
    displayCount = pageSize || 50;
  });

  // ── Derived data pipeline: filter → search → paginate ──
  let filtered = $derived.by(() => {
    let items = allItems;

    // Apply dropdown filters
    for (const f of filters) {
      const val = filterValues[f.key];
      if (val && val !== '') {
        if (f.min_match) {
          // Numeric "minimum" filter (e.g., engagement >= value)
          items = items.filter(item => (item[f.key] ?? 0) >= Number(val));
        } else {
          items = items.filter(item => String(item[f.key] ?? '') === val);
        }
      }
    }

    // Apply text search
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const searchFields = card.title ? [card.title] : [];
      if (card.subtitle) searchFields.push(card.subtitle);
      // Also search in field keys
      for (const f of fields) {
        if (f.key) searchFields.push(f.key);
      }
      items = items.filter(item =>
        searchFields.some(key => {
          const val = item[key];
          return val != null && String(val).toLowerCase().includes(q);
        })
      );
    }

    return items;
  });

  let visibleItems = $derived(
    displayCount > 0 ? filtered.slice(0, displayCount) : filtered
  );

  let hasMore = $derived(displayCount > 0 && filtered.length > displayCount);

  // ── Favorite toggle ──
  async function toggleFavorite(e, item) {
    e.stopPropagation();
    if (!favorite) return;
    const itemId = item[favorite.id_key || 'id'];
    const url = favorite.endpoint.replace('{id}', itemId);
    try {
      const result = await postData(url, {});
      // Update the item's favorite state in the local data
      const idx = allItems.findIndex(i => i[favorite.id_key || 'id'] === itemId);
      if (idx >= 0) {
        allItems[idx] = { ...allItems[idx], [favorite.key]: result.is_favorite };
        allItems = [...allItems]; // trigger reactivity
      }
    } catch { /* ignore */ }
  }

  function showMore() {
    displayCount += (pageSize || 50);
  }

  // ── Badge color helper ──
  function getBadgeStyle(item, colorKey) {
    if (!colorKey || !item[colorKey]) return '';
    const bg = item[colorKey];
    // Use white text for dark backgrounds, dark for light (simple heuristic)
    const isLight = bg === '#DDDD00' || bg === '#83CF39' || bg === '#52BDEC';
    const fg = isLight ? '#333' : 'white';
    return `background:${bg};color:${fg};`;
  }
</script>

<div class="ambolt-card-grid-container {className}" data-output-id={id}>
  {#if filters.length > 0 || searchable}
    <div class="card-toolbar">
      {#if searchable}
        <input
          type="text"
          class="card-search"
          placeholder={labels.search || "Search..."}
          bind:value={searchQuery}
        />
      {/if}
      {#each filters as filter}
        {#if filter.toggle}
          <button
            class="card-filter-toggle"
            class:active={filterValues[filter.key] === 'true'}
            onclick={() => {
              const cur = filterValues[filter.key];
              filterValues = { ...filterValues, [filter.key]: cur === 'true' ? '' : 'true' };
            }}
            title={filter.label}
          >{filter.label}</button>
        {:else}
          <div class="filter-chip">
            <button class="filter-chip-button" onclick={(e) => {
              e.stopPropagation();
              openFilter = openFilter === filter.key ? null : filter.key;
            }}>
              <span class="filter-chip-label">{filter.label} ▾</span>
              <span class="filter-chip-value">{filter.choices.find(c => c.value === (filterValues[filter.key] ?? ''))?.label || filter.choices[0]?.label || 'Alla'}</span>
            </button>
            {#if openFilter === filter.key}
              <div class="filter-chip-dropdown">
                {#each filter.choices as choice}
                  <button class="filter-chip-item" class:active={(filterValues[filter.key] ?? '') === choice.value}
                    onclick={() => { filterValues = { ...filterValues, [filter.key]: choice.value }; openFilter = null; }}>
                    {choice.label}
                  </button>
                {/each}
              </div>
            {/if}
          </div>
        {/if}
      {/each}
      {#if !fetch_state.loading && !fetch_state.error}
        <span class="card-count">{filtered.length} {labels.of || "of"} {allItems.length}</span>
      {/if}
    </div>
  {/if}

  {#if fetch_state.error}
    <p class="error">Kunde inte ladda data: {fetch_state.error}</p>
  {:else if fetch_state.loading}
    <p class="loading">Laddar...</p>
  {:else if visibleItems.length === 0}
    <p class="empty">{labels.noResults || "No results match the filters."}</p>
  {:else}
    <div class="ambolt-card-grid" style="grid-template-columns: repeat(auto-fill, minmax({minWidth}px, 1fr));">
      {#each visibleItems as item}
        <!-- svelte-ignore a11y_no_noninteractive_tabindex -->
        <div
          class="ambolt-card"
          class:clickable
          onclick={() => clickable && onclick(item)}
          role={clickable ? 'button' : undefined}
          tabindex={clickable ? 0 : undefined}
          onkeydown={(e) => {
            if (clickable && (e.key === 'Enter' || e.key === ' ')) {
              e.preventDefault();
              onclick(item);
            }
          }}
          style={card.border_color && item[card.border_color] ? `border-left: 4px solid ${item[card.border_color]};` : ''}
        >
          <!-- Backdrop icon -->
          {#if card.icon && item[card.icon]}
            <i class="bi bi-{item[card.icon]} card-backdrop-icon"></i>
          {/if}

          <!-- Favorite star -->
          {#if favorite}
            <button
              class="card-star"
              class:starred={item[favorite.key]}
              onclick={(e) => toggleFavorite(e, item)}
              aria-label={item[favorite.key] ? 'Ta bort favorit' : 'Lägg till favorit'}
            >
              <i class="bi" class:bi-star-fill={item[favorite.key]} class:bi-star={!item[favorite.key]}></i>
            </button>
          {/if}

          <!-- Badge (top-right corner) -->
          {#if card.badge && item[card.badge] != null}
            <span
              class="ambolt-badge badge-corner"
              style={getBadgeStyle(item, card.badge_color)}
            >
              {item[card.badge]}
            </span>
          {/if}

          <!-- Title -->
          {#if card.title && item[card.title] != null}
            <div class="card-title">{item[card.title]}</div>
          {/if}

          <!-- Subtitle -->
          {#if card.subtitle && item[card.subtitle] != null}
            <div class="card-subtitle">{item[card.subtitle]}</div>
          {/if}

          <!-- Rich fields -->
          {#if fields.length > 0}
            <div class="card-fields">
              {#each fields as field}
                {#if item[field.key] != null && item[field.key] !== '' && item[field.key] !== 'NA'}
                  <div class="card-field">
                    {#if field.render === 'badges'}
                      {@const badges = (item[field.key] || '').split(', ').filter(Boolean)}
                      {#if badges.length > 0}
                        <div class="topic-badges">
                          {#each badges as badge}
                            {@const color = field.colors?.[badge] || '#666'}
                            <span class="topic-badge" style="background:{color}22;color:{color}">{badge}</span>
                          {/each}
                        </div>
                      {/if}
                    {:else if field.badge}
                      <span
                        class="field-badge {field.class_key && item[field.class_key] ? item[field.class_key] : ''}"
                        style={!field.class_key ? getBadgeStyle(item, field.badge_color_key) : ''}
                      >{item[field.key]}</span>
                    {:else if field.link === 'mailto'}
                      <a href="mailto:{item[field.key]}" class="card-link" onclick={(e) => {
                        e.stopPropagation();
                        if (contactAction) {
                          const ca = contactAction;
                          window.dispatchEvent(new CustomEvent(ca.event || 'ambolt:contact-action', { detail: {
                            contactId: item.id, contactName: item[ca.nameKey || 'name'] || '', party: item[ca.partyKey || 'party'] || '',
                            type: 'utskick',
                            modal: (ca.modalTemplate || '').replace('{id}', item.id).replace('{type}', 'utskick')
                          }}));
                        }
                      }}>
                        {#if field.icon}<i class="bi bi-{field.icon}"></i>{/if}
                        {item[field.key]}
                      </a>
                    {:else if field.link === 'tel'}
                      <a href="tel:{item[field.key]}" class="card-link" onclick={(e) => {
                        e.stopPropagation();
                        if (contactAction) {
                          const ca = contactAction;
                          window.dispatchEvent(new CustomEvent(ca.event || 'ambolt:contact-action', { detail: {
                            contactId: item.id, contactName: item[ca.nameKey || 'name'] || '', party: item[ca.partyKey || 'party'] || '',
                            type: 'samtal',
                            modal: (ca.modalTemplate || '').replace('{id}', item.id).replace('{type}', 'samtal')
                          }}));
                        }
                      }}>
                        {#if field.icon}<i class="bi bi-{field.icon}"></i>{/if}
                        {item[field.key]}
                      </a>
                    {:else}
                      <span class="field-text">
                        {#if field.icon}<i class="bi bi-{field.icon}"></i>{/if}
                        {item[field.key]}
                      </span>
                    {/if}
                  </div>
                {/if}
              {/each}
            </div>
          {/if}

          <!-- Footer -->
          {#if card.footer && item[card.footer] != null}
            <div class="card-footer">{item[card.footer]}</div>
          {/if}
        </div>
      {/each}
    </div>

    {#if hasMore}
      <div class="card-show-more">
        <button onclick={showMore}>
          Visa fler ({filtered.length - displayCount} kvar)
        </button>
      </div>
    {/if}
  {/if}
</div>

<style>
  .ambolt-card-grid-container {
    width: 100%;
  }

  /* ── Toolbar: search + filters ── */
  .card-toolbar {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    align-items: center;
    margin-bottom: 0.75rem;
  }
  .card-search {
    padding: 0.4rem 0.6rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 0.85rem;
    min-width: 180px;
    outline: none;
  }
  .card-search:focus {
    border-color: var(--ambolt-primary, #4f46e5);
  }
  .filter-chip {
    position: relative;
  }
  .filter-chip-button {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    padding: 4px 8px;
    border: none;
    background: none;
    border-radius: 4px;
    cursor: pointer;
    transition: background 0.15s;
  }
  .filter-chip-button:hover {
    background: rgba(0,0,0,0.04);
  }
  .filter-chip-label {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--ambolt-primary, #006589);
  }
  .filter-chip-value {
    font-size: 0.85rem;
    color: #888;
  }
  .filter-chip-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    z-index: 100;
    min-width: 160px;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    padding: 0.25rem 0;
    margin-top: 2px;
  }
  .filter-chip-item {
    display: block;
    width: 100%;
    text-align: left;
    padding: 0.35rem 0.75rem;
    border: none;
    background: none;
    font-size: 0.85rem;
    color: #374151;
    cursor: pointer;
  }
  .filter-chip-item:hover {
    background: #f3f4f6;
  }
  .filter-chip-item.active {
    background: var(--ambolt-primary, #006589);
    color: white;
  }
  .card-filter-toggle {
    padding: 0.3rem 0.6rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 0.85rem;
    background: white;
    color: #6b7280;
    cursor: pointer;
    transition: all 0.15s;
  }
  .card-filter-toggle:hover {
    border-color: #f59e0b;
    color: #f59e0b;
  }
  .card-filter-toggle.active {
    background: #fef3c7;
    border-color: #f59e0b;
    color: #b45309;
  }
  .card-count {
    font-size: 0.8rem;
    color: #6b7280;
    margin-left: auto;
  }

  /* ── Grid ── */
  .ambolt-card-grid {
    display: grid;
    gap: 0.75rem;
  }

  /* ── Cards ── */
  .ambolt-card {
    position: relative;
    padding: 0.85rem 1rem;
    background: white;
    border: 1px solid var(--ambolt-card-border, #e5e7eb);
    border-radius: var(--ambolt-radius-md, 6px);
    transition: box-shadow 0.15s ease;
  }
  .ambolt-card.clickable {
    cursor: pointer;
  }
  .ambolt-card.clickable:hover {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  }
  .ambolt-card.clickable:focus-visible {
    outline: 2px solid var(--ambolt-primary, #4f46e5);
    outline-offset: 2px;
  }
  .card-title {
    font-weight: 600;
    font-size: 0.95rem;
    margin-bottom: 0.15rem;
    padding-right: 3.5rem; /* space for badge */
  }
  .card-subtitle {
    color: #6b7280;
    font-size: 0.85rem;
    margin-bottom: 0.3rem;
  }
  .card-footer {
    color: #9ca3af;
    font-size: 0.8rem;
    margin-top: 0.4rem;
  }

  /* ── Badge ── */
  .ambolt-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.1rem 0.45rem;
    border-radius: var(--ambolt-badge-radius, 3px);
    font-size: 0.75rem;
    font-weight: var(--ambolt-badge-weight, 600);
    background: var(--ambolt-badge-bg, var(--ambolt-primary-muted, #e0e7ff));
    color: var(--ambolt-badge-color, var(--ambolt-primary, #4f46e5));
  }
  .badge-corner {
    position: absolute;
    top: 0.7rem;
    right: 0.7rem;
  }

  /* ── Backdrop icon ── */
  .card-backdrop-icon {
    position: absolute;
    right: 0.8rem;
    top: 50%;
    transform: translateY(-50%);
    font-size: 3rem;
    color: rgba(0, 0, 0, 0.045);
    pointer-events: none;
    line-height: 1;
    z-index: 0;
  }
  .ambolt-card:has(.card-backdrop-icon) .card-title,
  .ambolt-card:has(.card-backdrop-icon) .card-subtitle,
  .ambolt-card:has(.card-backdrop-icon) .card-footer,
  .ambolt-card:has(.card-backdrop-icon) .card-fields {
    position: relative;
    z-index: 1;
  }

  /* ── Favorite star ── */
  .card-star {
    position: absolute;
    top: 2.2rem;
    right: 0.7rem;
    background: none;
    border: none;
    cursor: pointer;
    font-size: 0.85rem;
    color: #d1d5db;
    padding: 0.1rem;
    line-height: 1;
    transition: color 0.15s;
    z-index: 1;
  }
  .card-star:hover { color: #f59e0b; }
  .card-star.starred { color: #f59e0b; }

  /* ── Rich fields ── */
  .card-fields {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
    margin-top: 0.3rem;
  }
  .card-field {
    font-size: 0.82rem;
  }
  .card-link {
    color: var(--ambolt-primary, #006589);
    text-decoration: none;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 100%;
    display: inline-block;
  }
  .card-link:hover {
    text-decoration: underline;
  }
  .card-link i, .field-text i {
    margin-right: 0.3rem;
    font-size: 0.75rem;
    opacity: 0.7;
  }
  .field-text {
    color: #6b7280;
  }
  .field-badge {
    display: inline-block;
    padding: 0.1rem 0.5rem;
    border-radius: 10px;
    font-size: 0.75rem;
    font-weight: 500;
    color: white;
    background: #6b7280;
  }
  .topic-badges {
    display: flex;
    flex-wrap: wrap;
    gap: 0.2rem;
  }
  .topic-badge {
    display: inline-block;
    padding: 0.1rem 0.4rem;
    border-radius: 4px;
    font-size: 0.7rem;
    font-weight: 600;
  }

  /* ── Pagination ── */
  .card-show-more {
    text-align: center;
    margin-top: 1rem;
  }
  .card-show-more button {
    padding: 0.4rem 1.2rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 0.85rem;
    cursor: pointer;
    background: white;
    color: #374151;
  }
  .card-show-more button:hover {
    background: #f3f4f6;
  }

  /* ── States ── */
  .error { color: #dc2626; }
  .loading { color: #6b7280; }
  .empty { color: #6b7280; font-size: 0.9rem; }

  /* ── Mobile ── */
  @media (max-width: 480px) {
    .ambolt-card-grid {
      grid-template-columns: 1fr !important;
      gap: 0.5rem;
    }
    .card-toolbar {
      gap: 0.4rem;
    }
    .card-search {
      width: 100%;
    }
    .ambolt-card {
      padding: 0.6rem 0.75rem;
    }
    .filter-chip-dropdown {
      min-width: 140px;
      max-width: calc(100vw - 2rem);
    }
  }
</style>
