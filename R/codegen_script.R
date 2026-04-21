# --- ambolt Svelte <script> block generation ------------------
#
# Generates the Svelte <script> block: imports, state declarations,
# derived values, validation, and scenario loader functions.
# Depends on: utils.R (.input_component_name, .output_component_name, .get_default_value)

#' Generate validation derived declarations for action buttons with requires
#' @noRd
.generate_validation_deriveds <- function(inputs) {
  lines <- character(0)
  for (i in inputs) {
    if (i$type == "action" && !is.null(i$args$requires)) {
      required_ids <- i$args$requires
      checks <- sprintf("(%s !== '' && %s !== null && %s !== undefined && !Number.isNaN(%s))",
        required_ids, required_ids, required_ids, required_ids)
      cond <- paste(checks, collapse = " && ")
      lines <- c(lines, sprintf("  let %s_valid = $derived(%s);", i$id, cond))
    }
  }
  lines
}

#' Generate JS declarations for module outputs (column defs, card defs, callbacks)
#' @noRd
.generate_module_output_script <- function(module_outputs) {
  if (length(module_outputs) == 0) return(character(0))

  lines <- character(0)
  for (mod_out in module_outputs) {
    safe_id <- gsub("[/]", "_", mod_out$id)

    if (mod_out$type == "table") {
      # Column definitions
      col_var <- paste0(safe_id, "_columns")
      col_js <- vapply(mod_out$columns, function(col) {
        parts <- sprintf("key: '%s', label: '%s'", col$key, col$label)
        if (isTRUE(col$sortable)) parts <- paste0(parts, ", sortable: true")
        if (!is.null(col$render)) parts <- paste0(parts, sprintf(", render: '%s'", col$render))
        if (!is.null(col$edit_endpoint)) parts <- paste0(parts, sprintf(", edit_endpoint: '%s'", col$edit_endpoint))
        if (!is.null(col$edit_choices)) {
          choices_js <- vapply(col$edit_choices, function(ch) {
            sprintf("{ value: '%s', label: '%s' }", ch$value, ch$label)
          }, character(1))
          parts <- paste0(parts, sprintf(", edit_choices: [%s]", paste(choices_js, collapse = ", ")))
        }
        sprintf("{ %s }", parts)
      }, character(1))
      lines <- c(lines, sprintf("  let %s = [%s];", col_var, paste(col_js, collapse = ", ")))

      # Callback handler
      if (!is.null(mod_out$on_select)) {
        handler_name <- paste0(safe_id, "_onselect")
        on_sel <- mod_out$on_select
        if (!is.null(on_sel$modal)) {
          # Build modal.open call with parameter mapping
          params_js <- if (!is.null(on_sel$params)) {
            param_parts <- vapply(names(on_sel$params), function(k) {
              v <- on_sel$params[[k]]
              # "row.xxx" → row.xxx (unquoted); anything else → quoted string
              if (grepl("^row\\.", v)) {
                sprintf("%s: %s", k, v)
              } else {
                sprintf("%s: '%s'", k, v)
              }
            }, character(1))
            sprintf("{ %s }", paste(param_parts, collapse = ", "))
          } else "{}"

          # Extract size from modal id's module_output if available
          size_opt <- ""
          if (!is.null(on_sel$size)) {
            size_opt <- sprintf(', { size: "%s" }', on_sel$size)
          }
          lines <- c(lines, sprintf('  function %s(row) {\n    modal.open("%s", %s%s);\n  }',
            handler_name, on_sel$modal, params_js, size_opt))
        } else if (!is.null(on_sel$event)) {
          lines <- c(lines, sprintf('  function %s(row) {\n    events.emit("%s", row);\n  }',
            handler_name, on_sel$event))
        } else if (!is.null(on_sel$navigate)) {
          lines <- c(lines, sprintf('  function %s(row) {\n    currentPage = "%s";\n  }',
            handler_name, on_sel$navigate))
        }
      }
      # Filter state variables and derived params
      if (!is.null(mod_out$filters) && length(mod_out$filters) > 0) {
        for (f in mod_out$filters) {
          filter_var <- paste0(safe_id, "_filter_", f$id)
          lines <- c(lines, sprintf("  let %s = $state('');", filter_var))
          lines <- c(lines, sprintf("  let %s_open = $state(false);", filter_var))
        }
        # Close all filter dropdowns on outside click
        close_all <- paste(vapply(mod_out$filters, function(f) {
          sprintf("%s_filter_%s_open = false", safe_id, f$id)
        }, character(1)), collapse = "; ")
        lines <- c(lines, sprintf(
          "  $effect(() => { function cl(e) { if (!e.target.closest('.filter-chip')) { %s } } document.addEventListener('click', cl); return () => document.removeEventListener('click', cl); });",
          close_all))

        # Derived params object that feeds into DataTable's params prop
        param_parts <- vapply(mod_out$filters, function(f) {
          filter_var <- paste0(safe_id, "_filter_", f$id)
          sprintf("%s: %s", f$id, filter_var)
        }, character(1))
        params_var <- paste0(safe_id, "_params")
        lines <- c(lines, sprintf("  let %s = $derived({ %s });",
          params_var, paste(param_parts, collapse = ", ")))
      }

    } else if (mod_out$type == "cards") {
      # Card field mapping
      card_var <- paste0(safe_id, "_card")
      card_def <- mod_out$card %||% list()
      card_parts <- character(0)
      for (field in c("title", "subtitle", "badge", "badge_label", "badge_color",
                       "footer", "border_color", "icon")) {
        if (!is.null(card_def[[field]])) {
          card_parts <- c(card_parts, sprintf("%s: '%s'", field, card_def[[field]]))
        }
      }
      lines <- c(lines, sprintf("  let %s = { %s };", card_var, paste(card_parts, collapse = ", ")))

      # Rich fields array
      if (!is.null(card_def$fields) && length(card_def$fields) > 0) {
        fields_var <- paste0(safe_id, "_fields")
        # IMPORTANT: use `[[` (exact-match) instead of `$` for field lookups.
        # R's `$` does partial matching on lists by default, so `f$label`
        # would silently match `f$labels` (a multi-element vector) and corrupt
        # `parts` to length-N. Same risk: `f$badge` ↔ `f$badge_color_key`.
        field_entries <- vapply(card_def$fields, function(f) {
          parts <- sprintf("key: '%s'", f[["key"]])
          if (!is.null(f[["icon"]]))    parts <- paste0(parts, sprintf(", icon: '%s'", f[["icon"]]))
          if (!is.null(f[["link"]]))    parts <- paste0(parts, sprintf(", link: '%s'", f[["link"]]))
          if (!is.null(f[["label"]]))   parts <- paste0(parts, sprintf(", label: '%s'", f[["label"]]))
          if (isTRUE(f[["badge"]]))     parts <- paste0(parts, ", badge: true")
          if (!is.null(f[["badge_color_key"]])) parts <- paste0(parts, sprintf(", badge_color_key: '%s'", f[["badge_color_key"]]))
          if (!is.null(f[["class_key"]])) parts <- paste0(parts, sprintf(", class_key: '%s'", f[["class_key"]]))
          if (!is.null(f[["render"]]))  parts <- paste0(parts, sprintf(", render: '%s'", f[["render"]]))
          if (!is.null(f[["colors"]])) {
            colors_map <- f[["colors"]]
            colors_js <- paste(vapply(names(colors_map), function(k) {
              sprintf("'%s': '%s'", k, colors_map[[k]])
            }, character(1)), collapse = ", ")
            parts <- paste0(parts, sprintf(", colors: { %s }", colors_js))
          }
          # Optional `labels` map: remaps raw badge keys to display strings
          # (e.g., "Konkurrenskraft" → "Konk"). Used by render: 'badges'. The
          # raw key still appears as the badge's `title` (tooltip on hover).
          if (!is.null(f[["labels"]])) {
            labels_map <- f[["labels"]]
            labels_js <- paste(vapply(names(labels_map), function(k) {
              sprintf("'%s': '%s'", k, labels_map[[k]])
            }, character(1)), collapse = ", ")
            parts <- paste0(parts, sprintf(", labels: { %s }", labels_js))
          }
          sprintf("{ %s }", parts)
        }, character(1))
        lines <- c(lines, sprintf("  let %s = [%s];", fields_var, paste(field_entries, collapse = ", ")))
      }

      # group_by config: { default, options, label, expandAllLabel, collapseAllLabel }
      # Drives CardGrid's grouping UI: a selector to pick the field to group by,
      # plus expand/collapse-all buttons. See CardGrid.svelte's groupBy prop.
      if (!is.null(mod_out$group_by)) {
        gb <- mod_out$group_by
        gb_var <- paste0(safe_id, "_group_by")
        gb_parts <- character(0)
        if (!is.null(gb$default)) {
          gb_parts <- c(gb_parts, sprintf("default: '%s'", gb$default))
        }
        if (!is.null(gb$options) && length(gb$options) > 0) {
          opts_js <- paste(vapply(names(gb$options), function(k) {
            sprintf("'%s': '%s'", k, gb$options[[k]])
          }, character(1)), collapse = ", ")
          gb_parts <- c(gb_parts, sprintf("options: { %s }", opts_js))
        }
        if (!is.null(gb$label)) {
          gb_parts <- c(gb_parts, sprintf("label: '%s'", gb$label))
        }
        if (!is.null(gb$expand_all_label)) {
          gb_parts <- c(gb_parts, sprintf("expandAllLabel: '%s'", gb$expand_all_label))
        }
        if (!is.null(gb$collapse_all_label)) {
          gb_parts <- c(gb_parts, sprintf("collapseAllLabel: '%s'", gb$collapse_all_label))
        }
        # collapsible: TRUE (default — render as <details> with expand/collapse),
        # FALSE (render as plain <section>, no toolbar buttons)
        if (isFALSE(gb$collapsible)) {
          gb_parts <- c(gb_parts, "collapsible: false")
        }
        lines <- c(lines, sprintf("  let %s = { %s };",
          gb_var, paste(gb_parts, collapse = ", ")))
      }

      # Filters array
      if (!is.null(mod_out$filters) && length(mod_out$filters) > 0) {
        filters_var <- paste0(safe_id, "_filters")
        filter_entries <- vapply(mod_out$filters, function(f) {
          choices_js <- vapply(f$choices, function(ch) {
            sprintf("{ value: '%s', label: '%s' }", ch$value, ch$label)
          }, character(1))
          parts <- sprintf("key: '%s', label: '%s', choices: [%s]",
            f$key, f$label, paste(choices_js, collapse = ", "))
          if (isTRUE(f$min_match)) parts <- paste0(parts, ", min_match: true")
          if (isTRUE(f$toggle)) parts <- paste0(parts, ", toggle: true")
          sprintf("{ %s }", parts)
        }, character(1))
        lines <- c(lines, sprintf("  let %s = [%s];", filters_var, paste(filter_entries, collapse = ",\n    ")))
      }

      # Favorite config
      if (!is.null(mod_out$favorite)) {
        fav <- mod_out$favorite
        fav_var <- paste0(safe_id, "_favorite")
        lines <- c(lines, sprintf("  let %s = { key: '%s', id_key: '%s', endpoint: '%s' };",
          fav_var, fav$key, fav$id_key %||% "id", fav$endpoint))
      }

      # Contact action config
      if (!is.null(mod_out$contact_action)) {
        ca <- mod_out$contact_action
        ca_var <- paste0(safe_id, "_contact_action")
        lines <- c(lines, sprintf("  let %s = { event: '%s', nameKey: '%s', partyKey: '%s', modalTemplate: '%s' };",
          ca_var, ca$event %||% "ambolt:contact-action",
          ca$name_key %||% "name", ca$party_key %||% "party",
          ca$modal_template %||% ""))
      }

      # Labels (i18n)
      if (!is.null(mod_out$labels)) {
        labels_var <- paste0(safe_id, "_labels")
        label_parts <- vapply(names(mod_out$labels), function(k) {
          sprintf("%s: '%s'", k, mod_out$labels[[k]])
        }, character(1))
        lines <- c(lines, sprintf("  let %s = { %s };", labels_var, paste(label_parts, collapse = ", ")))
      }

      # Click handler
      if (!is.null(mod_out$on_click)) {
        handler_name <- paste0(safe_id, "_onclick")
        on_click <- mod_out$on_click
        if (!is.null(on_click$modal)) {
          params_js <- if (!is.null(on_click$params)) {
            param_parts <- vapply(names(on_click$params), function(k) {
              v <- on_click$params[[k]]
              if (grepl("^item\\.", v)) {
                sprintf("%s: %s", k, v)
              } else {
                sprintf("%s: '%s'", k, v)
              }
            }, character(1))
            sprintf("{ %s }", paste(param_parts, collapse = ", "))
          } else "{}"
          size_opt <- ""
          if (!is.null(on_click$size)) {
            size_opt <- sprintf(', { size: "%s" }', on_click$size)
          }
          lines <- c(lines, sprintf('  function %s(item) {\n    modal.open("%s", %s%s);\n  }',
            handler_name, on_click$modal, params_js, size_opt))
        } else if (!is.null(on_click$navigate)) {
          lines <- c(lines, sprintf('  function %s(item) {\n    currentPage = "%s";\n  }',
            handler_name, on_click$navigate))
        }
      }

    } else if (mod_out$type == "stats") {
      # Card definitions
      cards_var <- paste0(safe_id, "_cards")
      card_js <- vapply(mod_out$cards, function(card) {
        parts <- sprintf("key: '%s', label: '%s'", card$key, card$label)
        if (!is.null(card$color)) parts <- paste0(parts, sprintf(", color: '%s'", card$color))
        if (!is.null(card$icon)) parts <- paste0(parts, sprintf(", icon: '%s'", card$icon))
        sprintf("{ %s }", parts)
      }, character(1))
      lines <- c(lines, sprintf("  let %s = [%s];", cards_var, paste(card_js, collapse = ", ")))
    }
  }
  lines
}

#' Generate scenario loader functions as JS code lines
#' @noRd
.generate_scenario_functions <- function(scenarios) {
  if (length(scenarios) == 0) return(character(0))
  vapply(seq_along(scenarios), function(i) {
    s <- scenarios[[i]]
    assignments <- vapply(names(s$values), function(id) {
      val <- s$values[[id]]
      if (is.numeric(val)) {
        sprintf("    %s = %s;", id, format(val, scientific = FALSE))
      } else {
        sprintf("    %s = '%s';", id, val)
      }
    }, character(1))
    sprintf("  function loadScenario%d() {\n%s\n  }",
      i, paste(assignments, collapse = "\n"))
  }, character(1))
}

#' Generate the Svelte <script> block
#' @noRd
.generate_script <- function(inputs, outputs, port, scenarios = list(), pages = NULL, auth = NULL, modals = NULL, module_outputs = NULL, admin_links = list()) {
  # Collect all component names needed
  input_components <- if (length(inputs) > 0) {
    unique(vapply(inputs, function(i) .input_component_name(i$type), character(1)))
  } else character(0)
  output_components <- if (length(outputs) > 0) {
    unique(vapply(outputs, function(o) .output_component_name(o$type), character(1)))
  } else character(0)
  all_components <- c(input_components, output_components)

  # Add page navigation components if pages mode
  if (!is.null(pages)) {
    all_components <- c(all_components, "NavSidebar", "PageRouter")
    # Scan page scripts + HTML for component/utility references
    page_scripts <- paste(vapply(pages, function(p) p$script %||% "", character(1)), collapse = "")
    page_html <- paste(vapply(pages, function(p) p$html %||% "", character(1)), collapse = "")
    page_content <- paste(page_scripts, page_html)
    # Mutation utilities
    for (fn in c("postData", "putData", "deleteData")) {
      if (grepl(fn, page_content, fixed = TRUE)) {
        all_components <- c(all_components, fn)
      }
    }
    # Svelte components referenced in page HTML (e.g., <DataTable .../>)
    for (comp in c("DataTable", "PlotOutput", "HtmlOutput", "TabPanel")) {
      if (grepl(comp, page_content, fixed = TRUE)) {
        all_components <- c(all_components, comp)
      }
    }
    # Event bus
    if (grepl("events\\.", page_content, perl = TRUE)) {
      all_components <- c(all_components, "events")
    }
  }

  # Add auth components if auth is configured
  if (!is.null(auth)) {
    all_components <- c(all_components, "AuthGuard", "auth")
  }

  # Add modal components if modals are registered or page content uses them
  has_modals <- !is.null(modals) && length(modals) > 0
  if (!has_modals && !is.null(pages)) {
    page_all <- paste(
      paste(vapply(pages, function(p) p$script %||% "", character(1)), collapse = ""),
      paste(vapply(pages, function(p) p$html %||% "", character(1)), collapse = ""))
    has_modals <- grepl("modal\\.|data-modal", page_all, perl = TRUE)
  }
  if (has_modals) {
    all_components <- c(all_components, "Modal", "modal", "Toast")
  }

  # Add components needed by module outputs
  if (!is.null(module_outputs) && length(module_outputs) > 0) {
    for (mo in module_outputs) {
      comp <- .module_output_component_name(mo$type)
      all_components <- c(all_components, comp)
      # Table on_select with modal needs modal imports
      if (mo$type == "table" && !is.null(mo$on_select) && !is.null(mo$on_select$modal)) {
        all_components <- c(all_components, "Modal", "modal", "Toast")
      }
      if (mo$type == "table" && !is.null(mo$on_select) && !is.null(mo$on_select$event)) {
        all_components <- c(all_components, "events")
      }
      # Cards on_click with modal
      if (mo$type == "cards" && !is.null(mo$on_click) && !is.null(mo$on_click$modal)) {
        all_components <- c(all_components, "Modal", "modal", "Toast")
      }
    }
  }

  # Add ViewSwitcher if any page uses it
  if (!is.null(pages) && any(vapply(pages, function(p) {
    !is.null(p$ui) && .tree_has_type(p$ui, "view_switcher")
  }, logical(1)))) {
    all_components <- c(all_components, "ViewSwitcher")
  }

  # Add BasketPanel if app uses search_results_panel
  if (any(vapply(inputs, function(i) i$type == "search_results_panel", logical(1)))) {
    all_components <- c(all_components, "BasketPanel")
  }
  # MultiViewPanel is imported by name in the component — no codegen needed

  all_components <- unique(all_components)
  import_line <- if (length(all_components) > 0) {
    sprintf("  import { %s } from 'ambolt';", paste(all_components, collapse = ", "))
  } else {
    "  import { NavSidebar, PageRouter } from 'ambolt';"
  }

  # Generate state declarations for each input
  state_lines <- if (length(inputs) > 0) {
    vapply(inputs, function(i) {
      default_val <- .get_default_value(i)
      if (i$type %in% c("search_results_panel", "multi_view_panel")) {
        # No state variable — display-only components driven by props
        ""
      } else if (i$type == "action") {
        sprintf("  let %s = $state(0);", i$id)
      } else if (i$type == "server_search") {
        # Two state variables: value (selected entity) and query (search text for results page)
        paste0(sprintf("  let %s = $state('');", i$id), "\n",
               sprintf("  let %s_query = $state('');", i$id))
      } else if (i$type == "dynamic_filters") {
        sprintf("  let %s = $state('{}');", i$id)
      } else if (i$type == "multi_select") {
        vals <- if (!is.null(i$args$value)) i$args$value else character(0)
        sprintf("  let %s = $state([%s]);", i$id,
                paste(sprintf("'%s'", vals), collapse = ", "))
      } else if (i$type == "range_slider") {
        rng <- if (!is.null(i$args$value)) i$args$value
               else if (!is.null(i$args$min) && !is.null(i$args$max)) c(i$args$min, i$args$max)
               else c(0, 100)
        sprintf("  let %s = $state([%s, %s]);", i$id,
                format(rng[1], scientific = FALSE),
                format(rng[2], scientific = FALSE))
      } else if (i$type == "checkbox") {
        sprintf("  let %s = $state(%s);", i$id, tolower(as.character(default_val)))
      } else if (i$type == "checkbox_group") {
        vals <- if (!is.null(i$args$selected)) i$args$selected else character(0)
        sprintf("  let %s = $state([%s]);", i$id, paste(sprintf("'%s'", vals), collapse = ", "))
      } else if (length(default_val) == 1 && is.na(default_val)) {
        sprintf("  let %s = $state(NaN);", i$id)
      } else if (is.numeric(default_val)) {
        formatted <- format(default_val, scientific = FALSE)
        sprintf("  let %s = $state(%s);", i$id, formatted)
      } else {
        sprintf("  let %s = $state('%s');", i$id, default_val)
      }
    }, character(1))
  } else character(0)

  # Page state
  page_lines <- character(0)
  if (!is.null(pages)) {
    default_page <- pages[[1]]$id
    page_lines <- c(
      sprintf("  let currentPage = $state('%s');", default_page),
      sprintf("  const pages = [%s];",
        paste(vapply(pages, function(p) {
          icon_part <- if (!is.null(p$icon)) sprintf(", icon: '%s'", p$icon) else ""
          sprintf("{ id: '%s', label: '%s'%s }", p$id, p$label, icon_part)
        }, character(1)), collapse = ", "))
    )
  }

  # Admin links for NavSidebar
  if (length(admin_links) > 0) {
    al_entries <- vapply(admin_links, function(al) {
      parts <- character(0)
      for (k in c("endpoint", "icon", "label", "modal", "modalSize", "refreshEvent")) {
        if (!is.null(al[[k]])) parts <- c(parts, sprintf("%s: '%s'", k, al[[k]]))
      }
      sprintf("{ %s }", paste(parts, collapse = ", "))
    }, character(1))
    page_lines <- c(page_lines,
      sprintf("  const _adminLinks = [%s];", paste(al_entries, collapse = ", ")))
  }

  # Trigger-gated display derived
  triggers <- unique(unlist(lapply(outputs, function(o) o$trigger)))
  triggers <- triggers[!is.null(triggers)]
  derived_lines <- if (length(triggers) > 0) {
    conds <- paste(sprintf("%s > 0", triggers), collapse = " || ")
    sprintf("  let showResults = $derived(%s);", conds)
  } else character(0)

  validation_lines <- .generate_validation_deriveds(inputs)
  scenario_lines <- .generate_scenario_functions(scenarios)
  module_output_lines <- .generate_module_output_script(module_outputs %||% list())

  # Page-level script code (custom JS from page definitions)
  # Import lines are stripped — the framework handles all imports via
  # the unified import statement. This prevents duplicate declarations.
  page_script_lines <- character(0)
  if (!is.null(pages)) {
    default_page <- pages[[1]]$id
    for (p in pages) {
      # Collect scripts from both page-level $script and html_block nodes in $ui
      page_scripts <- character(0)
      if (!is.null(p$script)) page_scripts <- c(page_scripts, p$script)
      if (!is.null(p$ui)) {
        page_scripts <- c(page_scripts, .tree_collect_scripts(p$ui))
      }
      if (length(page_scripts) > 0) {
        combined <- paste(page_scripts, collapse = "\n")
        lines <- strsplit(combined, "\n")[[1]]
        lines <- lines[!grepl("^\\s*import\\s+", lines)]
        # Wrap in a named function + page-enter listener
        fn_name <- sprintf("_page_%s_init", gsub("[^a-zA-Z0-9]", "_", p$id))
        page_script_lines <- c(page_script_lines,
          sprintf("  // -- Page: %s --", p$id),
          sprintf("  function %s() {", fn_name),
          paste0("    ", lines),
          "  }",
          sprintf('  window.addEventListener("ambolt:page-enter", function(e) { if (e.detail.page === "%s") %s(); });', p$id, fn_name),
          # Also run on initial mount for the default page
          if (p$id == default_page) sprintf("  setTimeout(%s, 100);", fn_name) else NULL)
      }
    }
  }

  lines <- c("<script>", import_line, "", state_lines, page_lines,
             derived_lines, validation_lines, "", scenario_lines,
             module_output_lines, page_script_lines, "</script>")
  paste(lines, collapse = "\n")
}
