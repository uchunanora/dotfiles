-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

config.color_scheme = "Tokyo Night"
config.window_background_opacity = 0.85
config.macos_window_background_blur = 20
-- config.window_decorations = "RESIZE"
config.automatically_reload_config = true

-- font
config.font_size = 13.0
config.font = wezterm.font("HackGen Console NF")

-- and finally, return the configuration to wezterm
return config
