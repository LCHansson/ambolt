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
