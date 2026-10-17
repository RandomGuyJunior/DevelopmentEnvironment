-- Authored opt-in wrapper; pinned upstream bodies remain private.
local review = VFS.Include('40k_configs/demand_model_review.lua')
if review then VFS.Include('40k_configs/source_native_bounds_cache.lua').New() end
VFS.Include('40k_reference/demand_support/' .. (review and 'candidate/' or 'original/') .. 'luarules/gadgets/gfx_reclaim_fx.lua', getfenv(1))
