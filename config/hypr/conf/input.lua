-- ──────────────────────────────── INPUT ─────────────────────────────────────
hl.config({
    input = {
        kb_layout = "us",
        -- altgr-intl: same US layout you already use, but AltGr adds accents
        -- and ñ  →  AltGr+a = á, AltGr+n = ñ, AltGr+? = ¿
        kb_variant = "altgr-intl",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        numlock_by_default = true,
        repeat_rate        = 40,
        repeat_delay       = 250,

        follow_mouse       = 1,
        mouse_refocus      = true,
        float_switch_override_focus = 2,

        sensitivity  = 0,
        accel_profile = "flat", -- no mouse acceleration (better for games)

        resolve_binds_by_sym = false,

        touchpad = {
            natural_scroll   = false,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor    = 0.8,
        },
    },
})

-- ─────────────────────────────── GESTURES ───────────────────────────────────
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up",         action = "special",  workspace_name = "magic" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })

-- ────────────────────────────── PER-DEVICE ──────────────────────────────────
-- hyprctl devices  → exact names. Example of a per-device config:
-- hl.device({ name = "my-mouse", sensitivity = -0.2, accel_profile = "flat" })
