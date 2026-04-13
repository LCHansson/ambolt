# Tests for R/layout_dsl.R — DSL constructors

test_that("constructors return correct type field", {
  expect_equal(section("A")$type, "section")
  expect_equal(columns()$type, "columns")
  expect_equal(details("A")$type, "details")
  expect_equal(page_content()$type, "page_content")
  expect_equal(page_header("T")$type, "page_header")
  expect_equal(html_block("<p>hi</p>")$type, "html_block")
  expect_equal(create_button("Go")$type, "create_button")
  expect_equal(logout_button()$type, "logout_button")
  expect_equal(view_switcher()$type, "view_switcher")
  expect_equal(data_table("/api/x")$type, "data_table")
})

test_that("stat_cards supports both id and inline forms", {
  by_id <- stat_cards("contacts/stats")
  expect_equal(by_id$type, "stat_cards")
  expect_equal(by_id$output_id, "contacts/stats")
  expect_null(by_id$endpoint)

  inline <- stat_cards(endpoint = "/api/stats", cards = list(list(key = "n")))
  expect_equal(inline$type, "stat_cards")
  expect_equal(inline$endpoint, "/api/stats")
  expect_null(inline$output_id)
})

test_that(".drop_nulls strips NULL fields", {
  node <- ambolt:::.drop_nulls(list(a = 1, b = NULL, c = "x"))
  expect_equal(names(node), c("a", "c"))
})

test_that(".drop_nulls preserves non-NULL falsy values", {
  node <- ambolt:::.drop_nulls(list(a = FALSE, b = 0L, c = "", d = list()))
  expect_equal(names(node), c("a", "b", "c", "d"))
})

test_that("create_button does not include NULL href/modal/navigate", {
  btn <- create_button("Go", modal = "test/modal")
  expect_true("modal" %in% names(btn))
  expect_false("href" %in% names(btn))
  expect_false("navigate" %in% names(btn))
  expect_false("download" %in% names(btn))
})

test_that("view() puts positional children in children, not icon", {
  v <- view("a", "Alpha", html_block("<p>hi</p>"), html_block("<p>bye</p>"))
  expect_length(v$children, 2)
  expect_null(v$icon)
  expect_equal(v$children[[1]]$type, "html_block")
})

test_that("view() accepts icon as named arg", {
  v <- view("a", "Alpha", html_block("<p>content</p>"), icon = "star")
  expect_equal(v$icon, "star")
  expect_length(v$children, 1)
})

test_that("section compact flag is boolean", {
  s1 <- section("A", compact = TRUE)
  expect_true(s1$compact)
  s2 <- section("B")
  # compact defaults to FALSE but may be dropped by .drop_nulls if FALSE
  expect_true(is.null(s2$compact) || identical(s2$compact, FALSE))
})

test_that("data_table coerces page_size to integer", {
  dt <- data_table("/api/x", page_size = 25)
  expect_type(dt$page_size, "integer")
  expect_equal(dt$page_size, 25L)
})

test_that("page_header includes actions list", {
  ph <- page_header("Title", actions = list(create_button("A"), create_button("B")))
  expect_length(ph$actions, 2)
  expect_equal(ph$actions[[1]]$type, "create_button")
})

test_that("sidebar_layout validates types", {
  expect_error(sidebar_layout(list(type = "wrong"), main()))
})
