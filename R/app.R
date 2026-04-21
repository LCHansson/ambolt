# --- ambolt entry point ----------------------------------------
#
# Exports create_app() — the user-facing API for declaring inputs,
# outputs, layouts, and running the application.
#
# When loaded as a package (library(ambolt)), all R/*.R files are
# sourced automatically. When used via source("R/app.R") during
# development, the source chain below loads sibling modules.

# Source sibling modules when NOT loaded as a package
if (!isNamespace(environment())) {
  local({
    src_dir <- NULL
    for (i in seq_len(sys.nframe())) {
      env <- sys.frame(i)
      if (!is.null(env$ofile)) {
        src_dir <- normalizePath(dirname(env$ofile), mustWork = FALSE)
      }
    }
    if (is.null(src_dir)) {
      args <- commandArgs(trailingOnly = FALSE)
      file_arg <- grep("^--file=", args, value = TRUE)
      if (length(file_arg) > 0) {
        src_dir <- normalizePath(dirname(sub("^--file=", "", file_arg[1])), mustWork = FALSE)
      }
    }
    if (is.null(src_dir)) src_dir <- "R"
    for (f in c("utils.R", "codegen_script.R", "codegen_markup.R", "codegen_css.R",
                "codegen_tree.R", "codegen_layout.R", "layout_dsl.R", "build.R",
                "auth.R", "html_helpers.R")) {
      source(file.path(src_dir, f), local = FALSE)
    }
  })
}

# --- App constructor ----------------------------------------------

#' Create a new ambolt application
#'
#' Initializes an application object that wraps ambiorix with
#' framework conventions: CORS middleware, JSON/SVG response helpers,
#' and a consistent endpoint registration pattern.
#'
#' Supports two modes:
#' 1. Stage 1 (explicit): use data_endpoint/plot_endpoint + write your own Svelte
#' 2. Stage 2 (orchestrated): use input/output + app generates everything
#'
#' @param port Integer. Port for the R API server. Default 3000.
#' @param host Character. Host address. Default "127.0.0.1".
#' @return An ambolt app object (an environment with registration methods).
#' @export
#' @examples
#' \dontrun{
#' library(ambolt)
#'
#' app <- create_app(port = 3000L)
#' app$page("home", title = "Home", ui = page_content(
#'   page_header(title = "Hello, ambolt!")
#' ))
#' app$run()
#' }
create_app <- function(
  port = as.integer(Sys.getenv("AMBOLT_PORT", "3000")),
  host = Sys.getenv("AMBOLT_HOST", "127.0.0.1")
) {
  app_env <- new.env(parent = emptyenv())

  # The underlying ambiorix instance
  app_env$.app <- ambiorix::Ambiorix$new(port = port, host = host)
  app_env$.port <- port
  app_env$.host <- host

  # Storage for Stage 2 declarations
  app_env$.inputs <- list()
  app_env$.outputs <- list()
  app_env$.layout <- NULL
  app_env$.empty_state <- NULL
  app_env$.scenarios <- list()
  app_env$.theme_css <- NULL
  app_env$.init_script <- NULL
  app_env$.sections <- list()
  app_env$.meta <- list(title = "ambolt app", lang = "en")
  app_env$.ui_tree <- NULL
  app_env$.pages <- NULL
  app_env$.on_stop_hooks <- list()
  app_env$.auth <- NULL
  app_env$.admin_links <- list()
  app_env$.modals <- list()
  app_env$.modules <- list()
  app_env$.module_outputs <- list()

  # Shared app context — available as req$context in handlers
  app_env$context <- new.env(parent = emptyenv())

  # Register default CORS middleware (permissive — overridden by auth if configured)
  app_env$.app$use(function(req, res) {
    # Auth mode installs its own CORS (same-origin + credentials).
    # Skip this permissive middleware when auth is active.
    if (!is.null(app_env$.auth)) return(NULL)
    res$header("Access-Control-Allow-Origin", "*")
    res$header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    res$header("Access-Control-Allow-Headers", "Content-Type")
    NULL
  })

  # Inject app context into every request
  app_env$.app$use(function(req, res) {
    req$context <- app_env$context
    NULL
  })

  # --- Stage 1 API (explicit endpoints) --------------------------

  # Register a data endpoint (returns JSON)
  app_env$data_endpoint <- function(path, handler) {
    app_env$.app$get(path, function(req, res) {
      params <- as.list(req$query)
      result <- handler(params)
      res$json(result)
    })
    invisible(app_env)
  }

  # Register a plot endpoint (returns SVG)
  app_env$plot_endpoint <- function(path, handler, width = 7, height = 5) {
    app_env$.app$get(path, function(req, res) {
      params <- as.list(req$query)
      plot_obj <- handler(params)

      svg_string <- svglite::svgstring(width = width, height = height)
      print(plot_obj)
      svg_output <- svg_string()
      dev.off()

      # Force to a plain character string — svgstring() returns an
      # htmltools::HTML object which some serializers handle differently
      svg_text <- paste0(as.character(svg_output), collapse = "")

      res$header("Content-Type", "image/svg+xml")
      res$send(svg_text)
    })
    invisible(app_env)
  }

  # --- HTTP verb endpoints --------------------------------------

  # Register a GET endpoint (raw handler, no JSON wrapping)
  app_env$get <- function(path, handler) {
    app_env$.app$get(path, handler)
    invisible(app_env)
  }

  # Register a POST endpoint
  #
  # JSON request bodies are automatically parsed and available as req$body.
  app_env$post <- function(path, handler) {
    app_env$.app$post(path, function(req, res) {
      if (!is.null(req$CONTENT_TYPE) &&
          grepl("application/json", req$CONTENT_TYPE, fixed = TRUE)) {
        req$body <- ambiorix::parse_json(req)
      }
      handler(req, res)
    })
    invisible(app_env)
  }

  # Register a PUT endpoint
  #
  # JSON request bodies are automatically parsed and available as req$body.
  app_env$put <- function(path, handler) {
    app_env$.app$put(path, function(req, res) {
      if (!is.null(req$CONTENT_TYPE) &&
          grepl("application/json", req$CONTENT_TYPE, fixed = TRUE)) {
        req$body <- ambiorix::parse_json(req)
      }
      handler(req, res)
    })
    invisible(app_env)
  }

  # Register a DELETE endpoint
  app_env$delete <- function(path, handler) {
    app_env$.app$delete(path, handler)
    invisible(app_env)
  }

  # --- Middleware ----------------------------------------------

  # Register custom middleware
  #
  # Middleware runs on every request before route handlers.
  # Return NULL to continue to next handler; return a response to short-circuit.
  app_env$use <- function(handler) {
    app_env$.app$use(handler)
    invisible(app_env)
  }

  # --- Lifecycle hooks ----------------------------------------

  # Register a shutdown hook
  #
  # Called when the app stops (e.g., for closing DB connections).
  app_env$on_stop <- function(handler) {
    app_env$.on_stop_hooks <- c(app_env$.on_stop_hooks, list(handler))
    invisible(app_env)
  }

  # Register admin sidebar links (shown to admin users with live count badges).
  # @param ... Lists with: endpoint, icon, label, modal, modalSize, refreshEvent
  app_env$admin_links <- function(...) {
    app_env$.admin_links <- list(...)
    invisible(app_env)
  }

  # --- Multi-page navigation ---------------------------------

  # Declare app pages (multi-page navigation mode)
  #
  # Creates a nav sidebar with icon-based links and a page router.
  # Each page gets a full-width content area. Individual pages can
  # use sidebar_layout() internally if needed.
  #
  # @param ... Lists with id, label, icon (Bootstrap Icons name), and
  #   optionally html (raw HTML/Svelte content for the page body).
  #   Each list defines one page: list(id = "contacts", label = "Kontakter", icon = "people")
  app_env$pages <- function(...) {
    page_defs <- list(...)
    # Validate each page definition
    for (p in page_defs) {
      stopifnot(!is.null(p$id), !is.null(p$label))
    }
    app_env$.pages <- page_defs
    invisible(app_env)
  }

  # --- Authentication ------------------------------------------

  # Configure authentication
  #
  # Installs auth middleware, login/logout/session endpoints, rate limiting,
  # and CORS tightening. The framework handles cookies (HttpOnly), login UI,
  # and route protection. The developer provides verify and login functions.
  #
  # @param verify function(token, db) — return user data (list) or NULL.
  # @param login function(username, password, db) — return list(token, user) or NULL.
  # @param logout function(token, db) — optional cleanup on logout.
  # @param login_title Character. Title on login page.
  # @param exclude Character vector. Paths that skip auth.
  # @param cookie_name Character. Cookie name.
  # @param cookie_days Integer. Cookie expiration in days.
  # @param max_attempts Integer. Failed login attempts before lockout.
  # @param lockout_seconds Integer. Lockout duration after max_attempts.
  app_env$auth <- function(verify, login, logout = NULL,
                           login_title = NULL,
                           exclude = c("/api/auth/login"),
                           cookie_name = "ambolt_auth",
                           cookie_days = 30L,
                           max_attempts = 5L,
                           lockout_seconds = 60L) {
    app_env$.auth <- list(
      verify = verify,
      login = login,
      logout = logout,
      login_title = login_title,
      exclude = exclude,
      cookie_name = cookie_name,
      cookie_days = cookie_days,
      max_attempts = max_attempts,
      lockout_seconds = lockout_seconds
    )
    invisible(app_env)
  }

  # --- Modal dialogs ------------------------------------------

  # Register a server-rendered modal
  #
  # Creates a GET endpoint at /api/modal/{id} that returns
  # { title, html } JSON. The frontend modal system fetches
  # this when a data-modal link is clicked.
  #
  # @param id Character. Modal identifier (used in data-modal attributes).
  # @param render Function. function(params) returning list(title, html).
  # @param size Character. "sm", "md", "lg", "xl".
  app_env$modal <- function(id, render, size = "md") {
    app_env$.modals[[id]] <- list(id = id, render = render, size = size)
    invisible(app_env)
  }

  # --- Modules ------------------------------------------------

  # Create a namespaced module
  #
  # Groups related endpoints under a common prefix. The module
  # function receives a `mod` object with the same HTTP verb methods
  # as the app, but paths are auto-prefixed with /api/{id}.
  #
  # @param id Character. Module identifier (becomes URL prefix).
  # @param fn Function. function(mod, app) that registers endpoints.
  app_env$module <- function(id, fn) {
    # Create mod object with prefixed HTTP methods
    mod <- new.env(parent = emptyenv())
    prefix <- sprintf("/api/%s", id)

    # Helper: combine prefix + path, normalizing trailing slashes
    make_path <- function(path) {
      full <- paste0(prefix, path)
      # Remove trailing slash (but keep "/" as-is for root)
      if (nchar(full) > 1) full <- sub("/$", "", full)
      full
    }

    mod$get <- function(path, handler) {
      app_env$.app$get(make_path(path), handler)
      invisible(mod)
    }

    mod$post <- function(path, handler) {
      app_env$.app$post(make_path(path), function(req, res) {
        if (!is.null(req$CONTENT_TYPE) &&
            grepl("application/json", req$CONTENT_TYPE, fixed = TRUE)) {
          req$body <- ambiorix::parse_json(req)
        }
        handler(req, res)
      })
      invisible(mod)
    }

    mod$put <- function(path, handler) {
      app_env$.app$put(make_path(path), function(req, res) {
        if (!is.null(req$CONTENT_TYPE) &&
            grepl("application/json", req$CONTENT_TYPE, fixed = TRUE)) {
          req$body <- ambiorix::parse_json(req)
        }
        handler(req, res)
      })
      invisible(mod)
    }

    mod$delete <- function(path, handler) {
      app_env$.app$delete(make_path(path), handler)
      invisible(mod)
    }

    mod$modal <- function(modal_id, render, size = "md") {
      full_id <- sprintf("%s/%s", id, modal_id)
      app_env$.modals[[full_id]] <- list(id = full_id, render = render, size = size)
      invisible(mod)
    }

    # Declare a module output (rendered by the framework in page UI trees)
    #
    # @param output_id Character. Output identifier (unique within module).
    # @param type Character. One of: "table", "stats", "html", "plot".
    # @param ... Additional output configuration (endpoint, columns, cards, etc.)
    mod$output <- function(output_id, type, ...) {
      full_id <- sprintf("%s/%s", id, output_id)
      args <- list(...)
      app_env$.module_outputs[[full_id]] <- c(
        list(id = full_id, module_id = id, output_id = output_id, type = type),
        args
      )
      invisible(mod)
    }

    # Execute the module function
    fn(mod, app_env)

    # Store module metadata
    app_env$.modules[[id]] <- list(id = id)
    invisible(app_env)
  }

  # --- Stage 2 API (declarative inputs/outputs) -----------------

  # Declare an input
  #
  # @param id Character. Unique identifier for this input.
  # @param type Character. One of: "select", "text", "textarea", "numeric",
  #   "numeric_with_unit", "slider", "checkbox", "checkbox_group", "radio",
  #   "date", "date_range", "action".
  # @param ... Additional arguments passed to the component (label, choices,
  #   min, max, step, value, unit, variant, etc.)
  app_env$input <- function(id, type, ...) {
    args <- list(...)
    app_env$.inputs[[id]] <- list(id = id, type = type, args = args)
    invisible(app_env)
  }

  # Declare an output
  #
  # @param id Character. Unique identifier for this output.
  # @param type Character. One of: "plot", "table", "html".
  # @param render Function. Receives a named list of current input values,
  #   returns the output (ggplot object for "plot", data.frame for "table").
  # @param depends_on Character vector. Input ids that this output depends on.
  # @param trigger Character. Optional input id (action button) that gates
  #   when this output fetches. If set, the output only renders when the
  #   trigger fires, not on every input change.
  app_env$output <- function(id, type, render, depends_on = NULL, trigger = NULL) {
    # If depends_on not specified, assume it depends on all inputs
    if (is.null(depends_on)) {
      depends_on <- names(app_env$.inputs)
    }
    app_env$.outputs[[id]] <- list(
      id = id, type = type, render = render,
      depends_on = depends_on, trigger = trigger
    )
    invisible(app_env)
  }

  # Set the layout
  #
  # @param ... Layout specification. Currently supports:
  #   "sidebar" — inputs on left, outputs on right (default)
  #   list(type = "tabs", tabs = list(list(id=, label=, outputs=), ...))
  app_env$layout <- function(...) {
    args <- list(...)
    if (length(args) == 1 && is.character(args[[1]])) {
      app_env$.layout <- list(type = args[[1]])
    } else {
      app_env$.layout <- args[[1]]
    }
    invisible(app_env)
  }

  # Define the UI layout using the layout DSL
  #
  # Accepts a layout tree built from composable layout functions:
  # sidebar_layout(), sidebar(), main(), section(), columns().
  # When set, overrides the implicit layout (all inputs → sidebar,
  # all outputs → content).
  #
  # @param tree A layout tree (e.g., sidebar_layout(sidebar(...), main(...))).
  app_env$ui <- function(tree) {
    app_env$.ui_tree <- tree
    invisible(app_env)
  }

  # Set the empty state content
  #
  # Shown in the content area before any trigger-gated outputs have fired.
  # Hidden once the trigger (e.g., action button) is activated.
  #
  # @param title Character. Main heading.
  # @param subtitle Character. Subheading text (optional).
  # @param image Character. Path to an image shown above the title (optional).
  #   Resolved relative to the working directory. Copied to the build output.
  app_env$empty_state <- function(title, subtitle = NULL, image = NULL) {
    resolved_image <- NULL
    if (!is.null(image) && file.exists(image)) {
      resolved_image <- normalizePath(image, mustWork = FALSE)
    }
    app_env$.empty_state <- list(title = title, subtitle = subtitle,
                                  image = basename(image %||% ""),
                                  image_path = resolved_image)
    invisible(app_env)
  }

  # Register a predefined scenario (input preset)
  #
  # Generates a button that, when clicked, sets all specified input
  # values at once. Scenarios appear in the empty state area.
  #
  # @param label Character. Button label (e.g., "Dagligvaror glesbygd").
  # @param values Named list. Input id → value pairs to set.
  app_env$scenario <- function(label, values) {
    app_env$.scenarios <- c(app_env$.scenarios, list(
      list(label = label, values = values)
    ))
    invisible(app_env)
  }

  # Declare a section (input group with visibility rules)
  #
  # Groups inputs together and controls their visibility as a unit.
  # Inputs must be declared via app$input() before being referenced here.
  #
  # @param id Character. Unique identifier for this section.
  # @param inputs Character vector. Input ids that belong to this section.
  # @param label Character. Optional heading displayed above the group.
  # @param show_after Character. Optional trigger id — section is hidden
  #   until this action button has been clicked.
  # @param show_when List. Optional input-driven visibility (same as input show_when).
  app_env$section <- function(id, inputs, label = NULL, show_after = NULL, show_when = NULL) {
    app_env$.sections[[id]] <- list(
      id = id, inputs = inputs, label = label,
      show_after = show_after, show_when = show_when
    )
    invisible(app_env)
  }

  # Set page metadata
  #
  # Controls the HTML document title, language, and favicon.
  #
  # @param title Character. Page title shown in browser tab.
  # @param lang Character. HTML lang attribute (e.g., "sv", "en").
  # @param favicon Character. Path or URL to favicon image.
  app_env$meta <- function(title = NULL, lang = NULL, favicon = NULL) {
    if (!is.null(title)) app_env$.meta$title <- title
    if (!is.null(lang)) app_env$.meta$lang <- lang
    if (!is.null(favicon)) app_env$.meta$favicon <- favicon
    invisible(app_env)
  }

  # Set custom CSS theme
  #
  # Injects custom CSS into the generated Svelte app. Use this to override
  # framework styles, set CSS variables, or apply a complete design system.
  #
  # @param css Character. Raw CSS string to inject.
  # @param css_file Character. Path to a .css file (resolved relative to
  #   the calling script's directory). Loaded and prepended before any
  #   inline `css` string, so both can be used together.
  # @param fonts Character vector. Google Fonts URLs to load via <link> tags.
  app_env$theme <- function(css = NULL, css_file = NULL, fonts = NULL, colors = NULL,
                            radius = NULL, components = NULL) {
    if (!is.null(colors)) app_env$.theme_colors <- colors
    if (!is.null(radius)) app_env$.theme_radius <- radius
    if (!is.null(components)) app_env$.theme_components <- components
    if (!is.null(css_file)) {
      # Resolve relative to calling script's directory
      caller_dir <- NULL
      for (i in seq_len(sys.nframe())) {
        env <- sys.frame(i)
        if (!is.null(env$ofile)) {
          caller_dir <- normalizePath(dirname(env$ofile), mustWork = FALSE)
          break
        }
      }
      if (is.null(caller_dir)) caller_dir <- getwd()
      # If css_file is already absolute, use it directly
      if (grepl("^(/|[A-Za-z]:)", css_file)) {
        resolved <- normalizePath(css_file, mustWork = FALSE)
      } else {
        resolved <- normalizePath(file.path(caller_dir, css_file), mustWork = FALSE)
      }
      if (!file.exists(resolved)) {
        stop(sprintf("css_file not found: %s (resolved to %s)", css_file, resolved))
      }
      app_env$.theme_css <- paste(readLines(resolved, warn = FALSE), collapse = "\n")
    }
    if (!is.null(css)) {
      app_env$.theme_css <- paste0(app_env$.theme_css %||% "", "\n", css)
    }
    if (!is.null(fonts)) {
      if (is.list(fonts) && !is.null(fonts$urls)) {
        # New structured format: list(body = "...", heading = "...", urls = c("..."))
        app_env$.theme_fonts <- fonts$urls
        app_env$.theme_font_config <- fonts
      } else {
        # Legacy: character vector of font URLs
        app_env$.theme_fonts <- fonts
      }
    }
    invisible(app_env)
  }

  # --- Build & Run -----------------------------------------------

  # Start the application
  #
  # If Stage 2 declarations exist (inputs/outputs), generates the Svelte
  # --- Init script (custom JS injected after Svelte mount) ---
  app_env$init_script <- function(js) {
    app_env$.init_script <- paste0(app_env$.init_script %||% "", "\n", js)
  }

  # frontend, builds it, and serves it alongside the R API.
  # Otherwise, just starts the API server (Stage 1 mode).
  #
  # @param dev Logical. If TRUE, starts Vite dev server with HMR instead of
  #   building static files. The user visits Vite's port (default 5173) and
  #   API requests are proxied to ambiorix. Default FALSE.
  app_env$run <- function(dev = FALSE, rebuild = FALSE) {
    app_env$.rebuild <- rebuild
    has_declarations <- length(app_env$.inputs) > 0 || length(app_env$.outputs) > 0
    has_pages <- !is.null(app_env$.pages)

    # Register on_stop hooks
    if (length(app_env$.on_stop_hooks) > 0) {
      app_env$.app$on_stop <- function() {
        for (hook in app_env$.on_stop_hooks) {
          tryCatch(hook(), error = function(e) {
            message("on_stop hook error: ", e$message)
          })
        }
      }
    }

    # Register auth endpoints and middleware if configured
    if (!is.null(app_env$.auth)) {
      .register_auth(app_env)
    }

    # Register modal endpoints
    if (length(app_env$.modals) > 0) {
      .register_modal_endpoints(app_env)
    }

    if (has_declarations || has_pages) {
      if (has_declarations) {
        .register_output_endpoints(app_env)
      }

      if (dev) {
        # Dev mode: generate project, start Vite dev server with HMR
        build_dir <- .generate_dev_project(app_env)
        cat(sprintf("ambolt API running at http://%s:%d\n", host, port))
        cat("Starting Vite dev server (with HMR)...\n")
        .start_vite_dev(build_dir)
        vite_url <- "http://localhost:5173"
        cat(sprintf("Visit %s for the app (hot-reloading enabled)\n", vite_url))

        # Open Vite URL in RStudio Viewer (or system browser outside RStudio).
        # Suppress ambiorix's own browser open since port 3000 is API-only.
        viewer <- getOption("viewer", utils::browseURL)
        viewer(vite_url)
        app_env$.app$start(open = FALSE)
      } else {
        # Production mode: build and serve static files
        build_dir <- .generate_and_build(app_env)
        .serve_static(app_env, build_dir)
        cat(sprintf("ambolt app running at http://%s:%d\n", host, port))
        app_env$.app$start()
      }
    } else {
      cat(sprintf("ambolt app running at http://%s:%d\n", host, port))
      app_env$.app$start()
    }
  }

  app_env
}
