## 04-chart-and-table -- Linked filter feeding a chart and a table.
##
## Demonstrates: select input -> two outputs sharing the same depends_on,
## type = "chart" (SveltePlot spec), type = "table" (DataTable fed by a
## JSON endpoint). The chart and table refresh together as the filter
## changes.

build_app <- function(port = 3000L) {
  app <- ambolt::create_app(port = port)

  # Fake data set so the example is self-contained
  rows <- data.frame(
    region = c("North", "North", "South", "South", "East", "East", "West", "West"),
    year   = rep(c(2024L, 2025L), times = 4),
    sales  = c(120, 145, 200, 215, 90, 110, 175, 190),
    stringsAsFactors = FALSE
  )

  app$input("region", type = "select", label = "Region",
            choices = c("All", "North", "South", "East", "West"),
            selected = "All")

  filtered <- function(region) {
    if (identical(region, "All")) rows else rows[rows$region == region, , drop = FALSE]
  }

  # Chart: returns a SveltePlot spec (data + marks). The wire shape is
  # `{ data: [{...row...}, ...], marks: [{type, x, y, fill, ...}], ... }`.
  app$output("sales_chart", type = "chart",
             render = function(params) {
               df <- filtered(params$region)
               list(
                 data  = lapply(seq_len(nrow(df)), function(i) as.list(df[i, ])),
                 marks = list(
                   list(type = "bar",
                        x = "year", y = "sales", fill = "region")
                 ),
                 title  = "Sales by year",
                 locale = "sv-SE"
               )
             })

  # Table: returns rows + total. DataTable expects `{ rows: [...], total: N }`.
  app$output("sales_table", type = "table",
             render = function(params) {
               df <- filtered(params$region)
               list(
                 rows  = lapply(seq_len(nrow(df)), function(i) as.list(df[i, ])),
                 total = nrow(df)
               )
             })

  app$ui(ambolt::sidebar_layout(
    ambolt::sidebar("region"),
    ambolt::main(
      ambolt::page_header(title = "Sales"),
      ambolt::section("Chart", "sales_chart"),
      ambolt::section("Table", "sales_table")
    )
  ))

  app
}
