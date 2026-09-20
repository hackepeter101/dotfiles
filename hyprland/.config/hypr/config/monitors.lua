-- Monitor wiki https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({
    output   = "DP-3",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

hl.monitor({
    output   = "DP-1",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

local function assignWorkspaces()
    for workspace = 1, 5 do
        hl.dispatch(hl.dsp.workspace.move({
            workspace = workspace,
            monitor = "DP-3",
        }))
    end

    for workspace = 6, 7 do
        hl.dispatch(hl.dsp.workspace.move({
            workspace = workspace,
            monitor = "DP-1",
        }))
    end
end

hl.on("hyprland.start", assignWorkspaces)
hl.on("monitor.added", assignWorkspaces)
hl.on("monitor.removed", assignWorkspaces)
