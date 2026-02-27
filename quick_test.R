# Quick syntax check for the app
result <- try(parse(file = "inst/shinyapp/app.R"), silent = TRUE)
if (inherits(result, "try-error")) {
  cat("PARSING FAILED\n")
  cat(attr(result, "condition")$message, "\n")
} else {
  cat("PARSING SUCCESS\n")
  cat("Expressions:", length(result), "\n")
}
