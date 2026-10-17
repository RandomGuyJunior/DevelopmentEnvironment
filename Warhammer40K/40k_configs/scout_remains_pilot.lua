-- Default-off private authored presentation pilot; existing sole owner only.
local M={Option='prototype_scout_remains_pilot',Actor='imp_scout',Feature='40k_scout_corpse'}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(options)return type(options)=='table'and yes(options[M.Option])end
function M.Register(owner,options,VFS)
 if not M.Enabled(options)then return nil end
 assert(yes(options.prototype_marine_scout_squad),'Scout remains pilot requires paid fixed Scout squad')
 assert(VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options),'Scout remains pilot requires ordinary source progression')
 assert(not VFS.Include('40k_configs/scale_pilot.lua').Enabled(options),'Unpaired Scout remains scale085 refused')
 local recipe=VFS.Include('40k_configs/scout_remains_recipe.lua')
 local proof=VFS.Include('40k_configs/scout_remains_asset_closure.lua')
 assert(proof.nativeAccepted==false and proof.renderAccepted==false and proof.classification=='AUTHORED_STATIC_SCOUT_POSE','Truthful pending Scout authored presentation required')
 assert(recipe.Actor==M.Actor and recipe.Feature==M.Feature,'Exact private Scout recipe identity required')
 assert(recipe.Register(owner,options,VFS,proof),'Closed private Scout authored asset required')
 return owner.Definition(nil,M.Actor)
end
return M
