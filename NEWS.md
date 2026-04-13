# ambolt 0.1.0

Initial release. A web application framework for R developers, powered by
Svelte 5 and ambiorix.

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
