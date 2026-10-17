-- Authored opt-in particle metadata route; exact upstream fallback remains private.
if gadgetHandler:IsSyncedCode() then
 VFS.Include('40k_reference/demand_support/original/luarules/gadgets/gfx_fire_smoke_gl4.lua', getfenv(1))
 return
end
local review = VFS.Include('40k_configs/demand_model_review.lua')
VFS.Include('40k_reference/demand_support/' .. (review and 'candidate/' or 'original/') .. 'luarules/gadgets/gfx_fire_smoke_gl4.lua', getfenv(1))
