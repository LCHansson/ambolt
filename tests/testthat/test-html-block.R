## Locks the html_block() contract that fas 2 of 0.2 hardens:
##   1. Script execution is context-independent: a `script=` arg behaves
##      the same whether the html_block sits in a top-level page tree
##      (codegen-collected) or in a modal response (runtime tree-walker).
##   2. JS-string-escape foot-gun emits a heuristic warning at construction.
##   3. The foot-gun warning is suppressible.

test_that("html_block constructs a node with the documented shape", {
  node <- html_block("<p>hi</p>")
  expect_equal(node[["type"]], "html_block")
  expect_equal(node[["html"]], "<p>hi</p>")
  expect_null(node[["script"]])

  node2 <- html_block("<p>hi</p>", script = "console.log('x')")
  expect_equal(node2[["script"]], "console.log('x')")
})

test_that(".tree_collect_scripts surfaces scripts from html_block at any depth", {
  page_ui <- page_content(
    page_header(title = "P"),
    section(
      "S",
      html_block("<p>shallow</p>", script = "shallow();")
    ),
    columns(
      html_block("<p>deep</p>", script = "deep();")
    )
  )
  scripts <- .tree_collect_scripts(page_ui)
  expect_true(any(grepl("shallow\\(\\)", scripts)))
  expect_true(any(grepl("deep\\(\\)", scripts)))
})

test_that("modal response shape preserves the script identically (paritet)", {
  modal_node <- html_block("<p>m</p>", script = "modalScript();")
  expect_equal(modal_node[["script"]], "modalScript();")
  # The runtime walker (RenderNode.svelte) keys off node$type and node$script;
  # locking the shape here means the modal context cannot diverge silently
  # from the page-codegen context without breaking this test.
  expect_named(modal_node, c("type", "html", "script"), ignore.order = TRUE)
})

test_that("html_block warns on the JS-string-escape foot-gun (observations.md 2026-04-15)", {
  ## The observation: R double-quoted strings unescape `\"` to `"`, so this
  ## R source `script = "x = \"<p style=\"color:red\">y\""` produces the JS
  ## string  x = "<p style="color:red">y"  which breaks at the first inner `"`.
  broken <- 'x = "<p style="color:red">y"'
  expect_warning(
    html_block("<p>h</p>", script = broken),
    "JS string-escape collision"
  )
})

test_that("html_block escape warning is suppressible", {
  broken <- 'x = "<p style="color:red">y"'
  expect_no_warning(
    html_block("<p>h</p>", script = broken, .check_script_escapes = FALSE)
  )
})

test_that("html_block does not false-warn on benign scripts", {
  expect_no_warning(html_block("<p>h</p>", script = "console.log('ok');"))
  expect_no_warning(html_block("<p>h</p>", script = "el.textContent = 'plain';"))
  expect_no_warning(
    html_block(
      "<p>h</p>",
      script = "el.innerHTML = `<p style=\"color:red\">via template literal</p>`;"
    )
  )
})

test_that(".check_route_shadowing detects the ambiorix order foot-gun", {
  # Empty registry — no shadow possible
  expect_null(.check_route_shadowing(list(), "GET", "/api/items/compare"))

  # Earlier `:param` route shadows a later literal of same shape
  routes <- list(
    list(method = "GET", path = "/api/items/:id")
  )
  expect_equal(
    .check_route_shadowing(routes, "GET", "/api/items/compare"),
    "GET /api/items/:id"
  )

  # Different method — no shadow
  expect_null(.check_route_shadowing(routes, "POST", "/api/items/compare"))

  # Different segment count — no shadow
  expect_null(.check_route_shadowing(routes, "GET", "/api/items/compare/extra"))

  # Literal-vs-literal — no shadow (ambiorix correctly differentiates)
  routes2 <- list(list(method = "GET", path = "/api/items/foo"))
  expect_null(.check_route_shadowing(routes2, "GET", "/api/items/bar"))

  # New path has its own `:param` — not shadowed (it's also a param matcher)
  expect_null(.check_route_shadowing(routes, "GET", "/api/items/:other"))
})

test_that("mod$get warns when registering a literal after a :param route on the same shape", {
  ## Construct an app, register `:id` first, then a literal — the second
  ## registration must emit the shadow warning.
  app <- create_app(port = 0L)  # port=0 ⇒ no actual listener
  expect_warning(
    {
      app$module("items", function(mod, app_env) {
        mod$get("/:id", function(req, res) NULL)
        mod$get("/compare", function(req, res) NULL)
      })
    },
    "will be shadowed by earlier"
  )
})

test_that("mod$get does NOT warn when literal is registered before :param", {
  app <- create_app(port = 0L)
  expect_no_warning(
    app$module("items2", function(mod, app_env) {
      mod$get("/compare", function(req, res) NULL)
      mod$get("/:id", function(req, res) NULL)
    })
  )
})
