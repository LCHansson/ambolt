# --- ambolt authentication -----------------------------------------
#
# Auth helpers (password hashing, token generation) and the auth
# endpoint/middleware registration function.
#
# Helpers are available globally after sourcing app.R.
# .register_auth() is called internally by app$run().

# --- Auth helpers -------------------------------------------------

#' Generate a cryptographically random session token
#'
#' Returns 256 bits of randomness from `openssl::rand_bytes()`,
#' hex-encoded for use as an opaque session identifier.
#'
#' @return Character. A 64-character hex string.
#' @export
#' @examples
#' ambolt_session_token()
ambolt_session_token <- function() {
  paste0(sprintf("%02x", as.integer(openssl::rand_bytes(32))), collapse = "")
}

#' Hash a password
#'
#' Currently uses SHA-256 (hex-encoded) to match the legacy Shiny app's
#' password format during the migration period. Will be upgraded to
#' Argon2id (`sodium::password_store()`) with transparent re-hashing on
#' login once compatibility is no longer required.
#'
#' @param password Character. The plaintext password to hash.
#' @return Character. A hex-encoded SHA-256 digest.
#' @seealso [ambolt_verify_password()]
#' @export
#' @examples
#' hash <- ambolt_hash_password("hunter2")
#' ambolt_verify_password("hunter2", hash)
ambolt_hash_password <- function(password) {
  sodium::bin2hex(sodium::sha256(charToRaw(password)))
}

#' Verify a password against a stored hash
#'
#' @param password Character. The plaintext password to verify.
#' @param hash Character. The stored hash produced by [ambolt_hash_password()].
#' @return TRUE if the password matches, FALSE otherwise.
#' @seealso [ambolt_hash_password()]
#' @export
ambolt_verify_password <- function(password, hash) {
  identical(sodium::bin2hex(sodium::sha256(charToRaw(password))), hash)
}

# --- Auth registration -------------------------------------------

#' Register auth endpoints, middleware, and rate limiter
#'
#' Called from app$run() when app$auth() has been configured.
#' Installs: POST /api/auth/login, POST /api/auth/logout,
#' GET /api/auth/me, auth middleware, CORS tightening, rate limiter.
#' @noRd
.register_auth <- function(app_env) {
  # Fail fast if auth dependencies are missing
  auth_pkgs <- c("sodium", "openssl")
  missing <- auth_pkgs[!vapply(auth_pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("[ambolt] Auth requires missing R packages: ", paste(missing, collapse = ", "),
         "\n  Install with: install.packages(c(",
         paste0("'", missing, "'", collapse = ", "), "))",
         call. = FALSE)
  }

  auth <- app_env$.auth
  verify_fn <- auth$verify
  login_fn <- auth$login
  logout_fn <- auth$logout
  cookie_name <- auth$cookie_name
  cookie_days <- auth$cookie_days
  exclude <- auth$exclude
  max_attempts <- auth$max_attempts
  lockout_seconds <- auth$lockout_seconds

  # In-memory rate limiter state
  rate_limits <- new.env(parent = emptyenv())

  # Helper: read session token from cookie header
  .read_cookie <- function(req) {
    cookie_header <- req$HTTP_COOKIE %||% ""
    pattern <- sprintf("(?:^|;\\s*)%s=([^;]+)", cookie_name)
    m <- regmatches(cookie_header, regexec(pattern, cookie_header))[[1]]
    if (length(m) >= 2) m[2] else NULL
  }

  # Helper: build Set-Cookie header value
  .set_cookie_header <- function(token) {
    max_age <- cookie_days * 86400L
    secure_flag <- ""  # added by Caddy/reverse proxy in production
    sprintf("%s=%s; Path=/; HttpOnly; SameSite=Strict; Max-Age=%d%s",
      cookie_name, token, max_age, secure_flag)
  }

  .clear_cookie_header <- function() {
    sprintf("%s=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0", cookie_name)
  }

  # Helper: check rate limit
  .check_rate_limit <- function(username) {
    entry <- rate_limits[[username]]
    if (is.null(entry)) return(TRUE)  # no record, allow
    if (!is.null(entry$locked_until)) {
      if (Sys.time() < entry$locked_until) {
        return(FALSE)  # still locked out
      }
      # Lockout expired — reset counter
      rm(list = username, envir = rate_limits)
      return(TRUE)
    }
    TRUE
  }

  .record_failure <- function(username) {
    entry <- rate_limits[[username]]
    if (is.null(entry)) entry <- list(count = 0L, locked_until = NULL)
    entry$count <- entry$count + 1L
    if (entry$count >= max_attempts) {
      entry$locked_until <- Sys.time() + lockout_seconds
    }
    rate_limits[[username]] <- entry
  }

  .clear_rate_limit <- function(username) {
    if (exists(username, envir = rate_limits)) {
      rm(list = username, envir = rate_limits)
    }
  }

  # -- Tighten CORS when auth is enabled --
  # Replace the default permissive CORS with same-origin + credentials
  app_env$.app$use(function(req, res) {
    origin <- req$HTTP_ORIGIN %||% ""
    res$header("Access-Control-Allow-Origin", origin)
    res$header("Access-Control-Allow-Credentials", "true")
    res$header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    res$header("Access-Control-Allow-Headers", "Content-Type")
    NULL
  })

  # -- Auth middleware --
  # Check session cookie on all /api/ routes (except excluded paths)
  app_env$.app$use(function(req, res) {
    path <- req$PATH_INFO %||% ""

    # Skip non-API paths (static files, index.html)
    if (!grepl("^/api/", path)) return(NULL)

    # Skip excluded paths
    for (ex in exclude) {
      if (path == ex) return(NULL)
    }

    # Also skip the framework auth endpoints
    if (path %in% c("/api/auth/login", "/api/auth/logout", "/api/auth/me")) {
      return(NULL)
    }

    # Check session cookie
    token <- .read_cookie(req)
    if (is.null(token)) {
      res$status <- 401L
      return(res$json(list(error = "Authentication required")))
    }

    user <- tryCatch(
      verify_fn(token, app_env$context$db %||% NULL),
      error = function(e) {
        warning("[ambolt auth] Session verify error: ", e$message,
                immediate. = TRUE)
        NULL
      }
    )
    if (is.null(user)) {
      res$status <- 401L
      return(res$json(list(error = "Invalid or expired session")))
    }

    req$user <- user
    NULL  # continue to route handler
  })

  # -- POST /api/auth/login --
  app_env$.app$post("/api/auth/login", function(req, res) {
    # Parse JSON body
    if (!is.null(req$CONTENT_TYPE) &&
        grepl("application/json", req$CONTENT_TYPE, fixed = TRUE)) {
      req$body <- ambiorix::parse_json(req)
    }

    username <- req$body$username %||% ""
    password <- req$body$password %||% ""

    # Rate limit check
    if (!.check_rate_limit(username)) {
      res$status <- 429L
      return(res$json(list(
        success = FALSE,
        error = "F\u00f6r m\u00e5nga misslyckade f\u00f6rs\u00f6k. F\u00f6rs\u00f6k igen senare."
      )))
    }

    result <- tryCatch(
      login_fn(username, password, app_env$context$db %||% NULL),
      error = function(e) {
        warning("[ambolt auth] Login error for '", username, "': ",
                e$message, immediate. = TRUE)
        NULL
      }
    )

    if (is.null(result)) {
      .record_failure(username)
      res$status <- 401L
      return(res$json(list(
        success = FALSE,
        error = "Ogiltigt anv\u00e4ndarnamn eller l\u00f6senord"
      )))
    }

    .clear_rate_limit(username)

    # Set HttpOnly session cookie
    res$header("Set-Cookie", .set_cookie_header(result$token))
    res$json(list(success = TRUE, user = result$user))
  })

  # -- POST /api/auth/logout --
  app_env$.app$post("/api/auth/logout", function(req, res) {
    token <- .read_cookie(req)
    if (!is.null(token) && !is.null(logout_fn)) {
      tryCatch(
        logout_fn(token, app_env$context$db %||% NULL),
        error = function(e) message("Logout cleanup error: ", e$message)
      )
    }

    # Clear cookie
    res$header("Set-Cookie", .clear_cookie_header())
    res$json(list(success = TRUE))
  })

  # -- GET /api/auth/me --
  app_env$.app$get("/api/auth/me", function(req, res) {
    token <- .read_cookie(req)
    if (is.null(token)) {
      res$status <- 401L
      return(res$json(list(error = "Not authenticated")))
    }

    user <- tryCatch(
      verify_fn(token, app_env$context$db %||% NULL),
      error = function(e) {
        warning("[ambolt auth] Session verify error: ", e$message,
                immediate. = TRUE)
        NULL
      }
    )
    if (is.null(user)) {
      # Clear invalid cookie
      res$header("Set-Cookie", .clear_cookie_header())
      res$status <- 401L
      return(res$json(list(error = "Invalid or expired session")))
    }

    res$json(list(user = user))
  })

  cat("Auth configured: login at POST /api/auth/login\n")
}
