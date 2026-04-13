# Tests for R/html_helpers.R

test_that("html_escape handles special characters", {
  expect_equal(html_escape("&"), "&amp;")
  expect_equal(html_escape("<script>"), "&lt;script&gt;")
  expect_equal(html_escape('"hello"'), "&quot;hello&quot;")
  expect_equal(html_escape("it's"), "it&#39;s")
  expect_equal(html_escape("a&b<c>d\"e'f"), "a&amp;b&lt;c&gt;d&quot;e&#39;f")
})

test_that("html_escape handles edge cases", {
  expect_equal(html_escape(NULL), "")
  expect_equal(html_escape(NA), "")
  expect_equal(html_escape(""), "")
  expect_equal(html_escape(42), "42")  # coerces to character
})

test_that("action_button generates valid HTML", {
  btn <- action_button("Save", "/api/contacts/1", method = "PUT",
                       toast = "Saved!", emit = "contacts:updated")
  expect_true(grepl("data-ambolt-action=\"put\"", btn))
  expect_true(grepl("data-ambolt-endpoint=\"/api/contacts/1\"", btn))
  expect_true(grepl("data-ambolt-toast=\"Saved!\"", btn))
  expect_true(grepl("data-ambolt-emit=\"contacts:updated\"", btn))
  expect_true(grepl(">Save</button>", btn))
})

test_that("action_button escapes label", {
  btn <- action_button("<b>bold</b>", "/api/test")
  expect_true(grepl("&lt;b&gt;bold&lt;/b&gt;", btn))
})

test_that("action_button includes body as JSON", {
  btn <- action_button("Go", "/api/test", body = list(level = 3L))
  expect_true(grepl("data-ambolt-body=", btn))
  expect_true(grepl('"level":3', btn))
})

test_that("modal_link generates data-modal attribute", {
  link <- modal_link("Open", "contacts/profile", params = list(id = 42))
  expect_true(grepl('data-modal="contacts/profile\\?id=42"', link))
  expect_true(grepl('data-modal-size="md"', link))
  expect_true(grepl(">Open</a>", link))
})

test_that("badge generates span with class", {
  b <- badge("Active", class = "eng-active")
  expect_true(grepl('class="ambolt-badge eng-active"', b))
  expect_true(grepl(">Active</span>", b))
})

test_that("detail_row produces label-value HTML", {
  row <- detail_row("Name", "Alice")
  expect_true(grepl("<strong>Name:</strong>", row))
  expect_true(grepl("Alice", row))
})

test_that("detail_grid produces grid layout", {
  grid <- detail_grid(detail_row("A", "1"), detail_row("B", "2"), cols = 2)
  expect_true(grepl("grid-template-columns:repeat\\(2", grid))
})

test_that("action_bar produces flex row", {
  bar <- action_bar(action_button("A", "/api/a"), action_button("B", "/api/b"))
  expect_true(grepl("display:flex", bar))
})
