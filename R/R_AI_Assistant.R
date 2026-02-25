# AI R Assistant - Dev/source-checkout wrapper
# This file sources the canonical app.R from inst/shinyapp/ so there's
# only ONE copy of the app code to maintain.
#
# When installed as a package, addin-functions.R uses system.file() to
# find inst/shinyapp/app.R directly. This file is only used as a fallback
# when running from a source checkout (e.g., devtools::load_all()).

# Find app.R relative to this file's location
.app_path <- file.path(dirname(sys.frame(1)$ofile %||% "."), "..", "inst", "shinyapp", "app.R")
if (!file.exists(.app_path)) {
  # Try from working directory (common for devtools::load_all or source checkout)
  .app_path <- file.path("inst", "shinyapp", "app.R")
}
if (!file.exists(.app_path)) {
  stop("Cannot find inst/shinyapp/app.R. Run from the package root directory or install the package.")
}

# Source the canonical app.R — this defines ui, server, and calls shinyApp()
# when run standalone, but when sourced into an environment the ui/server
# objects are available for addin-functions.R to use.
source(.app_path, local = TRUE)
