#' Run a bundled ambolt example
#'
#' Discovers example apps shipped in `inst/examples/` and lets you launch
#' or just construct them. Each example is a self-contained `app.R` that
#' returns an ambolt app object (does not call `app$run()` itself when
#' `run = FALSE`, so it can be inspected).
#'
#' Pattern after Shiny's `shiny::runExample`. See `ambolt::list_examples()`
#' for the catalogue.
#'
#' If an example ships a `NOTES.md` next to its `app.R`, the contents
#' are printed to the console at startup. The auth-multipage example
#' uses this to surface its login credentials (user `demo`, password
#' `demo`) before the browser opens.
#'
#' @param name Character. The example slug (e.g. `"01-hello"`). Use
#'   `list_examples()` to see options.
#' @param port Integer. Port to listen on. Default 3000.
#' @param run Logical. When TRUE (default), call `app$run()` and block on
#'   the running server. When FALSE, return the app object so tests can
#'   inspect it without actually serving.
#' @return When `run = FALSE`, the ambolt app object. When `run = TRUE`,
#'   nothing visible (the call blocks until the server exits).
#' @export
#' @examples
#' \dontrun{
#' run_example("01-hello")
#' app <- run_example("01-hello", run = FALSE)
#' }
run_example <- function(name, port = 3000L, run = TRUE) {
  examples <- list_examples()
  if (!name %in% examples) {
    stop(sprintf(
      "Unknown example: %s\nAvailable: %s",
      name, paste(examples, collapse = ", ")), call. = FALSE)
  }
  example_dir <- system.file("examples", name, package = "ambolt")
  if (!nzchar(example_dir)) {
    # Development fallback: relative path during pkgload::load_all
    example_dir <- file.path("inst", "examples", name)
    if (!dir.exists(example_dir)) {
      stop(sprintf("Example directory not found: %s", name), call. = FALSE)
    }
  }
  app_file <- file.path(example_dir, "app.R")
  if (!file.exists(app_file)) {
    stop(sprintf("Example %s is missing app.R at %s", name, app_file), call. = FALSE)
  }

  # Each example exposes a function `build_app(port)` so we can construct
  # without launching. Source in a fresh environment to isolate vars.
  env <- new.env(parent = globalenv())
  source(app_file, local = env, chdir = TRUE)
  if (!is.function(env$build_app)) {
    stop(sprintf("Example %s/app.R must define build_app(port).", name),
         call. = FALSE)
  }
  app <- env$build_app(port = port)
  if (run) {
    .print_example_banner(name, example_dir, port)
    app$run()
    invisible(NULL)
  } else {
    invisible(app)
  }
}

#' Print a startup banner for a running example.
#'
#' Includes the slug, port, and the contents of `NOTES.md` if the example
#' provides one. Examples that need credentials (e.g. 05-auth-multipage)
#' put them in `NOTES.md` so the developer sees them before the browser
#' opens. Uses `message()` so the banner respects `suppressMessages()`.
#' @noRd
.print_example_banner <- function(name, example_dir, port) {
  banner <- c(
    "",
    strrep("-", 60),
    sprintf("ambolt example: %s", name),
    sprintf("URL: http://localhost:%d", port)
  )
  notes_file <- file.path(example_dir, "NOTES.md")
  if (file.exists(notes_file)) {
    banner <- c(banner, "", readLines(notes_file, warn = FALSE))
  }
  banner <- c(banner, strrep("-", 60), "")
  message(paste(banner, collapse = "\n"))
}

#' List bundled ambolt example slugs.
#'
#' Reads `inst/examples/` and returns the directory names. Filters to
#' entries that contain an `app.R` so partially-built examples don't show.
#' @return Character vector of example slugs, sorted.
#' @export
list_examples <- function() {
  ex_root <- system.file("examples", package = "ambolt")
  if (!nzchar(ex_root)) {
    # Development fallback
    ex_root <- file.path("inst", "examples")
    if (!dir.exists(ex_root)) return(character(0))
  }
  dirs <- list.dirs(ex_root, recursive = FALSE, full.names = TRUE)
  ok <- vapply(dirs, function(d) file.exists(file.path(d, "app.R")), logical(1))
  sort(basename(dirs[ok]))
}
