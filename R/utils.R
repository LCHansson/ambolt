# --- ambolt utilities ------------------------------------------
#
# Shared helpers: framework discovery, type mappings, defaults.

# Null-coalescing operator (not available in base R before 4.4)
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Convert a named list of CSS properties to an inline style string.
#' Also accepts a plain string (returned as-is for convenience).
#' @noRd
.style_to_string <- function(style) {
  if (is.null(style) || length(style) == 0) return(NULL)
  if (is.character(style) && length(style) == 1) return(style)
  paste(sprintf("%s:%s", names(style), style), collapse = ";")
}

#' Map input type to Svelte component name
#' @noRd
.input_component_name <- function(type) {
  switch(type,
    select = "SelectInput",
    text = "TextInput",
    textarea = "TextAreaInput",
    numeric = "NumericInput",
    numeric_with_unit = "NumericInputWithUnit",
    slider = "SliderInput",
    checkbox = "CheckboxInput",
    checkbox_group = "CheckboxGroupInput",
    radio = "RadioButtons",
    viz_type_selector = "VizTypeSelector",
    search_results_panel = "SearchResultsPanel",
    multi_view_panel = "MultiViewPanel",
    date = "DateInput",
    date_range = "DateRangeInput",
    action = "ActionButton",
    server_search = "ServerSearchInput",
    multi_select = "MultiSelect",
    range_slider = "RangeSlider",
    dynamic_filters = "DynamicFilters",
    stop(sprintf("Unknown input type: %s", type))
  )
}

#' Map output type to Svelte component name
#' @noRd
.output_component_name <- function(type) {
  switch(type,
    plot = "PlotOutput",
    chart = "ChartOutput",
    table = "DataTable",
    html = "HtmlOutput",
    # fetch_section reuses HtmlOutput on the frontend -- the difference is
    # purely server-side (declarative tree → static HTML in build.R).
    fetch_section = "HtmlOutput",
    stop(sprintf("Unknown output type: %s", type))
  )
}

#' Render a layout-DSL tree to a static HTML string (server-side).
#'
#' Used by `type = "fetch_section"` outputs to flatten a declarative tree
#' returned by the render handler into bytes the browser can consume
#' directly -- no Svelte runtime, no codegen, no JSON envelope. Recognises
#' the static layout nodes: page_content, section, columns, page_header,
#' html_block, badge, action_bar, detail_grid, detail_row, details.
#' Other node types are emitted as an HTML comment so a developer sees the
#' gap without the page silently breaking.
#' @noRd
.render_static_html <- function(node) {
  if (is.null(node)) return("")
  if (is.character(node) && length(node) == 1) return(node)
  if (!is.list(node)) return("")
  type <- node[["type"]]
  if (is.null(type)) {
    # Bare list of children
    parts <- vapply(node, .render_static_html, character(1))
    return(paste(parts, collapse = "\n"))
  }
  switch(type,
    page_content = {
      children <- node[["children"]] %||% list()
      cls <- node[["class"]] %||% ""
      style_attr <- .render_style_attr_static(node[["style"]])
      inner <- paste(vapply(children, .render_static_html, character(1)),
                     collapse = "\n")
      sprintf('<div class="ambolt-page-content %s"%s>%s</div>', cls, style_attr, inner)
    },
    section = {
      children <- node[["children"]] %||% list()
      label <- node[["title"]] %||% node[["label"]]
      cls <- node[["class"]] %||% ""
      style_attr <- .render_style_attr_static(node[["style"]])
      header <- if (!is.null(label)) sprintf('<h3 class="ambolt-section-title">%s</h3>', label) else ""
      inner <- paste(vapply(children, .render_static_html, character(1)),
                     collapse = "\n")
      sprintf('<section class="ambolt-section %s"%s>%s%s</section>', cls, style_attr, header, inner)
    },
    columns = {
      children <- node[["children"]] %||% list()
      cls <- node[["class"]] %||% ""
      gap <- node[["gap"]]
      style <- if (!is.null(gap)) sprintf("display:grid;grid-template-columns:repeat(%d,1fr);gap:%s;",
                                          length(children), gap) else
                sprintf("display:grid;grid-template-columns:repeat(%d,1fr);", length(children))
      inner <- paste(vapply(children, .render_static_html, character(1)),
                     collapse = "\n")
      sprintf('<div class="ambolt-columns %s" style="%s">%s</div>', cls, style, inner)
    },
    page_header = {
      title <- node[["title"]] %||% ""
      subtitle <- node[["subtitle"]]
      actions <- node[["actions"]]
      sub_html <- if (!is.null(subtitle)) sprintf('<p class="ambolt-page-subtitle">%s</p>', subtitle) else ""
      actions_html <- if (!is.null(actions)) .render_static_html(actions) else ""
      sprintf('<header class="ambolt-page-header"><h2 class="ambolt-page-title">%s</h2>%s%s</header>',
        title, sub_html, actions_html)
    },
    html_block = {
      # Note: script= is intentionally NOT executed in static fetch_section
      # context -- the section is meant to be data-declarative. If you need
      # JS, use html_block on a top-level page.
      html <- node[["html"]] %||% ""
      cls <- node[["class"]]
      style <- node[["style"]]
      if (!is.null(cls) || !is.null(style)) {
        style_attr <- .render_style_attr_static(style)
        sprintf('<div class="%s"%s>%s</div>', cls %||% "", style_attr, html)
      } else {
        html
      }
    },
    badge = {
      label <- node[["label"]] %||% ""
      variant <- node[["variant"]] %||% "default"
      sprintf('<span class="ambolt-badge ambolt-badge-%s">%s</span>', variant, label)
    },
    action_bar = {
      children <- node[["children"]] %||% list()
      inner <- paste(vapply(children, .render_static_html, character(1)),
                     collapse = "\n")
      sprintf('<div class="ambolt-action-bar">%s</div>', inner)
    },
    detail_grid = {
      children <- node[["children"]] %||% list()
      inner <- paste(vapply(children, .render_static_html, character(1)),
                     collapse = "\n")
      sprintf('<dl class="ambolt-detail-grid">%s</dl>', inner)
    },
    detail_row = {
      label <- node[["label"]] %||% ""
      value <- node[["value"]] %||% ""
      sprintf('<dt class="ambolt-detail-label">%s</dt><dd class="ambolt-detail-value">%s</dd>', label, value)
    },
    details = {
      label <- node[["label"]] %||% ""
      open <- isTRUE(node[["open"]])
      children <- node[["children"]] %||% list()
      inner <- paste(vapply(children, .render_static_html, character(1)),
                     collapse = "\n")
      sprintf('<details%s><summary>%s</summary>%s</details>',
        if (open) " open" else "", label, inner)
    },
    # Fallback: leave a visible comment so the dev notices unsupported types
    sprintf("<!-- ambolt fetch_section: unsupported node type \"%s\" -->", type)
  )
}

#' Style helper shared by static-HTML render path.
#' Accepts NULL, named list (CSS map), or character scalar.
#' @noRd
.render_style_attr_static <- function(style) {
  if (is.null(style)) return("")
  s <- .style_to_string(style)
  if (is.null(s) || nchar(s) == 0) return("")
  sprintf(' style="%s"', s)
}

#' Map module output type to Svelte component name
#' @noRd
.module_output_component_name <- function(type) {
  switch(type,
    plot = "PlotOutput",
    chart = "ChartOutput",
    table = "DataTable",
    html = "HtmlOutput",
    stats = "StatCards",
    cards = "CardGrid",
    stop(sprintf("Unknown module output type: %s", type))
  )
}

#' Get default value for an input
#' @noRd
.get_default_value <- function(input_def) {
  args <- input_def[["args"]]
  type <- input_def[["type"]]

  # Check for explicit value/selected
  if (!is.null(args[["value"]])) return(args[["value"]])
  if (!is.null(args[["selected"]])) return(args[["selected"]])

  # Type-specific defaults
  switch(type,
    select = if (!is.null(args[["choices"]])) args[["choices"]][1] else "",
    text = if (!is.null(args[["placeholder"]])) "" else "",
    textarea = "",
    numeric = if (!is.null(args[["min"]])) args[["min"]] else 0,
    numeric_with_unit = if (!is.null(args[["min"]])) args[["min"]] else 0,
    slider = if (!is.null(args[["min"]])) args[["min"]] else 0,
    checkbox = if (!is.null(args[["checked"]])) args[["checked"]] else FALSE,
    checkbox_group = character(0),
    radio = if (!is.null(args[["choices"]])) args[["choices"]][1] else "",
    date = format(Sys.Date(), "%Y-%m-%d"),
    date_range = format(Sys.Date(), "%Y-%m-%d"),
    action = NULL,
    server_search = "",
    multi_select = character(0),
    range_slider = if (!is.null(args[["value"]])) args[["value"]]
                   else if (!is.null(args[["min"]]) && !is.null(args[["max"]])) c(args[["min"]], args[["max"]])
                   else c(0, 100),
    dynamic_filters = "{}",
    ""
  )
}

#' Recursively merge two nested lists, with `new` overriding `old`.
#'
#' Used by `app$theme(tokens = ...)` to accumulate token assignments across
#' multiple calls. `app$theme(tokens = list(color = list(primary = "red")))`
#' followed by `app$theme(tokens = list(color = list(text = "black")))` ends
#' up with both `primary` and `text` set -- neither call zeros the other
#' category. Only nodes that are themselves lists are merged recursively;
#' scalars, vectors, and NULLs replace wholesale.
#' @noRd
.deep_merge_lists <- function(old, new) {
  if (is.null(old)) return(new)
  if (is.null(new)) return(old)
  if (!is.list(old) || !is.list(new)) return(new)
  for (key in names(new)) {
    if (is.list(new[[key]]) && is.list(old[[key]])) {
      old[[key]] <- .deep_merge_lists(old[[key]], new[[key]])
    } else {
      old[[key]] <- new[[key]]
    }
  }
  old
}

#' Detect when a literal route is shadowed by an earlier `:param` route.
#'
#' ambiorix dispatches routes in registration order. A route registered as
#' `/items/:id` consumes any subsequent registration of `/items/compare` --
#' the request matches the `:param` route first and returns 404 (or the
#' wrong handler). This helper scans the per-app registry and returns the
#' first shadowing route, or NULL if none.
#'
#' Algorithm: split both paths by `/`. If the new path has no `:param`
#' segment and an earlier same-method route has the same number of
#' segments where every existing segment is either an exact match or a
#' `:param`, that earlier route shadows this one.
#' @noRd
.check_route_shadowing <- function(routes, method, new_path) {
  if (length(routes) == 0) return(NULL)
  # Only literal routes can be shadowed by earlier :param routes
  if (grepl(":", new_path, fixed = TRUE)) return(NULL)
  new_segs <- strsplit(new_path, "/", fixed = TRUE)[[1]]
  for (r in routes) {
    if (r[["method"]] != method) next
    if (!grepl(":", r[["path"]], fixed = TRUE)) next  # literal-vs-literal can't shadow
    earlier_segs <- strsplit(r[["path"]], "/", fixed = TRUE)[[1]]
    if (length(earlier_segs) != length(new_segs)) next
    matches <- vapply(seq_along(earlier_segs), function(i) {
      es <- earlier_segs[[i]]
      ns <- new_segs[[i]]
      startsWith(es, ":") || identical(es, ns)
    }, logical(1))
    if (all(matches)) return(sprintf("%s %s", r[["method"]], r[["path"]]))
  }
  NULL
}

#' Find the framework Svelte components directory
#'
#' Search order:
#'   1. AMBOLT_COMPONENTS_DIR environment variable
#'   2. Installed package: system.file("svelte/components", package = "ambolt")
#'   3. Development: inst/svelte/components/ relative to source file or working dir
#' @noRd
.find_framework_dir <- function() {
  framework_dir <- NULL

  # 1. Environment variable override (highest priority)
  if (Sys.getenv("AMBOLT_COMPONENTS_DIR") != "") {
    framework_dir <- normalizePath(Sys.getenv("AMBOLT_COMPONENTS_DIR"), mustWork = FALSE)
  }

  # 2. Installed package location
  if (is.null(framework_dir) || !dir.exists(framework_dir)) {
    pkg_dir <- tryCatch(
      system.file("svelte/components", package = "ambolt", mustWork = TRUE),
      error = function(e) "")
    if (nchar(pkg_dir) > 0 && dir.exists(pkg_dir)) framework_dir <- pkg_dir
  }

  # 3. Development: inst/svelte/components/ relative to R/ source dir
  if (is.null(framework_dir) || !dir.exists(framework_dir)) {
    if (!is.null(.ambolt_source_dir)) {
      candidate <- normalizePath(
        file.path(.ambolt_source_dir, "..", "inst", "svelte", "components"),
        mustWork = FALSE)
      if (dir.exists(candidate)) framework_dir <- candidate
    }
  }

  # 4. Relative to working directory (dev mode)
  if (is.null(framework_dir) || !dir.exists(framework_dir)) {
    candidate <- normalizePath("inst/svelte/components", mustWork = FALSE)
    if (dir.exists(candidate)) framework_dir <- candidate
  }

  if (is.null(framework_dir) || !dir.exists(framework_dir)) {
    stop("Cannot find ambolt Svelte components. ",
         "Set AMBOLT_COMPONENTS_DIR environment variable, or ",
         "run from the project root directory.")
  }

  framework_dir
}

# Record where this file lives so we can find the Svelte components relative to it.
# This runs at source() time using a local helper to capture the script path.
local({
  get_script_dir <- function() {
    # Try multiple methods to find the source file location
    # Method 1: Walk the call stack looking for source()'s ofile
    for (i in seq_len(sys.nframe())) {
      env <- sys.frame(i)
      if (!is.null(env$ofile)) {
        return(normalizePath(dirname(env$ofile), mustWork = FALSE))
      }
    }
    # Method 2: Rscript --file argument
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", args, value = TRUE)
    if (length(file_arg) > 0) {
      script <- sub("^--file=", "", file_arg[1])
      return(normalizePath(dirname(script), mustWork = FALSE))
    }
    NULL
  }
  .ambolt_source_dir <<- get_script_dir()
})
