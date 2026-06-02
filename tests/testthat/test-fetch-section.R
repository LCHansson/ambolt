## fetch_section primitive — fas 4 of 0.2.
##
## Closes the "dashboard sections raw JS" gap from observations.md
## (2026-03-27, severity High). The primitive accepts a render handler
## that returns either a raw HTML string or a layout-DSL tree, and a
## frontend re-fetches when `refresh_event` fires. Same wire format as
## the existing type = "html"; the difference is purely server-side.

test_that(".render_static_html handles a minimal page_content tree", {
  tree <- page_content(
    page_header(title = "Dashboard"),
    section("Stats",
      html_block("<p>x</p>")
    )
  )
  out <- .render_static_html(tree)
  expect_match(out, "<div class=\"ambolt-page-content", fixed = TRUE)
  expect_match(out, "<h2 class=\"ambolt-page-title\">Dashboard</h2>", fixed = TRUE)
  expect_match(out, "<section class=\"ambolt-section", fixed = TRUE)
  expect_match(out, "<p>x</p>", fixed = TRUE)
})

test_that(".render_static_html handles columns with grid layout", {
  tree <- columns(
    html_block("<div>A</div>"),
    html_block("<div>B</div>"),
    gap = "1rem"
  )
  out <- .render_static_html(tree)
  expect_match(out, "grid-template-columns:repeat\\(2,1fr\\)")
  expect_match(out, "gap:1rem", fixed = TRUE)
  expect_match(out, "<div>A</div>", fixed = TRUE)
  expect_match(out, "<div>B</div>", fixed = TRUE)
})

test_that(".render_static_html preserves raw HTML returned by html_helpers (detail_grid)", {
  # detail_grid/detail_row are html_helpers that already produce raw HTML —
  # the walker passes character scalars through unchanged. Confirms a
  # common dashboard composition: section containing helper-emitted HTML.
  tree <- section("Profil",
    html_block(detail_grid(
      detail_row(label = "Namn", value = "Alma"),
      detail_row(label = "Parti", value = "C")
    ))
  )
  out <- .render_static_html(tree)
  expect_match(out, "<section class=\"ambolt-section", fixed = TRUE)
  expect_match(out, "<strong>Namn:</strong> Alma", fixed = TRUE)
  expect_match(out, "<strong>Parti:</strong> C", fixed = TRUE)
})

test_that(".render_static_html flags unsupported node types instead of breaking", {
  tree <- list(type = "data_table", endpoint = "/x")
  out <- .render_static_html(tree)
  expect_match(out, "unsupported node type", fixed = TRUE)
})

test_that(".render_static_html accepts raw HTML strings and bare child lists", {
  expect_equal(.render_static_html("plain"), "plain")
  expect_match(
    .render_static_html(list(html_block("<p>a</p>"), html_block("<p>b</p>"))),
    "<p>a</p>"
  )
})

test_that("app$output(type='fetch_section', ...) registers the output with refresh_event", {
  app <- create_app(port = 0L)
  app$output(
    "party_cards", type = "fetch_section",
    render = function(params) {
      page_content(section("Partier", html_block("<p>cards</p>")))
    },
    refresh_event = "ambolt:dashboard-refresh"
  )
  reg <- app$.outputs[["party_cards"]]
  expect_equal(reg[["type"]], "fetch_section")
  expect_equal(reg[["refresh_event"]], "ambolt:dashboard-refresh")
  expect_true(is.function(reg[["render"]]))
})

test_that("fetch_section output markup emits HtmlOutput with refreshEvent prop", {
  output_def <- list(
    id = "party_cards", type = "fetch_section",
    depends_on = character(0), trigger = NULL,
    refresh_event = "ambolt:dashboard-refresh"
  )
  markup <- .generate_output_markup(output_def, port = 3000L)
  expect_match(markup, "<HtmlOutput", fixed = TRUE)
  expect_match(markup, 'endpoint="/api/output/party_cards"', fixed = TRUE)
  expect_match(markup, 'refreshEvent="ambolt:dashboard-refresh"', fixed = TRUE)
})

test_that("fetch_section render returning DSL tree produces static HTML", {
  ## Mirror the server-side branch in build.R that wires up the endpoint:
  ## render(params) → if list with type, .render_static_html(out).
  render_fn <- function(params) {
    page_content(
      page_header(title = "Hello"),
      section("Body", html_block("<p>world</p>"))
    )
  }
  out <- render_fn(list())
  expect_true(is.list(out))
  expect_equal(out[["type"]], "page_content")
  html <- .render_static_html(out)
  expect_match(html, "<h2 class=\"ambolt-page-title\">Hello</h2>", fixed = TRUE)
  expect_match(html, "<p>world</p>", fixed = TRUE)
})
