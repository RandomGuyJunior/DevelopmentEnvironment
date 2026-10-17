-- Default-off private genuine Burna corpse pilot; existing sole owner only.
local M={Option='prototype_burna_remains_pilot',Actor='ork_burna',Feature='40k_burna_corpse'}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(options)return type(options)=='table'and yes(options[M.Option])end
function M.Register(owner,options,VFS)
 if not M.Enabled(options)then return nil end
 assert(yes(options.prototype_ork_burna_squad),'Burna remains pilot requires paid fixed Burna squad')
 assert(VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options),'Burna remains pilot requires ordinary source progression')
 assert(not VFS.Include('40k_configs/scale_pilot.lua').Enabled(options),'Unpaired Burna remains scale085 refused')
 local recipe=VFS.Include('40k_configs/burna_remains_recipe.lua')
 local proof=VFS.Include('40k_configs/burna_remains_asset_closure.lua')
 assert(proof.nativeAccepted==false and proof.renderAccepted==false and proof.classification=='GENUINE_BURNA_SOURCE_DEATH','Truthful pending Burna genuine presentation required')
 assert(recipe.Actor==M.Actor and recipe.Feature==M.Feature,'Exact private Burna recipe identity required')
 assert(recipe.Register(owner,options,VFS,proof),'Closed private Burna genuine asset required')
 return owner.Definition(nil,M.Actor)
end
return M
