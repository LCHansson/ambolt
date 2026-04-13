<script>
  // HtmlOutput — Framework component for displaying R-generated HTML
  //
  // Shiny equivalent: htmlOutput(outputId) / uiOutput(outputId)
  //
  // Divergence from Shiny: Shiny's uiOutput can render arbitrary UI
  // including inputs and outputs. This is simpler — it renders a static
  // HTML string returned by the server. No nested reactive bindings.
  //
  // Why: Covers the common case of dynamic text/HTML content (status
  // messages, score cards, formatted summaries) without the complexity
  // of full server-side UI rendering.
  //
  // Props:
  //   id       — unique identifier (like Shiny's outputId)
  //   endpoint — API URL path (e.g., "/api/output/summary")
  //   params   — object of key-value pairs sent as query parameters
  //   baseUrl  — API base URL (defaults to current page origin)
  //   trigger  — optional; when set, the component only fetches when this
  //              value changes, not on every param change.

  import { createFetchState } from './fetchData.svelte.js';
  import { events } from './eventBus.svelte.js';

  let {
    id = '',
    endpoint = '',
    params = {},
    baseUrl = '',
    trigger = undefined,
    refreshEvent = '',
    class: className = ''
  } = $props();

  const fetch_state = createFetchState(
    () => ({ endpoint, params, baseUrl, trigger }),
    'text'
  );

  // Re-fetch when a named event fires (e.g., after form submit or page enter)
  $effect(() => {
    if (!refreshEvent) return;
    const handler = () => fetch_state.refetch();
    events.on(refreshEvent, handler);
    return () => events.off(refreshEvent, handler);
  });
</script>

<div class="ambolt-html-output {className}" data-output-id={id}>
  {#if fetch_state.error}
    <p class="error">Content error: {fetch_state.error}</p>
  {:else if fetch_state.loading}
    <div class="loading">Loading...</div>
  {:else if fetch_state.data}
    {@html fetch_state.data}
  {/if}
</div>

<style>
  .ambolt-html-output {
    min-height: 1rem;
  }
  .error {
    color: #dc2626;
    font-weight: bold;
  }
  .loading {
    color: #6b7280;
  }
</style>
