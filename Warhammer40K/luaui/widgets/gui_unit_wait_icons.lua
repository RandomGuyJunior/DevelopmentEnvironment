-- Authored opt-in wrapper; pinned upstream bodies remain private.
local review = VFS.Include('40k_configs/demand_model_review.lua')
VFS.Include('40k_reference/demand_support/' .. (review and 'candidate/' or 'original/') .. 'luaui/widgets/gui_unit_wait_icons.lua', getfenv(1))
