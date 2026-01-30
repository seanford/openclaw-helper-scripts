# Contributing

Thank you for your interest in contributing to OpenClaw Helper Scripts!

## How to Contribute

### Reporting Issues

- Check existing issues first to avoid duplicates
- Include the script name, version, and OS/distro
- Provide the command you ran and the output
- Use `--dry-run` output when possible

### Suggesting Features

- Open an issue describing the feature
- Explain the use case and why it's useful
- If proposing a new script, describe what it would do

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test with `--dry-run` mode
5. Ensure `bash -n script.sh` passes (syntax check)
6. Commit with a clear message
7. Push and open a PR

## Code Style

### Shell Scripts

- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use consistent indentation (4 spaces)
- Quote variables: `"$variable"` not `$variable`
- Use `[[ ]]` for conditionals (bash-specific is fine)

### Color Coding

Follow the established color conventions:

```bash
RED='\033[0;31m'      # Errors, failures
GREEN='\033[0;32m'    # Success, confirmations
YELLOW='\033[1;33m'   # Warnings, caution
BLUE='\033[0;34m'     # Section headers, steps
MAGENTA='\033[0;35m'  # User prompts
CYAN='\033[0;36m'     # Highlights, values
```

### Prompts

Use the `prompt_input` and `confirm` helper functions:

```bash
# Yes/no confirmation
if confirm "Do something?" "y"; then
    # default yes
fi

# Text input
value=$(prompt_input "Enter value" "default")
```

### Dry-Run Support

All operations that modify the system should check `$DRY_RUN`:

```bash
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Would do something"
else
    # Actually do it
fi
```

### Documentation

- Update the relevant `README.md` when adding/changing features
- Add to `CHANGELOG.md` under `[Unreleased]`
- Include `--help` output in the script

## Directory Structure

```
openclaw-helper-scripts/
├── README.md           # Overview and quick links
├── CHANGELOG.md        # Version history
├── CONTRIBUTING.md     # This file
├── LICENSE             # MIT license
├── setup/              # Fresh installation scripts
│   ├── README.md
│   └── *.sh
└── migration/          # Migration scripts
    ├── README.md
    └── *.sh
```

## Questions?

- Open an issue for questions
- Join the [OpenClaw Discord](https://discord.com/invite/clawd)
