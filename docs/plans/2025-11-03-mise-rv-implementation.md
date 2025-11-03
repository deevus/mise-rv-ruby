# mise-rv Backend Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a mise backend plugin that manages Ruby versions using the rv tool.

**Architecture:** Three Lua hook functions (BackendListVersions, BackendInstall, BackendExecEnv) that wrap rv CLI commands. The plugin uses rv's native commands via the `cmd` module and parses JSON output using the `json` module.

**Tech Stack:** Lua 5.4, mise backend plugin system, rv (Ruby version manager)

---

## Task 1: Update Plugin Metadata

**Files:**
- Modify: `metadata.lua:1-30`

**Step 1: Replace placeholder values in metadata.lua**

Open `metadata.lua` and replace all placeholders with rv-specific values:

```lua
-- metadata.lua
-- Backend plugin metadata and configuration
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html

PLUGIN = { -- luacheck: ignore
    -- Required: Plugin name (will be the backend name users reference)
    name = "rv",

    -- Required: Plugin version (not the tool versions)
    version = "1.0.0",

    -- Required: Brief description of the backend and tools it manages
    description = "A mise backend plugin for managing Ruby versions using rv",

    -- Required: Plugin author/maintainer
    author = "spinel-coop",

    -- Optional: Plugin homepage/repository URL
    homepage = "https://github.com/spinel-coop/mise-rv",

    -- Optional: Plugin license
    license = "MIT",

    -- Optional: Important notes for users
    notes = {
        "Requires rv to be installed (automatically handled via ubi backend)",
    },
}
```

**Step 2: Verify syntax**

Run: `lua metadata.lua`
Expected: No output (syntax is valid)

**Step 3: Commit**

```bash
git add metadata.lua
git commit -m "feat: update metadata with rv-specific values

Replace template placeholders with mise-rv backend information.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Add rv Dependency

**Files:**
- Modify: `mise.toml:1-21`

**Step 1: Add rv as a tool dependency**

Open `mise.toml` and add `ubi:spinel-coop/rv` to the tools section:

```toml
[env]
MISE_USE_VERSIONS_HOST = "0"

[tools]
"ubi:spinel-coop/rv" = "latest"
actionlint = "latest"
hk = "latest"
lua = "5.4"
pkl = "latest"
stylua = "latest"

[tasks.format]
description = "Format Lua scripts"
run = "stylua metadata.lua hooks/"

[tasks.lint]
description = "Lint Lua scripts and GitHub Actions using hk"
run = "hk check"

[tasks.ci]
description = "Run all CI checks"
depends = ["lint", "test"]
```

**Step 2: Install rv**

Run: `mise install`
Expected: Output showing rv installation from ubi backend

**Step 3: Verify rv is available**

Run: `mise exec -- rv --version`
Expected: Version output from rv (e.g., "rv 0.x.x")

**Step 4: Commit**

```bash
git add mise.toml
git commit -m "feat: add rv as ubi backend dependency

Ensures rv is available when the plugin executes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Implement BackendListVersions

**Files:**
- Modify: `hooks/backend_list_versions.lua:1-86`

**Step 1: Implement version listing logic**

Replace the entire contents of `hooks/backend_list_versions.lua` with:

```lua
-- hooks/backend_list_versions.lua
-- Lists available versions for a tool in this backend
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions

function PLUGIN:BackendListVersions(ctx)
    local tool = ctx.tool

    -- Validate tool name
    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end

    -- Only support "ruby" as the tool name
    if tool ~= "ruby" then
        error("mise-rv backend only supports 'ruby' as the tool name. Use: rv:ruby@version")
    end

    -- Get available Ruby versions from rv
    local cmd = require("cmd")
    local json = require("json")

    -- Execute rv ruby list with JSON output
    local result, err = cmd.exec("rv ruby list --format json")

    if err then
        error("Failed to execute rv command. Is rv installed? Error: " .. err)
    end

    -- Parse JSON response
    local data, decode_err = pcall(json.decode, result)
    if not data then
        error("Failed to parse rv output: " .. (decode_err or "unknown error"))
    end

    -- Extract and deduplicate versions
    -- rv returns entries for each platform/arch combo, we just want unique version strings
    local versions_set = {}

    for _, entry in ipairs(decode_err) do -- decode_err contains the decoded data when pcall succeeds
        if entry.version then
            -- Strip "ruby-" prefix (e.g., "ruby-3.3.9" -> "3.3.9")
            local version = entry.version:gsub("^ruby%-", "")
            versions_set[version] = true
        end
    end

    -- Convert set to array
    local versions = {}
    for version, _ in pairs(versions_set) do
        table.insert(versions, version)
    end

    if #versions == 0 then
        error("No Ruby versions found from rv")
    end

    return { versions = versions }
end
```

**Step 2: Test version listing**

First, link the plugin:

Run: `mise plugin link --force rv .`
Expected: "Plugin rv linked to /Users/sh/Projects/foss/mise-rv"

Then test version listing:

Run: `mise ls-remote rv:ruby 2>&1 | head -20`
Expected: List of Ruby versions (3.2.9, 3.3.9, 3.4.7, etc.)

**Step 3: Fix if errors occur**

If you see errors about `pcall` usage, the issue is that `pcall` returns `(success, result)` not `(result, error)`. Fix the code:

```lua
-- Parse JSON response
local success, data = pcall(json.decode, result)
if not success then
    error("Failed to parse rv output: " .. tostring(data))
end

-- Extract and deduplicate versions
local versions_set = {}

for _, entry in ipairs(data) do
    if entry.version then
        -- Strip "ruby-" prefix (e.g., "ruby-3.3.9" -> "3.3.9")
        local version = entry.version:gsub("^ruby%-", "")
        versions_set[version] = true
    end
end
```

**Step 4: Re-test after fix**

Run: `mise ls-remote rv:ruby 2>&1 | head -20`
Expected: List of Ruby versions without errors

**Step 5: Commit**

```bash
git add hooks/backend_list_versions.lua
git commit -m "feat: implement BackendListVersions for rv

Queries rv ruby list --format json and extracts available Ruby
versions. Deduplicates versions across different platforms.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Implement BackendInstall

**Files:**
- Modify: `hooks/backend_install.lua:1-104`

**Step 1: Implement installation logic**

Replace the entire contents of `hooks/backend_install.lua` with:

```lua
-- hooks/backend_install.lua
-- Installs a specific version of a tool
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendinstall

function PLUGIN:BackendInstall(ctx)
    local tool = ctx.tool
    local version = ctx.version
    local install_path = ctx.install_path

    -- Validate inputs
    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end
    if not version or version == "" then
        error("Version cannot be empty")
    end
    if not install_path or install_path == "" then
        error("Install path cannot be empty")
    end

    -- Only support "ruby" as the tool name
    if tool ~= "ruby" then
        error("mise-rv backend only supports 'ruby' as the tool name. Use: rv:ruby@version")
    end

    -- Create installation directory
    local cmd = require("cmd")
    cmd.exec("mkdir -p " .. install_path)

    -- Install Ruby using rv with custom install directory
    -- rv ruby install <version> --install-dir <path>
    local install_cmd = "rv ruby install " .. version .. " --install-dir " .. install_path

    -- Execute installation (will error automatically if rv command fails)
    cmd.exec(install_cmd)

    return {}
end
```

**Step 2: Test installation**

Run: `mise install rv:ruby@3.3.9`
Expected: rv downloads and installs Ruby 3.3.9 (should be very fast, ~1 second)

**Step 3: Verify installation directory**

Run: `ls -la ~/.local/share/mise/installs/rv/ruby/3.3.9/bin/ | head -10`
Expected: ruby, gem, bundle, irb, etc. binaries

**Step 4: Commit**

```bash
git add hooks/backend_install.lua
git commit -m "feat: implement BackendInstall for rv

Installs Ruby versions to mise's install directory using
rv ruby install --install-dir flag.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Implement BackendExecEnv

**Files:**
- Modify: `hooks/backend_exec_env.lua:1-85`

**Step 1: Implement environment setup logic**

Replace the entire contents of `hooks/backend_exec_env.lua` with:

```lua
-- hooks/backend_exec_env.lua
-- Sets up environment variables for a tool
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendexecenv

function PLUGIN:BackendExecEnv(ctx)
    local install_path = ctx.install_path
    local tool = ctx.tool
    local version = ctx.version

    -- Validate inputs
    if not install_path or install_path == "" then
        error("Install path cannot be empty")
    end
    if not version or version == "" then
        error("Version cannot be empty")
    end

    -- Basic PATH setup
    local file = require("file")
    local bin_path = file.join_path(install_path, "bin")

    local env_vars = {
        -- Add tool's bin directory to PATH
        { key = "PATH", value = bin_path },
    }

    -- Set up GEM_HOME and GEM_PATH for proper gem isolation
    -- Ruby gem path uses major.minor.0 format (e.g., 3.3.9 -> 3.3.0)
    local major, minor = version:match("^(%d+)%.(%d+)")

    if major and minor then
        local gem_version = major .. "." .. minor .. ".0"
        local gem_path = file.join_path(install_path, "lib", "ruby", "gems", gem_version)

        table.insert(env_vars, {
            key = "GEM_HOME",
            value = gem_path,
        })

        table.insert(env_vars, {
            key = "GEM_PATH",
            value = gem_path,
        })
    end

    return {
        env_vars = env_vars,
    }
end
```

**Step 2: Test Ruby execution**

Run: `mise exec rv:ruby@3.3.9 -- ruby --version`
Expected: "ruby 3.3.9 ..." version output

**Step 3: Test gem environment**

Run: `mise exec rv:ruby@3.3.9 -- gem env | grep -A 2 "GEM PATHS"`
Expected: GEM_HOME points to mise's install directory

**Step 4: Test gem installation**

Run: `mise exec rv:ruby@3.3.9 -- gem install json --no-document`
Expected: Gem installs successfully

Run: `mise exec rv:ruby@3.3.9 -- gem list json`
Expected: Shows json gem is installed

**Step 5: Commit**

```bash
git add hooks/backend_exec_env.lua
git commit -m "feat: implement BackendExecEnv for rv

Sets up PATH, GEM_HOME, and GEM_PATH for proper Ruby and gem
execution with version isolation.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Update Test Script

**Files:**
- Modify: `mise-tasks/test:1-42`

**Step 1: Replace test script with rv-specific tests**

Replace the entire contents of `mise-tasks/test` with:

```bash
#!/usr/bin/env bash
#MISE description="Run backend plugin tests - test plugin linking and basic functionality"
set -euo pipefail

# Link the plugin for testing
mise plugin link --force rv .

# Clear cache to ensure fresh testing
mise cache clear

echo "Testing mise-rv backend plugin..."
echo "=================================="

# Test tool name - we only support "ruby"
TEST_TOOL="ruby"
TEST_VERSION="3.3.9"

# Test 1: Version listing
echo ""
echo "Test 1: Version listing"
echo "-----------------------"
if mise ls-remote rv:${TEST_TOOL} | grep -q "${TEST_VERSION}"; then
    echo "✓ Version listing works (found ${TEST_VERSION})"
else
    echo "✗ Version listing failed - ${TEST_VERSION} not found"
    exit 1
fi

# Test 2: Installation
echo ""
echo "Test 2: Installation"
echo "--------------------"
if mise install rv:${TEST_TOOL}@${TEST_VERSION}; then
    echo "✓ Installation works"
else
    echo "✗ Installation failed"
    exit 1
fi

# Test 3: Ruby execution
echo ""
echo "Test 3: Ruby execution"
echo "----------------------"
if mise exec rv:${TEST_TOOL}@${TEST_VERSION} -- ruby --version | grep -q "ruby ${TEST_VERSION}"; then
    echo "✓ Ruby execution works"
else
    echo "✗ Ruby execution failed"
    exit 1
fi

# Test 4: Gem environment
echo ""
echo "Test 4: Gem environment"
echo "-----------------------"
if mise exec rv:${TEST_TOOL}@${TEST_VERSION} -- gem env | grep -q "GEM PATHS"; then
    echo "✓ Gem environment configured"
else
    echo "✗ Gem environment not configured properly"
    exit 1
fi

# Test 5: Gem installation
echo ""
echo "Test 5: Gem installation"
echo "------------------------"
if mise exec rv:${TEST_TOOL}@${TEST_VERSION} -- gem install json --no-document 2>&1 | grep -q "Successfully installed"; then
    echo "✓ Gem installation works"
else
    echo "✗ Gem installation failed"
    exit 1
fi

echo ""
echo "=================================="
echo "✓ All tests passed!"
```

**Step 2: Make script executable**

Run: `chmod +x mise-tasks/test`

**Step 3: Run the test script**

Run: `mise run test`
Expected: All 5 tests pass with ✓ marks

**Step 4: Commit**

```bash
git add mise-tasks/test
git commit -m "feat: update test script for rv backend

Tests version listing, installation, Ruby execution, gem
environment, and gem installation.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: Final Validation

**Files:**
- None (testing only)

**Step 1: Run full CI suite**

Run: `mise run ci`
Expected: Both lint and test tasks pass

**Step 2: Test with different Ruby version**

Run: `mise install rv:ruby@3.4.7`
Expected: Installation succeeds

Run: `mise exec rv:ruby@3.4.7 -- ruby --version`
Expected: "ruby 3.4.7 ..." version output

**Step 3: Test error cases**

Test invalid tool name:
Run: `mise ls-remote rv:python 2>&1`
Expected: Error message "mise-rv backend only supports 'ruby' as the tool name"

Test invalid version:
Run: `mise install rv:ruby@99.99.99 2>&1`
Expected: rv error about version not found

**Step 4: Clean up test installations (optional)**

Run: `rm -rf ~/.local/share/mise/installs/rv`

**Step 5: Document completion**

Create a summary of what was implemented and tested. No commit needed.

---

## Verification Checklist

Before marking complete, verify:

- [ ] `mise ls-remote rv:ruby` lists available Ruby versions
- [ ] `mise install rv:ruby@3.3.9` installs Ruby successfully
- [ ] `mise exec rv:ruby@3.3.9 -- ruby --version` shows correct version
- [ ] `mise exec rv:ruby@3.3.9 -- gem env` shows GEM_HOME in mise directory
- [ ] `mise exec rv:ruby@3.3.9 -- gem install <gem>` installs gems correctly
- [ ] `mise run test` passes all tests
- [ ] `mise run ci` passes both lint and test
- [ ] All changes are committed to git
- [ ] Invalid tool names (not "ruby") produce helpful error messages

---

## Notes

- **TDD Approach**: For this plugin system, we test via mise commands rather than unit tests, since the Lua code runs within mise's plugin environment
- **Error Messages**: All error messages should be clear and actionable
- **Commit Messages**: Follow conventional commits format with emoji footer
- **Platform Support**: rv currently supports macOS 14+ and Ubuntu 24.04+, so tests will only work on these platforms
