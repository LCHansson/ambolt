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

  // Legend toggle (persisted per-instance, default visible)
  let legendVisible = $state(true);
  let hasLegend = $derived(
    !!legend && (legend.items?.length > 0 || legend.linetype_items?.length > 0)
  );
  let overcrowded = $derived(
    hasLegend && (legend.items?.length ?? 0) > 10
  );

  // Container ref for SVG download (clone the <svg> inside)
  let chartContainer;

  // Inline computed CSS into the cloned SVG so the exported file renders
  // standalone (browser inheritance + custom CSS otherwise lost).
  function inlineComputedStyles(srcSvg, destSvg) {
    const srcNodes = srcSvg.querySelectorAll('*');
    const destNodes = destSvg.querySelectorAll('*');
    const props = [
      'font-family', 'font-size', 'font-weight', 'fill', 'stroke',
      'stroke-width', 'stroke-dasharray', 'stroke-opacity', 'fill-opacity',
      'opacity', 'text-anchor', 'dominant-baseline'
    ];
    for (let i = 0; i < srcNodes.length; i++) {
      const cs = window.getComputedStyle(srcNodes[i]);
      const styleStr = props.map(p => `${p}:${cs.getPropertyValue(p)}`).join(';');
      destNodes[i].setAttribute('style', styleStr);
    }
  }

  function getChartSvg() {
    if (!chartContainer) return null;
    return chartContainer.querySelector('svg');
  }

  function sluggify(name) {
    if (!name) return 'chart';
    return String(name)
      .replace(/[^a-zA-Z0-9åäöÅÄÖ_\-]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .slice(0, 80) || 'chart';
  }

  function buildFilename(ext) {
    const slug = sluggify(title);
    const date = new Date().toISOString().slice(0, 10);
    return `${slug}_${date}.${ext}`;
  }

  function exportSvg() {
    const src = getChartSvg();
    if (!src) return;
    const clone = src.cloneNode(true);
    // Ensure width/height attrs are explicit
    const rect = src.getBoundingClientRect();
    clone.setAttribute('width', Math.round(rect.width));
    clone.setAttribute('height', Math.round(rect.height));
    clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    inlineComputedStyles(src, clone);
    const xml = new XMLSerializer().serializeToString(clone);
    const blob = new Blob([xml], { type: 'image/svg+xml;charset=utf-8' });
    triggerDownload(blob, buildFilename('svg'));
  }

  function exportPng() {
    const src = getChartSvg();
    if (!src) return;
    const clone = src.cloneNode(true);
    const rect = src.getBoundingClientRect();
    const w = Math.round(rect.width);
    const h = Math.round(rect.height);
    clone.setAttribute('width', w);
    clone.setAttribute('height', h);
    clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    inlineComputedStyles(src, clone);
    const xml = new XMLSerializer().serializeToString(clone);
    const svgBlob = new Blob([xml], { type: 'image/svg+xml;charset=utf-8' });
    const url = URL.createObjectURL(svgBlob);
    const img = new Image();
    img.onload = () => {
      const scale = window.devicePixelRatio || 2;
      const canvas = document.createElement('canvas');
      canvas.width = w * scale;
      canvas.height = h * scale;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = 'white';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.scale(scale, scale);
      ctx.drawImage(img, 0, 0, w, h);
      canvas.toBlob((blob) => {
        if (blob) triggerDownload(blob, buildFilename('png'));
        URL.revokeObjectURL(url);
      }, 'image/png');
    };
    img.onerror = () => { URL.revokeObjectURL(url); };
    img.src = url;
  }

  function triggerDownload(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(url), 100);
  }
  let isMap = $derived(!!geoMark);

  // GeoJSON data for map charts — fetched lazily when a geo mark is present
  let geoFeatures = $state([]);
  // Re-derive geoMark endpoint to ensure Svelte tracks it properly.
  // Accessing geoMark AND chartData in the same derived ensures the
  // effect re-triggers when either changes.
  let geoEndpoint = $derived(geoMark?.geojson_endpoint ?? '');
  let geoDataReady = $derived(geoEndpoint !== '' && chartData.length > 0);

  // Tracks whether the GeoJSON fetch + join is in flight so the map view
  // can show a loading overlay (B2). Reset on every geo effect re-run.
  let geoJoining = $state(false);

  $effect(() => {
    if (!geoDataReady) { geoFeatures = []; geoJoining = false; return; }
    const ep = geoEndpoint;  // track it
    const data = chartData;   // track it
    geoJoining = true;
    const t0 = performance.now();
    // Geo effect: fetch GeoJSON and join KPI data
    const base = baseUrl || window.location.origin;
    const url = new globalThis.URL(ep, base).toString();
    fetch(url)
      .then(r => r.json())
      .then(geojson => {
        if (geojson?.features) {
          const tFetch = performance.now();
          // Join KPI data onto GeoJSON features via id_field
          const joinField = geoMark.id_field ?? 'id';
          const valueMap = new Map();
          for (const row of data) {
            const key = row[joinField];
            if (key != null) valueMap.set(String(key), row.value);
          }
          // Also join fill_color (pre-computed in R for reliable choropleth)
          const colorMap = new Map();
          for (const row of data) {
            const key = row[joinField];
            if (key != null && row.fill_color) colorMap.set(String(key), row.fill_color);
          }
          const final = geojson.features.map(f => ({
            ...f,
            properties: {
              ...f.properties,
              _value: valueMap.get(f.properties[joinField]) ?? null,
              _name: f.properties.kom_namn ?? f.properties.name ?? '',
              _fill: colorMap.get(f.properties[joinField]) ?? '#f0f0f0'
            }
          }));
          const tJoin = performance.now();
          console.debug(
            `[ChartOutput] map ${ep}: fetch ${(tFetch - t0).toFixed(0)}ms`
            + `, join ${(tJoin - tFetch).toFixed(0)}ms`
            + `, features ${geojson.features.length}`
          );
          geoFeatures = final;
        }
      })
      .catch(err => console.warn('[ChartOutput] GeoJSON fetch failed:', err))
      .finally(() => { geoJoining = false; });
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

  // B4: when the cursor is in the right portion of the viewport, flag the
  // chart so the HTMLTooltip flips to the left of the cursor via CSS.
  // SveltePlot's tooltip is positioned with `left: <x>px` post-render —
  // we leave that positioning intact and translate the tooltip back with
  // CSS transform so the viewport doesn't expand horizontally.
  let tooltipFlip = $state(false);
  function onMouseMove(e) {
    // Only mutate when the threshold crossing actually changes the flag
    // — mousemove fires ~constantly and unnecessary $state writes would
    // re-run any derived that touches tooltipFlip.
    const flip = e.clientX > window.innerWidth * 0.65;
    if (flip !== tooltipFlip) tooltipFlip = flip;
  }

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

<div class="ambolt-chart-output" data-output-id={id}
     class:tooltip-flip={tooltipFlip}
     onmousemove={onMouseMove}
     role="presentation"
     bind:this={chartContainer}>
  {#if !fetch_state.error && !fetch_state.loading && (chartData.length > 0 || isGrid || geoFeatures.length > 0)}
    <div class="chart-controls">
      {#if hasLegend}
        <button type="button" class="chart-ctrl-btn"
                onclick={() => legendVisible = !legendVisible}
                title={legendVisible ? 'Dölj förklaring' : 'Visa förklaring'}>
          <i class="bi bi-{legendVisible ? 'eye' : 'eye-slash'}"></i>
          {legendVisible ? 'Dölj' : 'Visa'} förklaring
        </button>
      {/if}
      <span class="chart-ctrl-spacer"></span>
      <button type="button" class="chart-ctrl-btn" onclick={exportPng}
              title="Ladda ner som PNG-bild">
        <i class="bi bi-image"></i> PNG
      </button>
      <button type="button" class="chart-ctrl-btn" onclick={exportSvg}
              title="Ladda ner som SVG-vektorgrafik">
        <i class="bi bi-filetype-svg"></i> SVG
      </button>
    </div>
  {/if}
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
    <div class="map-wrap">
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
      {#if geoJoining}
        <div class="map-loading-overlay" aria-live="polite">
          <div class="spinner" aria-label="Uppdaterar karta..."></div>
        </div>
      {/if}
    </div>
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
    <div class="map-wrap map-wrap-empty">
      <div class="map-loading-overlay map-loading-overlay-empty">
        <div class="spinner" aria-label="Laddar karta..."></div>
        <div class="spinner-label">Laddar karta…</div>
      </div>
    </div>
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
          {@const isFieldFillY = typeof mark.fill === 'string' && !mark.fill.startsWith('#')}
          <BarY
            data={chartData}
            x={mark.x}
            y={mark.y}
            fill={isFieldFillY ? (d) => d[mark.fill] : (mark.fill ?? undefined)}
          />
        {:else if mark.type === 'barH'}
          {@const isFieldFillX = typeof mark.fill === 'string' && !mark.fill.startsWith('#')}
          <BarX
            data={mark.sort ? [...chartData].sort((a, b) => a[mark.x] - b[mark.x]) : chartData}
            x={mark.x}
            y={mark.y}
            fill={isFieldFillX ? (d) => d[mark.fill] : (mark.fill ?? undefined)}
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
    {#if hasLegend && legendVisible}
      <div class="chart-legend chart-legend-cat" class:overcrowded>
        {#if legend.items?.length > 0}
          {#if legend.stroke_label}
            <span class="chart-legend-title">Färg</span>
          {/if}
          {#each legend.items as item}
            <span class="chart-legend-item">
              <span class="chart-legend-swatch" style="background:{item.color}"></span>
              {item.label}
            </span>
          {/each}
        {/if}
        {#if legend.linetype_items?.length > 0}
          <span class="chart-legend-title">Linjetyp</span>
          {#each legend.linetype_items as item}
            <span class="chart-legend-item">
              <svg class="chart-legend-dash" width="24" height="8" viewBox="0 0 24 8">
                <line x1="0" y1="4" x2="24" y2="4"
                      stroke="#4A5568" stroke-width="2"
                      stroke-dasharray={item.dash === 'solid' ? '' : item.dash} />
              </svg>
              {item.label}
            </span>
          {/each}
        {/if}
        {#if overcrowded}
          <span class="chart-legend-hint">Hovra över en linje i grafen för att se exakt värde</span>
        {/if}
      </div>
    {/if}
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
  .chart-controls {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    margin-bottom: 0.4rem;
  }
  .chart-ctrl-spacer { flex: 1 1 auto; }
  .chart-ctrl-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    font-size: 0.75rem;
    padding: 0.25rem 0.55rem;
    border: 1px solid #E2E8F0;
    border-radius: 4px;
    background: white;
    color: #4A5568;
    cursor: pointer;
    font-family: inherit;
    transition: background-color 0.12s, border-color 0.12s, color 0.12s;
  }
  .chart-ctrl-btn:hover {
    background: #EBF5F5;
    border-color: #CCE6E5;
    color: #065956;
  }
  .chart-legend-cat {
    align-items: center;
  }
  .chart-legend-title {
    font-size: 0.72rem;
    font-weight: 600;
    color: #4A5568;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-right: 0.2rem;
  }
  .chart-legend-cat.overcrowded {
    font-size: 0.72rem;
    gap: 0.2rem 0.6rem;
  }
  .chart-legend-cat.overcrowded .chart-legend-swatch {
    width: 8px;
    height: 8px;
  }
  .chart-legend-hint {
    flex-basis: 100%;
    font-size: 0.7rem;
    color: #A0AEC0;
    font-style: italic;
    margin-top: 0.2rem;
  }
  .chart-legend-dash {
    vertical-align: middle;
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
  /* B2: map loading overlay. Positioned over the Plot so the previous
     rendering stays visible while a new fetch is in flight. */
  .map-wrap {
    position: relative;
  }
  .map-wrap-empty {
    min-height: 400px;
  }
  .map-loading-overlay {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.6rem;
    background: rgba(255, 255, 255, 0.55);
    backdrop-filter: blur(1px);
    z-index: 5;
    pointer-events: none;
  }
  .map-loading-overlay-empty {
    background: transparent;
    color: #6b7280;
  }
  .spinner {
    width: 36px;
    height: 36px;
    border: 3px solid #CCE6E5;
    border-top-color: #0B7A75;
    border-radius: 50%;
    animation: ambolt-spin 0.9s linear infinite;
  }
  .spinner-label {
    font-size: 0.82rem;
    color: #6b7280;
  }
  @keyframes ambolt-spin {
    to { transform: rotate(360deg); }
  }
  /* B4: HTMLTooltip flip — when the cursor is in the right portion of
     the viewport, translate the tooltip back so it opens to the left of
     the cursor and never expands the viewport horizontally. SveltePlot
     uses `.svelteplot-tooltip` for its HTMLTooltip wrapper. */
  .ambolt-chart-output.tooltip-flip :global(.svelteplot-tooltip) {
    transform: translateX(calc(-100% - 20px));
  }
</style>
