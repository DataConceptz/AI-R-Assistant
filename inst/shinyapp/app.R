# AI R Assistant v1.0.0 - Enhanced with Ollama & Advanced Charts
# Production-ready with Ollama local models (default), optional cloud providers, caching, i18n, and advanced visualizations
# Prereqs: install.packages(c("shiny","shinyAce","httr","jsonlite","memoise","keyring","rintrojs","ggplot2","plotly","viridis","patchwork","scales","corrplot","curl"))

# When running from source (not as installed package), load required libraries.
# When installed as a package, the NAMESPACE file handles all imports automatically.
if (!isNamespaceLoaded("aiRAssistant")) {
  library(shiny)
  library(shinyAce)
  library(httr)
  library(jsonlite)
  library(memoise)
  library(keyring)
  library(rintrojs)
  library(ggplot2)

  # Optional: Load if available for enhanced features
  tryCatch({ library(plotly) }, error = function(e) message("plotly not installed - interactive charts disabled"))
  tryCatch({ library(viridis) }, error = function(e) message("viridis not installed - using default colors"))
  tryCatch({ library(patchwork) }, error = function(e) message("patchwork not installed - multi-panel layouts limited"))
  tryCatch({ library(scales) }, error = function(e) message("scales not installed"))
  tryCatch({ library(corrplot) }, error = function(e) message("corrplot not installed"))
  tryCatch({ library(curl) }, error = function(e) message("curl not installed - streaming disabled"))
}

# Stage 3: Full i18n (EN/ES)
translations_en <- list(
  app_title = "AI R Assistant",
  model_label = "Model:",
  templates_label = "Templates:",
  api_label = "API Key (env/secure):",
  ollama_url_label = "Ollama URL:",
  language_label = "Language:",
  run_label = "Run Code",
  explain_label = "Explain",
  debug_label = "Debug",
  optimize_label = "Optimize",
  document_label = "Document",
  test_label = "Write Tests",
  chart_help_label = "Chart Help",
  chat_title = "AI Assistant",
  output_label = "Code Output",
  plot_output_label = "Plot Output",
  welcome = "Welcome! This AI assistant helps with R coding. Select a model (cloud or local Ollama), write code, and ask questions.",
  api_missing = "API key missing. Set the appropriate env var or use keyring for cloud providers.",
  ollama_error = "Ollama connection failed. Ensure Ollama is running at the specified URL.",
  api_calling = "Calling AI API...",
  api_error = "API Error:",
  run_done = "Code executed successfully",
  run_error = "Execution error:",
  template_loaded = "Template loaded",
  privacy_note = "Your code and API key are secure. Data transmitted over HTTPS (cloud) or stays local (Ollama).",
  onboarding_title = "Welcome Tour",
  model_type_label = "Model Type:",
  cloud_models = "Cloud (OpenAI/Anthropic/Gemini)",
  local_models = "Local (Ollama)",
  chart_templates = "Chart Templates",
  data_templates = "Data Templates"
)

translations_es <- list(
  app_title = "AI R Assistant",
  model_label = "Modelo:",
  templates_label = "Plantillas:",
  api_label = "Clave API (segura):",
  ollama_url_label = "URL de Ollama:",
  language_label = "Idioma:",
  run_label = "Ejecutar",
  explain_label = "Explicar",
  debug_label = "Depurar",
  optimize_label = "Optimizar",
  document_label = "Documentar",
  test_label = "Tests",
  chart_help_label = "Ayuda Gráficos",
  chat_title = "Asistente IA",
  output_label = "Salida de Código",
  plot_output_label = "Salida de Gráfico",
  welcome = "¡Bienvenido! Este asistente IA ayuda con R. Selecciona un modelo (nube u Ollama local), escribe código y haz preguntas.",
  api_missing = "Clave API ausente. Configure la variable de entorno o use keyring.",
  ollama_error = "Conexión Ollama fallida. Asegúrese que Ollama esté ejecutándose.",
  api_calling = "Llamando a la API de IA...",
  api_error = "Error de API:",
  run_done = "Código ejecutado exitosamente",
  run_error = "Error de ejecución:",
  template_loaded = "Plantilla cargada",
  privacy_note = "Tu código y clave API están seguros. Datos via HTTPS (nube) o local (Ollama).",
  onboarding_title = "Tour de Bienvenida",
  model_type_label = "Tipo de Modelo:",
  cloud_models = "Nube (OpenAI/Anthropic/Gemini)",
  local_models = "Local (Ollama)",
  chart_templates = "Plantillas de Gráficos",
  data_templates = "Plantillas de Datos"
)

`%||%` <- function(a, b) if (!is.null(a)) a else b
# lang and translate are initialised here for source() usage;
# the server function overrides lang with a session-scoped reactiveVal.
lang <- reactiveVal("en")
translate <- function(k) {
  cur <- tryCatch(lang(), error = function(e) "en")
  if (identical(cur, "es")) {
    v <- translations_es[[k]]
    if (!is.null(v)) return(v)
  }
  translations_en[[k]] %||% k
}

# Polished UI with better layout and styling
ui <- fluidPage(
  rintrojs::introjsUI(),
  tags$head(tags$style(HTML("
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700&display=swap');
    * { box-sizing: border-box; }
    html, body { height: 100%; }
    body { background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); color: #e0e0e0; font-family: 'JetBrains Mono', monospace; margin: 0; padding: 0; display: flex; flex-direction: column; }
    .container, .container-fluid { width: 100% !important; max-width: 100% !important; padding: 0 !important; margin: 0 !important; }
    body > .container-fluid { height: 100vh; min-height: 100vh; width: 100% !important; max-width: 100% !important; display: flex; flex-direction: column; overflow: hidden; padding: 0 !important; }
    .header-section { background: linear-gradient(90deg, #0f0f1e 0%, #1a1a2e 100%); border-bottom: 3px solid #00d4ff; padding: 12px 25px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 4px 20px rgba(0,0,0,0.5); flex: 0 0 auto; width: 100% !important; }
    .header-title { font-size: 22px; font-weight: 700; background: linear-gradient(90deg, #00d4ff 0%, #00ffaa 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin: 0; }
    .header-subtitle { color: #d6dde8; font-size: 11px; margin-top: 2px; }
    .header-controls { display: flex; gap: 8px; align-items: center; }
    /* Use fr tracks so the splitter + gaps are accounted for (avoids horizontal overflow/clipped borders). */
    .main-content { display: grid; grid-template-columns: minmax(360px, var(--left-track, 1fr)) 6px minmax(360px, var(--right-track, 1fr)); grid-template-rows: 1fr; gap: 12px; flex: 1 1 0; min-height: 0; padding: 12px; align-content: stretch; align-items: stretch; width: 100% !important; max-width: 100% !important; box-sizing: border-box; }
    @media (max-width: 900px) { .main-content { grid-template-columns: 1fr; } .splitter { display: none; } }
    .splitter { background: linear-gradient(180deg, rgba(0, 212, 255, 0.2), rgba(0, 212, 255, 0.05)); border-radius: 6px; cursor: col-resize; position: relative; min-width: 6px; }
    .splitter::before { content: ''; position: absolute; inset: 0 -8px; z-index: 10; cursor: col-resize; }
    .splitter:hover, .splitter:active { background: linear-gradient(180deg, rgba(0, 212, 255, 0.5), rgba(0, 212, 255, 0.15)); }
    .settings-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.7); z-index: 1000; align-items: center; justify-content: center; }
    .settings-overlay.visible { display: flex; }
    .settings-modal { background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border: 2px solid #00d4ff; border-radius: 12px; padding: 18px; width: 1000px; max-width: 95%; max-height: 85vh; overflow-y: auto; box-shadow: 0 8px 32px rgba(0, 212, 255, 0.35); }
    .settings-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; padding-bottom: 10px; border-bottom: 1px solid #2a2a3e; }
    .settings-title { color: #00d4ff; font-size: 16px; font-weight: 700; margin: 0; }
    .settings-close { background: transparent; border: 1px solid #ff5555; color: #ff5555; padding: 5px 12px; border-radius: 4px; cursor: pointer; font-size: 12px; transition: all 0.2s; }
    .settings-close:hover { background: rgba(255, 85, 85, 0.2); }
    .help-overlay { display: none; position: fixed; inset: 0; background: rgba(0, 0, 0, 0.76); z-index: 1050; align-items: center; justify-content: center; padding: 14px; }
    .help-overlay.visible { display: flex; }
    .help-modal { background: linear-gradient(135deg, #101427 0%, #16213e 100%); border: 2px solid #00d4ff; border-radius: 12px; width: min(1300px, 97vw); max-height: 92vh; display: flex; flex-direction: column; box-shadow: 0 12px 40px rgba(0, 212, 255, 0.28); }
    .help-header { display: flex; justify-content: space-between; align-items: center; gap: 10px; padding: 14px 16px; border-bottom: 1px solid #2a2a3e; }
    .help-title { color: #00d4ff; font-size: 17px; font-weight: 700; margin: 0; }
    .help-subtitle { color: #d0d7e2; font-size: 11px; margin-top: 4px; }
    .help-layout { display: grid; grid-template-columns: 260px minmax(0, 1fr); min-height: 0; flex: 1 1 auto; }
    .help-sidebar { border-right: 1px solid #2a2a3e; padding: 12px; overflow-y: auto; background: rgba(10, 15, 30, 0.55); }
    .help-nav-link { width: 100%; text-align: left; border: 1px solid #2a2a3e; background: rgba(0, 212, 255, 0.05); color: #d0d7e2; border-radius: 7px; padding: 8px 10px; margin-bottom: 6px; cursor: pointer; font-family: 'JetBrains Mono', monospace; font-size: 11px; transition: all 0.2s; }
    .help-nav-link:hover { border-color: #00d4ff; color: #00d4ff; }
    .help-nav-link.active { border-color: #00ffaa; color: #00ffaa; background: rgba(0, 255, 170, 0.12); }
    .help-content { padding: 14px 18px; overflow-y: auto; }
    .help-section { margin-bottom: 20px; padding: 12px; border: 1px solid rgba(0, 212, 255, 0.2); border-radius: 8px; background: rgba(15, 23, 42, 0.55); scroll-margin-top: 10px; }
    .help-section h4 { color: #00d4ff; margin: 0 0 8px 0; font-size: 14px; }
    .help-section p { color: #eaf2ff; font-size: 12px; margin: 0 0 8px 0; line-height: 1.45; }
    .help-section ul { margin: 0 0 8px 18px; padding: 0; }
    .help-section li { color: #eaf2ff; font-size: 12px; margin-bottom: 5px; line-height: 1.45; }
    .help-code { background: rgba(0, 0, 0, 0.28); border: 1px solid rgba(0, 212, 255, 0.22); border-radius: 6px; padding: 9px; color: #f8fafc; font-size: 11px; line-height: 1.35; white-space: pre-wrap; }
    @media (max-width: 950px) {
      .help-layout { grid-template-columns: 1fr; }
      .help-sidebar { border-right: none; border-bottom: 1px solid #2a2a3e; max-height: 160px; }
    }
    .settings-grid { display: grid; grid-template-columns: repeat(12, 1fr); gap: 12px; }
    .settings-block { grid-column: span 6; background: rgba(15, 23, 42, 0.65); border: 1px solid #2a2a3e; border-radius: 8px; padding: 10px 12px; }
    .settings-block.full { grid-column: span 12; }
    @media (max-width: 900px) { .settings-block { grid-column: span 12; } }
    .editor-panel { background: #0f0f1e; border: 2px solid #00d4ff; border-radius: 10px; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 8px 32px rgba(0,212,255,0.2); height: 100%; min-height: 0; width: 100% !important; }
    .chat-panel { background: #16213e; border: 2px solid #00a8cc; border-radius: 10px; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 8px 32px rgba(0,168,204,0.2); height: 100%; min-height: 0; width: 100% !important; }
    .panel-header { padding: 10px 15px; background: linear-gradient(90deg, #1a1a2e 0%, #16213e 100%); border-bottom: 1px solid #2a2a3e; display: flex; justify-content: space-between; align-items: center; flex: 0 0 auto; }
    .panel-title { color: #00d4ff; font-size: 15px; font-weight: 600; margin: 0; }
    .panel-body { flex: 1 1 auto; min-height: 0; padding: 12px; display: flex; flex-direction: column; gap: 8px; overflow-y: auto; }
    .editor-body { flex: 1 1 0; min-height: 0; display: flex; flex-direction: column; overflow: hidden; }
    .editor-top-area { flex: 1 1 0; min-height: 0; display: flex; flex-direction: column; overflow: hidden; }
    .editor-tabs { display: flex; gap: 8px; padding: 8px 12px 0; flex: 0 0 auto; }
    .editor-tab { padding: 6px 12px; cursor: pointer; font-size: 12px; color: #d0d7e2; border: 1px solid #2a2a3e; border-radius: 6px; background: rgba(0, 212, 255, 0.05); transition: all 0.2s; }
    .editor-tab:hover { color: #00d4ff; border-color: #00d4ff; }
    .editor-tab.active { color: #00ffaa; border-color: #00ffaa; background: rgba(0, 255, 170, 0.12); }
    .editor-tab-content { flex: 1 1 0; min-height: 0; padding: 8px 12px 10px; display: flex; overflow: hidden; }
    .editor-tab-pane { display: none; flex: 1 1 0; min-height: 0; width: 100%; overflow: hidden; }
    .editor-tab-pane.active { display: flex; flex-direction: column; gap: 8px; flex: 1 1 0; min-height: 0; overflow: hidden; }
    .editor-ace-wrap { flex: 1 1 0; min-height: 0; border: 1px solid #2a2a3e; border-radius: 8px; overflow: hidden; }
    .editor-ace-wrap .shiny-input-container { height: 100% !important; display: block !important; }
    .editor-ace-wrap .ace_editor { height: 100% !important; }
    .plot-pane { flex: 1 1 auto; min-height: 0; background: #0a0a14; border: 1px solid #2a2a3e; border-radius: 8px; padding: 10px; display: flex; flex-direction: column; }
    .plot-pane .plot-toolbar { flex: 0 0 auto; }
    .plot-pane .plot-canvas { flex: 1 1 auto; min-height: 0; }
    .plot-pane .plot-canvas .shiny-plot-output { height: 100% !important; width: 100% !important; }
    .plot-pane .plot-canvas .shiny-plot-output img { width: 100% !important; height: 100% !important; object-fit: contain; }
    /* Prevent Shiny's grey-out overlay during plot recalculation */
    .plot-pane .shiny-plot-output.recalculating { opacity: 1 !important; }
    .plot-pane .plotly.recalculating { opacity: 1 !important; }
    .plot-pane .plot-canvas .plotly, .plot-pane .plot-canvas .html-widget { height: 100% !important; width: 100% !important; }
    /* Data tab DT dark theme */
    #data_tab .dataTables_wrapper { color: #e0e0e0 !important; }
    #data_tab table.dataTable { background: #1a1a2e !important; color: #e0e0e0 !important; border-color: #2a2a3e !important; }
    #data_tab table.dataTable thead th { background: #16213e !important; color: #00d4ff !important; border-color: #2a2a3e !important; }
    #data_tab table.dataTable tbody tr { background: #1a1a2e !important; }
    #data_tab table.dataTable tbody tr:hover { background: #2a2a4e !important; }
    #data_tab table.dataTable tbody td { border-color: #2a2a3e !important; }
    #data_tab .dataTables_info, #data_tab .dataTables_length, #data_tab .dataTables_filter { color: #888 !important; }
    #data_tab .dataTables_filter input { background: #16213e !important; color: #e0e0e0 !important; border: 1px solid #2a2a3e !important; border-radius: 4px; padding: 4px 8px; }
    #data_tab .dataTables_paginate .paginate_button { color: #e0e0e0 !important; background: #16213e !important; border-color: #2a2a3e !important; }
    #data_tab .dataTables_paginate .paginate_button.current { background: #00d4ff !important; color: #000 !important; }
    #data_tab .form-group { margin-bottom: 0; }
    #data_tab .btn-file { background: #16213e; color: #00d4ff; border: 1px solid #2a2a3e; }
    /* Diff view styles */
    .diff-container { font-family: 'Fira Code', 'Consolas', monospace; font-size: 12px; line-height: 1.5; overflow: auto; padding: 10px; background: #0d0d1a; border-radius: 6px; height: 100%; }
    .diff-line { padding: 1px 8px; white-space: pre-wrap; word-break: break-all; }
    .diff-add { background: rgba(0, 255, 100, 0.12); color: #a0ffb0; border-left: 3px solid #00ff64; }
    .diff-del { background: rgba(255, 60, 60, 0.12); color: #ffb0b0; border-left: 3px solid #ff3c3c; }
    .diff-ctx { color: #888; border-left: 3px solid transparent; }
    .diff-header { color: #00d4ff; font-weight: bold; padding: 6px 8px; border-bottom: 1px solid #2a2a3e; margin-bottom: 6px; }
    .diff-empty { color: #666; padding: 20px; text-align: center; font-style: italic; }
    #plotly_display { display: none; }
    #plotly_display_popout { display: none; }
    .plot-popout .modal-dialog { width: 85vw; max-width: 1200px; }
    .plot-popout .modal-content { background: #0f0f1e; border: 2px solid #00d4ff; color: #e0e0e0; }
    .plot-popout .modal-header { border-bottom: 1px solid #2a2a3e; }
    .plot-popout .modal-body { height: 70vh; min-height: 400px; padding: 10px; display: flex; flex-direction: column; }
    .plot-popout .modal-body > div { flex: 1; min-height: 0; display: flex; flex-direction: column; }
    .plot-popout .shiny-plot-output { flex: 1; min-height: 300px; width: 100% !important; }
    .plot-popout .shiny-plot-output img { width: 100% !important; height: 100% !important; object-fit: contain; }
    .plot-popout .plotly, .plot-popout .html-widget { flex: 1; min-height: 300px; width: 100% !important; }
    .modal.modal-fullscreen .modal-dialog { width: 100vw !important; max-width: 100vw !important; height: 100vh !important; margin: 0 !important; }
    .modal.modal-fullscreen .modal-content { height: 100vh !important; border-radius: 0 !important; }
    .modal.modal-fullscreen .modal-body { height: calc(100vh - 110px) !important; min-height: unset !important; overflow: auto !important; display: flex !important; align-items: center !important; justify-content: center !important; padding: 20px !important; }
    .modal.modal-fullscreen .modal-body > div { width: 100% !important; height: 100% !important; min-height: unset !important; max-height: 100% !important; display: flex !important; align-items: stretch !important; justify-content: center !important; flex-direction: column !important; }
    .modal.modal-fullscreen #popout_plot_container { height: 100% !important; min-height: unset !important; max-height: 100% !important; }
    .modal.modal-fullscreen .shiny-plot-output { min-height: unset !important; height: 100% !important; width: 100% !important; flex: 1 !important; }
    .modal.modal-fullscreen .shiny-plot-output img { width: 100% !important; height: 100% !important; object-fit: contain !important; }
    .modal.modal-fullscreen .plotly, .modal.modal-fullscreen .html-widget { min-height: unset !important; height: 100% !important; width: 100% !important; flex: 1 !important; }
    .btn-fullscreen { background: rgba(0, 212, 255, 0.15); border: 1px solid #00d4ff; color: #00d4ff; padding: 6px 12px; border-radius: 6px; font-size: 12px; }
    .plot-toolbar { display: flex; gap: 6px; align-items: center; margin-bottom: 8px; flex-wrap: wrap; }
    .plot-toolbar-right { margin-left: auto; display: flex; gap: 6px; align-items: center; }
    .plot-toolbar .form-group { margin-bottom: 0; margin-top: 0; }
    .plot-toolbar .selectize-control { margin-bottom: 0; }
    .plot-toolbar .selectize-input { background: rgba(0, 212, 255, 0.15) !important; border: 1px solid #00d4ff !important; color: #00d4ff !important; font-size: 11px; font-weight: 600; font-family: 'JetBrains Mono', monospace; min-height: 31px !important; padding: 5px 8px !important; border-radius: 6px !important; box-shadow: none !important; line-height: 20px !important; }
    .plot-toolbar .selectize-input .item { color: #00d4ff !important; }
    .plot-toolbar .selectize-dropdown { background: #1a1a2e !important; border: 1px solid #00d4ff !important; border-radius: 6px !important; z-index: 10001 !important; }
    .plot-toolbar .selectize-dropdown .option { color: #e0e0e0; padding: 6px 10px; font-size: 11px; }
    .plot-toolbar .selectize-dropdown .option:hover { background: rgba(0, 212, 255, 0.2) !important; color: #00d4ff !important; }
    .toolbar-dropdown { position: relative; display: inline-block; }
    .toolbar-dropdown .dropdown-menu { display: none; position: absolute; top: 100%; left: 0; z-index: 10000; min-width: 140px; background: #1a1a2e; border: 1px solid #00d4ff; border-radius: 6px; padding: 4px 0; margin-top: 2px; box-shadow: 0 6px 20px rgba(0,0,0,0.5); }
    .toolbar-dropdown:hover .dropdown-menu, .toolbar-dropdown:focus-within .dropdown-menu { display: block; }
    .toolbar-dropdown .dropdown-menu .dd-item { display: block; width: 100%; padding: 6px 12px; background: none; border: none; color: #e0e0e0; font-size: 11px; font-family: 'JetBrains Mono', monospace; text-align: left; cursor: pointer; transition: background 0.15s; box-shadow: none; border-radius: 0; }
    .toolbar-dropdown .dropdown-menu .dd-item:hover, .toolbar-dropdown .dropdown-menu .dd-item:focus { background: rgba(0, 212, 255, 0.2); color: #00d4ff; outline: none; box-shadow: none; }
    .console-section { background: #0a0a14; display: flex; flex-direction: column; flex: 0 0 150px; min-height: 36px; }
    .console-section.collapsed { flex: 0 0 36px !important; min-height: 36px; max-height: 36px; }
    .console-section.collapsed .console-output { display: none; }
    .console-splitter { flex: 0 0 8px; background: linear-gradient(180deg, #00ffaa, #00cc88); cursor: ns-resize; position: relative; transition: background 0.15s; }
    .console-splitter::before { content: ''; position: absolute; inset: -4px 0; z-index: 10; cursor: ns-resize; }
    .console-splitter:hover, .console-splitter.active { background: linear-gradient(180deg, #00ffdd, #00ffaa); box-shadow: 0 0 12px rgba(0, 255, 170, 0.6); }
    .console-splitter.hidden { display: none; }
    .console-header { display: flex; align-items: center; gap: 10px; padding: 8px 12px; border-bottom: 1px solid #2a2a3e; }
    .console-title { color: #00ffaa; font-size: 12px; font-weight: 600; }
    .console-output { flex: 1 1 auto; padding: 12px 15px; font-family: 'JetBrains Mono', monospace; font-size: 12px; color: #00ffaa; overflow-y: auto; }
    .config-row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
    .config-label { color: #e0e0e0; font-size: 12px; min-width: 70px; font-weight: 500; }
    .quick-actions { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 5px; flex: 0 0 auto; }
    .quick-btn { background: rgba(0, 212, 255, 0.15); border: 1px solid #00d4ff; color: #00d4ff; padding: 7px 12px; border-radius: 6px; cursor: pointer; font-size: 11px; font-weight: 600; transition: all 0.2s ease; font-family: 'JetBrains Mono', monospace; }
    .quick-btn:hover { background: rgba(0, 212, 255, 0.25); transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0, 212, 255, 0.3); }
    .quick-btn-success { background: rgba(0, 255, 170, 0.15); border-color: #00ffaa; color: #00ffaa; }
    .quick-btn-success:hover { background: rgba(0, 255, 170, 0.25); box-shadow: 0 4px 12px rgba(0, 255, 170, 0.3); }
    .quick-btn-warning { background: rgba(255, 193, 7, 0.15); border-color: #ffc107; color: #ffc107; }
    .quick-btn-warning:hover { background: rgba(255, 193, 7, 0.25); box-shadow: 0 4px 12px rgba(255, 193, 7, 0.3); }
    .quick-btn-settings { background: rgba(156, 39, 176, 0.15); border-color: #9c27b0; color: #ce93d8; }
    .quick-btn-settings:hover { background: rgba(156, 39, 176, 0.25); box-shadow: 0 4px 12px rgba(156, 39, 176, 0.3); }
    .gear-btn { width: 34px; height: 34px; border-radius: 8px; padding: 0; display: inline-flex; align-items: center; justify-content: center; font-size: 16px; }
    .status-pill { padding: 4px 10px; border-radius: 999px; font-size: 10px; font-weight: 600; border: 1px solid #2a2a3e; color: #d0d7e2; background: rgba(255,255,255,0.04); }
    .status-pill.ok { color: #00ffaa; border-color: rgba(0,255,170,0.5); background: rgba(0,255,170,0.12); }
    .status-pill.bad { color: #ff6b6b; border-color: rgba(255,107,107,0.5); background: rgba(255,107,107,0.12); }
    .status-pill.muted { color: #c6d0dd; border-color: rgba(255,255,255,0.10); background: rgba(255,255,255,0.03); }
    .chat-messages { flex: 1; overflow-y: auto; padding: 10px 12px; display: flex; flex-direction: column; gap: 8px; min-height: 100px; }
    .message { padding: 10px 14px; border-radius: 8px; max-width: 90%; font-size: 13px; line-height: 1.5; animation: slideIn 0.3s ease-out; }
    @keyframes slideIn { from { opacity: 0; transform: translateY(15px); } to { opacity: 1; transform: translateY(0); } }
    .message-user { align-self: flex-end; background: linear-gradient(135deg, #00d4ff 0%, #00a8cc 100%); color: #0a0a14; font-weight: 600; box-shadow: 0 4px 15px rgba(0, 212, 255, 0.3); }
    .message-assistant { align-self: flex-start; background: rgba(0, 212, 255, 0.08); color: #e0e0e0; border: 1px solid rgba(0, 212, 255, 0.25); }
    .input-section { padding: 10px 12px; background: #0f0f1e; border-top: 1px solid #2a2a3e; }
    .input-container .shiny-input-container { flex: 1; margin-bottom: 0 !important; }
    .input-container textarea { width: 100% !important; }
    .send-btn { background: linear-gradient(135deg, #00d4ff 0%, #00a8cc 100%); border: none; color: #0a0a14; padding: 10px 18px; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 13px; transition: all 0.2s ease; font-family: 'JetBrains Mono', monospace; white-space: nowrap; }
    .send-btn:hover { transform: scale(1.03); box-shadow: 0 4px 15px rgba(0, 212, 255, 0.4); }
    .stop-btn { background: linear-gradient(135deg, #ff4757 0%, #ff6b81 100%); border: none; color: #fff; padding: 10px 14px; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 13px; transition: all 0.2s ease; font-family: 'JetBrains Mono', monospace; white-space: nowrap; }
    .stop-btn:hover { transform: scale(1.03); box-shadow: 0 4px 15px rgba(255, 71, 87, 0.4); }
    .chat-btn-group { display: flex; gap: 6px; align-items: center; flex-shrink: 0; align-self: stretch; }
    .chat-btn-group .btn { height: 100%; }
    .prompt-dropdown-wrap { margin-bottom: 6px; position: relative; }
    .prompt-dropdown-wrap .selectize-input { background: rgba(0, 212, 255, 0.08) !important; border: 1px solid #2a2a3e !important; color: #a0a8b8 !important; font-size: 11px !important; min-height: 28px !important; padding: 4px 8px !important; border-radius: 6px !important; }
    .prompt-dropdown-wrap .selectize-dropdown { background: #1a1a2e !important; border: 1px solid #00d4ff !important; border-radius: 6px !important; z-index: 10001 !important; max-height: 350px !important; bottom: 100% !important; top: auto !important; }
    .prompt-dropdown-wrap .selectize-dropdown .option { color: #d0d7e2; padding: 8px 10px; font-size: 11px; white-space: normal !important; line-height: 1.4; }
    .prompt-dropdown-wrap .selectize-dropdown .option:hover { background: rgba(0, 212, 255, 0.15) !important; color: #00d4ff !important; }
    .input-container { display: flex; gap: 8px; align-items: stretch; }
    .chat-tabs { display: flex; gap: 8px; padding: 8px 12px 0; }
    .chat-tab { padding: 6px 12px; cursor: pointer; font-size: 12px; color: #d0d7e2; border: 1px solid #2a2a3e; border-radius: 6px; background: rgba(0, 212, 255, 0.05); transition: all 0.2s; }
    .chat-tab:hover { color: #00d4ff; border-color: #00d4ff; }
    .chat-tab.active { color: #00ffaa; border-color: #00ffaa; background: rgba(0, 255, 170, 0.12); }
    .chat-tab-content { flex: 1 1 0; min-height: 0; display: flex !important; flex-direction: column !important; overflow: hidden !important; height: 100% !important; }
    .chat-tab-pane { display: none; flex: 1 1 0; min-height: 0; overflow: hidden; width: 100% !important; height: 100% !important; }
    .chat-tab-pane.active { display: flex !important; flex-direction: column !important; flex: 1 1 0 !important; min-height: 0 !important; height: 100% !important; width: 100% !important; }
    .ai-code-wrap { flex: 1 1 0; min-height: 100px; border: 1px solid #2a2a3e; border-radius: 8px; overflow: hidden; margin: 8px 12px; height: 100% !important; display: flex !important; flex-direction: column !important; }
    .ai-code-wrap .ace_editor { height: 100% !important; flex: 1 1 auto !important; }
    .ai-code-actions { flex: 0 0 auto; display: flex; gap: 8px; padding: 0 12px 12px; }
    .chat-code { background: rgba(0,0,0,0.25); padding: 10px; border-radius: 6px; border: 1px solid rgba(0,212,255,0.25); overflow-x: auto; }
    .chat-code, .chat-code code { color: #f8fafc; font-family: 'JetBrains Mono', monospace; font-size: 12px; line-height: 1.45; }
    .message-assistant { color: #eaf2ff; }
    .message-assistant code { color: #f8fafc; }

    /* IntroJS / rintrojs tour readability on dark UI */
    .introjs-tooltip { background: #0f0f1e !important; color: #f8fafc !important; border: 1px solid rgba(0,212,255,0.4) !important; box-shadow: 0 10px 30px rgba(0,0,0,0.6) !important; }
    .introjs-tooltiptext { color: #f8fafc !important; font-size: 13px !important; line-height: 1.4 !important; }
    .introjs-arrow { border-color: rgba(0,212,255,0.4) !important; }
    .introjs-button { background: rgba(0, 212, 255, 0.15) !important; border: 1px solid #00d4ff !important; color: #00d4ff !important; text-shadow: none !important; }
    .introjs-button:hover { background: rgba(0, 212, 255, 0.25) !important; }
    .introjs-skipbutton { color: #ff6b6b !important; }
    .introjs-helperLayer { box-shadow: 0 0 0 9999px rgba(0,0,0,0.65) !important; }
    .output-section { background: #0a0a14; border-top: 2px solid #00ffaa; display: flex; flex-direction: column; flex: 0 0 auto; min-height: 260px; }
    .output-tabs { display: flex; border-bottom: 1px solid #2a2a3e; }
    .output-tab { padding: 8px 15px; cursor: pointer; font-size: 12px; color: #d0d7e2; border-bottom: 2px solid transparent; transition: all 0.2s; }
    .output-tab:hover { color: #00d4ff; }
    .output-tab.active { color: #00ffaa; border-bottom-color: #00ffaa; }
    .output-content { padding: 12px 15px; font-family: 'JetBrains Mono', monospace; font-size: 12px; color: #00ffaa; min-height: 260px; max-height: 480px; overflow-y: auto; }
    .plot-output { background: #fff; border-radius: 6px; margin: 8px; min-height: 360px; }
    .ace_editor { font-size: 14px !important; }
    .editor-ace-wrap .shiny-input-container { height: 100% !important; display: block !important; }
    .editor-ace-wrap .ace_editor { height: 100% !important; }
    #code_editor { height: 100% !important; }
    ::-webkit-scrollbar { width: 6px; } ::-webkit-scrollbar-track { background: #0f0f1e; } ::-webkit-scrollbar-thumb { background: #00d4ff; border-radius: 3px; } ::-webkit-scrollbar-thumb:hover { background: #00a8cc; }
    .keyboard-hint { font-size: 10px; color: #c2cad6; margin-top: 5px; }

    .settings-section { margin-bottom: 12px; }
    .settings-section-title { color: #00d4ff; font-size: 13px; font-weight: 600; margin-bottom: 10px; padding-bottom: 6px; border-bottom: 1px solid #2a2a3e; }
    .settings-row { display: flex; gap: 12px; align-items: center; margin-bottom: 10px; flex-wrap: wrap; }
    .settings-label { color: #f0f4f8; font-size: 12px; min-width: 90px; font-weight: 600; }
    .settings-input { flex: 1; min-width: 200px; }
    .model-type-toggle { display: flex; gap: 8px; }
    .model-toggle-btn { padding: 8px 16px; border-radius: 6px; font-size: 12px; cursor: pointer; border: 1px solid #3a3a4e; background: transparent; color: #d7e0ea; transition: all 0.2s; font-weight: 600; }
    .model-toggle-btn.active { background: rgba(0, 212, 255, 0.2); border-color: #00d4ff; color: #00d4ff; }
    .model-toggle-btn:hover { border-color: #00d4ff; }
    .ollama-config { display: none; padding: 12px; background: rgba(0, 255, 170, 0.05); border: 1px solid rgba(0, 255, 170, 0.3); border-radius: 8px; margin-top: 12px; }
    .ollama-config.visible { display: block; }
    .cloud-config { padding: 12px; background: rgba(0, 212, 255, 0.05); border: 1px solid rgba(0, 212, 255, 0.3); border-radius: 8px; margin-top: 12px; }
    .template-row { display: flex; gap: 10px; align-items: center; }
    .template-label { color: #e5e7eb; font-size: 12px; min-width: 80px; }
    .status-bar { display: flex; gap: 15px; padding: 5px 12px; background: #0a0a14; font-size: 10px; color: #c6d0dd; border-top: 1px solid #1a1a2e; flex: 0 0 auto; }
    .status-item { display: flex; align-items: center; gap: 5px; }
    .status-dot { width: 8px; height: 8px; border-radius: 50%; }
    .status-dot.connected { background: #00ffaa; }
    .status-dot.disconnected { background: #ff5555; }
    select, input[type='text'] { background: #1a1a2e !important; border: 1px solid #3a3a4e !important; color: #ffffff !important; border-radius: 6px !important; font-family: 'JetBrains Mono', monospace !important; font-size: 12px !important; padding: 8px 10px !important; }
    select option { white-space: normal; }
    select:focus, input[type='text']:focus { border-color: #00d4ff !important; outline: none !important; }
    select option { background: #1a1a2e; color: #ffffff; }
    .form-group { margin-bottom: 8px !important; }
    .shiny-input-container { width: auto !important; }
    textarea { background: #1a1a2e !important; border: 1px solid #3a3a4e !important; color: #ffffff !important; border-radius: 6px !important; font-family: 'JetBrains Mono', monospace !important; }
    textarea:focus { border-color: #00d4ff !important; outline: none !important; }
    .privacy-note { font-size: 11px; color: #d7dde7; padding: 8px 12px; background: rgba(0, 212, 255, 0.08); border: 1px solid rgba(0, 212, 255, 0.3); border-radius: 6px; margin-top: 8px; }
  "))),


  # Settings Modal Overlay
  div(id = "settings_overlay", class = "settings-overlay",
    div(class = "settings-modal",
      div(class = "settings-header",
        div(class = "settings-title", "Settings"),
        actionButton("close_settings", "Close", class = "settings-close", onclick = "document.getElementById('settings_overlay').classList.remove('visible');")
      ),

      div(class = "settings-grid",
        div(class = "settings-block",
          div(class = "settings-section-title", "AI Model Configuration"),
          div(class = "settings-row",
            div(class = "settings-label", "Model Type:"),
            div(class = "model-type-toggle",
              actionButton("cloud_toggle", "Cloud", class = "model-toggle-btn"),
              actionButton("ollama_toggle", "Ollama", class = "model-toggle-btn active")
            )
          ),
          div(class = "settings-row",
            div(class = "settings-label", "Ollama Status:"),
            div(class = "settings-input",
              uiOutput("ollama_status_ui")
            )
          ),
          div(id = "cloud_config", class = "cloud-config", style = "display:none;",
            div(class = "settings-row",
              div(class = "settings-label", "Provider:"),
              div(class = "settings-input",
                selectInput(
                  "cloud_provider", NULL,
                  choices = list("OpenAI" = "openai", "Anthropic" = "anthropic", "Gemini" = "gemini",
                                "DeepSeek" = "deepseek", "Groq" = "groq", "OpenRouter" = "openrouter"),
                  selected = "openai", width = "160px"
                )
              )
            ),
            conditionalPanel("input.cloud_provider == 'openai'",
              div(class = "settings-row",
                div(class = "settings-label", "Model:"),
                div(class = "settings-input",
                  selectInput("openai_model", NULL,
                              choices = list("gpt-4o-mini" = "gpt-4o-mini", "gpt-4o" = "gpt-4o",
                                           "o3-mini" = "o3-mini", "o1" = "o1",
                                           "gpt-4.1" = "gpt-4.1", "gpt-4.1-mini" = "gpt-4.1-mini",
                                           "gpt-4.1-nano" = "gpt-4.1-nano"),
                              selected = "gpt-4o-mini", width = "200px")
                )
              ),
              div(class = "settings-row",
                div(class = "settings-label", "API Key:"),
                div(class = "settings-input",
                  passwordInput("api_key_openai", NULL, placeholder = "OPENAI_API_KEY or keyring: openai_api_key", width = "100%")
                )
              )
            ),
            conditionalPanel("input.cloud_provider == 'anthropic'",
              div(class = "settings-row",
                div(class = "settings-label", "Model:"),
                div(class = "settings-input",
                  selectInput("anthropic_model", NULL,
                              choices = list("Sonnet 4.6 (Latest)" = "claude-sonnet-4-6-20250514",
                                           "Haiku 4.5 (Fast)" = "claude-haiku-4-5-20251001",
                                           "Sonnet 3.5" = "claude-3-5-sonnet-20241022",
                                           "Haiku 3.5" = "claude-3-5-haiku-20241022"),
                              selected = "claude-haiku-4-5-20251001", width = "200px")
                )
              ),
              div(class = "settings-row",
                div(class = "settings-label", "API Key:"),
                div(class = "settings-input",
                  passwordInput("api_key_anthropic", NULL, placeholder = "ANTHROPIC_API_KEY or keyring: anthropic_api_key", width = "100%")
                )
              )
            ),
            conditionalPanel("input.cloud_provider == 'gemini'",
              div(class = "settings-row",
                div(class = "settings-label", "Model:"),
                div(class = "settings-input",
                  selectInput("gemini_model", NULL,
                              choices = list("gemini-2.0-flash" = "gemini-2.0-flash",
                                           "gemini-2.5-flash" = "gemini-2.5-flash-preview-05-20",
                                           "gemini-1.5-flash" = "gemini-1.5-flash",
                                           "gemini-1.5-pro" = "gemini-1.5-pro"),
                              selected = "gemini-2.0-flash", width = "200px")
                )
              ),
              div(class = "settings-row",
                div(class = "settings-label", "API Key:"),
                div(class = "settings-input",
                  passwordInput("api_key_gemini", NULL, placeholder = "GEMINI_API_KEY or keyring: gemini_api_key", width = "100%")
                )
              )
            ),
            conditionalPanel("input.cloud_provider == 'deepseek'",
              div(class = "settings-row",
                div(class = "settings-label", "Model:"),
                div(class = "settings-input",
                  selectInput("deepseek_model", NULL,
                              choices = list("DeepSeek Chat" = "deepseek-chat",
                                           "DeepSeek Coder" = "deepseek-coder",
                                           "DeepSeek Reasoner" = "deepseek-reasoner"),
                              selected = "deepseek-chat", width = "200px")
                )
              ),
              div(class = "settings-row",
                div(class = "settings-label", "API Key:"),
                div(class = "settings-input",
                  passwordInput("api_key_deepseek", NULL, placeholder = "DEEPSEEK_API_KEY", width = "100%")
                )
              )
            ),
            conditionalPanel("input.cloud_provider == 'groq'",
              div(class = "settings-row",
                div(class = "settings-label", "Model:"),
                div(class = "settings-input",
                  selectInput("groq_model", NULL,
                              choices = list("Llama 3.3 70B" = "llama-3.3-70b-versatile",
                                           "Llama 3.1 8B" = "llama-3.1-8b-instant",
                                           "Mixtral 8x7B" = "mixtral-8x7b-32768",
                                           "Gemma2 9B" = "gemma2-9b-it"),
                              selected = "llama-3.3-70b-versatile", width = "200px")
                )
              ),
              div(class = "settings-row",
                div(class = "settings-label", "API Key:"),
                div(class = "settings-input",
                  passwordInput("api_key_groq", NULL, placeholder = "GROQ_API_KEY", width = "100%")
                )
              )
            ),
            conditionalPanel("input.cloud_provider == 'openrouter'",
              div(class = "settings-row",
                div(class = "settings-label", "Model:"),
                div(class = "settings-input",
                  textInput("openrouter_model", NULL, value = "openai/gpt-4o-mini",
                            placeholder = "e.g. openai/gpt-4o, anthropic/claude-3.5-sonnet", width = "100%")
                )
              ),
              div(class = "settings-row",
                div(class = "settings-label", "API Key:"),
                div(class = "settings-input",
                  passwordInput("api_key_openrouter", NULL, placeholder = "OPENROUTER_API_KEY", width = "100%")
                )
              )
            )
          ),
          div(id = "ollama_config", class = "ollama-config visible", style = "display:block;",
            div(class = "settings-row",
              div(class = "settings-label", "Ollama URL:"),
              div(class = "settings-input",
                textInput("ollama_url", NULL, value = "http://localhost:11434", width = "100%")
              )
            ),
            div(class = "settings-row",
              div(class = "settings-label", "Ollama Model:"),
              div(class = "settings-input", style = "display: flex; gap: 8px;",
                selectInput("ollama_model", NULL,
                            choices = list("codellama:7b" = "codellama:7b",
                                        "codellama:13b" = "codellama:13b",
                                        "codellama:34b" = "codellama:34b",
                                        "deepseek-coder:6.7b" = "deepseek-coder:6.7b",
                                        "deepseek-coder:33b" = "deepseek-coder:33b",
                                        "qwen2.5-coder:7b" = "qwen2.5-coder:7b",
                                        "qwen2.5-coder:14b" = "qwen2.5-coder:14b",
                                        "llama3.2:3b" = "llama3.2:3b",
                                        "llama3.1:8b" = "llama3.1:8b",
                                        "mistral:7b" = "mistral:7b",
                                        "mixtral:8x7b" = "mixtral:8x7b",
                                        "phi3:medium" = "phi3:medium",
                                        "gemma2:9b" = "gemma2:9b",
                                        "starcoder2:7b" = "starcoder2:7b"),
                            selected = "codellama:7b", width = "100%"),
                actionButton("refresh_ollama", "Refresh", class = "quick-btn")
              )
            ),
            div(class = "settings-row",
              div(class = "settings-label", "Connection:"),
              div(class = "settings-input",
                actionButton("test_ollama", "Test Connection", class = "quick-btn")
              )
            )
          )
        ),
        div(class = "settings-block",
          div(class = "settings-section-title", "API Keys"),
          tags$p(style = "color: #aaa; font-size: 11px; margin: 0 0 8px 0;",
            "Enter API keys for cloud providers. Keys are saved locally and never shared."),
          div(class = "settings-row",
            div(class = "settings-label", "OpenAI:"),
            div(class = "settings-input",
              passwordInput("settings_key_openai", NULL, placeholder = "sk-...", width = "100%")
            )
          ),
          div(class = "settings-row",
            div(class = "settings-label", "Anthropic:"),
            div(class = "settings-input",
              passwordInput("settings_key_anthropic", NULL, placeholder = "sk-ant-...", width = "100%")
            )
          ),
          div(class = "settings-row",
            div(class = "settings-label", "Gemini:"),
            div(class = "settings-input",
              passwordInput("settings_key_gemini", NULL, placeholder = "AI...", width = "100%")
            )
          ),
          div(class = "settings-row",
            div(class = "settings-label", ""),
            div(class = "settings-input", style = "display: flex; gap: 8px; align-items: center;",
              actionButton("save_api_keys", "Save Keys", class = "quick-btn quick-btn-success"),
              span(id = "key_save_status", style = "color: #888; font-size: 11px;", "")
            )
          )
        ),
        div(class = "settings-block",
          div(class = "settings-section-title", "Language & Display"),
          div(class = "settings-row",
            div(class = "settings-label", "Language:"),
            div(class = "settings-input",
              selectInput("lang_select", NULL, choices = list("English" = "en", "Espa\u00f1ol" = "es"), selected = "en", width = "150px")
            )
          ),
          div(class = "settings-row",
            div(class = "settings-label", "Streaming:"),
            div(class = "settings-input",
              checkboxInput("stream_responses", NULL, value = TRUE)
            )
          ),
          div(class = "settings-row",
            div(class = "settings-label", "Max Tokens:"),
            div(class = "settings-input",
              numericInput("max_tokens_setting", NULL, value = 3000, min = 500, max = 16000, step = 500, width = "120px"),
              helpText("Higher values allow longer responses but may be slower")
            )
          ),
          div(class = "settings-row",
            div(class = "settings-label", "Auto-format Optimize:"),
            div(class = "settings-input",
              checkboxInput("auto_format_opt", NULL, value = TRUE)
            )
          ),
          div(class = "settings-row",
            div(class = "settings-label", "Conversation Memory:"),
            div(class = "settings-input",
              numericInput("context_turns", NULL, value = 10, min = 0, max = 50, step = 2, width = "120px"),
              helpText("Number of past message turns sent to AI (0 = stateless)")
            )
          ),
          div(class = "settings-row",
            div(class = "settings-label", "Auto-fix Errors:"),
            div(class = "settings-input",
              checkboxInput("auto_fix_errors", NULL, value = TRUE),
              helpText("Automatically send code errors to AI for correction")
            )
          ),
          div(class = "privacy-note", "Your code and API key are secure. Data transmitted over HTTPS (cloud) or stays completely local (Ollama).")
        )
      )
    )
  ),

  # Help Overlay
  div(id = "help_overlay", class = "help-overlay",
    div(class = "help-modal",
      div(class = "help-header",
        div(
          div(class = "help-title", "Help Center"),
          div(class = "help-subtitle", "Navigation and troubleshooting guide for use inside RStudio")
        ),
        actionButton("close_help", "Close", class = "settings-close", onclick = "closeHelpOverlay();")
      ),
      div(class = "help-layout",
        div(class = "help-sidebar",
          tags$button(type = "button", class = "help-nav-link active", "data-section" = "getting_started", onclick = "helpScrollTo('getting_started');", "Getting Started"),
          tags$button(type = "button", class = "help-nav-link", "data-section" = "rstudio", onclick = "helpScrollTo('rstudio');", "RStudio Install"),
          tags$button(type = "button", class = "help-nav-link", "data-section" = "models", onclick = "helpScrollTo('models');", "Model Setup"),
          tags$button(type = "button", class = "help-nav-link", "data-section" = "editor", onclick = "helpScrollTo('editor');", "Editor and Console"),
          tags$button(type = "button", class = "help-nav-link", "data-section" = "assistant", onclick = "helpScrollTo('assistant');", "AI Assistant"),
          tags$button(type = "button", class = "help-nav-link", "data-section" = "templates", onclick = "helpScrollTo('templates');", "Templates"),
          tags$button(type = "button", class = "help-nav-link", "data-section" = "charts", onclick = "helpScrollTo('charts');", "Charts and Plot Viewer"),
          tags$button(type = "button", class = "help-nav-link", "data-section" = "shortcuts", onclick = "helpScrollTo('shortcuts');", "Shortcuts"),
          tags$button(type = "button", class = "help-nav-link", "data-section" = "security", onclick = "helpScrollTo('security');", "Security and Privacy"),
          tags$button(type = "button", class = "help-nav-link", "data-section" = "troubleshooting", onclick = "helpScrollTo('troubleshooting');", "Troubleshooting"),
          tags$button(type = "button", class = "help-nav-link", "data-section" = "faq", onclick = "helpScrollTo('faq');", "FAQ")
        ),
        div(class = "help-content",
          div(id = "help_section_getting_started", class = "help-section",
            tags$h4("Getting Started"),
            tags$p("This app combines an R code editor, output console, plot viewer, and AI assistant. Use the left panel to write and run code, and the right panel to ask AI questions or request refactors."),
            tags$ul(
              tags$li("Use the gear button to configure model provider and language."),
              tags$li("Use the template selector to load chart or analysis examples."),
              tags$li("Use Run or Ctrl+Enter to execute code."),
              tags$li("Switch between Editor and Plot tabs to view charts.")
            )
          ),
          div(id = "help_section_rstudio", class = "help-section",
            tags$h4("Install and Launch in RStudio"),
            tags$p("Install from local folder with devtools, then launch through add-in or package function."),
            tags$div(class = "help-code",
"install.packages('devtools')\ndevtools::install_github('DataConceptz/AI-R-Assistant')\naiRAssistant::ai_r_assistant()"),
            tags$p("In RStudio menus: Tools -> Addins -> Browse Addins -> AI R Assistant.")
          ),
          div(id = "help_section_models", class = "help-section",
            tags$h4("Model Setup"),
            tags$p("Default mode is Ollama local models. You can switch to cloud models when needed."),
            tags$ul(
              tags$li("Ollama URL default: http://localhost:11434"),
              tags$li("Use Refresh to fetch installed local models."),
              tags$li("Use Test Connection to verify Ollama is reachable."),
              tags$li("Cloud providers supported: OpenAI, Anthropic, Gemini."),
              tags$li("API key options: in-app input, environment variable, or keyring entry.")
            )
          ),
          div(id = "help_section_editor", class = "help-section",
            tags$h4("Editor and Console"),
            tags$ul(
              tags$li("Editor tab: write code, use run actions, and apply formatting."),
              tags$li("Console section auto-scrolls and captures output/errors."),
              tags$li("Run Selection executes only highlighted code."),
              tags$li("Console can be collapsed/expanded to free space.")
            ),
            tags$p("Auto-save keeps editor text in localStorage and restores it on reload.")
          ),
          div(id = "help_section_assistant", class = "help-section",
            tags$h4("AI Assistant"),
            tags$ul(
              tags$li("Use Explain, Debug, Optimize, and Document quick actions."),
              tags$li("Chat tab stores the full dialog."),
              tags$li("Refined Code tab isolates extracted code blocks."),
              tags$li("Insert Code copies refined code directly into the editor cursor location."),
              tags$li("Copy stores assistant code to clipboard.")
            )
          ),
          div(id = "help_section_templates", class = "help-section",
            tags$h4("Templates"),
            tags$p("Templates provide high-quality chart and analysis starters designed for fast rendering."),
            tags$ul(
              tags$li("Choose a template in the dropdown."),
              tags$li("Click Apply to load it into the editor."),
              tags$li("Run the template to render chart/output."),
              tags$li("The active template indicator confirms what is loaded.")
            )
          ),
          div(id = "help_section_charts", class = "help-section",
            tags$h4("Charts and Plot Viewer"),
            tags$ul(
              tags$li("Plot tab renders ggplot and plotly outputs."),
              tags$li("Save exports chart file using selected format."),
              tags$li("Popout opens a larger plot viewer dialog."),
              tags$li("Fullscreen toggles the popout to use entire screen."),
              tags$li("Resizing splitter or window should reflow charts automatically.")
            )
          ),
          div(id = "help_section_shortcuts", class = "help-section",
            tags$h4("Keyboard Shortcuts"),
            tags$ul(
              tags$li("Ctrl+Enter: Run full editor code."),
              tags$li("Ctrl+Shift+Enter: Run selected code."),
              tags$li("Esc: close Settings/Help overlays.")
            )
          ),
          div(id = "help_section_security", class = "help-section",
            tags$h4("Security and Privacy"),
            tags$ul(
              tags$li("Local Ollama mode keeps prompts/code on your machine."),
              tags$li("Cloud requests use HTTPS endpoints."),
              tags$li("Use keyring for API key storage instead of plain text."),
              tags$li("Do not commit secrets into Git.")
            )
          ),
          div(id = "help_section_troubleshooting", class = "help-section",
            tags$h4("Troubleshooting"),
            tags$ul(
              tags$li("No models listed: confirm Ollama is running and click Refresh."),
              tags$li("Connection errors: test http://localhost:11434/api/tags in browser."),
              tags$li("Plot not filling panel: switch tabs once or resize pane to trigger reflow."),
              tags$li("Insert Code not working: confirm refined code exists in AI code tab."),
              tags$li("Slow replies: enable streaming and reduce max tokens.")
            ),
            tags$div(class = "help-code",
"# Quick endpoint test\n
httr::GET('http://localhost:11434/api/tags')\n
# Launch app from source checkout\n
shiny::runApp('inst/shinyapp')")
          ),
          div(id = "help_section_faq", class = "help-section",
            tags$h4("FAQ"),
            tags$p("Q: Why does RStudio not show Run App button?"),
            tags$p("A: Run App appears for app.R style projects; this app is launched via add-in or source call."),
            tags$p("Q: Where are editor drafts saved?"),
            tags$p("A: In browser localStorage under key editor_code."),
            tags$p("Q: Can I use this offline?"),
            tags$p("A: Yes, with local Ollama models.")
          )
        )
      )
    )
  ),

  # Header
  div(class = "header-section",
      div(
        div(class = "header-title", "AI R Assistant"),
        div(class = "header-subtitle", "Enhanced | Ollama + Cloud | Advanced Charts")
      ),
      div(class = "header-controls",
        actionButton("open_settings", NULL, class = "quick-btn quick-btn-settings gear-btn", icon = icon("gear"),
                     onclick = "document.getElementById('settings_overlay').classList.add('visible');"),
        actionButton("open_help", NULL, class = "quick-btn gear-btn", icon = icon("book"),
                     onclick = "openHelpOverlay('getting_started');"),
        actionButton("open_diagnostics", NULL, class = "quick-btn gear-btn", icon = icon("circle-info")),
        actionButton("open_export", NULL, class = "quick-btn gear-btn", icon = icon("download")),
        uiOutput("header_model_display"),
        actionButton("start_tour", "Tour", class = "quick-btn")
      )
  ),

  # Main Content
  div(class = "main-content",
    # Editor Panel (Left)
    div(class = "editor-panel",
      div(class = "panel-header",
        div(class = "panel-title", "R Code Editor"),
        div(style = "display: flex; gap: 10px; align-items: center;",
          selectInput("chart_templates", NULL,
                      choices = list("-- Charts --" = "",
                                  "Line Chart" = "line_chart",
                                  "Scatter + Regression" = "scatter_regression",
                                  "Grouped Bar" = "bar_grouped",
                                  "Histogram + Density" = "histogram_density",
                                  "Box + Violin" = "boxplot_comparison",
                                  "Correlation Heatmap" = "heatmap_correlation",
                                  "Faceted Plot" = "faceted_plot",
                                  "Time Series + MA" = "time_series",
                                  "Donut Chart" = "pie_donut",
                                  "Stacked Area" = "area_stacked",
                                  "Violin Plot" = "violin_plot",
                                  "Geographic Map" = "geographic_map",
                                  "Network Graph" = "network_graph",
                                  "Waterfall" = "waterfall_chart",
                                  "Radar Chart" = "radar_chart",
                                  "-- Publication --" = "",
                                  "Line + CI" = "pub_line_ci",
                                  "Bar + Error" = "pub_bar_error",
                                  "Forest Plot" = "forest_plot",
                                  "Dot + CI" = "dot_ci",
                                  "Volcano Plot" = "volcano_plot",
                                  "Kaplan-Meier" = "km_curve",
                                  "-- Data --" = "",
                                  "Data Summary" = "data_summary",
                                  "Linear Model" = "linear_model",
                                  "Data Manipulation" = "data_manipulation",
                                  "Function Template" = "function_template"),
                      selected = "", width = "160px"),
          actionButton("apply_template", "Apply", class = "quick-btn"),
          uiOutput("active_template_display"),
          uiOutput("current_model_display")
        )
      ),
      div(class = "editor-body",
        div(class = "editor-top-area",
            div(class = "editor-tabs",
              div(id = "tab_editor", class = "editor-tab active", onclick = "setEditorTabClient('editor')", "Editor"),
              div(id = "tab_plot", class = "editor-tab", onclick = "setEditorTabClient('plot')", "Plot"),
              div(id = "tab_data", class = "editor-tab", onclick = "setEditorTabClient('data')", "Data")
            ),
          div(class = "editor-tab-content",
            div(id = "editor_tab", class = "editor-tab-pane active",
              div(class = "editor-ace-wrap",
                shinyAce::aceEditor("code_editor", mode = "r", theme = "monokai", value = '# AI R Assistant - Advanced Charts
# Write your R code here or select a template

# Example: Quick ggplot2 visualization
library(ggplot2)

# Create sample data
data <- data.frame(
  category = rep(c("A", "B", "C", "D"), each = 25),
  value = c(rnorm(25, 10, 2), rnorm(25, 15, 3),
            rnorm(25, 12, 2.5), rnorm(25, 18, 4))
)

# Create an elegant box plot
ggplot(data, aes(x = category, y = value, fill = category)) +
  geom_boxplot(alpha = 0.8, outlier.shape = 21) +
  geom_jitter(width = 0.2, alpha = 0.5, size = 2) +
  scale_fill_viridis_d(option = "plasma") +
  labs(title = "Distribution by Category",
       subtitle = "Box plot with individual points",
       x = "Category", y = "Value") +
  theme_minimal(base_size = 14) +
  theme(legend.position = "none",
        plot.title = element_text(face = "bold"))',
                         height = "100%", autoComplete = "enabled")
              ),

              # Quick Action Buttons
              div(class = "quick-actions",
                actionButton("run_btn", "Run", class = "quick-btn quick-btn-success"),
                actionButton("run_sel_btn", "Run Selection", class = "quick-btn", onclick = "runSelection();"),
                actionButton("explain_btn", "Explain", class = "quick-btn"),
                actionButton("debug_btn", "Debug", class = "quick-btn"),
                actionButton("optimize_btn", "Optimize", class = "quick-btn"),
                actionButton("format_btn", "Format Code", class = "quick-btn"),
                actionButton("document_btn", "Document", class = "quick-btn"),
                actionButton("chart_help_btn", "Chart Help", class = "quick-btn quick-btn-warning"),
                actionButton("paste_btn", "New File", class = "quick-btn")
              ),
              div(class = "keyboard-hint", "Ctrl+Enter: Run | Tab: Autocomplete")
            ),
            div(id = "plot_tab", class = "editor-tab-pane",
              div(class = "plot-pane",
                div(class = "plot-toolbar",
                  tags$div(class = "toolbar-dropdown",
                    actionButton("theme_toggle", "\U0001F3A8 Theme", class = "quick-btn"),
                    tags$div(class = "dropdown-menu",
                      actionButton("theme_minimal", "Minimal", class = "dd-item"),
                      actionButton("theme_classic", "Classic", class = "dd-item"),
                      actionButton("theme_bw", "B&W", class = "dd-item"),
                      actionButton("theme_dark", "Dark", class = "dd-item"),
                      actionButton("theme_light", "Light", class = "dd-item"),
                      actionButton("theme_void", "Void", class = "dd-item"),
                      actionButton("theme_linedraw", "Linedraw", class = "dd-item"),
                      actionButton("theme_grey", "Grey", class = "dd-item"),
                      actionButton("theme_economist", "Economist", class = "dd-item"),
                      actionButton("theme_tufte", "Tufte", class = "dd-item"),
                      actionButton("theme_clean", "Clean", class = "dd-item")
                    )
                  ),
                  tags$div(class = "toolbar-dropdown",
                    actionButton("color_toggle", "\U0001F308 Colors", class = "quick-btn"),
                    tags$div(class = "dropdown-menu",
                      actionButton("pal_viridis", "Viridis", class = "dd-item"),
                      actionButton("pal_plasma", "Plasma", class = "dd-item"),
                      actionButton("pal_inferno", "Inferno", class = "dd-item"),
                      actionButton("pal_magma", "Magma", class = "dd-item"),
                      actionButton("pal_cividis", "Cividis", class = "dd-item"),
                      actionButton("pal_Set1", "Set1", class = "dd-item"),
                      actionButton("pal_Set2", "Set2", class = "dd-item"),
                      actionButton("pal_Paired", "Paired", class = "dd-item"),
                      actionButton("pal_Dark2", "Dark2", class = "dd-item"),
                      actionButton("pal_Spectral", "Spectral", class = "dd-item"),
                      actionButton("pal_Corporate", "Corporate", class = "dd-item"),
                      actionButton("pal_Ocean", "Ocean", class = "dd-item"),
                      actionButton("pal_Sunset", "Sunset", class = "dd-item"),
                      actionButton("pal_Forest", "Forest", class = "dd-item"),
                      actionButton("pal_Slate", "Slate", class = "dd-item")
                    )
                  ),
                  checkboxInput("auto_plot", "Auto Plot", value = TRUE),
                  tags$div(class = "plot-toolbar-right",
                    actionButton("toggle_plotly", "Interactive", class = "quick-btn", title = "Toggle static/interactive plot"),
                    selectInput("export_format", NULL, choices = c("PNG (300 DPI)" = "png", "PDF" = "pdf", "SVG" = "svg"), selected = "png", width = "120px"),
                    downloadButton("save_plot", "Save", class = "quick-btn"),
                    actionButton("popout_plot", "Popout", class = "quick-btn")
                  )
                ),
                div(class = "plot-canvas",
                  plotOutput("plot_display", height = "100%"),
                  if (requireNamespace("plotly", quietly = TRUE)) {
                    plotly::plotlyOutput("plotly_display", height = "100%")
                  } else {
                    div(id = "plotly_display", style = "display:none;")
                  }
                )
              )
            ),
            div(id = "data_tab", class = "editor-tab-pane",
              div(style = "display: flex; flex-direction: column; height: 100%; padding: 8px; gap: 8px;",
                div(style = "flex: 0 0 auto; display: flex; align-items: center; gap: 12px;",
                  fileInput("data_upload", NULL, accept = c(".csv", ".xlsx", ".xls", ".tsv", ".rds"),
                            width = "300px", placeholder = "Upload CSV/Excel/RDS..."),
                  uiOutput("data_info_display")
                ),
                div(style = "flex: 1 1 auto; min-height: 0; overflow: auto;",
                  if (requireNamespace("DT", quietly = TRUE)) {
                    DT::dataTableOutput("data_preview", height = "100%")
                  } else {
                    div(style = "color: #aaa; padding: 20px;",
                      "Install the DT package for interactive data preview:",
                      tags$br(),
                      tags$code("install.packages('DT')"))
                  }
                )
              )
            )
          )
        ),

        div(class = "console-splitter", id = "console_splitter"),
        div(class = "console-section", id = "console_section",
          div(class = "console-header",
            div(class = "console-title", "Console"),
            actionButton("toggle_console_btn", "Collapse", class = "quick-btn")
          ),
          div(id = "console_output", class = "console-output",
            verbatimTextOutput("code_output", placeholder = TRUE)
          )
        )
      )
    ),
    div(class = "splitter", id = "splitter"),
    # Chat Panel (Right)
    div(class = "chat-panel",
      div(class = "panel-header",
        div(class = "panel-title", "AI Assistant"),
        div(style = "display: flex; gap: 8px; align-items: center;",
          actionButton("insert_ai_code", "Insert Code", class = "quick-btn"),
          actionButton("copy_ai_code", "Copy", class = "quick-btn"),
          actionButton("clear_chat", "Clear", class = "quick-btn"),
          actionButton("save_session", icon("save"), class = "quick-btn", title = "Save Chat Session"),
          actionButton("load_session", icon("folder-open"), class = "quick-btn", title = "Load Chat Session")
        )
      ),
      div(class = "chat-tabs",
        div(id = "chat_tab_chat", class = "chat-tab active", onclick = "switchChatTab('chat')", "Chat"),
        div(id = "chat_tab_code", class = "chat-tab", onclick = "switchChatTab('code')", "Refined Code"),
        div(id = "chat_tab_diff", class = "chat-tab", onclick = "switchChatTab('diff')", "Diff View")
      ),
      div(class = "chat-tab-content",
        div(id = "chat_pane_chat", class = "chat-tab-pane active",
          div(class = "chat-messages", uiOutput("chat_display"))
        ),
        div(id = "chat_pane_code", class = "chat-tab-pane",
          div(class = "ai-code-wrap",
            shinyAce::aceEditor("ai_code_view", mode = "r", theme = "monokai", value = "", height = "100%", autoComplete = "disabled", readOnly = TRUE)
          ),
          div(class = "ai-code-actions",
            actionButton("run_ai_code_tab", "Run Code", class = "quick-btn quick-btn-success"),
            actionButton("insert_ai_code_tab", "Insert to Editor", class = "quick-btn"),
            actionButton("copy_ai_code_tab", "Copy", class = "quick-btn")
          )
        ),
        div(id = "chat_pane_diff", class = "chat-tab-pane",
          div(class = "diff-container", uiOutput("code_diff_display"))
        )
      ),
      div(class = "input-section",
        div(class = "prompt-dropdown-wrap",
          selectInput("sample_prompts", NULL, width = "100%",
            choices = c(
              "Select a sample prompt..." = "",
              "Publication bar chart with error bars" = "Create a publication-quality grouped bar chart with standard error bars using ggplot2. Use geom_col with position_dodge, add geom_errorbar for SE, apply scale_fill_brewer with a color-blind friendly palette, use theme_minimal with customized axis text sizes, add proper x/y axis labels with units, include a descriptive title and subtitle, and export at 300 DPI resolution suitable for journal submission.",
              "Interactive plotly scatter with regression" = "Build an interactive plotly scatter plot from my data with hover tooltips displaying all columns (x, y, group, value). Add a linear regression trend line with 95% confidence interval shading, color points by group with a custom discrete palette, set marker size proportional to a numeric variable, add axis titles with units, include a legend positioned inside the plot area, and enable zoom/pan/lasso selection tools.",
              "Data cleaning: wide-to-long reshape pipeline" = "Write a complete data cleaning and reshaping pipeline: read my data with readr, inspect structure with glimpse/summary, handle missing values using tidyr::replace_na or imputation, convert character columns to factors with forcats, pivot from wide to long format using pivot_longer specifying cols/names_to/values_to, validate the output dimensions, add derived columns with mutate, and include inline comments explaining each transformation step.",
              "Multi-panel faceted ggplot with annotations" = "Create a multi-panel faceted ggplot2 visualization using facet_wrap(~group, scales='free_y', ncol=3). Add individual geom_smooth trend lines per panel, customize strip labels using labeller=label_both, add panel-specific text annotations with geom_text, apply a consistent theme_bw with adjusted strip.background and strip.text, set a shared color scale across panels, and add an overall title with plot.title centered.",
              "Correlation heatmap with significance testing" = "Build a lower-triangle correlation heatmap: compute Pearson correlations with Hmisc::rcorr to get both r-values and p-values, reshape into long format, create the heatmap with geom_tile using scale_fill_gradient2 (blue-white-red, midpoint=0), overlay correlation coefficients as text with geom_text, add significance stars (*p<0.05, **p<0.01, ***p<0.001), apply hierarchical clustering to reorder variables using hclust, remove upper triangle and diagonal, and use coord_fixed for square tiles.",
              "Linear mixed model with full diagnostics" = "Write a complete linear mixed-effects model analysis: fit the model with lme4::lmer including fixed effects for treatment and time, random intercepts and slopes for subject, perform model selection comparing nested models with anova() and AIC/BIC, extract fixed effect estimates with confint(), create diagnostic plots (residuals vs fitted, QQ plot of residuals, random effects caterpillar plot using lattice::dotplot(ranef())), generate a publication-ready coefficient table with broom.mixed::tidy(), and test significance with lmerTest::anova(type=3).",
              "Survival analysis with Kaplan-Meier curves" = "Create a complete survival analysis: fit Kaplan-Meier curves with survival::survfit stratified by treatment group, plot with survminer::ggsurvplot including risk table below, median survival lines, 95% confidence bands, customized colors per group, log-rank test p-value annotation, add number-at-risk table with break.time.by, set custom axis labels (Time in months, Survival probability), apply a clean theme, and include a Cox proportional hazards model summary with hazard ratios and forest plot.",
              "Dashboard layout with patchwork" = "Build a 4-panel dashboard combining multiple ggplots using patchwork: (1) grouped bar chart with geom_col and position_dodge, (2) time series line plot with geom_line and geom_ribbon for CI, (3) box plot with geom_boxplot and overlaid jittered points, (4) scatter plot with geom_point colored by group and geom_smooth. Combine with (p1 | p2) / (p3 | p4), add a shared title with plot_annotation(title, subtitle, caption), collect legends with plot_layout(guides='collect'), and apply a consistent theme across all panels.",
              "Advanced dplyr pipeline with joins" = "Write an advanced data pipeline using dplyr: start with raw data, filter rows by multiple conditions using filter(between(), str_detect()), create derived columns with mutate(across(), case_when()), perform group_by with multiple grouping variables, summarize with n(), mean(), sd(), median(), and custom quantile functions, join with a reference table using left_join with multiple keys, add window functions like lag(), lead(), cumsum(), percent_rank(), pivot results wider for reporting, and arrange by multiple columns. Include comments explaining the business logic at each step.",
              "Geographic map with sf and ggplot2" = "Create a geographic map visualization: load shapefiles with sf::st_read, transform CRS to WGS84 with st_transform(crs=4326), plot base map with geom_sf filled by a variable using scale_fill_viridis_c, overlay point data with geom_sf using size/color aesthetics, add text labels with geom_sf_text repelled to avoid overlap, include a north arrow with ggspatial::annotation_north_arrow, add scale bar with annotation_scale, set coord_sf with xlim/ylim for the study area, apply theme_void with a custom legend position, and add title/subtitle with data source citation.",
              "Time series decomposition and forecast" = "Build a complete time series analysis: convert data to ts object with proper frequency, decompose with stl(s.window='periodic') and plot components (trend, seasonal, remainder), check stationarity with tseries::adf.test, fit auto.arima from forecast package, generate 12-period ahead forecast with prediction intervals, plot original data + forecast using autoplot with custom colors, add accuracy metrics (RMSE, MAE, MAPE) as text annotation, create a residual diagnostics panel (ACF, histogram, Ljung-Box test), and compare with an ETS model using accuracy() on a holdout set.",
              "Comprehensive testthat test suite" = "Write a comprehensive test suite using testthat: create test-myfunction.R with describe/it blocks, test normal inputs with expect_equal and tolerance for numeric comparisons, test edge cases (empty input, NA values, single element, very large data), test error handling with expect_error matching specific messages, test output types with expect_s3_class/expect_type, use test fixtures with setup/teardown for temporary files, mock external API calls with mockr or withr::local_envvar, test performance bounds with expect_lt on system.time, and include snapshot tests with expect_snapshot for complex outputs.",
              "Violin + box + jitter plot for publication" = "Create a layered violin plot for publication: use geom_violin(trim=FALSE, alpha=0.3) filled by group, overlay geom_boxplot(width=0.15, outlier.shape=NA) for quartiles, add geom_jitter(width=0.1, alpha=0.5, size=1.5) for individual data points, mark group means with stat_summary(fun=mean, geom='crossbar', width=0.3), add pairwise significance brackets using ggpubr::stat_compare_means(comparisons=list, method='wilcox.test'), apply scale_fill_manual with publication colors, use theme_classic with base_size=14, customize axis labels with expression() for units, and set y-axis limits with coord_cartesian to avoid clipping.",
              "PCA biplot with confidence ellipses" = "Build a PCA biplot: run prcomp(scale.=TRUE) on numeric columns, extract scores and loadings, create ggplot with PC1 vs PC2 as axes labeled with percent variance explained, plot sample scores as points colored by group using scale_color_manual, add 95% confidence ellipses per group with stat_ellipse(type='norm'), overlay variable loadings as arrows with geom_segment and geom_text_repel for labels, scale loadings to fit the score range, add a reference crosshair at origin with geom_hline/geom_vline, include a scree plot inset showing eigenvalues, and apply theme_minimal with customized legend.",
              "R code performance optimization" = "Analyze my R code for performance bottlenecks and rewrite it: profile with profvis or system.time to identify slow sections, replace for-loops with vectorized operations (ifelse, pmin/pmax, rowSums), convert data.frame operations to data.table with := and .SD for 10-100x speedup on large data, parallelize independent computations with future::plan(multisession) and furrr::future_map, use Rcpp for computationally intensive inner loops, apply memoization with memoise for repeated function calls, optimize memory with data.table::fread instead of read.csv, and benchmark before/after with microbenchmark showing median times and relative speedup."
            )
          )
        ),
        div(class = "input-container",
          textAreaInput("user_input", NULL, placeholder = "Ask about your code or charts...", width = "100%", rows = 2),
          div(class = "chat-btn-group",
            actionButton("send_btn", "Send", class = "send-btn"),
            actionButton("reask_btn", "Re-ask", class = "quick-btn"),
            actionButton("stop_btn", "Stop", class = "stop-btn")
          )
        )
      )
    )
  ),

  # Status Bar
  div(class = "status-bar",
    div(class = "status-item",
      div(id = "connection_dot", class = "status-dot connected"),
      span(id = "connection_status", "Ready")
    ),
    div(class = "status-item", uiOutput("latency_status")),
    div(class = "status-item", uiOutput("model_status")),
    div(class = "status-item", uiOutput("cache_status"))
  ),

  # Robust fallback: event delegation + error capture (independent of main script)
  tags$script(HTML("
    document.addEventListener('click', function(e) {
      var el = e.target;
      while (el && el !== document) {
        if (el.id === 'tab_editor') { _doEditorTab('editor'); return; }
        if (el.id === 'tab_plot')   { _doEditorTab('plot');   return; }
        if (el.id === 'tab_data')   { _doEditorTab('data');   return; }
        if (el.id === 'chat_tab_chat') { _doChatTab('chat'); return; }
        if (el.id === 'chat_tab_code') { _doChatTab('code'); return; }
        if (el.id === 'chat_tab_diff') { _doChatTab('diff'); return; }
        if (el.id === 'toggle_console_btn') { _doToggleConsole(); return; }
        el = el.parentElement;
      }
    });
    function _doEditorTab(tab) {
      if (tab !== 'plot' && tab !== 'data') tab = 'editor';
      var tabs = document.querySelectorAll('.editor-tab');
      for (var i = 0; i < tabs.length; i++) tabs[i].classList.remove('active');
      var t = document.getElementById('tab_' + tab);
      if (t) t.classList.add('active');
      var ep = document.getElementById('editor_tab');
      var pp = document.getElementById('plot_tab');
      var dp = document.getElementById('data_tab');
      if (ep) { if (tab === 'editor') ep.classList.add('active'); else ep.classList.remove('active'); }
      if (pp) { if (tab === 'plot') pp.classList.add('active'); else pp.classList.remove('active'); }
      if (dp) { if (tab === 'data') dp.classList.add('active'); else dp.classList.remove('active'); }
      try { Shiny.setInputValue('editor_tab', tab, {priority: 'event'}); } catch(x){}
    }
    function _doChatTab(tab) {
      var tabs = ['chat', 'code', 'diff'];
      for (var i = 0; i < tabs.length; i++) {
        var t = document.getElementById('chat_tab_' + tabs[i]);
        var p = document.getElementById('chat_pane_' + tabs[i]);
        if (t) t.classList.toggle('active', tabs[i] === tab);
        if (p) p.classList.toggle('active', tabs[i] === tab);
      }
    }
    function _doToggleConsole() {
      var c = document.getElementById('console_section');
      if (!c) return;
      c.classList.toggle('collapsed');
      var isCollapsed = c.classList.contains('collapsed');
      // Hide/show the splitter bar
      var bar = document.getElementById('console_splitter');
      if (bar) { if (isCollapsed) bar.classList.add('hidden'); else bar.classList.remove('hidden'); }
      // Update button text
      var btn = c.querySelector('.quick-btn');
      if (btn) {
        var label = btn.querySelector('.action-label') || btn;
        label.innerText = isCollapsed ? 'Expand' : 'Collapse';
      }
      // Resize editor after toggle
      try { ace.edit('code_editor').resize(); } catch(x) {}
    }
    // Expose global stubs so inline onclick= attributes don't throw
    // (main script block redefines these with full implementations)
    window.setEditorTabClient = function(tab) { _doEditorTab(tab); };
    window.switchChatTab = function(tab) { _doChatTab(tab); };
    window.toggleConsole = function() { _doToggleConsole(); };
    window.runSelection = function() { console.warn('runSelection: main script not yet loaded'); };
    window.toggleFullscreenModal = function() {
      var md = document.querySelector('.modal-dialog.plot-popout') || document.querySelector('.modal-dialog');
      if (!md) return;
      var modal = md.closest('.modal');
      if (!modal) return;
      modal.classList.toggle('modal-fullscreen');
      var fs = modal.classList.contains('modal-fullscreen');
      var btn = modal.querySelector('.btn-fullscreen');
      if (btn) btn.textContent = fs ? 'Exit Fullscreen' : 'Fullscreen';
      setTimeout(function() {
        window.dispatchEvent(new Event('resize'));
        try { Shiny.setInputValue('popout_resize', Date.now(), {priority:'event'}); } catch(x){}
      }, 150);
    };
    // Splitter drag fallback (works even if main script's initSplit fails)
    (function() {
      var dragging = false;
      document.addEventListener('mousedown', function(e) {
        var el = e.target;
        while (el && el !== document) {
          if (el.id === 'splitter' || (el.classList && el.classList.contains('splitter'))) {
            dragging = true;
            e.preventDefault();
            document.body.style.userSelect = 'none';
            document.body.style.cursor = 'col-resize';
            return;
          }
          el = el.parentElement;
        }
      });
      document.addEventListener('mouseup', function() {
        if (!dragging) return;
        dragging = false;
        document.body.style.userSelect = '';
        document.body.style.cursor = '';
      });
      document.addEventListener('mousemove', function(e) {
        if (!dragging) return;
        var main = document.querySelector('.main-content');
        if (!main) return;
        var rect = main.getBoundingClientRect();
        var x = e.clientX - rect.left;
        var ratio = (x / rect.width) * 100;
        ratio = Math.max(20, Math.min(80, ratio));
        main.style.setProperty('--left-track', ratio + 'fr');
        main.style.setProperty('--right-track', (100 - ratio) + 'fr');
        try { localStorage.setItem('split_ratio', String(ratio)); } catch(ex) {}
      });
    })();

    // Console splitter drag (same delegation pattern as main splitter)
    (function() {
      var dragging = false;
      var startY = 0;
      var startH = 0;
      var consoleEl = null;

      document.addEventListener('mousedown', function(e) {
        var el = e.target;
        // Walk up from click target to find the console_splitter
        while (el && el !== document) {
          if (el.id === 'console_splitter') {
            consoleEl = document.getElementById('console_section');
            if (!consoleEl || consoleEl.classList.contains('collapsed')) return;
            dragging = true;
            startY = e.clientY;
            startH = consoleEl.getBoundingClientRect().height;
            el.classList.add('active');
            document.body.style.userSelect = 'none';
            document.body.style.cursor = 'ns-resize';
            e.preventDefault();
            e.stopPropagation();
            return;
          }
          el = el.parentElement;
        }
      });

      document.addEventListener('mousemove', function(e) {
        if (!dragging || !consoleEl) return;
        e.preventDefault();
        var delta = startY - e.clientY;
        var newH = Math.max(60, Math.min(startH + delta, window.innerHeight * 0.6));
        consoleEl.style.flex = '0 0 ' + newH + 'px';
      });

      document.addEventListener('mouseup', function() {
        if (!dragging) return;
        dragging = false;
        var bar = document.getElementById('console_splitter');
        if (bar) bar.classList.remove('active');
        document.body.style.userSelect = '';
        document.body.style.cursor = '';
        try { ace.edit('code_editor').resize(); } catch(x) {}
        consoleEl = null;
      });
    })();
  ")),

  # JavaScript for layout, tabs, split pane, and helpers
  tags$script(HTML("
    document.addEventListener('fullscreenchange', function() {
      var modal = document.querySelector('.modal.in') || document.querySelector('.modal.show') || document.querySelector('.modal[style*=\\\"display: block\\\"]');
      if (!document.fullscreenElement) {
        if (modal) modal.classList.remove('modal-fullscreen');
      }
      // Trigger Shiny plot resize and Plotly resize after fullscreen toggle
      setTimeout(function() {
        try { Shiny.setInputValue('popout_resize', Date.now(), {priority: 'event'}); } catch (e) {}
        try {
          var pl = document.getElementById('plotly_display_popout');
          if (pl && window.Plotly) { Plotly.Plots.resize(pl); }
        } catch (e) {}
      }, 200);
    });

    // Track observers for cleanup
    window._appObservers = window._appObservers || [];

    // Watch for modal open to trigger plot resize
    try { (function initModalObserver() {
      var observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
          if (mutation.addedNodes) {
            mutation.addedNodes.forEach(function(node) {
              if (node.classList && node.classList.contains('modal')) {
                setTimeout(function() {
                  try { Shiny.setInputValue('popout_resize', Date.now(), {priority: 'event'}); } catch (e) {}
                  try {
                    var pl = document.getElementById('plotly_display_popout');
                    if (pl && window.Plotly) { Plotly.Plots.resize(pl); }
                  } catch (e) {}
                }, 200);
              }
            });
          }
        });
      });
      observer.observe(document.body, { childList: true, subtree: false });
      window._appObservers.push(observer);
    })(); } catch(_e) { console.warn('initModalObserver:', _e); }

    // Shared debounced plot-resize trigger (prevents flicker during drag/resize)
    var _plotResizeTimer = null;
    function debouncedPlotResize(delay) {
      clearTimeout(_plotResizeTimer);
      _plotResizeTimer = setTimeout(function() {
        try { Shiny.setInputValue('plot_resize', Date.now(), {priority: 'event'}); } catch (e) {}
        try {
          var pl = document.getElementById('plotly_display');
          if (pl && window.Plotly) { Plotly.Plots.resize(pl); }
        } catch (e) {}
      }, delay || 400);
    }

    // ResizeObserver for plot containers - debounced to prevent flickering
    try { (function initPlotResizeObserver() {
      if (typeof ResizeObserver === 'undefined') return;
      var resizeTimer = null;
      var lastWidth = 0;
      var lastHeight = 0;
      var observer = new ResizeObserver(function(entries) {
        // Only trigger if size actually changed significantly (>10px)
        var entry = entries[0];
        if (!entry) return;
        var newWidth = entry.contentRect.width;
        var newHeight = entry.contentRect.height;
        if (Math.abs(newWidth - lastWidth) < 10 && Math.abs(newHeight - lastHeight) < 10) return;
        lastWidth = newWidth;
        lastHeight = newHeight;
        debouncedPlotResize(600);
      });
      window.addEventListener('load', function() {
        var plotPane = document.querySelector('.plot-pane');
        if (plotPane) observer.observe(plotPane);
        var plotCanvas = document.querySelector('.plot-canvas');
        if (plotCanvas) observer.observe(plotCanvas);
      });
    })(); } catch(_e) { console.warn('initPlotResizeObserver:', _e); }

    function setEditorTabClient(tab) {
      if (tab !== 'plot' && tab !== 'data') tab = 'editor';
      document.querySelectorAll('.editor-tab').forEach(function(t) { t.classList.remove('active'); });
      var tabEl = document.getElementById('tab_' + tab);
      if (tabEl) tabEl.classList.add('active');
      var editorPane = document.getElementById('editor_tab');
      var plotPane = document.getElementById('plot_tab');
      var dataPane = document.getElementById('data_tab');
      if (editorPane) editorPane.classList.toggle('active', tab === 'editor');
      if (plotPane) plotPane.classList.toggle('active', tab === 'plot');
      if (dataPane) dataPane.classList.toggle('active', tab === 'data');
      try { Shiny.setInputValue('editor_tab', tab, {priority: 'event'}); } catch (e) {}

      if (tab === 'editor') {
        setTimeout(function() {
          try { ace.edit('code_editor').resize(); } catch (e) {}
        }, 0);
      } else if (tab === 'plot') {
        setTimeout(function() {
          try {
            var pl = document.getElementById('plotly_display');
            if (pl && pl.style.display !== 'none' && window.Plotly) {
              Plotly.Plots.resize(pl);
            }
          } catch (e) {}
        }, 0);
      }
    }

    function fixMainHeight() {
      var main = document.querySelector('.main-content');
      if (!main) return;
      var header = document.querySelector('.header-section');
      var status = document.querySelector('.status-bar');
      var headerH = header ? header.offsetHeight : 0;
      var statusH = status ? status.offsetHeight : 0;
      var h = window.innerHeight - headerH - statusH;
      if (h < 240) h = 240;
      main.style.height = h + 'px';
    }

    function setSplitRatio(ratio) {
      var main = document.querySelector('.main-content');
      if (!main) return;
      var clamped = Math.max(20, Math.min(80, ratio));
      main.style.setProperty('--left-track', clamped + 'fr');
      main.style.setProperty('--right-track', (100 - clamped) + 'fr');
      localStorage.setItem('split_ratio', String(clamped));
      // Debounce plot re-render — only fire once dragging stops
      debouncedPlotResize(400);
    }

    function toggleFullscreenModal() {
      // Target the .modal wrapper (parent of .modal-dialog) where CSS rules apply
      var modalDialog = document.querySelector('.modal-dialog.plot-popout');
      if (!modalDialog) modalDialog = document.querySelector('.modal-dialog');
      if (!modalDialog) return;
      var modal = modalDialog.closest('.modal');
      if (!modal) return;
      
      modal.classList.toggle('modal-fullscreen');
      var isFullscreen = modal.classList.contains('modal-fullscreen');
      
      // Update button text
      var btn = modal.querySelector('.btn-fullscreen');
      if (btn) btn.textContent = isFullscreen ? 'Exit Fullscreen' : 'Fullscreen';
      
      // Force Shiny to detect new container size by triggering resize on output elements
      setTimeout(function() {
        // Dispatch a window resize event so Shiny output bindings recalculate dimensions
        window.dispatchEvent(new Event('resize'));
        
        // Also explicitly resize plotly if present
        try {
          var pl = document.getElementById('plotly_display_popout');
          if (pl && window.Plotly) { Plotly.Plots.resize(pl); }
        } catch (e) {}
        
        // Fire popout_resize to trigger server-side re-render
        try { Shiny.setInputValue('popout_resize', Date.now(), {priority: 'event'}); } catch (e) {}
        
        // Second pass after layout fully settles
        setTimeout(function() {
          window.dispatchEvent(new Event('resize'));
          try { Shiny.setInputValue('popout_resize', Date.now(), {priority: 'event'}); } catch (e) {}
          try {
            var pl2 = document.getElementById('plotly_display_popout');
            if (pl2 && window.Plotly) { Plotly.Plots.resize(pl2); }
          } catch (e) {}
        }, 400);
      }, 100);
    }

    function closeHelpOverlay() {
      var overlay = document.getElementById('help_overlay');
      if (overlay) overlay.classList.remove('visible');
    }

    function openHelpOverlay(sectionId) {
      var overlay = document.getElementById('help_overlay');
      if (!overlay) return;
      overlay.classList.add('visible');
      if (sectionId) {
        setTimeout(function() { helpScrollTo(sectionId); }, 0);
      }
    }

    function helpScrollTo(sectionId) {
      var section = document.getElementById('help_section_' + sectionId);
      if (!section) return;

      var content = document.querySelector('.help-content');
      if (content && section.scrollIntoView) {
        section.scrollIntoView({behavior: 'smooth', block: 'start'});
      }

      document.querySelectorAll('.help-nav-link').forEach(function(el) {
        el.classList.toggle('active', el.getAttribute('data-section') === sectionId);
      });
    }

    function initHelpOverlay() {
      var overlay = document.getElementById('help_overlay');
      if (!overlay) return;
      overlay.addEventListener('click', function(e) {
        if (e.target === overlay) closeHelpOverlay();
      });
    }

    function initSplit() {
      var saved = parseFloat(localStorage.getItem('split_ratio'));
      if (!isNaN(saved)) setSplitRatio(saved);
      var splitter = document.getElementById('splitter');
      if (!splitter) return;
      var dragging = false;
      var plotCanvas = document.querySelector('.plot-canvas');
      splitter.addEventListener('mousedown', function(e) {
        dragging = true;
        document.body.style.userSelect = 'none';
        document.body.style.cursor = 'col-resize';
        // Prevent iframes/plots from stealing pointer events during drag
        if (plotCanvas) plotCanvas.style.pointerEvents = 'none';
      });
      window.addEventListener('mouseup', function() {
        if (!dragging) return;
        dragging = false;
        document.body.style.userSelect = '';
        document.body.style.cursor = '';
        if (plotCanvas) plotCanvas.style.pointerEvents = '';
        // Final crisp re-render after drag ends
        debouncedPlotResize(150);
      });
      window.addEventListener('mousemove', function(e) {
        if (!dragging) return;
        var main = document.querySelector('.main-content');
        if (!main) return;
        var rect = main.getBoundingClientRect();
        var x = e.clientX - rect.left;
        var ratio = (x / rect.width) * 100;
        setSplitRatio(ratio);
      });
    }

    function initConsoleSplitter() {
      // Console splitter is handled by document-level delegation in the first script block
    }

    function toggleConsole() {
      _doToggleConsole();
    }

    function initConsoleScroll() {
      var target = document.getElementById('console_output');
      if (!target) return;
      var observer = new MutationObserver(function() {
        target.scrollTop = target.scrollHeight;
      });
      observer.observe(target, { childList: true, subtree: true, characterData: true });
      window._appObservers = window._appObservers || [];
      window._appObservers.push(observer);
    }

    function runSelection() {
      try {
        // Check if fallback textarea is being used
        var textareaEl = document.getElementById('code_editor_fallback');
        if (textareaEl) {
          var start = textareaEl.selectionStart;
          var end = textareaEl.selectionEnd;
          var selection = textareaEl.value.substring(start, end);
          if (selection && selection.trim().length > 0) {
            Shiny.setInputValue('run_selection', selection, {priority: 'event'});
          }
          return;
        }
        
        var editor = ace.edit('code_editor');
        var selection = editor.getSelectedText();
        if (selection && selection.trim().length > 0) {
          Shiny.setInputValue('run_selection', selection, {priority: 'event'});
        }
      } catch (e) {}
    }

    function switchChatTab(tab) {
      var tabs = ['chat', 'code', 'diff'];
      for (var i = 0; i < tabs.length; i++) {
        var t = document.getElementById('chat_tab_' + tabs[i]);
        var p = document.getElementById('chat_pane_' + tabs[i]);
        if (t) t.classList.toggle('active', tabs[i] === tab);
        if (p) p.classList.toggle('active', tabs[i] === tab);
      }

      // Ensure layout triggers after tab switch
      setTimeout(function() {
        fixMainHeight();
        if (tab === 'code') {
          try {
            var editor = ace.edit('ai_code_view');
            editor.resize();
          } catch (e) {}
        }
      }, 50);
    }

    function copyAiCode() {
      try {
        var code = '';
        var editorEl = document.getElementById('ai_code_view');
        if (editorEl) {
          try {
            var editor = ace.edit(editorEl);
            if (editor && editor.session) code = editor.getValue();
          } catch (ex) {}
        }
        // Fallback: read from server-side last_ai_code via hidden input
        if (!code) {
          var codeEl = editorEl ? editorEl.querySelector('.ace_text-layer') : null;
          if (codeEl) code = codeEl.innerText;
        }
        if (!code || code.length === 0) {
          Shiny.setInputValue('_copy_fail', Math.random());
          return;
        }
        // execCommand fallback for HTTP (non-HTTPS) contexts where navigator.clipboard is unavailable
        var ta = document.createElement('textarea');
        ta.value = code;
        ta.style.position = 'fixed';
        ta.style.left = '-9999px';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.focus();
        ta.select();
        var ok = document.execCommand('copy');
        document.body.removeChild(ta);
        if (ok) {
          Shiny.setInputValue('_copy_ok', Math.random());
        } else if (navigator.clipboard) {
          navigator.clipboard.writeText(code).then(function() {
            Shiny.setInputValue('_copy_ok', Math.random());
          });
        }
      } catch (e) {
        console.warn('Copy failed:', e);
      }
    }

    function initHotkeys() {
      document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
          closeHelpOverlay();
          var settings = document.getElementById('settings_overlay');
          if (settings) settings.classList.remove('visible');
        }
        if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'Enter') {
          runSelection();
          e.preventDefault();
        }
      });
    }

    function initEditorStorage() {
      try {
        var saved = localStorage.getItem('editor_code');
        if (!saved || !saved.length) return;
        
        // Check if fallback textarea is being used
        var textareaEl = document.getElementById('code_editor_fallback');
        if (textareaEl) {
          textareaEl.value = saved;
          return;
        }
        
        var editor = ace.edit('code_editor');
        if (editor) {
          editor.setValue(saved, -1);
          var timer = null;
          editor.session.on('change', function() {
            if (window.__suspendEditorAutosave) return;
            clearTimeout(timer);
            timer = setTimeout(function() {
              localStorage.setItem('editor_code', editor.getValue());
            }, 400);
          });
        }
      } catch (e) {}
    }

    var _booted = false;
    function _bootUi() {
      if (_booted) return;
      _booted = true;
      try { fixMainHeight(); } catch(e) {}
      try { initSplit(); } catch(e) {}
      try { initHelpOverlay(); } catch(e) {}
      try { initConsoleScroll(); } catch(e) {}
      try { initConsoleSplitter(); } catch(e) {}
      try { initHotkeys(); } catch(e) {}
      try { initEditorStorage(); } catch(e) {}
    }
    window.addEventListener('load', _bootUi);
    window.addEventListener('DOMContentLoaded', function() { setTimeout(_bootUi, 0); });
    if (document.readyState === 'complete' || document.readyState === 'interactive') setTimeout(_bootUi, 0);
    window.addEventListener('resize', fixMainHeight);
    window.addEventListener('resize', function() {
      debouncedPlotResize(400);
    });

    Shiny.addCustomMessageHandler('switchEditorTab', function(tab) {
      setEditorTabClient(tab);
    });

    Shiny.addCustomMessageHandler('registerCleanup', function(data) {
      window.addEventListener('beforeunload', function() {
        if (window._appObservers) {
          window._appObservers.forEach(function(obs) { try { obs.disconnect(); } catch(e) {} });
          window._appObservers = [];
        }
      });
    });

    Shiny.addCustomMessageHandler('toggleConsole', function(data) {
      _doToggleConsole();
    });

    Shiny.addCustomMessageHandler('toggleModelType', function(type) {
      document.querySelectorAll('.model-toggle-btn').forEach(function(b) { b.classList.remove('active'); });
      document.getElementById(type + '_toggle').classList.add('active');
      document.getElementById('cloud_config').style.display = type === 'cloud' ? 'block' : 'none';
      document.getElementById('ollama_config').style.display = type === 'ollama' ? 'block' : 'none';
      document.getElementById('ollama_config').classList.toggle('visible', type === 'ollama');
    });

    Shiny.addCustomMessageHandler('ensureAceReady', function(data) {
      var preferredValue = (data && typeof data.value !== 'undefined') ? String(data.value) : '';
      var tries = 0;
      var maxTries = 40;
      function initAceNow() {
        var editorEl = document.getElementById('code_editor');
        if (!editorEl || typeof ace === 'undefined') {
          tries += 1;
          if (tries < maxTries) setTimeout(initAceNow, 100);
          return;
        }
        try {
          var editor = ace.edit(editorEl);
          if (!editor || !editor.session) throw new Error('Ace session unavailable');
          try { editor.setTheme('ace/theme/monokai'); } catch (e) {}
          try { editor.session.setMode('ace/mode/r'); } catch (e) {}
          var currentVal = '';
          try { currentVal = editor.getValue() || ''; } catch (e) {}
          if ((!currentVal || !currentVal.trim()) && preferredValue) {
            editor.session.setValue(preferredValue);
            editor.selection.clearSelection();
            editor.moveCursorTo(0, 0);
            try { Shiny.setInputValue('code_editor', preferredValue, {priority: 'event'}); } catch (e) {}
          }
          setTimeout(function() { try { editor.resize(); } catch (e) {} }, 0);
        } catch (e) {
          tries += 1;
          if (tries < maxTries) setTimeout(initAceNow, 120);
          else {
            // Fallback: Replace with textarea if Ace fails to load
            console.warn('Ace editor failed to initialize after', maxTries, 'tries. Using textarea fallback.');
            if (editorEl && editorEl.parentNode) {
              var textarea = document.createElement('textarea');
              textarea.id = 'code_editor_fallback';
              textarea.className = 'fallback-textarea';
              textarea.value = preferredValue || '# AI R Assistant\n# Write your R code here\n\n# Ace editor failed to load, using basic textarea\n\nprint(\"Hello, R!\")';
              textarea.style.width = '100%';
              textarea.style.height = '100%';
              textarea.style.fontFamily = 'monospace';
              textarea.style.fontSize = '14px';
              textarea.style.border = 'none';
              textarea.style.outline = 'none';
              textarea.style.resize = 'none';
              textarea.style.backgroundColor = '#272822';
              textarea.style.color = '#f8f8f2';
              textarea.style.padding = '10px';
              textarea.addEventListener('input', function() {
                try { Shiny.setInputValue('code_editor', textarea.value, {priority: 'event'}); } catch (e) {}
                // Autosave to localStorage
                if (window.__suspendEditorAutosave) return;
                clearTimeout(textarea._autosaveTimer);
                textarea._autosaveTimer = setTimeout(function() {
                  try { localStorage.setItem('editor_code', textarea.value); } catch (e) {}
                }, 400);
              });
              editorEl.parentNode.replaceChild(textarea, editorEl);
              try { Shiny.setInputValue('code_editor', textarea.value, {priority: 'event'}); } catch (e) {}
            }
          }
        }
      }
      initAceNow();
    });

    Shiny.addCustomMessageHandler('updateStatus', function(data) {
      var dot = document.getElementById('connection_dot');
      var status = document.getElementById('connection_status');
      dot.className = 'status-dot ' + (data.connected ? 'connected' : 'disconnected');
      status.textContent = data.message;
    });

    Shiny.addCustomMessageHandler('updateOllamaStatus', function(data) {
      var pill = document.getElementById('ollama_status');
      if (!pill) return;
      pill.classList.remove('ok', 'bad');
      pill.classList.add(data.ok ? 'ok' : 'bad');
      pill.textContent = data.message || (data.ok ? 'Connected' : 'Unavailable');
    });

    Shiny.addCustomMessageHandler('copyAiCode', function() {
      copyAiCode();
    });

    // Direct JS fallback for setting Refined Code editor value
    Shiny.addCustomMessageHandler('setAiCodeValue', function(data) {
      try {
        var val = (data && typeof data.value !== 'undefined') ? data.value : '';
        var editorEl = document.getElementById('ai_code_view');
        if (editorEl) {
          var editor = ace.edit(editorEl);
          if (editor && editor.session) {
            editor.session.setValue(val);
            editor.selection.clearSelection();
            editor.moveCursorTo(0, 0);
            setTimeout(function() { editor.resize(); }, 100);
          }
        }
      } catch (e) {
        console.error('Error in setAiCodeValue:', e);
      }
    });

    // Auto-switch to Refined Code tab when code is extracted
    Shiny.addCustomMessageHandler('switchToRefinedCode', function(data) {
      try {
        switchChatTab('code');
      } catch (e) {
        try { _doChatTab('code'); } catch (e2) {}
      }
    });

    Shiny.addCustomMessageHandler('setEditorValue', function(data) {
      // setEditorValue received
      try {
        var val = (data && typeof data.value !== 'undefined') ? data.value : '';
        
        // Check if fallback textarea is being used
        var textareaEl = document.getElementById('code_editor_fallback');
        if (textareaEl) {
          textareaEl.value = val;
          try { Shiny.setInputValue('code_editor', val, {priority: 'event'}); } catch (e) {}
          return;
        }
        
        var editorEl = document.getElementById('code_editor');
        if (!editorEl) {
          console.error('Div code_editor not found in DOM');
          return;
        }
        var editor = ace.edit(editorEl);
        if (!editor || !editor.session) {
          console.error('Ace editor instance not found on code_editor');
          return;
        }
        window.__suspendEditorAutosave = true;
        
        // Inserting value into Ace editor
        
        editor.session.setValue(val);
        editor.selection.clearSelection();
        editor.moveCursorTo(0, 0);
        
        try { localStorage.setItem('editor_code', val); } catch (e) {}
        Shiny.setInputValue('code_editor', val, {priority: 'event'});
        
        setTimeout(function() { 
          window.__suspendEditorAutosave = false;
          editor.resize();
          editor.focus();
        }, 300);
      } catch (e) {
        console.error('CRITICAL Error in setEditorValue JS:', e);
        window.__suspendEditorAutosave = false;
      }
    });

    Shiny.addCustomMessageHandler('insertCodeAtCursor', function(data) {
      // Insert code at cursor position
      try {
        var code = (data && typeof data.code !== 'undefined') ? data.code : '';
        if (!code) return;
        
        // Check if fallback textarea is being used
        var textareaEl = document.getElementById('code_editor_fallback');
        if (textareaEl) {
          var start = textareaEl.selectionStart;
          var end = textareaEl.selectionEnd;
          var val = textareaEl.value;
          textareaEl.value = val.substring(0, start) + code + val.substring(end);
          textareaEl.selectionStart = textareaEl.selectionEnd = start + code.length;
          try { Shiny.setInputValue('code_editor', textareaEl.value, {priority: 'event'}); } catch (e) {}
          textareaEl.focus();
          return;
        }
        
        var editorEl = document.getElementById('code_editor');
        if (!editorEl) {
          console.error('Div code_editor not found in DOM');
          return;
        }
        var editor = ace.edit(editorEl);
        if (!editor || !editor.session) {
          console.error('Ace editor instance not found on code_editor');
          return;
        }
        window.__suspendEditorAutosave = true;
        
        // Insert at current cursor position
        var pos = editor.getCursorPosition();
        editor.session.insert(pos, code);
        
        // Update Shiny input and localStorage
        var newVal = editor.getValue();
        try { localStorage.setItem('editor_code', newVal); } catch (e) {}
        Shiny.setInputValue('code_editor', newVal, {priority: 'event'});
        
        setTimeout(function() { 
          window.__suspendEditorAutosave = false;
          editor.resize();
          editor.focus();
        }, 100);
      } catch (e) {
        console.error('CRITICAL Error in insertCodeAtCursor JS:', e);
        window.__suspendEditorAutosave = false;
      }
    });

    Shiny.addCustomMessageHandler('plotType', function(type) {
      var gg = document.getElementById('plot_display');
      var pl = document.getElementById('plotly_display');
      var ggPop = document.getElementById('plot_display_popout');
      var plPop = document.getElementById('plotly_display_popout');
      if (gg) gg.style.display = type === 'ggplot' ? 'block' : 'none';
      if (pl) pl.style.display = type === 'plotly' ? 'block' : 'none';
      if (ggPop) ggPop.style.display = type === 'ggplot' ? 'block' : 'none';
      if (plPop) plPop.style.display = type === 'plotly' ? 'block' : 'none';
    });

    Shiny.addCustomMessageHandler('scrollChat', function() {
      try {
        var el = document.querySelector('.chat-messages');
        if (el) el.scrollTop = el.scrollHeight;
      } catch (e) {}
    });

    Shiny.addCustomMessageHandler('reflowLayout', function() {
      // Prevent panels shrinking after heavy reflows (plots, template loads).
      try { fixMainHeight(); } catch (e) {}
      try {
        var saved = parseFloat(localStorage.getItem('split_ratio'));
        if (!isNaN(saved)) setSplitRatio(saved);
      } catch (e) {}
      try { ace.edit('code_editor').resize(); } catch (e) {}
    });

    // Sync editor value to Shiny before Run button click fires
    // This ensures input$code_editor always has the latest user-typed content
    document.addEventListener('mousedown', function(e) {
      var btn = e.target.closest('#run_btn');
      if (!btn) return;
      try {
        var editorEl = document.getElementById('code_editor');
        if (editorEl) {
          var editor = ace.edit(editorEl);
          if (editor && editor.session) {
            var val = editor.getValue();
            Shiny.setInputValue('code_editor', val, {priority: 'event'});
          }
        }
        var fallback = document.getElementById('code_editor_fallback');
        if (fallback) {
          Shiny.setInputValue('code_editor', fallback.value, {priority: 'event'});
        }
      } catch (ex) {}
    });
  "))
)

# Server
server <- function(input, output, session) {
  `%||%` <- function(a, b) if (!is.null(a)) a else b

  # Session-scoped lang reactive (local <- avoids locked namespace error when
  # installed as a package; translate is redefined here to close over it).
  lang <- reactiveVal("en")
  translate <- function(k) {
    cur <- tryCatch(lang(), error = function(e) "en")
    if (identical(cur, "es")) {
      v <- translations_es[[k]]
      if (!is.null(v)) return(v)
    }
    translations_en[[k]] %||% k
  }

  # Reactive values
  messages <- reactiveVal(list(list(role = "assistant", content = translations_en$welcome)))
  model_type <- reactiveVal("ollama")  # "cloud" or "ollama"
  editor_tab_current <- reactiveVal("editor") # tracks both user + programmatic tab switches
  current_plot <- reactiveVal(NULL)
  current_plot_type <- reactiveVal("ggplot")
  last_plot_code <- reactiveVal("") # sanitized code used for the current_plot
  template_loading <- reactiveVal(FALSE)  # guard to prevent triple auto-plot during template load
  last_ai_code <- reactiveVal("")   # last extracted code block from assistant (reliable insert source)
  auto_fix_pending <- reactiveVal(FALSE)  # guard to prevent infinite auto-fix loops
  pre_ai_code <- reactiveVal("")   # snapshot of editor code before AI call (for diff view)
  uploaded_data <- reactiveVal(NULL)  # uploaded dataset for Data tab
  last_api_ms <- reactiveVal(NA_real_)
  last_api_provider <- reactiveVal("")
  active_template <- reactiveVal("")
  audit_log <- reactiveVal(list())
  cache_hits <- reactiveVal(0)
  api_calls <- reactiveVal(0)
  ollama_status <- reactiveVal(list(ok = FALSE, message = "Unknown"))
  ollama_models_cache <- reactiveVal(NULL)  # cache fetched model list
  stop_requested <- reactiveVal(FALSE)       # flag to stop AI generation
  last_user_message <- reactiveVal("")        # store last user message for re-ask

  add_audit <- function(event, details = "") {
    entry <- list(
      ts = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      event = as.character(event),
      details = as.character(details)
    )
    x <- audit_log()
    x[[length(x) + 1]] <- entry
    if (length(x) > 200) x <- x[(length(x) - 199):length(x)]
    audit_log(x)
  }

  # ── Data Upload Handler ──
  observeEvent(input$data_upload, {
    req(input$data_upload)
    file <- input$data_upload
    ext <- tolower(tools::file_ext(file$name))
    tryCatch({
      df <- if (ext == "csv") {
        read.csv(file$datapath, stringsAsFactors = FALSE)
      } else if (ext == "tsv") {
        read.delim(file$datapath, stringsAsFactors = FALSE)
      } else if (ext %in% c("xlsx", "xls")) {
        if (!requireNamespace("readxl", quietly = TRUE)) {
          showNotification("Install readxl package: install.packages('readxl')", type = "error")
          return()
        }
        readxl::read_excel(file$datapath)
      } else if (ext == "rds") {
        readRDS(file$datapath)
      } else {
        showNotification(paste("Unsupported format:", ext), type = "error")
        return()
      }
      uploaded_data(df)
      # Make data available in user code via globalenv
      assign("uploaded_data", df, envir = globalenv())
      add_audit("data_upload", paste(file$name, nrow(df), "rows", ncol(df), "cols"))
      showNotification(paste0("Loaded '", file$name, "': ", nrow(df), " rows x ", ncol(df), " cols"), type = "message", duration = 5)
      # Auto-generate starter code
      starter <- paste0(
        "# Data loaded from: ", file$name, "\n",
        "# Access via: uploaded_data\n",
        "library(ggplot2)\n\n",
        "str(uploaded_data)\n",
        "head(uploaded_data)\n"
      )
      shinyAce::updateAceEditor(session, "code_editor", value = starter)
      session$sendCustomMessage("setEditorValue", list(value = starter))
    }, error = function(e) {
      showNotification(paste("File read error:", e$message), type = "error", duration = 8)
    })
  })

  if (requireNamespace("DT", quietly = TRUE)) {
    output$data_preview <- DT::renderDataTable({
      df <- uploaded_data()
      if (is.null(df)) return(NULL)
      DT::datatable(df, options = list(pageLength = 15, scrollX = TRUE, scrollY = "400px"),
                    style = "bootstrap", class = "compact stripe hover")
    })
  }

  output$data_info_display <- renderUI({
    df <- uploaded_data()
    if (is.null(df)) return(span(style = "color: #888;", "No data loaded"))
    span(style = "color: #00d4ff; font-size: 12px;",
         paste0(nrow(df), " rows x ", ncol(df), " cols | ",
                paste(head(names(df), 5), collapse = ", "),
                if (ncol(df) > 5) "..." else ""))
  })

  error_message <- function(e) {
    msg <- tryCatch(conditionMessage(e), error = function(...) "")
    if (length(msg) == 0 || is.null(msg) || is.na(msg) || !nzchar(msg)) {
      msg <- tryCatch(as.character(e), error = function(...) "")
    }
    if (length(msg) == 0 || is.null(msg) || is.na(msg) || !nzchar(msg)) "Unknown error" else msg
  }

  prompt_templates <- list(
    explain = "System: Explain the code step by step. Use clear headings and bullets. Point out any pitfalls or assumptions.",
    debug = "System: Identify bugs, runtime errors, and logical issues. Provide fixes with minimal changes.",
    optimize = "System: Refactor for clarity and performance. Prefer vectorized R and tidy code style."
  )

  # i18n update
  observeEvent(input$lang_select, {
    lang(input$lang_select)
    welcome_msg <- if (lang() == "es") translations_es$welcome else translations_en$welcome
    messages(list(list(role = "assistant", content = welcome_msg)))
  })

  # Model type toggle
  observeEvent(input$cloud_toggle, {
    model_type("cloud")
    session$sendCustomMessage("toggleModelType", "cloud")
  })

  observeEvent(input$ollama_toggle, {
    model_type("ollama")
    session$sendCustomMessage("toggleModelType", "ollama")
    # Refresh models (which also tests connection) — non-blocking
    refresh_ollama_models()
  })

  # Editor tab switching
  switch_editor_tab <- function(tab) {
    tab <- if (identical(tab, "plot")) "plot" else "editor"
    editor_tab_current(tab)
    session$sendCustomMessage("switchEditorTab", tab)
  }

  ensure_editor_seeded <- function() {
    starter_code <- "# AI R Assistant\n# Write your R code here\n\n# Quick starter example\nlibrary(ggplot2)\nggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +\n  geom_point(size = 3) +\n  theme_minimal()"
    current_code <- isolate(input$code_editor)
    session$sendCustomMessage("ensureAceReady", list(value = starter_code))
    if (is.null(current_code) || !nzchar(trimws(current_code))) {
      shinyAce::updateAceEditor(session, "code_editor", value = starter_code)
      session$sendCustomMessage("setEditorValue", list(value = starter_code))
    }
  }

  session$onFlushed(function() {
    starter_code <- "# AI R Assistant\n# Write your R code here\n\n# Quick starter example\nlibrary(ggplot2)\nggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +\n  geom_point(size = 3) +\n  theme_minimal()"
    session$sendCustomMessage("ensureAceReady", list(value = starter_code))
    ensure_editor_seeded()
  }, once = TRUE)

  observeEvent(input$editor_tab, {
    # UI switches client-side immediately; keep server state in sync.
    editor_tab_current(if (identical(input$editor_tab, "plot")) "plot" else "editor")
  })

  # Render plots once; updates via current_plot reactivity.
  output$plot_display <- renderPlot({
    input$plot_resize
    result <- current_plot()
    if (is.null(result)) {
      # Show empty plot with message when no valid plot
      plot.new()
      text(0.5, 0.5, "No plot available\nRun code to generate a chart", cex = 1.2, col = "#666666")
      return()
    }
    tryCatch({
      if (inherits(result, "ggplot")) {
        print(result)
      } else if (inherits(result, "recordedplot")) {
        replayPlot(result)
      } else {
        plot.new()
        text(0.5, 0.5, "Plot type not supported for display", cex = 1.2, col = "#ff6b6b")
      }
    }, error = function(e) {
      plot.new()
      text(0.5, 0.5, paste("Render error:\n", e$message), cex = 1, col = "#ff6b6b")
    })
  }, bg = "white")

  if (requireNamespace("plotly", quietly = TRUE)) {
    output$plotly_display <- plotly::renderPlotly({
      result <- current_plot()
      if (is.null(result)) {
        # Return empty plotly plot with message
        plotly::plot_ly() %>%
          plotly::add_annotations(
            text = "No interactive plot available<br>Run code to generate a plotly chart",
            showarrow = FALSE,
            font = list(size = 14, color = "#666666")
          ) %>%
          plotly::layout(
            xaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE),
            yaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE)
          )
      } else if (inherits(result, "plotly")) {
        result
      } else {
        # Not a plotly object
        NULL
      }
    })
  }


  # API key retrieval (by provider)
  # ── API Key persistence ──
  api_keys_dir <- file.path(tools::R_user_dir("aiRAssistant", "data"))
  api_keys_file <- file.path(api_keys_dir, "api_keys.rds")

  # Load saved keys on startup and populate the Settings fields
  observe({
    if (!file.exists(api_keys_file)) return()
    saved <- tryCatch(readRDS(api_keys_file), error = function(e) list())
    if (nzchar(saved$openai %||% ""))
      updateTextInput(session, "settings_key_openai", value = saved$openai)
    if (nzchar(saved$anthropic %||% ""))
      updateTextInput(session, "settings_key_anthropic", value = saved$anthropic)
    if (nzchar(saved$gemini %||% ""))
      updateTextInput(session, "settings_key_gemini", value = saved$gemini)
  }) |> bindEvent(TRUE, once = TRUE)

  # Save keys handler
  observeEvent(input$save_api_keys, {
    keys <- list(
      openai    = input$settings_key_openai %||% "",
      anthropic = input$settings_key_anthropic %||% "",
      gemini    = input$settings_key_gemini %||% ""
    )
    tryCatch({
      if (!dir.exists(api_keys_dir)) dir.create(api_keys_dir, recursive = TRUE)
      saveRDS(keys, api_keys_file)
      showNotification("API keys saved securely.", type = "message", duration = 3)
    }, error = function(e) {
      showNotification(paste("Failed to save keys:", e$message), type = "error", duration = 5)
    })
  })

  get_cloud_api_key <- function(provider) {
    provider <- provider %||% "openai"
    provider <- as.character(provider)

    # Check order: Settings API Keys section -> provider-specific panel -> env var -> keyring
    settings_key <- switch(provider,
      "openai"    = input$settings_key_openai %||% "",
      "anthropic" = input$settings_key_anthropic %||% "",
      "gemini"    = input$settings_key_gemini %||% "",
      ""
    )
    if (nzchar(settings_key)) return(settings_key)

    # Provider-specific panel input (conditional panels)
    panel_key <- switch(provider,
      "openai"     = input$api_key_openai %||% "",
      "anthropic"  = input$api_key_anthropic %||% "",
      "gemini"     = input$api_key_gemini %||% "",
      "deepseek"   = input$api_key_deepseek %||% "",
      "groq"       = input$api_key_groq %||% "",
      "openrouter" = input$api_key_openrouter %||% "",
      ""
    )
    if (nzchar(panel_key)) return(panel_key)

    # Environment variable
    env_name <- switch(provider,
      "openai"     = "OPENAI_API_KEY",
      "anthropic"  = "ANTHROPIC_API_KEY",
      "gemini"     = "GEMINI_API_KEY",
      "deepseek"   = "DEEPSEEK_API_KEY",
      "groq"       = "GROQ_API_KEY",
      "openrouter" = "OPENROUTER_API_KEY",
      ""
    )
    if (nzchar(env_name)) {
      key <- Sys.getenv(env_name, "")
      if (nzchar(key)) return(key)
    }

    # Keyring
    kr_name <- switch(provider,
      "openai"     = "openai_api_key",
      "anthropic"  = "anthropic_api_key",
      "gemini"     = "gemini_api_key",
      "deepseek"   = "deepseek_api_key",
      "groq"       = "groq_api_key",
      "openrouter" = "openrouter_api_key",
      ""
    )
    if (nzchar(kr_name)) {
      kr <- tryCatch({ keyring::key_get(kr_name) }, error = function(e) "")
      if (nzchar(kr)) return(kr)
    }

    ""
  }

  update_ollama_status <- function(ok, message) {
    ollama_status(list(ok = ok, message = message))
    tryCatch(
      session$sendCustomMessage("updateOllamaStatus", list(ok = ok, message = message)),
      error = function(e) NULL
    )
  }

  output$ollama_status_ui <- renderUI({
    st <- ollama_status()
    cls <- if (isTRUE(st$ok)) "status-pill ok" else "status-pill bad"
    msg <- st$message %||% "Unknown"
    span(id = "ollama_status", class = cls, msg)
  })

  test_ollama_connection <- function(url = NULL) {
    if (is.null(url)) {
      url <- isolate(input$ollama_url)
    }
    base_url <- normalize_ollama_url(url)
    if (!nzchar(base_url)) {
      update_ollama_status(FALSE, "Missing URL")
      return(FALSE)
    }
    ok <- FALSE
    msg <- "Offline"
    tryCatch({
      resp <- httr::GET(paste0(base_url, "/api/tags"), httr::timeout(3))
      if (httr::status_code(resp) == 200) {
        ok <- TRUE
        models_data <- tryCatch(
          jsonlite::fromJSON(httr::content(resp, "text", encoding = "UTF-8")),
          error = function(e) NULL
        )
        n_models <- if (!is.null(models_data$models)) NROW(models_data$models) else 0L
        msg <- paste0("Connected (", n_models, " model", if (!identical(n_models, 1L)) "s", ")")
      } else {
        msg <- paste("HTTP", httr::status_code(resp))
      }
    }, error = function(e) {
      msg_text <- error_message(e)
      if (grepl("Timeout|timed out", msg_text, ignore.case = TRUE)) {
        msg <<- "Timeout"
      } else if (grepl("Connection refused", msg_text, ignore.case = TRUE)) {
        msg <<- "Not running"
      } else {
        msg <<- "Offline"
      }
    })
    update_ollama_status(ok, msg)
    ok
  }

  refresh_ollama_models <- function(url = NULL) {
    tryCatch({
      if (is.null(url)) {
        url <- isolate(input$ollama_url)
      }
      base_url <- normalize_ollama_url(url)
      if (!nzchar(base_url)) {
        update_ollama_status(FALSE, "Missing URL")
        return(FALSE)
      }
      resp <- httr::GET(paste0(base_url, "/api/tags"), httr::timeout(5))
      if (httr::status_code(resp) == 200) {
        models_data <- jsonlite::fromJSON(httr::content(resp, "text", encoding = "UTF-8"))
        if (!is.null(models_data$models) && NROW(models_data$models) > 0) {
          model_names <- models_data$models$name
          # Build descriptive labels with size info if available
          model_sizes <- if (!is.null(models_data$models$size)) {
            paste0(model_names, " (", round(models_data$models$size / 1e9, 1), "GB)")
          } else {
            model_names
          }
          names(model_names) <- model_sizes
          # Preserve current selection if still available
          current_sel <- isolate(input$ollama_model)
          sel <- if (!is.null(current_sel) && current_sel %in% model_names) current_sel else model_names[1]
          updateSelectInput(session, "ollama_model", choices = model_names, selected = sel)
          ollama_models_cache(model_names)
          showNotification(paste("Found", length(model_names), "Ollama model(s)"), type = "message", duration = 3)
        } else {
          showNotification("Ollama connected but no models installed. Pull a model first: ollama pull codellama:7b", type = "warning", duration = 8)
        }
        update_ollama_status(TRUE, "Connected")
        return(TRUE)
      }
      update_ollama_status(FALSE, paste("HTTP", httr::status_code(resp)))
      FALSE
    }, error = function(e) {
      update_ollama_status(FALSE, "Offline")
      FALSE
    })
  }

  observeEvent(input$refresh_ollama, { refresh_ollama_models() })

  observeEvent(input$test_ollama, {
    ok <- refresh_ollama_models()
    if (ok) {
      showNotification("Ollama connection OK", type = "message", duration = 3)
    } else {
      showNotification("Cannot reach Ollama. Is it running?", type = "error", duration = 5)
    }
  })

  # Debounced URL change — wait 1.5s of idle before reconnecting
  ollama_url_debounced <- debounce(reactive({ input$ollama_url }), 1500)

  observeEvent(input$ollama_url, {
    normalized <- normalize_ollama_url(input$ollama_url)
    if (nzchar(normalized) && normalized != input$ollama_url) {
      updateTextInput(session, "ollama_url", value = normalized)
    }
  })

  observeEvent(ollama_url_debounced(), {
    refresh_ollama_models()
  }, ignoreInit = TRUE)

  # Delayed Ollama auto-check on startup (runs once after 2 seconds)
  local({
    startup_done <- reactiveVal(FALSE)
    observe({
      invalidateLater(2000, session)
      if (!isolate(startup_done())) {
        startup_done(TRUE)
        url <- isolate(input$ollama_url)
        if (is.null(url) || !nzchar(trimws(url))) url <- "http://localhost:11434"
        refresh_ollama_models(url)
      }
    })
  })

  # Validate chart code before execution
  validate_chart_code <- function(code) {
    if (!nzchar(code)) return(list(valid = FALSE, message = "Empty code"))

    # Check for basic syntax
    parsed <- tryCatch({
      parse(text = code)
    }, error = function(e) {
      return(list(valid = FALSE, message = paste("Syntax error:", e$message)))
    })

    # Check for required packages
    required_pkgs <- c("ggplot2")
    missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing_pkgs) > 0) {
      return(list(valid = FALSE, message = paste("Missing required packages:", paste(missing_pkgs, collapse = ", "))))
    }

    # Check if code likely produces a plot
    has_plot_indicators <- grepl("ggplot\\(|plot\\(|geom_|plotly::|qplot\\(", code)
    if (!has_plot_indicators) {
      return(list(valid = FALSE, message = "Code does not appear to generate a plot"))
    }

    list(valid = TRUE, message = "Code appears valid")
  }

  # Chart Templates - pass-through (no injection to keep templates clean and stable)
  enhance_template <- function(code) code

  chart_templates <- list(
    # ── Line Chart ──────────────────────────────────────────────
    line_chart = 'library(ggplot2)

# Publication-quality time series line chart
set.seed(42)
dates <- seq(as.Date("2024-01-01"), by = "month", length.out = 12)
data <- data.frame(
  date = rep(dates, 3),
  value = c(cumsum(rnorm(12, 5, 2)), cumsum(rnorm(12, 4, 3)),
            cumsum(rnorm(12, 6, 2.5))),
  series = rep(c("Product A", "Product B", "Product C"), each = 12)
)

ggplot(data, aes(x = date, y = value, color = series, group = series)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5, stroke = 0.4) +
  scale_color_brewer(palette = "Dark2") +
  scale_x_date(date_labels = "%b %Y", date_breaks = "2 months",
               expand = expansion(mult = 0.02)) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.08))) +
  labs(title = "Monthly Performance Trends",
       subtitle = "Cumulative values over time",
       x = NULL, y = "Cumulative Value", color = NULL,
       caption = "Source: Simulated data | Error bars omitted for clarity") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    axis.line = element_line(color = "grey70", linewidth = 0.3),
    axis.ticks = element_line(color = "grey70", linewidth = 0.3)
  )',

    # ── Scatter + Regression ────────────────────────────────────
    scatter_regression = 'library(ggplot2)

# Scatter plot with grouped regression and confidence bands
set.seed(123)
n <- 120
data <- data.frame(
  x = runif(n, 0, 100),
  group = sample(c("Group A", "Group B"), n, replace = TRUE)
)
data$y <- 2 + 0.5 * data$x +
  ifelse(data$group == "Group A", 10, 0) + rnorm(n, 0, 8)

ggplot(data, aes(x = x, y = y, color = group, fill = group)) +
  geom_point(alpha = 0.6, size = 2, shape = 16) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE, alpha = 0.15, linewidth = 1) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Relationship Analysis with Regression",
       subtitle = "Linear fit with 95% confidence interval",
       x = "Independent Variable", y = "Dependent Variable",
       color = NULL, fill = NULL,
       caption = "Method: OLS linear regression") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "inside",
    legend.position.inside = c(0.15, 0.92),
    legend.background = element_rect(fill = "white", color = NA),
    panel.grid.minor = element_blank(),
    axis.line = element_line(color = "grey70", linewidth = 0.3)
  )',

    # ── Grouped Bar Chart ───────────────────────────────────────
    bar_grouped = 'library(ggplot2)

# Grouped bar chart with standard error bars
data <- data.frame(
  quarter = rep(c("Q1", "Q2", "Q3", "Q4"), each = 3),
  region = rep(c("Region A", "Region B", "Region C"), 4),
  value = c(45, 52, 38, 58, 61, 45, 62, 70, 55, 75, 82, 68),
  se = c(3.2, 4.1, 2.8, 3.5, 4.5, 3.0, 3.8, 5.0, 3.3, 4.2, 5.5, 4.0)
)

ggplot(data, aes(x = quarter, y = value, fill = region)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_errorbar(aes(ymin = value - se, ymax = value + se),
                position = position_dodge(width = 0.8), width = 0.2,
                linewidth = 0.4) +
  scale_fill_brewer(palette = "Set2") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Quarterly Performance by Region",
       subtitle = "Mean \\u00B1 SE",
       x = NULL, y = "Revenue ($M)", fill = NULL,
       caption = "Error bars represent standard error of the mean") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "top",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    axis.line.x = element_line(color = "grey70", linewidth = 0.3)
  )',

    # ── Histogram + Density ─────────────────────────────────────
    histogram_density = 'library(ggplot2)

# Distribution comparison: histogram with density overlay
set.seed(456)
data <- data.frame(
  value = c(rnorm(500, 50, 10), rnorm(500, 65, 12)),
  group = rep(c("Control", "Treatment"), each = 500)
)

ggplot(data, aes(x = value, fill = group)) +
  geom_histogram(aes(y = after_stat(density)), bins = 35,
                 alpha = 0.45, position = "identity", color = "white",
                 linewidth = 0.1) +
  geom_density(aes(color = group), linewidth = 1, fill = NA) +
  geom_vline(xintercept = c(50, 65), linetype = "dashed",
             color = "grey40", linewidth = 0.4) +
  annotate("text", x = 50, y = Inf, label = "\\u03BC = 50", vjust = 2,
           hjust = 1.1, size = 3.2, color = "grey30") +
  annotate("text", x = 65, y = Inf, label = "\\u03BC = 65", vjust = 2,
           hjust = -0.1, size = 3.2, color = "grey30") +
  scale_fill_brewer(palette = "Set1") +
  scale_color_brewer(palette = "Set1") +
  labs(title = "Distribution Comparison",
       subtitle = "Histogram with kernel density estimates",
       x = "Value", y = "Density", fill = NULL, color = NULL,
       caption = "Dashed lines indicate group means") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "top",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )',

    # ── Box + Violin Plot ───────────────────────────────────────
    boxplot_comparison = 'library(ggplot2)

# Violin + box plot with individual observations
set.seed(789)
data <- data.frame(
  group = rep(c("Baseline", "Week 4", "Week 8", "Week 12"), each = 60),
  score = c(rnorm(60, 50, 10), rnorm(60, 55, 12),
            rnorm(60, 62, 11), rnorm(60, 70, 9))
)
data$group <- factor(data$group,
                     levels = c("Baseline", "Week 4", "Week 8", "Week 12"))

ggplot(data, aes(x = group, y = score, fill = group)) +
  geom_violin(alpha = 0.35, trim = FALSE, color = NA) +
  geom_boxplot(width = 0.18, fill = "white", outlier.shape = NA,
               linewidth = 0.4) +
  geom_jitter(width = 0.1, size = 1, alpha = 0.25, color = "grey30") +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 3.5,
               color = "red3") +
  scale_fill_brewer(palette = "Blues") +
  labs(title = "Treatment Response Over Time",
       subtitle = "Violin + box plots with observations (red diamond = mean)",
       x = NULL, y = "Score",
       caption = "N = 60 per group | Diamond = mean, line = median") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "none",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    axis.line = element_line(color = "grey70", linewidth = 0.3)
  )',

    # ── Correlation Heatmap ─────────────────────────────────────
    heatmap_correlation = 'library(ggplot2)

# Correlation heatmap with coefficient labels
data(mtcars)
vars <- c("mpg", "disp", "hp", "drat", "wt", "qsec")
cor_matrix <- round(cor(mtcars[, vars]), 2)
df <- as.data.frame(as.table(cor_matrix))
colnames(df) <- c("Var1", "Var2", "r")

ggplot(df, aes(x = Var1, y = Var2, fill = r)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = r, color = abs(r) > 0.6),
            size = 3.8, fontface = "bold") +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
                       midpoint = 0, limits = c(-1, 1),
                       name = "Pearson r") +
  scale_color_manual(values = c("TRUE" = "white", "FALSE" = "grey20"),
                     guide = "none") +
  labs(title = "Correlation Matrix",
       subtitle = "Selected mtcars variables",
       x = NULL, y = NULL,
       caption = "Pearson correlation coefficients") +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    axis.text.x = element_text(angle = 45, hjust = 1, face = "bold"),
    axis.text.y = element_text(face = "bold"),
    panel.grid = element_blank(),
    legend.position = "right"
  )',

    # ── Faceted Plot ────────────────────────────────────────────
    faceted_plot = 'library(ggplot2)

# Multi-panel faceted analysis
set.seed(101)
data <- expand.grid(x = 1:20,
                    panel = c("Cohort A", "Cohort B", "Cohort C", "Cohort D"))
data$y <- with(data, {
  base <- sin(x / 3) * 10 + 20
  offset <- as.numeric(factor(panel)) * 5
  base + rnorm(nrow(data), 0, 2) + offset
})

ggplot(data, aes(x = x, y = y)) +
  geom_line(color = "#2166AC", linewidth = 0.9) +
  geom_point(color = "#2166AC", size = 1.8) +
  facet_wrap(~ panel, scales = "free_y", ncol = 2) +
  labs(title = "Multi-Panel Faceted Analysis",
       subtitle = "Independent y-axes per cohort",
       x = "Time Point", y = "Value",
       caption = "Simulated data | Panels share x-axis scale") +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    strip.background = element_rect(fill = "grey90", color = NA),
    strip.text = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank(),
    panel.spacing = unit(1, "lines")
  )',

    # ── Time Series + Moving Average ────────────────────────────
    time_series = 'library(ggplot2)

# Time series with trend decomposition
set.seed(202)
dates <- seq(as.Date("2022-01-01"), by = "day", length.out = 365)
trend <- seq(100, 150, length.out = 365)
seasonal <- 20 * sin(2 * pi * (1:365) / 365)

data <- data.frame(
  date = dates,
  value = trend + seasonal + rnorm(365, 0, 5)
)
data$ma_7  <- stats::filter(data$value, rep(1/7, 7), sides = 2)
data$ma_30 <- stats::filter(data$value, rep(1/30, 30), sides = 2)

ggplot(data, aes(x = date)) +
  geom_line(aes(y = value, color = "Daily"), alpha = 0.35, linewidth = 0.3) +
  geom_line(aes(y = ma_7, color = "7-day MA"), linewidth = 0.8, na.rm = TRUE) +
  geom_line(aes(y = ma_30, color = "30-day MA"), linewidth = 1.1, na.rm = TRUE) +
  scale_color_manual(values = c("Daily" = "grey60", "7-day MA" = "#2166AC",
                                "30-day MA" = "#B2182B"),
                     breaks = c("Daily", "7-day MA", "30-day MA")) +
  scale_x_date(date_labels = "%b", date_breaks = "2 months",
               expand = expansion(mult = 0.01)) +
  labs(title = "Time Series with Moving Averages",
       subtitle = "Trend extraction via rolling window smoothing",
       x = NULL, y = "Value", color = NULL,
       caption = "MA = Moving Average | Trend + seasonal + noise") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )',

    # ── Donut Chart ─────────────────────────────────────────────
    pie_donut = 'library(ggplot2)

# Publication donut chart with percentage labels
data <- data.frame(
  category = c("Technology", "Healthcare", "Finance", "Energy", "Consumer"),
  value = c(35, 25, 20, 12, 8)
)
data$pct <- data$value / sum(data$value) * 100
data$ymax <- cumsum(data$pct / 100)
data$ymin <- c(0, head(data$ymax, -1))
data$mid <- (data$ymax + data$ymin) / 2
data$label <- paste0(data$category, "\\n", data$value, "%")

ggplot(data, aes(ymax = ymax, ymin = ymin, xmax = 4, xmin = 2.5, fill = category)) +
  geom_rect(color = "white", linewidth = 1.2) +
  geom_text(aes(x = 3.25, y = mid, label = label),
            size = 3.3, lineheight = 0.9, fontface = "bold") +
  coord_polar(theta = "y") +
  xlim(c(1, 4.5)) +
  scale_fill_brewer(palette = "Set2") +
  labs(title = "Market Share Distribution", subtitle = "Sector allocation") +
  theme_void(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15, hjust = 0.5),
    plot.subtitle = element_text(color = "grey40", size = 11, hjust = 0.5),
    legend.position = "none"
  )',

    # ── Stacked Area ────────────────────────────────────────────
    area_stacked = 'library(ggplot2)

# Stacked area chart
set.seed(303)
data <- data.frame(
  month = factor(rep(month.abb, 4), levels = month.abb),
  platform = rep(c("Web", "Mobile", "Desktop", "API"), each = 12),
  users = c(cumsum(abs(rnorm(12, 10, 2))),
            cumsum(abs(rnorm(12, 8, 1.5))),
            cumsum(abs(rnorm(12, 5, 1))),
            cumsum(abs(rnorm(12, 3, 0.8))))
)

ggplot(data, aes(x = month, y = users, fill = platform, group = platform)) +
  geom_area(alpha = 0.85, color = "white", linewidth = 0.3) +
  scale_fill_brewer(palette = "Paired") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05)),
                     labels = function(x) paste0(round(x), "K")) +
  labs(title = "Cumulative Traffic by Platform",
       subtitle = "Monthly active users",
       x = NULL, y = "Users (thousands)", fill = NULL,
       caption = "Simulated data") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank()
  )',

    # ── Violin Plot ─────────────────────────────────────────────
    violin_plot = 'library(ggplot2)

# Grouped violin with summary statistics
set.seed(404)
data <- data.frame(
  treatment = rep(c("Placebo", "Low Dose", "High Dose"), each = 80),
  response = c(rnorm(80, 50, 12), rnorm(80, 58, 10), rnorm(80, 68, 11))
)
data$treatment <- factor(data$treatment,
                         levels = c("Placebo", "Low Dose", "High Dose"))

ggplot(data, aes(x = treatment, y = response, fill = treatment)) +
  geom_violin(alpha = 0.4, trim = FALSE, color = NA) +
  geom_boxplot(width = 0.12, fill = "white", outlier.shape = NA,
               linewidth = 0.4) +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 3.5,
               color = "red3") +
  scale_fill_brewer(palette = "Pastel1") +
  labs(title = "Dose-Response Distribution",
       subtitle = "Violin plots with embedded box plots (red diamond = mean)",
       x = NULL, y = "Response",
       caption = "N = 80 per group") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "none",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )',

    # ── Geographic Map ──────────────────────────────────────────
    geographic_map = 'library(ggplot2)

# US choropleth map
set.seed(707)
states_map <- ggplot2::map_data("state")
state_data <- data.frame(
  state = tolower(state.name),
  value = runif(length(state.name), 10, 100)
)
states_map <- merge(states_map, state_data, by.x = "region",
                    by.y = "state", all.x = TRUE)
states_map <- states_map[order(states_map$order), ]

ggplot(states_map, aes(long, lat, group = group, fill = value)) +
  geom_polygon(color = "white", linewidth = 0.2) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1,
                       na.value = "grey80", name = "Value") +
  coord_fixed(1.3) +
  labs(title = "Geographic Distribution by State",
       subtitle = "Simulated metric across US states",
       caption = "Data: Simulated | Projection: Albers equal-area") +
  theme_void(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15, hjust = 0.5),
    plot.subtitle = element_text(color = "grey40", size = 11, hjust = 0.5),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0.5),
    legend.position = "bottom",
    legend.key.width = unit(1.5, "cm"),
    legend.key.height = unit(0.3, "cm")
  )',

    # ── Network Graph ───────────────────────────────────────────
    network_graph = 'library(ggplot2)

# Network graph with edges and nodes
set.seed(808)
nodes <- data.frame(
  id = paste0("N", 1:20), x = rnorm(20), y = rnorm(20),
  degree = sample(2:8, 20, replace = TRUE)
)
edges <- data.frame(from = sample(nodes$id, 35, replace = TRUE),
                    to = sample(nodes$id, 35, replace = TRUE))
edges <- edges[edges$from != edges$to, ]
edges <- merge(edges, nodes[, c("id","x","y")], by.x = "from", by.y = "id")
edges <- merge(edges, nodes[, c("id","x","y")], by.x = "to", by.y = "id",
               suffixes = c("", "_end"))

ggplot() +
  geom_segment(data = edges,
               aes(x = x, y = y, xend = x_end, yend = y_end),
               color = "grey60", alpha = 0.5, linewidth = 0.3) +
  geom_point(data = nodes, aes(x = x, y = y, size = degree),
             color = "#2166AC", alpha = 0.85) +
  geom_text(data = nodes[nodes$degree > 5, ],
            aes(x = x, y = y, label = id),
            size = 2.8, vjust = -1.2, fontface = "bold") +
  scale_size_continuous(range = c(2, 9), name = "Degree") +
  labs(title = "Network Visualization",
       subtitle = "Node size proportional to degree centrality",
       caption = "Labels shown for high-degree nodes only") +
  theme_void(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15, hjust = 0.5),
    plot.subtitle = element_text(color = "grey40", size = 11, hjust = 0.5),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0.5),
    legend.position = "right"
  )',

    # ── Waterfall Chart ─────────────────────────────────────────
    waterfall_chart = 'library(ggplot2)

# Financial waterfall chart
data <- data.frame(
  item = c("Revenue", "COGS", "Gross Profit", "OpEx", "Marketing",
           "Tax", "Net Income"),
  value = c(100, -35, NA, -20, -12, -8, NA),
  type = c("total", "neg", "subtotal", "neg", "neg", "neg", "total")
)
data$end <- cumsum(ifelse(is.na(data$value),
                          0, data$value))
data$end[3] <- data$end[2]
data$end[7] <- data$end[6]
data$start <- c(0, head(data$end, -1))
data$start[c(3, 7)] <- 0
data$item <- factor(data$item, levels = data$item)

ggplot(data, aes(x = item)) +
  geom_rect(aes(xmin = as.numeric(item) - 0.4,
                xmax = as.numeric(item) + 0.4,
                ymin = pmin(start, end), ymax = pmax(start, end),
                fill = type)) +
  geom_segment(data = data[!data$type %in% "total", ],
               aes(x = as.numeric(item) + 0.4,
                   xend = as.numeric(item) + 0.6,
                   y = end, yend = end),
               linetype = "dotted", color = "grey50") +
  geom_text(aes(y = (start + end) / 2,
                label = ifelse(is.na(value), round(end), value)),
            fontface = "bold", size = 3.8) +
  scale_fill_manual(values = c("total" = "#2166AC", "neg" = "#B2182B",
                               "subtotal" = "#4393C3"),
                    guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.08))) +
  labs(title = "Income Statement Waterfall",
       subtitle = "Revenue to net income breakdown ($M)",
       x = NULL, y = "Amount ($M)",
       caption = "Subtotals shown in blue") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 30, hjust = 1, face = "bold")
  )',

    # ── Radar Chart ─────────────────────────────────────────────
    radar_chart = 'library(ggplot2)

# Radar/spider chart via coord_polar
categories <- c("Speed", "Power", "Accuracy", "Endurance", "Flexibility", "Agility")
data <- data.frame(
  category = factor(rep(categories, 2), levels = categories),
  value = c(85, 70, 90, 75, 60, 80,
            70, 90, 75, 85, 80, 65),
  player = rep(c("Player A", "Player B"), each = 6)
)

ggplot(data, aes(x = category, y = value, group = player,
                 color = player, fill = player)) +
  geom_polygon(alpha = 0.15, linewidth = 1.2) +
  geom_point(size = 3) +
  coord_polar(clip = "off") +
  scale_y_continuous(limits = c(0, 100), breaks = seq(25, 100, 25)) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Player Performance Comparison",
       subtitle = "Radar chart across six metrics",
       color = NULL, fill = NULL) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 15, hjust = 0.5),
    plot.subtitle = element_text(color = "grey40", size = 11, hjust = 0.5),
    legend.position = "bottom",
    axis.title = element_blank(),
    axis.text.y = element_text(size = 8, color = "grey50"),
    panel.grid.major = element_line(color = "grey85")
  )',

    # ── Publication Line + CI ───────────────────────────────────
    pub_line_ci = 'library(ggplot2)

# Longitudinal outcome with confidence ribbons
set.seed(121)
df <- data.frame(time = rep(1:8, 2),
                 group = rep(c("Treatment", "Control"), each = 8))
df$mean <- ifelse(df$group == "Treatment",
                  cumsum(rnorm(8, 0.6, 0.3)),
                  cumsum(rnorm(8, 0.3, 0.2)))
df$se <- runif(nrow(df), 0.15, 0.35)
df$lower <- df$mean - 1.96 * df$se
df$upper <- df$mean + 1.96 * df$se

ggplot(df, aes(x = time, y = mean, color = group, fill = group)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.15, color = NA) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  scale_x_continuous(breaks = 1:8) +
  labs(title = "Longitudinal Outcome",
       subtitle = "Mean \\u00B1 95% CI",
       x = "Visit", y = "Mean Response", color = NULL, fill = NULL,
       caption = "CI = 1.96 \\u00D7 SE") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "top",
    panel.grid.minor = element_blank()
  )',

    # ── Publication Bar + Error ─────────────────────────────────
    pub_bar_error = 'library(ggplot2)

# Bar chart with significance brackets
df <- data.frame(
  group = factor(c("Control", "Low", "Medium", "High"),
                 levels = c("Control", "Low", "Medium", "High")),
  mean = c(4.8, 5.5, 6.1, 7.2),
  se = c(0.4, 0.45, 0.5, 0.6)
)

ggplot(df, aes(x = group, y = mean, fill = group)) +
  geom_col(width = 0.65, color = "grey30", linewidth = 0.3) +
  geom_errorbar(aes(ymin = mean - se, ymax = mean + se),
                width = 0.15, linewidth = 0.4) +
  geom_text(aes(label = sprintf("%.1f", mean), y = mean + se + 0.3),
            size = 3.5, fontface = "bold") +
  scale_fill_brewer(palette = "Blues") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Dose-Response Relationship",
       subtitle = "Mean \\u00B1 SE by treatment group",
       x = "Dose Group", y = "Mean Response",
       caption = "N = 30 per group | * p < 0.05 vs Control") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "none",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    axis.line.x = element_line(color = "grey70", linewidth = 0.3)
  )',

    # ── Forest Plot ─────────────────────────────────────────────
    forest_plot = 'library(ggplot2)

# Forest plot for meta-analysis / regression effects
df <- data.frame(
  term = c("Age", "BMI", "Treatment", "Smoking", "Exercise", "Gender"),
  estimate = c(0.12, 0.35, -0.42, 0.28, -0.15, 0.08),
  lower = c(0.05, 0.10, -0.65, 0.05, -0.30, -0.10),
  upper = c(0.19, 0.60, -0.19, 0.51, 0.00, 0.26)
)
df$term <- factor(df$term, levels = rev(df$term))
df$sig <- ifelse(df$lower > 0 | df$upper < 0, "Significant", "NS")

ggplot(df, aes(x = estimate, y = term, color = sig)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_pointrange(aes(xmin = lower, xmax = upper),
                  size = 0.7, fatten = 3, linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.2f [%.2f, %.2f]", estimate, lower, upper)),
            hjust = -0.1, size = 3, color = "grey30") +
  scale_color_manual(values = c("Significant" = "#B2182B", "NS" = "grey50"),
                     guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.35))) +
  labs(title = "Forest Plot of Regression Coefficients",
       subtitle = "Point estimate with 95% CI",
       x = "Effect Size (95% CI)", y = NULL,
       caption = "Red = statistically significant (CI excludes 0)") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank()
  )',

    # ── Volcano Plot ────────────────────────────────────────────
    volcano_plot = 'library(ggplot2)

# Differential expression volcano plot
set.seed(222)
n <- 500
df <- data.frame(
  log2fc = rnorm(n, 0, 1.5),
  pval = 10^(-runif(n, 0, 6))
)
df$neglog10p <- -log10(df$pval)
df$status <- with(df, ifelse(pval < 0.05 & log2fc > 1, "Up",
                    ifelse(pval < 0.05 & log2fc < -1, "Down", "NS")))
n_up <- sum(df$status == "Up")
n_down <- sum(df$status == "Down")

ggplot(df, aes(x = log2fc, y = neglog10p, color = status)) +
  geom_point(alpha = 0.7, size = 1.8) +
  geom_vline(xintercept = c(-1, 1), linetype = "dashed", color = "grey50") +
  geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "grey50") +
  scale_color_manual(values = c("Up" = "#B2182B", "Down" = "#2166AC",
                                "NS" = "grey70"),
                     name = NULL) +
  annotate("text", x = 3.5, y = max(df$neglog10p) * 0.95,
           label = paste0("Up: ", n_up), color = "#B2182B", size = 3.5,
           fontface = "bold", hjust = 0) +
  annotate("text", x = -3.5, y = max(df$neglog10p) * 0.95,
           label = paste0("Down: ", n_down), color = "#2166AC", size = 3.5,
           fontface = "bold", hjust = 1) +
  labs(title = "Volcano Plot",
       subtitle = "Differential expression analysis",
       x = expression(log[2]~"Fold Change"),
       y = expression(-log[10]~"(p-value)"),
       caption = "Thresholds: |log2FC| > 1, p < 0.05") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )',

    # ── Kaplan-Meier Survival Curve ─────────────────────────────
    km_curve = 'library(ggplot2)

# Kaplan-Meier style survival curves
time_pts <- seq(0, 24, by = 1)
set.seed(314)
surv_trt <- cumprod(c(1, 1 - runif(24, 0.01, 0.04)))
surv_ctl <- cumprod(c(1, 1 - runif(24, 0.02, 0.06)))

df <- data.frame(
  time = rep(time_pts, 2),
  survival = c(surv_trt, surv_ctl),
  group = rep(c("Treatment", "Control"), each = length(time_pts))
)

ggplot(df, aes(x = time, y = survival, color = group)) +
  geom_step(linewidth = 1.1) +
  geom_hline(yintercept = 0.5, linetype = "dotted", color = "grey50") +
  annotate("text", x = 24.5, y = 0.5, label = "50%", size = 3,
           color = "grey50", hjust = 0) +
  scale_color_brewer(palette = "Set1") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(0, 1),
                     expand = expansion(mult = c(0.02, 0.05))) +
  scale_x_continuous(breaks = seq(0, 24, 6),
                     expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Kaplan-Meier Survival Curve",
       subtitle = "Treatment vs Control",
       x = "Time (months)", y = "Survival Probability",
       color = NULL,
       caption = "Simulated data | Dotted line = 50% survival") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    legend.position = "inside",
    legend.position.inside = c(0.85, 0.85),
    legend.background = element_rect(fill = "white", color = "grey80",
                                     linewidth = 0.3),
    panel.grid.minor = element_blank()
  )',

    # ── Dot + CI Plot ───────────────────────────────────────────
    dot_ci = 'library(ggplot2)

# Dot plot with confidence intervals for multiple endpoints
df <- data.frame(
  endpoint = factor(c("Primary", "Secondary 1", "Secondary 2",
                       "Exploratory 1", "Exploratory 2"),
                    levels = rev(c("Primary", "Secondary 1", "Secondary 2",
                                   "Exploratory 1", "Exploratory 2"))),
  estimate = c(1.45, 1.20, 0.85, 1.60, 0.95),
  lower = c(1.10, 0.90, 0.55, 1.10, 0.60),
  upper = c(1.90, 1.55, 1.25, 2.20, 1.40)
)
df$sig <- ifelse(df$lower > 1, "Significant", "NS")

ggplot(df, aes(y = endpoint, x = estimate, color = sig)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey50") +
  geom_pointrange(aes(xmin = lower, xmax = upper),
                  size = 0.8, fatten = 3, linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.2f", estimate)), vjust = -1.2,
            size = 3.5, color = "grey30") +
  scale_color_manual(values = c("Significant" = "#2166AC", "NS" = "grey50"),
                     guide = "none") +
  labs(title = "Treatment Effect by Endpoint",
       subtitle = "Hazard ratio with 95% CI",
       x = "Hazard Ratio (95% CI)", y = NULL,
       caption = "Dashed line = null effect (HR = 1)") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank()
  )',

    # ── Data Templates (non-chart) ──────────────────────────────
    data_summary = 'data(mtcars)
summary(mtcars)
cat("\\nColumn Means:\\n")
print(round(sapply(mtcars, mean), 2))',

    linear_model = 'library(ggplot2)
data(mtcars)
model <- lm(mpg ~ wt + hp + cyl, data = mtcars)
cat("Model Summary:\\n")
print(summary(model))

# Observed vs Predicted diagnostic plot
mtcars$predicted <- predict(model)
r2 <- round(summary(model)$r.squared, 3)

ggplot(mtcars, aes(x = predicted, y = mpg)) +
  geom_point(color = "#2166AC", size = 2.5, alpha = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              color = "#B2182B") +
  annotate("text", x = min(mtcars$predicted) + 1,
           y = max(mtcars$mpg) - 1,
           label = paste0("R\\u00B2 = ", r2),
           size = 4, fontface = "bold", hjust = 0) +
  labs(title = "Linear Model Diagnostics",
       subtitle = "Observed vs Predicted",
       x = "Predicted MPG", y = "Observed MPG",
       caption = "Dashed line = perfect prediction") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey40", size = 11),
    plot.caption = element_text(color = "grey50", size = 8, hjust = 0)
  )',

    data_manipulation = '# Data manipulation with base R
data(mtcars)

# Add derived variable
mtcars$efficiency <- round(mtcars$mpg / mtcars$wt, 2)

# Filter and aggregate
high_power <- mtcars[mtcars$hp > 100, ]
result <- aggregate(cbind(mpg, hp, efficiency) ~ cyl,
                    data = high_power, FUN = mean)
result <- result[order(-result$mpg), ]
colnames(result) <- c("Cylinders", "Avg MPG", "Avg HP", "Avg Efficiency")
result[, -1] <- round(result[, -1], 1)

cat("High-Horsepower Vehicles (HP > 100) by Cylinder Count:\\n\\n")
print(result, row.names = FALSE)',

    function_template = "#\\' Custom Analysis Function
#\\'
#\\' @param data A data frame to analyze
#\\' @param var_name Column name to analyze (character)
#\\' @param group_var Optional grouping variable
#\\' @return A summary data frame
#\\' @export
analyze_variable <- function(data, var_name, group_var = NULL) {
  if (!var_name %in% names(data)) {
    stop(paste0(\"Variable \\'\", var_name, \"\\' not found in data\"))
  }

  col <- data[[var_name]]

  if (is.null(group_var)) {
    data.frame(
      variable = var_name,
      n = sum(!is.na(col)),
      mean = round(mean(col, na.rm = TRUE), 3),
      sd = round(sd(col, na.rm = TRUE), 3),
      median = round(median(col, na.rm = TRUE), 3),
      min = round(min(col, na.rm = TRUE), 3),
      max = round(max(col, na.rm = TRUE), 3)
    )
  } else {
    do.call(rbind, lapply(split(col, data[[group_var]]), function(x) {
      data.frame(n = length(x), mean = round(mean(x, na.rm = TRUE), 3),
                 sd = round(sd(x, na.rm = TRUE), 3))
    }))
  }
}

# Example
cat(\"Overall:\\n\")
print(analyze_variable(mtcars, \"mpg\"))
cat(\"\\nBy cylinders:\\n\")
print(analyze_variable(mtcars, \"mpg\", \"cyl\"))"
  )

  apply_template_by_id <- function(tpl_id) {
    tryCatch({
      tpl_id <- if (is.null(tpl_id)) "" else as.character(tpl_id[[1]])
      if (!nzchar(tpl_id) || grepl("^--", tpl_id)) {
        showNotification("Select a template first.", type = "warning")
        return(invisible(FALSE))
      }
      tmpl <- chart_templates[[tpl_id]]
      if (is.null(tmpl)) {
        showNotification("Template not found.", type = "error")
        return(invisible(FALSE))
      }
      tmpl <- enhance_template(tmpl)

      # Warn if template uses missing packages
      pkgs <- unique(gsub("^\\s*library\\(([^)]+)\\).*$", "\\1", grep("^\\s*library\\(", unlist(strsplit(tmpl, "\n")), value = TRUE)))
      if (length(pkgs) > 0) {
        missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
        if (length(missing) > 0) {
          install_cmd <- sprintf("install.packages(c('%s'))", paste(missing, collapse = "', '"))
          showNotification(paste("Missing packages:", paste(missing, collapse = ", "), ".", install_cmd), type = "warning")
        }
      }

      # Check for optional dependencies that enhance charts
      optional_pkgs <- c("viridis", "patchwork", "scales", "corrplot", "curl")
      missing_optional <- optional_pkgs[!vapply(optional_pkgs, requireNamespace, logical(1), quietly = TRUE)]
      if (length(missing_optional) > 0) {
        showNotification(paste("Optional packages for enhanced charts:", paste(missing_optional, collapse = ", "),
                              ". Some chart features may be limited."), type = "info", duration = 8)
      }

      # Guard: block auto-plot observers from re-executing while we load+render
      template_loading(TRUE)
      on.exit(template_loading(FALSE), add = TRUE)

      shinyAce::updateAceEditor(session, "code_editor", value = tmpl)
      session$sendCustomMessage("setEditorValue", list(value = tmpl))
      session$sendCustomMessage("reflowLayout", list())
      add_audit("template_loaded", tpl_id)
      showNotification(translate("template_loaded"), type = "message")

      # Single execution: render plot and switch to plot tab
      if (grepl("ggplot|plot\\(|geom_|plotly", tmpl, ignore.case = TRUE)) {
        update_plot_only(sanitize_code(tmpl))
        switch_editor_tab("plot")
      } else {
        switch_editor_tab("editor")
      }
      invisible(TRUE)
    }, error = function(e) {
      showNotification(paste("Template apply failed:", conditionMessage(e)), type = "error", duration = 8)
      invisible(FALSE)
    })
  }

  # Track selected template (display active selection) + auto-apply
  observeEvent(input$chart_templates, {
    selected_template <- input$chart_templates
    if (!is.null(selected_template) && nzchar(selected_template) && !grepl("^--", selected_template)) {
      active_template(selected_template)
      apply_template_by_id(selected_template)
    }
  })

  # Apply template explicitly (reliable + allows re-apply of same template)
  observeEvent(input$apply_template, {
    tpl_id <- active_template()
    if (!nzchar(tpl_id)) tpl_id <- input$chart_templates %||% ""
    apply_template_by_id(tpl_id)
  })

  # Onboarding tour
  observeEvent(input$start_tour, {
    rintrojs::introjs(session, options = list(
      steps = list(
        list(element = "#cloud_toggle", intro = "Toggle between Cloud (OpenAI/Anthropic/Gemini) and Local (Ollama) AI models"),
        list(element = "#openai_model", intro = "Select a cloud AI model (OpenAI, Anthropic, or Gemini)"),
        list(element = "#chart_templates", intro = "Choose from 18+ advanced chart templates"),
        list(element = "#code_editor", intro = "Write or edit your R code here"),
        list(element = "#run_btn", intro = "Execute your code to see output and plots"),
        list(element = ".editor-tabs", intro = "Switch between Editor and Plot views"),
        list(element = "#user_input", intro = "Ask questions about your code or charts"),
        list(element = "#chart_help_btn", intro = "Get AI help for creating advanced visualizations")
      ),
      showBullets = TRUE,
      showProgress = TRUE
    ))
  })

  # Normalize Ollama base URL
  normalize_ollama_url <- function(url) {
    if (is.null(url)) return("")
    url <- trimws(url)
    if (!nzchar(url)) return("")
    if (!grepl("^https?://", url)) url <- paste0("http://", url)
    sub("/+$", "", url)
  }

  # Remove hidden/incompatible characters that can break parsing
  sanitize_code <- function(code) {
    if (is.null(code)) return("")
    code <- enc2utf8(code)
    code <- gsub("\uFEFF", "", code, fixed = TRUE)            # BOM
    code <- gsub("[\u200B-\u200D\u2060]", "", code, perl = TRUE) # zero-width
    iconv(code, from = "UTF-8", to = "UTF-8", sub = "")
  }

  format_code_text <- function(code) {
    if (!nzchar(code)) return(code)
    # Skip formatting for code with expression()/plotmath — styler can corrupt these
    if (grepl("expression\\s*\\(", code)) return(code)
    if (requireNamespace("styler", quietly = TRUE)) {
      tryCatch({
        styled <- styler::style_text(code)
        if (is.character(styled)) {
          return(paste(styled, collapse = "\n"))
        }
        code
      }, error = function(e) code)
    } else if (requireNamespace("formatR", quietly = TRUE)) {
      tryCatch({
        tidy <- formatR::tidy_source(text = code, output = FALSE)$text.tidy
        paste(tidy, collapse = "\n")
      }, error = function(e) code)
    } else {
      code
    }
  }

  # Auto-fix common AI mistakes in R code before execution
  fix_ai_code_issues <- function(code) {
    if (!nzchar(code)) return(code)
    # Fix LaTeX-style $ in expression() calls — replace with valid plotmath
    # e.g., expression(Value~($\times 10^3$)) -> expression(Value~(10^3))
    if (grepl("expression\\s*\\(.*\\$", code)) {
      # Remove $ signs inside expression() calls
      code <- gsub("(expression\\s*\\([^)]*?)\\$([^)]*?\\))", "\\1\\2", code, perl = TRUE)
      # Clean up leftover LaTeX commands
      code <- gsub("\\\\times", "%*%", code)
      code <- gsub("\\\\mu", "mu", code)
      code <- gsub("\\\\alpha", "alpha", code)
      code <- gsub("\\\\beta", "beta", code)
      code <- gsub("\\\\sigma", "sigma", code)
      code <- gsub("\\\\Delta", "Delta", code)
    }
    # Fix smart/curly quotes that AI sometimes produces
    code <- gsub("\u201C|\u201D", '"', code)  # smart double quotes
    code <- gsub("\u2018|\u2019", "'", code)  # smart single quotes
    code
  }

  format_code_blocks <- function(text) {
    if (!nzchar(text)) return(text)
    # Handle \r\n, \n, optional {r} lang tags, spaces after lang tag
    pattern <- "```(?:\\{?([a-zA-Z0-9]*)\\}?)?[ \t]*[\r\n]+([\\s\\S]*?)[\r\n]*```"
    matches <- gregexpr(pattern, text, perl = TRUE)
    blocks <- regmatches(text, matches)[[1]]
    if (length(blocks) == 0) return(text)
    for (block in blocks) {
      m <- regexec(pattern, block, perl = TRUE)
      res <- regmatches(block, m)
      if (length(res) > 0 && length(res[[1]]) >= 3) {
        lang <- res[[1]][2]
        code <- res[[1]][3]
      } else {
        next
      }
      formatted <- format_code_text(code)
      new_block <- paste0("```", lang, "\n", formatted, "\n```")
      text <- sub(block, new_block, text, fixed = TRUE)
    }
    text
  }

  escape_html <- function(text) {
    text <- gsub("&", "&amp;", text, fixed = TRUE)
    text <- gsub("<", "&lt;", text, fixed = TRUE)
    text <- gsub(">", "&gt;", text, fixed = TRUE)
    text
  }

  format_chat_html <- function(text) {
    if (!nzchar(text)) return("")
    text <- escape_html(text)
    pattern <- "```(?:\\{?[a-zA-Z0-9]*\\}?)?[ \t]*[\r\n]+[\\s\\S]*?[\r\n]*```"
    m <- gregexpr(pattern, text, perl = TRUE)[[1]]
    if (m[1] == -1) {
      return(gsub("\n", "<br>", text))
    }
    out <- ""
    last <- 1
    code_extract <- "```(?:\\{?[a-zA-Z0-9]*\\}?)?[ \t]*[\r\n]+([\\s\\S]*?)[\r\n]*```"
    for (i in seq_along(m)) {
      start <- m[i]
      len <- attr(m, "match.length")[i]
      if (start > last) {
        out <- paste0(out, gsub("\n", "<br>", substr(text, last, start - 1)))
      }
      block <- substr(text, start, start + len - 1)
      code <- sub(code_extract, "\\1", block, perl = TRUE)
      out <- paste0(out, "<pre class=\"chat-code\"><code>", code, "</code></pre>")
      last <- start + len
    }
    if (last <= nchar(text)) {
      out <- paste0(out, gsub("\n", "<br>", substr(text, last, nchar(text))))
    }
    out
  }

  extract_first_code_block <- function(text) {
    if (!nzchar(text)) return("")
    pattern <- "```(?:\\{?[a-zA-Z0-9]*\\}?)?[ \t]*[\r\n]+([\\s\\S]*?)[\r\n]*```"

    # Extract ALL code blocks
    all_matches <- gregexpr(pattern, text, perl = TRUE)
    all_blocks <- regmatches(text, all_matches)[[1]]

    if (length(all_blocks) > 0) {
      codes <- vapply(all_blocks, function(block) {
        m <- regexec(pattern, block, perl = TRUE)
        res <- regmatches(block, m)
        if (length(res) > 0 && length(res[[1]]) >= 2) trimws(res[[1]][2]) else ""
      }, character(1), USE.NAMES = FALSE)

      # Find all R-looking blocks
      r_pattern <- "<-|library\\(|ggplot|geom_|aes\\(|plot\\(|data\\.frame|%>%|\\|>"
      r_blocks <- which(nzchar(codes) & grepl(r_pattern, codes))

      if (length(r_blocks) > 0) {
        # Pick the LONGEST R block — this is the complete code, not explanation snippets
        r_codes <- codes[r_blocks]
        r_lengths <- nchar(r_codes)
        longest_idx <- which.max(r_lengths)
        best_code <- r_codes[longest_idx]

        # If the longest block has a plot call but NO data definition,
        # and another block defines data, concatenate all R blocks
        has_plot_call <- grepl("ggplot\\(|plot\\(|plot_ly\\(|geom_", best_code)
        has_data_def <- grepl("<-|data\\.frame|tibble|read\\.|matrix\\(|c\\(", best_code)
        if (has_plot_call && !has_data_def && length(r_blocks) > 1) {
          return(paste(r_codes, collapse = "\n\n"))
        }
        return(best_code)
      }
      # Fallback to longest non-empty block
      non_empty <- which(nzchar(codes))
      if (length(non_empty) > 0) {
        ne_codes <- codes[non_empty]
        return(ne_codes[which.max(nchar(ne_codes))])
      }
    }

    # Fallback: if text looks like pure code without fenced blocks
    if (!grepl("```", text) && grepl("[{}]|<-|library\\(|ggplot", text)) {
      return(trimws(text))
    }
    ""
  }

  # System prompt shared by all providers
  ai_system_prompt <- paste0(
    "You are an expert R programming and data visualization assistant. Help with R coding, ",
    "debugging, explanations, and especially creating advanced charts with ggplot2, plotly, and other packages.\n",
    "Provide clear, helpful responses with complete R code examples. For chart questions, include ",
    "full working code with proper theming and aesthetics. Always wrap code in ```r code blocks."
  )

  # Build multi-turn conversation messages from chat history
  build_conversation_messages <- function(code_context, n_turns = 10) {
    msgs <- isolate(messages())
    # Collect up to n_turns of user+assistant pairs (skip the latest empty assistant placeholder)
    history <- list()
    if (n_turns > 0 && length(msgs) > 2) {
      # Skip last 2 entries (current user + empty assistant placeholder)
      past <- msgs[seq_len(max(1, length(msgs) - 2))]
      # Take the last n_turns * 2 messages (user+assistant pairs)
      start_idx <- max(1, length(past) - (n_turns * 2) + 1)
      past <- past[start_idx:length(past)]
      for (m in past) {
        if (m$role %in% c("user", "assistant") && nzchar(m$content)) {
          history[[length(history) + 1]] <- list(role = m$role, content = m$content)
        }
      }
    }
    # Add code context as a system-level note if available
    if (nzchar(code_context)) {
      context_msg <- paste0("Current R code in the editor:\n```r\n", code_context, "\n```")
      history[[length(history) + 1]] <- list(role = "user", content = context_msg)
      history[[length(history) + 1]] <- list(role = "assistant", content = "I can see your code. How can I help?")
    }
    history
  }

  # Cloud API calls for OpenAI, Anthropic, and Gemini

  call_openai_api <- function(user_message, code_context, model, api_key, max_tokens = 3000, conversation = NULL, base_url = NULL) {
    url <- base_url %||% "https://api.openai.com/v1/chat/completions"
    api_messages <- list(list(role = "system", content = ai_system_prompt))
    if (!is.null(conversation) && length(conversation) > 0) {
      api_messages <- c(api_messages, conversation)
    }
    api_messages <- c(api_messages, list(list(role = "user", content = user_message)))
    body <- list(
      model = model,
      messages = api_messages,
      temperature = 0.2,
      max_tokens = max_tokens
    )
    resp <- httr::POST(
      url,
      httr::add_headers("Content-Type" = "application/json", "Authorization" = paste("Bearer", api_key)),
      body = jsonlite::toJSON(body, auto_unbox = TRUE),
      encode = "json",
      httr::timeout(180)
    )
    if (httr::status_code(resp) == 200) {
      api_calls(api_calls() + 1)
      r <- jsonlite::fromJSON(httr::content(resp, "text"))
      text_content <- sapply(r$choices, function(ch) ch$message$content %||% "")
      paste(text_content, collapse = "\n")
    } else {
      paste0(translate("api_error"), " ", httr::status_code(resp))
    }
  }

  call_anthropic_api <- function(user_message, code_context, model, api_key, max_tokens = 3000, conversation = NULL) {
    api_messages <- list()
    if (!is.null(conversation) && length(conversation) > 0) {
      api_messages <- conversation
    }
    api_messages <- c(api_messages, list(list(role = "user", content = user_message)))
    body <- list(
      model = model,
      max_tokens = max_tokens,
      system = ai_system_prompt,
      messages = api_messages
    )
    resp <- httr::POST(
      "https://api.anthropic.com/v1/messages",
      httr::add_headers(
        "Content-Type" = "application/json",
        "x-api-key" = api_key,
        "anthropic-version" = "2023-06-01"
      ),
      body = jsonlite::toJSON(body, auto_unbox = TRUE),
      encode = "json",
      httr::timeout(180)
    )
    if (httr::status_code(resp) == 200) {
      api_calls(api_calls() + 1)
      r <- jsonlite::fromJSON(httr::content(resp, "text"))
      parts <- r$content
      if (is.null(parts)) return("")
      text_content <- sapply(parts, function(p) p$text %||% "")
      paste(text_content, collapse = "\n")
    } else {
      paste0(translate("api_error"), " ", httr::status_code(resp))
    }
  }

  call_gemini_api <- function(user_message, code_context, model, api_key, max_tokens = 3000, conversation = NULL) {
    # Build conversation for Gemini (uses contents array with role: user/model)
    contents <- list()
    # Add system instruction as first user message
    contents[[1]] <- list(role = "user", parts = list(list(text = ai_system_prompt)))
    contents[[2]] <- list(role = "model", parts = list(list(text = "I'm ready to help with R programming and data visualization.")))
    if (!is.null(conversation) && length(conversation) > 0) {
      for (m in conversation) {
        gemini_role <- if (m$role == "assistant") "model" else "user"
        contents[[length(contents) + 1]] <- list(role = gemini_role, parts = list(list(text = m$content)))
      }
    }
    contents[[length(contents) + 1]] <- list(role = "user", parts = list(list(text = user_message)))
    url <- paste0(
      "https://generativelanguage.googleapis.com/v1beta/models/",
      model,
      ":generateContent"
    )
    body <- list(contents = contents)
    resp <- httr::POST(
      url,
      httr::add_headers("Content-Type" = "application/json", "x-goog-api-key" = api_key),
      body = jsonlite::toJSON(body, auto_unbox = TRUE),
      encode = "json",
      httr::timeout(180)
    )
    if (httr::status_code(resp) == 200) {
      api_calls(api_calls() + 1)
      r <- jsonlite::fromJSON(httr::content(resp, "text"))
      cand <- r$candidates
      if (is.null(cand) || length(cand) < 1) return("")
      parts <- cand[[1]]$content$parts
      if (is.null(parts) || length(parts) < 1) return("")
      parts[[1]]$text %||% ""
    } else {
      paste0(translate("api_error"), " ", httr::status_code(resp))
    }
  }

  # Ollama API call — uses /api/chat (proper chat endpoint with roles)
  call_ollama_api <- function(user_message, code_context, model, base_url, max_tokens = 3000, conversation = NULL) {
    base_url <- normalize_ollama_url(base_url)
    if (!nzchar(base_url)) {
      return(paste0(translate("ollama_error"), " Missing Ollama URL."))
    }

    api_messages <- list(list(role = "system", content = ai_system_prompt))
    if (!is.null(conversation) && length(conversation) > 0) {
      api_messages <- c(api_messages, conversation)
    }
    api_messages <- c(api_messages, list(list(role = "user", content = user_message)))

    body <- list(
      model = model,
      messages = api_messages,
      stream = FALSE,
      options = list(
        temperature = 0.3,
        num_predict = max_tokens,
        num_ctx = 4096
      )
    )

    tryCatch({
      resp <- httr::POST(
        paste0(base_url, "/api/chat"),
        httr::add_headers("Content-Type" = "application/json"),
        body = jsonlite::toJSON(body, auto_unbox = TRUE),
        encode = "json",
        httr::timeout(180)
      )

      if (!inherits(resp, "response")) {
        stop("Ollama: no response received.")
      }

      status <- httr::status_code(resp)
      if (status == 200) {
        api_calls(api_calls() + 1)
        r <- jsonlite::fromJSON(httr::content(resp, "text", encoding = "UTF-8"))
        content <- r$message$content %||% ""
        if (!nzchar(content)) {
          return("Ollama returned an empty response. The model may be loading — try again.")
        }
        content
      } else if (status == 404) {
        paste0("Model '", model, "' not found. Pull it first: ollama pull ", model)
      } else {
        raw <- tryCatch(httr::content(resp, "text", encoding = "UTF-8"), error = function(e) "")
        paste0(translate("api_error"), " HTTP ", status, ": ", substr(raw, 1, 200))
      }
    }, error = function(e) {
      msg_text <- error_message(e)
      if (grepl("Timeout|timed out", msg_text, ignore.case = TRUE)) {
        "Ollama request timed out. The model may still be loading. Try a smaller model or wait and retry."
      } else if (grepl("Connection refused|Could not resolve", msg_text, ignore.case = TRUE)) {
        "Cannot connect to Ollama. Make sure it is running (ollama serve)."
      } else {
        paste0(translate("ollama_error"), " ", msg_text)
      }
    })
  }

  # Cached API calls — only for cloud providers (Ollama is local & fast, caching adds staleness)
  # Note: Caching disabled for multi-turn conversation support
  # (conversation context changes per call, making cache keys unreliable)

  can_stream <- function() {
    isTRUE(input$stream_responses) && requireNamespace("curl", quietly = TRUE)
  }

  stream_sse_post <- function(url, headers, body_json, on_data_line) {
    # Minimal SSE reader for "data: {...}" frames.
    if (!requireNamespace("curl", quietly = TRUE)) {
      stop("curl package not available for streaming")
    }
    h <- curl::new_handle()
    curl::handle_setheaders(h, .list = headers)
    curl::handle_setopt(h, post = TRUE, postfields = body_json,
                        connecttimeout = 30, low_speed_limit = 1, low_speed_time = 120)
    buf <- ""
    tryCatch({
      curl::curl_fetch_stream(
        url,
        function(x) {
          chunk <- rawToChar(x)
          buf <<- paste0(buf, chunk)
          if (nchar(buf) > 500000) buf <<- substr(buf, nchar(buf) - 10000, nchar(buf))
          repeat {
            nl <- regexpr("\n", buf, fixed = TRUE)[1]
            if (nl == -1) break
            line <- substr(buf, 1, nl - 1)
            buf <<- substr(buf, nl + 1, nchar(buf))
            line <- sub("\r$", "", line)
            if (nzchar(line)) on_data_line(line)
          }
          nchar(chunk)
        },
        handle = h
      )
    }, error = function(e) {
      warning("Streaming error: ", e$message)
    })
  }

  stream_openai_chat <- function(prompt, model, api_key, on_delta, max_tokens = 3000, conversation = NULL, base_url = NULL) {
    url <- base_url %||% "https://api.openai.com/v1/chat/completions"
    api_messages <- list(list(role = "system", content = ai_system_prompt))
    if (!is.null(conversation) && length(conversation) > 0) {
      api_messages <- c(api_messages, conversation)
    }
    api_messages <- c(api_messages, list(list(role = "user", content = prompt)))
    body <- list(
      model = model,
      messages = api_messages,
      temperature = 0.2,
      max_tokens = max_tokens,
      stream = TRUE
    )
    acc <- ""
    stream_sse_post(
      url,
      headers = list("Content-Type" = "application/json", "Authorization" = paste("Bearer", api_key)),
      body_json = jsonlite::toJSON(body, auto_unbox = TRUE),
      on_data_line = function(line) {
        if (!startsWith(line, "data:")) return()
        payload <- trimws(sub("^data:\\s*", "", line))
        if (!nzchar(payload) || payload == "[DONE]") return()
        obj <- tryCatch(jsonlite::fromJSON(payload), error = function(e) NULL)
        if (is.null(obj)) return()
        delta <- ""
        if (!is.null(obj$choices) && length(obj$choices) >= 1) {
          delta <- obj$choices[[1]]$delta$content %||% ""
        }
        if (nzchar(delta)) {
          acc <<- paste0(acc, delta)
          on_delta(delta, acc)
        }
      }
    )
    acc
  }

  stream_anthropic_messages <- function(prompt, model, api_key, on_delta, max_tokens = 3000, conversation = NULL) {
    url <- "https://api.anthropic.com/v1/messages"
    api_messages <- list()
    if (!is.null(conversation) && length(conversation) > 0) {
      api_messages <- conversation
    }
    api_messages <- c(api_messages, list(list(role = "user", content = prompt)))
    body <- list(
      model = model,
      max_tokens = max_tokens,
      stream = TRUE,
      system = ai_system_prompt,
      messages = api_messages
    )
    acc <- ""
    stream_sse_post(
      url,
      headers = list(
        "Content-Type" = "application/json",
        "x-api-key" = api_key,
        "anthropic-version" = "2023-06-01"
      ),
      body_json = jsonlite::toJSON(body, auto_unbox = TRUE),
      on_data_line = function(line) {
        if (!startsWith(line, "data:")) return()
        payload <- trimws(sub("^data:\\s*", "", line))
        if (!nzchar(payload)) return()
        obj <- tryCatch(jsonlite::fromJSON(payload), error = function(e) NULL)
        if (is.null(obj)) return()
        delta <- ""
        if (!is.null(obj$delta) && !is.null(obj$delta$text)) {
          delta <- obj$delta$text %||% ""
        }
        if (nzchar(delta)) {
          acc <<- paste0(acc, delta)
          on_delta(delta, acc)
        }
      }
    )
    acc
  }

  # Ollama streaming via /api/chat — produces JSON lines (NOT SSE)
  stream_ollama_chat <- function(prompt, model, base_url, on_delta, code_context = "", max_tokens = 3000, conversation = NULL) {
    base_url <- normalize_ollama_url(base_url)
    if (!nzchar(base_url)) stop("Missing Ollama URL")

    api_messages <- list(list(role = "system", content = ai_system_prompt))
    if (!is.null(conversation) && length(conversation) > 0) {
      api_messages <- c(api_messages, conversation)
    }
    api_messages <- c(api_messages, list(list(role = "user", content = prompt)))

    url <- paste0(base_url, "/api/chat")
    body <- list(
      model = model,
      messages = api_messages,
      stream = TRUE,
      options = list(
        temperature = 0.3,
        num_predict = max_tokens,
        num_ctx = 4096
      )
    )
    body_json <- jsonlite::toJSON(body, auto_unbox = TRUE)

    acc <- ""

    if (!requireNamespace("curl", quietly = TRUE)) {
      # Fallback: non-streaming call
      result <- call_ollama_api(prompt, code_context, model, base_url)
      on_delta(result, result)
      return(result)
    }

    h <- curl::new_handle()
    curl::handle_setheaders(h, "Content-Type" = "application/json")
    curl::handle_setopt(h, post = TRUE, postfields = body_json,
                        connecttimeout = 30, low_speed_limit = 1, low_speed_time = 180)
    buf <- ""

    tryCatch({
      curl::curl_fetch_stream(
        url,
        function(x) {
          chunk <- rawToChar(x)
          buf <<- paste0(buf, chunk)
          if (nchar(buf) > 500000) buf <<- substr(buf, nchar(buf) - 10000, nchar(buf))
          # Ollama sends newline-delimited JSON (NOT SSE)
          repeat {
            nl <- regexpr("\n", buf, fixed = TRUE)[1]
            if (nl == -1) break
            line <- substr(buf, 1, nl - 1)
            buf <<- substr(buf, nl + 1, nchar(buf))
            line <- sub("\r$", "", line)
            if (!nzchar(line)) next
            obj <- tryCatch(jsonlite::fromJSON(line), error = function(e) NULL)
            if (is.null(obj)) next
            # /api/chat returns message.content per chunk
            delta <- obj$message$content %||% ""
            if (nzchar(delta)) {
              acc <<- paste0(acc, delta)
              on_delta(delta, acc)
            }
          }
          nchar(chunk)
        },
        handle = h
      )
    }, error = function(e) {
      msg_text <- error_message(e)
      if (!nzchar(acc)) {
        if (grepl("Timeout|timed out|low speed", msg_text, ignore.case = TRUE)) {
          acc <<- paste0("Streaming timed out after 3 minutes. Possible causes:\n",
                         "- Model is still loading (first run takes longer)\n",
                         "- Model is too large for available RAM\n",
                         "- Ollama server is overloaded\n\n",
                         "Try: 1) Wait and retry, 2) Use a smaller model, 3) Check 'ollama ps' for status")
        } else if (grepl("Connection refused|Could not resolve", msg_text, ignore.case = TRUE)) {
          acc <<- "Cannot connect to Ollama. Make sure it is running: ollama serve"
        } else {
          acc <<- paste0("Streaming error: ", msg_text)
        }
        on_delta(acc, acc)
      }
    })
    acc
  }

  # Send message handler
  send_message <- function(user_message, mode = "chat") {
    if (!nzchar(user_message)) return()

    # Store the last user message for re-ask functionality
    last_user_message(user_message)

    stop_requested(FALSE)
    code_context <- input$code_editor
    session$sendCustomMessage("updateStatus", list(connected = TRUE, message = "Calling AI..."))
    showNotification(translate("api_calling"), type = "default", duration = 3)
    add_audit("chat_send", mode)
    started <- Sys.time()

    system_prompt <- prompt_templates[[mode]]
    if (!is.null(system_prompt)) {
      user_message <- paste(system_prompt, user_message, sep = "\n\n")
    }

    # Snapshot current editor code for diff view
    pre_ai_code(code_context)

    # Add user + placeholder assistant message immediately (enables streaming updates).
    m <- messages()
    m[[length(m) + 1]] <- list(role = "user", content = user_message)
    m[[length(m) + 1]] <- list(role = "assistant", content = "")
    assistant_idx <- length(m)
    messages(m)
    session$sendCustomMessage("scrollChat", list())

    update_assistant <- function(full_text) {
      mm <- messages()
      if (length(mm) >= assistant_idx) {
        mm[[assistant_idx]]$content <- full_text
        messages(mm)
      }
    }

    # Throttle UI updates (avoid re-rendering the chat on every token).
    last_flush <- proc.time()[["elapsed"]]
    maybe_flush <- function() {
      # Check stop flag - interrupt streaming by signaling an error
      if (isTRUE(isolate(stop_requested()))) {
        stop("__STOPPED_BY_USER__", call. = FALSE)
      }
      now <- proc.time()[["elapsed"]]
      if ((now - last_flush) >= 0.05) {
        last_flush <<- now
        session$sendCustomMessage("scrollChat", list())
        # Incremental code extraction for faster visual feedback
        try({
          mm <- messages()
          full_text <- mm[[assistant_idx]]$content
          if (nzchar(full_text)) {
            code <- extract_first_code_block(full_text)
            if (nzchar(code)) {
              shinyAce::updateAceEditor(session, "ai_code_view", value = code)
              session$sendCustomMessage("setAiCodeValue", list(value = code))
            }
          }
        }, silent = TRUE)
        try(session$flushReact(), silent = TRUE)
      }
    }

    ai_resp <- if (model_type() == "cloud") {
      provider <- input$cloud_provider %||% "openai"
      last_api_provider(provider)
      api_key <- get_cloud_api_key(provider)
      if (!nzchar(api_key)) {
        showNotification(paste("API key missing for", provider), type = "error")
        session$sendCustomMessage("updateStatus", list(connected = FALSE, message = "API key missing"))
        update_assistant("API key missing. Please check Settings.")
        return()
      }

      cloud_model <- switch(
        provider,
        openai = input$openai_model,
        anthropic = input$anthropic_model,
        gemini = input$gemini_model,
        deepseek = input$deepseek_model,
        groq = input$groq_model,
        openrouter = input$openrouter_model,
        input$openai_model
      )

      # Build multi-turn conversation context
      n_turns <- input$context_turns %||% 10
      conversation <- build_conversation_messages(code_context, n_turns)
      on_delta_cb <- function(delta, acc) { update_assistant(acc); maybe_flush() }

      # OpenAI-compatible providers share the same streaming/non-streaming functions
      # with different base URLs
      openai_compat_base_url <- switch(
        provider,
        deepseek = "https://api.deepseek.com/v1/chat/completions",
        groq = "https://api.groq.com/openai/v1/chat/completions",
        openrouter = "https://openrouter.ai/api/v1/chat/completions",
        NULL
      )

      if (can_stream()) {
        tryCatch({
          if (identical(provider, "openai") || !is.null(openai_compat_base_url)) {
            stream_openai_chat(user_message, cloud_model, api_key, on_delta_cb,
                               max_tokens = input$max_tokens_setting, conversation = conversation,
                               base_url = openai_compat_base_url)
          } else if (identical(provider, "anthropic")) {
            stream_anthropic_messages(user_message, cloud_model, api_key, on_delta_cb, max_tokens = input$max_tokens_setting, conversation = conversation)
          } else {
            # Gemini fallback to non-streaming call
            call_gemini_api(user_message, code_context, cloud_model, api_key, input$max_tokens_setting, conversation = conversation)
          }
        }, error = function(e) {
          msg_text <- error_message(e)
          if (grepl("__STOPPED_BY_USER__", msg_text, fixed = TRUE)) return(NULL)
          paste(translate("api_error"), msg_text)
        })
      } else {
        tryCatch(
          if (!is.null(openai_compat_base_url)) {
            call_openai_api(user_message, code_context, cloud_model, api_key, input$max_tokens_setting,
                           conversation = conversation, base_url = openai_compat_base_url)
          } else {
            switch(provider,
              openai = call_openai_api(user_message, code_context, cloud_model, api_key, input$max_tokens_setting, conversation = conversation),
              anthropic = call_anthropic_api(user_message, code_context, cloud_model, api_key, input$max_tokens_setting, conversation = conversation),
              gemini = call_gemini_api(user_message, code_context, cloud_model, api_key, input$max_tokens_setting, conversation = conversation),
              call_openai_api(user_message, code_context, cloud_model, api_key, input$max_tokens_setting, conversation = conversation)
            )
          },
          error = function(e) paste(translate("api_error"), error_message(e))
        )
      }
    } else {
      last_api_provider("ollama")
      # Verify Ollama is reachable before making a long call
      if (!test_ollama_connection()) {
        update_assistant("Ollama is not reachable. Please check that it is running (ollama serve) and the URL is correct.")
        session$sendCustomMessage("updateStatus", list(connected = FALSE, message = "Ollama offline"))
        return()
      }
      n_turns <- input$context_turns %||% 10
      conversation <- build_conversation_messages(code_context, n_turns)
      if (can_stream()) {
        tryCatch(
          stream_ollama_chat(user_message, input$ollama_model, input$ollama_url, function(delta, acc) {
            update_assistant(acc); maybe_flush()
          }, code_context = code_context, max_tokens = input$max_tokens_setting, conversation = conversation),
          error = function(e) {
            msg_text <- error_message(e)
            if (grepl("__STOPPED_BY_USER__", msg_text, fixed = TRUE)) return(NULL)
            paste(translate("ollama_error"), msg_text)
          }
        )
      } else {
        tryCatch(
          call_ollama_api(user_message, code_context, input$ollama_model, input$ollama_url, input$max_tokens_setting, conversation = conversation),
          error = function(e) {
            msg_text <- error_message(e)
            if (grepl("__STOPPED_BY_USER__", msg_text, fixed = TRUE)) return(NULL)
            paste(translate("ollama_error"), msg_text)
          }
        )
      }
    }

    last_api_ms(as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000)
    
    # Handle user-initiated stop: keep partial response
    if (isTRUE(stop_requested())) {
      mm <- messages()
      if (length(mm) >= assistant_idx && nzchar(mm[[assistant_idx]]$content)) {
        ai_resp <- paste0(mm[[assistant_idx]]$content, "\n\n*[Generation stopped by user]*")
      } else {
        ai_resp <- "*[Generation stopped by user]*"
      }
      stop_requested(FALSE)
    }
    
    ai_resp <- format_code_blocks(as.character(ai_resp %||% ""))
    if (!nzchar(ai_resp)) {
      ai_resp <- "No response received from AI. Please check your API key and network connection."
    }
    
    # Final extraction and update
    ai_code <- extract_first_code_block(ai_resp)
    # AI code extraction complete
    
    if (nzchar(ai_code)) {
      # Don't run styler on AI code — it can corrupt code and adds latency
      # Update via shinyAce AND direct JS fallback for reliability
      shinyAce::updateAceEditor(session, "ai_code_view", value = ai_code)
      session$sendCustomMessage("setAiCodeValue", list(value = ai_code))
      last_ai_code(ai_code)
      # Auto-switch to Refined Code tab so user sees the extracted code
      session$sendCustomMessage("switchToRefinedCode", list())
    } else {
      shinyAce::updateAceEditor(session, "ai_code_view", value = "")
      session$sendCustomMessage("setAiCodeValue", list(value = ""))
      last_ai_code("")
    }

    if (mode == "optimize" && isTRUE(input$auto_format_opt)) {
      if (nzchar(ai_code)) {
        session$sendCustomMessage("setEditorValue", list(value = ai_code))
        switch_editor_tab("editor")
      }
    }

    # Replace placeholder assistant message with final formatted response.
    update_assistant(ai_resp)
    updateTextAreaInput(session, "user_input", value = "")
    session$sendCustomMessage("updateStatus", list(connected = TRUE, message = "Ready"))
    session$sendCustomMessage("reflowLayout", list())
  }

  # Stop button handler
  observeEvent(input$stop_btn, {
    if (isTRUE(stop_requested())) {
      # Already stopping
      return()
    }
    stop_requested(TRUE)
    showNotification("Stopping generation...", type = "warning", duration = 2)
    session$sendCustomMessage("updateStatus", list(connected = TRUE, message = "Stopped"))
  })

  # Re-ask button handler - resends the last user message
  observeEvent(input$reask_btn, {
    last_msg <- last_user_message()
    if (nzchar(last_msg)) {
      send_message(last_msg)
    } else {
      showNotification("No previous message to re-ask", type = "warning", duration = 2)
    }
  })

  # Paste sample prompt into query box
  observeEvent(input$sample_prompts, {
    prompt <- input$sample_prompts
    if (nzchar(prompt %||% "")) {
      updateTextAreaInput(session, "user_input", value = prompt)
      updateSelectInput(session, "sample_prompts", selected = "")
    }
  })

  # Event handlers
  observeEvent(input$send_btn, { send_message(input$user_input) })
  observeEvent(input$explain_btn, { send_message("Please explain this R code in detail, including what each part does.", "explain") })
  observeEvent(input$debug_btn, { send_message("Debug this R code. Identify any issues, errors, or potential problems.", "debug") })
  observeEvent(input$optimize_btn, { send_message("How can I optimize this R code for better performance and readability?", "optimize") })
  observeEvent(input$format_btn, {
    code <- format_code_text(sanitize_code(input$code_editor))
    session$sendCustomMessage("setEditorValue", list(value = code))
    session$sendCustomMessage("reflowLayout", list())
  })
  observeEvent(input$clear_chat, {
    messages(list(list(role = "assistant", content = if (lang() == "es") translations_es$welcome else translations_en$welcome)))
  })

  # Console collapse/expand via Shiny's button handler
  observeEvent(input$toggle_console_btn, {
    session$sendCustomMessage("toggleConsole", list())
  })

  # Session persistence - save/load chat sessions
  session_dir <- file.path(tools::R_user_dir("aiRAssistant", "data"), "sessions")

  observeEvent(input$save_session, {
    if (!dir.exists(session_dir)) dir.create(session_dir, recursive = TRUE)
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    # Build a short label from first user message
    msgs <- messages()
    label <- "session"
    for (m in msgs) {
      if (m$role == "user") {
        label <- substr(gsub("[^a-zA-Z0-9 ]", "", m$content), 1, 30)
        label <- gsub("\\s+", "_", trimws(label))
        break
      }
    }
    fname <- paste0(timestamp, "_", label, ".rds")
    session_data <- list(
      messages = msgs,
      code = input$code_editor,
      timestamp = Sys.time()
    )
    saveRDS(session_data, file.path(session_dir, fname))
    showNotification(paste("Session saved:", fname), type = "message", duration = 3)
  })

  observeEvent(input$load_session, {
    if (!dir.exists(session_dir)) {
      showNotification("No saved sessions found.", type = "warning", duration = 3)
      return()
    }
    files <- list.files(session_dir, pattern = "\\.rds$", full.names = FALSE)
    if (length(files) == 0) {
      showNotification("No saved sessions found.", type = "warning", duration = 3)
      return()
    }
    # Show modal with session list (most recent first)
    files <- rev(sort(files))
    showModal(modalDialog(
      title = "Load Chat Session",
      selectInput("session_file", "Select a session:", choices = files),
      actionButton("confirm_load_session", "Load", class = "quick-btn"),
      actionButton("delete_session", "Delete", class = "quick-btn", style = "color: #ff6b6b;"),
      footer = modalButton("Cancel"),
      easyClose = TRUE
    ))
  })

  observeEvent(input$confirm_load_session, {
    req(input$session_file)
    fpath <- file.path(session_dir, input$session_file)
    if (!file.exists(fpath)) {
      showNotification("Session file not found.", type = "error", duration = 3)
      return()
    }
    session_data <- tryCatch(readRDS(fpath), error = function(e) NULL)
    if (is.null(session_data)) {
      showNotification("Failed to load session.", type = "error", duration = 3)
      return()
    }
    messages(session_data$messages)
    if (!is.null(session_data$code) && nzchar(session_data$code)) {
      shinyAce::updateAceEditor(session, "code_editor", value = session_data$code)
    }
    removeModal()
    showNotification("Session loaded successfully.", type = "message", duration = 3)
  })

  observeEvent(input$delete_session, {
    req(input$session_file)
    fpath <- file.path(session_dir, input$session_file)
    if (file.exists(fpath)) file.remove(fpath)
    # Refresh the file list in the modal
    files <- rev(sort(list.files(session_dir, pattern = "\\.rds$", full.names = FALSE)))
    if (length(files) == 0) {
      removeModal()
      showNotification("All sessions deleted.", type = "message", duration = 3)
    } else {
      updateSelectInput(session, "session_file", choices = files)
      showNotification("Session deleted.", type = "message", duration = 3)
    }
  })

  insert_ai_code <- function() {
    # Use server-cached extracted code first
    code_block <- isolate(last_ai_code())
    
    if (!nzchar(code_block %||% "")) {
      msgs <- messages()
      last_assistant <- NULL
      for (i in rev(seq_along(msgs))) {
        if (msgs[[i]]$role == "assistant") {
          last_assistant <- msgs[[i]]$content
          break
        }
      }
      if (!is.null(last_assistant)) {
        code_block <- extract_first_code_block(last_assistant)
      }
    }
    
    code_block <- sanitize_code(code_block)
    code_block <- fix_ai_code_issues(code_block)

    if (nzchar(code_block %||% "")) {
      len <- nchar(code_block)
      showNotification(paste("Inserted", len, "characters into editor"), type = "message", duration = 3)

      # Use the same proven pattern as templates: shinyAce::updateAceEditor + JS sync
      shinyAce::updateAceEditor(session, "code_editor", value = code_block)
      session$sendCustomMessage("setEditorValue", list(value = as.character(code_block)))

      # Reset last_plot_code so auto-plot and Run don't skip this new code
      last_plot_code("")

      # Run the inserted code directly (we already have the code_block, no need to read from editor)
      run_code(code_block)
      session$sendCustomMessage("reflowLayout", list())
    } else {
      showNotification("No code block detected to insert.", type = "warning")
    }
  }
  observeEvent(input$insert_ai_code, { insert_ai_code() })
  observeEvent(input$insert_ai_code_tab, { insert_ai_code() })
  observeEvent(input$copy_ai_code, { session$sendCustomMessage("copyAiCode", list()) })
  observeEvent(input$copy_ai_code_tab, { session$sendCustomMessage("copyAiCode", list()) })
  observeEvent(input$`_copy_ok`, {
    showNotification("Code copied to clipboard", type = "message", duration = 2)
  })
  observeEvent(input$`_copy_fail`, {
    showNotification("No code available to copy", type = "warning", duration = 2)
  })
  # Run Code button in Refined Code tab — runs the AI code directly without inserting to editor
  observeEvent(input$run_ai_code_tab, {
    code_block <- isolate(last_ai_code())
    if (!nzchar(code_block %||% "")) {
      msgs <- messages()
      for (i in rev(seq_along(msgs))) {
        if (msgs[[i]]$role == "assistant") {
          code_block <- extract_first_code_block(msgs[[i]]$content)
          break
        }
      }
    }
    code_block <- sanitize_code(code_block)
    code_block <- fix_ai_code_issues(code_block)
    if (nzchar(code_block %||% "")) {
      run_code(code_block)
    } else {
      showNotification("No code to run. Ask the AI a coding question first.", type = "warning", duration = 3)
    }
  })
  observeEvent(input$document_btn, { send_message("Add comprehensive roxygen2 documentation to this R code.") })
  observeEvent(input$chart_help_btn, {
    send_message("Help me improve this visualization. Suggest ways to make it more professional, visually appealing, and informative. Include complete code for an enhanced version.")
  })
  observeEvent(input$paste_btn, {
    # Send Refined Code to a new file in RStudio
    code_block <- isolate(last_ai_code())
    if (!nzchar(code_block %||% "")) {
      msgs <- messages()
      for (i in rev(seq_along(msgs))) {
        if (msgs[[i]]$role == "assistant") {
          code_block <- extract_first_code_block(msgs[[i]]$content)
          break
        }
      }
    }
    code_block <- sanitize_code(code_block)
    if (!nzchar(code_block %||% "")) {
      showNotification("No refined code available to send.", type = "warning")
      return()
    }
    tryCatch({
      if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
        # Create a new untitled document in RStudio and insert the refined code
        rstudioapi::documentNew(text = code_block, type = "r")
        showNotification("Refined code sent to new RStudio file", type = "message", duration = 3)
      } else {
        showNotification("RStudio API not available. Copy the code manually.", type = "warning")
      }
    }, error = function(e) {
      showNotification(paste("Could not create new file:", e$message), type = "error", duration = 5)
    })
  })

  # Helper: detect whether code uses base R graphics (plot, barplot, hist, etc.)
  uses_base_graphics <- function(code) {
    grepl("\\bplot\\(|\\bbarplot\\(|\\bhist\\(|\\bboxplot\\(|\\bpie\\(|\\bpairs\\(|\\bimage\\(|\\bcontour\\(|\\bheatmap\\(|\\bcurve\\(|\\bpar\\(|\\bmatplot\\(", code)
  }

  # Helper: safe eval that inherits loaded packages via globalenv()
  safe_eval_code <- function(code) {
    parsed <- parse(text = code)
    env <- new.env(parent = globalenv())
    eval(parsed, envir = env)
  }

  # Run code - capture both output and plots with improved stability
  run_code <- function(code) {
    if (!nzchar(code)) return()

    # Auto-fix common AI-generated code issues before execution
    code <- fix_ai_code_issues(code)

    is_base_plot <- uses_base_graphics(code)
    is_ggplot    <- grepl("ggplot\\(|geom_|qplot\\(", code)
    is_plotly    <- grepl("plot_ly\\(|plotly::|ggplotly\\(", code, ignore.case = TRUE)
    has_plot     <- is_base_plot || is_ggplot || is_plotly

    # Pre-validate: try parsing first to give clear error feedback
    parsed_code <- tryCatch(parse(text = code), error = function(e) {
      showNotification(paste("Syntax error in code:", e$message), type = "error", duration = 8)
      output$code_output <- renderText(paste("Parse error:", e$message))
      NULL
    })
    if (is.null(parsed_code)) {
      switch_editor_tab("editor")
      return()
    }

    run_error <- FALSE
    text_out <- tryCatch({
      result <- NULL
      out <- capture.output({
        if (is_base_plot && !is_ggplot && !is_plotly) {
          # Base R graphics: open a null device, run code, capture with recordPlot()
          dev_id <- dev.cur()
          pdf(NULL)  # open invisible PDF device to capture base plots
          on.exit({ dev.off(); if (dev_id > 1) dev.set(dev_id) }, add = TRUE)
          eval(parsed_code, envir = new.env(parent = globalenv()))
          result <- recordPlot()
        } else {
          # ggplot / plotly: evaluate all expressions, capture plot objects
          eval_env <- new.env(parent = globalenv())
          exprs <- as.list(parsed_code)
          result <- NULL
          for (expr in exprs) {
            result <- eval(expr, envir = eval_env)
          }

          # If last expression didn't produce a plot, search env for plot objects
          if (!inherits(result, "ggplot") && !inherits(result, "plotly") && has_plot) {
            env_objs <- ls(eval_env)
            for (nm in rev(env_objs)) {
              obj <- get(nm, envir = eval_env)
              if (inherits(obj, "ggplot") || inherits(obj, "plotly")) {
                result <- obj
                break
              }
            }
          }
        }

        # If result is not a recognised plot, print it as console output
        if (!is.null(result) &&
            !inherits(result, "ggplot") &&
            !inherits(result, "plotly") &&
            !inherits(result, "recordedplot")) {
          print(result)
          result <- NULL
        }
      })

      # Update reactive plot state (ggplot errors caught in renderPlot)
      if (!is.null(result) &&
          (inherits(result, "ggplot") || inherits(result, "plotly") || inherits(result, "recordedplot"))) {
        current_plot(result)
        if (inherits(result, "plotly")) {
          current_plot_type("plotly")
        } else {
          current_plot_type("ggplot")  # covers ggplot AND recordedplot
        }
        last_plot_code(code)
      } else if (has_plot) {
        # Code was supposed to produce a plot but didn't — keep last known plot
        # (avoids clearing a valid chart after partial re-runs)
      } else {
        current_plot(NULL)
      }

      out
    }, error = function(e) {
      run_error <<- TRUE
      paste(translate("run_error"), e$message)
    })

    out_text <- paste(text_out, collapse = "\n")
    if (!nzchar(out_text)) {
      out_text <- "No console output."
    }
    output$code_output <- renderText(out_text)

    session$sendCustomMessage("plotType", current_plot_type())

    if (run_error) {
      showNotification(paste("Code error:", substr(out_text, 1, 200)), type = "error", duration = 6)
      switch_editor_tab("editor")
      # Auto-fix: send error to AI for correction (if enabled and not already fixing)
      if (isTRUE(input$auto_fix_errors) && !isTRUE(isolate(auto_fix_pending()))) {
        auto_fix_pending(TRUE)
        error_msg <- sub(paste0("^", translate("run_error"), "\\s*"), "", out_text)
        fix_prompt <- paste0(
          "The following R code produced an error. Please fix it and return the corrected complete code.\n\n",
          "Code:\n```r\n", code, "\n```\n\n",
          "Error: ", error_msg, "\n\n",
          "Return ONLY the corrected complete R code in a ```r code block."
        )
        showNotification("Auto-fix: sending error to AI...", type = "default", duration = 3)
        send_message(fix_prompt)
        # Delay reset so that if the auto-fixed code is auto-run and errors again,
        # we don't enter an infinite fix loop within the same reactive cycle
        shiny::onFlushed(function() {
          auto_fix_pending(FALSE)
        }, session = session)
      }
    } else if (has_plot && !is.null(current_plot())) {
      switch_editor_tab("plot")
      showNotification(translate("run_done"), type = "message", duration = 2)
    } else {
      switch_editor_tab("editor")
      showNotification(translate("run_done"), type = "message", duration = 2)
    }

    session$sendCustomMessage("reflowLayout", list())
  }

  update_plot_only <- function(code, quiet = FALSE) {
    if (!nzchar(code)) return()
    # Auto-fix common AI code issues before attempting plot
    code <- fix_ai_code_issues(code)
    tryCatch({
      parsed_code <- parse(text = code)
      is_base <- uses_base_graphics(code) &&
                 !grepl("ggplot\\(|geom_|qplot\\(", code)
      has_plot <- is_base || grepl("ggplot\\(|geom_|qplot\\(|plot_ly\\(|plotly::|ggplotly\\(", code, ignore.case = TRUE)

      result <- if (is_base) {
        dev_id <- dev.cur()
        pdf(NULL)
        on.exit({ dev.off(); if (dev_id > 1) dev.set(dev_id) }, add = TRUE)
        eval(parsed_code, envir = new.env(parent = globalenv()))
        recordPlot()
      } else {
        # Evaluate all expressions individually to capture plot objects
        eval_env <- new.env(parent = globalenv())
        exprs <- as.list(parsed_code)
        last_result <- NULL
        for (expr in exprs) {
          last_result <- eval(expr, envir = eval_env)
        }
        # If last expression isn't a plot, search environment for plot objects
        if (!inherits(last_result, "ggplot") && !inherits(last_result, "plotly") && has_plot) {
          for (nm in rev(ls(eval_env))) {
            obj <- get(nm, envir = eval_env)
            if (inherits(obj, "ggplot") || inherits(obj, "plotly")) {
              last_result <- obj
              break
            }
          }
        }
        last_result
      }

      if (!is.null(result) &&
          (inherits(result, "ggplot") || inherits(result, "plotly") || inherits(result, "recordedplot"))) {
        current_plot(result)
        if (inherits(result, "plotly")) {
          current_plot_type("plotly")
        } else {
          current_plot_type("ggplot")
        }
        session$sendCustomMessage("plotType", current_plot_type())
        last_plot_code(code)
      }
      # If result is not a plot, keep current_plot unchanged (don't clear)
    }, error = function(e) {
      if (!quiet) showNotification(paste("Plot error:", e$message), type = "warning", duration = 5)
      # On error, keep last valid plot rather than clearing
    })
  }

  observeEvent(input$run_btn, {
    raw_code <- input$code_editor
    if (is.null(raw_code) || !nzchar(trimws(raw_code %||% ""))) {
      showNotification("Editor is empty. Write some code first.", type = "warning", duration = 3)
      return()
    }
    code <- sanitize_code(raw_code)
    if (!identical(code, raw_code)) {
      shinyAce::updateAceEditor(session, "code_editor", value = code)
    }
    run_code(code)
  })

  observeEvent(input$run_selection, {
    code <- sanitize_code(input$run_selection)
    if (nzchar(code)) run_code(code)
  })

  auto_plot_code <- reactive({
    code <- input$code_editor
    if (is.null(code)) return("")
    sanitize_code(code)
  })
  auto_plot_debounced <- debounce(auto_plot_code, 1500)
  observeEvent(auto_plot_debounced(), {
    if (isTRUE(isolate(template_loading()))) return()   # template handler already rendered
    if (!isTRUE(isolate(input$auto_plot))) return()
    if (!identical(isolate(editor_tab_current()), "plot")) return()
    code_txt <- auto_plot_debounced()
    if (is.null(code_txt) || !nzchar(code_txt)) return()
    if (nchar(code_txt) > 6000) { showNotification("Code too long for auto-plot preview. Use Run to render.", type = "info", duration = 3, id = "autoplot_skip"); return() }
    if (identical(code_txt, isolate(last_plot_code()))) return()
    if (!grepl("ggplot|plot\\(|geom_|plotly|barplot|hist\\(|boxplot", code_txt, ignore.case = TRUE)) return()
    update_plot_only(code_txt, quiet = TRUE)
  })

  observeEvent(editor_tab_current(), {
    if (isTRUE(template_loading())) return()             # template handler already rendered
    if (!isTRUE(input$auto_plot)) return()
    if (!identical(editor_tab_current(), "plot")) return()
    code_txt <- sanitize_code(input$code_editor)
    if (is.null(code_txt) || !nzchar(code_txt)) return()
    if (nchar(code_txt) > 6000) { showNotification("Code too long for auto-plot preview. Use Run to render.", type = "info", duration = 3, id = "autoplot_skip"); return() }
    if (identical(code_txt, last_plot_code())) return()
    if (!grepl("ggplot|plot\\(|geom_|plotly|barplot|hist\\(|boxplot", code_txt, ignore.case = TRUE)) return()
    update_plot_only(code_txt, quiet = TRUE)
  })

  # ── Helper: replace a function call handling nested/balanced parens ──
  replace_scale_in_code <- function(code, fn_pattern, replacement) {
    search_from <- 1L
    repeat {
      piece <- substring(code, search_from)
      m <- regexpr(fn_pattern, piece, perl = TRUE)
      if (m < 0L) break
      abs_pos <- search_from + as.integer(m) - 1L
      fn_len  <- attr(m, "match.length")
      nc <- nchar(code)
      i <- abs_pos + fn_len
      while (i <= nc && substr(code, i, i) %in% c(" ", "\t")) i <- i + 1L
      if (i > nc || substr(code, i, i) != "(") { search_from <- i; next }
      depth <- 0L; j <- i
      while (j <= nc) {
        ch <- substr(code, j, j)
        if (ch == "(") depth <- depth + 1L
        else if (ch == ")") { depth <- depth - 1L; if (depth == 0L) break }
        j <- j + 1L
      }
      if (depth != 0L) break
      code <- paste0(substr(code, 1L, abs_pos - 1L), replacement, substring(code, j + 1L))
      search_from <- abs_pos + nchar(replacement)
    }
    code
  }

  # ── Theme Picker ─────────────────────────────────────────────────
  # Custom enterprise themes defined as inline theme objects
  enterprise_themes <- list(
    theme_economist = function() {
      ggplot2::theme_minimal(base_size = 13) +
        ggplot2::theme(
          plot.background = ggplot2::element_rect(fill = "#d5e4eb", color = NA),
          panel.background = ggplot2::element_rect(fill = "#d5e4eb", color = NA),
          panel.grid.major.y = ggplot2::element_line(color = "#b3c6d0"),
          panel.grid.major.x = ggplot2::element_blank(),
          panel.grid.minor = ggplot2::element_blank(),
          axis.line.x = ggplot2::element_line(color = "#2b6a8a"),
          axis.ticks.x = ggplot2::element_line(color = "#2b6a8a"),
          plot.title = ggplot2::element_text(face = "bold", size = 16, color = "#01364d"),
          plot.subtitle = ggplot2::element_text(size = 11, color = "#3b6f8a")
        )
    },
    theme_tufte = function() {
      ggplot2::theme_minimal(base_size = 13, base_family = "serif") +
        ggplot2::theme(
          panel.grid = ggplot2::element_blank(),
          axis.ticks = ggplot2::element_line(color = "#333333", linewidth = 0.3),
          axis.line = ggplot2::element_line(color = "#333333", linewidth = 0.3),
          plot.title = ggplot2::element_text(face = "italic", size = 15),
          plot.background = ggplot2::element_rect(fill = "#fffff8", color = NA),
          panel.background = ggplot2::element_rect(fill = "#fffff8", color = NA)
        )
    },
    theme_clean = function() {
      ggplot2::theme_minimal(base_size = 13) +
        ggplot2::theme(
          panel.grid.minor = ggplot2::element_blank(),
          panel.grid.major = ggplot2::element_line(color = "#eeeeee", linewidth = 0.4),
          panel.background = ggplot2::element_rect(fill = "#fafafa", color = "#dddddd", linewidth = 0.5),
          plot.title = ggplot2::element_text(face = "bold", size = 15, margin = ggplot2::margin(b = 8)),
          plot.subtitle = ggplot2::element_text(color = "#555555"),
          axis.title = ggplot2::element_text(face = "bold", size = 11),
          legend.position = "bottom"
        )
    }
  )

  apply_theme <- function(theme_id) {
    # Use whatever code produced the CURRENT plot (works for both editor and Refined Code Run)
    code <- last_plot_code()
    if (!nzchar(code %||% "")) code <- input$code_editor
    if (is.null(code) || !nzchar(code)) return()

    # Remove any leftover custom theme definition
    code <- sub("(?s)theme_pub\\s*<-\\s*function\\([^)]*\\)\\s*\\{.*?\\}\\s*\\n*", "", code, perl = TRUE)
    code <- sub("(?s)theme_enterprise\\s*<-\\s*function\\([^)]*\\)\\s*\\{.*?\\}\\s*\\n*", "", code, perl = TRUE)

    # Check if code has a theme call to replace
    theme_pat <- "(ggplot2::)?theme_(minimal|classic|bw|dark|light|void|grey|gray|linedraw|pub|economist|tufte|clean)\\([^)]*\\)"
    is_custom <- theme_id %in% names(enterprise_themes)

    if (grepl(theme_pat, code, perl = TRUE)) {
      if (is_custom) {
        # Replace existing theme call with custom theme function call
        code <- gsub(theme_pat, paste0(theme_id, "()"), code, perl = TRUE)
        # Prepend the custom theme function definition
        theme_def <- paste0(theme_id, " <- ", paste(deparse(enterprise_themes[[theme_id]]), collapse = "\n"))
        code <- paste0(theme_def, "\n\n", code)
      } else {
        code <- gsub(theme_pat, paste0(theme_id, "()"), code, perl = TRUE)
      }
    } else {
      # No theme found — try appending
      if (grepl("ggplot\\(|geom_", code)) {
        theme_call <- if (is_custom) {
          theme_def <- paste0(theme_id, " <- ", paste(deparse(enterprise_themes[[theme_id]]), collapse = "\n"))
          paste0(theme_def, "\n\n")
        } else ""
        code <- paste0(theme_call, code, " +\n  ", theme_id, "()")
      } else {
        showNotification("No ggplot2 code found to apply theme.", type = "warning")
        return()
      }
    }

    template_loading(TRUE)
    on.exit(template_loading(FALSE), add = TRUE)
    shinyAce::updateAceEditor(session, "code_editor", value = code)
    session$sendCustomMessage("setEditorValue", list(value = code))
    update_plot_only(sanitize_code(code))
    switch_editor_tab("plot")
  }

  observeEvent(input$theme_minimal,  { apply_theme("theme_minimal") },  ignoreInit = TRUE)
  observeEvent(input$theme_classic,  { apply_theme("theme_classic") },  ignoreInit = TRUE)
  observeEvent(input$theme_bw,       { apply_theme("theme_bw") },       ignoreInit = TRUE)
  observeEvent(input$theme_dark,     { apply_theme("theme_dark") },     ignoreInit = TRUE)
  observeEvent(input$theme_light,    { apply_theme("theme_light") },    ignoreInit = TRUE)
  observeEvent(input$theme_void,     { apply_theme("theme_void") },     ignoreInit = TRUE)
  observeEvent(input$theme_linedraw, { apply_theme("theme_linedraw") }, ignoreInit = TRUE)
  observeEvent(input$theme_grey,     { apply_theme("theme_grey") },     ignoreInit = TRUE)
  observeEvent(input$theme_economist,{ apply_theme("theme_economist") },ignoreInit = TRUE)
  observeEvent(input$theme_tufte,    { apply_theme("theme_tufte") },    ignoreInit = TRUE)
  observeEvent(input$theme_clean,    { apply_theme("theme_clean") },    ignoreInit = TRUE)

  # ── Color Palette Picker ─────────────────────────────────────────
  # Enterprise color palettes (manual hex colors)
  enterprise_palettes <- list(
    Corporate = c("#003f5c", "#2f4b7c", "#665191", "#a05195", "#d45087", "#f95d6a", "#ff7c43", "#ffa600"),
    Ocean     = c("#023e8a", "#0077b6", "#0096c7", "#00b4d8", "#48cae4", "#90e0ef", "#ade8f4", "#caf0f8"),
    Sunset    = c("#590d22", "#800f2f", "#a4133c", "#c9184a", "#ff4d6d", "#ff758f", "#ff8fa3", "#ffb3c1"),
    Forest    = c("#1b4332", "#2d6a4f", "#40916c", "#52b788", "#74c69d", "#95d5b2", "#b7e4c7", "#d8f3dc"),
    Slate     = c("#212529", "#343a40", "#495057", "#6c757d", "#adb5bd", "#ced4da", "#dee2e6", "#f8f9fa")
  )

  apply_palette <- function(pal) {
    # Use whatever code produced the CURRENT plot (works for both editor and Refined Code Run)
    code <- last_plot_code()
    if (!nzchar(code %||% "")) code <- input$code_editor
    if (is.null(code) || !nzchar(code)) return()

    viridis_opts <- c("viridis", "plasma", "inferno", "magma", "cividis")
    cont_kw <- c("viridis_c", "distiller", "continuous", "gradient",
                 "gradient2", "gradientn", "fermenter", "steps")

    # Detect continuous vs discrete PER scale type (not globally)
    detect_cont <- function(code_str, prefix_pat) {
      fn_match <- regmatches(code_str,
                             regexpr(paste0("scale_", prefix_pat, "_\\w+"),
                                     code_str, perl = TRUE))
      if (length(fn_match) == 0 || !nzchar(fn_match)) return(FALSE)
      any(vapply(cont_kw, grepl, logical(1), x = fn_match, fixed = TRUE))
    }

    # Build palette-replaced code for given cont/discrete flags
    is_enterprise <- pal %in% names(enterprise_palettes)

    build_palette_code <- function(src, f_cont, c_cont) {
      make_repl <- function(prefix, is_cont) {
        if (is_enterprise) {
          hex <- paste0('"', enterprise_palettes[[pal]], '"', collapse = ", ")
          if (is_cont) {
            sprintf('scale_%s_gradientn(colors = c(%s))', prefix, hex)
          } else {
            sprintf('scale_%s_manual(values = c(%s))', prefix, hex)
          }
        } else if (pal %in% viridis_opts) {
          suf <- if (is_cont) "c" else "d"
          sprintf('scale_%s_viridis_%s(option = "%s")', prefix, suf, pal)
        } else {
          fn <- if (is_cont) "distiller" else "brewer"
          sprintf('scale_%s_%s(palette = "%s")', prefix, fn, pal)
        }
      }
      nc <- src
      nc <- replace_scale_in_code(nc, "scale_(color|colour)_\\w+", make_repl("color", c_cont))
      nc <- replace_scale_in_code(nc, "scale_fill_\\w+", make_repl("fill", f_cont))
      nc
    }

    # Try building the ggplot to validate scale/data compatibility
    try_build <- function(code_str) {
      tryCatch({
        res <- eval(parse(text = code_str), envir = new.env(parent = globalenv()))
        if (inherits(res, "ggplot")) ggplot2::ggplot_build(res)
        NULL
      }, error = function(e) e$message)
    }

    fill_cont  <- detect_cont(code, "fill")
    color_cont <- detect_cont(code, "colou?r")
    new_code <- build_palette_code(code, fill_cont, color_cont)

    if (identical(new_code, code)) {
      showNotification("No color/fill scale found in code to update.", type = "warning")
      return()
    }

    # Validate: if scale/data mismatch, auto-flip cont/discrete and retry
    err <- try_build(new_code)
    if (!is.null(err)) {
      if (grepl("Discrete values supplied to continuous scale", err, fixed = TRUE)) {
        new_code <- build_palette_code(code, fill_cont = FALSE, color_cont = FALSE)
      } else if (grepl("Continuous values supplied to discrete scale", err, fixed = TRUE)) {
        new_code <- build_palette_code(code, fill_cont = TRUE, color_cont = TRUE)
      }
    }

    template_loading(TRUE)
    on.exit(template_loading(FALSE), add = TRUE)
    shinyAce::updateAceEditor(session, "code_editor", value = new_code)
    session$sendCustomMessage("setEditorValue", list(value = new_code))
    update_plot_only(sanitize_code(new_code))
    switch_editor_tab("plot")
  }

  observeEvent(input$pal_viridis,  { apply_palette("viridis") },  ignoreInit = TRUE)
  observeEvent(input$pal_plasma,   { apply_palette("plasma") },   ignoreInit = TRUE)
  observeEvent(input$pal_inferno,  { apply_palette("inferno") },  ignoreInit = TRUE)
  observeEvent(input$pal_magma,    { apply_palette("magma") },    ignoreInit = TRUE)
  observeEvent(input$pal_cividis,  { apply_palette("cividis") },  ignoreInit = TRUE)
  observeEvent(input$pal_Set1,     { apply_palette("Set1") },     ignoreInit = TRUE)
  observeEvent(input$pal_Set2,     { apply_palette("Set2") },     ignoreInit = TRUE)
  observeEvent(input$pal_Paired,   { apply_palette("Paired") },   ignoreInit = TRUE)
  observeEvent(input$pal_Dark2,    { apply_palette("Dark2") },    ignoreInit = TRUE)
  observeEvent(input$pal_Spectral,  { apply_palette("Spectral") },  ignoreInit = TRUE)
  observeEvent(input$pal_Corporate, { apply_palette("Corporate") }, ignoreInit = TRUE)
  observeEvent(input$pal_Ocean,     { apply_palette("Ocean") },     ignoreInit = TRUE)
  observeEvent(input$pal_Sunset,    { apply_palette("Sunset") },    ignoreInit = TRUE)
  observeEvent(input$pal_Forest,    { apply_palette("Forest") },    ignoreInit = TRUE)
  observeEvent(input$pal_Slate,     { apply_palette("Slate") },     ignoreInit = TRUE)

  output$save_plot <- downloadHandler(
    filename = function() {
      ts <- format(Sys.time(), "%Y%m%d_%H%M%S")
      result <- current_plot()
      # Determine format based on plot type
      if (inherits(result, "plotly")) {
        paste0("chart_", ts, ".html")
      } else {
        fmt <- input$export_format %||% "png"
        paste0("chart_", ts, ".", fmt)
      }
    },
    content = function(file) {
      result <- current_plot()
      fmt <- input$export_format %||% "png"

      if (inherits(result, "plotly") && requireNamespace("htmlwidgets", quietly = TRUE)) {
        htmlwidgets::saveWidget(result, file, selfcontained = TRUE)
      } else if (inherits(result, "ggplot")) {
        if (fmt == "pdf") {
          pdf_device <- if (capabilities("cairo")) cairo_pdf else grDevices::pdf
          ggplot2::ggsave(file, plot = result, device = pdf_device, width = 10, height = 7)
        } else {
          ggplot2::ggsave(file, plot = result, device = fmt,
                          width = 10, height = 7, dpi = if (fmt == "svg") 96 else 300)
        }
      } else if (inherits(result, "recordedplot")) {
        if (fmt == "pdf") {
          pdf(file, width = 10, height = 7)
        } else if (fmt == "svg") {
          svg(file, width = 10, height = 7)
        } else {
          png(file, width = 10 * 300, height = 7 * 300, res = 300)
        }
        replayPlot(result)
        dev.off()
      } else {
        stop("No valid plot to save. Run code first to generate a chart.")
      }
    }
  )

  # Toggle between static ggplot and interactive plotly
  observeEvent(input$toggle_plotly, {
    result <- current_plot()
    if (is.null(result)) {
      showNotification("No plot to toggle. Run code first.", type = "warning", duration = 3)
      return()
    }
    if (inherits(result, "ggplot") || inherits(result, "recordedplot")) {
      new_type <- if (current_plot_type() == "ggplot") "plotly" else "ggplot"
      current_plot_type(new_type)
      session$sendCustomMessage("plotType", new_type)
      showNotification(paste("Switched to", if (new_type == "plotly") "interactive" else "static", "mode"), type = "message", duration = 2)
    } else if (inherits(result, "plotly")) {
      showNotification("Already an interactive plotly chart", type = "default", duration = 2)
    }
  })

  observeEvent(input$popout_plot, {
    showModal(modalDialog(
      title = "Plot Viewer",
      div(id = "popout_plot_container", 
          style = "min-height: 400px; width: 100%; height: 100%; display: flex; flex-direction: column;",
        plotOutput("plot_display_popout", height = "100%", width = "100%"),
        if (requireNamespace("plotly", quietly = TRUE)) {
          plotly::plotlyOutput("plotly_display_popout", height = "100%", width = "100%")
        } else {
          div(id = "plotly_display_popout", style = "display:none;")
        }
      ),
      easyClose = TRUE,
      size = "l",
      class = "plot-popout",
      footer = tagList(
        tags$button(type = "button", class = "btn-fullscreen", onclick = "toggleFullscreenModal()", "Fullscreen"),
        modalButton("Close")
      )
    ))
    session$sendCustomMessage("plotType", current_plot_type())
  })

  output$plot_display_popout <- renderPlot({
    # Re-render when fullscreen toggles to get high-res image at new size
    input$popout_resize
    result <- current_plot()
    if (is.null(result)) {
      # Show empty plot with message when no valid plot
      plot.new()
      text(0.5, 0.5, "No plot available\nRun code to generate a chart", cex = 1.2, col = "#666666")
      return()
    }
    tryCatch({
      if (inherits(result, "ggplot")) {
        print(result)
      } else if (inherits(result, "recordedplot")) {
        replayPlot(result)
      } else {
        plot.new()
        text(0.5, 0.5, "Plot type not supported for display", cex = 1.2, col = "#ff6b6b")
      }
    }, error = function(e) {
      plot.new()
      text(0.5, 0.5, paste("Render error:\n", e$message), cex = 1, col = "#ff6b6b")
    })
  }, bg = "white", width = function() {
    # Dynamic width based on modal size
    session$clientData$output_plot_display_popout_width %||% 800
  }, height = function() {
    # Dynamic height based on modal size
    session$clientData$output_plot_display_popout_height %||% 600
  }, res = 96)

  if (requireNamespace("plotly", quietly = TRUE)) {
    output$plotly_display_popout <- plotly::renderPlotly({
      result <- current_plot()
      if (is.null(result)) {
        # Return empty plotly plot with message
        plotly::plot_ly() %>%
          plotly::add_annotations(
            text = "No interactive plot available<br>Run code to generate a plotly chart",
            showarrow = FALSE,
            font = list(size = 14, color = "#666666")
          ) %>%
          plotly::layout(
            xaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE),
            yaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE)
          )
      } else if (inherits(result, "plotly")) {
        result
      } else {
        # Not a plotly object
        NULL
      }
    })
  }

  # Render chat messages
  output$chat_display <- renderUI({
    msgs <- messages()
    tagList(lapply(msgs, function(m) {
      div(class = paste("message", ifelse(m$role == "user", "message-user", "message-assistant")),
          HTML(format_chat_html(m$content)))
    }))
  })

  # Diff view display
  output$code_diff_display <- renderUI({
    old_code <- pre_ai_code()
    new_code <- tryCatch({
      # Get current AI refined code from the ai_code_view editor
      ai_code <- input$ai_code_view
      if (is.null(ai_code) || !nzchar(trimws(ai_code))) ""
      else ai_code
    }, error = function(e) "")

    if (!nzchar(old_code) && !nzchar(new_code)) {
      return(div(class = "diff-empty", "No diff available yet. Send a message to the AI to see code changes."))
    }
    if (!nzchar(old_code)) {
      return(div(class = "diff-empty", "No previous code snapshot. The diff will appear after your next AI interaction."))
    }
    if (!nzchar(new_code)) {
      return(div(class = "diff-empty", "No refined code yet. The AI hasn't produced code changes."))
    }

    old_lines <- strsplit(old_code, "\n", fixed = TRUE)[[1]]
    new_lines <- strsplit(new_code, "\n", fixed = TRUE)[[1]]

    # Simple line-by-line diff using longest common subsequence
    # Build diff output
    diff_html <- character(0)
    diff_html <- c(diff_html, sprintf('<div class="diff-header">--- Original (%d lines) &nbsp;&nbsp; +++ Modified (%d lines)</div>', length(old_lines), length(new_lines)))

    # Use a simple LCS-based diff
    m <- length(old_lines)
    n <- length(new_lines)

    if (m + n > 500) {
      # For very large files, fall back to simple side-by-side
      max_len <- max(m, n)
      for (i in seq_len(max_len)) {
        ol <- if (i <= m) old_lines[i] else ""
        nl <- if (i <= n) new_lines[i] else ""
        if (identical(ol, nl)) {
          diff_html <- c(diff_html, sprintf('<div class="diff-line diff-ctx"> %s</div>', htmltools::htmlEscape(ol)))
        } else {
          if (nzchar(ol)) diff_html <- c(diff_html, sprintf('<div class="diff-line diff-del">-%s</div>', htmltools::htmlEscape(ol)))
          if (nzchar(nl)) diff_html <- c(diff_html, sprintf('<div class="diff-line diff-add">+%s</div>', htmltools::htmlEscape(nl)))
        }
      }
    } else {
      # LCS table
      dp <- matrix(0L, nrow = m + 1, ncol = n + 1)
      for (i in seq_len(m)) {
        for (j in seq_len(n)) {
          if (identical(old_lines[i], new_lines[j])) {
            dp[i + 1, j + 1] <- dp[i, j] + 1L
          } else {
            dp[i + 1, j + 1] <- max(dp[i, j + 1], dp[i + 1, j])
          }
        }
      }
      # Backtrack
      result <- list()
      i <- m; j <- n
      while (i > 0 || j > 0) {
        if (i > 0 && j > 0 && identical(old_lines[i], new_lines[j])) {
          result <- c(list(list(type = "ctx", text = old_lines[i])), result)
          i <- i - 1; j <- j - 1
        } else if (j > 0 && (i == 0 || dp[i + 1, j] >= dp[i, j + 1])) {
          result <- c(list(list(type = "add", text = new_lines[j])), result)
          j <- j - 1
        } else {
          result <- c(list(list(type = "del", text = old_lines[i])), result)
          i <- i - 1
        }
      }
      for (r in result) {
        prefix <- if (r$type == "add") "+" else if (r$type == "del") "-" else " "
        diff_html <- c(diff_html, sprintf('<div class="diff-line diff-%s">%s%s</div>', r$type, prefix, htmltools::htmlEscape(r$text)))
      }
    }

    HTML(paste(diff_html, collapse = "\n"))
  })

  # Status bar updates
  output$model_status <- renderUI({
    model_name <- if (model_type() == "cloud") {
      provider <- input$cloud_provider %||% "openai"
      switch(
        provider,
        openai = paste("OpenAI:", input$openai_model),
        anthropic = paste("Anthropic:", input$anthropic_model),
        gemini = paste("Gemini:", input$gemini_model),
        deepseek = paste("DeepSeek:", input$deepseek_model),
        groq = paste("Groq:", input$groq_model),
        openrouter = paste("OpenRouter:", input$openrouter_model),
        paste("Cloud:", provider)
      )
    } else {
      paste("Ollama:", input$ollama_model)
    }
    span(paste("Model:", model_name))
  })

  output$header_model_display <- renderUI({
    model_name <- if (model_type() == "cloud") {
      provider <- input$cloud_provider %||% "openai"
      switch(
        provider,
        openai = paste("OpenAI:", input$openai_model),
        anthropic = paste("Anthropic:", input$anthropic_model),
        gemini = paste("Gemini:", input$gemini_model),
        deepseek = paste("DeepSeek:", input$deepseek_model),
        groq = paste("Groq:", input$groq_model),
        openrouter = paste("OpenRouter:", input$openrouter_model),
        paste("Cloud:", provider)
      )
    } else {
      paste("Ollama:", input$ollama_model)
    }
    span(class = "status-pill", paste("Model:", model_name))
  })

  output$cache_status <- renderUI({
    span(paste("API Calls:", api_calls()))
  })

  output$latency_status <- renderUI({
    ms <- last_api_ms()
    prov <- last_api_provider()
    if (is.na(ms) || ms <= 0) {
      return(span(class = "status-pill muted", "Latency: --"))
    }
    label <- if (nzchar(prov)) paste0("Latency: ", round(ms), " ms (", prov, ")") else paste0("Latency: ", round(ms), " ms")
    span(class = "status-pill muted", label)
  })

  output$active_template_display <- renderUI({
    tpl <- active_template()
    if (!nzchar(tpl)) {
      return(span(class = "status-pill muted", "Template: None"))
    }
    span(class = "status-pill", paste("Template:", tpl))
  })

  show_diagnostics <- function() {
    showModal(modalDialog(
      title = "Diagnostics",
      tags$div(style = "font-family: 'JetBrains Mono', monospace; font-size: 12px;",
        tags$p(tags$b("Model type:"), model_type()),
        tags$p(tags$b("Provider:"), input$cloud_provider %||% "openai"),
        tags$p(tags$b("Last latency (ms):"), ifelse(is.na(last_api_ms()), "--", round(last_api_ms()))),
        tags$p(tags$b("API calls:"), api_calls()),
        tags$p(tags$b("Ollama status:"), (ollama_status()$message %||% "Unknown")),
        tags$hr(),
        tags$p(tags$b("Notes:"), "Keys are never displayed here. Use Settings to configure providers.")
      ),
      easyClose = TRUE,
      footer = modalButton("Close")
    ))
  }
  observeEvent(input$open_diagnostics, { show_diagnostics() })

  observeEvent(input$open_export, {
    showModal(modalDialog(
      title = "Export",
      tags$p("Download your current session artifacts."),
      downloadButton("download_code", "Download Code (.R)", class = "quick-btn"),
      tags$br(), tags$br(),
      downloadButton("download_chat", "Download Chat (.md)", class = "quick-btn"),
      tags$br(), tags$br(),
      downloadButton("download_audit", "Download Audit Log (.csv)", class = "quick-btn"),
      easyClose = TRUE,
      footer = modalButton("Close")
    ))
  })

  output$download_code <- downloadHandler(
    filename = function() paste0("ai_r_assistant_code_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".R"),
    content = function(file) writeLines(sanitize_code(input$code_editor), file, useBytes = TRUE)
  )

  output$download_chat <- downloadHandler(
    filename = function() paste0("ai_r_assistant_chat_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".md"),
    content = function(file) {
      msgs <- messages()
      lines <- character(0)
      for (m in msgs) {
        role <- toupper(m$role %||% "unknown")
        lines <- c(lines, paste0("## ", role), "", m$content %||% "", "")
      }
      writeLines(lines, file, useBytes = TRUE)
    }
  )

  output$download_audit <- downloadHandler(
    filename = function() paste0("ai_r_assistant_audit_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"),
    content = function(file) {
      x <- audit_log()
      if (length(x) == 0) {
        utils::write.csv(data.frame(ts = character(0), event = character(0), details = character(0)), file, row.names = FALSE)
        return()
      }
      df <- data.frame(
        ts = vapply(x, function(e) e$ts %||% "", character(1)),
        event = vapply(x, function(e) e$event %||% "", character(1)),
        details = vapply(x, function(e) e$details %||% "", character(1)),
        stringsAsFactors = FALSE
      )
      utils::write.csv(df, file, row.names = FALSE)
    }
  )

  # Session cleanup: disconnect JS observers, remove globalenv assignments
  session$onSessionEnded(function() {
    # Clean up uploaded_data from globalenv if we put it there
    if (exists("uploaded_data", envir = globalenv())) {
      rm("uploaded_data", envir = globalenv())
    }
    # JS observers are cleaned up via page unload (browser handles this)
  })
  session$sendCustomMessage("registerCleanup", list())
}

shinyApp(ui = ui, server = server)
