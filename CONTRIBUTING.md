# Contributing to ODA

Thank you for your interest in contributing to ODA! This document provides guidelines and instructions for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/oda.git`
3. Create a new branch: `git checkout -b feature/your-feature-name`

## Development Guidelines

### Code Style
- Use shellcheck for shell script linting
- Follow POSIX shell compatibility where possible
- Use meaningful variable and function names
- Add comments for complex operations

### Commit Messages
- Use clear and descriptive commit messages
- Start with a verb in present tense
- Keep the first line under 50 characters
- Add detailed description if needed

Example:
```
Add ZFS compression optimization

- Implements LZ4 compression
- Adds recordsize tuning
- Includes performance monitoring
```

### Testing
Before submitting a PR:
1. Test all scripts in a ZFS environment
2. Verify monitoring functionality
3. Check for potential data loss scenarios
4. Test with different storage configurations

### Documentation
- Update README.md for new features
- Document all script parameters
- Include usage examples
- Update performance recommendations

## Pull Request Process

1. Update the README.md with details of changes
2. Update the version numbers following [SemVer](http://semver.org/)
3. Create a Pull Request with a clear title and description
4. Link any related issues

## Code Review Process

1. At least one maintainer must review and approve
2. All automated checks must pass
3. Documentation must be complete
4. All discussions must be resolved

## Getting Help

- Open an issue for bug reports
- Use discussions for feature requests
- Tag maintainers for urgent issues

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
