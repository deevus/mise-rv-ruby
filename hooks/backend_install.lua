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
