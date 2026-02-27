#' AI R Assistant - RStudio Add-in
#'
#' Launches the AI R Assistant Shiny app. Works both as an installed
#' package and when run from a source checkout.
#'
#' @export
#' @examples
#' \dontrun{
#' ai_r_assistant()
#' }

ai_r_assistant <- function() {
  if (!requireNamespace("shiny", quietly = TRUE))
    stop("shiny is required: install.packages('shiny')")

  message("Launching AI R Assistant...")

  # ── 1. Best path: source app.R fresh from inst/shinyapp/ ──────────────────
  # This avoids any locked-namespace issues because the code runs in a plain
  # new environment, not the sealed package namespace.
  pkg_app <- system.file("shinyapp", package = "aiRAssistant")
  if (nzchar(pkg_app) && file.exists(file.path(pkg_app, "app.R"))) {
    shiny::runApp(pkg_app, host = "127.0.0.1", port = 5050,
                  launch.browser = TRUE)
    return(invisible(NULL))
  }

  # ── 2. Dev / source-checkout fallback: run from inst/shinyapp/ directly ─────
  dev_app <- "inst/shinyapp"
  if (dir.exists(dev_app) && file.exists(file.path(dev_app, "app.R"))) {
    shiny::runApp(dev_app, host = "127.0.0.1", port = 5050,
                  launch.browser = TRUE)
    return(invisible(NULL))
  }

  stop(
    "Could not locate the app. Install with:\n",
    "  devtools::install_github('DataConceptz/AI-R-Assistant')"
  )
}

#' Get selected code from RStudio editor
#' @export
#' @return Character string of selected code, or empty string if none.
get_rstudio_selection <- function() {
  if (!requireNamespace("rstudioapi", quietly = TRUE) ||
      !rstudioapi::isAvailable()) return("")
  context <- rstudioapi::getActiveDocumentContext()
  if (!is.null(context) && length(context$selection) > 0)
    return(context$selection[[1]]$text)
  ""
}

#' Run R code in RStudio console
#' @param code Character string of R code to run.
#' @export
run_code_in_rstudio <- function(code) {
  if (!requireNamespace("rstudioapi", quietly = TRUE) ||
      !rstudioapi::isAvailable())
    stop("RStudio is not available.")
  if (is.character(code) && length(code) == 1 &&
      !is.na(code) && nzchar(code))
    rstudioapi::sendToConsole(code, execute = TRUE)
}

#' Insert text at cursor position in RStudio editor
#' @param text Character string to insert.
#' @export
insert_text_rstudio <- function(text) {
  if (!requireNamespace("rstudioapi", quietly = TRUE) ||
      !rstudioapi::isAvailable())
    stop("RStudio is not available.")
  if (is.character(text) && length(text) == 1 &&
      !is.na(text) && nzchar(text)) {
    context <- rstudioapi::getActiveDocumentContext()
    if (!is.null(context) && length(context$selection) > 0)
      rstudioapi::insertText(
        location = context$selection[[1]]$range, text = text)
    else
      rstudioapi::insertText(text = text)
  }
}
