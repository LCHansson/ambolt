## 06-modal-form -- A button opens a modal containing a form. Submit
## posts back to a module endpoint and refreshes the list on the page.
##
## Demonstrates: create_button(modal = "contacts/create"); app$module()
## with mod$modal() returning a {title, content} layout-DSL response;
## mod$post() for the form handler; mod$output() declares the listing
## with refresh_event so it re-fetches after submit.

`%||%` <- function(x, y) if (is.null(x)) y else x

build_app <- function(port = 3000L) {
  app <- ambolt::create_app(port = port)
  app$meta(title = "Modal-form demo")

  # In-memory store keeps the example self-contained
  store <- list()

  app$module("contacts", function(mod, app_env) {
    # Declare the listing output so the page can reference it as
    # "contacts/table". The framework wires up <HtmlOutput> with the
    # endpoint + refresh_event.
    mod$output("table", type = "html",
               endpoint = "/api/contacts/table",
               refresh_event = "ambolt:contact-created")

    mod$get("/table", function(req, res) {
      rows <- if (length(store) == 0) {
        "<p><em>No contacts yet -- click 'New contact'.</em></p>"
      } else {
        items <- vapply(store, function(c) {
          sprintf("<li>%s &lt;%s&gt;</li>",
                  ambolt::html_escape(c$name), ambolt::html_escape(c$email))
        }, character(1))
        sprintf("<ul>%s</ul>", paste(items, collapse = ""))
      }
      res$header("Content-Type", "text/html; charset=utf-8")
      res$send(rows)
    })

    mod$modal("create", render = function(req) {
      list(
        title = "New contact",
        content = ambolt::page_content(
          ambolt::section("Details",
            ambolt::html_block(
              paste0(
                '<form id="new-contact-form" onsubmit="event.preventDefault(); ',
                "fetch('/api/contacts/create', {",
                "method:'POST', ",
                "headers:{'Content-Type':'application/json'}, ",
                "body: JSON.stringify(Object.fromEntries(new FormData(this)))",
                "}).then(()=>{ ",
                "window.dispatchEvent(new CustomEvent('ambolt:contact-created')); ",
                "modal.close(); ",
                '});">',
                '<label style="display:block;margin-bottom:0.5rem;">Name<br>',
                '<input name="name" required style="width:100%;padding:0.5rem;">',
                '</label>',
                '<label style="display:block;margin-bottom:1rem;">Email<br>',
                '<input name="email" type="email" required style="width:100%;padding:0.5rem;">',
                '</label>',
                '<button type="submit" class="ambolt-action-btn ambolt-action-btn-primary">Save</button>',
                '</form>'
              )
            )
          )
        )
      )
    })

    mod$post("/create", function(req, res) {
      data <- req$body
      store[[length(store) + 1L]] <<- list(name = data$name, email = data$email)
      res$json(list(ok = TRUE))
    })
  })

  app$pages(
    list(id = "home", label = "Contacts", icon = "people",
         ui = ambolt::page_content(
           ambolt::page_header(
             title = "Contacts",
             actions = ambolt::create_button("New contact",
                          modal = "contacts/create", icon = "plus")),
           ambolt::section("All contacts", "contacts/table")
         ))
  )

  app
}
