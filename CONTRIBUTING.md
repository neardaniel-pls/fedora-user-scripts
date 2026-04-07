# Contributing

1. Fork the repo at https://github.com/neardaniel-pls/fedora-user-scripts
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Push and open a pull request

## Script Guidelines

- Use `set -euo pipefail`
- Follow the existing style (header docs, color/icon functions, output helpers)
- Validate all user inputs
- Use absolute paths to prevent path traversal
- Test on Fedora

## Commit Messages

Use conventional commits: `feat`, `fix`, `docs`, `refactor`, `chore`
