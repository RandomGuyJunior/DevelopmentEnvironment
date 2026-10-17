-- Four exact original BAR visual comparisons. No normal actor or production.
local M={Version=3}
M.Keys={'corsolar','corfus','corafus','corgeo'}
M.Models={corsolar='d56dfe075901356c9a9617244fe43b312b5550616d526144f87f83c826713358',corfus='1e2ff199716edcb995847825469c328efd605f44e69f1a975b96b441a809e487',corafus='12a82066470268188a3d9656bea77d2a09ff6ff7ef51d0b7e013de7c3627a9d9',corgeo='977575fbfcd9e045abab3ddd6187ed368226aecdacb42ec17fca525738880bc7'}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(o)if o and yes(o.prototype_human_inspection_scene)then return false end;return o and(yes(o.prototype_generator_native_fixture)or yes(o.prototype_source_bounds_capture))or false end
local function clone(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r end
function M.Apply(D,V,o,ready)
 local report={registered={}}
 if not M.Enabled(o)then return report end
 assert(type(ready)=='table','Explicit original generator reference closure required')
 local count=0;for _ in pairs(ready)do count=count+1 end;assert(count==4,'Exact four original generator references required')
 local pending={}
 for _,key in ipairs(M.Keys)do
  local r=assert(ready[key],'Original generator class reference absent');local alias='40k_generator_ref_'..key
  assert(r.originalKey==key and r.alias==alias and r.modelSHA256==M.Models[key]and r.nativeAccepted==false,'Original reference identity mismatch')
  assert(not D[alias],'Original diagnostic alias collision')
  local d=clone(assert(r.definition,'Original reference definition absent'));local cp=d.customparams or{}
  assert(d.objectname==alias..'.s3o'and d.script==alias..(key=='corgeo'and'.lua'or'.cob'),'Original diagnostic model/script alias mismatch')
  assert(cp.prototype40k_original_generator_reference==key and cp.original_bar_model_sha256==r.modelSHA256 and cp.original_bar_script_sha256==r.scriptSHA256,'Exact original source marker required')
  assert(not cp.prototype40k and not cp.animsource and not d.builder and not d.canmove and not d.canattack and not d.weapons and not d.buildoptions,'Visual reference cannot acquire faction production/combat roles')
  assert(cp.diagnostic_only==1 and d.name==r.label and type(r.bind_bounds)=='table'and type(r.native_bind_midpoint)=='table','Original class labelled bounds contract required')
  for _,path in ipairs(r.requiredFiles)do assert(V.FileExists(path),'Original reference dependency absent: '..path)end
  -- These aliases are appended after the stock normalizer. Its ordinary
  -- unitDefs loader tail unconditionally ipairs(buildoptions), and later
  -- weapon parsers expect normalized empty tables. Empty tables grant no role.
  d.buildoptions={};d.weapondefs={};d.weapons={}
  -- Native UnitDef canAttack defaults true even for unarmed buildings.
  -- These reference actors are explicitly noncombat/mobile/builder roles.
  d.builder=false;d.canmove=false;d.canattack=false
  pending[alias]=d
 end
 -- Validate the entire closure/collision set before creating any alias.
 for alias,d in pairs(pending)do D[alias]=d;report.registered[#report.registered+1]=alias end
 table.sort(report.registered);return report
end
return M
