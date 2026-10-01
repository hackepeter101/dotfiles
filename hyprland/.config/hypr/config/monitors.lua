-- Monitor wiki https://wiki.hypr.land/Configuring/Basics/Monitors/

local monitorConfig = {
    monitors = {
        {
            output   = "DP-3",
            mode     = "preferred",
            position = "auto",
            scale    = "auto",
        },
        {
            output   = "DP-1",
            mode     = "preferred",
            position = "auto",
            scale    = "auto",
        },
    },
    workspaces = {
        ["DP-3"] = { 1, 2, 3, 4, 5 },
        ["DP-1"] = { 6, 7 },
    },
}

-- Keep hardware-specific monitor choices outside the shared repository.
local home = os.getenv("HOME")
local localConfigPath = home and (home .. "/.config/hypr-monitors.lua")
local localConfigFile = localConfigPath and io.open(localConfigPath, "r")

if localConfigFile then
    localConfigFile:close()
    local loaded, customConfig = pcall(dofile, localConfigPath)
    if not loaded then
        error("Could not load " .. localConfigPath .. ": " .. customConfig)
    end
    if type(customConfig) ~= "table" then
        error(localConfigPath .. " must return a Lua table")
    end
    monitorConfig = customConfig
end

for _, monitor in ipairs(monitorConfig.monitors or {}) do
    hl.monitor(monitor)
end

local function assignWorkspaces()
    for monitor, workspaces in pairs(monitorConfig.workspaces or {}) do
        for _, workspace in ipairs(workspaces) do
            hl.dispatch(hl.dsp.workspace.move({
                workspace = workspace,
                monitor = monitor,
            }))
        end
    end
end

hl.on("hyprland.start", assignWorkspaces)
hl.on("monitor.added", assignWorkspaces)
hl.on("monitor.removed", assignWorkspaces)
