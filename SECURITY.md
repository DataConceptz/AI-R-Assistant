# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.1.x   | Yes       |
| 1.0.x   | Yes       |

## Reporting a Vulnerability

If you discover a security issue, please **do not open a public GitHub issue**.

Report privately to:

- **Email:** Open an issue on GitHub
- **Subject:** `[AI-R-Assistant Security] <short summary>`

Please include:

1. Description of the vulnerability
2. Steps to reproduce
3. Potential impact
4. Suggested mitigation (if known)

## Response Process

- Initial acknowledgement target: **within 3 business days**
- Triage and severity assessment: **as soon as possible**
- Fix timeline depends on severity and complexity

When a fix is released, we will document it in `CHANGELOG.md`.

## Security Best Practices for Contributors

- Never commit API keys or secrets.
- Use `keyring` or the in-app Settings panel for credential storage.
- Keep dependencies up to date.
- Validate and sanitize external inputs where applicable.
