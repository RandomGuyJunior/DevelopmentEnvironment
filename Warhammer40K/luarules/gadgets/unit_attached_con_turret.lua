-- Authored opt-in route; exact original body remains the normal fallback.
local review = VFS.Include('40k_configs/demand_model_review.lua')
VFS.Include('40k_reference/demand_support/' .. (review and 'candidate/' or 'original/') .. 'luarules/gadgets/unit_attached_con_turret.lua', getfenv(1))
