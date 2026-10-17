-- Assembly hashes bytes; runtime checks recorded identities and VFS existence only.
-- Root passes VFS, ork_ranged_wrecks and included ignored closure facts.
-- Ready returns one callback for AttachLocalFeatures or nil plus exact refusal.
local M={ReceiptSHA256='620c1596570dabac7f68d8745fd4e1ed652fd0ecafc38ce9873a2c27eebb5636',Atlases={
 ork_kan_twin_shoota={'cd880e4101762a07158f1f9122f81f06fca3dd19ea0db4b06c8c29162a9636b9','9de5a42c872e604ed6e4b10a9c295608fdace62de18f5be6ebeab32969b6b9c3'},
 ork_kan_twin_kmb={'cd880e4101762a07158f1f9122f81f06fca3dd19ea0db4b06c8c29162a9636b9','9de5a42c872e604ed6e4b10a9c295608fdace62de18f5be6ebeab32969b6b9c3'},
 ork_kan_twin_rokkit={'cd880e4101762a07158f1f9122f81f06fca3dd19ea0db4b06c8c29162a9636b9','9de5a42c872e604ed6e4b10a9c295608fdace62de18f5be6ebeab32969b6b9c3'},
 ork_dread_ranged_fourarm={'5f45b6a7b716c6c506a240ec2e862b898c18c54e842660f23193ff98104fa50f','04208be7944001f96e923a14fbebb8f6844c5c3c51cc85e8401bce3ad7afd86c'},
}}
function M.Ready(V,W,facts)
 if not V or type(V.FileExists)~='function'or not W or not facts or facts.schema~=1
  or facts.receipt_sha256~=M.ReceiptSHA256 or facts.stage_sha256_verified~=true
  or facts.runtime_sha256_verified~=false or type(facts.rows)~='table'then return nil,'closure_facts_identity'end
 local ready={};local count=0;for _ in pairs(facts.rows)do count=count+1 end
 if count~=4 then return nil,'closure_row_count'end
 for _,key in ipairs(W.Keys)do
  local row=W.Rows[key];local f=facts.rows[key];local atlas=M.Atlases[key]
  if not f or not atlas or f.model~=row.model or f.sha256~=row.sha256 or type(f.dependencies)~='table'or #f.dependencies~=3 then return nil,'closure_row_'..key end
  local paths={'objects3d/'..row.model,'unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png'}
  local hashes={row.sha256,atlas[1],atlas[2]}
  for i,path in ipairs(paths)do
   local dep=f.dependencies[i]
   if type(dep)~='table'or dep.path~=path or dep.sha256~=hashes[i]or V.FileExists(path)~=true then return nil,'closure_dependency_'..key..'_'..i end
  end
  ready[row.model]=row.sha256
 end
 return function(model,sha)return ready[model]==sha and sha~=nil end,'assembly_sha256_record_plus_runtime_identity_existence'
end
return M
