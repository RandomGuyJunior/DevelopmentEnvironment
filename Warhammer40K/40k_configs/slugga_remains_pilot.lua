-- Default-off private genuine Slugga corpse pilot; existing sole owner only.
local M={Option='prototype_slugga_remains_pilot',Actor='ork_slugga',Feature='40k_slugga_corpse'}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(options)return type(options)=='table'and yes(options[M.Option])end
function M.Register(owner,options,VFS)
 if not M.Enabled(options)then return nil end
 assert(yes(options.prototype_ork_slugga_squad),'Slugga remains pilot requires paid fixed Slugga squad')
 assert(VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options),'Slugga remains pilot requires ordinary source progression')
 assert(not VFS.Include('40k_configs/scale_pilot.lua').Enabled(options),'Unpaired Slugga remains scale085 refused')
 local recipe=VFS.Include('40k_configs/slugga_remains_recipe.lua')
 local proof=VFS.Include('40k_configs/slugga_remains_asset_closure.lua')
 assert(proof.nativeAccepted==false and proof.renderAccepted==false and proof.classification=='GENUINE_SLUGGA_SOURCE_DEATH','Truthful pending Slugga genuine presentation required')
 assert(recipe.Actor==M.Actor and recipe.Feature==M.Feature,'Exact private Slugga recipe identity required')
 assert(recipe.Register(owner,options,VFS,proof),'Closed private Slugga genuine asset required')
 return owner.Definition(nil,M.Actor)
end
return M
