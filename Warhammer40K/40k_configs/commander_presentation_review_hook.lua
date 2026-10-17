-- Explicit startup-only commander review. No runtime callbacks or payment changes.
local M={}
local function on(v)return v==true or v==1 or v=='1'or v=='true'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local bankFacts={}
local specs={
 bigmek={faction='Orks',key='ork_big_mek_commander',donor='ork_big_mek_defence',asset='ork_big_mek_defence',clips={idle='idle_1',walk='run_1',build='choppa_repair',fire='fire',melee='melee_1'},markers={'marker_big_mek_axe_blade','marker_big_mek_slugga_barrel','marker_big_mek_trans_mid'}},
 force={faction='Imperium',key='imp_field_commander',donor='imp_force_commander_candidate',asset='imp_force_commander_candidate',clips={idle='idle_1',walk='run_1',command_build='idle_1',fire='fire',melee='power_sword_melee_1'},markers={'bip01 l hand','marker_marine_boltpistol_barrel','marker_marine_power_sword_blade'}},
}
local function facts(V,s)
 local path='scripts/generated/'..s.asset..'_anim.lua'
 for _,p in ipairs({'objects3d/'..s.asset..'.glb','unittextures/'..s.asset..'_tex1.png','unittextures/'..s.asset..'_tex2.png',path,'unitpics/40k_'..s.asset..'.png','scripts/40k_roster.lua'})do
  if not V.FileExists(p)then return nil,'missing_asset:'..p end
 end
 if not bankFacts[path]then
  -- Frozen archives bind this small generated summary to the exact immutable
  -- banks in the freezer. An unstaged development tree retains legacy checks.
  local metadataPath='scripts/generated/commander_startup_facts.lua'
  local metadata=V.FileExists(metadataPath)
  local ok,data=pcall(V.Include,metadata and metadataPath or path)
  if not ok or type(data)~='table'then return nil,'bank_load_refused:'..path end
  if metadata then
   if data.schema~=1 or type(data.actors)~='table'then return nil,'invalid_bank_facts'end
   data=data.actors[s.asset]
   if type(data)~='table'or data.bankPath~=path or type(data.bankSha256)~='string'
    or #data.bankSha256~=64 or not data.bankSha256:match('^[0-9a-f]+$')
    or not finite(data.bankBytes)or data.bankBytes<=0 or data.bankBytes~=math.floor(data.bankBytes)
    or type(data.bones)~='table'or type(data.clips)~='table'then return nil,'invalid_bank_facts'end
  end
  local f={bones={},clips={},clipCount=0}
  for _,n in ipairs(data.bones or{})do if type(n)~='string'or f.bones[n]then return nil,'invalid_bone_map'end;f.bones[n]=true end
  for label,c in pairs(data.clips or{})do
   if type(c)~='table'or type(c.source)~='string'or not finite(c.duration)or c.duration<=0 then return nil,'invalid_source_clip'end
   if metadata then
    if not finite(c.frameCount)or c.frameCount<=0 or c.frameCount~=math.floor(c.frameCount)then return nil,'invalid_source_clip'end
   elseif type(c.frames)~='table'or #c.frames==0 then return nil,'invalid_source_clip'end
   f.clips[label]=c.source;f.clipCount=f.clipCount+1
  end
  if metadata and data.clipCount~=f.clipCount then return nil,'invalid_bank_facts'end
  bankFacts[path]=f -- Small immutable facts only; source frames never change.
 end
 local f=bankFacts[path]
 for _,n in ipairs(s.markers)do if not f.bones[n]then return nil,'missing_source_marker:'..n end end
 for label,source in pairs(s.clips)do if f.clips[label]~=source then return nil,'wrong_source_clip:'..label end end
 if s.asset=='imp_force_commander_candidate'and f.clipCount~=77 then return nil,'whole_force_bank_required'end
 return f
end
function M.Apply(defs,opts,V)
 opts=opts or{}
 if not on(opts.prototype_commander_presentation_review)then return{applied=true,enabled=false,reason='inactive'}end
 local mode=opts.prototype_commander_presentation_mode
 if mode~='bigmek'and mode~='force'and mode~='both'then return{applied=false,enabled=true,reason='explicit_mode_required'}end
 if type(V)~='table'or type(V.Include)~='function'or type(V.FileExists)~='function'then return{applied=false,enabled=true,reason='missing_source_reader'}end
 for _,d in pairs(defs)do for _,name in ipairs(d.buildoptions or{})do if name=='imp_force_commander_candidate'then return{applied=false,enabled=true,reason='candidate_must_not_be_recruited'}end end end
 local selected=mode=='both'and{'bigmek','force'}or{mode};local working={};for k,d in pairs(defs)do working[k]=d end
 local ready,factions={},{}
 for _,which in ipairs(selected)do
  local s=specs[which];local original=defs[s.key]
  if not original or original.builder~=true or not finite(original.workertime)or original.workertime<=0 or type(original.buildoptions)~='table'or #original.buildoptions==0 then return{applied=false,enabled=true,reason='stable_paid_builder_missing:'..s.key}end
  local f,why=facts(V,s);if not f then return{applied=false,enabled=true,reason=why}end
  if which=='force'then
   local ok,constructor=pcall(V.Include,'40k_configs/commander_source_definitions_candidate.lua');if not ok or type(constructor)~='table'or type(constructor.ForceCommander)~='function'then return{applied=false,enabled=true,reason='missing_force_constructor'}end
   local built,d=pcall(constructor.ForceCommander,V,true);if not built or type(d)~='table'or type(d.customparams)~='table'then return{applied=false,enabled=true,reason='force_constructor_refused'}end
   if d.customparams.source_whm_sha256~='bae55403be5bca7161afd12ee3096f28a2a28d93fc62e0fbbe4890a402e51e21'or d.customparams.source_glb_sha256~='47df0f59cc4b0e21401ff54e9307fa21c1930db37791c227b75b625af7cecb62'then return{applied=false,enabled=true,reason='force_source_pins_changed'}end
   working[s.donor]=d
  end
  local d=working[s.donor];local cp=d and d.customparams or{}
  if not d or cp.faction~=s.faction or cp.animsource~=s.asset or tostring(cp.prototype40k)~='1'or d.objectname~=s.asset..'.glb'or d.script~='40k_roster.lua'then return{applied=false,enabled=true,reason='wrong_exact_source_donor'}end
  if which=='bigmek'then
   local shields=0
   for _,w in pairs(d.weapondefs or{})do if w.weapontype=='Shield'then
    local q=w.shield or{};if not finite(q.power)or q.power<=0 or not finite(q.radius)or q.radius<=0 or not finite(q.powerregenenergy)or q.powerregenenergy<=0 then return{applied=false,enabled=true,reason='native_paid_shield_missing'}end
    shields=shields+1
   end end
   if shields~=1 then return{applied=false,enabled=true,reason='exact_one_native_shield_required'}end
  end
  ready[s.donor]=true;factions[s.faction]=true
 end
 local ok,presentation=pcall(V.Include,'40k_configs/commander_presentation_candidate.lua');if not ok or type(presentation)~='table'or type(presentation.Apply)~='function'then return{applied=false,enabled=true,reason='missing_presentation_adapter'}end
 local called,applied,why=pcall(presentation.Apply,working,{enabled=true,factions=factions,Ready=function(name)return ready[name]==true end})
 if not called then return{applied=false,enabled=true,reason='presentation_adapter_refused'}end
 if not applied then return{applied=false,enabled=true,reason=why}end
 for _,which in ipairs(selected)do local s=specs[which];local d=working[s.key];d.customparams.commander_presentation_review_mode=mode;defs[s.key]=d end
 if factions.Imperium then defs.imp_force_commander_candidate=working.imp_force_commander_candidate end
 return{applied=true,enabled=true,mode=mode,nativeAccepted=false,sourceFactsChecked=true}
end
return M
