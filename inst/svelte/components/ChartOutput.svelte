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

  // DEBUG: log chart data structure when it updates
  $effect(() => {
    if (chartData.length > 0) {
      const cols = Object.keys(chartData[0] ?? {});
      console.log('[ChartOutput] data:', chartData.length, 'rows, cols:', cols);
      if (cols.length > 2) {
        for (const col of cols) {
          if (col === 'year' || col === 'value') continue;
          const distinct = [...new Set(chartData.map(r => r[col]))];
          console.log('  ', col, 'distinct:', distinct);
        }
      }
      console.log('[ChartOutput] marks JSON:', JSON.stringify(marks));
      console.log('[ChartOutput] first mark stroke=', marks[0]?.stroke,
                  'type=', typeof marks[0]?.stroke);
    }
  });

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
    console.log('[ChartOutput] Geo effect fired, endpoint:', ep, 'data rows:', data.length);
    const base = baseUrl || window.location.origin;
    const url = new globalThis.URL(ep, base).toString();
    fetch(url)
      .then(r => r.json())
      .then(geojson => {
        if (geojson?.features) {
          // Join KPI data onto GeoJSON features via id_field
          const valueMap = new Map();
          for (const row of data) {
            const key = row[geoMark?.fill_key] ?? row.municipality_id ?? row.municipality ?? row.id;
            if (key) valueMap.set(String(key), row.value);
          }
          const joined = geojson.features.map(f => ({
            ...f,
            properties: {
              ...f.properties,
              _value: valueMap.get(f.properties[geoMark.id_field]) ?? null,
              _name: f.properties.kom_namn ?? f.properties.name ?? ''
            }
          }));
          const matched = joined.filter(f => f.properties._value != null).length;
          console.log(`[ChartOutput] GeoJSON: ${geojson.features.length} features, ${valueMap.size} data points, ${matched} matched`);
          console.log('[ChartOutput] Sample join:', joined[0]?.properties?.id, '→', joined[0]?.properties?._value);
          geoFeatures = joined;
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
</script>

<div class="ambolt-chart-output" data-output-id={id}>
  {#if fetch_state.error}
    <p class="error">Chart error: {fetch_state.error}</p>
  {:else if fetch_state.loading}
    <div class="loading">Loading chart...</div>
  {:else if chartData.length === 0 && !isMap}
    <div class="empty">Ingen data</div>
  {:else if isMap && geoFeatures.length > 0}
    <!-- MAP MODE: choropleth via Geo mark -->
    {#if title}
      <div class="chart-title">{title}</div>
    {/if}
    <Plot
      projection={{ type: 'mercator', domain: { type: 'FeatureCollection', features: geoFeatures } }}
      color={{ type: 'linear', scheme: 'blues', domain: [
        Math.min(...geoFeatures.map(f => f.properties._value).filter(v => v != null && isFinite(v))),
        Math.max(...geoFeatures.map(f => f.properties._value).filter(v => v != null && isFinite(v)))
      ] }}
      height={500}
    >
      <Geo
        data={geoFeatures}
        fill={(d) => d.properties._value}
        stroke={geoMark.stroke ?? '#fff'}
        strokeWidth={geoMark.strokeWidth ?? 0.5}
        title={(d) => `${d.properties._name}: ${d.properties._value != null ? d.properties._value : 'Ingen data'}`}
      />
    </Plot>
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
                <div class="su-tooltip-x">{fmtX(datum[xChannel])}</div>
                <div class="su-tooltip-y">{fmtY(datum[yChannel])}</div>
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
  .loading, .empty {
    color: #6b7280;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 200px;
  }
  :global(.su-tooltip) {
    background: rgba(45, 55, 72, 0.95);
    color: white;
    padding: 0.4rem 0.6rem;
    border-radius: 4px;
    font-size: 0.85rem;
    line-height: 1.3;
    box-shadow: 0 2px 8px rgb(0 0 0 / 0.2);
    pointer-events: none;
    white-space: nowrap;
  }
  :global(.su-tooltip-x) {
    font-weight: 600;
    color: #cce6e5;
  }
  :global(.su-tooltip-y) {
    color: white;
  }
</style>
