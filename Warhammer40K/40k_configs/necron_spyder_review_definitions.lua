-- Root composition hook; identity only, never stats or paid profiles.
local M={}
local actors={nec_spyder='necron_tomb_spyder',nec_warrior='necron_basic_warrior',nec_flayed='necron_flayed_one',nec_immortal='necron_immortal',nec_wraith='necron_wraith',nec_destroyer='necron_destroyer'}
function M.Apply(defs,options)
 if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_spyder_harvest_review)or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression)or options.prototype_diagnostic~='expandedproduction'then return false end
 for name,actor in pairs(actors)do
  local d=defs[name];if d then local cp=d.customparams or{};d.customparams=cp
   assert(cp.animsource==name,'Unknown source animation identity')
   assert(not cp.source_entity or cp.source_entity=='attrib/ebps/races/necrons/troops/'..actor..'.lua','Conflicting source identity')
   cp.source_entity='attrib/ebps/races/necrons/troops/'..actor..'.lua';cp.necron_spyder_harvest_review=1
  end
 end
 return true
end
return M
