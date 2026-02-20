\name{ai_r_assistant}
\alias{ai_r_assistant}
\alias{get_rstudio_selection}
\alias{run_code_in_rstudio}
\alias{insert_text_rstudio}
\title{RStudio Add-in Helpers for AI R Assistant}
\description{
Launch the AI R Assistant add-in and helper utilities that integrate with the RStudio editor.
}
\usage{
ai_r_assistant()

get_rstudio_selection()

run_code_in_rstudio(code)

insert_text_rstudio(text)
}
\arguments{
  \item{code}{Character string of R code to run in the RStudio console.}
  \item{text}{Character string to insert into the active RStudio editor.}
}
\value{
\code{ai_r_assistant()} launches the Shiny app and returns invisibly.
\code{get_rstudio_selection()} returns a character string (possibly empty).
Other helpers are called for side effects.
}
\details{
These functions require \pkg{rstudioapi} and an active RStudio session.
}
\examples{
\dontrun{
ai_r_assistant()
code <- get_rstudio_selection()
run_code_in_rstudio("summary(mtcars)")
insert_text_rstudio("\n# Added by AI R Assistant\n")
}
}
