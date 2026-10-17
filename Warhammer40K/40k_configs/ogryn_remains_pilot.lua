-- Default-off private genuine Ogryn corpse pilot; existing sole owner only.
local M={Option='prototype_ogryn_remains_pilot',Actor='imp_ogryn',Feature='40k_ogryn_corpse'}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(options)return type(options)=='table'and yes(options[M.Option])end
function M.Register(owner,options,VFS)
 if not M.Enabled(options)then return nil end
 assert(yes(options.prototype_guard_ogryn_squad),'Ogryn remains pilot requires paid fixed Ogryn squad')
 assert(VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options),'Ogryn remains pilot requires ordinary source progression')
 assert(not VFS.Include('40k_configs/scale_pilot.lua').Enabled(options),'Unpaired Ogryn remains scale085 refused')
 local recipe=VFS.Include('40k_configs/ogryn_remains_recipe.lua')
 local proof=VFS.Include('40k_configs/ogryn_remains_asset_closure.lua')
 assert(proof.nativeAccepted==false and proof.renderAccepted==false and proof.classification=='GENUINE_OGRYN_SOURCE_DEATH','Truthful pending Ogryn genuine presentation required')
 assert(recipe.Actor==M.Actor and recipe.Feature==M.Feature,'Exact private Ogryn recipe identity required')
 assert(recipe.Register(owner,options,VFS,proof),'Closed private Ogryn genuine asset required')
 return owner.Definition(nil,M.Actor)
end
return M
