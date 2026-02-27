# Contributing to AI-R-Assistant

Thank you for your interest in improving **AI-R-Assistant**.

## How to Contribute

1. Fork this repository (or create a branch if you have direct access).
2. Create a focused feature branch:
   - `feature/<short-description>`
   - `fix/<short-description>`
3. Make your change with clear, minimal commits.
4. Run checks (see below).
5. Open a pull request with:
   - What changed
   - Why it changed
   - How it was tested

## Development Setup

1. Install R (>= 4.2 recommended) and RStudio.
2. Install required packages:

```r
install.packages(c(
  "shiny", "httr", "jsonlite", "shinyAce", "keyring",
  "memoise", "rintrojs", "rstudioapi", "ggplot2"
))
```

3. From the project root, run the app from source:

```r
shiny::runApp("inst/shinyapp")
```

## Validation Checklist

Before submitting a PR, verify:

- [ ] `inst/shinyapp/app.R` parses successfully
- [ ] Add-in entrypoint still works (`aiRAssistant::ai_r_assistant()`)
- [ ] New UI/server behavior is manually tested
- [ ] README and docs are updated if behavior changed

Quick parse check:

```r
source("quick_test.R")
```

## Coding Guidelines

- Keep fixes small and targeted.
- Prefer explicit namespaces (e.g., `shiny::runApp`).
- Avoid hardcoding secrets or API keys.
- Add comments only where logic is non-obvious.

## Reporting Issues

Use GitHub Issues and include:

- Steps to reproduce
- Expected behavior
- Actual behavior
- Session info (`sessionInfo()`)
- Relevant screenshots/log output
