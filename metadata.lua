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
    author = "deevus",

    -- Optional: Plugin homepage/repository URL
    homepage = "https://github.com/deevus/mise-rv",

    -- Optional: Plugin license
    license = "MIT",

    -- Optional: Important notes for users
    notes = {
        "Requires rv to be installed (automatically handled via ubi backend)",
    },
}
