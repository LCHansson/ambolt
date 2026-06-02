## Smoke-test the bundled examples in `inst/examples/`.
##
## For each example: load via `run_example(name, run = FALSE)`, verify the
## returned object is an app environment with the expected inputs/outputs.
## We do NOT run `app$run()` (would block) and do NOT trigger the Vite
## build (heavy + needs Node). The `tests/apps/` infra exercises the
## codegen+build pipeline end-to-end in browser-driven tests.

test_that("list_examples returns the six bundled apps", {
  ex <- ambolt::list_examples()
  expect_setequal(
    ex,
    c("01-hello", "02-layout", "03-inputs-gallery",
      "04-chart-and-table", "05-auth-multipage", "06-modal-form")
  )
})

test_that("run_example errors on unknown slug", {
  expect_error(
    ambolt::run_example("99-nope", run = FALSE),
    "Unknown example"
  )
})

test_that("each example builds an app object without error", {
  for (name in ambolt::list_examples()) {
    app <- tryCatch(
      ambolt::run_example(name, port = 0L, run = FALSE),
      error = function(e) {
        fail(sprintf("Example %s failed to build: %s", name, conditionMessage(e)))
        NULL
      }
    )
    expect_true(is.environment(app), info = sprintf("Example %s built", name))
    # Every example registers SOMETHING — either inputs+outputs, or pages
    has_decl <- length(app$.inputs) > 0 ||
                length(app$.outputs) > 0 ||
                !is.null(app$.pages) ||
                length(app$.modules) > 0 ||
                !is.null(app$.ui_tree)
    expect_true(has_decl, info = sprintf("Example %s declares something", name))
  }
})

test_that("01-hello has the expected one-input-one-output shape", {
  app <- ambolt::run_example("01-hello", port = 0L, run = FALSE)
  expect_equal(names(app$.inputs), "name")
  expect_equal(app$.inputs$name$type, "text")
  expect_equal(names(app$.outputs), "greeting")
  expect_equal(app$.outputs$greeting$type, "html")
})

test_that("04-chart-and-table wires chart + table outputs to the same input", {
  app <- ambolt::run_example("04-chart-and-table", port = 0L, run = FALSE)
  expect_equal(app$.outputs$sales_chart$type, "chart")
  expect_equal(app$.outputs$sales_table$type, "table")
  expect_true("region" %in% app$.outputs$sales_chart$depends_on)
  expect_true("region" %in% app$.outputs$sales_table$depends_on)
})

test_that("examples that need credentials ship a NOTES.md surfacing them", {
  # 05-auth-multipage requires login. The credentials live in NOTES.md
  # so `.print_example_banner` prints them at startup. Anchor: if the
  # file goes missing, running the example becomes a guessing game.
  ex_root <- system.file("examples", package = "ambolt")
  if (!nzchar(ex_root)) ex_root <- file.path("inst", "examples")
  notes <- file.path(ex_root, "05-auth-multipage", "NOTES.md")
  expect_true(file.exists(notes))
  body <- paste(readLines(notes, warn = FALSE), collapse = "\n")
  expect_match(body, "demo", fixed = TRUE)
})
