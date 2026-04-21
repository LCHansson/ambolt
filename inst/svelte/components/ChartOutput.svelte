<script>
  // ChartOutput — Framework component for interactive charts via SveltePlot
  //
  // Fetches a JSON chart spec from R (data + marks + scales) and renders
  // it using SveltePlot components. The spec format is designed to be
  // a thin layer between R and SveltePlot's grammar-of-graphics API.
  //
  // Props: same as PlotOutput (id, endpoint, params, baseUrl, trigger)

  import { createFetchState } from './fetchData.svelte.js';
  import { Plot, Line, BarY, BarX, Dot, RuleX, RuleY, Text, Geo, HTMLTooltip } from 'svelteplot';
  import { geoConicEqualArea } from 'd3-geo';

  let {
    id = '',
    endpoint = '',
    params = {},
    baseUrl = '',
    trigger = undefined
  } = $props();

  const fetch_state = createFetchState(
    () => ({ endpoint, params, baseUrl, trigger }),
    'json'
  );

  // Parse the spec to extract data and marks
  let chartData = $derived(fetch_state.data?.data ?? []);
  let marks = $derived(fetch_state.data?.marks ?? []);
  let title = $derived(fetch_state.data?.title ?? '');
  let legend = $derived(fetch_state.data?.legend ?? null);
  let grid = $derived(fetch_state.data?.grid ?? null);
  let isGrid = $derived(!!grid && grid.length > 0);

  // Default tickFormat suppresses SveltePlot's auto-compact notation
  // (which renders 1200 as "1.2k" / "1,2 tn"). Setting an explicit
  // tickFormat object on the scale tells AxisX/AxisY to use it as-is.
  // x-axis: no grouping (years like 2023 must not become "2 023").
  // y-axis: grouping ON (1200 → "1 200" with svensk space separator).
  const xTickFormat = {
    style: 'decimal',
    useGrouping: false,
    maximumFractionDigits: 0
  };
  const yTickFormat = {
    style: 'decimal',
    useGrouping: true,
    maximumFractionDigits: 2
  };
  let scales = $derived.by(() => {
    const s = fetch_state.data?.scales ?? {};
    return {
      ...s,
      x: { tickFormat: xTickFormat, ...(s.x ?? {}) },
      y: { tickFormat: yTickFormat, ...(s.y ?? {}) }
    };
  });

  // Detect if this is a map chart (has a geo mark)
  let geoMark = $derived(marks.find(m => m.type === 'geo'));
  let isMap = $derived(!!geoMark);

  // GeoJSON data for map charts — fetched lazily when a geo mark is present
  let geoFeatures = $state([]);
  // Re-derive geoMark endpoint to ensure Svelte tracks it properly.
  // Accessing geoMark AND chartData in the same derived ensures the
  // effect re-triggers when either changes.
  let geoEndpoint = $derived(geoMark?.geojson_endpoint ?? '');
  let geoDataReady = $derived(geoEndpoint !== '' && chartData.length > 0);

  $effect(() => {
    if (!geoDataReady) { geoFeatures = []; return; }
    const ep = geoEndpoint;  // track it
    const data = chartData;   // track it
    // Geo effect: fetch GeoJSON and join KPI data
    const base = baseUrl || window.location.origin;
    const url = new globalThis.URL(ep, base).toString();
    fetch(url)
      .then(r => r.json())
      .then(geojson => {
        if (geojson?.features) {
          // Join KPI data onto GeoJSON features via id_field
          const joinField = geoMark.id_field ?? 'id';
          const valueMap = new Map();
          for (const row of data) {
            const key = row[joinField];
            if (key != null) valueMap.set(String(key), row.value);
          }
          const joined = geojson.features.map(f => ({
            ...f,
            properties: {
              ...f.properties,
              _value: valueMap.get(f.properties[joinField]) ?? null,
              _name: f.properties.kom_namn ?? f.properties.name ?? ''
            }
          }));
          // Also join fill_color (pre-computed in R for reliable choropleth)
          const colorMap = new Map();
          for (const row of data) {
            const key = row[joinField];
            if (key != null && row.fill_color) colorMap.set(String(key), row.fill_color);
          }

          const final = joined.map(f => ({
            ...f,
            properties: {
              ...f.properties,
              _fill: colorMap.get(f.properties[joinField]) ?? '#f0f0f0'
            }
          }));

          const matched = final.filter(f => f.properties._value != null).length;
          // GeoJSON join complete: ${matched}/${geojson.features.length} features matched
          geoFeatures = final;
        }
      })
      .catch(err => console.warn('[ChartOutput] GeoJSON fetch failed:', err));
  });

  // For tooltip: identify x/y channels from first positional mark.
  // All marks in a chart_spec share the same channels (current convention).
  let primaryMark = $derived(marks.find(m =>
    ['line', 'dot', 'bar'].includes(m.type)));
  let xChannel = $derived(primaryMark?.x);
  let yChannel = $derived(primaryMark?.y);

  // Tooltip enabled only when a positional mark and data exist
  let showTooltip = $derived(
    !!primaryMark && chartData.length > 0
  );

  // Format helpers for tooltip — reuse the Plot's locale/format
  const locale = $derived(fetch_state.data?.locale ?? 'sv-SE');
  function fmtX(v) {
    if (typeof v === 'number') {
      return new Intl.NumberFormat(locale, xTickFormat).format(v);
    }
    return String(v);
  }
  function fmtY(v) {
    if (typeof v === 'number') {
      return new Intl.NumberFormat(locale, yTickFormat).format(v);
    }
    return String(v);
  }
  // Tooltip key labels — humanise common columns; fall back to key name
  // (with `_text` suffix stripped, leading char uppercased).
  const KEY_LABELS = {
    year: 'År',
    period_label: 'Period',
    date: 'Datum',
    kpi_label: 'Nyckeltal',
    municipality: 'Kommun',
    municipality_text: 'Kommun',
    gender: 'Kön',
    gender_text: 'Kön',
    Kon: 'Kön',
    Kon_text: 'Kön',
    Sektor: 'Sektor',
    Sektor_text: 'Sektor',
    ContentsCode: 'Innehåll',
    ContentsCode_text: 'Innehåll',
    UtbMYH: 'Utbildning',
    UtbMYH_text: 'Utbildning',
    Region: 'Region',
    Region_text: 'Region',
    series: 'Serie',
    value: 'Värde',
  };
  function tooltipLabel(k) {
    if (KEY_LABELS[k]) return KEY_LABELS[k];
    const stripped = k.replace(/_text$|_label$/, '');
    return stripped.charAt(0).toUpperCase() + stripped.slice(1);
  }
  // Internal/redundant columns that should never appear in the tooltip
  // body. The dedicated period block (built from year + period_label)
  // and the value row cover time and value separately.
  const TOOLTIP_SKIP = new Set([
    'date', 'period', '.composite_stroke', '.group',
    'year', 'period_label', 'Tid', 'time', 'ar', 'manad', 'kvartal',
    // `series` is the composite stroke key (KPI · group1 · group2…) used
    // for line color grouping. Each part is shown on its own row, so the
    // composite is redundant. `kpi_label` (just the title) replaces it.
    'series',
  ]);
  // Period block — derived from `year` + `period_label` so the tooltip
  // shows the source-canonical period (not the interpolated end-of-period
  // `date` we use only for sorting/plotting). Annual data → just "År:";
  // sub-annual → "År:" + "Period:".
  function derivePeriod(datum) {
    if (!datum) return [];
    const year = datum.year ?? datum.ar;
    const periodLabel = datum.period_label;
    const out = [];
    if (year != null) {
      out.push({ label: tooltipLabel('year'), value: String(year) });
    }
    if (periodLabel != null && String(periodLabel) !== String(year)) {
      out.push({ label: tooltipLabel('period_label'), value: String(periodLabel) });
    }
    if (out.length === 0) {
      // Fallback: use whatever the chart's xChannel is
      out.push({
        label: tooltipLabel(xChannel),
        value: fmtX(datum[xChannel]),
      });
    }
    return out;
  }
  // Values that mean "aggregated total". When a column has ONLY one
  // unique value across the whole dataset AND that value is one of these,
  // treat it as an implicit default and hide it from the tooltip.
  // Picking specific values explicitly (e.g. "Med last") leaves the
  // column with one unique value too — but the value won't match this
  // set, so it stays visible.
  const TOTALT_VALUES = new Set([
    'Totalt', 'totalt', 'Alla', 'alla', 'Samtliga', 'samtliga',
    'Hela riket', 'B\u00e5da k\u00f6nen', 'b\u00e5da k\u00f6nen',
    'T', 't1', 'TOT', 'TOTAL',
  ]);
  // Compute once per data refresh: which columns are single-value and
  // hold a Totalt-like value across all rows → hide from tooltip.
  // Nulls are ignored so multi-KPI overlay (where each KPI's dim cols
  // are NA in the other KPI's rows) still reduces correctly.
  let implicitTotaltCols = $derived.by(() => {
    const out = new Set();
    if (!chartData || chartData.length === 0) return out;
    const cols = new Set();
    for (const row of chartData) for (const k of Object.keys(row)) cols.add(k);
    for (const k of cols) {
      const seen = new Set();
      for (const row of chartData) {
        const v = row[k];
        if (v == null) continue;
        seen.add(v);
        if (seen.size > 1) break;
      }
      if (seen.size === 1) {
        const v = [...seen][0];
        if (TOTALT_VALUES.has(String(v))) out.add(k);
      }
    }
    return out;
  });

  function tooltipRows(datum) {
    if (!datum) return [];
    const keys = Object.keys(datum);
    // Prefer `_text` / `_label` versions when both exist — the raw code
    // (e.g. `Kon = "1"`) gets hidden in favour of the human label
    // (`Kon_text = "Män"`).
    const hasText = new Set();
    for (const k of keys) {
      if (k.endsWith('_text') || k.endsWith('_label')) {
        hasText.add(k.replace(/_text$|_label$/, ''));
      }
    }
    const rows = [];
    for (const [k, v] of Object.entries(datum)) {
      if (TOOLTIP_SKIP.has(k)) continue;
      if (k === xChannel || k === yChannel) continue;
      if (hasText.has(k)) continue;  // raw code superseded by _text/_label sibling
      if (implicitTotaltCols.has(k)) continue;  // implicit default totalt
      if (v == null || v === '') continue;
      rows.push({ key: k, label: tooltipLabel(k), value: String(v) });
    }
    return rows;
  }
</script>

<div class="ambolt-chart-output" data-output-id={id}>
  {#if fetch_state.error}
    <p class="error">Chart error: {fetch_state.error}</p>
  {:else if fetch_state.loading}
    <div class="loading">Loading chart...</div>
  {:else if isGrid}
    <!-- GRID MODE: small multiples -->
    {#if title}
      <div class="chart-title">{title}</div>
    {/if}
    <div class="chart-grid" style="grid-template-columns: repeat({Math.min(grid.length, 3)}, 1fr)">
      {#each grid as cell}
        <div class="chart-grid-cell">
          <div class="chart-grid-title">{cell.title ?? ''}</div>
          <Plot
            data={cell.data ?? []}
            x={cell.scales?.x ?? { tickFormat: xTickFormat }}
            y={cell.scales?.y ?? { tickFormat: yTickFormat }}
            marginLeft={50}
            marginBottom={35}
            locale="sv-SE"
          >
            {#each cell.marks ?? [] as mark}
              {#if mark.type === 'line'}
                {@const isFieldStroke = typeof mark.stroke === 'string' && !mark.stroke.startsWith('#')}
                <Line
                  data={cell.data ?? []}
                  x={mark.x}
                  y={mark.y}
                  stroke={isFieldStroke ? (d) => d[mark.stroke] : mark.stroke}
                  strokeWidth={mark.strokeWidth ?? 2}
                />
              {:else if mark.type === 'dot'}
                <Dot
                  data={cell.data ?? []}
                  x={mark.x}
                  y={mark.y}
                  fill={mark.fill ?? mark.stroke ?? undefined}
                  r={mark.r ?? 3}
                />
              {/if}
            {/each}
          </Plot>
        </div>
      {/each}
    </div>
  {:else if chartData.length === 0 && !isMap}
    <div class="empty">{title || 'Ingen data'}</div>
  {:else if isMap && geoFeatures.length > 0}
    <!-- MAP MODE: choropleth via Geo mark -->
    {#if title}
      <div class="chart-title">{title}</div>
    {/if}
    <Plot
      projection={{ type: geoConicEqualArea, domain: { type: 'FeatureCollection', features: geoFeatures } }}
      height={600}
      marginLeft={0}
      marginRight={0}
    >
      <Geo
        data={geoFeatures}
        fill={(d) => d.properties._fill}
        stroke={geoMark.stroke ?? '#333'}
        strokeWidth={geoMark.strokeWidth ?? 0.8}
        title={(d) => `${d.properties._name}: ${d.properties._value != null ? new Intl.NumberFormat('sv-SE', {maximumFractionDigits: 1}).format(d.properties._value) : 'Ingen data'}`}
      />
    </Plot>
    {#if legend?.items}
      <div class="chart-legend">
        {#each legend.items as item}
          <span class="chart-legend-item">
            <span class="chart-legend-swatch" style="background:{item.color}"></span>
            {item.label}
          </span>
        {/each}
        {#if legend.na_color}
          <span class="chart-legend-item">
            <span class="chart-legend-swatch" style="background:{legend.na_color}"></span>
            Ingen data
          </span>
        {/if}
      </div>
    {/if}
  {:else if isMap}
    <div class="loading">Laddar kartdata...</div>
  {:else}
    {#if title}
      <div class="chart-title">{title}</div>
    {/if}
    <Plot
      data={chartData}
      x={scales.x ?? undefined}
      y={scales.y ?? undefined}
      color={scales.color ?? undefined}
      marginLeft={scales.marginLeft ?? 60}
      marginBottom={scales.marginBottom ?? 40}
      locale={fetch_state.data?.locale ?? 'sv-SE'}
      numberFormat={fetch_state.data?.numberFormat ?? {
        style: 'decimal',
        useGrouping: true,
        maximumFractionDigits: 2
      }}
    >
      {#each marks as mark}
        {#if mark.type === 'line'}
          <!-- Line rendering with two independent visual channels:
               - stroke = column name (color, via SveltePlot's stroke channel)
               - linetype = column name (dash, emulated via multiple <Line>
                 components — one per unique linetype value, each with its
                 own constant strokeDasharray).
               Without a linetype column, render a single <Line> with
               stroke as either field accessor (column) or constant. -->
          {@const isFieldStroke = typeof mark.stroke === 'string' &&
                                  !mark.stroke.startsWith('#')}
          {#if mark.linetype && typeof mark.linetype === 'string'}
            {@const dashPalette = [undefined, '6,3', '2,2', '6,3,2,3',
                                   '10,4', '4,2,2,2']}
            {@const linetypeValues =
              [...new Set(chartData.map(d => d[mark.linetype]))]}
            {#each linetypeValues as ltVal, i}
              {@const subset = chartData.filter(d => d[mark.linetype] === ltVal)}
              <Line
                data={subset}
                x={mark.x}
                y={mark.y}
                stroke={isFieldStroke ? (d) => d[mark.stroke] : mark.stroke}
                strokeDasharray={dashPalette[i % dashPalette.length]}
                strokeWidth={mark.strokeWidth ?? 2}
              />
            {/each}
          {:else}
            <Line
              data={chartData}
              x={mark.x}
              y={mark.y}
              stroke={isFieldStroke ? (d) => d[mark.stroke] : mark.stroke}
              strokeWidth={mark.strokeWidth ?? 2}
            />
          {/if}
        {:else if mark.type === 'dot'}
          <Dot
            data={chartData}
            x={mark.x}
            y={mark.y}
            fill={mark.fill ?? mark.stroke ?? undefined}
            r={mark.r ?? 3}
          />
        {:else if mark.type === 'bar'}
          <BarY
            data={chartData}
            x={mark.x}
            y={mark.y}
            fill={mark.fill ?? undefined}
          />
        {:else if mark.type === 'barH'}
          <BarX
            data={mark.sort ? [...chartData].sort((a, b) => a[mark.x] - b[mark.x]) : chartData}
            x={mark.x}
            y={mark.y}
            fill={mark.fill ?? undefined}
          />
        {:else if mark.type === 'text'}
          <Text
            data={chartData}
            x={mark.x}
            y={mark.y}
            text={mark.text}
            fontSize={mark.fontSize ?? 11}
            fill={mark.fill ?? '#4A5568'}
            textAnchor={mark.textAnchor ?? 'start'}
            dx={mark.dx ?? 4}
          />
        {:else if mark.type === 'ruleX'}
          <RuleX data={[mark.x]} x={d => d} stroke={mark.stroke ?? '#999'} />
        {:else if mark.type === 'ruleY'}
          <RuleY data={[mark.y]} y={d => d} stroke={mark.stroke ?? '#999'} />
        {/if}
      {/each}
      {#snippet overlay()}
        {#if showTooltip}
          <HTMLTooltip data={chartData} x={xChannel} y={yChannel}>
            {#snippet children({ datum })}
              <div class="su-tooltip">
                {#each tooltipRows(datum) as row}
                  <div class="su-tooltip-row">
                    <span class="su-tooltip-key">{row.label}</span>
                    <span class="su-tooltip-val">{row.value}</span>
                  </div>
                {/each}
                {#each derivePeriod(datum) as p, i}
                  <div class="su-tooltip-row {i === 0 ? 'su-tooltip-period' : ''}">
                    <span class="su-tooltip-key">{p.label}</span>
                    <span class="su-tooltip-val">{p.value}</span>
                  </div>
                {/each}
                <div class="su-tooltip-row su-tooltip-value">
                  <span class="su-tooltip-key">{tooltipLabel(yChannel)}</span>
                  <span class="su-tooltip-val">{fmtY(datum[yChannel])}</span>
                </div>
              </div>
            {/snippet}
          </HTMLTooltip>
        {/if}
      {/snippet}
    </Plot>
  {/if}
</div>

<style>
  .ambolt-chart-output {
    border: 1px solid #d1d5db;
    border-radius: 4px;
    padding: 1rem;
    background: white;
    min-height: 100px;
  }
  .chart-title {
    font-size: 0.9rem;
    font-weight: 600;
    color: #374151;
    margin-bottom: 0.5rem;
  }
  .error {
    color: #dc2626;
    font-weight: bold;
  }
  .chart-grid {
    display: grid;
    gap: 1rem;
  }
  .chart-grid-cell {
    border: 1px solid #e5e7eb;
    border-radius: 4px;
    padding: 0.75rem;
    background: white;
  }
  .chart-grid-title {
    font-size: 0.82rem;
    font-weight: 600;
    color: #374151;
    margin-bottom: 0.4rem;
  }
  .chart-legend {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem 1rem;
    margin-top: 0.75rem;
    font-size: 0.78rem;
    color: #4A5568;
  }
  .chart-legend-item {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    white-space: nowrap;
  }
  .chart-legend-swatch {
    display: inline-block;
    width: 14px;
    height: 14px;
    border-radius: 2px;
    border: 1px solid #d1d5db;
    flex-shrink: 0;
  }
  .loading, .empty {
    color: #6b7280;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 200px;
  }
  :global(.su-tooltip) {
    background: rgba(45, 55, 72, 0.96);
    color: white;
    padding: 0.45rem 0.65rem;
    border-radius: 4px;
    font-size: 0.82rem;
    line-height: 1.35;
    box-shadow: 0 2px 8px rgb(0 0 0 / 0.2);
    pointer-events: none;
    white-space: nowrap;
    display: grid;
    grid-template-columns: max-content auto;
    column-gap: 0.7rem;
    row-gap: 0.1rem;
  }
  :global(.su-tooltip-row) {
    display: contents;
  }
  :global(.su-tooltip-key) {
    color: #A8C7C5;
    font-size: 0.72rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    align-self: center;
  }
  :global(.su-tooltip-val) {
    font-weight: 500;
    color: white;
  }
  :global(.su-tooltip-period .su-tooltip-key),
  :global(.su-tooltip-period .su-tooltip-val) {
    margin-top: 0.15rem;
    border-top: 1px solid rgba(255,255,255,0.15);
    padding-top: 0.2rem;
  }
  :global(.su-tooltip-value .su-tooltip-val) {
    font-weight: 700;
    font-size: 0.95rem;
  }
</style>
