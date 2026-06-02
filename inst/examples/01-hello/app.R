## 01-hello -- Smallest possible ambolt app.
##
## Demonstrates: create_app, app$input, app$output (type = "html"),
## app$ui referencing input/output by id string (the codegen translates
## "name" -> <TextInput id="name" ... /> etc.).

build_app <- function(port = 3000L) {
  app <- ambolt::create_app(port = port)

  app$input("name", type = "text",
            label = "Your name",
            placeholder = "Type and the greeting updates")

  app$output("greeting", type = "html",
             render = function(params) {
               who <- if (!is.null(params$name) && nzchar(params$name)) {
                 params$name
               } else "stranger"
               sprintf('<p style="font-size:1.5em;">Hello, %s!</p>',
                       ambolt::html_escape(who))
             })

  app$ui(ambolt::page_content(
    ambolt::page_header(title = "Hello, ambolt!"),
    ambolt::section("Greeting",
      "name",      # input id -- becomes <TextInput .../>
      "greeting"   # output id -- becomes <HtmlOutput .../>
    )
  ))

  app
}
