-- Optional participant: genuine HP02 weapon-choice consumer; no payment/stat duplication.
local M={Version=1}
local prefix='ork_pile_o_guns__'
local owned={ua_ork_research_bigshoota=true,ua_ork_research_tougherorks=true,ua_ork_kommandoz_squad=true,ua_ork_research_morechoppy=true,ua_ork_research_evenmorechoppy=true,ua_ork_research_powerclaw=true,ua_ork_research_tougher_bosses=true,ua_ork_research_tougher_bosses_2=true,ua_ork_research_tougher_bosses_3=true,ua_ork_research_grot_infiltrate=true,ua_ork_research_tank_busta_infiltrate=true,ua_ork_research_stikk_bombs=true,ua_ork_research_boomy_stikk_bombs=true,ua_ork_research_tankbustabombs=true}
local function copy(t)if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out end
local function near(a,b)return type(a)=='number'and a==a and math.abs(a-b)<=math.max(.0001,math.abs(b)*.000001)end
function M.New(C,S,D,W,F,Codec,armor)
 local R={};local manager
 local E=F.weaponSelectionEvidence
 if not E and VFS and VFS.FileExists('scripts/generated/ork_primary_weapon_selection_facts.lua')then E=VFS.Include('scripts/generated/ork_primary_weapon_selection_facts.lua')end
 local key=prefix..'ua_ork_research_evenmorechoppy';local fingerprint=F.profiles[key]and Codec.Encode(F.profiles[key]);local rule='40k_ork_hp02_source_selection_v1'
 local function actor(def)
  local d=D[def];local cp=d and d.customParams or{}
  return d and d.name=='ork_stormboy'and cp.source_entity=='attrib/ebps/races/orks/troops/ork_stormboy.lua'
   and cp.animsource=='ork_stormboy'and cp.faction=='Orks'and tostring(cp.prototype40k)=='1'
 end
 local function mount(def)
  if not actor(def)then return nil end
  local result
  for n,m in ipairs(D[def].weapons or{})do
   local w=W[m.weaponDef];local cp=w and w.customParams or{}
   local source=cp.source_weapon_profile or cp.source_weapon
   if source=='attrib/weapon/ork_choppa_boyz_stormboyz.lua'then
    if result or w.type~='Melee'or cp.source_muzzle~='marker_boyz_choppa_knife_blade'or cp.source_fireclip~='melee'then return nil end
    result=n
   end
  end
  return result
 end
 function R.Owns(k)return type(k)=='string'and k:sub(1,#prefix)==prefix and owned[k:sub(#prefix+1)]==true end
 function R.Supported(k,p)
  if not R.Owns(k)then return false,'outside_extra_consumer_scope'end
  if k~=key then return false,'whole_extra_consumer_pending:'..k end
  if not E or E.version~=1 or E.actor_sha256~='fc8a7d692d13a5ec3ccf8d06637ef1b7574150aee8b229e5e5e6727fd44badfa'
   or E.native_ap_morale_policy~='qualified_existing_categories_uniform_mean_no_morale_v1'or type(E.differing_source_fields)~='table'
   or E.native_adaptation~='existing_uniform_source_mean_melee45_v1'or E.visibility_equivalent~=true
   or E.muzzle_equivalent~=true or E.genuine_marker~=true or E.genuine_melee_clip~=true then return false,'genuine_weapon_selection_evidence_missing'end
  if not p or p.sha256~=E.research_sha256 or not F.profiles[k]or Codec.Encode(p)~=fingerprint or Codec.Encode(F.profiles[k])~=fingerprint then return false,'source_selection_profile_changed'end
  local choices=0
  for _,e in ipairs(p.effects)do
   if e.exclusive or e.probability~=1 or type(e.usage_type)~='string'then return false,'source_selection_modifier_semantics'end
   if e.type=='default_weapon_modifier_hardpoint2'then
    if e.target~='ork_stormboy'or e.value~=1 or e.probability~=1 or e.exclusive or not e.usage_type:find('addition',1,true)then return false,'unsupported_source_selection_row'end
    choices=choices+1
   elseif e.type~='min_damage_weapon_modifier'and e.type~='max_damage_weapon_modifier'then return false,'whole_selection_effect_unresolved:'..e.type
   elseif not F.weapons[e.target]or type(e.value)~='number'or e.value<0 or e.value~=e.value or e.value>=math.huge or not(e.usage_type:find('addition',1,true)or e.usage_type:find('multiplication',1,true)or e.usage_type:find('percentage',1,true))then return false,'source_selection_damage_semantics'end
  end
  if choices~=1 then return false,'source_selection_count'end
  for _,stem in ipairs({'ork_choppa_boyz_stormboyz','ork_choppa_stormboyz_big'})do
   local f=F.weapons[stem];local e=E.weapons[stem]
   if not f or not e or f.sha256~=e.sha256 or f.minimum~=e.minimum or f.maximum~=e.maximum or e.reload~=1 or e.accuracy~=1 then return false,'source_selection_weapon_changed'end
  end
  if not(S.GetUnitWeaponDamages and S.SetUnitWeaponDamages and S.GetUnitWeaponState and S.SetUnitWeaponState and S.GetUnitRulesParam and S.SetUnitRulesParam)then return false,'native_weapon_selection_API_required'end
  local found=false;for def in pairs(D)do if actor(def)then if not mount(def)then return false,'actual_native_melee_mount_missing'end;found=true end end
  if not found then return false,'actual_genuine_stormboy_definition_missing'end;return true
 end
 local function enabled(team,prospective)
  return prospective and prospective.key==key and prospective.team==team or C.HasResearch(team,key)and manager and manager.IsApplied(team,key)==true
 end
 function R.SelectionPlan(id,b,team,prospective,birth,plan)
  if not actor(b.def)then return plan end
  local active=enabled(team,prospective)
  local okay,why=R.Supported(key,F.profiles[key]);if not okay then if active then return nil,why else return plan end end
  local n=mount(b.def);if not n then return nil,'actual_source_choice_mount_missing'end
  local w=plan.weapons[n];local baseline=F.weapons.ork_choppa_boyz_stormboyz;local mean=(baseline.minimum+baseline.maximum)/2
  if not w or w.source~='ork_choppa_boyz_stormboyz'or not near(w.range,45)then return nil,'source_choice_native_baseline_changed'end
  for _,damage in pairs(w.damages)do if not near(damage,mean)then return nil,'uniform_native_source_mean_baseline_required'end end
  local choice=active and 2 or 1
  if choice==2 then
   local f=F.weapons.ork_choppa_stormboyz_big;w.source='ork_choppa_stormboyz_big';w.range=45
   for a in pairs(w.damages)do w.damages[a]=(f.minimum+f.maximum)/2 end
  end
  plan.extra={version=M.Version,def=b.def,team=team,mount=n,choice=choice,source=w.source,research=key,research_sha256=E.research_sha256,actor_sha256=E.actor_sha256,model_sha256=E.model_sha256,anim_sha256=E.anim_sha256}
  return plan
 end
 function R.ModifyPlan(id,b,team,prospective,birth,out)return out end
 function R.Snapshot(id)return {saved=S.GetUnitRulesParam(id,rule),def=S.GetUnitDefID(id),team=S.GetUnitTeam(id)}end
 function R.ApplyPlan(id,plan)
  local p=plan;if not p then return true end;if not E then return false,'genuine_weapon_selection_evidence_missing'end
  if p.choice~=1 and p.choice~=2 or p.source~=(p.choice==2 and 'ork_choppa_stormboyz_big'or 'ork_choppa_boyz_stormboyz')or p.actor_sha256~=E.actor_sha256 or p.model_sha256~=E.model_sha256 or p.anim_sha256~=E.anim_sha256 or p.research_sha256~=E.research_sha256 then return false,'selection_plan_changed'end
  if p.version~=M.Version or S.GetUnitDefID(id)~=p.def or S.GetUnitTeam(id)~=p.team or not actor(p.def)or mount(p.def)~=p.mount then return false,'selection_actor_changed'end
  local encoded=Codec.Encode(p);S.SetUnitRulesParam(id,rule,encoded,{private=true})
  return S.GetUnitRulesParam(id,rule)==encoded,'selection_receipt_readback'
 end
 function R.Restore(id,snapshot)
  if not snapshot or S.GetUnitDefID(id)~=snapshot.def or S.GetUnitTeam(id)~=snapshot.team then return false,'selection_snapshot_actor_changed'end
  S.SetUnitRulesParam(id,rule,snapshot.saved,{private=true});return S.GetUnitRulesParam(id,rule)==snapshot.saved,'selection_rollback_readback'
 end
 function R.Bind(m)manager=m end
 return R
end
return M
