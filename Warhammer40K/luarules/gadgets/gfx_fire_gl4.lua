-- Authored opt-in Fire GL4 route; exact upstream fallback remains private.
if gadgetHandler:IsSyncedCode() then
	return
end
local review = VFS.Include('40k_configs/demand_model_review.lua')
VFS.Include('40k_reference/demand_support/' .. (review and 'candidate/' or 'original/') .. 'luarules/gadgets/gfx_fire_gl4.lua', getfenv(1))
