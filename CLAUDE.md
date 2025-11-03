# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is **mise-rv-ruby**, a mise backend plugin that manages Ruby versions using the rv tool. It provides fast Ruby installation by downloading pre-built binaries instead of compiling from source.

## Key Concepts

### Backend Plugin Architecture
- **Backend name**: `rv-ruby`
- **Tool name**: `ruby` (the only tool this backend manages)
- **Usage**: `rv-ruby@3.3.9` (simple) or `rv-ruby:ruby@3.3.9` (explicit) or `ruby@3.3.9` with alias
- **Underlying tool**: [rv](https://github.com/spinel-coop/rv) - Fast Ruby version manager in Rust

### Compatibility with gem Backend

**Important**: The alias feature only works once the plugin is added to the mise registry. For local development with linked plugins, you must use the explicit syntax `rv-ruby:ruby@version`.

Once published to the registry, use aliasing:
```toml
[alias]
ruby = "rv-ruby"

[tools]
ruby = "3.3.9"           # Resolves to rv-ruby via alias (registry only)
"gem:bundler" = "latest"  # gem backend finds ruby via alias
```

For local development (linked plugin):
```toml
[tools]
"rv-ruby:ruby" = "3.3.9"  # Explicit syntax required for linked plugins
# gem:bundler won't work - install gems manually with mise exec
```

## Development Commands

### Local Testing Workflow
```bash
# Link plugin for development
mise plugin link --force rv-ruby .

# List available Ruby versions (must use explicit syntax for linked plugins)
mise ls-remote rv-ruby:ruby

# Install a specific Ruby version
mise install rv-ruby:ruby@3.3.9

# Execute Ruby
mise exec rv-ruby:ruby@3.3.9 -- ruby --version

# Install gems manually (gem backend doesn't work with linked plugins)
mise exec rv-ruby:ruby@3.3.9 -- gem install bundler

# Run full test suite
mise run test

# Lint Lua code and GitHub Actions
mise run lint

# Format Lua code
mise run format

# Run all CI checks (lint + test)
mise run ci
```

### Pre-commit Hooks
```bash
# Install pre-commit hooks (runs linting on commit)
hk install

# Run all linters manually
hk check

# Run linters and auto-fix issues
hk fix
```

## Code Architecture

### Plugin Entry Point: `metadata.lua`
Defines plugin metadata:
- Plugin name: `rv-ruby`
- Manages only the `ruby` tool
- Requires rv to be installed (handled via ubi backend dependency)

### Hook Functions: `hooks/*.lua`

#### `backend_list_versions.lua`
**Purpose**: Return list of available Ruby versions from rv

**Implementation**:
1. Executes `rv ruby list --format json`
2. Parses JSON response
3. Extracts unique version strings (strips "ruby-" prefix)
4. Returns deduplicated array of versions

**Key validation**: Accepts both `tool == "ruby"` and `tool == "rv-ruby"` for flexibility

#### `backend_install.lua`
**Purpose**: Install a specific Ruby version using rv

**Implementation**:
1. Validates inputs (tool name, version format, install path)
2. Creates installation directory
3. Executes `rv ruby install <version> --install-dir <path>`

**Security features**:
- Version format validation (prevents shell injection)
- Install path sanitization (blocks shell metacharacters)

**Directory structure**: rv installs to `<install_path>/ruby-<version>/`

#### `backend_exec_env.lua`
**Purpose**: Set up environment for running Ruby

**Environment variables set**:
- `PATH`: `<install_path>/ruby-<version>/bin`
- `GEM_HOME`: `<install_path>/ruby-<version>/lib/ruby/gems/<major>.<minor>.0`
- `GEM_PATH`: Same as GEM_HOME (for gem isolation)

**Gem version parsing**: Converts version like `3.3.9` to gem path `3.3.0`

## Available Lua Modules

Backend plugins have access to these built-in modules:
- `cmd` - Execute shell commands: `cmd.exec("command")`
- `json` - JSON parsing: `json.decode(str)`, `json.encode(table)`
- `file` - File operations: `file.join_path(a, b)`

## Runtime Information

Platform detection available via `RUNTIME` global:
- `RUNTIME.osType` - `"Darwin"`, `"Linux"`, `"Windows"`
- `RUNTIME.archType` - `"amd64"`, `"arm64"`, etc.

## Testing Strategy

### Test File: `mise-tasks/test`
Validates all functionality:
1. **Version listing** - Tests `BackendListVersions`
2. **Installation** - Tests `BackendInstall`
3. **Ruby execution** - Tests PATH setup in `BackendExecEnv`
4. **Gem environment** - Tests GEM_HOME/GEM_PATH setup
5. **Gem installation** - End-to-end validation

### CI Pipeline: `.github/workflows/ci.yml`
- Runs on Ubuntu and macOS
- Executes `mise run ci` (lint + test)

## Using with gem Backend

### Recommended Setup

In your project's `mise.toml`:
```toml
[alias]
ruby = "rv-ruby"

[tools]
ruby = "3.3.9"          # Resolves to rv-ruby:ruby via alias
"gem:bundler" = "latest" # gem backend finds ruby via alias
```

### How It Works

1. **gem backend declares dependency** on `"ruby"`
2. **Alias resolves** `ruby` → `rv-ruby:ruby`
3. **gem backend gets environment** from rv-ruby's Ruby installation
4. **gem install runs** with PATH pointing to rv-ruby's Ruby

### Alternative: Direct Installation

Without aliasing, install gems directly:
```bash
mise exec rv-ruby@3.3.9 -- gem install bundler
```

Or use tasks:
```toml
[tools]
rv-ruby = "3.3.9"

[tasks.gems]
run = """
gem install bundler
gem install rails
"""
```

## rv-Specific Behavior

### Fast Installation
rv downloads pre-built Ruby binaries instead of compiling from source:
- Installation typically completes in <1 second
- Supports Ruby 3.2.x, 3.3.x, and 3.4.x+
- Platform support: macOS 14+, Ubuntu 24.04+

### Directory Structure
rv installs Ruby into a `ruby-<version>` subdirectory:
```
~/.local/share/mise/installs/rv-ruby/ruby/3.3.9/
└── ruby-3.3.9/
    ├── bin/
    │   ├── ruby
    │   ├── gem
    │   └── bundle
    └── lib/
        └── ruby/
            └── gems/
                └── 3.3.0/
```

This differs from the template assumption and is handled correctly in `BackendExecEnv`.

## Error Handling Patterns

### Input Validation
```lua
-- Version format (semantic versioning only)
if not version:match("^%d+%.%d+%.%d+$") and not version:match("^%d+%.%d+%.%d+%-[%w%.%-]+$") then
    error("Invalid version format: " .. version)
end

-- Path sanitization
if install_path:match("[;&|`$()]") then
    error("Install path contains invalid characters")
end
```

### Tool Name Validation
```lua
-- Accept both "ruby" and "rv-ruby" as the tool name
-- This allows both rv-ruby@version and rv-ruby:ruby@version
if tool ~= "ruby" and tool ~= "rv-ruby" then
    error("mise-rv-ruby backend only supports ruby. Use: rv-ruby@version or rv-ruby:ruby@version")
end
```

## Publishing Checklist

Before publishing:
- [ ] All tests pass: `mise run ci`
- [ ] Version listing works: `mise ls-remote rv-ruby:ruby`
- [ ] Installation works: `mise install rv-ruby:ruby@3.3.9`
- [ ] Ruby execution works: `mise exec rv-ruby:ruby@3.3.9 -- ruby --version`
- [ ] Gem environment is correct: `mise exec rv-ruby:ruby@3.3.9 -- gem env`
- [ ] Manual gem installation works: `mise exec rv-ruby:ruby@3.3.9 -- gem install bundler`
- [ ] After registry: Simple syntax works: `mise install rv-ruby@3.3.9`
- [ ] After registry: gem backend integration works with alias
- [ ] Documentation is complete
- [ ] GitHub repository exists and is public

## Real-World Examples

### Basic Usage (Registry Plugin)
```bash
# Install rv-ruby plugin from registry
mise plugin install rv-ruby https://github.com/deevus/mise-rv-ruby

# Install Ruby (simple syntax works after registry installation)
mise install rv-ruby@3.3.9

# Use Ruby
mise exec rv-ruby@3.3.9 -- ruby --version

# Or with explicit syntax (also works)
mise install rv-ruby:ruby@3.3.9
```

### With Alias (Recommended)
```toml
# mise.toml
[alias]
ruby = "rv-ruby"

[tools]
ruby = "3.3.9"
"gem:bundler" = "latest"
```

```bash
mise install  # Installs both Ruby and bundler
bundle install  # Uses rv-ruby's Ruby and gem
```

## Reference

- [rv GitHub Repository](https://github.com/spinel-coop/rv)
- [mise Backend Plugin Development](https://mise.jdx.dev/backend-plugin-development.html)
- [mise Alias Documentation](https://mise.jdx.dev/configuration.html#alias)
