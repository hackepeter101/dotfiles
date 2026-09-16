-- Monitor wiki https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({
    output    = "",
    mode      = "preferred",
    position  = "auto",
    scale     = "auto",
})

local function assignWorkspaces()
    local monitors = io.popen("hyprctl monitors -j | jq -r 'sort_by(.width * .height) | reverse | .[] | [.name, .width, .height] | @tsv'")
    if not monitors then
        return
    end

    local monitor_index = 0
    local next_workspace = 8

    for line in monitors:lines() do
        local monitor, width, height = line:match("([^%s]+)%s+(%d+)%s+(%d+)")
        if monitor and width and height then
            local first_workspace
            local last_workspace

            if monitor_index == 0 then
                first_workspace = 1
                last_workspace = 5
            elseif monitor_index == 1 then
                first_workspace = 6
                last_workspace = 7
            else
                first_workspace = next_workspace
                last_workspace = next_workspace + 1
                next_workspace = last_workspace + 1
            end

            for workspace = first_workspace, last_workspace do
                hl.dispatch(hl.dsp.workspace.move({
                    workspace = workspace,
                    monitor = monitor,
                }))
            end

            monitor_index = monitor_index + 1
        end
    end

    monitors:close()
end

hl.on("hyprland.start", assignWorkspaces)
hl.on("monitor.added", assignWorkspaces)
hl.on("monitor.removed", assignWorkspaces)
