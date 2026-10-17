-- Prepared genuine Ogryn terminal source corpse, one existing shared owner.
local M={Version=1,Actor='imp_ogryn',Feature='40k_ogryn_corpse'}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Register(owner,options,VFS,proof)
 if not yes((options or{}).prototype_guard_ogryn_squad)then return false,'ogryn_squad_route_disabled'end
 if type(proof)~='table'or proof.status~='STATIC_SOURCE_DEATH_VERIFIED'or proof.actor~=M.Actor or proof.feature~=M.Feature
  or proof.sourceOwnedStandalone~=true or proof.donor~=false or proof.clip~='die_normal_1'or proof.terminalFrame~=181
  or proof.recipeSHA256~='b1206cb5d10569686ec40d7160a745d95fe0a0bce38e6320dcc9878b04e28300'
  or proof.staticUnskinned~=true or proof.groundContactVerified~=true or proof.heightBoundVerified~=true or proof.materialsMatchLive~=true then
  return false,'genuine_ogryn_corpse_closure_unready'
 end
 assert(type(owner)=='table'and owner.Version==1 and owner.Fraction==.25 and type(owner.Actors)=='table'and type(owner.Definition)=='function','Reviewed sole corpse owner required')
 assert(not owner.Actors[M.Actor],'Duplicate Ogryn corpse registration refused')
 assert(type(VFS)=='table'and type(VFS.FileExists)=='function','Exact private asset closure required')
 for _,path in ipairs({'objects3d/'..M.Feature..'.glb','unittextures/'..M.Feature..'_tex1.png','unittextures/'..M.Feature..'_tex2.png'})do
  if VFS.FileExists(path)~=true then return false,'genuine_private_ogryn_corpse_asset_missing'end
 end
 owner.Actors[M.Actor]={feature=M.Feature,name='Ogryn'}
 return true,'registered_existing_single_entitlement_owner_only'
end
return M
