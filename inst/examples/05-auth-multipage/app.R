## 05-auth-multipage -- Multi-page app with login.
##
## Demonstrates: app$auth() (verify + login function pair, with a session
## token generated server-side); app$pages() registering pages that show
## up in the NavSidebar; app$module() with a per-page output declared via
## `mod$output()` so the layout can reference it by id.
##
## Login: user = "demo", password = "demo".

build_app <- function(port = 3000L) {
  app <- ambolt::create_app(port = port)
  app$meta(title = "Multi-page demo")

  hashed <- ambolt::ambolt_hash_password("demo")

  app$auth(
    verify = function(token, db = NULL) {
      # Real apps look `token` up in a session store. The demo treats any
      # presented token as the demo user (we issued it ourselves in login).
      list(user = "demo")
    },
    login = function(username, password, db = NULL) {
      if (identical(username, "demo") &&
          ambolt::ambolt_verify_password(password, hashed)) {
        list(token = ambolt::ambolt_session_token(), user = "demo")
      } else NULL
    }
  )

  app$module("profile", function(mod, app_env) {
    # Declare the output so the layout can reference it as "profile/info"
    mod$output("info", type = "html",
               endpoint = "/api/profile/info")

    mod$get("/info", function(req, res) {
      who <- (req$session %||% list())$user %||% "(anonymous)"
      res$header("Content-Type", "text/html; charset=utf-8")
      res$send(sprintf("<p>Signed in as <strong>%s</strong>.</p>", who))
    })
  })

  app$pages(
    list(id = "overview", label = "Overview", icon = "house",
         ui = ambolt::page_content(
           ambolt::page_header(title = "Overview",
                               subtitle = "Logged-in user lands here"),
           ambolt::section("Stats",
             ambolt::html_block("<p>Imagine a dashboard here.</p>")
           )
         )),
    list(id = "profile", label = "Profile", icon = "person",
         ui = ambolt::page_content(
           ambolt::page_header(title = "Your profile"),
           ambolt::section("Account", "profile/info")
         ))
  )

  app
}
