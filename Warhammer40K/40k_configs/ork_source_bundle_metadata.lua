-- Explicit private bundle identity only; no costs, menus or mechanics changed.
local M={}
function M.Apply(defs,options)
 if not VFS.Include('40k_configs/ork_source_consumers_native.lua').Enabled(options)then return {marked=0}end
 local path='scripts/generated/ork_source_consumer_bundle_evidence.lua'
 if not VFS.FileExists(path)then return {marked=0,reason='private_genuine_bundle_evidence_missing'}end
 local e=VFS.Include(path);assert(e.version==1 and type(e.entries)=='table','Invalid private bundle identity')
 local n=0
 for key,row in pairs(e.entries)do
  local d=assert(defs[key],'Genuine reviewed native definition missing: '..key);local cp=assert(d.customparams,'Native source identity missing')
  assert(row.reviewed==true and cp.faction=='Orks'and tostring(cp.prototype40k)=='1','Only genuine Ork definitions')
  assert(d.objectname==row.asset..'.glb'and cp.animsource==row.asset,'Native bundle asset mismatch')
  assert(VFS.FileExists('objects3d/'..row.asset..'.glb')and VFS.FileExists('scripts/generated/'..row.asset..'_anim.lua'),'Native bundle files unavailable')
  assert(type(row.source_entity)=='string'and row.source_entity:match('^attrib/ebps/races/orks/.+%.lua$'),'Exact source entity required')
  assert(not cp.source_entity or cp.source_entity==row.source_entity,'Conflicting source entity')
  assert(type(row.source_model_sha256)=='string'and #row.source_model_sha256==64 and type(row.generated_glb_sha256)=='string'and #row.generated_glb_sha256==64,'Distinct original and converted hashes required')
  cp.source_entity=row.source_entity;cp.source_model_sha256=row.source_model_sha256;cp.source_native_glb_sha256=row.generated_glb_sha256;n=n+1
 end
 return {marked=n}
end
return M
