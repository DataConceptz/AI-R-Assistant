# AI-R-Assistant

AI-R-Assistant is an enterprise-grade Shiny application and RStudio add-in for AI-assisted R development. It combines code authoring, execution, visualization, and model-assisted reasoning in one interface.

## What this project delivers

- Local-first AI with Ollama as the default provider
- Optional cloud model providers: OpenAI, Anthropic, and Gemini
- Rich R editor with syntax highlighting, shortcuts, and template workflows
- Built-in console and plot surfaces (ggplot2 and Plotly)
- Plot popout viewer with fullscreen mode
- Streaming model responses (when `curl` is installed)
- RStudio add-in entrypoint for direct launch from IDE
- Keyring and environment variable support for API credentials

## Architecture

- App entrypoint and UI/server definitions: `R/R_AI_Assistant.R`
- RStudio add-in functions: `R/addin-functions.R`
- Add-in registration: `inst/rstudio/addins.dcf`
- Package metadata: `DESCRIPTION`, `NAMESPACE`

## Prerequisites

- R 4.2 or newer
- RStudio (for add-in usage)
- Ollama running locally for default workflow (`http://localhost:11434`)

Optional:
- `plotly`, `viridis`, `patchwork`, `scales`, `corrplot`, `curl`, `htmlwidgets`

## Quick start (source checkout)

1. Clone repository:

```bash
git clone https://github.com/DataConceptz/R-Assistant.git
cd R-Assistant
```

2. Install dependencies in R:

```r
install.packages(c(
  "shiny",
  "httr",
  "jsonlite",
  "shinyAce",
  "keyring",
  "memoise",
  "shinyBS",
  "rintrojs",
  "rstudioapi",
  "digest",
  "ggplot2"
))

install.packages(c(
  "plotly", "viridis", "patchwork", "scales",
  "corrplot", "curl", "htmlwidgets"
))
```

3. Run from source:

```r
source("R/R_AI_Assistant.R")
shiny::runApp(shiny::shinyApp(ui = ui, server = server))
```

## Install in RStudio with devtools

### Install directly from GitHub

```r
install.packages("devtools")
devtools::install_github("DataConceptz/AI-R-Assistant", upgrade = "never")
```

### Launch add-in after install

```r
aiRAssistant::ai_r_assistant()
```

In RStudio UI:
`Tools -> Addins -> Browse Addins -> AI R Assistant`

## Troubleshooting

### Installation Issues
If you encounter errors during installation or launching, first install the required dependencies:

```r
install.packages(c(
  "promises", "shiny", "httr", "jsonlite", "shinyAce", "keyring", "memoise",
  "shinyBS", "rintrojs", "rstudioapi", "digest", "ggplot2"
))
```

Then install the package:

```r
install.packages("devtools")
devtools::install_github("DataConceptz/AI-R-Assistant", upgrade = "never")
```

If you see `namespace 'promises' 1.3.3 is already loaded, but >= 1.5.0 is required`, install from a fresh R session (not the current RStudio session):

```r
system2(
  file.path(R.home("bin"), "Rscript"),
  c(
    "--vanilla",
    "-e",
    shQuote("install.packages('promises', repos='https://cran.rstudio.com/'); remotes::install_github('DataConceptz/AI-R-Assistant', upgrade='never')")
  )
)
```

Then restart RStudio and run:

```r
aiRAssistant::ai_r_assistant()
```

### Launching Issues
If the add-in fails to launch with "could not find function" errors, try running from source:

```r
source("R/R_AI_Assistant.R")
shiny::runApp(shiny::shinyApp(ui = ui, server = server), port = 5050)
```

Ensure Ollama is running locally if using local models.

## Model configuration

### Ollama (default)

- Default URL: `http://localhost:11434`
- Supports model refresh and connection testing from settings

Installing Ollama & Pulling Models — Detailed Guide
1. Install Ollama

WINDOWS
- Go to https://ollama.com/download
- Click Download for Windows — downloads OllamaSetup.exe 
- Run the installer (no admin required; installs to %LOCALAPPDATA%\Programs\Ollama)
- Ollama starts automatically as a background service (system tray icon appears)

Verify: open PowerShell and run:
powershell
ollama --version

MACOS
- Download the .zip from https://ollama.com/download
- Unzip → drag Ollama.app to /Applications
- Launch the app (menu bar icon appears)
Verify:
bash
ollama --version

LINUX
bash
- curl -fsSL https://ollama.com/install.sh | sh # Installs the ollama binary and registers a systemd service
- Service starts automatically; verify with:

bash
systemctl status ollama
ollama --version

2. Verify the Ollama Server is Running
- Ollama runs a local REST API on port 11434 by default.

powershell
# PowerShell / bash
curl http://localhost:11434

# Expected: "Ollama is running"
Or check via browser: http://localhost:11434

3. Browse Available Models
Visit the Ollama model library: https://ollama.com/library

4. Pull (Download) a Model
powershell
ollama pull <model-name>:<tag>

Examples
powershell
# Pull default (latest) tag
ollama pull llama3.2
 
# Pull a specific size variant
ollama pull llama3.1:8b
ollama pull mistral:7b
ollama pull gemma3:4b
 
# Pull a coding model
ollama pull codellama:7b
 
# Pull an embedding model (for RAG apps)
- ollama pull nomic-embed-text
- Progress bar shows download status
- Models are stored in %USERPROFILE%\.ollama\models (Windows) or ~/.ollama/models (Linux/macOS)

# Pull a cloud model 
If you do not have too much storage on and still want a model that generate fast response, I encourage you to pull Ollama cloud models:
https://ollama.com/search?c=cloud

However, you WOULD HAVE TO LOGIN TO OLLAMA TO USE THE CLOUD MODELS. They are pretty generous with the cloud models. This is the only time you would have to login to Ollama. Other local models do not require login.

5. Run / Test a Model
powershell
# Interactive chat in terminal
ollama run llama3.2
 
# One-shot prompt
ollama run mistral "Explain photosynthesis in 2 sentences"
- Type /bye or press Ctrl+D to exit the chat.

6. Manage Models
powershell
# List all downloaded models
ollama list
 
# Show model details/metadata
ollama show llama3.2
 
# Remove a model (frees disk space)
ollama rm llama3.2:latest
 
# Copy/rename a model
ollama cp llama3.2 my-custom-llama

### Cloud providers
Supported providers:
- OpenAI
- Anthropic
- Gemini

Credentials can be supplied either in-app, by env var, or keyring:
- OpenAI: `OPENAI_API_KEY` or keyring key `openai_api_key`
- Anthropic: `ANTHROPIC_API_KEY` or keyring key `anthropic_api_key`
- Gemini: `GEMINI_API_KEY` or keyring key `gemini_api_key`

## Usage flow

1. Select model provider and model.
2. Write or paste code in the editor.
3. Run code with `Ctrl+Enter` or action buttons.
4. Ask for explain/debug/optimize/document assistance.
5. Review plots in the Plot tab or pop out to fullscreen.
6. Insert AI-generated code back into the editor when needed.

## File tree

```
R-Assistant/
|-- R/
|   |-- R_AI_Assistant.R
|   `-- addin-functions.R
|-- inst/
|   `-- rstudio/
|       `-- addins.dcf
|-- DESCRIPTION
|-- NAMESPACE
|-- README.md
|-- CHANGELOG.md
|-- CONTRIBUTING.md
|-- SECURITY.md
`-- quick_test.R
```

## Troubleshooting

### Ollama not detected

```r
httr::GET("http://localhost:11434/api/tags")
```

If endpoint is not reachable, start Ollama service and retry.

### Add-in not visible in RStudio

- Reinstall package with `devtools::install_local(...)`
- Restart RStudio
- Check `inst/rstudio/addins.dcf` exists in installed package

### Parse check

```r
source("quick_test.R")
```

## Security and governance

- No telemetry is required for core functionality.
- Local Ollama mode keeps prompts/code on local machine.
- Optional cloud traffic uses HTTPS endpoints.
- See `SECURITY.md` for reporting workflow.

## Contributing

Contributions are welcome. Review:
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`

## License

MIT. See `LICENSE`.
