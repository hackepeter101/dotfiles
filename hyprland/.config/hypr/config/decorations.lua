-- Look and feel configuration

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 1,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border = {
                colors = { charcoal, frozenWater },
                angle = 90,
            },
            inactive_border = charcoal,
        },
    },
    group = {
        col = {
            border_active = frozenWater,
            border_inactive = charcoal,
            border_locked_active = darkRed,
            border_locked_inactive = charcoal,
        },
        groupbar = {
            col = {
                active = frozenWater,
                inactive = charcoal,
                locked_active = goldenPollen,
                locked_inactive = charcoal,
            },
        },
    },
    decoration = {
        dim_special = 0.3,
        rounding = 0,
        active_opacity = 0.95,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1,
        blur = {
            size = 5,
            passes = 4,
            special = true,
        },
    },
})
