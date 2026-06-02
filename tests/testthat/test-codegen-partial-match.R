## Empirical audit for `$` partial-match risk in codegen.
##
## Background: v0.1.0.9026 fixed a length-N corruption where
## `.generate_module_output_script`'s cards branch used `f$label` on a
## spec list that *also* defined a `labels` map. R's default partial
## matching silently rewrote `f$label` to the 15-element `labels` vector,
## and `parts` was recycled. The targeted fix converted the cards branch
## to `f[["X"]]`.
##
## This test runs codegen against specs that intentionally include
## colliding-prefix fields across all module output types (table, cards,
## stats). With `options(warnPartialMatchDollar = TRUE)` set in
## helper-options.R, any remaining partial-match site emits a warning
## that `expect_no_warning()` traps.

test_that("module output codegen survives prefix-colliding spec fields (cards)", {
  module_outputs <- list(
    list(
      id = "test/cards",
      module_id = "test",
      output_id = "cards",
      type = "cards",
      card = list(
        title = "title",
        subtitle = "subtitle",
        badge = "b",
        badge_label = "bl",
        badge_color = "bc",
        footer = "f",
        border_color = "bdc",
        icon = "ic",
        ## NOTE: `fields` is iterated as `f` inside codegen.  We craft
        ## fields with prefix collisions: `label` vs `labels`, `key` vs
        ## `class_key`, `badge` vs `badge_color_key`, `colors` vs `class`.
        fields = list(
          list(
            key = "k1",
            icon = "i",
            link = "l",
            label = "L",
            labels = list(a = "A", b = "B"),
            badge = TRUE,
            badge_color_key = "bck",
            class_key = "ck",
            render = "badges",
            colors = list(x = "red")
          )
        )
      ),
      group_by = list(
        default = "k1",
        options = list(k1 = "K1"),
        label = "Group",
        expand_all_label = "exp",
        collapse_all_label = "col",
        collapsible = TRUE
      ),
      filters = list(
        ## Filter spec: `key` vs `class_key` is not in API but we add a
        ## phantom `keys` to bait the partial-match heuristic, plus the
        ## known `label`/`labels` and `min_match` family.
        list(
          key = "fk",
          keys = c("a", "b"),
          label = "FL",
          labels = list(x = "X"),
          min_match = TRUE,
          min = 1L,
          toggle = FALSE,
          choices = list(list(value = "v", label = "V"))
        )
      ),
      favorite = list(key = "fav", id_key = "id", id = "i", endpoint = "/e"),
      contact_action = list(
        event = "ev",
        events = list("e2"),
        name_key = "nk",
        name = "n",
        party_key = "pk",
        party = "p",
        modal_template = "m",
        modal = "m"
      ),
      labels = list(a = "A"),
      on_click = list(
        modal = "test/m",
        modal_template = "mt",
        params = list(x = "1"),
        size = "sm",
        sizes = c("sm", "md")
      )
    )
  )

  expect_no_warning(
    out <- .generate_module_output_script(module_outputs)
  )
  expect_type(out, "character")
  expect_true(length(out) > 0)
})

test_that("module output codegen survives prefix-colliding spec fields (table)", {
  module_outputs <- list(
    list(
      id = "test/table",
      module_id = "test",
      output_id = "table",
      type = "table",
      columns = list(
        list(
          key = "c1",
          keys = c("a"),
          label = "L",
          labels = list(x = "X"),
          sortable = TRUE,
          render = "text",
          edit_endpoint = "/e",
          edit_choices = list(list(value = "v", label = "V")),
          edit = "inline"
        )
      ),
      filters = list(
        list(id = "f1", ids = c("a"))
      ),
      on_select = list(
        modal = "m",
        modal_template = "mt",
        params = list(x = "row.k"),
        size = "sm",
        sizes = c("sm"),
        event = "e",
        events = list("e2"),
        navigate = "p",
        navigation = "n"
      )
    )
  )

  expect_no_warning(
    out <- .generate_module_output_script(module_outputs)
  )
  expect_type(out, "character")
})

test_that("module output codegen survives prefix-colliding spec fields (stats)", {
  module_outputs <- list(
    list(
      id = "test/stats",
      module_id = "test",
      output_id = "stats",
      type = "stats",
      cards = list(
        list(
          key = "k1",
          keys = c("a"),
          label = "L",
          labels = list(x = "X"),
          color = "blue",
          colors = list(x = "red"),
          icon = "i",
          icons = list()
        )
      )
    )
  )

  expect_no_warning(
    out <- .generate_module_output_script(module_outputs)
  )
  expect_type(out, "character")
})

test_that("scenario generation survives prefix-colliding value keys", {
  scenarios <- list(
    list(
      name = "A",
      names = c("X"),
      values = list(speed = 100, speed_unit = "km/h", name = "x", names = c("y"))
    )
  )
  expect_no_warning(
    out <- .generate_scenario_functions(scenarios)
  )
  expect_type(out, "character")
})

test_that("validation derived survives prefix-colliding input args", {
  inputs <- list(
    list(
      id = "go",
      type = "action",
      args = list(
        requires = c("a", "b"),
        require = "phantom",
        requires_all = TRUE,
        label = "Go",
        labels = c("Go!")
      )
    )
  )
  expect_no_warning(
    out <- .generate_validation_deriveds(inputs)
  )
  expect_type(out, "character")
})
