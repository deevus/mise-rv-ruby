# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **mise backend plugin template** for building vfox-style backend plugins. Backend plugins extend mise to manage multiple tools using the `backend:tool` format (e.g., `npm:prettier`, `cargo:ripgrep`), unlike standard plugins that manage a single tool.

## Key Concepts

### Backend Plugin Architecture
- **Backend plugins** manage families of tools from an ecosystem (package managers, tool families)
- Tools are referenced as `<BACKEND>:<tool>@<version>` (e.g., `npm:prettier@3.0.0`)
- Three required hooks implement the plugin lifecycle:
  - `BackendListVersions` - Lists available versions for a tool
  - `BackendInstall` - Installs a specific version of a tool
  - `BackendExecEnv` - Sets up environment variables for the tool

### Placeholders to Replace
When implementing a new backend, replace these placeholders throughout the codebase:
- `<BACKEND>` → Your backend name (e.g., `npm`, `cargo`, `pip`)
- `<GITHUB_USER>` → Your GitHub username or organization
- `<TEST_TOOL>` → A real tool name your backend can install (for testing)

Files containing placeholders:
- `metadata.lua` - Plugin metadata
- `hooks/*.lua` - Backend implementation
- `mise-tasks/test` - Test script

## Development Commands

### Local Testing Workflow
```bash
# Link plugin for development
mise plugin link --force <BACKEND> .

# List available versions for a tool
mise ls-remote <BACKEND>:<tool>

# Install a specific version
mise install <BACKEND>:<tool>@<version>

# Execute a tool
mise exec <BACKEND>:<tool>@<version> -- <tool> --version

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
Defines plugin metadata returned to mise:
- Plugin name, version, description
- Author, homepage, license
- Optional user notes

### Hook Functions: `hooks/*.lua`

#### `backend_list_versions.lua`
**Purpose**: Return list of available versions for a tool

**Context variables**:
- `ctx.tool` - Tool name (e.g., `"prettier"`)

**Return value**: `{versions = {"1.0.0", "2.0.0", ...}}`

**Implementation patterns**:
- API-based: Query registry API (npm, PyPI, crates.io)
- Command-based: Execute CLI commands and parse output
- File-based: Parse local registry or manifest files

#### `backend_install.lua`
**Purpose**: Install a specific version of a tool to a directory

**Context variables**:
- `ctx.tool` - Tool name
- `ctx.version` - Version to install
- `ctx.install_path` - Target installation directory

**Return value**: `{}`

**Implementation patterns**:
- Package manager: Run install command with target directory
- Binary download: Download archive from URL, extract to install_path
- Build from source: Clone repository, checkout version, build and install

#### `backend_exec_env.lua`
**Purpose**: Set up environment variables for running the tool

**Context variables**:
- `ctx.tool` - Tool name
- `ctx.version` - Tool version
- `ctx.install_path` - Installation directory

**Return value**: `{env_vars = {{key = "PATH", value = "/path/to/bin"}, ...}}`

**Common patterns**:
- Add `bin/` directory to PATH
- Set tool-specific home/config directories
- Platform-specific library paths (LD_LIBRARY_PATH, DYLD_LIBRARY_PATH)

### Available Lua Modules

Backend plugins have access to these built-in modules:

- `cmd` - Execute shell commands: `cmd.exec("command")`
- `http` - HTTP client: `http.get({url = "..."})`, `http.download({url = "...", output = "..."})`
- `json` - JSON parsing: `json.decode(str)`, `json.encode(table)`
- `file` - File operations: `file.exists(path)`, `file.read(path)`, `file.join_path(a, b)`

### Runtime Information: `RUNTIME` Global

Platform detection available in all hooks:
- `RUNTIME.osType` - Operating system: `"Darwin"`, `"Linux"`, `"Windows"`
- `RUNTIME.archType` - CPU architecture: `"amd64"`, `"arm64"`, etc.

Example:
```lua
if RUNTIME.osType == "Darwin" then
    -- macOS-specific logic
elseif RUNTIME.osType == "Linux" then
    -- Linux-specific logic
end
```

## Testing Strategy

### Test File: `mise-tasks/test`
Bash script that validates the plugin:
1. Links the plugin with `mise plugin link --force`
2. Clears cache for fresh testing
3. Tests version listing with `mise ls-remote`
4. Tests installation with `mise install`
5. Tests tool execution with `mise exec`

**Note**: The test script will fail until you:
- Replace `<BACKEND>` and `<TEST_TOOL>` placeholders
- Implement the three backend hooks

### CI Pipeline: `.github/workflows/ci.yml`
- Runs on Ubuntu and macOS
- Executes `mise run ci` (lint + test)
- Triggered on push to main, PRs, and manual dispatch

## Code Quality Tools

### Linting: `hk.pkl`
Pre-commit hooks and linters configured via hk:
- **luacheck** - Lua static analysis (configured in `.luacheckrc`)
- **stylua** - Lua code formatting (configured in `stylua.toml`)
- **actionlint** - GitHub Actions workflow validation

### Luacheck Configuration: `.luacheckrc`
- Standard: Lua 5.1
- Allowed globals: `PLUGIN`, `RUNTIME`
- Read-only globals: `cmd`, `http`, `json`, `file`, standard Lua functions
- Ignores: Line length, trailing whitespace, unused arguments in hook functions

## Environment Variables

### `mise.toml` Configuration
```toml
[env]
MISE_USE_VERSIONS_HOST = "0"  # Disable version host for backend plugins
```

## Common Implementation Patterns

### Error Handling
```lua
-- Validate inputs
if not tool or tool == "" then
    error("Tool name cannot be empty")
end

-- Check API responses
if resp.status_code ~= 200 then
    error("API returned status " .. resp.status_code .. " for " .. tool)
end

-- Validate results
if #versions == 0 then
    error("No versions found for " .. tool)
end
```

### Platform-Specific Downloads
```lua
local platform = RUNTIME.osType:lower()
local arch = RUNTIME.archType
local url = "https://releases.example.com/" .. tool .. "/" .. version ..
            "/" .. tool .. "-" .. platform .. "-" .. arch .. ".tar.gz"
```

### PATH Setup
```lua
local file = require("file")
local bin_path = file.join_path(install_path, "bin")

return {
    env_vars = {
        {key = "PATH", value = bin_path}
    }
}
```

## Publishing Process

1. Replace all placeholders with real values
2. Implement the three backend hooks
3. Test locally: `mise run ci`
4. Push to GitHub repository
5. Test installation: `mise plugin install <backend> https://github.com/<user>/<repo>`
6. (Optional) Transfer to [mise-plugins](https://github.com/mise-plugins) organization
7. Add to mise registry via PR to [registry.toml](https://github.com/jdx/mise/blob/main/registry.toml)

## Reference Documentation

- [Backend Plugin Development Guide](https://mise.jdx.dev/backend-plugin-development.html)
- [Backend Architecture](https://mise.jdx.dev/dev-tools/backend_architecture.html)
- [Lua Modules Reference](https://mise.jdx.dev/plugin-lua-modules.html)
- [mise-plugins Organization](https://github.com/mise-plugins)

## Real-World Examples

Study these existing backend plugins for implementation patterns:
- [vfox-npm](https://github.com/jdx/vfox-npm) - npm package manager backend
- mise built-in backends: npm, cargo, pip, gem
