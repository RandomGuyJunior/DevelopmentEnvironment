-- Authored opt-in wrapper; pinned upstream bodies remain private.
local review = VFS.Include('40k_configs/demand_model_review.lua')
VFS.Include('40k_reference/demand_support/' .. (review and 'candidate/' or 'original/') .. 'luarules/gadgets/unit_area_timed_damage.lua', getfenv(1))
