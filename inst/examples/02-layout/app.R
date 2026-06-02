## 02-layout — Composing layout DSL.
##
## Demonstrates: sidebar_layout, page_content, page_header, section,
## columns, details (collapsible). No data flow — purely structural.

build_app <- function(port = 3000L) {
  app <- ambolt::create_app(port = port)

  app$ui(ambolt::page_content(
    ambolt::page_header(
      title = "Layout DSL tour",
      subtitle = "Composing page structure without raw HTML"
    ),
    ambolt::section("Two-column row",
      ambolt::columns(
        ambolt::html_block("<p>Left column. Cards, charts, or anything else go here.</p>"),
        ambolt::html_block("<p>Right column. Each child of <code>columns()</code> becomes one column.</p>"),
        gap = "2rem"
      )
    ),
    ambolt::section("Nested sections",
      ambolt::html_block("<p>Sections can nest. Each gets the framework's spacing tokens.</p>"),
      ambolt::section("Sub-section",
        ambolt::html_block("<p>Like this one.</p>")
      )
    ),
    ambolt::section("Collapsible details",
      ambolt::details("Click me",
        ambolt::html_block("<p>Hidden content. Rendered as <code>&lt;details&gt;</code> — no JS needed.</p>")
      )
    )
  ))

  app
}
