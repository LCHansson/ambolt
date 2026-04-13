# Tests for R/auth.R — auth helpers
# These regression-lock the A1 security fix verification.

test_that("ambolt_session_token returns 64-char hex string", {
  token <- ambolt_session_token()
  expect_type(token, "character")
  expect_equal(nchar(token), 64L)
  expect_true(grepl("^[0-9a-f]+$", token))
})

test_that("ambolt_session_token generates unique tokens", {
  tokens <- replicate(10, ambolt_session_token())
  expect_equal(length(unique(tokens)), 10L)
})

test_that("ambolt_hash_password returns consistent hash", {
  h1 <- ambolt_hash_password("test123")
  h2 <- ambolt_hash_password("test123")
  expect_equal(h1, h2)
})

test_that("ambolt_hash_password returns hex string", {
  h <- ambolt_hash_password("password")
  expect_type(h, "character")
  expect_true(grepl("^[0-9a-f]+$", h))
  expect_equal(nchar(h), 64L)  # SHA-256 = 32 bytes = 64 hex chars
})

test_that("different passwords produce different hashes", {
  h1 <- ambolt_hash_password("abc")
  h2 <- ambolt_hash_password("xyz")
  expect_false(identical(h1, h2))
})

test_that("ambolt_verify_password returns TRUE for correct password", {
  hash <- ambolt_hash_password("hunter2")
  expect_true(ambolt_verify_password("hunter2", hash))
})

test_that("ambolt_verify_password returns FALSE for wrong password", {
  hash <- ambolt_hash_password("hunter2")
  expect_false(ambolt_verify_password("wrong", hash))
  expect_false(ambolt_verify_password("Hunter2", hash))  # case-sensitive
  expect_false(ambolt_verify_password("", hash))
})
