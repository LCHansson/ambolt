## Surface `$` partial-match foot-guns during package development.
## R will warn instead of silently corrupting a value when `obj$foo`
## resolves via partial match to `obj$foobar`. Background: 0.1.0.9026
## fixed a length-N corruption where codegen's `f$label` partial-matched
## a new `labels` field on the same spec. See observations.md entry
## from 2026-04-15.
options(warnPartialMatchDollar = TRUE)
