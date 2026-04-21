<script>
  // FilterRenderer — Renders dynamic filter controls from a filter_spec
  //
  // Takes a filter_spec object (from R's filter_spec()) and renders the
  // appropriate control per dimension. Bound `value` is an object keyed
  // by dimension name, e.g. { year: [2010, 2024], gender: "T", ... }.
  //
  // Dimensions are grouped into three classes (time/geo/other) and rendered
  // in three labeled blocks per the wireframe design.
  //
  // Props:
  //   spec              — filter_spec object: { source, entity_id, dimensions: [...] }
  //   value             — bindable object of current filter values (by dim name)
  //   yearMin, yearMax  — bounds for time-class range sliders (defaults sensible)

  import RangeSlider from './RangeSlider.svelte';
  import MultiSelect from './MultiSelect.svelte';
  import SelectInput from './SelectInput.svelte';

  let {
    spec = null,
    value = $bindable({}),
    yearMin = 1990,
    yearMax = 2030,
    kpiViewMap = {},
  } = $props();

  // Convert _kpi_values (array of KPI value strings) to view-letter badges.
  // kpiViewMap maps KPI values → view letters (e.g. "kolada:N01951" → ["A", "C"])
  function viewBadges(dim) {
    const kpiValues = dim?._kpi_values;
    if (!kpiValues || !Array.isArray(kpiValues) || Object.keys(kpiViewMap).length === 0) return [];
    const letters = new Set();
    for (const kpiVal of kpiValues) {
      const vl = kpiViewMap[kpiVal];
      if (vl) vl.forEach(l => letters.add(l));
    }
    return [...letters].sort();
  }

  let dimensions = $derived(spec?.dimensions ?? []);

  function dimsByClass(cls) {
    return dimensions.filter(d => d.class === cls);
  }

  let timeDims = $derived(dimsByClass('time'));
  let geoDims  = $derived(dimsByClass('geo'));
  let otherDims = $derived(dimensions.filter(d => d.class !== 'time' && d.class !== 'geo'));

  // Helper: per-dimension bounds (use dim's min/max if provided, else fallback)
  function rangeBounds(d) {
    return [d.min ?? yearMin, d.max ?? yearMax];
  }

  // Find a real "Totalt" code in the values list — returns null if no
  // genuine totalt match (we do NOT fall back to the first value here).
  // Used to decide whether an empty filter implies an aggregated default
  // and whether to show the "Visar totalvärden" hint.
  function findTotalCode(values) {
    if (!values || values.length === 0) return null;
    const totalCodes = ['T', 't1', 'TOT', 'TOTAL', 'Alla'];
    for (const tc of totalCodes) {
      const match = values.find(v => v.code === tc);
      if (match) return match.code;
    }
    const labelMatch = values.find(v =>
      /^(totalt|alla|samtliga|total)$/i.test(v.text));
    return labelMatch ? labelMatch.code : null;
  }

  // True when an empty filter on this dim resolves to "Totalt" downstream.
  function isAggregatedByDefault(d) {
    if (d.type === 'range') return false;
    if (!d.values || d.values.length === 0) return false;
    return findTotalCode(d.values) !== null;
  }

  // Initialize defaults for any missing dimension values.
  // Range dims get bounds. Multi-select dims start empty — if the dim
  // has a real Totalt code, the backend defaults to it automatically and
  // we surface a discreet "Visar totalvärden" hint (see template below).
  // Single-select dims still pre-fill (first value or detected total).
  $effect(() => {
    if (!spec) return;
    let changed = false;
    const v = { ...value };
    for (const d of dimensions) {
      if (v[d.name] === undefined) {
        if (d.type === 'range') {
          v[d.name] = rangeBounds(d);
        } else if (d.multi) {
          v[d.name] = [];
        } else if (d.values && d.values.length > 0) {
          v[d.name] = findTotalCode(d.values) ?? d.values[0].code;
        } else {
          v[d.name] = '';
        }
        changed = true;
      }
    }
    if (changed) value = v;
  });

  // True when current value for `d` is empty (no chips picked).
  function isEmptyValue(d) {
    const v = value[d.name];
    if (v === undefined || v === null) return true;
    if (Array.isArray(v)) return v.length === 0;
    return v === '';
  }

  // Convert filter_spec values format (list of {code,text}) to MultiSelect choices format
  function toChoices(vals) {
    if (!vals) return [];
    return vals.map(v => ({ code: v.code, text: v.text }));
  }

  // Convert to SelectInput choices: { value: code, label: text } pairs
  function toSelectChoices(vals) {
    if (!vals) return [];
    return vals.map(v => ({ value: v.code, label: v.text }));
  }

  // Fetch lookup choices from a server endpoint (for select_lookup type).
  // Cached per endpoint so repeated renders don't re-fetch.
  const lookupCache = {};
  async function fetchLookupChoices(endpoint) {
    if (lookupCache[endpoint]) return lookupCache[endpoint];
    const base = window.location.origin;
    const res = await fetch(new URL(endpoint, base).toString());
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    // Expect array of {value, label} objects (same as /api/municipalities)
    const choices = (Array.isArray(data) ? data : []).map(d => ({
      code: d.value || d.code || '',
      text: d.label || d.text || ''
    }));
    lookupCache[endpoint] = choices;
    return choices;
  }

  // Svelte 5 doesn't allow bind:value={value[key]} for dynamic keys.
  // We use inline arrow functions in the bind: syntax below.
</script>

{#if spec && dimensions.length > 0}
  <div class="filter-renderer">
    {#if timeDims.length > 0}
      <div class="filter-block">
        <div class="filter-block-title">Tidsperiod
          {#if viewBadges(timeDims[0]).length > 0}<span class="filter-attribution">{#each viewBadges(timeDims[0]) as letter}<span class="filter-badge">{letter}</span>{/each}</span>{/if}
        </div>
        {#each timeDims as dim (dim.name)}
          {#if dim.type === 'range'}
            <RangeSlider
              id={`filter-${dim.name}`}
              label={dim.label}
              bind:value={
                () => value[dim.name] ?? rangeBounds(dim),
                (v) => { value = { ...value, [dim.name]: v }; }
              }
              min={dim.min ?? yearMin}
              max={dim.max ?? yearMax}
              step={1}
            />
          {/if}
        {/each}
      </div>
    {/if}

    {#if geoDims.length > 0}
      <div class="filter-block">
        <div class="filter-block-title">Geografi
          {#if viewBadges(geoDims[0]).length > 0}<span class="filter-attribution">{#each viewBadges(geoDims[0]) as letter}<span class="filter-badge">{letter}</span>{/each}</span>{/if}
        </div>
        {#each geoDims as dim (dim.name)}
          {#if dim.values && dim.values.length > 0}
            <MultiSelect
              id={`filter-${dim.name}`}
              label={dim.label}
              choices={toChoices(dim.values)}
              bind:value={
                () => value[dim.name] ?? [],
                (v) => { value = { ...value, [dim.name]: v }; }
              }
              placeholder="Sök {dim.label.toLowerCase()}..."
            />
          {:else if dim.type === 'select_lookup' && (dim.endpoint || dim.lookup_endpoint)}
            <!-- Server-backed multi-select: fetches choices from endpoint -->
            {#await fetchLookupChoices(dim.endpoint || dim.lookup_endpoint)}
              <div class="filter-placeholder">Laddar {dim.label.toLowerCase()}...</div>
            {:then choices}
              <MultiSelect
                id={`filter-${dim.name}`}
                label={dim.label}
                {choices}
                bind:value={
                  () => value[dim.name] ?? [],
                  (v) => { value = { ...value, [dim.name]: v }; }
                }
                placeholder="Sök {dim.label.toLowerCase()}..."
              />
            {:catch}
              <div class="filter-placeholder">{dim.label} — kunde inte laddas</div>
            {/await}
          {:else}
            <div class="filter-placeholder">
              {dim.label} — konfiguration saknas
            </div>
          {/if}
          {#if isEmptyValue(dim)}
            <div class="filter-default-hint">Visar Riket</div>
          {/if}
        {/each}
      </div>
    {/if}

    {#if otherDims.length > 0}
      <div class="filter-block">
        <div class="filter-block-title">Övriga</div>
        {#each otherDims as dim (dim.name)}
          {@const hasBadges = viewBadges(dim).length > 0}
          {#if hasBadges}
            <div class="filter-dim-badges">
              <span class="filter-dim-label">{dim.label}</span>
              <span class="filter-attribution">{#each viewBadges(dim) as letter}<span class="filter-badge">{letter}</span>{/each}</span>
            </div>
          {/if}
          {#if dim.type === 'categorical' && dim.values}
            {#if dim.multi}
              <MultiSelect
                id={`filter-${dim.name}`}
                label={hasBadges ? '' : dim.label}
                choices={toChoices(dim.values)}
                bind:value={
                  () => value[dim.name] ?? [],
                  (v) => { value = { ...value, [dim.name]: v }; }
                }
              />
            {:else}
              <div class="filter-row">
                {#if !hasBadges}<label for={`filter-${dim.name}`} class="filter-label">{dim.label}</label>{/if}
                <SelectInput
                  id={`filter-${dim.name}`}
                  choices={toSelectChoices(dim.values)}
                  bind:value={
                    () => value[dim.name] ?? '',
                    (v) => { value = { ...value, [dim.name]: v }; }
                  }
                />
              </div>
            {/if}
            {#if dim.multi && isAggregatedByDefault(dim) && isEmptyValue(dim)}
              <div class="filter-default-hint">Visar totalvärden</div>
            {/if}
          {/if}
        {/each}
      </div>
    {/if}
  </div>
{/if}

<style>
  .filter-renderer {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .filter-block {
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
    padding-bottom: 0.8rem;
    border-bottom: 1px solid #E2E8F0;
  }
  .filter-block:last-child {
    border-bottom: none;
  }
  .filter-block-title {
    font-size: 0.75rem;
    font-weight: 600;
    color: #065956;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .filter-attribution {
    display: inline-flex;
    gap: 0.2rem;
    margin-left: 0.4rem;
    vertical-align: middle;
  }
  .filter-dim-badges {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    margin-bottom: -0.2rem;
  }
  .filter-dim-label {
    font-size: 0.78rem;
    color: #4A5568;
    font-weight: 500;
  }
  :global(.filter-badge) {
    font-size: 0.55rem;
    color: #065956;
    background: #CCE6E5;
    padding: 0.05rem 0.35rem;
    border-radius: 10px;
    font-weight: 600;
    white-space: nowrap;
    max-width: 80px;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .filter-row {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }
  .filter-default-hint {
    font-size: 0.7rem;
    color: #94A3B8;
    font-style: italic;
    margin-top: -0.2rem;
    padding-left: 0.1rem;
  }
  .filter-label {
    font-size: 0.85rem;
    color: #4A5568;
  }
  .filter-placeholder {
    font-size: 0.8rem;
    color: #A0AEC0;
    font-style: italic;
    padding: 0.4rem 0;
  }
</style>
