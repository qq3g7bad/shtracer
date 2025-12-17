# Git Hooks for shtracer

This directory contains optional Git hooks for local development.

## Available Hooks

### pre-commit

Runs code quality checks before each commit:
- **shellcheck**: Static analysis for shell scripts
- **shfmt**: Shell script formatting checks

## Installation

To enable the pre-commit hook:

```bash
ln -sf ../../.git-hooks/pre-commit .git/hooks/pre-commit
```

## Requirements

Install the required tools:

```bash
# Install shellcheck
sudo apt-get install shellcheck  # Debian/Ubuntu
brew install shellcheck          # macOS

# Install shfmt
go install mvdan.cc/sh/v3/cmd/shfmt@latest
# or download from https://github.com/mvdan/sh/releases
```

## Bypassing Hooks

If you need to commit without running the hooks (not recommended):

```bash
git commit --no-verify
```

## Note

These hooks are optional for local development. All checks are also enforced in CI, so even if you skip the local hooks, your code will be checked during pull requests.
