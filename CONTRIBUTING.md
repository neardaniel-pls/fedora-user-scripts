# Contributing to User Scripts Collection

Thank you for your interest in contributing to this Fedora-focused script collection! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites
- Fedora Linux system (scripts are optimized for Fedora)
- Basic knowledge of Bash scripting
- Git for version control
- Understanding of security best practices

### Setting Up Your Development Environment

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

We welcome the following types of contributions:

### 1. Bug Reports
- Use the provided bug report template
- Include detailed reproduction steps
- Provide system information (Fedora version, etc.)
- Include relevant logs or error messages

### 2. Feature Requests
- Use the feature request template
- Clearly describe the proposed feature
- Explain the use case and benefits
- Consider implementation complexity

### 3. Script Contributions
- New scripts should follow the existing style and structure
- Include comprehensive documentation
- Add appropriate error handling
- Test thoroughly on Fedora systems

### 4. Documentation Improvements
- Fix typos or grammatical errors
- Improve clarity of existing documentation
- Add examples or use cases
- Translate documentation (if applicable)

## Script Development Guidelines

### Code Style
- Follow the existing script template format
- Use `set -euo pipefail` for error handling
- Include comprehensive header documentation
- Use consistent naming conventions
- Add inline comments for complex logic

### Security Requirements
- Validate all user inputs
- Use absolute paths to prevent path traversal
- Handle temporary files securely
- Avoid eval and similar potentially dangerous constructs
- Follow principle of least privilege

### Documentation Requirements
Each script must include:
- Clear description of purpose
- Usage examples
- Dependency list
- Security considerations
- Troubleshooting section

### Testing
- Test scripts on multiple Fedora versions if possible
- Verify error handling works correctly
- Test with various input scenarios
- Ensure documentation matches actual behavior

## Submission Process

### Pull Request Guidelines
1. Ensure your code follows the style guidelines
2. Update relevant documentation
3. Add tests if applicable
4. Commit your changes with clear messages
5. Push to your fork and create a pull request

### Commit Message Format
Use clear, descriptive commit messages:
```
type(scope): brief description

Detailed explanation if needed
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Review Process
- All contributions require review
- Maintainers may request changes
- Be responsive to feedback
- Update your PR as needed

## Community Guidelines

### Code of Conduct
- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Avoid personal attacks or criticism

### Communication
- Use GitHub issues for bug reports and feature requests
- Join discussions in existing threads
- Be patient with response times
- Help others when you can

## Release Process

### Versioning
This project follows semantic versioning:
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)

### Changelog
All significant changes must be documented in CHANGELOG.md with:
- Version number
- Release date
- Change type (Added, Fixed, Changed, etc.)
- Brief description of changes

## Getting Help

If you need help with contributing:
- Check existing issues and discussions
- Read the documentation thoroughly
- Ask questions in relevant issues
- Contact maintainers if needed

## Recognition

Contributors are recognized in:
- README.md contributors section
- Release notes for significant contributions
- Git commit history

Thank you for contributing to the Fedora User Scripts Collection!