# --- ambolt build infrastructure -------------------------------
#
# Project scaffolding, npm/Vite orchestration, and static file serving.
# Depends on: utils.R (.find_framework_dir), codegen.R (.generate_app_svelte)

#' Scaffold a Svelte project directory with all required files
#'
#' Shared by both production and dev build paths. Writes App.svelte,
#' main.js, app.css, index.html, vite.config.js, and package.json.
#'
#' @param build_base Character. Path to the project directory.
#' @param app_env The ambolt app environment (for code generation).
#' @param mode Character. "prod" or "dev" — controls vite config and package.json.
#' @return Invisibly returns build_base.
#' @noRd
.scaffold_project <- function(build_base, app_env, mode = "prod", app_svelte = NULL) {
  framework_dir <- .find_framework_dir()
  framework_dir_js <- gsub("\\\\", "/", framework_dir)

  # Generate App.svelte from declarations (unless pre-generated content was passed)
  if (is.null(app_svelte)) {
    app_svelte <- .generate_app_svelte(app_env)
  }

  # Write src/ files
  src_dir <- file.path(build_base, "src")
  if (dir.exists(src_dir)) unlink(src_dir, recursive = TRUE)
  dir.create(src_dir, recursive = TRUE)

  writeLines(app_svelte, file.path(src_dir, "App.svelte"))

  # Copy static assets (e.g., empty state image) to public/
  public_dir <- file.path(build_base, "public")
  if (!dir.exists(public_dir)) dir.create(public_dir)
  empty_state <- app_env$.empty_state
  if (!is.null(empty_state$image_path) && file.exists(empty_state$image_path)) {
    file.copy(empty_state$image_path, file.path(public_dir, empty_state$image), overwrite = TRUE)
  }

  writeLines("body { margin: 0; padding: 0; background: #fafafa; }",
    file.path(src_dir, "app.css"))

  writeLines(
    "import { mount } from 'svelte'\nimport './app.css'\nimport App from './App.svelte'\nconst app = mount(App, { target: document.getElementById('app') })\nexport default app",
    file.path(src_dir, "main.js"))

  # Write index.html using meta settings
  meta <- app_env$.meta
  favicon_tag <- if (!is.null(meta$favicon)) {
    sprintf('\n  <link rel="icon" href="%s" />', meta$favicon)
  } else ""
  writeLines(sprintf(
    '<!doctype html>\n<html lang="%s">\n<head>\n  <meta charset="UTF-8" />\n  <meta name="viewport" content="width=device-width, initial-scale=1.0" />%s\n  <title>%s</title>\n</head>\n<body>\n  <div id="app"></div>\n  <script type="module" src="/src/main.js"></script>\n</body>\n</html>',
    meta$lang, favicon_tag, meta$title),
    file.path(build_base, "index.html"))

  # Write vite.config.js — dev mode adds API proxy
  if (mode == "dev") {
    api_target <- sprintf("http://%s:%d", app_env$.host, app_env$.port)
    writeLines(sprintf(
      "import { defineConfig } from 'vite'\nimport { svelte } from '@sveltejs/vite-plugin-svelte'\nimport { resolve } from 'path'\n\nexport default defineConfig({\n  plugins: [svelte()],\n  resolve: {\n    alias: {\n      'ambolt': '%s',\n      'flatpickr': resolve('node_modules/flatpickr'),\n    }\n  },\n  server: {\n    proxy: {\n      '/api': '%s'\n    }\n  }\n})",
      framework_dir_js, api_target),
      file.path(build_base, "vite.config.js"))
  } else {
    writeLines(sprintf(
      "import { defineConfig } from 'vite'\nimport { svelte } from '@sveltejs/vite-plugin-svelte'\nimport { resolve } from 'path'\n\nexport default defineConfig({\n  plugins: [svelte()],\n  resolve: {\n    alias: {\n      'ambolt': '%s',\n      'flatpickr': resolve('node_modules/flatpickr'),\n    }\n  }\n})",
      framework_dir_js),
      file.path(build_base, "vite.config.js"))
  }

  # Write package.json — dev mode includes "dev" script
  if (mode == "dev") {
    writeLines(
      '{"name":"ambolt-generated","private":true,"version":"0.0.0","type":"module","scripts":{"dev":"vite","build":"vite build"},"devDependencies":{"@sveltejs/vite-plugin-svelte":"^5.0.0","svelte":"^5.0.0","vite":"^6.0.0"},"dependencies":{"flatpickr":"^4.6.13","@gka/svelteplot":"^0.12.0"}}',
      file.path(build_base, "package.json"))
  } else {
    writeLines(
      '{"name":"ambolt-generated","private":true,"version":"0.0.0","type":"module","scripts":{"build":"vite build"},"devDependencies":{"@sveltejs/vite-plugin-svelte":"^5.0.0","svelte":"^5.0.0","vite":"^6.0.0"},"dependencies":{"flatpickr":"^4.6.13","@gka/svelteplot":"^0.12.0"}}',
      file.path(build_base, "package.json"))
  }

  invisible(build_base)
}

#' Run npm install in the given directory
#' @noRd
.npm_install <- function(build_base) {
  old_wd <- setwd(build_base)
  on.exit(setwd(old_wd), add = TRUE)

  install_result <- system2("npm", "install", stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(install_result, "status")) && attr(install_result, "status") != 0) {
    stop("npm install failed:\n", paste(install_result, collapse = "\n"))
  }
}

#' Generate the frontend project, build it, return the dist path
#'
#' Uses a persistent build directory (.ambolt_build/ next to the app)
#' with content-hash caching. If the generated App.svelte hasn't changed
#' since last build, serves the cached dist/ instantly.
#' @noRd
.generate_and_build <- function(app_env) {
  # Use a persistent directory instead of tempdir() — survives restarts
  build_base <- Sys.getenv("AMBOLT_BUILD_DIR", "")
  if (build_base == "") {
    build_base <- file.path(getwd(), ".ambolt_build")
  }
  if (!dir.exists(build_base)) dir.create(build_base, recursive = TRUE)

  # Generate App.svelte content and compute hash
  # Hash includes both the generated app AND framework source components,
  # so changes to framework .svelte/.js files also trigger a rebuild.
  app_svelte <- .generate_app_svelte(app_env)
  inst_dir <- .find_framework_dir()
  framework_files <- list.files(
    file.path(inst_dir, "components"), pattern = "\\.(svelte|js)$",
    full.names = TRUE, recursive = TRUE)
  framework_mtimes <- paste(file.mtime(framework_files), collapse = "|")
  content_hash <- digest::digest(
    paste(app_svelte, framework_mtimes, sep = "\n"), algo = "md5")
  hash_file <- file.path(build_base, ".build_hash")
  dist_dir <- file.path(build_base, "dist")

  # Check if cached build matches current content
  force_rebuild <- isTRUE(app_env$.rebuild)
  if (!force_rebuild &&
      file.exists(hash_file) &&
      dir.exists(dist_dir) &&
      file.exists(file.path(dist_dir, "index.html"))) {
    cached_hash <- readLines(hash_file, warn = FALSE)[1]
    if (identical(cached_hash, content_hash)) {
      cat("Frontend unchanged -- using cached build.\n")
      return(dist_dir)
    }
  }

  cat("Generating Svelte frontend...\n")
  .scaffold_project(build_base, app_env, mode = "prod", app_svelte = app_svelte)

  # Run npm install if node_modules is missing or package.json has changed
  nm_dir <- file.path(build_base, "node_modules")
  pkg_json <- file.path(build_base, "package.json")
  pkg_hash_file <- file.path(build_base, ".pkg_hash")
  pkg_hash <- digest::digest(readLines(pkg_json, warn = FALSE), algo = "md5")
  cached_hash <- if (file.exists(pkg_hash_file)) readLines(pkg_hash_file, warn = FALSE)[1] else ""
  if (!dir.exists(nm_dir) || !identical(pkg_hash, cached_hash)) {
    cat("Installing dependencies...\n")
    .npm_install(build_base)
    writeLines(pkg_hash, pkg_hash_file)
  } else {
    cat("Using cached node_modules.\n")
  }

  cat("Building frontend...\n")
  old_wd <- setwd(build_base)
  on.exit(setwd(old_wd), add = TRUE)
  build_result <- system2("npm", c("run", "build"), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(build_result, "status")) && attr(build_result, "status") != 0) {
    stop("npm run build failed:\n", paste(build_result, collapse = "\n"))
  }

  # Save hash for next startup
  writeLines(content_hash, hash_file)

  cat("Frontend built successfully.\n")
  dist_dir
}

#' Generate the dev project (with node_modules caching, no build step)
#' @noRd
.generate_dev_project <- function(app_env) {
  build_base <- file.path(tempdir(), "ambolt_dev")
  node_modules_exist <- dir.exists(file.path(build_base, "node_modules"))

  if (!dir.exists(build_base)) dir.create(build_base, recursive = TRUE)

  cat("Generating Svelte frontend (dev mode)...\n")
  .scaffold_project(build_base, app_env, mode = "dev")

  if (!node_modules_exist) {
    cat("Installing dependencies (first run only)...\n")
    .npm_install(build_base)
    cat("Dependencies installed.\n")
  } else {
    cat("Using cached node_modules.\n")
  }

  build_base
}

#' Register API endpoints for all declared outputs
#' @noRd
.register_output_endpoints <- function(app_env) {
  for (output_def in app_env$.outputs) {
    # Use local() to capture the current value of each variable,
    # avoiding the classic R closure-in-loop bug where all handlers
    # would end up referencing the last output_def's render function.
    local({
      id <- output_def$id
      type <- output_def$type
      render_fn <- output_def$render
      path <- sprintf("/api/output/%s", id)

      if (type == "plot") {
        app_env$plot_endpoint(path, render_fn)
      } else if (type == "table" || type == "chart") {
        app_env$data_endpoint(path, render_fn)
      } else if (type == "html") {
        app_env$.app$get(path, function(req, res) {
          params <- as.list(req$query)
          html_string <- render_fn(params)
          res$header("Content-Type", "text/html; charset=utf-8")
          res$send(html_string)
        })
      }
    })
  }
}

#' Register modal endpoints (GET /api/modal/{id})
#' @noRd
.register_modal_endpoints <- function(app_env) {
  for (modal_def in app_env$.modals) {
    local({
      id <- modal_def$id
      render_fn <- modal_def$render
      path <- sprintf("/api/modal/%s", id)

      app_env$.app$get(path, function(req, res) {
        params <- as.list(req$query)
        params$.user <- req$user  # Pass authenticated user to modal render
        result <- tryCatch(
          render_fn(params),
          error = function(e) {
            message("Modal render error (", id, "): ", e$message)
            list(title = "Fel", html = sprintf("<p>Kunde inte ladda: %s</p>", e$message))
          }
        )
        res$json(result)
      })
    })
  }
}

#' Serve static files from a directory
#' @noRd
.serve_static <- function(app_env, dist_dir) {
  # Map dist/assets/ to /assets/ URL prefix — this is where Vite puts built JS/CSS
  app_env$.app$static(file.path(dist_dir, "assets"), "assets")

  # Serve index.html for the root path
  app_env$.app$get("/", function(req, res) {
    index_path <- file.path(dist_dir, "index.html")
    res$header("Content-Type", "text/html")
    res$send(readLines(index_path, warn = FALSE) |> paste(collapse = "\n"))
  })
}

#' Start Vite dev server in the background
#' @noRd
.start_vite_dev <- function(build_dir) {
  old_wd <- setwd(build_dir)
  on.exit(setwd(old_wd), add = TRUE)

  # Start Vite dev server as a background process
  # On Windows/MINGW we need to use system2 with wait = FALSE
  system2("npx", c("vite", "--host"), wait = FALSE,
    stdout = file.path(build_dir, "vite.log"),
    stderr = file.path(build_dir, "vite.log"))
}
