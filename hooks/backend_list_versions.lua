-- hooks/backend_list_versions.lua
-- Lists available versions for a tool in this backend
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions

function PLUGIN:BackendListVersions(ctx)
    local tool = ctx.tool

    -- Validate tool name
    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end

    -- Accept both "ruby" and "rv-ruby" as the tool name
    -- This allows both rv-ruby@version and rv-ruby:ruby@version
    if tool ~= "ruby" and tool ~= "rv-ruby" then
        error("mise-rv-ruby backend only supports ruby. Use: rv-ruby@version or rv-ruby:ruby@version")
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
    local success, data = pcall(json.decode, result)
    if not success then
        error("Failed to parse rv output: " .. tostring(data))
    end

    -- Extract and deduplicate versions
    -- rv returns entries for each platform/arch combo, we just want unique version strings
    local versions_set = {}

    for _, entry in ipairs(data) do
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

    -- Sort versions in ascending order (oldest first)
    -- Use semantic version comparison: split by dots and compare numerically
    table.sort(versions, function(a, b)
        local a_parts = {}
        local b_parts = {}

        -- Split version strings by dots
        for part in a:gmatch("[^%.%-]+") do
            table.insert(a_parts, tonumber(part) or part)
        end
        for part in b:gmatch("[^%.%-]+") do
            table.insert(b_parts, tonumber(part) or part)
        end

        -- Compare each part numerically
        for i = 1, math.max(#a_parts, #b_parts) do
            local a_val = a_parts[i] or 0
            local b_val = b_parts[i] or 0

            -- Convert to numbers for comparison if both are numbers
            if type(a_val) == "number" and type(b_val) == "number" then
                if a_val ~= b_val then
                    return a_val < b_val
                end
            else
                -- Fallback to string comparison for non-numeric parts
                if a_val ~= b_val then
                    return tostring(a_val) < tostring(b_val)
                end
            end
        end

        return false
    end)

    if #versions == 0 then
        error("No Ruby versions found from rv")
    end

    return { versions = versions }
end
