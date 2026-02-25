# Direct app launcher for R-Assistant
# Run this to launch the app with current source code, bypassing any installed package issues.

# Source into a clean environment so the package namespace guard doesn't block shinyApp creation
app_env <- new.env(parent = globalenv())
sys.source("R/R_AI_Assistant.R", envir = app_env)
app <- shiny::shinyApp(ui = app_env$ui, server = app_env$server)
shiny::runApp(app, host = "127.0.0.1", port = 5050, launch.browser = TRUE)