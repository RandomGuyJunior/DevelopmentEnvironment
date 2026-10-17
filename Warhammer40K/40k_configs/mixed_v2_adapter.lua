-- Exact diagnostic-only source graph adapter; never ordinary acceptance.
local M={}
function M.Enabled(options)
 return VFS.Include('40k_configs/mixed_v2.lua').Enabled(options)
  and VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression)
end
function M.Selected(options)
 if not M.Enabled(options)then return nil end
 return VFS.Include('40k_configs/mixed_v2.lua').Selected(options)
end
local function copy(value)
 if type(value)~='table'then return value end
 local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out
end
function M.Apply(defs,options)
 local selected=M.Selected(options)
 if not selected then return {enabled=false}end
 local staged,ready,blockers={},{},{}
 for name in pairs(selected)do
  local d=defs[name];local cp=d and d.customparams
  local identity=cp and cp.animsource
  -- The exporter identity is the exact actual GLB basename, never another actor.
  if not identity and d and type(d.objectname)=='string'then identity=d.objectname:match('^([^/\\]+)%.glb$')end
  if not d or not cp or tostring(cp.prototype40k)~='1' or not identity or not d.script
   or not VFS.FileExists('objects3d/'..d.objectname)
   or not VFS.FileExists('scripts/'..d.script)
   or not VFS.FileExists('scripts/generated/'..identity..'_anim.lua')then
   blockers[#blockers+1]=name..':missing_exact_definition_model_script_animation'
  else
   staged[name]=copy(d);staged[name].customparams.animsource=identity;ready[name]=true
  end
 end
 table.sort(blockers)
 if #blockers>0 then return {enabled=true,applied=false,blockers=blockers}end
 local imperial=VFS.Include('40k_configs/imperium_release_graph.lua')
 local reports={imperial.Apply(staged,function(name)return ready[name]==true end),
  VFS.Include('40k_configs/ork_release_graph.lua').Apply(staged,ready),
  VFS.Include('40k_configs/necron_release_graph.lua').Apply(staged,ready)}
 for _,team in ipairs(VFS.Include('40k_configs/mixed_v2.lua').teams)do
  local function edge(parent,child)
   for _,entry in ipairs(staged[parent].buildoptions or {})do if entry==child then return true end end
   return false
  end
  if not edge(team.factory,team.product)then blockers[#blockers+1]=team.factory..':missing_source_product_'..team.product end
  if not edge(team.builder,team.generator)then blockers[#blockers+1]=team.builder..':missing_source_generator_'..team.generator end
 end
 table.sort(blockers)
 if #blockers>0 then return {enabled=true,applied=false,blockers=blockers}end
 local count=0
 for name,d in pairs(staged)do
  d.customparams.prototype40k_source_progression=1
  d.customparams.prototype40k_mixed_v2_debug=1
  -- No acceptance marker/status or research/economy state is written.
  defs[name]=d;count=count+1
 end
 return {enabled=true,applied=true,exposed=count,graphs=reports,paidAcceptance=false,
  scope='exact diagnostic actor/producer graph only; real paid runtime still required'}
end
return M
