<script>
  // DataTable — Interactive data table for ambolt apps
  //
  // Shiny equivalent: DT::dataTableOutput / DT::renderDataTable
  //
  // Features: column sorting, global search, pagination, row selection.
  // All processing is client-side (fine for ≤5,000 rows).
  //
  // Props:
  //   id         — unique identifier
  //   endpoint   — API URL path for data fetching
  //   params     — query parameters for the endpoint
  //   baseUrl    — API base URL (defaults to current page origin)
  //   columns    — array of { key, label, sortable, render }
  //   trigger    — action button counter (gates fetching)
  //   pageSize   — rows per page (0 = no pagination)
  //   searchable — show global search input
  //   selectable — enable row click selection
  //   onselect   — callback (row) => void

  import { createFetchState } from './fetchData.svelte.js';
  import { events } from './eventBus.svelte.js';
  import { putData } from './mutations.js';

  let {
    id = '',
    endpoint = '',
    params = {},
    baseUrl = '',
    columns = null,
    trigger = undefined,
    pageSize = 0,
    searchable = false,
    selectable = false,
    onselect = undefined,
    refreshEvent = '',
    class: className = ''
  } = $props();

  const fetch_state = createFetchState(
    () => ({ endpoint, params, baseUrl, trigger }),
    'json'
  );

  // Re-fetch when a named event fires (e.g., after form modal submit)
  $effect(() => {
    if (!refreshEvent) return;
    const handler = () => fetch_state.refetch();
    events.on(refreshEvent, handler);
    return () => events.off(refreshEvent, handler);
  });

  let allRows = $derived(fetch_state.data ?? []);

  // Auto-detect columns from first row if not explicitly provided
  let displayColumns = $derived(
    columns ??
    (allRows.length > 0
      ? Object.keys(allRows[0]).map(key => ({ key, label: key.replace(/_/g, ' ') }))
      : [])
  );

  // ── Sort state ──
  let sortKey = $state(null);
  let sortDir = $state('asc');

  function toggleSort(key) {
    if (sortKey === key) {
      sortDir = sortDir === 'asc' ? 'desc' : 'asc';
    } else {
      sortKey = key;
      sortDir = 'asc';
    }
    currentPage = 0;
  }

  // ── Search state ──
  let searchQuery = $state('');

  // ── Pagination state ──
  let currentPage = $state(0);

  // ── Selection state ──
  let selectedIndex = $state(-1);

  // ── Derived data pipeline: filter → sort → paginate ──
  let filtered = $derived.by(() => {
    if (!searchQuery.trim()) return allRows;
    const q = searchQuery.toLowerCase();
    return allRows.filter(row =>
      displayColumns.some(col => {
        const val = row[col.key];
        return val != null && String(val).toLowerCase().includes(q);
      })
    );
  });

  let sorted = $derived.by(() => {
    if (!sortKey) return filtered;
    const key = sortKey;
    const dir = sortDir === 'asc' ? 1 : -1;
    return [...filtered].sort((a, b) => {
      const va = a[key] ?? '';
      const vb = b[key] ?? '';
      if (typeof va === 'number' && typeof vb === 'number') {
        return (va - vb) * dir;
      }
      return String(va).localeCompare(String(vb), undefined, { numeric: true }) * dir;
    });
  });

  let totalPages = $derived(
    pageSize > 0 ? Math.ceil(sorted.length / pageSize) : 1
  );

  let paged = $derived(
    pageSize > 0
      ? sorted.slice(currentPage * pageSize, (currentPage + 1) * pageSize)
      : sorted
  );

  // Reset page when search changes
  $effect(() => {
    void searchQuery;
    currentPage = 0;
  });

  function handleRowClick(row, idx) {
    if (!selectable) return;
    selectedIndex = idx;
    if (onselect) onselect(row);
  }

  // ── Cell rendering ──
  function renderCell(value, render) {
    if (value == null) return '';
    if (!render) return String(value);
    if (render === 'badge') return value; // handled in template
    if (render === 'date') {
      try { return new Date(value).toLocaleDateString('sv-SE'); }
      catch { return String(value); }
    }
    if (render === 'number') {
      try { return Number(value).toLocaleString('sv-SE'); }
      catch { return String(value); }
    }
    return String(value);
  }

  // ── Inline edit ──
  async function handleInlineEdit(row, col, newValue) {
    if (!col.edit_endpoint) return;
    const rowId = row.id || row.Id;
    if (!rowId) return;
    const url = col.edit_endpoint.replace('{id}', rowId);
    const body = {};
    body[col.key] = newValue;
    try {
      await putData(url, body);
      // Update local data
      const idx = allRows.findIndex(r => (r.id || r.Id) === rowId);
      if (idx >= 0) {
        allRows[idx] = { ...allRows[idx], [col.key]: newValue };
        allRows = [...allRows];
      }
    } catch { /* silently ignore */ }
  }
</script>

<div class="ambolt-data-table {className}" data-output-id={id}>
  {#if fetch_state.error}
    <p class="error">Data error: {fetch_state.error}</p>
  {:else if fetch_state.loading}
    <p class="loading">Laddar data...</p>
  {:else}
    <div class="table-toolbar">
      {#if searchable}
        <input
          type="text"
          class="table-search"
          placeholder="Sök..."
          bind:value={searchQuery}
        />
      {/if}
      <span class="row-count">
        {filtered.length}{filtered.length !== allRows.length ? ` av ${allRows.length}` : ''} rader
      </span>
    </div>

    <div class="table-scroll">
      <table>
        <thead>
          <tr>
            {#each displayColumns as col}
              <th
                class:sortable={col.sortable}
                onclick={() => col.sortable && toggleSort(col.key)}
              >
                {col.label}
                {#if col.sortable && sortKey === col.key}
                  <span class="sort-indicator">{sortDir === 'asc' ? '▲' : '▼'}</span>
                {/if}
              </th>
            {/each}
          </tr>
        </thead>
        <tbody>
          {#each paged as row, i}
            <tr
              class:selectable
              class:selected={selectable && selectedIndex === currentPage * (pageSize || 0) + i}
              onclick={() => handleRowClick(row, currentPage * (pageSize || 0) + i)}
            >
              {#each displayColumns as col}
                <td>
                  {#if col.render === 'editable_select' && col.edit_choices}
                    <!-- svelte-ignore a11y_no_static_element_interactions -->
                    <select
                      class="inline-select"
                      value={row[col.key] ?? ''}
                      onchange={(e) => handleInlineEdit(row, col, e.target.value)}
                      onclick={(e) => e.stopPropagation()}
                    >
                      {#each col.edit_choices as choice}
                        <option value={choice.value}>{choice.label}</option>
                      {/each}
                    </select>
                  {:else if col.render === 'badge'}
                    <span class="ambolt-badge" data-value={row[col.key] ?? ''}>{row[col.key] ?? ''}</span>
                  {:else}
                    {renderCell(row[col.key], col.render)}
                  {/if}
                </td>
              {/each}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    {#if pageSize > 0 && totalPages > 1}
      <div class="pagination">
        <button disabled={currentPage === 0} onclick={() => currentPage--}>← Föreg.</button>
        <span class="page-info">Sida {currentPage + 1} av {totalPages}</span>
        <button disabled={currentPage >= totalPages - 1} onclick={() => currentPage++}>Nästa →</button>
      </div>
    {/if}
  {/if}
</div>

<style>
  .ambolt-data-table {
    border: var(--ambolt-table-outer-border, 1px solid #d1d5db);
    border-radius: var(--ambolt-radius-md, 6px);
    padding: 1rem;
    background: var(--ambolt-table-bg, white);
  }
  .table-toolbar {
    display: flex;
    align-items: center;
    gap: 1rem;
    margin-bottom: 0.75rem;
  }
  .table-search {
    padding: 0.4rem 0.6rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 0.9rem;
    width: 220px;
    outline: none;
  }
  .table-search:focus {
    border-color: var(--ambolt-primary, #4f46e5);
  }
  .row-count {
    color: #6b7280;
    font-size: 0.85rem;
    margin-left: auto;
  }
  .error {
    color: #dc2626;
    font-weight: bold;
  }
  .loading {
    color: #6b7280;
  }
  .table-scroll {
    overflow-x: auto;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    background: white;
  }
  th, td {
    border: var(--ambolt-table-cell-border, 1px solid #e5e7eb);
    padding: 0.4rem 0.6rem;
    text-align: left;
    font-size: 0.9rem;
  }
  th {
    background: var(--ambolt-table-header-bg, #f3f4f6);
    font-weight: var(--ambolt-table-th-weight, 600);
    position: sticky;
    top: 0;
    user-select: none;
  }
  th.sortable {
    cursor: pointer;
  }
  th.sortable:hover {
    background: #e5e7eb;
  }
  .sort-indicator {
    font-size: 0.7rem;
    margin-left: 0.3rem;
  }
  tr:nth-child(even) {
    background: var(--ambolt-table-stripe-bg, #f9fafb);
  }
  tr.selectable {
    cursor: pointer;
  }
  tr.selectable:hover {
    background: var(--ambolt-table-hover-bg, #eff6ff);
  }
  tr.selected {
    background: #dbeafe !important;
  }
  .ambolt-badge {
    display: inline-block;
    padding: 0.15rem 0.5rem;
    border-radius: var(--ambolt-badge-radius, 9999px);
    font-size: 0.8rem;
    font-weight: var(--ambolt-badge-weight, 500);
    background: var(--ambolt-badge-bg, var(--ambolt-primary-muted, #e0e7ff));
    color: var(--ambolt-badge-color, var(--ambolt-primary, #4f46e5));
  }
  .inline-select {
    padding: 0.2rem 0.4rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 0.8rem;
    background: white;
    cursor: pointer;
  }
  .inline-select:focus {
    border-color: var(--ambolt-primary, #4f46e5);
    outline: none;
  }
  .pagination {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 1rem;
    margin-top: 0.75rem;
    padding-top: 0.75rem;
    border-top: 1px solid #e5e7eb;
  }
  .pagination button {
    padding: 0.3rem 0.8rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    background: white;
    cursor: pointer;
    font-size: 0.85rem;
  }
  @media (max-width: 480px) {
    .ambolt-data-table {
      padding: 0.5rem;
    }
    th, td {
      padding: 0.3rem 0.4rem;
      font-size: 0.8rem;
    }
    .table-search {
      width: 100%;
    }
    .table-toolbar {
      flex-wrap: wrap;
    }
  }
  .pagination button:hover:not(:disabled) {
    background: #f3f4f6;
  }
  .pagination button:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
  .page-info {
    font-size: 0.85rem;
    color: #6b7280;
  }
</style>
