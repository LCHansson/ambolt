# --- ambolt layout DSL ---------------------------------------------
#
# Composable layout functions that return data nodes forming a layout tree.
# The tree is passed to app$ui() and walked by the codegen to produce
# Svelte markup. Each function returns a plain named list.
#
# Styling: All layout functions accept `class` and `style` for per-instance
# customization (tier 3). Global theming uses app$theme() tokens (tier 1).
# Semantic props like `compact`, `gap`, `variant` provide framework-level
# control (tier 2).
#
# Shiny analogy:
#   sidebar_layout() ≈ sidebarLayout()
#   sidebar()        ≈ sidebarPanel()
#   main()           ≈ mainPanel()
#   section()        ≈ wellPanel() / conditionalPanel()
#   columns()        ≈ fluidRow(column(), column())

#' Drop NULL fields from a DSL node list.
#'
#' R's NULL values get serialized by jsonlite in ways that produce truthy
#' JavaScript values (empty object), which breaks Svelte's truthiness-based
#' dispatch (e.g. `{#if node.href}`). DSL constructors MUST call this before
#' returning so only explicitly-set fields reach the frontend over JSON.
#' Non-NULL falsy values (FALSE, 0, empty string/list) are preserved.
#' @noRd
.drop_nulls <- function(x) {
  x[!vapply(x, is.null, logical(1))]
}

#' Top-level two-panel layout: fixed sidebar + flexible main area.
#'
#' @param sidebar A [sidebar()] node.
#' @param main A [main()] node.
#' @return A layout node (named list with `type = "sidebar_layout"`).
#' @export
#' @examples
#' sidebar_layout(
#'   sidebar = sidebar("price", "qty"),
#'   main = main("result")
#' )
sidebar_layout <- function(sidebar, main) {
  stopifnot(sidebar$type == "sidebar", main$type == "main")
  list(type = "sidebar_layout", sidebar = sidebar, main = main)
}

#' Sidebar panel — left column in a sidebar_layout.
#'
#' @param ... Children: input/output ids (strings) or nested layout nodes.
#' @return A layout node (named list with `type = "sidebar"`).
#' @export
sidebar <- function(...) {
  list(type = "sidebar", children = list(...))
}

#' Main content panel — right column in a sidebar_layout.
#'
#' @param ... Children: input/output ids (strings) or nested layout nodes.
#' @return A layout node (named list with `type = "main"`).
#' @export
main <- function(...) {
  list(type = "main", children = list(...))
}

#' Grouped section with optional label and visibility rules.
#' Can contain inputs, outputs, or nested layout nodes.
#'
#' @param label Character (first positional). Optional heading.
#' @param ... Child item ids or layout nodes.
#' @param show_when List. Input-driven visibility condition.
#' @param show_after Character. Trigger id for visibility gating.
#' @param compact Logical. If TRUE, inputs render in a dense inline layout
#'   (label left-aligned, input right) instead of the default stacked layout.
#'   Useful for assumption/settings panels with many small inputs.
#' @param toggle Character. Input id of a checkbox that controls this section.
#'   The checkbox is rendered in the section header (not the body), and
#'   child content is dimmed when unchecked. The checkbox must also appear
#'   in the children list so the framework knows about it.
#' @param class Character. Additional CSS class(es).
#' @param style Named list. Inline CSS properties (e.g., list(padding = "2rem")).
#' @return A layout node (named list with `type = "section"`).
#' @export
#' @examples
#' section("Inputs", "price", "qty", compact = TRUE)
section <- function(label = NULL, ..., show_when = NULL, show_after = NULL,
                    compact = FALSE, toggle = NULL, class = NULL, style = NULL) {
  .drop_nulls(list(
    type = "section",
    label = label,
    children = list(...),
    show_when = show_when,
    show_after = show_after,
    compact = isTRUE(compact),
    toggle = toggle,
    class = class,
    style = style
  ))
}

#' Side-by-side columns. Children rendered in equal-width columns.
#' Collapses to stacked on narrow viewports.
#'
#' @param ... Child items or layout nodes (one per column).
#' @param gap Character. CSS gap value (e.g., "2rem"). Overrides default.
#' @param class Character. Additional CSS class(es).
#' @param style Named list. Inline CSS properties.
#' @return A layout node (named list with `type = "columns"`).
#' @export
#' @examples
#' columns("input1", "input2", "input3", gap = "1.5rem")
columns <- function(..., gap = NULL, class = NULL, style = NULL) {
  .drop_nulls(list(type = "columns", children = list(...),
                   gap = gap, class = class, style = style))
}

#' Collapsible section using native HTML <details>/<summary>.
#' Click the label to expand/collapse the content. No JavaScript needed.
#'
#' @param label Character. The clickable summary text (e.g., "Läs mer").
#' @param ... Child item ids or layout nodes shown when expanded.
#' @param open Logical. If TRUE, starts expanded. Default FALSE.
#' @param show_after Character. Optional trigger id for visibility gating.
#' @param class Character. Additional CSS class(es).
#' @param style Named list. Inline CSS properties.
#' @return A layout node (named list with `type = "details"`).
#' @export
details <- function(label, ..., open = FALSE, show_after = NULL,
                    class = NULL, style = NULL) {
  .drop_nulls(list(
    type = "details",
    label = label,
    children = list(...),
    open = isTRUE(open),
    show_after = show_after,
    class = class,
    style = style
  ))
}

# --- Pages-mode DSL -------------------------------------------------
#
# Declarative layout functions for pages-mode apps. These let the
# developer compose page UI in R instead of writing raw HTML strings.
# Each function returns a plain list with $type — the tree walker
# dispatches on this to produce Svelte markup.

#' Container for page children (analogous to main() for sidebar mode).
#'
#' @param ... Child items: output ids (strings like "contacts/table"),
#'   layout nodes (page_header, section, columns), or html_block() nodes.
#' @param gap Character. CSS gap value for content spacing.
#' @param class Character. Additional CSS class(es).
#' @param style Named list. Inline CSS properties.
#' @return A layout node (named list with `type = "page_content"`).
#' @export
page_content <- function(..., gap = NULL, class = NULL, style = NULL) {
  .drop_nulls(list(type = "page_content", children = list(...),
                   gap = gap, class = class, style = style))
}

#' Styled page header with optional subtitle and action buttons.
#'
#' @param title Character. Main heading text.
#' @param subtitle Character. Optional subtitle below the heading.
#' @param actions List. Action nodes to render right-aligned (e.g., create_button()).
#' @param help Character. Raw HTML for a help button rendered inline with the
#'   title. On mobile, stays next to the heading while actions wrap to a
#'   second row.
#' @param class Character. Additional CSS class(es).
#' @param style Named list. Inline CSS properties.
#' @return A layout node (named list with `type = "page_header"`).
#' @export
#' @examples
#' page_header(
#'   title = "Contacts",
#'   subtitle = "Manage your CRM",
#'   actions = list(create_button("New contact", modal = "contacts/create"))
#' )
page_header <- function(title, subtitle = NULL, actions = list(),
                        help = NULL, class = NULL, style = NULL) {
  .drop_nulls(list(type = "page_header", title = title, subtitle = subtitle,
                   actions = actions, help = help, class = class, style = style))
}

#' Stat cards grid.
#'
#' Two forms:
#'   \code{stat_cards("module/output")} — reference a module output (page context)
#'   \code{stat_cards(endpoint = "/api/...", cards = list(...))} — inline config (modal context)
#'
#' @param output_id Character. Fully qualified output id ("module/output") for
#'   the legacy reference form. Mutually exclusive with \code{endpoint}/\code{cards}.
#' @param endpoint Character. API URL path for fetching stats data (inline form).
#' @param cards List. Card definitions: \code{list(list(key, label, color, icon), ...)}.
#' @param class Character. Additional CSS class(es).
#' @param style Named list. Inline CSS properties.
#' @return A layout node (named list with `type = "stat_cards"`).
#' @export
#' @examples
#' # Inline form (modal context)
#' stat_cards(
#'   endpoint = "/api/overview/stats",
#'   cards = list(
#'     list(key = "total", label = "Contacts", color = "primary"),
#'     list(key = "active", label = "Active", color = "success")
#'   )
#' )
#' # Reference form (page context)
#' stat_cards("contacts/stats")
stat_cards <- function(output_id = NULL, endpoint = NULL, cards = NULL,
                       class = NULL, style = NULL) {
  if (!is.null(output_id)) {
    .drop_nulls(list(type = "stat_cards", output_id = output_id,
                     class = class, style = style))
  } else {
    .drop_nulls(list(type = "stat_cards", endpoint = endpoint, cards = cards,
                     class = class, style = style))
  }
}

#' Interactive data table.
#'
#' Modal-context constructor with inline endpoint + columns. Pages continue to
#' reference tables via bare module-output strings (e.g., "contacts/table").
#'
#' @param endpoint Character. API URL path returning JSON rows.
#' @param columns List. Column definitions: \code{list(list(key, label, sortable), ...)}.
#'   If NULL, columns are auto-detected from the first row.
#' @param page_size Integer. Rows per page; 0 disables pagination.
#' @param searchable Logical. Show a global search input.
#' @param selectable Logical. Enable row click selection.
#' @param refresh_event Character. Event name that triggers a refetch.
#' @param class Character. Additional CSS class(es).
#' @param style Named list. Inline CSS properties.
#' @return A layout node (named list with `type = "data_table"`).
#' @export
#' @examples
#' data_table(
#'   endpoint = "/api/contacts",
#'   columns = list(
#'     list(key = "name",  label = "Name",  sortable = TRUE),
#'     list(key = "party", label = "Party", sortable = TRUE)
#'   ),
#'   page_size = 25L,
#'   searchable = TRUE
#' )
data_table <- function(endpoint, columns = NULL, page_size = 0L,
                       searchable = FALSE, selectable = FALSE,
                       refresh_event = NULL, class = NULL, style = NULL) {
  .drop_nulls(list(
    type = "data_table", endpoint = endpoint, columns = columns,
    page_size = as.integer(page_size), searchable = isTRUE(searchable),
    selectable = isTRUE(selectable), refresh_event = refresh_event,
    class = class, style = style
  ))
}

#' Escape hatch for raw HTML/JS in a page layout tree.
#'
#' @param html Character. Raw HTML string.
#' @param script Character. Optional raw JS (added to page script block).
#' @param class Character. Additional CSS class(es). Wraps HTML in a div.
#' @param style Named list. Inline CSS properties. Wraps HTML in a div.
#' @return A layout node (named list with `type = "html_block"`).
#' @export
#' @examples
#' html_block("<p>Plain HTML escape hatch.</p>")
html_block <- function(html, script = NULL, class = NULL, style = NULL) {
  .drop_nulls(list(type = "html_block", html = html, script = script,
                   class = class, style = style))
}

#' Action button for page_header actions (e.g. "Ny interaktion").
#'
#' Renders a styled button that opens a modal or navigates to a page.
#' Avoids html_block for a common pattern.
#'
#' @param label Character. Button label.
#' @param modal Character. Modal id to open on click.
#' @param navigate Character. Page id to navigate to on click.
#' @param variant Character. "primary" (filled) or "outline" (default).
#' @param icon Character. Bootstrap Icon name (e.g., "plus", "download").
#' @param modal_size Character. Size of the opened modal: "sm", "md", "lg", "xl", "full".
#' @param href Character. URL for download/external link variant.
#' @param download Logical. If TRUE, the `<a>` element gets the `download` attribute.
#' @param class Character. Additional CSS class(es).
#' @param style Named list. Inline CSS properties.
#' @return A layout node (named list with `type = "create_button"`).
#' @export
#' @examples
#' create_button("New contact", modal = "contacts/create", icon = "plus")
#' create_button("Export PDF", href = "/api/export.pdf",
#'               download = TRUE, variant = "outline", icon = "download")
create_button <- function(label, modal = NULL, modal_size = NULL,
                          navigate = NULL, variant = "primary", icon = NULL,
                          href = NULL, download = FALSE,
                          class = NULL, style = NULL) {
  .drop_nulls(list(
    type = "create_button", label = label, variant = variant,
    modal = modal, modal_size = modal_size, navigate = navigate,
    icon = icon, href = href,
    download = if (isTRUE(download)) TRUE else NULL,
    class = class, style = style
  ))
}

#' Logout button for use in page_header actions.
#'
#' @param label Character. Button label. Default "Logga ut".
#' @param class Character. Additional CSS class(es).
#' @param style Named list. Inline CSS properties.
#' @return A layout node (named list with `type = "logout_button"`).
#' @export
logout_button <- function(label = "Logga ut", class = NULL, style = NULL) {
  .drop_nulls(list(type = "logout_button", label = label,
                   class = class, style = style))
}

#' Define a single view within a view_switcher.
#'
#' @param id Character. Unique view identifier.
#' @param label Character. Button label text.
#' @param ... Child items: output ids (strings) or layout nodes.
#' @param icon Character. Bootstrap Icon name (e.g., "grid-3x2-gap").
#'   Must be passed by name to avoid collision with positional children.
#' @return A view definition (named list) for use inside [view_switcher()].
#' @export
view <- function(id, label, ..., icon = NULL) {
  .drop_nulls(list(id = id, label = label, icon = icon, children = list(...)))
}

#' Toggle between multiple views of the same data.
#'
#' Renders a button bar and conditionally mounts the active view's content.
#' Replaces manual html_block view switching with a single DSL call.
#'
#' @param ... view() nodes defining each view and its content.
#' @param default Character. Id of the initially active view. Defaults to first.
#' @param actions html_block() node for right-side actions (e.g., export links).
#' @param class Character. Additional CSS class(es).
#' @param style Named list. Inline CSS properties.
#' @return A layout node (named list with `type = "view_switcher"`).
#' @export
#' @examples
#' view_switcher(
#'   view("table", "Table", "contacts/table", icon = "table"),
#'   view("cards", "Cards", "contacts/cards", icon = "grid-3x2-gap"),
#'   default = "table"
#' )
view_switcher <- function(..., default = NULL, actions = NULL,
                          class = NULL, style = NULL) {
  .drop_nulls(list(
    type = "view_switcher",
    views = list(...),
    default = default,
    actions = actions,
    class = class,
    style = style
  ))
}
