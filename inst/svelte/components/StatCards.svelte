<script>
  // StatCards — Responsive stat cards grid for ambolt apps
  //
  // Fetches JSON from an endpoint and renders each key as a stat card.
  // Follows the same fetch pattern as DataTable/PlotOutput.
  //
  // Props:
  //   endpoint  — API URL path for data fetching
  //   cards     — array of { key, label, color, icon } definitions
  //   baseUrl   — API base URL (defaults to current page origin)

  import { createFetchState } from './fetchData.svelte.js';

  let {
    endpoint = '',
    cards = [],
    baseUrl = '',
    class: className = ''
  } = $props();

  const fetch_state = createFetchState(
    () => ({ endpoint, params: {}, baseUrl }),
    'json'
  );

  let stats = $derived(fetch_state.data ?? {});
</script>

<div class="ambolt-stat-cards {className}">
  {#if fetch_state.error}
    <p class="error">Data error: {fetch_state.error}</p>
  {:else if fetch_state.loading}
    <p class="loading">Laddar...</p>
  {:else}
    {#each cards as card}
      <div class="ambolt-stat-card">
        <div
          class="ambolt-stat-value"
          style="color: var(--ambolt-{card.color ?? 'primary'}, #4f46e5);"
        >
          {stats[card.key] ?? '—'}
        </div>
        <div class="ambolt-stat-label">{card.label}</div>
      </div>
    {/each}
  {/if}
</div>

<style>
  .ambolt-stat-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 1rem;
  }
  .ambolt-stat-card {
    padding: 1.5rem;
    background: white;
    border: 1px solid var(--ambolt-card-border, #e5e7eb);
    border-radius: var(--ambolt-radius-md, 8px);
    text-align: center;
  }
  .ambolt-stat-value {
    font-size: 2rem;
    font-weight: 700;
  }
  .ambolt-stat-label {
    color: #6b7280;
    font-size: 0.9rem;
    margin-top: 0.25rem;
  }
  .error {
    color: #dc2626;
    font-weight: bold;
  }
  .loading {
    color: #6b7280;
  }
</style>
