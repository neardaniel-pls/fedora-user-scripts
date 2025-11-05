# Contributing to Fedora User Scripts

Quick guide for contributing to this Fedora-focused script collection.

## Getting Started

1. Fork the repository at https://github.com/neardaniel-pls/fedora-user-scripts
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/fedora-user-scripts.git
   cd fedora-user-scripts
   ```
3. Create a new branch for your contribution:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Types of Contributions

- **Bug Reports**: Include reproduction steps and system information
- **Feature Requests**: Clearly describe the proposed feature and use case
- **Script Contributions**: Follow existing style, include documentation, add error handling
- **Documentation Improvements**: Fix typos, improve clarity, add examples

## Script Guidelines

- Follow the existing script template format
- Use `set -euo pipefail` for error handling
- Include comprehensive header documentation
- Validate all user inputs
- Use absolute paths to prevent path traversal
- Test thoroughly on Fedora systems

## Submission Process

1. Ensure your code follows the style guidelines
2. Update relevant documentation
3. Commit your changes with clear messages:
   ```
   type(scope): brief description
   
   Detailed explanation if needed
   ```
4. Push to your fork and create a pull request

## Commit Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

## Community Guidelines

- Be respectful
- Focus on constructive feedback
- Help others when you can

Thank you for contributing to the Fedora User Scripts Collection!