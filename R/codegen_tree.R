# --- ambolt layout tree walker -------------------------------------
#
# Walks the layout tree (built by the DSL functions in layout_dsl.R)
# and renders each node to Svelte markup. Resolves input/output ids
# against their registries.
# Depends on: codegen_markup.R (.generate_input_markup, .generate_output_markup)
#             utils.R (.style_to_string)

# --- Styling helpers ------------------------------------------------

#' Build a CSS class string: base framework classes + optional user class.
#' @noRd
.render_class_attr <- function(base_classes, node_class = NULL) {
  if (!is.null(node_class)) paste(base_classes, node_class) else base_classes
}

#' Build a style="..." HTML attribute from a node's style field.
#' Returns empty string if no style, or ' style="..."' with leading space.
#' @noRd
.render_style_attr <- function(node_style) {
  s <- .style_to_string(node_style)
  if (is.null(s)) return("")
  sprintf(' style="%s"', s)
}

#' Render a single node in the layout tree to Svelte markup.
#'
#' A node is either a bare string (input/output id) or a layout node
#' (list with $type). The walker resolves ids against the inputs/outputs
#' registries and dispatches to the appropriate renderer.
#'
#' In pages mode, bare strings can also reference module outputs
#' (e.g., "contacts/table") which are resolved against module_outputs.
#' @noRd
.render_tree_node <- function(node, inputs, outputs, port, module_outputs = NULL) {
  # Bare string: resolve to input, output, or module output markup
  if (is.character(node) && length(node) == 1) {
    if (node %in% names(inputs)) {
      return(.generate_input_markup(inputs[[node]]))
    } else if (node %in% names(outputs)) {
      tag <- .generate_output_markup(outputs[[node]], port)
      # Wrap trigger-gated outputs in {#if showResults} to hide before trigger
      if (!is.null(outputs[[node]]$trigger)) {
        tag <- sprintf("    {#if showResults}\n%s\n    {/if}", tag)
      }
      return(tag)
    } else if (!is.null(module_outputs) && node %in% names(module_outputs)) {
      return(.generate_module_output_markup(module_outputs[[node]]))
    } else {
      stop(sprintf("Layout tree references unknown id: '%s'", node))
    }
  }

  # Layout node: dispatch by type
  switch(node$type,
    section = .render_tree_section(node, inputs, outputs, port, module_outputs),
    columns = .render_tree_columns(node, inputs, outputs, port, module_outputs),
    details = .render_tree_details(node, inputs, outputs, port, module_outputs),
    sidebar_layout = .render_tree_sidebar_layout(node, inputs, outputs, port, module_outputs),
    page_content = .render_tree_page_content(node, inputs, outputs, port, module_outputs),
    page_header = .render_tree_page_header(node),
    stat_cards = .render_tree_stat_cards(node, module_outputs),
    html_block = .render_tree_html_block(node),
    logout_button = .render_tree_logout_button(node),
    view_switcher = .render_tree_view_switcher(node, inputs, outputs, port, module_outputs),
    stop(sprintf("Unknown layout node type: '%s'", node$type))
  )
}

#' Render children of a layout node, concatenating markup.
#' @noRd
.render_tree_children <- function(children, inputs, outputs, port, module_outputs = NULL) {
  parts <- vapply(children, function(child) {
    .render_tree_node(child, inputs, outputs, port, module_outputs)
  }, character(1))
  paste(parts, collapse = "\n")
}

#' Render a section node from the layout tree.
#' @noRd
.render_tree_section <- function(node, inputs, outputs, port, module_outputs = NULL) {
  toggle_id <- node$toggle

  # Filter out the toggle checkbox from children (it goes in the header)
  children <- node$children
  if (!is.null(toggle_id)) {
    children <- Filter(function(c) !(is.character(c) && c == toggle_id), children)
  }

  inner <- .render_tree_children(children, inputs, outputs, port, module_outputs)

  # Build section header
  if (!is.null(node$label)) {
    if (!is.null(toggle_id)) {
      # Toggle section: checkbox + label in header row, help icon pulled from
      # the toggle input's help text if present
      toggle_input <- inputs[[toggle_id]]
      help_html <- ""
      if (!is.null(toggle_input$args$help)) {
        safe_help <- gsub('"', '&quot;', toggle_input$args$help)
        help_html <- sprintf(
          ' <span class="help-tooltip section-help"><span class="help-icon">?</span><span class="help-text">%s</span></span>',
          safe_help)
      }
      header <- sprintf(
        '    <div class="section-header">\n      <label class="section-toggle"><input type="checkbox" bind:checked={%s} /> %s</label>%s\n    </div>',
        toggle_id, node$label, help_html)
      # Wrap body in a div that dims when toggle is off
      inner <- sprintf('%s\n    <div class="section-body" class:section-dimmed={!%s}>\n%s\n    </div>',
        header, toggle_id, inner)
    } else {
      inner <- sprintf('    <h4 class="section-label">%s</h4>\n%s', node$label, inner)
    }
  }

  # Build CSS class list
  classes <- "section"
  if (isTRUE(node$compact)) classes <- paste(classes, "section-compact")
  classes <- .render_class_attr(classes, node$class)
  style_attr <- .render_style_attr(node$style)

  # Wrap in a div with section class
  block <- sprintf('    <div class="%s"%s>\n%s\n    </div>', classes, style_attr, inner)

  # Wrap in {#if} for show_after (trigger-gated)
  if (!is.null(node$show_after)) {
    block <- sprintf("    {#if %s > 0}\n%s\n    {/if}", node$show_after, block)
  }

  # Wrap in {#if} for show_when (input-gated)
  if (!is.null(node$show_when)) {
    block <- sprintf("    {#if %s}\n%s\n    {/if}", .show_when_condition(node$show_when), block)
  }

  block
}

#' Render a columns node from the layout tree.
#' @noRd
.render_tree_columns <- function(node, inputs, outputs, port, module_outputs = NULL) {
  col_parts <- vapply(node$children, function(child) {
    inner <- .render_tree_node(child, inputs, outputs, port, module_outputs)
    sprintf('      <div class="ambolt-column">\n%s\n      </div>', inner)
  }, character(1))

  col_classes <- .render_class_attr("ambolt-columns", node$class)
  col_style <- node$style %||% list()
  if (!is.null(node$gap)) col_style[["gap"]] <- node$gap
  style_attr <- .render_style_attr(col_style)

  sprintf('    <div class="%s"%s>\n%s\n    </div>',
    col_classes, style_attr, paste(col_parts, collapse = "\n"))
}

#' Render a details (collapsible) node from the layout tree.
#' @noRd
.render_tree_details <- function(node, inputs, outputs, port, module_outputs = NULL) {
  inner <- .render_tree_children(node$children, inputs, outputs, port, module_outputs)
  open_attr <- if (isTRUE(node$open)) " open" else ""
  det_classes <- .render_class_attr("ambolt-details", node$class)
  style_attr <- .render_style_attr(node$style)

  block <- sprintf(
    '    <details class="%s"%s%s>\n      <summary>%s</summary>\n      <div class="ambolt-details-content">\n%s\n      </div>\n    </details>',
    det_classes, style_attr, open_attr, node$label, inner)

  if (!is.null(node$show_after)) {
    block <- sprintf("    {#if %s > 0}\n%s\n    {/if}", node$show_after, block)
  }

  block
}

#' Render a sidebar_layout node nested inside another layout (e.g. page_content).
#'
#' Produces a two-column grid identical to the top-level sidebar_layout
#' template but as an inline HTML block (no wrapping <main>/<style>).
#' CSS for .sidebar-layout/.sidebar/.content is provided by the
#' top-level template that contains it.
#' @noRd
.render_tree_sidebar_layout <- function(node, inputs, outputs, port, module_outputs = NULL) {
  sidebar_html <- .render_tree_children(node$sidebar$children, inputs, outputs, port, module_outputs)
  content_html <- .render_tree_children(node$main$children, inputs, outputs, port, module_outputs)
  sprintf('    <div class="sidebar-layout">\n      <div class="sidebar">\n%s\n      </div>\n      <div class="content">\n%s\n      </div>\n    </div>',
    sidebar_html, content_html)
}

# --- Pages-mode node renderers --------------------------------------

#' Render a page_content container node.
#' @noRd
.render_tree_page_content <- function(node, inputs, outputs, port, module_outputs = NULL) {
  inner <- .render_tree_children(node$children, inputs, outputs, port, module_outputs)
  pc_classes <- .render_class_attr("ambolt-page-content", node$class)
  pc_style <- node$style %||% list()
  if (!is.null(node$gap)) pc_style[["gap"]] <- node$gap
  style_attr <- .render_style_attr(pc_style)
  sprintf('    <div class="%s"%s>\n%s\n    </div>', pc_classes, style_attr, inner)
}

#' Render a page_header node with title, subtitle, and action buttons.
#' @noRd
.render_tree_page_header <- function(node) {
  help_html <- if (!is.null(node$help)) {
    sprintf(' <span class="ambolt-page-help">%s</span>', node$help)
  } else ""
  title_html <- sprintf('<h2 class="ambolt-page-title">%s%s</h2>', node$title, help_html)
  subtitle_html <- if (!is.null(node$subtitle)) {
    sprintf('\n        <p class="ambolt-page-subtitle">%s</p>', node$subtitle)
  } else ""

  actions_html <- ""
  if (length(node$actions) > 0) {
    action_parts <- vapply(node$actions, function(a) {
      if (is.list(a) && !is.null(a$type)) {
        switch(a$type,
          logout_button = .render_tree_logout_button(a),
          create_button = .render_tree_create_button(a),
          html_block = .render_tree_html_block(a),
          sprintf("<!-- unknown action type: %s -->", a$type)
        )
      } else if (is.character(a)) {
        a
      } else {
        "<!-- unknown action -->"
      }
    }, character(1))
    actions_html <- sprintf('\n      <div class="ambolt-page-actions">\n%s\n      </div>',
      paste(paste0("        ", action_parts), collapse = "\n"))
  }

  hdr_classes <- .render_class_attr("ambolt-page-header", node$class)
  style_attr <- .render_style_attr(node$style)
  sprintf('    <div class="%s"%s>\n      <div class="ambolt-page-header-title">%s%s\n      </div>%s\n    </div>',
    hdr_classes, style_attr, title_html, subtitle_html, actions_html)
}

#' Render a stat_cards reference node.
#' @noRd
.render_tree_stat_cards <- function(node, module_outputs = NULL) {
  output_id <- node$output_id
  if (!is.null(module_outputs) && output_id %in% names(module_outputs)) {
    return(.generate_module_output_markup(module_outputs[[output_id]]))
  }
  sprintf('    <StatCards outputId="%s" />', output_id)
}

#' Render an html_block escape hatch node.
#' When class or style is specified, wraps HTML in a <div>. Otherwise raw.
#' @noRd
.render_tree_html_block <- function(node) {
  if (!is.null(node$class) || !is.null(node$style)) {
    cls <- node$class %||% ""
    style_attr <- .render_style_attr(node$style)
    sprintf('    <div class="%s"%s>%s</div>', cls, style_attr, node$html)
  } else {
    sprintf("    %s", node$html)
  }
}

#' Render a create_button action node.
#' @noRd
.render_tree_create_button <- function(node) {
  label <- node$label
  variant <- node$variant %||% "primary"
  base_class <- if (variant == "primary") "ambolt-action-btn ambolt-action-btn-primary" else "ambolt-action-btn"
  btn_classes <- .render_class_attr(base_class, node$class)
  style_attr <- .render_style_attr(node$style)
  icon_html <- if (!is.null(node$icon)) sprintf('<i class="bi bi-%s"></i> ', node$icon) else ""

  # Download link or modal link rendered as <a>
  if (!is.null(node$href)) {
    download_attr <- if (isTRUE(node$download)) " download" else ""
    # Merge base link styles with node styles to avoid duplicate style attributes
    base_style <- "text-decoration:none;display:inline-flex;align-items:center;gap:0.3rem;"
    extra_style <- if (!is.null(node$style)) .style_to_string(node$style) else ""
    combined_style <- paste0(base_style, extra_style)
    return(sprintf('<a href="%s"%s class="%s" style="%s">%s%s</a>',
      node$href, download_attr, btn_classes, combined_style, icon_html, label))
  }

  # Modal or navigate button
  if (!is.null(node$modal)) {
    return(sprintf('<button class="%s"%s data-modal="%s" data-modal-size="%s">%s%s</button>',
      btn_classes, style_attr, node$modal, node$modal_size %||% "md", icon_html, label))
  }

  onclick <- if (!is.null(node$navigate)) {
    sprintf("() => currentPage = '%s'", node$navigate)
  } else "() => {}"

  sprintf('<button class="%s"%s onclick={%s}>%s%s</button>', btn_classes, style_attr, onclick, icon_html, label)
}

#' Render a logout_button node.
#' @noRd
.render_tree_logout_button <- function(node) {
  label <- node$label %||% "Logga ut"
  btn_classes <- .render_class_attr("ambolt-logout-btn", node$class)
  style_attr <- .render_style_attr(node$style)
  sprintf('<button class="%s"%s onclick={() => auth.logout()}>%s ({auth.user?.name})</button>',
    btn_classes, style_attr, label)
}

#' Render a view_switcher node: button bar + conditional view content.
#' @noRd
.render_tree_view_switcher <- function(node, inputs, outputs, port, module_outputs = NULL) {
  views <- node$views
  default_view <- node$default %||% views[[1]]$id

  # Build views JSON array for the Svelte component prop
  views_json <- sprintf("[%s]", paste(vapply(views, function(v) {
    icon_part <- if (!is.null(v$icon)) sprintf(',icon:"%s"', v$icon) else ""
    sprintf('{id:"%s",label:"%s"%s}', v$id, v$label, icon_part)
  }, character(1)), collapse = ","))

  # Build {#if} blocks for each view's content
  view_blocks <- vapply(views, function(v) {
    inner <- .render_tree_children(v$children, inputs, outputs, port, module_outputs)
    sprintf("      {#if activeView === '%s'}\n%s\n      {/if}", v$id, inner)
  }, character(1))

  # Build optional actions snippet
  actions_snippet <- ""
  if (!is.null(node$actions)) {
    actions_html <- if (is.character(node$actions)) node$actions
                    else if (!is.null(node$actions$type) && node$actions$type == "html_block") node$actions$html
                    else ""
    actions_snippet <- sprintf('\n      {#snippet actions()}\n        %s\n      {/snippet}', actions_html)
  }

  extra_props <- ""
  if (!is.null(node$class)) extra_props <- paste0(extra_props, sprintf(' class="%s"', node$class))
  if (!is.null(node$style)) extra_props <- paste0(extra_props, sprintf(' style="%s"', .style_to_string(node$style)))

  sprintf('    <ViewSwitcher views={%s} defaultView="%s"%s>\n      {#snippet content(activeView)}\n%s\n      {/snippet}%s\n    </ViewSwitcher>',
    views_json, default_view, extra_props, paste(view_blocks, collapse = "\n"), actions_snippet)
}

#' Collect scripts from html_block nodes in a layout tree.
#'
#' Walks the tree recursively and returns a character vector of all
#' script strings found on html_block nodes. Used to elevate html_block
#' scripts into the page-level script block.
#' @noRd
.tree_collect_scripts <- function(node) {
  if (is.character(node)) return(character(0))
  scripts <- character(0)
  if (node$type == "html_block" && !is.null(node$script)) {
    scripts <- c(scripts, node$script)
  }
  children <- node$children %||% list()
  if (node$type == "sidebar_layout") {
    children <- list(node$sidebar, node$main)
  }
  # Also walk page_header actions (may contain html_block nodes with scripts)
  if (node$type == "page_header" && length(node$actions) > 0) {
    children <- c(children, node$actions)
  }
  # Walk view_switcher views and their children
  if (node$type == "view_switcher") {
    children <- unlist(lapply(node$views, function(v) v$children), recursive = FALSE)
    if (!is.null(node$actions)) children <- c(children, list(node$actions))
  }
  for (child in children) {
    scripts <- c(scripts, .tree_collect_scripts(child))
  }
  scripts
}

#' Check if a layout tree contains any nodes of a given type.
#' @noRd
.tree_has_type <- function(node, target_type) {
  if (is.character(node)) return(FALSE)
  if (node$type == target_type) return(TRUE)
  children <- node$children %||% list()
  # Also check sidebar/main for sidebar_layout
  if (node$type == "sidebar_layout") {
    children <- list(node$sidebar, node$main)
  }
  # Also check page_header actions (may contain html_block etc.)
  if (node$type == "page_header" && length(node$actions) > 0) {
    children <- c(children, node$actions)
  }
  # Walk view_switcher views and their children
  if (node$type == "view_switcher") {
    children <- unlist(lapply(node$views, function(v) v$children), recursive = FALSE)
    if (!is.null(node$actions)) children <- c(children, list(node$actions))
  }
  any(vapply(children, function(c) .tree_has_type(c, target_type), logical(1)))
}
