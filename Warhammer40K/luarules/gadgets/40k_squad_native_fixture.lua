function gadget:GetInfo()return{name='40K squad native diagnostic',desc='Default-off funded native queue and casualty repair scene',author='Local project',layer=150,enabled=true}end
if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(Spring.GetModOptions().prototype_squad_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local function done()Spring.SendCommands('quitforce')end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_squad_fixture_done',done)end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_squad_fixture_done')end
 return
end
local S=Spring;local phase=0;local begin=0;local factory,builder,seed,leader;local owned={};local before;local armoury,specialOld,expectedXP,target,targetHealth,fireMember,firstReload
local casualtyFeature,reclaimMetal
local function emit(s)S.Echo('40K_SQUAD_NATIVE '..s)end
local function finish(reason)
 if phase==9 then return end;phase=9
 emit('COMPLETE '..reason..' diagnostic=true ordinary_paid_acceptance=false')
 for _,id in ipairs(owned)do if S.ValidUnitID(id)and not S.GetUnitIsDead(id)then S.DestroyUnit(id,false,true)end end
 SendToUnsynced('fortyk_squad_fixture_done',reason)
end
local function create(name,x,z)
 local id=S.CreateUnit(name,x,S.GetGroundHeight(x,z),z,0,0);if id then owned[#owned+1]=id end;return id
end
function gadget:GameFrame(frame)
 if phase==9 then return end
 if frame>4500 then finish('FAIL timeout phase='..phase);return end
 if frame==90 then
  local d=UnitDefNames.imp_marine_barracks;local x,z
  for _,fraction in ipairs({.25,.35,.65,.75})do
   for _,f in ipairs({.25,.35,.65,.75})do local px,pz=Game.mapSizeX*fraction,Game.mapSizeZ*f
    local state,feature=S.TestBuildOrder(d.id,px,S.GetGroundHeight(px,pz),pz,0)
    if state and state>=2 and not feature then x,z=px,pz;break end
   end;if x then break end
  end
  if not x then finish('FAIL no_factory_site');return end
  factory=create('imp_marine_barracks',x,z);builder=create('imp_marine_builder',x+128,z+128)
  if not factory or not builder then finish('FAIL create');return end
  -- Explicit funded fixture, not an ordinary economy/balance acceptance game.
  S.SetTeamResource(0,'ms',100000);S.SetTeamResource(0,'es',100000)
  S.SetTeamResource(0,'m',50000);S.SetTeamResource(0,'e',50000)
  S.SetUnitBuildSpeed(factory,1000)
  before=S.GetTeamResources(0,'metal')
  S.GiveOrderToUnit(factory,-UnitDefNames.imp_marine.id,{},0);phase=1;begin=frame
  emit('QUEUE product=imp_marine capacity=4 native_factory=true fixture_speed=1000')
 end
 local R=GG.Recoil40KSquads;if not R then if frame==91 then finish('FAIL missing_owner')end;return end
 if phase==1 then
  for key,s in pairs(R.squads)do if s.team==0 and s.profile=='marine_tactical'then seed=key;leader=s.leader;break end end
  if seed then
   local members=R.Members(leader);if #members~=4 then finish('FAIL partial_birth');return end
   for _,id in ipairs(members)do owned[#owned+1]=id end
   local current=S.GetTeamResources(0,'metal');emit('DELIVERY members=4 metal_delta='..tostring(before-current)..' native_final_step=true')
   local x,y,z=S.GetUnitPosition(leader)
   S.GiveOrderToUnit(leader,CMD.FIRE_STATE,{0},0)
   S.GiveOrderToUnit(leader,CMD.PATROL,{x+240,y,z},0)
   for _,id in ipairs(members)do local q=S.GetUnitCommands(id,-1);if not q or #q==0 then finish('FAIL orders');return end end
   S.DestroyUnit(leader,false,false);local survivor=R.squads[seed]and R.squads[seed].leader
   if not survivor or #R.Members(survivor)~=3 then finish('FAIL leader_casualty');return end
   S.GiveOrderToUnit(survivor,CMD.STOP,{},0)
   S.GiveOrderToUnit(builder,CMD.REPAIR,{survivor},0)
   phase=2;begin=frame;emit('CASUALTY living=3 native_repair_order=true')
  elseif frame-begin>1800 then finish('FAIL queue_no_delivery')end
  if frame%300==0 then
   local building=S.GetUnitIsBuilding(factory);local q=S.GetFactoryCommands(factory,-1)or{};local progress=building and select(5,S.GetUnitHealth(building))or -1
   local C=GG.Recoil40KResearch;local allowed=C and C.CanBuild(0,UnitDefNames.imp_marine.id,factory,false)
   for _,id in ipairs(S.GetTeamUnits(0)or{})do if S.GetUnitRulesParam(id,'40k_squad_delivery_failed')==1 then finish('FAIL delivery_refused');return end end
   emit('QUEUE_STATE factory='..factory..' active='..tostring(S.GetUnitIsActive(factory))..' building='..tostring(building)..' progress='..tostring(progress)..' commands='..#q..' permitted='..tostring(allowed))
  end
 elseif phase==2 then
  local s=R.squads[seed];if not s then finish('FAIL lost_survivors');return end
  if not casualtyFeature then
   local found={}
   for _,fid in ipairs(S.GetAllFeatures())do if S.GetFeatureRulesParam(fid,'40k_remains_squad')==seed then found[#found+1]=fid end end
   if #found~=1 then finish('FAIL casualty_feature_count count='..#found);return end
   casualtyFeature=found[1];local m,dm,e,de,left,time=S.GetFeatureResources(casualtyFeature)
   if math.abs(m-12)>.001 or dm~=m or e~=0 or de~=0 or left~=1 or math.abs(time-125)>.001 or S.GetFeatureRulesParam(casualtyFeature,'40k_remains_generation')~=1 then finish('FAIL casualty_resources');return end
   emit('CORPSE single_native_feature=true body_metal=48 salvage_metal=12 energy=0 generation=1')
  end
  if #R.Members(s.leader)==4 then
   local restored=s.slots[1];if restored==leader then finish('FAIL reused_dead_body');return end
   owned[#owned+1]=restored;emit('RESTORE living=4 new_body=true work_paid=true')
   S.GiveOrderToUnit(builder,CMD.STOP,{},0) -- Stop the real repair before wounding.
   specialOld=s.slots[4];S.SetUnitExperience(specialOld,.25);expectedXP=S.GetUnitExperience(specialOld)
   local _,max=S.GetUnitHealth(specialOld);S.SetUnitHealth(specialOld,{health=max*.5})
   local x,y,z=S.GetUnitPosition(factory);local d=UnitDefNames.imp_marine_armoury
   for _,off in ipairs({{192,0},{0,192},{-192,0},{0,-192},{192,192},{-192,-192}})do
    local px,pz=x+off[1],z+off[2];local state,feature=S.TestBuildOrder(d.id,px,S.GetGroundHeight(px,pz),pz,0)
    if state and state>=2 and not feature then armoury=create('imp_marine_armoury',px,pz);if armoury then break end end
   end
   if not armoury then finish('FAIL armoury_site');return end
   local C=GG.Recoil40KResearch;local rec=C and C.records.marine_squad_heavy_bolter
   if not rec then finish('FAIL research_record');return end
   S.GiveOrderToUnit(armoury,rec.cmd,{},0);phase=3;begin=frame
   emit('RESEARCH_START metal=350 energy=1500 time=50 wounded_special=true')
  end
 elseif phase==3 then
  local s=R.squads[seed];if not s then finish('FAIL lost_squad_during_research');return end
  local member=s.slots[4]
  if S.GetTeamRulesParam(0,'40k_research_marine_squad_heavy_bolter')==1 and member==specialOld then
   -- Normal native regeneration during50s is legitimate. Wound immediately
   -- before the owner swaps the living role, rather than expecting it to persist.
   local _,max=S.GetUnitHealth(member);S.SetUnitHealth(member,{health=max*.5})
   return
  end
  if S.GetTeamRulesParam(0,'40k_research_marine_squad_heavy_bolter')==1 and member~=specialOld then
   if #R.Members(s.leader)~=4 or S.GetUnitDefID(member)~=UnitDefNames.imp_marine_heavy_member.id then finish('FAIL wrong_special_actor');return end
   local hp,max=S.GetUnitHealth(member);local xp=S.GetUnitExperience(member);local state=S.GetUnitStates(member)
   if math.abs(hp/max-.5)>.005 or math.abs(xp-expectedXP)>1e-4 or state.firestate~=0 then finish('FAIL upgraded_state_changed ratio='..tostring(hp/max)..' xp='..tostring(xp)..' expected_xp='..tostring(expectedXP)..' firestate='..tostring(state.firestate));return end
   owned[#owned+1]=member;emit('RESEARCH_COMPLETE genuine_heavy_actor=true wounded_fraction_preserved=true xp_preserved=true firestate_preserved=true')
   local x,y,z=S.GetUnitPosition(member)
   target=S.CreateUnit('imp_guardsman',x+120,S.GetGroundHeight(x+120,z),z,0,S.GetGaiaTeamID())
   if not target then finish('FAIL weapon_target');return end;owned[#owned+1]=target
   S.SetUnitMaxHealth(target,50000);S.SetUnitHealth(target,{health=50000});S.GiveOrderToUnit(target,CMD.FIRE_STATE,{0},0)
   targetHealth=S.GetUnitHealth(target);fireMember=member;firstReload=S.GetUnitWeaponState(member,1,'reloadState')or 0
   S.GiveOrderToUnit(s.leader,CMD.FIRE_STATE,{2},0);S.GiveOrderToUnit(s.leader,CMD.ATTACK,{target},0)
   phase=4;begin=frame
  elseif frame-begin>1800 then finish('FAIL research_timeout')end
 elseif phase==4 then
  local hp=S.GetUnitHealth(target);local reload=S.GetUnitWeaponState(fireMember,1,'reloadState')or 0
  if hp and hp<targetHealth and reload>firstReload then
   emit('WEAPON_FIRE heavy_reload_advanced=true target_damaged=true native_weapons=true')
   local s=R.squads[seed];local members=R.Members(s.leader);for _,id in ipairs(members)do S.DestroyUnit(id,false,false)end
   if R.squads[seed]then finish('FAIL wipe_identity_survived');return end
   emit('WIPE identity_removed=true')
   if not S.GetFeatureDefID(casualtyFeature)then finish('FAIL original_corpse_lost');return end
   reclaimMetal=S.GetTeamResources(0,'metal')
   S.GiveOrderToUnit(builder,CMD.RECLAIM,{Game.maxUnits+casualtyFeature},0)
   phase=5;begin=frame
  elseif frame-begin>450 then finish('FAIL heavy_weapon_no_fire')end
 elseif phase==5 then
  if not S.GetFeatureDefID(casualtyFeature)then
   local current=S.GetTeamResources(0,'metal')
   if current<reclaimMetal+12-.01 then finish('FAIL native_reclaim_no_credit');return end
   emit('RECLAIM native_builder=true feature_consumed=true metal_increased=true entitlement=12 income_in_delta=true')
   finish('PASS queue casualty repair research preserved_state native_fire wipe corpse native_reclaim')
  elseif frame-begin>450 then finish('FAIL native_reclaim_timeout')end
 end
end
