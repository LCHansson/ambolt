# ambolt 0.1.0.9067

* **Dynamic labels and help text via `alt_label` / `alt_help` /
  `alt_when`.** `app$input()` now accepts an `alt_label` (and/or
  `alt_help`) plus an `alt_when` condition (same shape as `show_when`:
  named list of `input_id -> allowed_value(s)`). When the condition
  evaluates truthy in the running app, the alt text replaces the
  primary `label` / `help`; otherwise the primary text shows. Useful
  for inputs that need to reflect another input's choice — e.g. an EK
  van switching its fuel type from diesel to bensin should retitle
  every related label and help tooltip. Implemented as a Svelte
  ternary expression on the prop at codegen time; works for both
  prop-based help (numeric, numeric_with_unit, select) and the
  external `.input-with-help` tooltip wrapper used by the other input
  types.

# ambolt 0.1.0.9066

* **SliderInput: fix filled-bar height clipping.** Previously, setting
  `--ambolt-slider-bar-height` larger than `--ambolt-slider-track-height`
  had no visible effect on WebKit because the range input's element
  height was sized to the track-height, clipping the bar's
  background-image. The input element is now sized to the max of the
  two heights, and two layered backgrounds are drawn (filled bar on
  top, full track underneath), each at its own height and vertically
  centered. Firefox's `::-moz-range-progress` now also uses
  `bar-height`. Apps that don't set `bar-height` (and therefore inherit
  it from `track-height`) are visually unchanged.

# ambolt 0.1.0.9065

* **Server-issued analytics session token.** Output render functions
  registered via `app$output()` now receive three extra fields on the
  `params` list passed to their render handler:
  * `params$.session` — opaque per-browser token (32 hex chars), read
    from the `ambolt_session` HttpOnly cookie. A fresh token is
    minted and the cookie set the first time a client hits any
    `/api/output/*` endpoint without one. 30-day Max-Age, SameSite=Lax.
    Intended for anonymous event logging — separate from the `auth`
    subsystem's user session.
  * `params$.client_ip` — value of `X-Forwarded-For` if present,
    otherwise `REMOTE_ADDR`.
  * `params$.user_agent` — value of the `User-Agent` request header.
  Apps that don't need these fields can ignore them; existing render
  functions are unaffected since the names start with a dot and won't
  collide with declared input ids.

# ambolt 0.1.0.9064

* **`createFetchState`: separate `busy` from `loading`.** `loading`
  still flips true only on the first fetch (preserving the no-flash
  re-fetch behaviour for line / bar / table outputs); a new `busy`
  field is true for the lifetime of any fetch, including re-fetches.
  Map ChartOutput now uses `busy` for its loading overlay so filter
  changes show a spinner immediately instead of leaving the canvas
  silent while the server crunches a 4–6 s query. `busy` is also
  flipped on at the start of the debounce window so consumers see
  feedback before the `DEBOUNCE_MS` delay elapses.
* **ChartOutput dot/bar colour resolution: strict fallback.** When a
  rendered category has no matching `legend.items` entry,
  Dot / BarY / BarX now fall back to `scales.color.range` by
  first-occurrence index (and finally to brand teal), instead of
  returning `undefined` and letting SveltePlot pick a colour from its
  own categorical palette. This eliminated a class of legend ↔ chart
  mismatches where the legend was correct but the dots overlaying
  the line ended up in a different (gold / orange) hue.

# ambolt 0.1.0.9063

* **`sidebar_layout()` wraps primary inputs.** Non-action sidebar
  children are now emitted inside a `<div class="primary-inputs">`
  block, while action buttons (and the optional scenario-button
  fallback) stay as direct children of `.sidebar`. Apps can now set
  the gap between the inputs block and the action button with a
  single rule on `.sidebar` (e.g. `display: flex; gap: 32px;`)
  instead of relying on adjacent-sibling margins across the input
  set. Purely additive DOM change — apps that do not target the new
  class are unaffected.

# ambolt 0.1.0.9062

* **ChartOutput line marks: per-(stroke, linetype) split.** Line
  rendering now emits one `<Line>` per cross-product of unique stroke
  and linetype values, each with a constant stroke color and dash
  pattern. SveltePlot's `<Line>` does not auto-split series when
  `stroke` is an accessor returning categorical strings — it draws a
  single path with per-point coloring, producing visible "bind"
  segments between distinct categories. The explicit split removes
  that artefact and guarantees one independent path per category.
* **ChartOutput color resolution via `legend.items`.** Line, BarY and
  BarX now resolve fill / stroke colors by looking up the rendered
  category value in `spec.legend.items[*].label` (single source of
  truth shared with the legend swatch). Falls back to
  `scales.color.range` by index when no legend is present. Eliminates
  legend ↔ chart color mismatches that arose when SveltePlot's
  internal category ordering diverged from the legend's
  first-occurrence order.
* **ChartOutput map view: spinner during server fetch + previous map
  retained.** The map branch now renders whenever `geoFeatures` exist,
  even while `fetch_state.loading` is true, with the
  `map-loading-overlay` drawn on top. Previous geo features are
  retained across filter changes; they are cleared only when the
  `geojson_endpoint` changes (KPI / geo-level change). Filter changes
  on a map view no longer blank the canvas with a generic
  "Loading chart…" text.

# ambolt 0.1.0.9061

* **ChartOutput map loading overlay.** Choropleth view shows a centered
  spinner over the existing map while a new GeoJSON fetch + join is in
  flight, instead of blanking the canvas. First paint (no previous map)
  uses a full-area spinner. Diagnostic timing (`fetch ms / join ms /
  features n`) logs to `console.debug`.
* **ChartOutput tooltip viewport flip.** When the cursor is in the
  right ~35 % of the viewport, the tooltip is translated to the left
  of the cursor via CSS so it never forces a horizontal scrollbar.
  Implemented as a `tooltip-flip` class toggled on the chart container
  by a mousemove listener; SveltePlot's `.svelteplot-tooltip`
  positioning is left intact, only translated.

# ambolt 0.1.0.9060

## ChartOutput: categorical legend + image download

* Control row above the chart: legend visibility toggle, `PNG` download
  (2× pixel density, computed CSS inlined for standalone rendering) and
  `SVG` download (vector, same inlining). Filenames are
  `<title-slug>_<YYYY-MM-DD>.<png|svg>`.
* Categorical legend (line, dot, bar) reads `legend.items[]`
  (color swatches + labels) and optional `legend.linetype_items[]`
  (dash patterns) from the chart spec.
* Overcrowded mode: when `legend.items.length > 10`, swatches and font
  shrink and a hint suggests hovering over the chart for exact values.
* `BarY` / `BarX` `fill` supports column-name accessors (parity with
  `Line`'s `stroke`) so bars can be coloured per category from the spec.

# ambolt 0.1.0.9058–9059

## KpiInfoModal + extra-info surfacing

* New `KpiInfoModal.svelte` — HTML5 `<dialog>` that lazy-fetches
  `/api/kpi_info?value=<source>:<entity_id>` from the host app and
  renders full metadata for a search hit (title, source badge, code,
  category, description, plus per-source extras). The host app
  implements the endpoint.
* `SearchResultsPanel` measures whether each card's description is
  visually truncated (`scrollHeight` vs `clientHeight` via a Svelte
  action) and shows a "more info" affordance when needed. The
  affordance also appears when the hit carries `has_extra_info: true`,
  so cards with rich metadata but a short visible description still
  expose it.
* `KpiInfoModal` renders inline markdown-style links `[label](url)` as
  `<a>` tags in description, contents, contact and notes fields. HTML
  is escaped first to prevent injection from upstream metadata.

# ambolt 0.1.0.9057

## SearchResultsPanel: enrich-priority hint

* Clicking an action on a search hit fires a fire-and-forget
  `GET /api/enrich_priority?entity_id=<id>` so a host-app background
  worker can lift that entity to the front of its work queue. No-op
  when the host doesn't expose the endpoint; network errors silently
  ignored. Only fires for sources the host opts in to via prop config.

# ambolt 0.1.0.9054–9056

## FilterRenderer: server-driven defaults + measure-axis awareness

* `findTotalCode()` reads an optional `totalt_code` field directly off
  the dim spec when the server provides it; falls back to a client-side
  heuristic over recognised total-aggregate tokens (`T`, `t1`, `TOT`,
  `0`, `00`, …) when absent.
* `isAggregatedByDefault()` short-circuits to `false` when the dim spec
  carries `is_measure_axis: true` — for "measure" dims where each value
  is a distinct metric rather than an aggregation, the aggregate
  hint stays hidden.

## SearchResultsPanel: freshness partition

* Hits with `freshness === "stale"` render under a separate heading
  below the current results instead of mixed in. Card markup factored
  into a `{#snippet card(item)}` and rendered twice with slightly
  reduced opacity on stale cards.

# ambolt 0.1.0.9048–9053

## FilterRenderer: compatibility-based dim disabling

* New optional `kpi_specs` field on the filter spec, each entry
  `{ kpi_id, source, valid_combos: [[dim, ...], ...] }`. Dims not in
  any valid combo containing the user's currently-narrowed selection
  are greyed out (opacity 0.4 + `pointer-events: none`) with an
  incompatibility tooltip.
* Multi-KPI views are union-friendly: a dim is enabled if at least
  one KPI in the selection considers it compatible. KPIs without
  `valid_combos` count as "no constraint" so source-specific
  restrictions don't bleed into other sources' filters.
* Range dims (time sliders) and the implicit year axis are always
  treated as enabled.
* Falls back gracefully to the legacy single-KPI spec shape.
* Bundled fixes (0.1.0.9051–9053): `{@const}` placement under the new
  `.dim-row` wrapper, vertical-rhythm regression from the wrapper, and
  a cross-KPI false-disable when an active dim doesn't exist in a
  sibling KPI's universe.

# ambolt 0.1.0.9050

## app$run(clean = TRUE)

* New `clean` argument on `app$run()`. Removes the entire
  `.ambolt_build/` directory (including `node_modules` and the Vite
  cache) before starting, forcing a fresh install and full rebuild.
  Implies `rebuild = TRUE`. Use when dependencies or Vite's transform
  cache are in an inconsistent state; for ambolt-version updates
  `rebuild = TRUE` is still enough and faster.

# ambolt 0.1.0.9049

## Build: suppress css_unused_selector warnings

* Generated `vite.config.js` installs an `onwarn` handler on the
  Svelte plugin that filters `css_unused_selector` warnings, which
  vite-plugin-svelte ≥ 5 treats as build errors. They are emitted for
  CSS the static analyser cannot prove reachable (e.g. rules emitted
  unconditionally by the codegen) and are lint noise, not actual
  problems.

# ambolt 0.1.0.9047

## ChartOutput: surface empty-state title

* The empty branch (`chartData.length === 0`) renders the chart spec's
  `title` instead of a hardcoded fallback, so the host app can pass an
  actionable hint via `chart_spec(title = ...)`.

# ambolt 0.1.0.9042–9046

## ChartOutput tooltip overhaul

* **Key–value grid layout.** The tooltip surfaces every meaningful
  column on the hovered datum (grouping cols, filter dims, series),
  with dedicated rows for the period (X) and the value (Y). Value row
  is bolder and visually separated. Keys are humanised via a
  `KEY_LABELS` table that host apps can extend.
* **Period block.** Derived from `year` + `period_label` instead of
  the chart's `xChannel`. Annual data renders just the year row;
  sub-annual adds a period row. The interpolated end-of-period `date`
  value (used only for sorting) is no longer surfaced.
* **Dedup + label preference.** Time-equivalent columns are skipped
  (the period row already covers them). When both `<dim>` and
  `<dim>_text` / `<dim>_label` exist, the raw code is hidden in favour
  of the human label.
* **Implicit-total hiding.** Columns whose only non-null value across
  the whole dataset is a recognised total-aggregate token are hidden
  from the tooltip. Multi-KPI overlays ignore null values when counting
  uniques so the dedup still triggers.
* The composite `series` stroke key is suppressed; each grouping dim
  already has its own row, so the composite is redundant.

## Card / chip metadata polish

* `BasketPanel`, `SearchResultsPanel` and `MultiViewPanel` show
  `source` + `entity_id` under each title/label (small mono-spaced)
  and add `title` attributes for full-name hover on truncated text.

# ambolt 0.1.0.9041

## VizTypeSelector polish

* Tighter button padding and font-size. Inactive buttons hide the
  verbal label (icon only); active button retains both. `title`
  attribute on inactive buttons preserves accessible naming. Wrap
  margin adjusted so the selector sits above the chart it controls.

# ambolt 0.1.0.9040

## MultiViewPanel: empty-state gating

* The empty-state placeholder only renders when the basket has items
  but no views yet. In pure single-view mode (basket empty) the
  component produces no output, leaving the host layout's own
  single-view chart uncluttered.

# ambolt 0.1.0.9039

## FilterRenderer: empty-filter total hint

* Multi-select dims start empty on initial render instead of
  pre-filling with a total-aggregate code.
* When an empty filter resolves to a total downstream (the dim has a
  recognised total code or matching label), the renderer shows a
  discreet hint below the input.
* `findTotalCode()` returns `null` instead of falling back to the
  first value, so `isAggregatedByDefault()` can distinguish real
  total-aggregate dims from arbitrary categorical dims.

# ambolt 0.1.0.9038

## Basket system + new inputs + chart enhancements

* New `basketStore.svelte.js` — singleton Svelte 5 store for
  collecting data series across searches, following the `modalStore`
  pattern. API: `basket.add(item)`, `basket.remove(value)`,
  `basket.clear()`, `basket.toggle()`, `basket.has(value)`, reactive
  `basket.items` / `basket.count`.
* New `BasketPanel.svelte` — fixed-position panel at the bottom of
  the viewport. Shows mini-cards for collected series, is
  collapsible, and exposes an action button to enter exploration
  mode. Codegen auto-appends it when a `search_results_panel` input
  is registered.
* New input `search_results_panel` — data-driven component that
  replaces R-rendered HTML search results. Fetches from `/api/search`
  with a reactive `query` prop, groups results by source with a
  visual separator, exposes source filter buttons, shows a category
  metadata line, and pairs each card with dual action buttons
  (open / add-to-basket) plus an added-state for items already in
  the basket. Codegen treats it as display-only.
* New input `viz_type_selector` — horizontal icon button group for
  visualization type selection (Bootstrap Icons:
  `bi-graph-up`, `bi-bar-chart-fill`, `bi-geo-alt-fill`). Per-button
  `disabled` state for data-dependent availability.
* `FilterRenderer` now prefers total-aggregate codes (`T`, `t1`,
  `TOT`) and labels as defaults instead of always picking the first
  value.
* New `app$init_script(js)` — injects custom JavaScript into
  `main.js` that runs after the Svelte app mounts. Useful for
  URL-based state initialisation, analytics and debug tooling.

## ChartOutput: grid mode, legend, correct projection

* `chart_spec.grid` array renders multiple sub-charts as small
  multiples in a CSS grid layout.
* `chart_spec.legend` renders color swatches with labels below the
  chart (used for choropleth maps).
* Map projection switched from `geoMercator` (string, broken) to
  `geoConicEqualArea` (function) for correct area-preserving
  rendering.

# ambolt 0.1.0.9036

## page_content as top-level layout

* `app$ui()` accepts `page_content()` as the top-level layout node,
  in addition to `sidebar_layout()`, enabling fluid full-width
  layouts analogous to Shiny's `fluidPage()`. `sidebar_layout()` can
  be nested inside `page_content()` (or any other container); the
  codegen emits the same `.sidebar-layout` / `.sidebar` / `.content`
  classes so nested sidebars get framework styling automatically.

## ChartOutput: Geo mark fixes

* Map/choropleth data join now uses `geoMark.id_field` (from
  `mark_geo(id_field = ...)`) instead of the non-existent
  `geoMark.fill_key` property.
* Map borders use the R-specified `stroke` / `strokeWidth` from the
  mark spec, with darker defaults (#333 @ 0.8px vs #666 @ 0.5px).

# ambolt 0.1.0.9034

## ServerSearchInput: live-search fallback

* `ServerSearchInput` gains two optional props: `liveEndpoint` (URL
  of a per-source live-search endpoint that accepts
  `?source=<id>&q=<query>` and returns the main endpoint's shape) and
  `liveSources` (array of `{id, label}` objects describing the
  sources to offer buttons for). When either the main endpoint
  reports `suggest_live: true` or the local result list is empty, a
  small panel at the bottom of the dropdown offers one button per
  live source. Clicking fetches from `liveEndpoint` and merges rows
  into the dropdown.
* The main endpoint response may be an object with `results` plus
  meta-fields (`status`, `count`, `suggest_live`, `query`); callers
  returning a bare JSON array continue to work unchanged.
* Codegen wiring:
  `app$input("x", type = "server_search", live_endpoint = ...,
  live_sources = list(list(id = "...", label = "..."), ...))`
  translates to the corresponding Svelte props.

# ambolt 0.1.0

Initial release. A web application framework for R developers,
powered by Svelte 5 and ambiorix.

## Inputs

* **dynamic_filters** — filter component that watches another input
  and refetches a `filter_spec` from a server endpoint. Renders
  adaptive controls via `FilterRenderer`; the bound value is a JSON
  string consumable in R via `jsonlite::fromJSON(params$filters)`.
  Props: `spec_endpoint`, `trigger`, `trigger_param_name`,
  `year_min`, `year_max`.
* **range_slider** — two-handle numeric range slider. Bound value is
  a `[from, to]` array. Designed for time periods but works for any
  numeric range.
* **multi_select** — multi-select dropdown with searchable options.
  Bound value is an array of selected codes. Choices use
  `{code, text}`.
* **server_search** — server-backed typeahead with configurable
  debounce. Dropdown shows label, description snippet and source
  badge per result. Keyboard navigation (arrow keys, enter, escape)
  and clear button. Props: `endpoint`, `placeholder`, `debounce`,
  `baseUrl`, `valueField`.
* **FilterRenderer.svelte** — utility component that renders dynamic
  filter controls from a `filter_spec` object. Groups dimensions
  into time / geography / other blocks. Embedded by the
  dynamic-filters wiring.

## Outputs

* **chart** — interactive charts rendered via SveltePlot. R returns a
  JSON spec (data + marks + scales); the frontend renders it
  natively using SveltePlot's grammar-of-graphics components.
  Supported marks: `line`, `dot`, `bar`, `geo`, `ruleX`, `ruleY`.
  `svelteplot` (^0.14.0) added as an npm dependency in the generated
  `package.json`; a Vite alias for `svelteplot` is added to the
  generated `vite.config.js`.
* ChartOutput renders an `HTMLTooltip` that snaps to the nearest data
  point on hover, with formatted X and Y values. Default locale is
  configurable via `chart_spec(locale = ..., number_format = ...)`;
  explicit `tickFormat` on x and y axes suppresses SveltePlot's
  auto-compact notation.

## Runtime modal rendering

* Modals use the same composable layout functions as pages
  (`page_content()`, `section()`, `view_switcher()`, …) via a runtime
  renderer (`RenderNode.svelte`). New response shape:
  `list(title, content = page_content(...))` alongside the existing
  `list(title, html)` and `list(title, fields)` forms. New
  constructor: `data_table()` for tables with inline endpoint
  config.

## Core API

* `create_app()` — application constructor with module system, auth
  and themes.
* Layout DSL: `page_content()`, `page_header()`, `view_switcher()`,
  `section()`, `columns()`, `details()`, `sidebar_layout()`.
* HTML helpers: `action_button()`, `modal_link()`, `badge()`,
  `detail_row()`, `detail_grid()`, `action_bar()`, `html_escape()`.

## Components

* **DataTable** — sortable, searchable, paginated tables with inline
  editing.
* **CardGrid** — filterable card layout with search, favorites,
  rich fields.
* **StatCards** — key metrics display.
* **ViewSwitcher** — toggle between multiple views of the same data.
* **Modal** — stacked modals with back navigation, tabs, forms.
* **FormBody** — auto-generated forms with validation.
* **NavSidebar** — collapsible navigation with page routing.
* **AuthGuard** — login / session management with argon2id passwords.
* **Toast** — notification system.

## Theme system (3-tier)

1. **Theme tokens** (`app$theme()`) — global CSS variables for
   colors, fonts, radius and component-level overrides (nav, table,
   badge, button, card, modal).
2. **Semantic props** — per-instance control via `gap`, `compact`,
   `variant`, `icon`.
3. **Escape hatch** — every DSL function accepts `class` and `style`
   parameters.

## Declarative action system

* Server-rendered HTML uses `data-ambolt-*` attributes for fetch
  actions. No inline JavaScript needed — `action_button()` generates
  pure HTML.

## Page lifecycle

* `ambolt:page-enter` / `ambolt:page-exit` events for multi-page
  apps. `HtmlOutput` supports `refreshEvent` for event-driven
  re-fetching.

## Package infrastructure

* R CMD check passes with 0 errors; testthat assertions across auth,
  layout and HTML helpers; auto-generated NAMESPACE via roxygen2;
  man pages with `@param` / `@return` / `@examples`; MIT LICENSE;
  getting-started and multi-page-with-auth vignettes.
