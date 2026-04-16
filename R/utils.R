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
    stop(sprintf("Unknown output type: %s", type))
  )
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
  args <- input_def$args
  type <- input_def$type

  # Check for explicit value/selected
  if (!is.null(args$value)) return(args$value)
  if (!is.null(args$selected)) return(args$selected)

  # Type-specific defaults
  switch(type,
    select = if (!is.null(args$choices)) args$choices[1] else "",
    text = if (!is.null(args$placeholder)) "" else "",
    textarea = "",
    numeric = if (!is.null(args$min)) args$min else 0,
    numeric_with_unit = if (!is.null(args$min)) args$min else 0,
    slider = if (!is.null(args$min)) args$min else 0,
    checkbox = if (!is.null(args$checked)) args$checked else FALSE,
    checkbox_group = character(0),
    radio = if (!is.null(args$choices)) args$choices[1] else "",
    date = format(Sys.Date(), "%Y-%m-%d"),
    date_range = format(Sys.Date(), "%Y-%m-%d"),
    action = NULL,
    server_search = "",
    multi_select = character(0),
    range_slider = if (!is.null(args$value)) args$value
                   else if (!is.null(args$min) && !is.null(args$max)) c(args$min, args$max)
                   else c(0, 100),
    dynamic_filters = "{}",
    ""
  )
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
