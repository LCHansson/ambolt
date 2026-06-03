# --- ambolt CSS generation -----------------------------------------
#
# Generates CSS blocks for framework features: empty state, tooltips,
# sections, columns, details. Each function returns a CSS string
# (or empty string if the feature isn't used).

#' Generate CSS variables from theme colors
#'
#' Produces --ambolt-{name} variables plus hover/focus derived variants.
#' Returns empty string if no colors are defined.
#' @noRd
.generate_theme_colors_css <- function(colors) {
  if (is.null(colors) || length(colors) == 0) return("")

  lines <- character(0)
  for (name in names(colors)) {
    hex <- colors[[name]]
    lines <- c(lines, sprintf("    --ambolt-%s: %s;", name, hex))
    # Derive a darker hover variant (mix with black ~15%)
    lines <- c(lines, sprintf("    --ambolt-%s-hover: color-mix(in srgb, %s 85%%, black);", name, hex))
    # Derive a lighter/muted variant (mix with white ~70%)
    lines <- c(lines, sprintf("    --ambolt-%s-muted: color-mix(in srgb, %s 30%%, white);", name, hex))
    # Focus ring color (semi-transparent)
    lines <- c(lines, sprintf("    --ambolt-%s-focus: color-mix(in srgb, %s 40%%, transparent);", name, hex))
  }

  sprintf("\n  :root {\n%s\n  }", paste(lines, collapse = "\n"))
}

#' Generate :root CSS from the nested design-token tree.
#'
#' Walks `tokens` (a nested named list -- see `R/app.R` `app_env$theme`'s
#' `tokens =` argument and `vignettes/theming.Rmd`) and emits `--ambolt-...`
#' variables. The tree is **additive**: only paths the user actually set
#' produce variables; unset paths fall through to component scoped defaults.
#'
#' Recognised top-level categories:
#'   - color: { primary, primary_hover?, secondary, surface, surface_alt,
#'              text, text_muted, border, success, warning, danger, accent }
#'   - font:  { family, family_mono, size_base, scale_ratio, line_height,
#'              weight = { regular, medium, bold } }
#'   - radius: { sm, md, lg } -- also accepts arbitrary keys
#'   - space:  { unit, sm, md, lg } -- also accepts arbitrary keys
#'   - shadow: { sm, md, lg }
#'
#' Color auto-derive: when `color.primary` is set but `color.primary_hover`
#' / `_muted` / `_focus` are unset, the variants are derived at CSS runtime
#' via `color-mix(in srgb, var(--ambolt-color-primary) X%, Y)`. Same for
#' any other base color. Explicit values always win.
#'
#' Returns: a single CSS block as a character scalar (possibly empty), e.g.
#'   ":root { --ambolt-color-primary: #1a73e8; ... }
#'    body { font-family: var(--ambolt-font-family); ... }"
#' @noRd
.generate_design_tokens_block <- function(tokens) {
  if (is.null(tokens) || length(tokens) == 0) return("")
  root_vars <- character(0)
  global_rules <- character(0)

  ## ----- color -----
  color <- tokens[["color"]]
  if (is.list(color) && length(color) > 0) {
    base_color_names <- c("primary", "secondary", "surface", "surface_alt",
                          "text", "text_muted", "border", "success",
                          "warning", "danger", "accent")
    for (name in names(color)) {
      val <- color[[name]]
      if (is.null(val)) next
      css_name <- gsub("_", "-", name, fixed = TRUE)
      root_vars <- c(root_vars,
        sprintf("    --ambolt-color-%s: %s;", css_name, val))
    }
    # Auto-derive hover/muted/focus when base set but variant absent.
    for (base in base_color_names) {
      if (is.null(color[[base]])) next
      css_base <- gsub("_", "-", base, fixed = TRUE)
      for (variant in c("hover", "muted", "focus")) {
        full_key <- paste0(base, "_", variant)
        if (is.null(color[[full_key]])) {
          mix <- switch(variant,
            hover = sprintf("color-mix(in srgb, var(--ambolt-color-%s) 85%%, black)", css_base),
            muted = sprintf("color-mix(in srgb, var(--ambolt-color-%s) 30%%, white)", css_base),
            focus = sprintf("color-mix(in srgb, var(--ambolt-color-%s) 40%%, transparent)", css_base)
          )
          root_vars <- c(root_vars,
            sprintf("    --ambolt-color-%s-%s: %s;", css_base, variant, mix))
        }
      }
    }
  }

  ## ----- font -----
  font <- tokens[["font"]]
  if (is.list(font) && length(font) > 0) {
    for (name in c("family", "family_mono", "size_base", "scale_ratio", "line_height")) {
      val <- font[[name]]
      if (is.null(val)) next
      css_name <- gsub("_", "-", name, fixed = TRUE)
      root_vars <- c(root_vars,
        sprintf("    --ambolt-font-%s: %s;", css_name, val))
    }
    weight <- font[["weight"]]
    if (is.list(weight)) {
      for (wname in names(weight)) {
        if (is.null(weight[[wname]])) next
        root_vars <- c(root_vars,
          sprintf("    --ambolt-font-weight-%s: %s;",
            gsub("_", "-", wname, fixed = TRUE), weight[[wname]]))
      }
    }
    # Global body rules -- only emit when the user set a relevant token
    body_parts <- character(0)
    if (!is.null(font[["family"]]))
      body_parts <- c(body_parts, "  font-family: var(--ambolt-font-family);")
    if (!is.null(font[["size_base"]]))
      body_parts <- c(body_parts, "  font-size: var(--ambolt-font-size-base);")
    if (!is.null(font[["line_height"]]))
      body_parts <- c(body_parts, "  line-height: var(--ambolt-font-line-height);")
    if (length(body_parts) > 0) {
      global_rules <- c(global_rules,
        sprintf("\n  body {\n%s\n  -webkit-font-smoothing: antialiased;\n  }",
          paste(body_parts, collapse = "\n")))
    }
  }

  ## ----- radius / space / shadow (flat, arbitrary keys) -----
  for (cat in c("radius", "space", "shadow")) {
    entries <- tokens[[cat]]
    if (!is.list(entries) || length(entries) == 0) next
    for (name in names(entries)) {
      val <- entries[[name]]
      if (is.null(val)) next
      css_name <- gsub("_", "-", name, fixed = TRUE)
      root_vars <- c(root_vars,
        sprintf("    --ambolt-%s-%s: %s;", cat, css_name, val))
    }
  }

  ## ----- color text/surface global body cascade -----
  if (is.list(color)) {
    body_parts <- character(0)
    if (!is.null(color[["text"]]))
      body_parts <- c(body_parts, "  color: var(--ambolt-color-text);")
    if (!is.null(color[["surface"]]))
      body_parts <- c(body_parts, "  background: var(--ambolt-color-surface);")
    if (length(body_parts) > 0) {
      global_rules <- c(global_rules,
        sprintf("\n  body {\n%s\n  }", paste(body_parts, collapse = "\n")))
    }
  }

  parts <- character(0)
  if (length(root_vars) > 0)
    parts <- c(parts, sprintf("  :root {\n%s\n  }", paste(root_vars, collapse = "\n")))
  if (length(global_rules) > 0)
    parts <- c(parts, global_rules)

  paste(parts, collapse = "\n")
}

#' Generate CSS from full theme token specification
#'
#' Generates :root CSS variables from structured theme tokens (fonts, radius,
#' component overrides). Svelte components reference these variables with
#' sensible defaults, so setting variables here cascades through the UI.
#' Also generates global element rules for body/heading fonts.
#' @noRd
.generate_theme_tokens_css <- function(theme_env) {
  root_vars <- character(0)
  css_rules <- character(0)

  # Font tokens → variables + global element rules
  fonts <- theme_env$.theme_font_config
  if (!is.null(fonts) && is.list(fonts)) {
    if (!is.null(fonts[["body"]]))
      root_vars <- c(root_vars, sprintf("    --ambolt-font: %s;", fonts[["body"]]))
    if (!is.null(fonts[["heading"]]))
      root_vars <- c(root_vars, sprintf("    --ambolt-heading-font: %s;", fonts[["heading"]]))

    # Global element rules (not scoped, so these cascade properly)
    if (!is.null(fonts[["heading"]])) {
      css_rules <- c(css_rules, '
  h1, h2, h3, h4, h5, h6,
  .ambolt-page-title, .ambolt-nav-header, .card-title, .ambolt-modal-header {
    font-family: var(--ambolt-heading-font);
  }')
    }
    css_rules <- c(css_rules, '
  body {
    font-family: var(--ambolt-font, system-ui, sans-serif);
    -webkit-font-smoothing: antialiased;
  }')
  }

  # Radius tokens → variables (components use var(--ambolt-radius-*, default))
  radius <- theme_env$.theme_radius
  if (!is.null(radius) && is.list(radius)) {
    for (name in names(radius)) {
      root_vars <- c(root_vars, sprintf("    --ambolt-radius-%s: %s;", name, radius[[name]]))
    }
  }

  # Component tokens → variables (components reference these in scoped styles)
  comps <- theme_env$.theme_components
  if (!is.null(comps) && is.list(comps)) {
    # Nav sidebar
    nav <- comps[["nav"]]
    if (!is.null(nav)) {
      if (!is.null(nav[["bg"]])) root_vars <- c(root_vars, sprintf("    --ambolt-nav-bg: %s;", nav[["bg"]]))
      if (!is.null(nav[["color"]])) root_vars <- c(root_vars, sprintf("    --ambolt-nav-color: %s;", nav[["color"]]))
      if (!is.null(nav[["active_bg"]])) root_vars <- c(root_vars, sprintf("    --ambolt-nav-active-bg: %s;", nav[["active_bg"]]))
      if (!is.null(nav[["hover_bg"]])) root_vars <- c(root_vars, sprintf("    --ambolt-nav-hover-bg: %s;", nav[["hover_bg"]]))
      if (!is.null(nav[["border"]])) root_vars <- c(root_vars, sprintf("    --ambolt-nav-border: %s;", nav[["border"]]))
    }

    # Table
    tbl <- comps[["table"]]
    if (!is.null(tbl)) {
      if (!is.null(tbl[["header_bg"]])) root_vars <- c(root_vars, sprintf("    --ambolt-table-header-bg: %s;", tbl[["header_bg"]]))
      if (!is.null(tbl[["stripe_bg"]])) root_vars <- c(root_vars, sprintf("    --ambolt-table-stripe-bg: %s;", tbl[["stripe_bg"]]))
      if (!is.null(tbl[["border_color"]])) root_vars <- c(root_vars, sprintf("    --ambolt-table-border: %s;", tbl[["border_color"]]))
      if (!is.null(tbl[["hover_bg"]])) root_vars <- c(root_vars, sprintf("    --ambolt-table-hover-bg: %s;", tbl[["hover_bg"]]))
      if (!is.null(tbl[["outer_border"]])) root_vars <- c(root_vars, sprintf("    --ambolt-table-outer-border: %s;", tbl[["outer_border"]]))
      if (!is.null(tbl[["bg"]])) root_vars <- c(root_vars, sprintf("    --ambolt-table-bg: %s;", tbl[["bg"]]))
      if (!is.null(tbl[["cell_border"]])) root_vars <- c(root_vars, sprintf("    --ambolt-table-cell-border: %s;", tbl[["cell_border"]]))
      if (!is.null(tbl[["th_weight"]])) root_vars <- c(root_vars, sprintf("    --ambolt-table-th-weight: %s;", tbl[["th_weight"]]))
    }

    # Badge
    bdg <- comps[["badge"]]
    if (!is.null(bdg)) {
      if (!is.null(bdg[["bg"]])) root_vars <- c(root_vars, sprintf("    --ambolt-badge-bg: %s;", bdg[["bg"]]))
      if (!is.null(bdg[["color"]])) root_vars <- c(root_vars, sprintf("    --ambolt-badge-color: %s;", bdg[["color"]]))
      if (!is.null(bdg[["radius"]])) root_vars <- c(root_vars, sprintf("    --ambolt-badge-radius: %s;", bdg[["radius"]]))
      if (!is.null(bdg[["weight"]])) root_vars <- c(root_vars, sprintf("    --ambolt-badge-weight: %s;", bdg[["weight"]]))
    }

    # Card
    crd <- comps[["card"]]
    if (!is.null(crd)) {
      if (!is.null(crd[["border"]])) root_vars <- c(root_vars, sprintf("    --ambolt-card-border: %s;", crd[["border"]]))
    }

    # Modal
    mdl <- comps[["modal"]]
    if (!is.null(mdl)) {
      if (!is.null(mdl[["radius"]])) root_vars <- c(root_vars, sprintf("    --ambolt-modal-radius: %s;", mdl[["radius"]]))
      if (!is.null(mdl[["shadow"]])) root_vars <- c(root_vars, sprintf("    --ambolt-modal-shadow: %s;", mdl[["shadow"]]))
    }

    # Button primary
    btn <- comps[["button_primary"]]
    if (!is.null(btn)) {
      if (!is.null(btn[["bg"]])) root_vars <- c(root_vars, sprintf("    --ambolt-btn-primary-bg: %s;", btn[["bg"]]))
      if (!is.null(btn[["hover_bg"]])) root_vars <- c(root_vars, sprintf("    --ambolt-btn-primary-hover: %s;", btn[["hover_bg"]]))
    }
  }

  # Assemble: single :root block + global rules
  parts <- character(0)
  if (length(root_vars) > 0)
    parts <- c(parts, sprintf("  :root {\n%s\n  }", paste(root_vars, collapse = "\n")))
  if (length(css_rules) > 0)
    parts <- c(parts, css_rules)

  paste(parts, collapse = "\n")
}

#' Generate CSS for the pages layout grid (returns empty string if no pages)
#'
#' Only emits the top-level grid layout. Component-specific styles
#' (nav sidebar, page content) live in NavSidebar.svelte and PageRouter.svelte.
#' @noRd
.generate_pages_layout_css <- function(has_pages) {
  if (!has_pages) return("")
  '
  .ambolt-app-layout {
    min-height: 100vh;
    margin-left: 220px;
  }
  @media (max-width: 768px) {
    .ambolt-app-layout {
      margin-left: 0;
      padding-top: 3rem;
    }
  }
  @media (max-width: 480px) {
    .ambolt-app-layout {
      padding-top: 2.5rem;
    }
  }'
}

#' Generate CSS for empty state (returns empty string if no empty state)
#' @noRd
.generate_empty_state_css <- function(empty_state) {
  if (is.null(empty_state)) return("")
  '
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    padding: 3rem 1rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    background: white;
    color: #6b7280;
  }
  .empty-state h2 {
    color: #374151;
    margin: 0 0 0.5rem;
  }
  .empty-state p {
    margin: 0;
    font-size: 1.1rem;
  }
  .scenario-buttons {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-top: 1.5rem;
    justify-content: center;
  }
  .scenario-button {
    font-size: 0.9rem;
    padding: 0.4rem 0.8rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    background: white;
    color: #374151;
    cursor: pointer;
    transition: background 0.15s;
  }
  .scenario-button:hover {
    background: #f3f4f6;
  }'
}

#' Generate CSS for help tooltips (returns empty string if no inputs have help)
#' @noRd
.generate_tooltip_css <- function(inputs) {
  has_help <- any(vapply(inputs, function(i) !is.null(i[["args"]][["help"]]), logical(1)))
  if (!has_help) return("")
  '
  .input-with-help {
    position: relative;
  }
  .help-tooltip {
    position: relative;
  }
  .input-with-help > .help-tooltip {
    position: absolute;
    top: 0;
    right: 0;
  }
  /* Help icon positioning is handled by default (absolute, top-right) */
  .help-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 1.2rem;
    height: 1.2rem;
    font-size: 0.85rem;
    color: #9ca3af;
    cursor: help;
    vertical-align: middle;
  }
  .help-text {
    display: none;
    position: absolute;
    right: 0;
    top: 1.5rem;
    width: 220px;
    padding: 0.5rem 0.7rem;
    background: #1f2937;
    color: white;
    font-size: 0.8rem;
    line-height: 1.4;
    border-radius: 6px;
    z-index: 10;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  }
  .help-tooltip:hover .help-text {
    display: block;
  }'
}

#' Generate CSS for sections (returns empty string if no sections used)
#' @noRd
.generate_section_css <- function(has_sections) {
  if (!has_sections) return("")
  '
  .section {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid #e5e7eb;
  }
  .section-label {
    font-size: 0.9rem;
    font-weight: 600;
    color: #374151;
    margin: 0 0 0.75rem;
  }
  /* Toggle section header: checkbox + label + help icon in one row */
  .section-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding-bottom: 0.75rem;
    margin-bottom: 0.75rem;
    border-bottom: 1px solid #e5e7eb;
  }
  .section-toggle {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    font-weight: 600;
    color: #374151;
    cursor: pointer;
    flex: 1;
    margin: 0;
  }
  .section-toggle input[type="checkbox"] {
    width: 1.1rem;
    height: 1.1rem;
    cursor: pointer;
  }
  .section-help {
    margin-left: auto;
  }
  /* Dimmed body when toggle is off */
  .section-dimmed {
    opacity: 0.5;
    pointer-events: none;
  }
  /* Compact section: right-aligned table-like layout (matches EK assumptions) */
  .section-compact {
    display: flex;
    flex-direction: column;
    gap: var(--ambolt-compact-gap, 12px);
  }
  /* Each input component becomes an inline row: label ... [input][unit] */
  .section-compact :global([data-input-id]) {
    display: flex !important;
    align-items: center;
    gap: 8px;
    margin-bottom: 0 !important;
    font-size: var(--ambolt-compact-font-size, 12px);
  }
  /* input-with-help wrapper: also flex, component fills remaining space */
  .section-compact > :global(.input-with-help) {
    display: flex !important;
    align-items: center;
    gap: 4px;
    margin-bottom: 0 !important;
  }
  .section-compact > :global(.input-with-help) > :global([data-input-id]) {
    flex: 1;
    min-width: 0;
  }
  .section-compact :global(label) {
    flex: 1 !important;
    /* min-width: 0 lets the label shrink below its nowrap content size
       when the column is narrower than label + fixed-width input would
       otherwise need. Without it, long labels (e.g. multi-word Swedish
       question text) push the row past the column edge. The overflow /
       ellipsis pair degrades a too-long label to a truncated one-liner
       rather than overflowing the parent. */
    min-width: 0 !important;
    overflow: hidden !important;
    text-overflow: ellipsis !important;
    text-align: right !important;
    white-space: nowrap !important;
    margin-bottom: 0 !important;
    font-size: var(--ambolt-compact-font-size, 12px) !important;
    font-weight: 400 !important;
  }
  .section-compact :global(input[type="number"]),
  .section-compact :global(input[type="text"]) {
    width: var(--ambolt-compact-input-width, 70px) !important;
    height: var(--ambolt-compact-row-height, 20px) !important;
    /* Cancel the framework-wide --ambolt-input-min-height baseline so
       compact mode stays at the explicit row height (the global default
       would otherwise pin all inputs/selects to 2.5rem). */
    min-height: 0 !important;
    padding: 0 4px !important;
    font-size: var(--ambolt-compact-font-size, 12px) !important;
    border-radius: 4px !important;
    flex: 0 0 var(--ambolt-compact-input-width, 70px) !important;
  }
  .section-compact :global(select) {
    width: var(--ambolt-compact-select-width, 140px) !important;
    height: var(--ambolt-compact-row-height, 20px) !important;
    min-height: 0 !important;
    padding: 0 14px 0 4px !important;
    font-size: var(--ambolt-compact-font-size, 12px) !important;
    border-radius: 4px !important;
    flex: 0 0 auto !important;
  }
  .section-compact :global(.unit) {
    height: var(--ambolt-compact-row-height, 20px) !important;
    font-size: var(--ambolt-compact-font-size, 12px) !important;
    padding: 0 4px !important;
    line-height: var(--ambolt-compact-row-height, 20px) !important;
    border-radius: 0 4px 4px 0 !important;
    width: var(--ambolt-compact-input-width, 70px) !important;
    flex: 0 0 var(--ambolt-compact-input-width, 70px) !important;
  }
  .section-compact :global(.ambolt-numeric-with-unit) :global(input) {
    border-radius: 4px 0 0 4px !important;
  }
  .section-compact :global(.input-row) {
    flex: 0 0 auto !important;
    display: flex !important;
    gap: 0 !important;
  }
  /* Help tooltip in compact body: stays in flow, not absolutely positioned.
     Scoped to section-body to avoid affecting section-header tooltips. */
  .section-compact :global(.section-body) :global(.help-tooltip) {
    position: static !important;
    flex: 0 0 auto;
  }'
}

#' Generate CSS for columns layout
#' @noRd
.generate_columns_css <- function(has_columns) {
  if (!has_columns) return("")
  '
  .ambolt-columns {
    display: flex;
    gap: var(--ambolt-columns-gap, 1rem);
    width: 100%;
    align-items: stretch;
  }
  .ambolt-columns > * {
    flex: 1;
    min-width: 0;
  }
  /* Stack inner columns vertically while the sidebar is still visible
     (768-1024 zone) — gives compact secondary panels enough room to
     render their fixed-width inputs without overflowing the iframe. */
  @media (max-width: 1024px) {
    .ambolt-columns { flex-direction: column; }
  }'
}

#' Generate CSS for page header (pages-mode declarative layout)
#' @noRd
.generate_page_header_css <- function(has_page_header) {
  if (!has_page_header) return("")
  '
  .ambolt-page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }
  .ambolt-page-title {
    margin: 0;
    font-size: 1.5rem;
    font-weight: 700;
    color: #111827;
  }
  .ambolt-page-subtitle {
    margin: 0.25rem 0 0;
    color: #6b7280;
    font-size: 0.95rem;
  }
  .ambolt-page-actions {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }
  .ambolt-logout-btn {
    padding: 0.4rem 0.8rem;
    background: none;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.85rem;
    color: #374151;
  }
  .ambolt-logout-btn:hover {
    background: #f3f4f6;
  }
  .ambolt-action-btn {
    padding: 0.4rem 0.8rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.85rem;
    color: #374151;
    background: white;
    box-sizing: border-box;
    line-height: 1.2;
    vertical-align: middle;
  }
  .ambolt-action-btn:hover {
    background: #f3f4f6;
  }
  .ambolt-action-btn-primary {
    background: var(--ambolt-btn-primary-bg, var(--ambolt-primary, #4f46e5));
    color: white;
    border-color: var(--ambolt-btn-primary-bg, var(--ambolt-primary, #4f46e5));
  }
  .ambolt-action-btn-primary:hover {
    background: var(--ambolt-btn-primary-hover, var(--ambolt-primary-hover, #4338ca));
    border-color: var(--ambolt-btn-primary-hover, var(--ambolt-primary-hover, #4338ca));
  }
  @media (max-width: 768px) {
    .ambolt-page-header {
      padding-left: 2.5rem;
    }
  }
  .ambolt-page-help {
    display: inline-flex;
    align-items: center;
    margin-left: 0.3rem;
    vertical-align: baseline;
  }
  @media (max-width: 480px) {
    .ambolt-page-header {
      flex-wrap: wrap;
      gap: 0.3rem;
      padding-left: 2.5rem;
    }
    .ambolt-page-header-title {
      flex: 1 1 100%;
      min-width: 0;
    }
    .ambolt-page-title { font-size: 1.2rem; }
    .ambolt-page-subtitle { font-size: 0.8rem; }
    .ambolt-page-actions {
      flex-wrap: wrap;
      gap: 0.3rem;
    }
    .ambolt-action-btn {
      font-size: 0.8rem;
      padding: 0.3rem 0.5rem;
    }
  }'
}

#' Generate CSS for page content container (pages-mode)
#' @noRd
.generate_page_content_css <- function(has_page_content) {
  if (!has_page_content) return("")
  '
  .ambolt-page-content {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }'
}

#' Generate CSS for table filter bar
#' @noRd
.generate_filter_bar_css <- function(has_filters) {
  if (!has_filters) return("")
  '
  .ambolt-filter-bar {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    align-items: stretch;
    margin-bottom: 0.75rem;
  }
  .filter-chip {
    position: relative;
  }
  .filter-chip-button {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    padding: 4px 8px;
    border: none;
    background: none;
    border-radius: 4px;
    cursor: pointer;
    transition: background 0.15s;
  }
  .filter-chip-button:hover {
    background: rgba(0,0,0,0.04);
  }
  .filter-chip-label {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--ambolt-primary, #006589);
  }
  .filter-chip-value {
    font-size: 0.85rem;
    color: #888;
  }
  .filter-chip-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    z-index: 100;
    min-width: 160px;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    padding: 0.25rem 0;
    margin-top: 2px;
  }
  .filter-chip-item {
    display: block;
    width: 100%;
    text-align: left;
    padding: 0.35rem 0.75rem;
    border: none;
    background: none;
    font-size: 0.85rem;
    color: #374151;
    cursor: pointer;
  }
  .filter-chip-item:hover {
    background: #f3f4f6;
  }
  .filter-chip-item.active {
    background: var(--ambolt-primary, #006589);
    color: white;
  }
  @media (max-width: 650px) {
    .ambolt-filter-bar { gap: 0.25rem; }
    .filter-chip-button { padding: 2px 4px; }
  }
  @media (max-width: 480px) {
    .filter-chip-dropdown {
      min-width: 140px;
      max-width: calc(100vw - 2rem);
    }
  }'
}

#' Generate CSS for details (collapsible) sections
#' @noRd
.generate_details_css <- function(has_details) {
  if (!has_details) return("")
  '
  .ambolt-details {
    margin-top: 1rem;
    width: 100%;
  }
  .ambolt-details summary {
    cursor: pointer;
    font-weight: 600;
    font-size: 0.95rem;
    color: #374151;
    padding: 0.5rem 0;
    list-style: none;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .ambolt-details summary::before {
    content: "\\25B6";
    font-size: 0.7rem;
    transition: transform 0.2s;
  }
  .ambolt-details[open] summary::before {
    transform: rotate(90deg);
  }
  .ambolt-details summary::-webkit-details-marker {
    display: none;
  }
  .ambolt-details-content {
    padding: 1rem 0;
  }'
}
