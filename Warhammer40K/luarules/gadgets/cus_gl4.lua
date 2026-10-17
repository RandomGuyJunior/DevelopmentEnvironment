-- Release-only: retain the original visual-only scope before cache admission.
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "CUS GL4",
		desc = "Implements CustomUnitShaders for GL4 rendering pipeline",
		version = "0.5",
		author = "ivand, Beherith",
		date = "20220310",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		depends = { "gl4" },
	}
end

if gadgetHandler:IsSyncedCode() or (Platform and Platform.isHeadless) then
 return false
end
-- Authored opt-in wrapper; pinned upstream bodies remain private.
local review = VFS.Include('40k_configs/demand_model_review.lua')
if review then VFS.Include('40k_configs/source_native_bounds_cache.lua').New() end
VFS.Include('40k_reference/demand_support/' .. (review and 'candidate/' or 'original/') .. 'luarules/gadgets/cus_gl4.lua', getfenv(1))
