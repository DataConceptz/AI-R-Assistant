# Quick test of the file
result <- try(parse(file = "R/R_AI_Assistant.R"), silent = TRUE)
if (inherits(result, "try-error")) {
  cat("PARSING FAILED\n")
} else {
  cat("PARSING SUCCESS\n")
  cat("Expressions:", length(result), "\n")
}
