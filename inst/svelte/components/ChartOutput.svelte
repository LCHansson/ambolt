<script>
  // ChartOutput — Framework component for interactive charts via SveltePlot
  //
  // Fetches a JSON chart spec from R (data + marks + scales) and renders
  // it using SveltePlot components. The spec format is designed to be
  // a thin layer between R and SveltePlot's grammar-of-graphics API.
  //
  // Props: same as PlotOutput (id, endpoint, params, baseUrl, trigger)

  import { createFetchState } from './fetchData.svelte.js';
  import { Plot, Line, BarY, Dot, RuleX, RuleY, AxisX, AxisY, Text } from '@gka/svelteplot';

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
  let scales = $derived(fetch_state.data?.scales ?? {});
  let title = $derived(fetch_state.data?.title ?? '');
</script>

<div class="ambolt-chart-output" data-output-id={id}>
  {#if fetch_state.error}
    <p class="error">Chart error: {fetch_state.error}</p>
  {:else if fetch_state.loading}
    <div class="loading">Loading chart...</div>
  {:else if chartData.length === 0}
    <div class="empty">Ingen data</div>
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
    >
      <AxisX />
      <AxisY />
      {#each marks as mark}
        {#if mark.type === 'line'}
          <Line
            x={mark.x}
            y={mark.y}
            stroke={mark.stroke ?? undefined}
            strokeWidth={mark.strokeWidth ?? 2}
          />
        {:else if mark.type === 'dot'}
          <Dot
            x={mark.x}
            y={mark.y}
            fill={mark.fill ?? mark.stroke ?? undefined}
            r={mark.r ?? 3}
          />
        {:else if mark.type === 'bar'}
          <BarY
            x={mark.x}
            y={mark.y}
            fill={mark.fill ?? undefined}
          />
        {:else if mark.type === 'ruleX'}
          <RuleX x={mark.x} stroke={mark.stroke ?? '#999'} />
        {:else if mark.type === 'ruleY'}
          <RuleY y={mark.y} stroke={mark.stroke ?? '#999'} />
        {/if}
      {/each}
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
</style>
