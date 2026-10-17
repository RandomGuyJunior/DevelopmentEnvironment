-- Authored opt-in route; exact normal effect body remains available.
local review = VFS.Include('40k_configs/demand_model_review.lua')
VFS.Include('40k_reference/demand_support/' .. (review and 'candidate/' or 'original/') .. 'luarules/gadgets/gfx_reclaim_shards.lua', getfenv(1))
