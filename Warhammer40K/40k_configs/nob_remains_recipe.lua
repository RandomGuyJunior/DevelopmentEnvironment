-- Coordinator-only candidate; missing/generated-unaccepted asset refuses activation.
local M={Actor='ork_nob',Feature='40k_nob_corpse',DefaultEnabled=false,GeometryFactor=1,SourceClip='die_1'}
function M.Register(owner,enabled)
 if enabled~=true then return nil end
 for _,path in ipairs({'objects3d/'..M.Feature..'.glb','unittextures/'..M.Feature..'_tex1.png','unittextures/'..M.Feature..'_tex2.png'})do assert(VFS and VFS.FileExists and VFS.FileExists(path),'Missing exported Nob remains closure '..path)end
 assert(owner.Fraction==.25 and type(owner.Definition)=='function','Existing sole corpse owner required')
 local row=owner.Actors[M.Actor]
 assert(not row or row.feature==M.Feature,'Conflicting Nob remains registration')
 owner.Actors[M.Actor]={feature=M.Feature,name='Nob'}
 return owner.Definition(M.Feature..'.glb',M.Actor)
end
return M
