## Vite dev server port (0.2.0.9004).
##
## Locks the contract for `create_app(dev_port = )`:
##   - the generated dev vite.config.js carries the port and strictPort,
##     so Vite never drifts to another port than the one run() opens
##   - the production config has no dev server block at all
##   - a taken or invalid port is caught before Vite is started

scaffold_config <- function(app, mode) {
  build_base <- tempfile("ambolt_dev_port_")
  dir.create(build_base)
  on.exit(unlink(build_base, recursive = TRUE), add = TRUE)
  .scaffold_project(build_base, app, mode = mode, app_svelte = "<p>test</p>")
  paste(readLines(file.path(build_base, "vite.config.js")), collapse = "\n")
}

test_that("dev_port defaults to 5173 and follows AMBOLT_DEV_PORT", {
  old <- Sys.getenv("AMBOLT_DEV_PORT", unset = NA)
  on.exit(
    if (is.na(old)) Sys.unsetenv("AMBOLT_DEV_PORT") else Sys.setenv(AMBOLT_DEV_PORT = old),
    add = TRUE
  )

  Sys.unsetenv("AMBOLT_DEV_PORT")
  expect_equal(create_app(port = 0L)$.dev_port, 5173L)

  Sys.setenv(AMBOLT_DEV_PORT = "5199")
  expect_equal(create_app(port = 0L)$.dev_port, 5199L)
  expect_equal(create_app(port = 0L, dev_port = 5201L)$.dev_port, 5201L)
})

test_that("dev vite config pins the port, prod config has no server block", {
  app <- create_app(port = 0L, dev_port = 5199L)

  dev_config <- scaffold_config(app, "dev")
  expect_match(dev_config, "port: 5199,", fixed = TRUE)
  expect_match(dev_config, "strictPort: true", fixed = TRUE)
  expect_match(dev_config, "'/api':", fixed = TRUE)

  prod_config <- scaffold_config(app, "prod")
  expect_no_match(prod_config, "server:", fixed = TRUE)
  expect_no_match(prod_config, "5199", fixed = TRUE)
})

test_that(".check_dev_port rejects invalid ports", {
  expect_error(.check_dev_port(NA_integer_), "dev_port")
  expect_error(.check_dev_port(0L), "dev_port")
  expect_error(.check_dev_port(70000L), "dev_port")
  expect_error(.check_dev_port(c(5173L, 5174L)), "dev_port")
})

test_that(".check_dev_port stops when the port is taken", {
  # Find a port we can listen on, then ask for that same port.
  port <- NULL
  srv <- NULL
  for (candidate in sample(49152:65535, 20)) {
    srv <- tryCatch(serverSocket(candidate), error = function(e) NULL)
    if (!is.null(srv)) {
      port <- candidate
      break
    }
  }
  skip_if(is.null(srv), "no free port to listen on")

  expect_true(.port_in_use(port))
  expect_error(.check_dev_port(port), "already in use")

  close(srv)
  expect_false(.port_in_use(port))
  expect_equal(.check_dev_port(port), port)
})
