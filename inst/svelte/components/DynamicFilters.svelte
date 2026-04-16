<script>
  // DynamicFilters — Smart filter component that fetches a filter_spec
  // and renders adaptive controls.
  //
  // Watches a "trigger value" prop (typically the value of another input
  // like kpi_search). When it changes, fetches the spec endpoint with
  // that value, gets back a filter_spec, and renders FilterRenderer.
  //
  // Filter values are maintained as a Svelte $state object and serialized
  // to a JSON string exposed via `bind:value` so other ambolt outputs
  // can read them via depends_on params (parsed in R with jsonlite).
  //
  // Props:
  //   id                  — input id
  //   spec_endpoint       — API URL returning filter_spec JSON
  //   trigger_value       — value of dependency input (refetch on change)
  //   trigger_param_name  — query param name when fetching spec (default "value")
  //   value               — bindable JSON string of current filter values
  //   year_min, year_max  — bounds for time-class range sliders

  import FilterRenderer from './FilterRenderer.svelte';

  let {
    id = '',
    spec_endpoint = '',
    trigger_value = '',
    trigger_param_name = 'value',
    value = $bindable('{}'),
    year_min = 1990,
    year_max = 2030
  } = $props();

  let spec = $state(null);
  let loading = $state(false);
  let error = $state(null);
  let filterValues = $state({});

  async function fetchSpec(triggerVal) {
    if (!triggerVal) {
      spec = null;
      filterValues = {};
      value = '{}';
      return;
    }
    loading = true;
    error = null;
    try {
      const url = new URL(spec_endpoint, window.location.origin);
      url.searchParams.set(trigger_param_name, triggerVal);
      const res = await fetch(url.toString());
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      spec = data;
      filterValues = {};
    } catch (err) {
      error = err.message;
      spec = null;
    } finally {
      loading = false;
    }
  }

  // Refetch spec when trigger value changes
  $effect(() => {
    fetchSpec(trigger_value);
  });

  // Serialize filter values to JSON string for ambolt's depends_on mechanism
  $effect(() => {
    value = JSON.stringify(filterValues);
  });
</script>

<div class="dynamic-filters" {id}>
  {#if error}
    <div class="dynamic-filters-error">Kunde inte ladda filter: {error}</div>
  {:else if loading}
    <div class="dynamic-filters-loading">Laddar filter...</div>
  {:else if spec}
    <FilterRenderer
      {spec}
      bind:value={filterValues}
      yearMin={year_min}
      yearMax={year_max}
    />
  {:else}
    <div class="dynamic-filters-empty">Välj ett nyckeltal för att se filter.</div>
  {/if}
</div>

<style>
  .dynamic-filters {
    width: 100%;
  }
  .dynamic-filters-error {
    padding: 0.6rem;
    background: #FEF2F2;
    color: #DC2626;
    border-radius: 4px;
    font-size: 0.85rem;
  }
  .dynamic-filters-loading,
  .dynamic-filters-empty {
    padding: 0.6rem;
    color: #6b7280;
    font-style: italic;
    font-size: 0.85rem;
  }
</style>
