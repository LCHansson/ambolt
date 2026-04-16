# --- ambolt layout templates and App.svelte orchestrator ----------
#
# HTML layout templates (sidebar, stacked) and the top-level orchestrator
# that assembles a complete App.svelte from all codegen modules.
#
# Depends on:
#   codegen_script.R — <script> block generation
#   codegen_markup.R — input/output Svelte markup
#   codegen_css.R    — CSS generation for framework features
#   codegen_tree.R   — layout tree walker

# --- Layout templates --------------------------------------------

#' Render sidebar layout
#' @noRd
.render_sidebar_layout <- function(input_markup, content_html, extra_css) {
  sprintf('
<main>
  <div class="sidebar-layout">
    <div class="sidebar">
%s
    </div>
    <div class="content">
%s
    </div>
  </div>
</main>

<style>
  :root {
    --ambolt-font: system-ui, sans-serif;
    --ambolt-max-width: 1200px;
    --ambolt-sidebar-width: 280px;
    --ambolt-gap: 2rem;
    --ambolt-sidebar-bg: white;
    --ambolt-sidebar-border: 1px solid #d1d5db;
    --ambolt-sidebar-radius: 6px;
    --ambolt-sidebar-padding: 1.5rem;
    --ambolt-content-gap: 1.5rem;
    --ambolt-breakpoint: 768px;
  }
  main {
    font-family: var(--ambolt-font);
    max-width: var(--ambolt-max-width);
    margin: var(--ambolt-margin, 2rem auto);
    padding: var(--ambolt-padding, 0 1rem);
  }
  .sidebar-layout {
    display: grid;
    grid-template-columns: var(--ambolt-sidebar-width) 1fr;
    gap: var(--ambolt-gap);
  }
  .sidebar {
    border: var(--ambolt-sidebar-border);
    border-radius: var(--ambolt-sidebar-radius);
    padding: var(--ambolt-sidebar-padding);
    background: var(--ambolt-sidebar-bg);
    align-self: start;
  }
  .content {
    display: flex;
    flex-direction: column;
    gap: var(--ambolt-content-gap);
  }
  @media (max-width: 768px) {
    main { padding: 0 0.5rem; margin: 1rem auto; }
    .sidebar-layout { grid-template-columns: 1fr; gap: 1rem; }
    .sidebar { padding: 1rem; }
  }%s
</style>',
    paste(input_markup, collapse = "\n"),
    content_html,
    extra_css)
}

#' Render stacked layout (fallback)
#' @noRd
.render_stacked_layout <- function(input_markup, content_html, extra_css) {
  sprintf('
<main>
%s
%s
</main>

<style>
  main {
    font-family: var(--ambolt-font, system-ui, sans-serif);
    max-width: 800px;
    margin: 2rem auto;
    padding: 0 1rem;
  }%s
</style>',
    paste(input_markup, collapse = "\n"),
    content_html,
    extra_css)
}

#' Render page_content as top-level layout.
#'
#' Full-width flex column with the same CSS variables as sidebar_layout
#' (so nested sidebar_layout nodes get their styling). Analogous to
#' Shiny's fluidPage().
#' @noRd
.render_page_content_toplevel <- function(content_html, extra_css) {
  sprintf('
<main>
  <div class="ambolt-page-content">
%s
  </div>
</main>

<style>
  :root {
    --ambolt-font: system-ui, sans-serif;
    --ambolt-max-width: 1200px;
    --ambolt-sidebar-width: 280px;
    --ambolt-gap: 2rem;
    --ambolt-sidebar-bg: white;
    --ambolt-sidebar-border: 1px solid #d1d5db;
    --ambolt-sidebar-radius: 6px;
    --ambolt-sidebar-padding: 1.5rem;
    --ambolt-content-gap: 1.5rem;
    --ambolt-breakpoint: 768px;
  }
  main {
    font-family: var(--ambolt-font);
    max-width: var(--ambolt-max-width);
    margin: var(--ambolt-margin, 2rem auto);
    padding: var(--ambolt-padding, 0 1rem);
  }
  .ambolt-page-content {
    display: flex;
    flex-direction: column;
    gap: var(--ambolt-content-gap);
  }
  /* Nested sidebar_layout inside page_content */
  .sidebar-layout {
    display: grid;
    grid-template-columns: var(--ambolt-sidebar-width) 1fr;
    gap: var(--ambolt-gap);
  }
  .sidebar {
    border: var(--ambolt-sidebar-border);
    border-radius: var(--ambolt-sidebar-radius);
    padding: var(--ambolt-sidebar-padding);
    background: var(--ambolt-sidebar-bg);
    align-self: start;
  }
  .content {
    display: flex;
    flex-direction: column;
    gap: var(--ambolt-content-gap);
  }
  @media (max-width: 768px) {
    main { padding: 0 0.5rem; margin: 1rem auto; }
    .sidebar-layout { grid-template-columns: 1fr; gap: 1rem; }
    .sidebar { padding: 1rem; }
  }%s
</style>',
    content_html,
    extra_css)
}

# --- App.svelte orchestrator -------------------------------------

#' Generate the full App.svelte content
#'
#' Orchestrates script generation, input/output markup, layout rendering,
#' and conditional display logic into a complete Svelte component.
#' Supports two modes:
#'   1. Layout tree (app$ui()) — walks the tree to place items
#'   2. Legacy implicit layout — inputs→sidebar, outputs→content
#' @noRd
.generate_app_svelte <- function(app_env) {
  inputs <- app_env$.inputs
  outputs <- app_env$.outputs
  port <- app_env$.port
  empty_state <- app_env$.empty_state
  scenarios <- app_env$.scenarios
  theme_css <- app_env$.theme_css
  theme_colors <- app_env$.theme_colors
  ui_tree <- app_env$.ui_tree
  pages <- app_env$.pages

  auth <- app_env$.auth
  modals <- app_env$.modals
  module_outputs <- app_env$.module_outputs
  admin_links <- app_env$.admin_links %||% list()
  script <- .generate_script(inputs, outputs, port, scenarios, pages, auth, modals, module_outputs, admin_links)

  # Each layout mode returns list(markup, head_parts)
  if (!is.null(pages)) {
    result <- .generate_from_pages(app_env)
  } else if (!is.null(ui_tree)) {
    result <- .generate_from_tree(ui_tree, inputs, outputs, port, empty_state, scenarios)
  } else {
    result <- .generate_from_legacy(app_env)
  }

  markup <- result$markup

  # Append Modal component if modals are registered
  has_modals <- length(modals) > 0
  if (!has_modals && !is.null(pages)) {
    page_scripts <- paste(vapply(pages, function(p) p$script %||% "", character(1)), collapse = "")
    has_modals <- grepl("modal\\.", page_scripts, perl = TRUE)
  }
  # Module outputs with on_select/on_click → modal also need Modal
  if (!has_modals && length(module_outputs) > 0) {
    has_modals <- any(vapply(module_outputs, function(mo) {
      (!is.null(mo$on_select) && !is.null(mo$on_select$modal)) ||
      (!is.null(mo$on_click) && !is.null(mo$on_click$modal))
    }, logical(1)))
  }
  if (has_modals) {
    markup <- paste0(markup, "\n<Modal />\n<Toast />")
  }

  # Wrap in AuthGuard if auth is configured
  if (!is.null(auth)) {
    login_title <- auth$login_title %||% app_env$.meta$title %||% "Logga in"
    markup <- sprintf('
<AuthGuard loginTitle="%s">
  {#snippet children()}%s
  {/snippet}
</AuthGuard>', login_title, markup)
  }
  head_parts <- result$head_parts %||% character(0)

  # -- Unified <svelte:head> assembly --
  # All modes contribute to head_parts; theme assets are added here.
  theme_fonts <- app_env$.theme_fonts
  if (!is.null(theme_fonts)) {
    head_parts <- c(head_parts, vapply(theme_fonts, function(url) {
      sprintf('  <link rel="stylesheet" href="%s" />', url)
    }, character(1)))
  }

  # Theme colors (CSS variables)
  colors_css <- .generate_theme_colors_css(theme_colors)

  # Theme tokens (fonts, radius, component overrides)
  tokens_css <- .generate_theme_tokens_css(app_env)

  # Combine all CSS: theme colors + tokens + mode-specific + custom theme CSS
  all_css <- paste0(colors_css, "\n", tokens_css, result$style_css %||% "")
  if (!is.null(theme_css)) {
    all_css <- paste0(all_css, "\n", theme_css)
  }
  if (nchar(all_css) > 0) {
    head_parts <- c(head_parts, sprintf("  <style>%s\n  </style>", all_css))
  }

  theme_block <- ""
  if (length(head_parts) > 0) {
    theme_block <- sprintf("\n\n<svelte:head>\n%s\n</svelte:head>",
      paste(head_parts, collapse = "\n"))
  }

  paste0(script, "\n", markup, theme_block)
}

#' Generate markup from a layout tree (new mode).
#'
#' Supports two top-level layout types:
#'   - sidebar_layout: traditional two-column sidebar + content
#'   - page_content:   full-width stacked layout (can nest sidebar_layout)
#' @noRd
.generate_from_tree <- function(ui_tree, inputs, outputs, port, empty_state, scenarios) {
  stopifnot(ui_tree$type %in% c("sidebar_layout", "page_content"))

  # Always emit DSL primitive CSS — modals can use these at runtime
  # regardless of what the page tree contains (RenderNode.svelte).
  extra_css <- paste0(
    .generate_empty_state_css(empty_state),
    .generate_tooltip_css(inputs),
    .generate_section_css(TRUE),
    .generate_columns_css(TRUE),
    .generate_details_css(TRUE)
  )

  if (ui_tree$type == "page_content") {
    return(.generate_from_tree_page_content(ui_tree, inputs, outputs, port,
                                            empty_state, scenarios, extra_css))
  }

  # --- sidebar_layout (original path) ---
  # Render sidebar children individually so we can wrap action buttons
  sidebar_parts <- vapply(ui_tree$sidebar$children, function(child) {
    tag <- .render_tree_node(child, inputs, outputs, port)
    # If this is an action button, hide it after first trigger and show
    # scenario buttons in its place (matching Shiny's "button disappears" pattern)
    if (is.character(child) && child %in% names(inputs) && inputs[[child]]$type == "action") {
      button_wrapped <- sprintf("    {#if !showResults}\n%s\n    {/if}", tag)
      if (length(scenarios) > 0) {
        scenario_buttons <- vapply(seq_along(scenarios), function(i) {
          sprintf('        <button class="scenario-button" onclick={loadScenario%d}>%s</button>',
            i, scenarios[[i]]$label)
        }, character(1))
        scenario_html <- sprintf(
          '    {#if showResults}\n    <div class="sidebar-scenarios">\n      <p class="sidebar-scenarios-label">Du kan ocks\u00e5 testa ett av f\u00f6ljande scenarier:</p>\n      <div class="scenario-buttons">\n%s\n      </div>\n    </div>\n    {/if}',
          paste(scenario_buttons, collapse = "\n"))
        return(paste(button_wrapped, scenario_html, sep = "\n"))
      }
      return(button_wrapped)
    }
    tag
  }, character(1))
  sidebar_html <- paste(sidebar_parts, collapse = "\n")
  content_items <- .render_tree_children(ui_tree$main$children, inputs, outputs, port)

  # Wrap content with empty state / trigger display logic
  content_html <- .wrap_content_with_empty_state(content_items, outputs, empty_state, scenarios)

  list(markup = .render_sidebar_layout(list(sidebar_html), content_html, extra_css))
}

#' Generate markup when the top-level node is page_content.
#'
#' Renders all children (sections, outputs, nested sidebar_layout, etc.)
#' via the tree walker and wraps them in a full-width flex container.
#' @noRd
.generate_from_tree_page_content <- function(ui_tree, inputs, outputs, port,
                                             empty_state, scenarios, extra_css) {
  content_items <- .render_tree_children(ui_tree$children, inputs, outputs, port)
  content_html <- .wrap_content_with_empty_state(content_items, outputs, empty_state, scenarios)
  list(markup = .render_page_content_toplevel(content_html, extra_css))
}

#' Generate markup from legacy implicit layout (backward compatible).
#' @noRd
.generate_from_legacy <- function(app_env) {
  inputs <- app_env$.inputs
  outputs <- app_env$.outputs
  port <- app_env$.port
  layout <- app_env$.layout
  empty_state <- app_env$.empty_state
  scenarios <- app_env$.scenarios
  sections <- app_env$.sections

  if (is.null(layout)) layout <- list(type = "sidebar")

  # Use section-aware input rendering if sections exist
  if (length(sections) > 0) {
    input_markup <- .generate_sidebar_inputs(inputs, sections)
  } else {
    input_markup <- vapply(inputs, .generate_input_markup, character(1))
  }

  content_html <- .generate_content_html(outputs, port, empty_state, scenarios)
  extra_css <- paste0(
    .generate_empty_state_css(empty_state),
    .generate_tooltip_css(inputs),
    .generate_section_css(length(sections) > 0)
  )

  markup <- if (layout$type == "sidebar") {
    .render_sidebar_layout(input_markup, content_html, extra_css)
  } else {
    .render_stacked_layout(input_markup, content_html, extra_css)
  }

  list(markup = markup)
}

#' Wrap content-area markup with empty state and trigger display logic.
#'
#' In tree mode, the content comes pre-rendered from the tree walker.
#' This function adds the empty state before it and wraps trigger-gated
#' content in {#if showResults}.
#' @noRd
.wrap_content_with_empty_state <- function(content_items, outputs, empty_state, scenarios) {
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
    image_html <- if (!is.null(empty_state$image) && nchar(empty_state$image) > 0) {
      sprintf('\n      <img class="empty-state-image" src="/%s" alt="" />', empty_state$image)
    } else ""
    empty_html <- sprintf(
      '    {#if !showResults}\n    <div class="empty-state">%s\n      <h2>%s</h2>%s%s\n    </div>\n    {/if}',
      image_html,
      empty_state$title,
      if (!is.null(empty_state$subtitle)) sprintf("\n      <p>%s</p>", empty_state$subtitle) else "",
      scenario_html
    )
    # In tree mode, individual outputs and sections handle their own
    # visibility (show_after / trigger). No bulk wrapping needed.
    sprintf('%s\n%s', empty_html, content_items)
  } else {
    content_items
  }
}

# --- Pages mode layout ----------------------------------------

#' Generate markup for multi-page navigation mode.
#'
#' Produces an app-level layout with NavSidebar + PageRouter.
#' Pages with a `ui` field get their content from the layout tree walker.
#' Pages with `html`/`script` work as before (backward compatible).
#' @noRd
.generate_from_pages <- function(app_env) {
  pages <- app_env$.pages
  meta <- app_env$.meta
  inputs <- app_env$.inputs
  outputs <- app_env$.outputs
  port <- app_env$.port
  module_outputs <- app_env$.module_outputs

  # Build page content snippets
  page_cases <- vapply(pages, function(p) {
    if (!is.null(p$ui)) {
      # Declarative mode: walk the UI tree
      content <- .render_tree_node(p$ui, inputs, outputs, port, module_outputs)
    } else {
      content <- p$html %||% sprintf('<p>Sidan "%s" har inget inneh\u00e5ll \u00e4nnu.</p>', p$label)
    }
    sprintf("        {#if pageId === '%s'}\n          %s\n        {/if}", p$id, content)
  }, character(1))

  nav_title <- meta$title %||% ""

  # Pages layout CSS (grid only — component styles live in .svelte files)
  layout_css <- .generate_pages_layout_css(TRUE)

  # Check if any page uses declarative features that need CSS
  has_page_header <- any(vapply(pages, function(p) {
    !is.null(p$ui) && .tree_has_type(p$ui, "page_header")
  }, logical(1)))
  has_stat_cards <- any(vapply(pages, function(p) {
    !is.null(p$ui) && .tree_has_type(p$ui, "stat_cards")
  }, logical(1)))
  has_page_content <- any(vapply(pages, function(p) !is.null(p$ui), logical(1)))

  # Check if any module output uses filters
  has_filters <- any(vapply(module_outputs, function(mo) {
    !is.null(mo$filters) && length(mo$filters) > 0
  }, logical(1)))

  extra_css <- paste0(
    .generate_page_header_css(has_page_header),
    .generate_page_content_css(has_page_content),
    .generate_filter_bar_css(has_filters),
    # Always emit DSL primitive CSS — modals can use these at runtime
    # regardless of what the page tree contains (RenderNode.svelte).
    .generate_section_css(TRUE),
    .generate_columns_css(TRUE),
    .generate_details_css(TRUE)
  )

  style_css <- paste0("\n  :root { --ambolt-font: system-ui, sans-serif; }", layout_css, extra_css)

  # Bootstrap Icons CDN link
  head_parts <- c(
    '  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" />'
  )

  # Conditionally pass user info to NavSidebar when auth is configured
  auth <- app_env$.auth
  sidebar_extra_props <- ""
  if (!is.null(auth)) {
    sidebar_extra_props <- "\n    user={auth.user}\n    onlogout={() => auth.logout()}"
  }
  # Admin links (configurable sidebar items with live count badges)
  if (length(app_env$.admin_links) > 0) {
    sidebar_extra_props <- paste0(sidebar_extra_props, "\n    adminLinks={_adminLinks}")
  }

  markup <- sprintf('
<NavSidebar
  {pages}
  bind:currentPage={currentPage}
  title="%s"%s
/>
<div class="ambolt-app-layout">
  <PageRouter {pages} {currentPage}>
    {#snippet page(pageId)}
%s
    {/snippet}
  </PageRouter>
</div>',
    nav_title,
    sidebar_extra_props,
    paste(page_cases, collapse = "\n"))

  list(markup = markup, head_parts = head_parts, style_css = style_css)
}
