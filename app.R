# Entry point for running AI R Assistant directly from the repository.
# This allows RStudio "Run App" button to work from source checkouts.
shiny::runApp("inst/shinyapp", launch.browser = TRUE)
