-- Exactly one genuine animation/weapon owner; no fake seats or model edits.
include('40k_roster.lua')
VFS.Include('40k_configs/squad_carrier_script.lua').Install(
 script,Spring,GG,UnitDefs,unitID,unitDefID)
