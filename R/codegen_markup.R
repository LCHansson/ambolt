# --- ambolt Svelte markup generation --------------------------
#
# Generates Svelte markup for inputs and outputs: component tags,
# props, bindings, show_when conditionals, help tooltips.
# Depends on: utils.R (.input_component_name, .output_component_name)

#' Convert a show_when list to a Svelte conditional expression
#'
#' list(vehicle_class = "truck")         -> "vehicle_class === 'truck'"
#' list(vehicle_class = c("van","taxi")) -> "vehicle_class === 'van' || vehicle_class === 'taxi'"
#' list(a = "x", b = "y")               -> "(a === 'x') && (b === 'y')"
#' @noRd
.show_when_condition <- function(show_when) {
  parts <- mapply(function(input_id, values) {
    if (is.logical(values) && length(values) == 1) {
      # Boolean: checkbox true/false
      if (values) input_id else sprintf("!%s", input_id)
    } else if (length(values) == 1) {
      sprintf("%s === '%s'", input_id, values)
    } else {
      # Multiple values: OR them together
      or_parts <- sprintf("%s === '%s'", input_id, values)
      sprintf("(%s)", paste(or_parts, collapse = " || "))
    }
  }, names(show_when), show_when, SIMPLIFY = TRUE, USE.NAMES = FALSE)

  if (length(parts) == 1) {
    parts
  } else {
    # Multiple conditions: AND them together
    paste(sprintf("(%s)", parts), collapse = " && ")
  }
}

#' Generate Svelte markup for a single input
#' @noRd
.generate_input_markup <- function(input_def) {
  id <- input_def$id
  type <- input_def$type
  args <- input_def$args
  component <- .input_component_name(type)

  # Build props string
  props <- sprintf('id="%s"', id)
  if (!is.null(args$label)) props <- c(props, sprintf('label="%s"', args$label))

  # Handle choices (arrays)
  if (!is.null(args$choices)) {
    if (is.null(names(args$choices))) {
      # Simple string vector
      choices_js <- sprintf("[%s]", paste(sprintf("'%s'", args$choices), collapse = ", "))
    } else {
      # Named vector -> {value, label} objects
      items <- mapply(function(val, lab) {
        sprintf("{ value: '%s', label: '%s' }", val, lab)
      }, args$choices, names(args$choices), SIMPLIFY = TRUE)
      choices_js <- sprintf("[%s]", paste(items, collapse = ", "))
    }
    props <- c(props, sprintf("choices={%s}", choices_js))
  }

  # Numeric props
  for (prop_name in c("min", "max", "step", "rows")) {
    if (!is.null(args[[prop_name]])) {
      props <- c(props, sprintf("%s={%s}", prop_name, args[[prop_name]]))
    }
  }

  # String props
  if (!is.null(args$placeholder)) {
    props <- c(props, sprintf('placeholder="%s"', args$placeholder))
  }

  # Unit prop (for numeric_with_unit and slider)
  if (!is.null(args$unit)) {
    props <- c(props, sprintf('unit="%s"', args$unit))
  }

  # Color prop (for slider accent color)
  if (!is.null(args$color)) {
    props <- c(props, sprintf('color="%s"', args$color))
  }

  # Variant prop (for action buttons and radio)
  if (!is.null(args$variant)) {
    props <- c(props, sprintf('variant="%s"', args$variant))
  }

  # Icons prop (for radio button-bar with SVG icons)
  if (!is.null(args$icons)) {
    icon_entries <- mapply(function(val, svg) {
      # Escape backticks in SVG content for JS template safety
      safe_svg <- gsub("`", "\\\\`", svg)
      sprintf("'%s': `%s`", val, safe_svg)
    }, names(args$icons), args$icons, SIMPLIFY = TRUE, USE.NAMES = FALSE)
    icons_js <- paste0("{ ", paste(icon_entries, collapse = ", "), " }")
    props <- c(props, paste0("icons={", icons_js, "}"))
  }

  # Server search props (endpoint, baseUrl, debounce)
  if (type == "server_search") {
    if (!is.null(args$endpoint)) {
      props <- c(props, sprintf('endpoint="%s"', args$endpoint))
    }
    if (!is.null(args$base_url)) {
      props <- c(props, sprintf('baseUrl="%s"', args$base_url))
    }
    if (!is.null(args$debounce)) {
      props <- c(props, sprintf("debounce={%s}", args$debounce))
    }
  }

  # Binding — depends on input type
  if (type == "action") {
    # Action buttons: onclick increments counter, no value binding
    props <- c(props, sprintf("onclick={() => %s++}", id))
    # Add disabled prop if requires is specified
    if (!is.null(args$requires)) {
      props <- c(props, sprintf("disabled={!%s_valid}", id))
    }
  } else {
    binding <- switch(type,
      checkbox = sprintf("bind:checked={%s}", id),
      checkbox_group = sprintf("bind:selected={%s}", id),
      date_range = sprintf('bind:start={%s_start} bind:end={%s_end}', id, id),
      sprintf("bind:value={%s}", id)
    )
    props <- c(props, binding)
  }

  # Pass help text as a prop for components that support inline help icons
  help_text <- input_def$args$help
  types_with_help_prop <- c("numeric", "numeric_with_unit", "select")
  if (!is.null(help_text) && type %in% types_with_help_prop) {
    safe_help <- gsub('"', '&quot;', help_text)
    props <- c(props, sprintf('help="%s"', safe_help))
    help_text <- NULL  # Don't also wrap in input-with-help
  }

  tag <- sprintf("    <%s %s />", component, paste(props, collapse = "\n      "))

  # Fallback: wrap with external help tooltip for types that don't support help prop
  if (!is.null(help_text)) {
    safe_help <- gsub('"', '&quot;', help_text)
    tag <- sprintf(
      '    <div class="input-with-help">\n  %s\n      <span class="help-tooltip"><span class="help-icon">?</span><span class="help-text">%s</span></span>\n    </div>',
      tag, safe_help)
  }

  # Wrap in {#if} block if show_when is specified
  show_when <- input_def$args$show_when
  if (!is.null(show_when)) {
    tag <- sprintf("    {#if %s}\n  %s\n    {/if}", .show_when_condition(show_when), tag)
  }

  tag
}

#' Generate Svelte markup for a single output
#' @noRd
.generate_output_markup <- function(output_def, port) {
  id <- output_def$id
  type <- output_def$type
  depends_on <- output_def$depends_on
  trigger <- output_def$trigger
  component <- .output_component_name(type)

  endpoint <- sprintf("/api/output/%s", id)

  # Build params object from depends_on
  params_obj <- paste(depends_on, collapse = ", ")

  # Add trigger prop if specified
  trigger_prop <- ""
  if (!is.null(trigger)) {
    trigger_prop <- sprintf(" trigger={%s}", trigger)
  }

  sprintf('    <%s id="%s" endpoint="%s" params={{ %s }}%s />',
    component, id, endpoint, params_obj, trigger_prop)
}

#' Generate the content area (empty state + outputs with conditional display)
#' @noRd
.generate_content_html <- function(outputs, port, empty_state, scenarios = list()) {
  output_markup <- vapply(outputs, function(o) .generate_output_markup(o, port), character(1))
  has_triggers <- any(vapply(outputs, function(o) !is.null(o$trigger), logical(1)))

  # Generate scenario buttons HTML
  scenario_html <- ""
  if (length(scenarios) > 0) {
    buttons <- vapply(seq_along(scenarios), function(i) {
      sprintf('        <button class="scenario-button" onclick={loadScenario%d}>%s</button>',
        i, scenarios[[i]]$label)
    }, character(1))
    scenario_html <- sprintf(
      '\n      <div class="scenario-buttons">\n%s\n      </div>',
      paste(buttons, collapse = "\n"))
  }

  if (has_triggers && !is.null(empty_state)) {
    empty_html <- sprintf(
      '    {#if !showResults}\n    <div class="empty-state">\n      <h2>%s</h2>%s%s\n    </div>\n    {/if}',
      empty_state$title,
      if (!is.null(empty_state$subtitle)) sprintf("\n      <p>%s</p>", empty_state$subtitle) else "",
      scenario_html
    )
    sprintf('%s\n    {#if showResults}\n%s\n    {/if}',
      empty_html, paste(output_markup, collapse = "\n"))
  } else if (has_triggers) {
    sprintf('    {#if showResults}\n%s\n    {/if}',
      paste(output_markup, collapse = "\n"))
  } else {
    paste(output_markup, collapse = "\n")
  }
}

#' Generate Svelte markup for a section (grouped inputs with visibility)
#' @noRd
.generate_section_markup <- function(section_def, inputs) {
  # Generate markup for each input in the section
  section_inputs <- inputs[section_def$inputs]
  input_tags <- vapply(section_inputs, .generate_input_markup, character(1))
  inner <- paste(input_tags, collapse = "\n")

  # Add section heading if label is set
  if (!is.null(section_def$label)) {
    inner <- sprintf('    <h4 class="section-label">%s</h4>\n%s', section_def$label, inner)
  }

  # Wrap in a div with section class
  block <- sprintf('    <div class="section" data-section-id="%s">\n%s\n    </div>', section_def$id, inner)

  # Wrap in {#if} for show_after (trigger-gated)
  if (!is.null(section_def$show_after)) {
    block <- sprintf("    {#if %s > 0}\n%s\n    {/if}", section_def$show_after, block)
  }

  # Wrap in {#if} for show_when (input-gated)
  if (!is.null(section_def$show_when)) {
    block <- sprintf("    {#if %s}\n%s\n    {/if}", .show_when_condition(section_def$show_when), block)
  }

  block
}

# --- Module output markup generation ------------------------------

#' Generate Svelte markup for a module output declaration.
#'
#' Dispatches by type: "table" → DataTable, "stats" → StatCards,
#' "html" → HtmlOutput, "plot" → PlotOutput.
#' @noRd
.generate_module_output_markup <- function(mod_output) {
  type <- mod_output$type
  switch(type,
    table = .generate_module_table_markup(mod_output),
    stats = .generate_module_stats_markup(mod_output),
    cards = .generate_module_cards_markup(mod_output),
    html  = .generate_module_html_markup(mod_output),
    plot  = .generate_module_plot_markup(mod_output),
    stop(sprintf("Unknown module output type: '%s'", type))
  )
}

#' Generate DataTable markup from module output declaration.
#' @noRd
.generate_module_table_markup <- function(mod_output) {
  id <- mod_output$id
  endpoint <- mod_output$endpoint
  columns <- mod_output$columns
  page_size <- mod_output$page_size %||% 0
  searchable <- isTRUE(mod_output$searchable)
  selectable <- isTRUE(mod_output$selectable)
  on_select <- mod_output$on_select
  filters <- mod_output$filters

  safe_id <- gsub("[/]", "_", id)

  # Build component props
  props <- c(
    sprintf('endpoint="%s"', endpoint),
    sprintf("columns={%s}", paste0(safe_id, "_columns"))
  )

  # If filters are defined, pass the reactive params object
  if (!is.null(filters) && length(filters) > 0) {
    props <- c(props, sprintf("params={%s}", paste0(safe_id, "_params")))
  }

  if (page_size > 0) props <- c(props, sprintf("pageSize={%s}", page_size))
  if (searchable) props <- c(props, "searchable")
  if (selectable) props <- c(props, "selectable")

  # Callback handler
  if (!is.null(on_select)) {
    props <- c(props, sprintf("onselect={%s}", paste0(safe_id, "_onselect")))
  }

  # Event-driven refresh (e.g., after form modal submit)
  if (!is.null(mod_output$refresh_on)) {
    props <- c(props, sprintf('refreshEvent="%s"', mod_output$refresh_on))
  }

  # User-supplied CSS class
  if (!is.null(mod_output$class)) {
    props <- c(props, sprintf('class="%s"', mod_output$class))
  }

  table_tag <- sprintf("<DataTable %s />", paste(props, collapse = "\n      "))

  # If filters are defined, wrap with a filter bar above the table
  if (!is.null(filters) && length(filters) > 0) {
    filter_chips <- vapply(filters, function(f) {
      filter_var <- paste0(safe_id, "_filter_", f$id)
      # Build dropdown items from choices
      if (!is.null(names(f$choices))) {
        items <- vapply(seq_along(f$choices), function(i) {
          val <- f$choices[[i]]
          lab <- names(f$choices)[[i]]
          sprintf('              <button class="filter-chip-item" class:active={%s === "%s"} onclick={() => { %s = "%s"; %s_open = false }}>%s</button>',
            filter_var, val, filter_var, val, filter_var, lab)
        }, character(1))
        first_label <- names(f$choices)[[1]]
      } else {
        items <- vapply(f$choices, function(c) {
          sprintf('              <button class="filter-chip-item" class:active={%s === "%s"} onclick={() => { %s = "%s"; %s_open = false }}>%s</button>',
            filter_var, c, filter_var, c, filter_var, c)
        }, character(1))
        first_label <- f$choices[[1]]
      }
      # Build label lookup for display
      if (!is.null(names(f$choices))) {
        lookup_entries <- vapply(seq_along(f$choices), function(i) {
          sprintf('"%s": "%s"', f$choices[[i]], names(f$choices)[[i]])
        }, character(1))
      } else {
        lookup_entries <- vapply(f$choices, function(c) {
          sprintf('"%s": "%s"', c, c)
        }, character(1))
      }
      lookup_obj <- sprintf("{%s}", paste(lookup_entries, collapse = ", "))
      display_expr <- sprintf('(%s[%s] || "%s")', lookup_obj, filter_var, first_label)

      sprintf('        <div class="filter-chip" class:open={%s_open}>
          <button class="filter-chip-button" onclick={() => %s_open = !%s_open}>
            <span class="filter-chip-label">%s \u25be</span>
            <span class="filter-chip-value">{%s}</span>
          </button>
          {#if %s_open}
            <div class="filter-chip-dropdown">
%s
            </div>
          {/if}
        </div>',
        filter_var, filter_var, filter_var,
        f$label, display_expr,
        filter_var,
        paste(items, collapse = "\n"))
    }, character(1))

    filter_bar <- sprintf('    <div class="ambolt-filter-bar">\n%s\n    </div>',
      paste(filter_chips, collapse = "\n"))
    return(sprintf("%s\n    %s", filter_bar, table_tag))
  }

  sprintf("    %s", table_tag)
}

#' Generate CardGrid markup from module output declaration.
#' @noRd
.generate_module_cards_markup <- function(mod_output) {
  id <- mod_output$id
  endpoint <- mod_output$endpoint
  safe_id <- gsub("[/]", "_", id)

  card_var <- paste0(safe_id, "_card")

  props <- c(
    sprintf('id="%s"', id),
    sprintf('endpoint="%s"', endpoint),
    sprintf("card={%s}", card_var)
  )

  # Rich fields
  card_def <- mod_output$card %||% list()
  if (!is.null(card_def$fields) && length(card_def$fields) > 0) {
    fields_var <- paste0(safe_id, "_fields")
    props <- c(props, sprintf("fields={%s}", fields_var))
  }

  # Filters
  if (!is.null(mod_output$filters) && length(mod_output$filters) > 0) {
    filters_var <- paste0(safe_id, "_filters")
    props <- c(props, sprintf("filters={%s}", filters_var))
  }

  # Searchable
  if (isTRUE(mod_output$searchable)) {
    props <- c(props, "searchable={true}")
  }

  # Page size
  if (!is.null(mod_output$page_size)) {
    props <- c(props, sprintf("pageSize={%d}", as.integer(mod_output$page_size)))
  }

  # Min card width
  if (!is.null(mod_output$min_width)) {
    props <- c(props, sprintf("minWidth={%d}", as.integer(mod_output$min_width)))
  }

  # Favorite
  if (!is.null(mod_output$favorite)) {
    fav_var <- paste0(safe_id, "_favorite")
    props <- c(props, sprintf("favorite={%s}", fav_var))
  }

  # Click handler
  if (!is.null(mod_output$on_click)) {
    handler_name <- paste0(safe_id, "_onclick")
    props <- c(props, sprintf("onclick={%s}", handler_name))
  }

  # Event-driven refresh
  if (!is.null(mod_output$refresh_on)) {
    props <- c(props, sprintf('refreshEvent="%s"', mod_output$refresh_on))
  }

  # Contact action (dispatches event on mailto/tel click)
  if (!is.null(mod_output$contact_action)) {
    ca_var <- paste0(safe_id, "_contact_action")
    props <- c(props, sprintf("contactAction={%s}", ca_var))
  }

  # Labels (i18n)
  if (!is.null(mod_output$labels)) {
    labels_var <- paste0(safe_id, "_labels")
    props <- c(props, sprintf("labels={%s}", labels_var))
  }

  # User-supplied CSS class
  if (!is.null(mod_output$class)) {
    props <- c(props, sprintf('class="%s"', mod_output$class))
  }

  sprintf("    <CardGrid %s />", paste(props, collapse = "\n      "))
}

#' Generate StatCards markup from module output declaration.
#' @noRd
.generate_module_stats_markup <- function(mod_output) {
  id <- mod_output$id
  endpoint <- mod_output$endpoint

  # Generate card definitions as JS variable name
  cards_var <- gsub("[/]", "_", id)
  cards_var <- paste0(cards_var, "_cards")

  class_prop <- if (!is.null(mod_output$class)) sprintf(' class="%s"', mod_output$class) else ""
  sprintf('    <StatCards endpoint="%s" cards={%s}%s />', endpoint, cards_var, class_prop)
}

#' Generate HtmlOutput markup from module output declaration.
#' @noRd
.generate_module_html_markup <- function(mod_output) {
  endpoint <- mod_output$endpoint %||% sprintf("/api/output/%s", mod_output$id)
  safe_id <- gsub("[/]", "_", mod_output$full_id %||% mod_output$id)
  extra <- sprintf(' id="%s"', safe_id)
  if (!is.null(mod_output$class)) extra <- paste0(extra, sprintf(' class="%s"', mod_output$class))
  if (!is.null(mod_output$refresh_on)) extra <- paste0(extra, sprintf(' refreshEvent="%s"', mod_output$refresh_on))
  sprintf('    <HtmlOutput endpoint="%s"%s />', endpoint, extra)
}

#' Generate PlotOutput markup from module output declaration.
#' @noRd
.generate_module_plot_markup <- function(mod_output) {
  endpoint <- mod_output$endpoint %||% sprintf("/api/output/%s", mod_output$id)
  class_prop <- if (!is.null(mod_output$class)) sprintf(' class="%s"', mod_output$class) else ""
  sprintf('    <PlotOutput endpoint="%s"%s />', endpoint, class_prop)
}

#' Generate all sidebar input markup, respecting section grouping
#'
#' Inputs that belong to a section are rendered inside that section's
#' container. Unsectioned inputs are rendered in declaration order.
#' Sections are placed after all unsectioned inputs.
#' @noRd
.generate_sidebar_inputs <- function(inputs, sections) {
  # Find which inputs belong to sections
  sectioned_ids <- unlist(lapply(sections, function(s) s$inputs))

  # Render unsectioned inputs in declaration order
  unsectioned <- inputs[!names(inputs) %in% sectioned_ids]
  unsectioned_markup <- vapply(unsectioned, .generate_input_markup, character(1))

  # Render sections
  section_markup <- vapply(sections, function(s) {
    .generate_section_markup(s, inputs)
  }, character(1))

  c(unsectioned_markup, section_markup)
}
