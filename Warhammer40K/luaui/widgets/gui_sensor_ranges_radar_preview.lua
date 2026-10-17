-- Authored opt-in route; exact original body remains the normal fallback.
local review = VFS.Include('40k_configs/demand_model_review.lua')
VFS.Include('40k_reference/demand_support/' .. (review and 'candidate/' or 'original/') .. 'luaui/widgets/gui_sensor_ranges_radar_preview.lua', getfenv(1))
