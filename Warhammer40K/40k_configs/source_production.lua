-- Explicit source progression review. File presence is test exposure, never acceptance.
local M={}
local Development=VFS.Include('40k_configs/development_playtest.lua')
-- Root passes {Requires=M.SupplementalRequirements} to the common paid controller.
-- These keys remain actor identities, never aliases to unrelated buildings.
M.SupplementalRequirements={
 ork_big_mek_defence={buildings={'ork_settlement'},unit_limit=1},
 ork_flak_wartrak={buildings={'ork_mek_shop'},research={'ork_mek_technology'},tier=2},
 ork_rokkit_interceptor={buildings={'ork_mek_shop'},research={'ork_mek_technology'},tier=2},
 wh40k_armack={buildings={'imp_hq','imp_research'},research={'imperial_logistics'},tier=2},
 wh40k_armacv={buildings={'imp_hq','imp_research'},research={'imperial_logistics'},tier=2},
}
local function marker(key)return VFS.FileExists('40k_configs/validated/'..key..'.lua')end
function M.Enabled(opts)
 if not Development.OptionEnabled(opts.prototype_source_progression) then return false end
 local mode=opts.prototype_diagnostic
 return Development.Enabled(opts) or mode=='roster' or mode=='expandedproduction' or ((not mode or mode=='normal') and marker('source_progression'))
end
function M.BlockedAliases()
 local list={}
 for _,key in ipairs(VFS.Include('40k_configs/imperium_release_graph.lua').BlockedAliases)do list[#list+1]=key end
 -- Source BildaPit is research, never a donor walker production building.
 list[#list+1]='corvp';list[#list+1]='coravp'
 return list
end
function M.Apply(defs,opts,nativeOriginals)
 if not M.Enabled(opts) then return {enabled=false} end
 local mode=opts.prototype_diagnostic
 local review=mode=='roster' or mode=='expandedproduction'
 -- Legacy tank script selects the genuine baseline model without animsource.
 -- Supply only its exact exported identity; acceptance still uses the actor key.
 local russ=defs.imp_russ;local russCP=russ and russ.customparams
 if russCP and tostring(russCP.prototype40k)=='1' and russCP.faction=='Imperium'
  and russ.objectname=='leman_russ.glb' and russ.script=='40k_tank.lua'
  and not russCP.animsource and (review or marker('imp_russ') or Development.Allowed('imp_russ',opts))
  and VFS.FileExists('objects3d/leman_russ.glb')
  and VFS.FileExists('scripts/40k_tank.lua')
  and VFS.FileExists('scripts/generated/leman_russ_anim.lua')then russCP.animsource='leman_russ' end
 local function ready(key)
  local d=defs[key];local cp=d and d.customparams
  if not cp or tostring(cp.prototype40k)~='1' or not d.objectname or not cp.animsource then return false end
  if not VFS.FileExists('objects3d/'..d.objectname) or not VFS.FileExists('scripts/'..d.script)
   or not VFS.FileExists('scripts/generated/'..cp.animsource..'_anim.lua') then return false end
  return review or marker(key) or Development.Allowed(key,opts)
 end
 local imperial=VFS.Include('40k_configs/imperium_release_graph.lua')
 -- Historical generic aliases must not turn source research into jammers/storage.
 for _,key in ipairs(M.BlockedAliases()) do
  if nativeOriginals and nativeOriginals[key] then defs[key]=nativeOriginals[key] end
 end
 local necronReady={}
 for key,d in pairs(defs)do
  if ready(key)then
   necronReady[key]=true
   -- Commander identity remains in prototype40k_vital/iscommander. Keep the
   -- genuine actor's animation role; replacing builder/infantry with commander
   -- disables its whole-body gun aim in the shared source-pose runtime.
  end
 end
 local reports={imperial.Apply(defs,ready),VFS.Include('40k_configs/ork_release_graph.lua').Apply(defs,ready),VFS.Include('40k_configs/necron_release_graph.lua').Apply(defs,necronReady)}
 -- Final source menus replace earlier generic additions. Restore only explicit
 -- source producer relationships, not every historical alias or arbitrary menu.
 local restored={}
 local function append(parent,child)
  if not ready(parent)or not ready(child)or defs[parent].builder~=true then return end
  local menu=defs[parent].buildoptions or {};defs[parent].buildoptions=menu
  if M.SupplementalRequirements[child]then defs[child].customparams.prototype40k_tech_requires=child end
  for _,old in ipairs(menu)do if old==child then return end end
  menu[#menu+1]=child;restored[#restored+1]=parent..':'..child
 end
 -- Source Mek Shop spawns Wartrak; these mounted AA/interception variants are
 -- explicit native role adaptations of that actor. Source Boyz Hut spawns Mek
 -- Boy; Settlement does not, so the old settlement shortcut is not restored.
 append('ork_mek_shop','ork_flak_wartrak')
 append('ork_mek_shop','ork_rokkit_interceptor')
 append('ork_boyz_hut','ork_big_mek_defence')
 for _,child in ipairs({'wh40k_armack','wh40k_armacv'})do
  local d=defs[child];local cp=d and d.customparams or {}
  if d and d.builder==true and cp.faction=='Imperium' and cp.prototype40k_donor=='imp_enginseer'
   and cp.prototype40k_vital=='constructor' and ready('imp_enginseer')then
   append('imp_hq',child)
   local veteran=defs.wh40k_armalab;local vp=veteran and veteran.customparams or {}
   if vp.prototype40k_donor=='imp_barracks' and vp.prototype40k_vital=='barracks'then append('wh40k_armalab',child)end
  end
 end
 if ready('nec_lord') and ready('nec_nightbringer')then VFS.Include('40k_configs/necron_possession.lua').Configure(defs.nec_lord,defs.nec_nightbringer,true)end
 local count=0
 for key,d in pairs(defs)do
  if ready(key)then d.customparams.prototype40k_source_progression=1;count=count+1 end
 end
 return {enabled=true,review=review,development=Development.Enabled(opts),exposed=count,graphs=reports,restored_source_menus=restored}
end
return M
