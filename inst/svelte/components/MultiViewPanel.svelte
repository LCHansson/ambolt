<script>
  // MultiViewPanel — Manages N visualization views, each with per-view
  // KPI selection, viz-type selector, and ChartOutput.
  //
  // Reads from the basket store to know which KPIs are available.
  // Each view renders a ChartOutput with dynamically computed params.
  //
  // Props:
  //   filters   — current filter JSON string (from DynamicFilters)
  //   baseUrl   — API base URL

  import { basket } from './basketStore.svelte.js';
  import ChartOutput from './ChartOutput.svelte';
  import VizTypeSelector from './VizTypeSelector.svelte';
  let {
    filters = '{}',
    baseUrl = '',
  } = $props();

  // Each view: { id, kpiValues: string[], vizType: string, layout: string }
  let views = $state([]);
  let nextViewId = $state(1);

  // Auto-create initial view when basket has items and no views exist
  $effect(() => {
    if (basket.count > 0 && views.length === 0) {
      addView(basket.items.map(i => i.value));
    }
  });

  // Notify DynamicFilters about all active KPIs (for merged filter spec)
  // Also build a map of KPI → view letters for badge display
  let activeKpis = $derived([...new Set(views.flatMap(v => v.kpiValues))]);

  // Map: kpiValue → set of view letters (e.g. "kolada:N01951" → ["A", "C"])
  let kpiViewMap = $derived.by(() => {
    const map = {};
    views.forEach((v, i) => {
      const letter = viewLetter(i);
      for (const kpi of v.kpiValues) {
        if (!map[kpi]) map[kpi] = [];
        map[kpi].push(letter);
      }
    });
    return map;
  });

  $effect(() => {
    if (activeKpis.length > 0) {
      document.dispatchEvent(new CustomEvent('ambolt:filter-trigger', {
        detail: { values: activeKpis, kpiViewMap: kpiViewMap }
      }));
    }
  });

  // View index letters: A, B, C, ...
  function viewLetter(index) {
    return String.fromCharCode(65 + index);
  }

  function addView(kpiValues = []) {
    views = [...views, {
      id: nextViewId,
      kpiValues: kpiValues,
      vizType: 'timeseries',
      layout: 'overlay',
    }];
    nextViewId++;
  }

  function removeView(viewId) {
    views = views.filter(v => v.id !== viewId);
  }

  function toggleKpiInView(viewId, kpiValue) {
    views = views.map(v => {
      if (v.id !== viewId) return v;
      const has = v.kpiValues.includes(kpiValue);
      return {
        ...v,
        kpiValues: has
          ? v.kpiValues.filter(k => k !== kpiValue)
          : [...v.kpiValues, kpiValue],
      };
    });
  }

  function soloKpiInView(viewId, kpiValue) {
    views = views.map(v => v.id === viewId ? { ...v, kpiValues: [kpiValue] } : v);
  }

  function setVizType(viewId, type) {
    views = views.map(v => v.id === viewId ? { ...v, vizType: type } : v);
  }

  function setLayout(viewId, layout) {
    views = views.map(v => v.id === viewId ? { ...v, layout: layout } : v);
  }

  // Build ChartOutput params for a view
  function viewParams(view) {
    const primary = view.kpiValues[0] ?? '';
    const secondary = view.kpiValues[1] ?? '';
    return {
      kpi_search: primary,
      kpi_search2: secondary,
      filters: filters,
      viz_type: view.vizType,
      multi_layout: view.layout,
    };
  }

  // Get label for a KPI value from basket
  function kpiLabel(value) {
    const item = basket.items.find(i => i.value === value);
    return item?.label ?? value.split(':').slice(1).join(':');
  }

  // Check if map should be disabled for a view
  function mapDisabled(view) {
    return view.kpiValues.length > 1;
  }
</script>

{#if views.length > 0}
  <div class="mvp" data-mvp-active="true">
    {#each views as view, viewIndex (view.id)}
      <div class="mvp-view">
        <div class="mvp-view-header">
          <span class="mvp-view-index">{viewLetter(viewIndex)}</span>
          <div class="mvp-view-title">
            {#if view.kpiValues.length > 0}
              {view.kpiValues.map(v => kpiLabel(v)).join(' + ')}
            {:else}
              Välj nyckeltal
            {/if}
          </div>
          {#if views.length > 1}
            <button class="mvp-remove-btn" onclick={() => removeView(view.id)} title="Ta bort vy">×</button>
          {/if}
        </div>

        <!-- KPI selector: click toggles -->
        <div class="mvp-kpi-selector">
          {#each basket.items as item (item.value)}
            {@const id = item.value.includes(':') ? item.value.slice(item.value.indexOf(':') + 1).replace('\u001f', ' / ') : item.value}
            <button type="button"
              class="mvp-kpi-chip"
              class:selected={view.kpiValues.includes(item.value)}
              onclick={() => toggleKpiInView(view.id, item.value)}
              title={`${item.label} (${item.source} · ${id})`}
            >
              <span class="mvp-kpi-chip-label">{item.label}</span>
              <span class="mvp-kpi-chip-source">{item.source} · {id}</span>
            </button>
          {/each}
        </div>

        <!-- Viz type selector -->
        <div class="mvp-viz-bar">
          <VizTypeSelector
            id="mvp_viz_{view.id}"
            bind:value={
              () => view.vizType,
              (v) => setVizType(view.id, v)
            }
            disabled={{ map: mapDisabled(view) }}
          />
          {#if view.kpiValues.length > 1}
            <div class="mvp-layout-toggle">
              <button class="mvp-layout-btn" class:active={view.layout === 'overlay'}
                      onclick={() => setLayout(view.id, 'overlay')}>Overlay</button>
              <button class="mvp-layout-btn" class:active={view.layout === 'grid'}
                      onclick={() => setLayout(view.id, 'grid')}>Grid</button>
            </div>
          {/if}
        </div>

        <!-- Chart or placeholder -->
        {#if view.kpiValues.length > 0}
          <ChartOutput
            id="mvp_chart_{view.id}"
            endpoint="/api/output/kpi_chart_interactive"
            params={viewParams(view)}
            {baseUrl}
          />
        {:else}
          <div class="mvp-placeholder">
            <i class="bi bi-bar-chart-line"></i>
            <p>Välj ett eller flera nyckeltal i menyn ovan för att visa grafik.</p>
          </div>
        {/if}
      </div>
    {/each}

    <button class="mvp-add-view" onclick={() => addView()}>
      + Lägg till vy
    </button>
  </div>
{:else if basket.count > 0}
  <div class="mvp-empty">
    <p>Lägg till nyckeltal i korgen och klicka "Utforska data" för att börja visualisera.</p>
  </div>
{/if}

<style>
  .mvp {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
  .mvp-view {
    border: 1px solid #E2E8F0;
    border-radius: 8px;
    padding: 1rem;
    background: white;
  }
  .mvp-view-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.5rem;
  }
  .mvp-view-index {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 1.5rem;
    height: 1.5rem;
    border-radius: 4px;
    background: #0B7A75;
    color: white;
    font-size: 0.75rem;
    font-weight: 700;
    flex-shrink: 0;
  }
  .mvp-view-title {
    flex: 1;
    font-size: 0.9rem;
    font-weight: 600;
    color: #2D3748;
  }
  .mvp-placeholder {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 3rem;
    color: #CBD5E0;
    text-align: center;
  }
  .mvp-placeholder i {
    font-size: 2.5rem;
    margin-bottom: 0.5rem;
  }
  .mvp-placeholder p {
    font-size: 0.85rem;
    margin: 0;
  }
  .mvp-remove-btn {
    font-size: 1.2rem;
    color: #A0AEC0;
    background: none;
    border: none;
    cursor: pointer;
    padding: 0 0.3rem;
  }
  .mvp-remove-btn:hover {
    color: #E05A47;
  }
  .mvp-kpi-selector {
    display: flex;
    flex-wrap: wrap;
    gap: 0.35rem;
    margin-bottom: 0.5rem;
  }
  .mvp-kpi-chip {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.2rem 0.5rem;
    border: 1px solid #E2E8F0;
    border-radius: 4px;
    font-size: 0.75rem;
    cursor: pointer;
    background: white;
    transition: all 0.15s;
  }
  .mvp-kpi-chip.selected {
    border-color: #0B7A75;
    background: #EBF5F5;
  }
  .mvp-kpi-chip input[type="checkbox"] {
    display: none;
  }
  .mvp-kpi-chip-label {
    color: #2D3748;
    font-weight: 500;
    max-width: 180px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .mvp-kpi-chip-source {
    color: #0B7A75;
    font-size: 0.6rem;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }
  .mvp-viz-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;
  }
  .mvp-layout-toggle {
    display: inline-flex;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    overflow: hidden;
  }
  .mvp-layout-btn {
    font-size: 0.75rem;
    padding: 0.25rem 0.6rem;
    border: none;
    border-right: 1px solid #d1d5db;
    background: white;
    color: #4A5568;
    cursor: pointer;
    font-family: inherit;
  }
  .mvp-layout-btn:last-child {
    border-right: none;
  }
  .mvp-layout-btn.active {
    background: #0B7A75;
    color: white;
  }
  .mvp-add-view {
    align-self: center;
    padding: 0.5rem 1.2rem;
    border: 1px dashed #A0AEC0;
    border-radius: 6px;
    background: transparent;
    color: #4A5568;
    font-size: 0.85rem;
    cursor: pointer;
    font-family: inherit;
    transition: all 0.15s;
  }
  .mvp-add-view:hover {
    border-color: #0B7A75;
    color: #0B7A75;
  }
  .mvp-empty {
    text-align: center;
    padding: 3rem;
    color: #A0AEC0;
  }
</style>
