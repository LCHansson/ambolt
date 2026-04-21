# ambolt 0.1.0.9047

## ChartOutput: surface empty-state title (2026-04-21)

* The empty branch (`chartData.length === 0`) now renders the chart
  spec's `title` instead of a hardcoded "Ingen data". This lets the
  host app pass an actionable hint via `chart_spec(title=...)` —
  e.g. "Inga data från Trafikanalys — pröva att utelämna kortyp".

# ambolt 0.1.0.9046

## Tooltip implicit-Totalt: handle multi-KPI nulls (2026-04-21)

* `implicitTotaltCols` now ignores null values when counting unique
  values per column. Previously a multi-KPI overlay had two unique
  values per column (the Totalt code from one KPI's rows, and `null`
  from the other KPI's rows) and so no columns got hidden.

# ambolt 0.1.0.9045

## Tooltip: hide implicit-Totalt columns (2026-04-21)

* New `implicitTotaltCols` derived in ChartOutput: a column is hidden
  from the tooltip when (a) it has only one unique value across the
  whole `chartData`, and (b) that value is a Totalt-like marker
  (`Totalt`, `Alla`, `Samtliga`, `Båda könen`, `T`, `t1`, `TOT`, …).
  An explicitly chosen single value (e.g. "Med last") still shows.

# ambolt 0.1.0.9044

## Tooltip period block + KPI label decoupling (2026-04-21)

* Tooltip period rows are derived from `year` + `period_label` instead
  of the chart's `xChannel`. The interpolated end-of-period `date` value
  (used only for sorting) is no longer surfaced to the user. Annual data
  → just "År:". Sub-annual → "År:" + "Period:".
* `series` (composite stroke key like "Invånare · Män") is suppressed
  from the tooltip in favour of a separate `kpi_label` column the host
  app sets. Each grouping dimension already shows on its own row, so
  the composite is redundant.
* KEY_LABELS extended with Swedish names for SCB pixieweb dims (Kon →
  Kön, ContentsCode → Innehåll, Sektor, Region, UtbMYH).

# ambolt 0.1.0.9043

## Tooltip dedup + label preference (2026-04-21)

* `tooltipRows()` now skips time-equivalent columns (year, period_label,
  Tid, time, ar, manad, kvartal) — the explicit period row at the
  bottom already conveys this, so the previous duplication ("Period"
  AND "Tid" with identical values) is gone.
* When both `<dim>` and `<dim>_text` (or `<dim>_label`) exist on the
  datum, the raw code is hidden in favour of the human label. E.g.
  `Kon = "1"` is suppressed when `Kon_text = "Män"` is present.

# ambolt 0.1.0.9042

## Richer chart tooltip + KPI metadata polish (2026-04-20)

* **ChartOutput.svelte:** tooltip is now a key-value grid that surfaces
  every meaningful column on the hovered datum (KPI grouping cols,
  filter dimensions, series), with dedicated rows for the period (X)
  and the value (Y). Value row is bolder and visually separated. Keys
  are humanised via a `KEY_LABELS` table (year→År, gender→Kön etc.).
* **BasketPanel.svelte:** basket cards show source + entity ID under
  the title (small mono-spaced, light grey). Title gets a `title`
  attribute for hover-tooltip on truncated long names.
* **SearchResultsPanel.svelte:** card subtitle re-organised — category
  and entity ID now render as siblings on a separate line, with the ID
  in mono-spaced light grey. Title gets full-name hover.
* **MultiViewPanel.svelte:** KPI chips show `source · entity_id` under
  the label and full `label (source · id)` as the chip's `title`.

# ambolt 0.1.0.9041

## VizTypeSelector polish (2026-04-20)

* Tightened button padding (`0.25rem 0.5rem`) and font-size (`0.78rem`)
  for a more compact icon-row footprint.
* Inactive buttons now hide the verbal label — only the icon shows.
  The active button still displays both icon and label, and the
  `title` attribute on inactive buttons preserves accessible naming.
* Wrap margin: `0 0 0.4rem 0` so the selector sits cleanly *above*
  the chart it controls (previously had `margin-top: -0.5rem` to
  anchor below).

# ambolt 0.1.0.9040

## MultiViewPanel: gate empty-state placeholder on basket count (2026-04-20)

* The "Lägg till nyckeltal i korgen..." placeholder now only renders when
  the basket has items but no views yet. In pure single-view mode
  (basket empty) the component produces no output, leaving the host
  layout's own single-view chart uncluttered.

# ambolt 0.1.0.9039

## FilterRenderer: empty-filter Totalt hint (2026-04-20)

* Multi-select dims no longer pre-fill with a Totalt code on initial
  render — they start empty so the user sees a clean "no choice" state.
* When an empty filter resolves to Totalt downstream (the dim has a real
  Totalt code like `t1`/`T`/`TOT` or label `Totalt`/`Alla`), the renderer
  shows a discreet "Visar totalvärden" hint below the input.
* Geographic block shows "Visar Riket" hint when no kommun/region is
  picked — mirrors the Totalt convention.
* `findTotalCode()` now returns `null` instead of falling back to the
  first value, so `isAggregatedByDefault()` can distinguish real Totalt
  dims from arbitrary categorical dims.

# ambolt 0.1.0.9038

## Basket system: store + panel + codegen (2026-04-17)

* New `basketStore.svelte.js` — singleton Svelte 5 store for collecting
  data series across searches. Follows the `modalStore` pattern.
  API: `basket.add(item)`, `basket.remove(value)`, `basket.clear()`,
  `basket.toggle()`, `basket.has(value)`, reactive `basket.items`/`basket.count`.
* New `BasketPanel.svelte` — fixed-position panel at the bottom of the
  viewport. Shows mini-cards for collected series, collapsible, with
  "Utforska data" button to enter exploration mode.
* Codegen auto-appends `<BasketPanel />` when the app registers a
  `search_results_panel` input (basket-enabled apps).

## SearchResultsPanel component (2026-04-17)

* New input type `search_results_panel` — data-driven Svelte component
  that replaces R-rendered HTML search results. Features:
  - Fetches from `/api/search` endpoint with reactive `query` prop
  - Groups results by source with visual separator
  - Source filter buttons (Alla / KOLADA / SCB / TRAFA)
  - Category metadata line (operating_area / subject_path / product)
  - Dual action buttons: "Visa direkt" + "+ Lägg i korg"
  - "I korg ✓" state for already-added items
* New codegen support: `search_results_panel` input type generates
  no `$state` variable (display-only) and passes `query` prop.

## VizTypeSelector component (2026-04-17)

* New input type `viz_type_selector` — horizontal icon button group for
  visualization type selection. Uses Bootstrap Icons (`bi-graph-up`,
  `bi-bar-chart-fill`, `bi-geo-alt-fill`). Supports per-button `disabled`
  state for data-dependent availability.

## FilterRenderer: smart defaults (2026-04-17)

* `FilterRenderer` now prefers "total" codes (`T`, `t1`, `TOT`) and labels
  (`Totalt`, `Alla`, `Samtliga`) as defaults, instead of always picking the
  first value.

## app$init_script() (2026-04-17)

* New `app$init_script(js)` method — injects custom JavaScript into
  `main.js` that runs after the Svelte app mounts. Useful for URL-based
  state initialization, analytics, and debug tooling.

## ChartOutput: grid mode + legend (2026-04-17)

* ChartOutput supports `grid` array in chart_spec — renders multiple
  sub-charts as small multiples in a CSS grid layout.
* ChartOutput supports `legend` in chart_spec — renders color swatches
  with labels below the chart (used for choropleth maps).
* Map projection changed from `geoMercator` (string, broken) to
  `geoConicEqualArea` (function) for correct rendering with proper
  area preservation. Documented in svelteplot_notes.md #10-11.

# ambolt 0.1.0.9036

## page_content as top-level layout (2026-04-18)

* `app$ui()` now accepts `page_content()` as the top-level layout node,
  in addition to the existing `sidebar_layout()`. This enables fluid
  full-width layouts analogous to Shiny's `fluidPage()`.
* `sidebar_layout()` can be nested inside `page_content()` (or any other
  container node). The codegen emits the same `.sidebar-layout` /
  `.sidebar` / `.content` CSS classes so nested sidebars get framework
  styling automatically.
* Example:
  ```r
  app$ui(page_content(
    section("Search", "query"),
    sidebar_layout(
      sidebar = sidebar(section("Filters", "filters")),
      main = main("chart", "commentary")
    )
  ))
  ```

## ChartOutput: Geo mark fixes (2026-04-18)

* Fixed data join bug in map/choropleth rendering: the join key now
  correctly uses `geoMark.id_field` (from `mark_geo(id_field = ...)`)
  instead of the non-existent `geoMark.fill_key` property.
* Map borders now use the R-specified `stroke`/`strokeWidth` from the
  mark spec, with darker defaults (#333 @ 0.8px vs #666 @ 0.5px).

# ambolt 0.1.0.9034

## server_search: live-search fallback ("nödutgång") (2026-04-15)

* `ServerSearchInput` gains two optional props:
  * `liveEndpoint` — URL of a per-source live-search endpoint that accepts
    `?source=<id>&q=<query>` and returns the same shape as the main search
    endpoint.
  * `liveSources` — array of `{id, label}` objects describing the sources
    to offer buttons for.
  When either the main endpoint reports `suggest_live: true` or the local
  result list is empty, a small panel at the bottom of the dropdown offers
  one button per live source. Clicking a button fetches from `liveEndpoint`
  and merges the returned rows into the dropdown.
* The main endpoint response may now be an object with `results` +
  meta-fields (`status`, `count`, `suggest_live`, `query`). Callers that
  still return a bare JSON array continue to work unchanged.
* New codegen wiring: `app$input("x", type = "server_search",
  live_endpoint = "/api/search/live", live_sources = list(list(id = "scb",
  label = "SCB"), ...))` is translated into the corresponding
  `liveEndpoint`/`liveSources` Svelte props.

# ambolt 0.1.0

Initial release. A web application framework for R developers, powered by
Svelte 5 and ambiorix.

## DynamicFilters input type (2026-04-15)

- New input type: `dynamic_filters` — smart filter component that watches
  another input's value and refetches a `filter_spec` from a server endpoint.
  Renders adaptive controls via FilterRenderer; values are exposed as a
  JSON string for ambolt's `depends_on` mechanism.
- Bound value is a JSON string like `'{"year":[2010,2024],"gender":"T"}'`.
- Outputs read filter values via `jsonlite::fromJSON(params$filters)`.
- Props: `spec_endpoint`, `trigger` (other input id), `trigger_param_name`,
  `year_min`, `year_max`.
- Files: `DynamicFilters.svelte`, `utils.R`, `codegen_markup.R`, `codegen_script.R`.

## Adaptive filter components (2026-04-15)

- New input type: `range_slider` — two-handle numeric range slider via
  `RangeSlider.svelte`. Bound value is a `[from, to]` array. Designed for
  time periods but works for any numeric range.
- New input type: `multi_select` — multi-select dropdown with searchable
  options via `MultiSelect.svelte`. Bound value is an array of selected
  codes. Choices use `{code, text}` format (vs the existing `select`'s
  `{value, label}`).
- New utility component: `FilterRenderer.svelte` — renders dynamic filter
  controls from a `filter_spec` object. Groups dimensions into three
  blocks (Tidsperiod / Geografi / Övriga) per the SU wireframe design.
  Not yet a registered output type — meant to be embedded by app authors
  in fas 4.3.
- Files: `RangeSlider.svelte`, `MultiSelect.svelte`, `FilterRenderer.svelte`,
  `utils.R`, `codegen_markup.R`, `codegen_script.R`, `index.js`.

## ChartOutput tooltips + locale (2026-04-15)

- `ChartOutput.svelte` now renders an `HTMLTooltip` over the chart that
  snaps to the nearest data point on hover. Shows formatted x and y
  values from the primary positional mark (line/dot/bar).
- Locale defaults to `sv-SE` with explicit decimal `tickFormat` on x and y
  axes. Suppresses SveltePlot's auto-compact notation (which would
  otherwise render 1200 as "1.2k" / "1,2 tn").
- x-axis: no grouping (years like 2023 stay unformatted).
- y-axis: grouping ON (1200 → "1 200" with svensk space separator).
- R can override locale and numberFormat via `chart_spec(locale=, number_format=)`.

## ChartOutput / SveltePlot integration (2026-04-14)

- New output type: `chart` — interactive charts rendered via SveltePlot.
  R returns a JSON spec (data + marks + scales); the frontend renders it
  natively using SveltePlot's grammar-of-graphics components.
- Supported marks: `line`, `dot`, `bar`, `ruleX`, `ruleY`. Extensible.
- `svelteplot` (^0.14.0) added as npm dependency in generated package.json.
- Vite alias for `svelteplot` added to generated `vite.config.js` so
  imports from components living outside the build dir can resolve.
- Each mark receives `data` explicitly (SveltePlot marks don't inherit
  from `<Plot>` — default is empty array).
- Registered via `app$output(id, type = "chart", render = function(params) { ... })`.
- Files: `ChartOutput.svelte`, `utils.R`, `build.R`.

## ServerSearchInput (2026-04-13)

- New input type: `server_search` — server-backed typeahead search.
  Unlike `SearchSelect` (which filters a client-side choices array), this
  component fetches suggestions from an API endpoint with configurable debounce.
- Props: `endpoint`, `placeholder`, `debounce` (ms), `baseUrl`, `valueField`.
- Dropdown shows label, description snippet, and source badge per result.
- Keyboard navigation (arrow keys, enter, escape) and clear button.
- Registered via `app$input(id, type = "server_search", endpoint = "/api/search")`.
- Files: `ServerSearchInput.svelte`, `utils.R`, `codegen_markup.R`, `codegen_script.R`.

## Runtime modal rendering (2026-04-11)

- Modals now use the same composable layout functions as pages
  (`page_content()`, `section()`, `view_switcher()`, etc.) via a runtime
  renderer (`RenderNode.svelte`).
- New response shape: `list(title, content = page_content(...))` alongside
  the existing `list(title, html)` and `list(title, fields)` forms.
- New constructor: `data_table()` for tables with inline endpoint config.
- All production app modals (~15 HTML-shaped) ported to the new content path.
- Legacy `entry.tabs` branch removed from Modal.svelte.
- `.drop_nulls()` applied to all layout constructors to prevent
  NULL-serialization issues on the frontend.

## Package infrastructure (2026-04-12)

- R CMD check passes with 0 errors
- 73 testthat assertions across auth, layout, and HTML helpers
- Auto-generated NAMESPACE via roxygen2
- 27 man pages with `@param`, `@return`, and `@examples`
- MIT LICENSE file
- Demo apps use `library(ambolt)` with `source()` fallback
- Getting-started and multi-page-with-auth vignettes

## Core API

- `create_app()` — application constructor with module system, auth, themes
- Layout DSL: `page_content()`, `page_header()`, `view_switcher()`, `section()`,
  `columns()`, `details()`, `sidebar_layout()`
- HTML helpers: `action_button()`, `modal_link()`, `badge()`, `detail_row()`,
  `detail_grid()`, `action_bar()`, `html_escape()`

## Components

- **DataTable** — sortable, searchable, paginated tables with inline editing
- **CardGrid** — filterable card layout with search, favorites, rich fields
- **StatCards** — key metrics display
- **ViewSwitcher** — toggle between multiple views of the same data
- **Modal** — stacked modals with back navigation, tabs, forms
- **FormBody** — auto-generated forms with validation
- **NavSidebar** — collapsible navigation with page routing
- **AuthGuard** — login/session management with argon2id passwords
- **Toast** — notification system

## Theme System (3-tier)

1. **Theme tokens** (`app$theme()`) — global CSS variables for colors, fonts,
   radius, and component-level overrides (nav, table, badge, button, card, modal)
2. **Semantic props** — per-instance control via `gap`, `compact`, `variant`, `icon`
3. **Escape hatch** — every DSL function accepts `class` and `style` parameters

## Declarative Action System

Server-rendered HTML uses `data-ambolt-*` attributes for fetch actions.
No inline JavaScript needed — `action_button()` generates pure HTML.

## Page Lifecycle

`ambolt:page-enter` / `ambolt:page-exit` events for multi-page apps.
HtmlOutput supports `refreshEvent` for event-driven re-fetching.
