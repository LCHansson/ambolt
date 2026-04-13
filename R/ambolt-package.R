#' ambolt: Web Applications with R and Svelte
#'
#' Build reactive web applications using R for the backend and Svelte 5 for
#' the frontend. ambolt provides a declarative DSL for layouts, inputs,
#' outputs, modals, authentication, and themes; the framework generates
#' Svelte components from the R declarations and serves them via ambiorix.
#'
#' @section Getting started:
#'
#' Create an app with [create_app()], declare layout with the DSL primitives
#' ([page_header()], [section()], [columns()], [view_switcher()],
#' [stat_cards()], [data_table()], [html_block()], ...), and run it:
#'
#' \preformatted{
#' library(ambolt)
#'
#' app <- create_app(port = 3000L)
#' app$page("home", title = "Home", ui = page_content(
#'   page_header(title = "Hello, ambolt"),
#'   section("A friendly framework for R + Svelte apps")
#' ))
#' app$run()
#' }
#'
#' @section Key concepts:
#'
#' \itemize{
#'   \item \strong{Layout DSL} — composable list-based primitives that
#'     describe the UI tree. The codegen walks the tree at build time
#'     for pages and at request time for modals
#'     (via the runtime tree walker in \code{inst/svelte/components/RenderNode.svelte}).
#'   \item \strong{Modules} — group related routes, outputs, and modals
#'     under a namespace via \code{app$module()}.
#'   \item \strong{Auth} — pluggable session-cookie-based authentication
#'     via \code{app$auth()}, with rate limiting and CORS tightening.
#'   \item \strong{Theming} — three-tier styling: design tokens via
#'     \code{app$theme()}, semantic component props, and per-instance
#'     class/style escape hatches.
#' }
#'
#' @section Production example:
#'
#' \href{https://elektrifieringskollen.se}{Elektrifieringskollen} is a
#' production fleet electrification calculator built with ambolt.
#'
#' @section More information:
#'
#' \itemize{
#'   \item Vignettes: \code{vignette("getting-started", package = "ambolt")} and
#'     \code{vignette("multi-page-with-auth", package = "ambolt")}
#'   \item GitHub: \url{https://github.com/LCHansson/ambolt}
#'   \item Issues: \url{https://github.com/LCHansson/ambolt/issues}
#' }
#'
#' @importFrom grDevices dev.off
#' @importFrom utils modifyList
#' @keywords internal
"_PACKAGE"
