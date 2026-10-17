-- Actual genuine buildings; diagnostic opt-in never implies native acceptance.
local opts=Spring and Spring.GetModOptions and Spring.GetModOptions()or{}
-- Mixed benchmark has an exact independent roster; never grow it here.
if VFS.Include('40k_configs/mixed_v2_adapter.lua').Enabled(opts)then return {}end
local M=VFS.Include('40k_configs/marine_infrastructure_candidates.lua')
local facts=VFS.Include('40k_configs/marine_infrastructure_facts.lua')
-- Verified pinned UnitDef recipe: immobile + yardmap + positive builder rate/distance.
-- This verifies classification prerequisites, not native egress or model acceptance.
local function factoryContract(key)
 return key=='imp_marine_hq'or key=='imp_marine_barracks'
end
return M.Definitions(facts,opts,factoryContract)
