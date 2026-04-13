# --- ambolt HTML helper functions -----------------------------------
#
# R functions that generate HTML for use in server-rendered content
# (modal bodies, html_blocks). These replace hand-written sprintf
# patterns and ensure proper escaping and consistent styling.
#
# All helpers produce plain HTML strings. They work with the existing
# {@html} rendering in Modal.svelte and html_block nodes.

# --- Security: HTML escaping ----------------------------------------

#' Escape text for safe insertion into HTML
#'
#' Replaces &, <, >, ", ' with their HTML entity equivalents.
#' Use this whenever inserting user-supplied data into server-rendered HTML.
#'
#' @param text Character string to escape
#' @return Escaped string safe for HTML insertion
#' @export
#' @examples
#' html_escape("<script>alert('xss')</script>")
#' html_escape("Tom & Jerry")
html_escape <- function(text) {

  if (is.null(text) || is.na(text)) return("")
  text <- as.character(text)
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  text <- gsub(">", "&gt;", text, fixed = TRUE)
  text <- gsub('"', "&quot;", text, fixed = TRUE)
  text <- gsub("'", "&#39;", text, fixed = TRUE)
  text
}

# --- Action buttons -------------------------------------------------

#' Generate an action button for server-rendered HTML
#'
#' Creates a button that triggers a fetch request when clicked.
#' Uses data-ambolt-* attributes processed by the declarative action handler
#' in Modal.svelte. No inline JS — all behavior is driven by data attributes.
#'
#' @param label Button text (will be HTML-escaped)
#' @param endpoint API endpoint to call (must start with /api/)
#' @param method HTTP method: "POST", "PUT", or "DELETE"
#' @param body Named list to send as JSON body
#' @param toast Toast message to show on success
#' @param emit Event name to emit on success (e.g., "contacts:updated")
#' @param remove CSS selector of ancestor element to remove on success
#' @param modal_refresh Whether to refresh the current modal after success
#' @param open_modal Modal ID to open after success (e.g., "interactions/add_followup?id=5")
#' @param open_modal_size Size for the opened modal ("sm", "md", "lg")
#' @param style Named list of inline CSS properties
#' @param class Additional CSS class(es)
#' @param icon Bootstrap Icon name (e.g., "check", "bell")
#' @return HTML string
#' @export
action_button <- function(label, endpoint, method = "POST", body = list(),
                          toast = NULL, emit = NULL, remove = NULL,
                          modal_refresh = FALSE, open_modal = NULL,
                          open_modal_size = "sm", style = list(),
                          class = NULL, icon = NULL) {
  # Build data attributes
  attrs <- sprintf('data-ambolt-action="%s" data-ambolt-endpoint="%s"',
    tolower(method), html_escape(endpoint))

  if (length(body) > 0) {
    body_json <- jsonlite::toJSON(body, auto_unbox = TRUE)
    attrs <- paste0(attrs, sprintf(' data-ambolt-body=\'%s\'', body_json))
  }
  if (!is.null(toast))
    attrs <- paste0(attrs, sprintf(' data-ambolt-toast="%s"', html_escape(toast)))
  if (!is.null(emit))
    attrs <- paste0(attrs, sprintf(' data-ambolt-emit="%s"', html_escape(emit)))
  if (!is.null(remove))
    attrs <- paste0(attrs, sprintf(' data-ambolt-remove="%s"', html_escape(remove)))
  if (modal_refresh)
    attrs <- paste0(attrs, ' data-ambolt-modal-refresh="true"')
  if (!is.null(open_modal)) {
    attrs <- paste0(attrs, sprintf(' data-ambolt-open-modal="%s"', html_escape(open_modal)))
    attrs <- paste0(attrs, sprintf(' data-ambolt-open-modal-size="%s"', open_modal_size))
  }

  # Build style string
  default_style <- list(
    `font-size` = "0.8rem",
    padding = "0.2rem 0.5rem",
    border = "1px solid #d1d5db",
    `border-radius` = "4px",
    color = "#424542",
    background = "none",
    cursor = "pointer"
  )
  merged_style <- modifyList(default_style, style)
  style_str <- paste(sprintf("%s:%s", names(merged_style), merged_style), collapse = ";")

  # Build class string
  class_str <- paste(c("ambolt-action-btn", class), collapse = " ")

  # Icon prefix
  icon_html <- if (!is.null(icon)) sprintf('<i class="bi bi-%s"></i> ', icon) else ""

  sprintf('<button %s class="%s" style="%s">%s%s</button>',
    attrs, class_str, style_str, icon_html, html_escape(label))
}

# --- Modal links ----------------------------------------------------

#' Generate a link that opens a modal
#'
#' @param label Link text (will be HTML-escaped)
#' @param modal_id Modal identifier (e.g., "contacts/profile")
#' @param params Named list of query parameters
#' @param size Modal size: "sm", "md", "lg", "xl"
#' @param style Named list of inline CSS properties
#' @param class Additional CSS class(es)
#' @param icon Bootstrap Icon name
#' @return HTML string
#' @export
modal_link <- function(label, modal_id, params = list(), size = "md",
                       style = list(), class = NULL, icon = NULL) {
  # Build query string from params
  query <- if (length(params) > 0) {
    parts <- vapply(names(params), function(k) {
      sprintf("%s=%s", k, params[[k]])
    }, character(1))
    paste0("?", paste(parts, collapse = "&"))
  } else ""

  modal_attr <- paste0(modal_id, query)

  default_style <- list(
    `text-decoration` = "none",
    `font-size` = "0.85rem",
    color = "#006589"
  )
  merged_style <- modifyList(default_style, style)
  style_str <- paste(sprintf("%s:%s", names(merged_style), merged_style), collapse = ";")

  class_str <- if (!is.null(class)) sprintf(' class="%s"', class) else ""
  icon_html <- if (!is.null(icon)) sprintf('<i class="bi bi-%s"></i> ', icon) else ""

  sprintf('<a href="#" data-modal="%s" data-modal-size="%s"%s style="%s">%s%s</a>',
    html_escape(modal_attr), size, class_str, style_str, icon_html, html_escape(label))
}

# --- Badges ---------------------------------------------------------

#' Generate a styled badge
#'
#' @param text Badge text (will be HTML-escaped)
#' @param class CSS class(es) for color coding (e.g., "eng-identifierad")
#' @param data_value Optional data-value attribute for CSS targeting
#' @param style Named list of additional inline CSS
#' @return HTML string
#' @export
badge <- function(text, class = NULL, data_value = NULL, style = list()) {
  default_style <- list(
    display = "inline-block",
    padding = "0.1rem 0.4rem",
    `border-radius` = "4px",
    `font-size` = "0.8rem",
    `font-weight` = "500"
  )
  merged_style <- modifyList(default_style, style)
  style_str <- paste(sprintf("%s:%s", names(merged_style), merged_style), collapse = ";")

  class_str <- paste(c("ambolt-badge", class), collapse = " ")
  data_attr <- if (!is.null(data_value)) sprintf(' data-value="%s"', html_escape(data_value)) else ""

  sprintf('<span class="%s"%s style="%s">%s</span>',
    class_str, data_attr, style_str, html_escape(text))
}

# --- Layout helpers -------------------------------------------------

#' Generate a label-value detail row
#'
#' @param label Row label (bold)
#' @param value Row value (can contain HTML — not escaped)
#' @return HTML string
#' @export
detail_row <- function(label, value) {
  sprintf('<p><strong>%s:</strong> %s</p>', html_escape(label), value)
}

#' Generate a grid layout for detail sections
#'
#' @param ... detail_row() outputs or other HTML strings
#' @param cols Number of columns (default 2)
#' @return HTML string
#' @export
detail_grid <- function(..., cols = 2) {
  items <- list(...)
  # Split items into columns
  per_col <- ceiling(length(items) / cols)
  col_html <- character(0)
  for (i in seq_len(cols)) {
    start <- (i - 1) * per_col + 1
    end <- min(i * per_col, length(items))
    if (start <= length(items)) {
      col_html <- c(col_html, sprintf('<div>%s</div>',
        paste(items[start:end], collapse = "\n")))
    }
  }
  sprintf('<div style="display:grid;grid-template-columns:repeat(%d,1fr);gap:0.75rem;">%s</div>',
    cols, paste(col_html, collapse = "\n"))
}

#' Generate a horizontal action bar (flex row of buttons/links)
#'
#' @param ... action_button(), modal_link(), or other HTML strings
#' @param justify CSS justify-content value (default "flex-start")
#' @return HTML string
#' @export
action_bar <- function(..., justify = "flex-start") {
  items <- list(...)
  sprintf('<div style="display:flex;gap:0.4rem;flex-wrap:wrap;justify-content:%s;">%s</div>',
    justify, paste(items, collapse = "\n"))
}
