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
  let multiMode = $state(false);  // true when multi-KPI trigger is active

  // Update filter values AND the serialized `value` prop synchronously, in the
  // SAME call. Do NOT serialize in a separate $effect: writing a $bindable from
  // an $effect lands in a later update cycle, so downstream outputs (the chart)
  // read `value` one change behind — the "lag-by-one" filter bug.
  function setFilterValues(v) {
    filterValues = v;
    value = JSON.stringify(v);
  }

  // Keep only the part of a preserved value that is still VALID under dim `d`.
  // Range dims: keep as-is (FilterRenderer clamps to the new min/max).
  // Categorical dims with a known value set: intersect against the new codes.
  // Server-backed lookups (no inline values): leave untouched. Returns
  // undefined when a single-select value is no longer valid → FilterRenderer
  // re-fills the dim default (Totalt) instead of keeping a dead selection.
  function pruneValue(d, v) {
    if (!d) return v;
    if (d.type === 'range') {
      // Clamp a preserved range into the NEW dim bounds. Otherwise a handle
      // (e.g. the min-year) keeps a value outside the new KPI's extent — the
      // slider track shows [min,max] but the selected handle sits off-track.
      if (!Array.isArray(v) || v.length < 2) return v;
      if (d.min == null || d.max == null) return v;
      let a = Math.max(v[0], d.min);
      let b = Math.min(v[1], d.max);
      if (a > b) { a = d.min; b = d.max; }   // fully out of range → reset
      return [a, b];
    }
    if (!d.values || d.values.length === 0) return v;
    const codes = new Set(d.values.map(x => x.code));
    if (Array.isArray(v)) return v.filter(x => codes.has(x));
    return codes.has(v) ? v : undefined;
  }

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
      // Preserve existing filter values, but only those still VALID under the
      // new spec. Drop dims that no longer exist AND prune selected codes that
      // are not in the new dim value set. A stale-but-name-matching selection
      // would otherwise trap the control disabled (dimCompat) or silently
      // filter the new KPI on a code it does not have.
      const byName = {};
      for (const d of (data.dimensions ?? [])) byName[d.name] = d;
      const preserved = {};
      for (const [k, v] of Object.entries(filterValues)) {
        const d = byName[k];
        if (!d) continue;
        const pv = pruneValue(d, v);
        if (pv !== undefined) preserved[k] = pv;
      }
      setFilterValues(preserved);
    } catch (err) {
      error = err.message;
      spec = null;
    } finally {
      loading = false;
    }
  }

  // Refetch spec when trigger value changes (skip if multi-mode is active)
  $effect(() => {
    if (!multiMode) {
      fetchSpec(trigger_value);
    }
  });

  // KPI → view letter mapping (set by MultiViewPanel for badge display)
  let kpiViewMap = $state({});

  // Listen for multi-KPI trigger override from MultiViewPanel
  $effect(() => {
    function handleMultiTrigger(e) {
      if (e.detail?.kpiViewMap) {
        kpiViewMap = e.detail.kpiViewMap;
      }
      const values = (e.detail?.values ?? []).filter(Boolean);
      if (values.length > 0) {
        multiMode = true;
        fetchSpec(values.join(','));
      } else if (multiMode) {
        // Multi-view emptied → hand control back to the single-KPI trigger.
        // Without this, multiMode latched true forever after any multi-view
        // use, so later single-KPI selections never refetched their filter
        // spec (stale/disabled filters, old series hanging on).
        multiMode = false;
        fetchSpec(trigger_value);
      }
    }
    document.addEventListener('ambolt:filter-trigger', handleMultiTrigger);
    return () => document.removeEventListener('ambolt:filter-trigger', handleMultiTrigger);
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
      bind:value={
        () => filterValues,
        (v) => setFilterValues(v)
      }
      yearMin={year_min}
      yearMax={year_max}
      {kpiViewMap}
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
