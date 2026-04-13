<script>
  // PlotOutput — Framework component for displaying R-generated plots
  //
  // Shiny equivalent: plotOutput(outputId)
  //
  // Divergence from Shiny: instead of Shiny's implicit wiring where the server
  // pushes plot updates, this component fetches from an explicit API endpoint.
  // The `params` prop determines what gets sent to R — when params change,
  // the component automatically re-fetches.
  //
  // Why: In our stateless architecture, the client pulls data rather than the
  // server pushing it. This eliminates WebSocket dependency and makes the app
  // resilient to disconnection — the plot simply re-fetches when needed.
  //
  // Props:
  //   id       — unique identifier (like Shiny's outputId)
  //   endpoint — API URL path (e.g., "/api/plot")
  //   params   — object of key-value pairs sent as query parameters
  //   baseUrl  — API base URL (defaults to current page origin)
  //   trigger  — optional; when set, the component only fetches when this
  //              value changes (e.g., an action button click counter),
  //              not on every param change. Omit for auto-fetch behavior.

  import { createFetchState } from './fetchData.svelte.js';

  let {
    id = '',
    endpoint = '',
    params = {},
    baseUrl = '',
    trigger = undefined
  } = $props();

  const fetch_state = createFetchState(
    () => ({ endpoint, params, baseUrl, trigger }),
    'text'
  );
</script>

<div class="ambolt-plot-output" data-output-id={id}>
  {#if fetch_state.error}
    <p class="error">Plot error: {fetch_state.error}</p>
  {:else if fetch_state.loading}
    <div class="loading">Loading plot...</div>
  {:else}
    {@html fetch_state.data}
  {/if}
</div>

<style>
  .ambolt-plot-output {
    border: 1px solid #d1d5db;
    border-radius: 4px;
    padding: 1rem;
    background: white;
    display: flex;
    justify-content: center;
    min-height: 100px;
  }
  .error {
    color: #dc2626;
    font-weight: bold;
  }
  .loading {
    color: #6b7280;
    display: flex;
    align-items: center;
  }
</style>
