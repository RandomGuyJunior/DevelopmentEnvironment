-- The generic mixed-faction low-detail asset is an explicit integration input.
-- Do not replace this closure with a detailed corpse or a placeholder object.
local path='40k_configs/corpse_pile_asset_closure.lua'
if not VFS.FileExists(path)then return{}end
local c=VFS.Include(path)
if c.enabled~=true then return{}end
assert(c.schema==1 and c.mixedFactions==true and c.renderApproved==true
 and type(c.vertexCount)=='number'and c.vertexCount>0 and c.vertexCount<=4096,
 'Reviewed low-detail mixed-faction pile geometry required')
assert(type(c.model)=='string'and c.model:match('%.glb$')and not c.model:find('..',1,true)
 and VFS.FileExists('objects3d/'..c.model),'Pile model unavailable')
assert(type(c.files)=='table'and #c.files>=1 and #c.files<=8,'Bounded pile asset closure required')
for _,file in ipairs(c.files)do assert(VFS.FileExists(file),'Missing pile dependency '..file)end
local M=VFS.Include('40k_configs/corpse_pile_aggregation.lua')
return{[M.Feature]=M.Definition(c.model)}
