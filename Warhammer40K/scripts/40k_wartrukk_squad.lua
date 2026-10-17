-- Keep the one genuine chassis/weapon animator. Only cargo/death callbacks differ.
include('40k_roster.lua')
VFS.Include('40k_configs/wartrukk_squad_script.lua').Install(script,Spring,GG,UnitDefs,unitID,unitDefID)
