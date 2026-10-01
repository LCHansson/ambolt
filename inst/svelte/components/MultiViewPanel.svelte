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

  // Multi-view activates ONLY on an explicit "Utforska data" (the
  // ambolt:explore-basket event) — not automatically when the basket has
  // items. A single-KPI selection (ambolt:select without fromBasket) leaves
  // the multi-view by clearing the views; the basket itself is kept so the
  // user can re-explore. This is what stops the OLD comparison from hanging
  // on when the user picks a new single series from search.
  $effect(() => {
    function handleExploreBasket(e) {
      const vals = (e.detail?.values ?? []).filter(Boolean);
      if (vals.length === 0) return;
      views = [{ id: nextViewId, kpiValues: vals, vizType: 'timeseries', layout: 'overlay' }];
      nextViewId++;
    }
    function handleSingleSelect(e) {
      if (!e.detail?.fromBasket) views = [];
    }
    document.addEventListener('ambolt:explore-basket', handleExploreBasket);
    document.addEventListener('ambolt:select', handleSingleSelect);
    return () => {
      document.removeEventListener('ambolt:explore-basket', handleExploreBasket);
      document.removeEventListener('ambolt:select', handleSingleSelect);
    };
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

  // Always announce the current active-KPI set — INCLUDING the empty set, so
  // DynamicFilters can leave multi-mode and return to single-KPI filtering
  // when the user drops back out of the multi-view. (Previously this only
  // fired for length > 0, which latched DynamicFilters in multi-mode forever.)
  $effect(() => {
    document.dispatchEvent(new CustomEvent('ambolt:filter-trigger', {
      detail: { values: activeKpis, kpiViewMap: kpiViewMap }
    }));
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

  // --- Per-view "Visa R-kod" (reproduces this view's exact pipeline) ---
  let codeDialog;
  let codeText = $state('');
  let codeLoading = $state(false);

  async function showCode(view) {
    codeText = '';
    codeLoading = true;
    codeDialog?.showModal();
    try {
      const p = viewParams(view);
      const url = new URL('/api/codegen', baseUrl || window.location.origin);
      for (const [k, v] of Object.entries(p)) {
        if (v != null && v !== '') url.searchParams.set(k, v);
      }
      const res = await fetch(url.toString());
      const data = await res.json();
      codeText = data.code || '# (ingen kod)';
    } catch (err) {
      codeText = '# Fel vid hämtning av R-kod: ' + err.message;
    } finally {
      codeLoading = false;
    }
  }
  function copyCode(btn) {
    navigator.clipboard.writeText(codeText);
    if (btn) {
      btn.textContent = 'Kopierad!';
      setTimeout(() => { btn.textContent = 'Kopiera kod'; }, 1500);
    }
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
          <div class="mvp-viz-bar-right">
            {#if view.kpiValues.length > 1}
              <div class="mvp-layout-toggle">
                <button class="mvp-layout-btn" class:active={view.layout === 'overlay'}
                        onclick={() => setLayout(view.id, 'overlay')}>Overlay</button>
                <button class="mvp-layout-btn" class:active={view.layout === 'grid'}
                        onclick={() => setLayout(view.id, 'grid')}>Grid</button>
              </div>
            {/if}
            {#if view.kpiValues.length > 0}
              <button type="button" class="mvp-code-btn" onclick={() => showCode(view)}
                      title="Visa R-kod som reproducerar denna vy">&lt;/&gt; R-kod</button>
            {/if}
          </div>
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

    <dialog bind:this={codeDialog} class="mvp-code-dialog"
            onclick={(e) => { if (e.target === codeDialog) codeDialog.close(); }}>
      <div class="mvp-code-inner">
        <div class="mvp-code-head">
          <span class="mvp-code-title">R-kod för denna vy</span>
          <button type="button" class="mvp-code-close" onclick={() => codeDialog.close()}>×</button>
        </div>
        {#if codeLoading}
          <div class="mvp-code-loading">Genererar...</div>
        {:else}
          <pre class="mvp-code-pre">{codeText}</pre>
          <button type="button" class="mvp-code-copy" onclick={(e) => copyCode(e.currentTarget)}>Kopiera kod</button>
        {/if}
      </div>
    </dialog>
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
  .mvp-viz-bar-right {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
  }
  .mvp-code-btn {
    background: #F7FAFC;
    border: 1px solid #E2E8F0;
    color: #4A5568;
    border-radius: 5px;
    padding: 0.25rem 0.6rem;
    font-size: 0.75rem;
    font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
    cursor: pointer;
  }
  .mvp-code-btn:hover {
    border-color: #0B7A75;
    color: #0B7A75;
  }
  .mvp-code-dialog {
    border: none;
    border-radius: 10px;
    padding: 0;
    max-width: min(860px, 92vw);
    width: 860px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.25);
  }
  .mvp-code-dialog::backdrop {
    background: rgba(0, 0, 0, 0.4);
  }
  .mvp-code-inner {
    padding: 1.1rem 1.3rem 1.3rem;
  }
  .mvp-code-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.7rem;
  }
  .mvp-code-title {
    font-weight: 600;
    font-size: 1rem;
  }
  .mvp-code-close {
    background: none;
    border: none;
    font-size: 1.4rem;
    line-height: 1;
    cursor: pointer;
    color: #6b7280;
  }
  .mvp-code-loading {
    color: #6b7280;
    font-style: italic;
    padding: 1rem 0;
  }
  .mvp-code-pre {
    background: #0f172a;
    color: #e2e8f0;
    border-radius: 8px;
    padding: 1rem;
    overflow: auto;
    max-height: 60vh;
    font-size: 0.78rem;
    line-height: 1.5;
    white-space: pre;
  }
  .mvp-code-copy {
    margin-top: 0.8rem;
    background: #0B7A75;
    color: #fff;
    border: none;
    border-radius: 6px;
    padding: 0.45rem 0.9rem;
    font-size: 0.85rem;
    cursor: pointer;
  }
  .mvp-code-copy:hover {
    background: #065956;
  }
  .mvp-empty {
    text-align: center;
    padding: 3rem;
    color: #A0AEC0;
  }
</style>
