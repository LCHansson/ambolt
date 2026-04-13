# ambolt

> Build web apps in R — with a modern frontend you don't have to write.

ambolt is an R package for building multi-page web applications. You
describe your UI with composable R functions, connect it to R backend
logic, and the framework takes care of the rest. If you've used Shiny,
the workflow will feel familiar — but the resulting app is a modern
single-page application with real UI components, not server-rendered
HTML strings.

## Installation

```r
# install.packages("remotes")
remotes::install_github("LCHansson/ambolt")
```

You also need [Node.js](https://nodejs.org/) (>= 18) installed — ambolt
uses it behind the scenes to build the frontend on first startup.

## Quick start

Create a file `app.R`:

```r
library(ambolt)

app <- create_app()

app$input("name", "text", label = "Your name", placeholder = "Type here...")

app$output("greeting", "html",
  depends_on = "name",
  render = function(params) {
    sprintf("<h2>Hello, %s!</h2>", params$name)
  }
)

app$run()
```

Run it with `Rscript app.R` and visit <http://localhost:3000>. You'll see
a sidebar with a text input and a content area that updates as you type.
No JavaScript, no HTML templates — just R.

## What you get

- **Multi-page apps** with sidebar navigation and URL routing
- **Built-in components**: interactive tables, stat cards, modals, forms,
  card grids, plots, and date pickers
- **Authentication** with login pages, session cookies, and rate limiting
- **Theming**: set your brand colors in one place and every component
  picks them up
- **Responsive layout** that works on desktop and mobile
- **An escape hatch** for custom HTML/JS when the built-in components
  aren't enough

## In production

[Elektrifieringskollen](https://elektrifieringskollen.se) is a fleet
electrification calculator built with ambolt — a single-page app that
compares total cost of ownership for electric vs. diesel vehicles.

## How it works

Under the hood, ambolt generates a [Svelte 5](https://svelte.dev/)
frontend from your R declarations and serves it alongside your R API
via [ambiorix](https://ambiorix.dev/). The frontend is compiled once at
startup (or rebuilt automatically in dev mode with hot reload).

You don't need to know Svelte to use ambolt — but if you do, you can
extend the 30+ built-in components in `inst/svelte/components/`.

## Learn more

- `vignette("getting-started", package = "ambolt")` — hello world through
  layout primitives
- `vignette("multi-page-with-auth", package = "ambolt")` — pages, modules,
  modals, authentication, and theming
- [Changelog](NEWS.md)
- [Contributing](CONTRIBUTING.md)

## License

[MIT](LICENSE.md)
