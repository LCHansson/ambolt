## 03-inputs-gallery -- Every built-in input type, one page.
##
## Demonstrates: select, text, textarea, numeric, slider, checkbox,
## checkbox_group, radio, date, date_range, action. The output is a
## single html block that echoes whichever inputs the user has set,
## so the dev can verify wiring at a glance. Updates reactively as
## any input changes (no trigger gate -- the action button is here to
## show the input type, not to drive the output).

build_app <- function(port = 3000L) {
  app <- ambolt::create_app(port = port)

  app$input("flavor", type = "select",
            label = "Flavor",
            choices = c("Vanilla" = "vanilla",
                        "Chocolate" = "chocolate",
                        "Mint" = "mint"))
  app$input("name",     type = "text",     label = "Name")
  app$input("bio",      type = "textarea", label = "Bio", rows = 3)
  app$input("age",      type = "numeric",  label = "Age", min = 0, max = 150, value = 30)
  app$input("temp",     type = "slider",   label = "Temperature", min = -10, max = 30, value = 20)
  app$input("agree",    type = "checkbox", label = "I agree", checked = TRUE)
  app$input("toppings", type = "checkbox_group", label = "Toppings",
            choices = c("Nuts", "Caramel", "Sprinkles"))
  app$input("size",     type = "radio", label = "Size",
            choices = c("Small" = "s", "Medium" = "m", "Large" = "l"),
            selected = "m")
  app$input("born",     type = "date", label = "Birthday", value = "1990-01-01")
  app$input("vacation", type = "date_range", label = "Vacation",
            value = c("2026-06-01", "2026-06-14"))
  app$input("go",       type = "action", label = "Submit")

  app$output("echo", type = "html",
             render = function(params) {
               rows <- vapply(names(params), function(k) {
                 if (startsWith(k, ".")) return(NA_character_)
                 v <- params[[k]]
                 vstr <- if (is.null(v) || (length(v) == 1 && is.na(v))) "(unset)"
                         else paste(as.character(v), collapse = ", ")
                 sprintf("<dt>%s</dt><dd>%s</dd>",
                         ambolt::html_escape(k), ambolt::html_escape(vstr))
               }, character(1))
               rows <- rows[!is.na(rows)]
               sprintf('<dl style="display:grid;grid-template-columns:max-content 1fr;gap:0.5rem 1rem;">%s</dl>',
                       paste(rows, collapse = ""))
             })

  app$ui(ambolt::sidebar_layout(
    ambolt::sidebar(
      "flavor", "name", "bio", "age", "temp", "agree",
      "toppings", "size", "born", "vacation", "go"
    ),
    ambolt::main(
      ambolt::page_header(title = "Inputs gallery"),
      ambolt::section("Submitted values", "echo")
    )
  ))

  app
}
