<script>
  // VizTypeSelector — Horizontal icon button group for visualization type.
  //
  // Props:
  //   id       — input id
  //   value    — bindable active viz type ("timeseries" | "bar" | "map")
  //   disabled — object with per-type disabled state, e.g. { map: true }

  let {
    id = '',
    value = $bindable('timeseries'),
    disabled = {}
  } = $props();

  const types = [
    { code: 'timeseries', label: 'Tidsserie', icon: 'graph-up' },
    { code: 'bar', label: 'Stapel', icon: 'bar-chart-fill' },
    { code: 'map', label: 'Karta', icon: 'geo-alt-fill' },
  ];

  function select(code) {
    if (disabled[code]) return;
    value = code;
  }
</script>

<div class="viz-selector-wrap" data-input-id={id}>
<div class="viz-selector">
  {#each types as t}
    <button
      type="button"
      class="viz-btn"
      class:active={value === t.code}
      class:disabled={disabled[t.code]}
      disabled={disabled[t.code]}
      title={t.label}
      onclick={() => select(t.code)}
    >
      <i class="bi bi-{t.icon}"></i>
      <span class="viz-label">{t.label}</span>
    </button>
  {/each}
</div>
</div>

<style>
  .viz-selector-wrap {
    display: flex;
    justify-content: flex-end;
    margin: 0 0 0.4rem 0;
  }
  .viz-selector {
    display: inline-flex;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    overflow: hidden;
  }
  .viz-btn {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.25rem 0.5rem;
    border: none;
    border-right: 1px solid #d1d5db;
    background: white;
    color: #4A5568;
    font-size: 0.78rem;
    font-family: inherit;
    cursor: pointer;
    transition: all 0.15s;
  }
  .viz-btn:last-child {
    border-right: none;
  }
  .viz-btn:hover:not(.disabled) {
    background: #f7fafc;
  }
  .viz-btn.active {
    background: #0B7A75;
    color: white;
  }
  .viz-btn.active:hover {
    background: #065956;
  }
  .viz-btn.disabled {
    color: #CBD5E0;
    cursor: not-allowed;
    background: #F7FAFC;
  }
  .viz-btn i {
    font-size: 0.95rem;
  }
  /* Show the verbal label only on the active button — inactive buttons
     stay icon-only with their `title` attribute as a tooltip. */
  .viz-label {
    font-weight: 500;
  }
  .viz-btn:not(.active) .viz-label {
    display: none;
  }
</style>
