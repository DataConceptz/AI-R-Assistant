# Changelog

All notable changes to this project are documented in this file.

## [1.1.0] - 2026-02-27

### Added

- Multi-turn conversation context: AI remembers prior exchanges for follow-up questions
- Auto-fix on error: AI suggests fixes when code produces errors
- Code diff view tab showing before/after changes
- CSV/Excel data upload with interactive DT preview
- Interactive Plotly toggle for any ggplot
- Run Code button in Refined Code tab
- 5 new plot themes (Linedraw, Grey, Economist, Tufte, Clean)
- 5 enterprise color palettes (Corporate, Ocean, Sunset, Forest, Slate)
- API Keys section in Settings with persistent storage
- Chat session save/load

### Fixed

- Refined Code now shows the longest complete code block, not explanation snippets
- Plot generation speed improved (removed redundant ggplot_build validation)
- Editor sync before Run button click
- Copy button in Refined Code tab works on HTTP (non-HTTPS) contexts
- Themes and colors apply to plots from Refined Code Run, not just editor plots
- Removed stale R_AI_Assistant.R (replaced with thin wrapper)
- Moved unused packages (promises, digest, shinyBS) from Imports to Suggests
- DT wrapped in requireNamespace guard for graceful fallback

### Changed

- Chart export upgraded to 300 DPI with PDF support and timestamped filenames
- API key resolution: Settings panel keys checked first, then env vars, then keyring

## [1.0.0] - 2026-02-19

### Added

- Enhanced AI-powered R coding assistant UX
- Secure API key management through `keyring`
- RStudio add-in integration (`ai_r_assistant()`)
- Code templates, chat workflow, and onboarding/help improvements
- Expanded package metadata and dependency declarations

### Documentation

- Added complete repository documentation set:
  - `README.md`
  - `LICENSE`
  - `CONTRIBUTING.md`
  - `CODE_OF_CONDUCT.md`
  - `SECURITY.md`
  - `CHANGELOG.md`
