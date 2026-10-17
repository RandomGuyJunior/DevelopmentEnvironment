-- Prepared authored-static Scout recipe; source-owned death clip stays unavailable.
-- The existing shared owner alone handles paid generations, native death and reclaim.
local M={Version=1,Actor='imp_scout',Feature='40k_scout_corpse'}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Register(owner,options,VFS,proof)
 if not yes((options or{}).prototype_marine_scout_squad)then return false,'scout_squad_route_disabled'end
 if type(proof)~='table'or proof.status~='AUTHORED_STATIC_SCOUT_VERIFIED'or proof.actor~=M.Actor or proof.feature~=M.Feature
  or proof.authoredStatic~=true or proof.sourceOwnedStandalone~=false or proof.sourceDeathClipAvailable~=false or proof.donor~=false
  or proof.initialScoutAction~='bolter_idle_1'or proof.heightBoundVerified~=true
  or proof.poseRecipeSHA256~='05de98bf4bdc63ee3099801313e19b6073e869b0f933f5710abcbfcf4c671c90'
  or proof.staticUnskinned~=true or proof.groundContactVerified~=true or proof.materialsMatchLive~=true then
  return false,'authored_static_scout_pose_closure_unready'
 end
 assert(type(owner)=='table'and owner.Version==1 and owner.Fraction==.25 and type(owner.Actors)=='table'
  and type(owner.Definition)=='function','Reviewed sole corpse owner required')
 assert(not owner.Actors[M.Actor],'Duplicate Scout corpse registration refused')
 assert(type(VFS)=='table'and type(VFS.FileExists)=='function','Exact private asset closure required')
 for _,path in ipairs({'objects3d/'..M.Feature..'.glb','unittextures/'..M.Feature..'_tex1.png','unittextures/'..M.Feature..'_tex2.png'})do
  if VFS.FileExists(path)~=true then return false,'genuine_private_scout_corpse_asset_missing'end
 end
 owner.Actors[M.Actor]={feature=M.Feature,name='Scout Marine'}
 return true,'registered_existing_single_entitlement_owner_only'
end
return M
