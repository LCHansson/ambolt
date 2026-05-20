// fetchData — shared reactive data fetching for output components
//
// Handles URL building, trigger-vs-auto mode, loading/error state.
// Used by PlotOutput (parser: 'text') and DataTable (parser: 'json').
//
// Trigger mode behavior (matching Shiny's observeEvent + reactive pattern):
//   - Before first trigger: no fetch, output is empty
//   - First trigger (e.g. button click): fetch immediately with current params
//   - After activation: re-fetch reactively whenever params change,
//     debounced to avoid excessive requests during continuous input (e.g. slider drag)
//   - Existing content stays visible during re-fetch (no loading flash)

const DEBOUNCE_MS = 300;

/**
 * Create reactive fetch state for an output component.
 *
 * @param {() => object} getProps - Function returning current { endpoint, params, baseUrl, trigger }
 * @param {'text' | 'json'} parser - How to parse the response
 * @returns {{ data: any, error: string|null, loading: boolean }}
 */
export function createFetchState(getProps, parser = 'json') {
  let data = $state(null);
  let error = $state(null);
  let loading = $state(false);
  // `busy` is TRUE for the full lifetime of any fetch (first or re-fetch).
  // `loading` retains the original "first-fetch-only" semantics so the
  // line/bar chart "Loading chart..." text doesn't flash on every
  // slider keystroke. Consumers that want progress feedback on every
  // re-fetch (e.g. ChartOutput map overlay) should read `busy` instead.
  let busy = $state(false);
  let debounceTimer = null;

  function buildUrl() {
    const { endpoint, params, baseUrl } = getProps();
    const base = baseUrl || window.location.origin;
    const url = new URL(endpoint, base);
    for (const [key, val] of Object.entries(params)) {
      if (val !== undefined && val !== null) {
        url.searchParams.set(key, val);
      }
    }
    return url.toString();
  }

  function doFetch() {
    const url = buildUrl();
    // Only show loading spinner on first fetch (when no data exists yet).
    // Subsequent re-fetches keep showing previous data for smooth updates.
    if (data === null) loading = true;
    busy = true;
    error = null;

    fetch(url)
      .then(res => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return parser === 'json' ? res.json() : res.text();
      })
      .then(result => {
        data = result;
        loading = false;
        busy = false;
      })
      .catch(err => {
        error = err.message;
        loading = false;
        busy = false;
      });
  }

  function debouncedFetch() {
    clearTimeout(debounceTimer);
    // Flag busy immediately so consumers (e.g. ChartOutput map overlay)
    // can show a spinner during the debounce window too — otherwise the
    // user sees no feedback for the first DEBOUNCE_MS after releasing a
    // slider on a slow endpoint.
    busy = true;
    debounceTimer = setTimeout(doFetch, DEBOUNCE_MS);
  }

  const { trigger } = getProps();
  if (trigger !== undefined) {
    // Trigger-then-reactive mode:
    // Before activation (trigger === 0): do nothing.
    // After activation (trigger > 0): fetch reactively on any param change.
    let fullUrl = $derived.by(() => buildUrl());
    let triggerValue = $derived(getProps().trigger);
    let prevTrigger = 0;
    $effect(() => {
      const t = triggerValue;
      const url = fullUrl;  // track param changes after activation
      if (t > 0) {
        if (prevTrigger === 0) {
          // First activation — fetch immediately (user clicked the button)
          prevTrigger = t;
          doFetch();
        } else if (t > prevTrigger) {
          // Button clicked again — fetch immediately
          prevTrigger = t;
          doFetch();
        } else {
          // Param change after activation — debounce
          debouncedFetch();
        }
      }
    });
  } else {
    // Auto mode: re-fetch whenever params change (debounced)
    let fullUrl = $derived.by(() => buildUrl());
    $effect(() => {
      void fullUrl;
      debouncedFetch();
    });
  }

  return {
    get data() { return data; },
    get error() { return error; },
    get loading() { return loading; },
    get busy() { return busy; },
    refetch: doFetch
  };
}
