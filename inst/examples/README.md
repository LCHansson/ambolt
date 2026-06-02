# ambolt examples

Six bundled mini-apps that demonstrate the framework's core surface. Each
folder is a self-contained `app.R` that defines `build_app(port)` and
returns an app object you can either launch (`ambolt::run_example()`) or
inspect (`run_example("…", run = FALSE)`).

| Example | Topic | Notes |
|---------|-------|-------|
| `01-hello` | Single input → single output (`type = "html"`). The smallest meaningful app. | |
| `02-layout` | Composing the layout DSL — `page_content`, `section`, `columns`, `details`. No data flow. | |
| `03-inputs-gallery` | Every built-in input type wired to a single echo output gated by an action button. | |
| `04-chart-and-table` | A select drives a `ChartOutput` (SveltePlot spec) and a `DataTable` simultaneously. | |
| `05-auth-multipage` | `app$auth()` + `app$pages()` + `app$module()` with NavSidebar and a per-user endpoint. | **Login: `demo` / `demo`** |
| `06-modal-form` | `create_button` → `mod$modal` → `mod$post` cycle with `refresh_event` re-fetch. | |

Examples with a `NOTES.md` print it to the console at startup — so credentials, ports, and other run-time hints surface where you'll see them.

## Running

```r
library(ambolt)
list_examples()         # see the catalogue
run_example("01-hello") # blocks on the server
```

To inspect an example without serving:

```r
app <- run_example("04-chart-and-table", run = FALSE)
names(app$.outputs)
```
