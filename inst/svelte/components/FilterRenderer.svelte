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
    yearMax = 2030
  } = $props();

  let dimensions = $derived(spec?.dimensions ?? []);

  function dimsByClass(cls) {
    return dimensions.filter(d => d.class === cls);
  }

  let timeDims = $derived(dimsByClass('time'));
  let geoDims  = $derived(dimsByClass('geo'));
  let otherDims = $derived(dimsByClass('other'));

  // Helper: per-dimension bounds (use dim's min/max if provided, else fallback)
  function rangeBounds(d) {
    return [d.min ?? yearMin, d.max ?? yearMax];
  }

  // Initialize defaults for any missing dimension values.
  // For mandatory categorical dims, pre-fill with first value so user
  // immediately sees what's being shown (rather than empty filter widgets).
  $effect(() => {
    if (!spec) return;
    let changed = false;
    const v = { ...value };
    for (const d of dimensions) {
      if (v[d.name] === undefined) {
        if (d.type === 'range') {
          v[d.name] = rangeBounds(d);
        } else if (d.multi) {
          // Mandatory multi-select: pre-fill with first value (visible in UI)
          if (d.required && d.values && d.values.length > 0) {
            v[d.name] = [d.values[0].code];
          } else {
            v[d.name] = [];
          }
        } else if (d.values && d.values.length > 0) {
          v[d.name] = d.values[0].code;
        } else {
          v[d.name] = '';
        }
        changed = true;
      }
    }
    if (changed) value = v;
  });

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
        <div class="filter-block-title">Tidsperiod</div>
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
        <div class="filter-block-title">Geografi</div>
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
        {/each}
      </div>
    {/if}

    {#if otherDims.length > 0}
      <div class="filter-block">
        <div class="filter-block-title">Övriga</div>
        {#each otherDims as dim (dim.name)}
          {#if dim.type === 'categorical' && dim.values}
            {#if dim.multi}
              <MultiSelect
                id={`filter-${dim.name}`}
                label={dim.label}
                choices={toChoices(dim.values)}
                bind:value={
                  () => value[dim.name] ?? [],
                  (v) => { value = { ...value, [dim.name]: v }; }
                }
              />
            {:else}
              <div class="filter-row">
                <label for={`filter-${dim.name}`} class="filter-label">{dim.label}</label>
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
  .filter-row {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
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
