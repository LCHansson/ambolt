## Theme tokens — fas 3 of 0.2.
##
## Locks the contract from `plans/specs/theme-tokens.md`:
##   - nested grammar accepted by `app$theme(tokens = list(...))`
##   - additive across calls (deep-merge, not replace)
##   - color auto-derive for hover/muted/focus
##   - cascade ordering: design tokens BEFORE legacy colors/components
##     BEFORE css= (later wins)
##   - empty input yields empty CSS (zero opinion when unconfigured)

test_that(".deep_merge_lists merges nested categories additively", {
  a <- list(color = list(primary = "red"), font = list(family = "Inter"))
  b <- list(color = list(text = "black"))
  merged <- .deep_merge_lists(a, b)
  expect_equal(merged$color$primary, "red")
  expect_equal(merged$color$text, "black")
  expect_equal(merged$font$family, "Inter")
})

test_that(".deep_merge_lists overrides scalars wholesale", {
  a <- list(color = list(primary = "red"))
  b <- list(color = list(primary = "blue"))
  expect_equal(.deep_merge_lists(a, b)$color$primary, "blue")
})

test_that(".deep_merge_lists handles NULLs at either side", {
  expect_equal(.deep_merge_lists(NULL, list(x = 1)), list(x = 1))
  expect_equal(.deep_merge_lists(list(x = 1), NULL), list(x = 1))
  expect_null(.deep_merge_lists(NULL, NULL))
})

test_that(".generate_design_tokens_block returns empty for empty input", {
  expect_equal(.generate_design_tokens_block(NULL), "")
  expect_equal(.generate_design_tokens_block(list()), "")
})

test_that(".generate_design_tokens_block emits :root variables for color tokens", {
  tokens <- list(color = list(primary = "#1a73e8", text = "#202124"))
  css <- .generate_design_tokens_block(tokens)
  expect_match(css, "--ambolt-color-primary: #1a73e8;", fixed = TRUE)
  expect_match(css, "--ambolt-color-text: #202124;", fixed = TRUE)
})

test_that(".generate_design_tokens_block auto-derives hover/muted/focus from a base color", {
  tokens <- list(color = list(primary = "#1a73e8"))
  css <- .generate_design_tokens_block(tokens)
  expect_match(css, "--ambolt-color-primary-hover: color-mix", fixed = TRUE)
  expect_match(css, "--ambolt-color-primary-muted: color-mix", fixed = TRUE)
  expect_match(css, "--ambolt-color-primary-focus: color-mix", fixed = TRUE)
})

test_that("explicit color variant overrides auto-derive", {
  tokens <- list(color = list(primary = "#1a73e8", primary_hover = "#000000"))
  css <- .generate_design_tokens_block(tokens)
  expect_match(css, "--ambolt-color-primary-hover: #000000;", fixed = TRUE)
  # The auto-derive line for hover must NOT also appear
  expect_false(grepl("--ambolt-color-primary-hover: color-mix", css, fixed = TRUE))
})

test_that(".generate_design_tokens_block emits font tokens + global body cascade", {
  tokens <- list(font = list(
    family = "Inter, sans-serif",
    size_base = "16px",
    line_height = 1.5,
    weight = list(regular = 400, bold = 700)
  ))
  css <- .generate_design_tokens_block(tokens)
  expect_match(css, "--ambolt-font-family: Inter, sans-serif;", fixed = TRUE)
  expect_match(css, "--ambolt-font-size-base: 16px;", fixed = TRUE)
  expect_match(css, "--ambolt-font-weight-regular: 400;", fixed = TRUE)
  expect_match(css, "--ambolt-font-weight-bold: 700;", fixed = TRUE)
  # Global body rule
  expect_match(css, "font-family: var(--ambolt-font-family);", fixed = TRUE)
})

test_that(".generate_design_tokens_block emits radius/space/shadow tokens", {
  tokens <- list(
    radius = list(md = "8px", lg = "16px"),
    space = list(md = "1rem"),
    shadow = list(md = "0 2px 8px rgba(0,0,0,0.1)")
  )
  css <- .generate_design_tokens_block(tokens)
  expect_match(css, "--ambolt-radius-md: 8px;", fixed = TRUE)
  expect_match(css, "--ambolt-space-md: 1rem;", fixed = TRUE)
  expect_match(css, "--ambolt-shadow-md: 0 2px 8px rgba(0,0,0,0.1);", fixed = TRUE)
})

test_that("app$theme(tokens=...) is additive across multiple calls", {
  app <- create_app(port = 0L)
  app$theme(tokens = list(color = list(primary = "#ff0000")))
  app$theme(tokens = list(color = list(text = "#000000")))
  expect_equal(app$.theme_tokens$color$primary, "#ff0000")
  expect_equal(app$.theme_tokens$color$text, "#000000")
})

test_that("app$theme(tokens=...) merges with legacy colors= without conflict", {
  app <- create_app(port = 0L)
  app$theme(tokens = list(color = list(primary = "#ff0000")))
  app$theme(colors = list(secondary = "#00ff00"))
  expect_equal(app$.theme_tokens$color$primary, "#ff0000")
  expect_equal(app$.theme_colors$secondary, "#00ff00")
})

test_that("design-tokens CSS appears BEFORE legacy css = in cascade order", {
  ## The cascade rule: design tokens first, css= last. We can verify
  ## ordering by inspecting the assembled all_css fragment. We construct
  ## a minimal app and call the layout codegen to obtain the rendered
  ## <style> block.
  app <- create_app(port = 0L)
  app$theme(
    tokens = list(color = list(primary = "#token-color")),
    colors = list(primary = "#legacy-color"),
    css = "/* user-css-marker */"
  )
  app$ui(page_content(page_header(title = "h")))
  result <- .generate_app_svelte(app)
  # The order in the <style> tag must be: design tokens → legacy colors → user css.
  pos_tokens <- regexpr("token-color", result, fixed = TRUE)
  pos_legacy <- regexpr("legacy-color", result, fixed = TRUE)
  pos_user   <- regexpr("user-css-marker", result, fixed = TRUE)
  expect_gt(pos_tokens, 0)
  expect_gt(pos_legacy, pos_tokens)
  expect_gt(pos_user, pos_legacy)
})
