function gadget:GetInfo()
 return {name='40K source Necron acceptance fixture',desc='Native paid source progression and possession journal',author='Local project',layer=110,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
local opts=Spring.GetModOptions() or {}
if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression) or opts.prototype_source_acceptance~='necrons' or opts.prototype_diagnostic~='expandedproduction' then return false end
local possession=VFS.Include('40k_configs/necron_possession.lua')
local nightConfig=VFS.Include('40k_configs/necron_night_ability.lua')
local relicConfig=VFS.Include('40k_configs/necron_relic_capture.lua')
local abilityProofConfig=VFS.Include('40k_configs/necron_ability_acceptance.lua')
local abilityProof,abilityDeadline,abilityRecharge,scarab,relic,abilityAttacked
local abilityIncomingCount=0
local leechAccounting=VFS.Include('40k_configs/40k_leech_accounting.lua')
local experienceRules=VFS.Include('40k_configs/40k_experience_policy.lua').Read()
assert(experienceRules and type(experienceRules.healthScale)=='number'and experienceRules.healthScale>=0,'Actual experience health policy required')
local leechObserver
local fps=Game.gameSpeed or 30
local state='waiting';local team,lord,enemy,base,start,entered
local current,index,created,paid={},1,{},{}
local sites,mexes={},{}
local beforeHits,healing={},{}
local incomingHits={};local incomingJournalCount=0;local incomingJournalTruncated=false


local rangedHit,meleeHit,leechProof=false,false,false
local origin,form,formsSeen= nil,nil,0
local regenJournalCount=0;local regenFailure
local function regenJournal(id,frame,hp,max,xp,after,newMax,newXP,requested,rate)
 if id~=form then return end
 if abilityProof then local ok,reason=abilityProof.Regenerated(frame,hp,max,xp,after,newMax,newXP,requested);if not ok then regenFailure=reason end end
 if not leechObserver then return end
 local okay,delta,pending=leechObserver.Regenerated(frame,hp,max,xp,after,newMax,newXP,requested)
 if regenJournalCount<32 then
  Spring.Echo('40K SOURCE NECRON ACTUAL REGEN',frame,id,okay,delta,pending or 'none','requested',requested,'rate',rate,'before',hp,'after',after,'max',max,'xp',xp)
  regenJournalCount=regenJournalCount+1
 elseif regenJournalCount==32 then Spring.Echo('40K SOURCE NECRON ACTUAL REGEN TRUNCATED',frame);regenJournalCount=33 end
 if not okay then regenFailure=tostring(delta)end
end
GG.Recoil40KNightRegenObserver=regenJournal
local cooldownAttempt,cooldownReceipt,cooldownDeadline,retryLord
local steps={
 {kind='build',name='nec_mex'},{kind='build',name='nec_mex'},
 {kind='build',name='nec_hq'},
 {kind='build',name='nec_generator'},{kind='build',name='nec_generator'},
 {kind='build',name='nec_generator'},{kind='build',name='nec_generator'},
 {kind='build',name='nec_core'},
 {kind='research',name='nec_awakening_1',producer='nec_hq'},
 {kind='build',name='nec_greater_core'},
 {kind='research',name='nec_awakening_2',producer='nec_hq'},
 {kind='build',name='nec_ancient_core'},{kind='build',name='nec_archive'},
 {kind='research',name='nec_ctan_manifestation',producer='nec_archive'},
 {kind='factory',name='nec_scarab',producer='nec_hq'},
 {kind='capture',name='40k_relic_objective'},
 {kind='research',name=nightConfig.ResearchKey,producer='nec_archive'}}
local function journal(...)Spring.Echo('40K SOURCE NECRON ACCEPTANCE',Spring.GetGameFrame(),...)end
local issuing=0
local outsideOrders=0
local function giveOrder(...)
 issuing=issuing+1
 local ok,result=pcall(Spring.GiveOrderToUnit,...)
 issuing=issuing-1
 if not ok then error(result,0)end
 return result
end
-- Native signature includes playerID before origin flags. No commands are blocked.
function gadget:UnitCommand(id,def,t,cmd,params,options,tag,playerID,fromSynced,fromLua)
 if state=='done' or not team or t~=team or issuing>0 then return end
 outsideOrders=outsideOrders+1
 if outsideOrders<=128 then
  journal('OUTSIDE_FIXTURE_ORDER',id,UnitDefs[def].name,'command',cmd,'tag',tag,
   'player',playerID,'fromSynced',fromSynced,'fromLua',fromLua)
 elseif outsideOrders==129 then journal('OUTSIDE_ORDER_JOURNAL_LIMIT',128)end
end

local function alive(id)return id and Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id)end
local function finish(ok,reason)
 if state=='done'then return end;state='done'
 Spring.SetGameRulesParam('40k_source_necron_acceptance_result',ok and 1 or -1)
 journal(ok and 'PASS' or 'FAIL',reason,'steps',index-1,'forms',formsSeen,'ranged',rangedHit,'melee',meleeHit,'leech',leechProof)
end
local function phase(nextState)state=nextState;entered=Spring.GetGameFrame();journal('STATE',state)end
local function nonCooldownReady(p)
 return p and p.valid==true and p.pending==false and p.form==false and p.validLord==true and p.ready==true
  and p.research==true and p.archive==true and p.cap==true and p.clear==true
end
local function possessionReview()
 local review=GG.Recoil40KNecronAcceptance
 if review and type(review.Prerequisites)=='function'and type(review.LastRequest)=='function'then return review end
end
local function cooldownRule()
 if Spring.GetUnitRulesParam(lord,'40k_nec_save_kind')~='cooldown'then return end
 return Spring.GetUnitRulesParam(lord,'40k_nec_save_cooldown')
end
local function units(teamID)
 local list=Spring.GetTeamUnits(teamID) or {};table.sort(list);return list
end
local function find(name)
 local d=UnitDefNames[name];if not d then return end
 for _,u in ipairs(units(team))do if Spring.GetUnitDefID(u)==d.id then local hp,_,_,_,p=Spring.GetUnitHealth(u);if hp and hp>0 and p==1 then return u end end end
end
local function resources(label)
 for _,r in ipairs({'metal','energy'})do local c,s,p,i,e=Spring.GetTeamResources(team,r);journal(label,r,c,s,p,i,e)end
end
local function option(builder,name)
 local d=UnitDefNames[name];if not d then return end
 for _,def in ipairs(UnitDefs[Spring.GetUnitDefID(builder)].buildOptions or {})do if def==d.id then return d.id end end
end
local function site(def,metal)
 local candidates={}
 if metal then
  for x=math.max(96,base[1]-1200),math.min(Game.mapSizeX-96,base[1]+1200),32 do
   for z=math.max(96,base[3]-1200),math.min(Game.mapSizeZ-96,base[3]+1200),32 do
    if (select(3,Spring.GetGroundInfo(x,z)) or 0)>0 then candidates[#candidates+1]={x,z,(x-base[1])^2+(z-base[3])^2}end
   end
  end
  table.sort(candidates,function(a,b)if a[3]~=b[3]then return a[3]<b[3]end;if a[1]~=b[1]then return a[1]<b[1]end;return a[2]<b[2]end)
 else
  for ring=4,25 do for step=0,15 do local a=step*math.pi/8;candidates[#candidates+1]={base[1]+ring*32*math.cos(a),base[3]+ring*32*math.sin(a)}end end
 end
 for _,p in ipairs(candidates)do
  local x=math.floor(p[1]/16)*16+8;local z=math.floor(p[2]/16)*16+8;local y=Spring.GetGroundHeight(x,z);local clear=y>0 and x>96 and z>96 and x<Game.mapSizeX-96 and z<Game.mapSizeZ-96
  for _,old in ipairs(sites)do if (x-old[1])^2+(z-old[3])^2<160^2 then clear=false end end
  if metal then for _,old in ipairs(mexes)do if (x-old[1])^2+(z-old[3])^2<180^2 then clear=false end end end
  if clear and Spring.TestBuildOrder(def,x,y,z,0)==2 and (not metal or (select(3,Spring.GetGroundInfo(x,z)) or 0)>0)then
   local found={x,y,z,0};sites[#sites+1]=found;if metal then mexes[#mexes+1]=found end;return found
  end
 end
end
local function nextStep(frame)
 local row=steps[index]
 if not row then resources('ECONOMY_AFTER');phase('approach');return end
 resources('BEFORE_'..row.name);current={row=row,start=frame}
 if row.kind=='capture'then
  local capture=GG.Recoil40KRelicCapture;local objective=UnitDefNames['40k_relic_objective'];scarab=find('nec_scarab')
  if not capture or not objective or not scarab or capture.Owned(team)then finish(false,'missing_or_preowned_genuine_relic_capture');return end
  local all=Spring.GetAllUnits()or{};local gaia=Spring.GetGaiaTeamID();local matched=0
  for _,id in ipairs(all)do
   if Spring.GetUnitDefID(id)==objective.id then
    matched=matched+1;journal('RELIC_LOOKUP_CANDIDATE',id,objective.id,Spring.GetUnitTeam(id),gaia,Spring.GetUnitRulesParam(id,'40k_relic_owner'),Spring.GetUnitRulesParam(id,'40k_relic_reviewed'))
    if Spring.GetUnitTeam(id)==gaia and not relic then relic=id end
   end
  end
  journal('RELIC_LOOKUP',objective.id,gaia,#all,matched,relic or -1)
  if type(capture.ObjectiveWitness)=='function'then for _,row in ipairs(capture.ObjectiveWitness())do
   journal('RELIC_LOOKUP_LIFECYCLE',row.frame,row.event,row.id,row.def,row.team,row.hp or 'nil',row.built or 'nil',row.extra or 'none')
  end end
  if not relic then finish(false,'genuine_neutral_relic_not_placed');return end
  journal('REAL_RELIC_CAPTURE_ORDER',scarab,relic,relicConfig.Command,'seconds',61.5);giveOrder(scarab,relicConfig.Command,{relic},{})
 elseif row.kind=='factory'then
  local producer=find(row.producer);local d=producer and option(producer,row.name)
  if not producer or not d or find(row.name)then finish(false,'missing_or_prebuilt_scarab_factory_product');return end
  current.producer=producer;current.builder=producer;current.def=d
  local def=UnitDefs[d];if def.metalCost<=0 or def.energyCost<=0 or def.buildTime<=0 then finish(false,'scarab_native_price_missing');return end
  journal('PAID_FACTORY_ORDER',producer,row.name,d,def.metalCost,def.energyCost,def.buildTime);giveOrder(producer,-d,{},{})
 elseif row.kind=='build'then
  local d=option(lord,row.name);if not d then finish(false,'missing_native_build_menu_'..row.name);return end
  local p=site(d,row.name=='nec_mex');if not p then finish(false,'no_real_build_site_'..row.name);return end
  current.def=d;current.position=p
  journal('BUILD_ORDER',row.name,lord,d,p[1],p[3],UnitDefs[d].metalCost,UnitDefs[d].energyCost,UnitDefs[d].buildTime)
  giveOrder(lord,-d,p,{})
 else
  local research=GG.Recoil40KResearch;local record=research and research.records[row.name];local producer=find(row.producer)
  if not record or not producer then finish(false,'missing_paid_research_producer_'..row.name);return end
  if research.HasResearch(team,row.name)then finish(false,'research_precompleted_without_fixture_payment_'..row.name);return end
  current.producer=producer;current.record=record
  journal('RESEARCH_ORDER',row.name,producer,record.cmd,record.row.cost.metal or 0,record.row.cost.energy or 0,record.frames)
  giveOrder(producer,record.cmd,{},{})
 end
end
local function initialize(frame)
 local list=Spring.GetAllUnits() or {};table.sort(list)
 for _,u in ipairs(list)do if UnitDefs[Spring.GetUnitDefID(u)].name=='nec_lord' then lord=u;team=Spring.GetUnitTeam(u);break end end
 if not lord then if frame>fps*60 then finish(false,'no_native_starting_lord')end;return end
 if #units(team)~=1 then finish(false,'unexpected_units_at_normal_start');return end
 local x,y,z=Spring.GetUnitPosition(lord);base={x,y,z};start=frame
 for _,u in ipairs(list)do if not Spring.AreTeamsAllied(team,Spring.GetUnitTeam(u))then
  local d=UnitDefs[Spring.GetUnitDefID(u)];local cp=d.customParams or {}
  if cp.iscommander or cp.commander or d.isBuilder then enemy=u;break end
 end end
 if not enemy or not GG.Recoil40KResearch then finish(false,'missing_native_hostile_actor_or_paid_controller');return end
 giveOrder(enemy,CMD.FIRE_STATE,{0},{})
 giveOrder(lord,CMD.FIRE_STATE,{0},{})
 journal('NORMAL_START',lord,team,enemy);resources('ECONOMY_BEFORE');phase('progression');nextStep(frame)
end
function gadget:UnitCreated(id,def,t,builder)
 if state=='done' or not team or t~=team then return end
 local transform=GG.Prototype40kTransform
 if transform and transform.kind=='necron_possession' and transform.from==lord and def==UnitDefNames.nec_nightbringer.id then
  local hp,max=Spring.GetUnitHealth(lord);if origin and hp and max then origin.transferredFraction=hp/max end
  created[id]={builder=transform.from,kind='possession'};formsSeen=formsSeen+1;form=id;journal('FORM_CREATED',lord,id,t);return
 end
 if transform and transform.kind=='necron_possession' and transform.from==form and def==UnitDefNames.nec_lord.id then
  created[id]={builder=transform.from,kind='reversal'};lord=id;journal('LORD_RECREATED',form,id,t);return
 end
 if state=='progression' and current.def==def and builder==(current.builder or lord)then
  if current.row.kind=='factory'then
   local row=(Spring.GetFactoryCommands(builder,-1)or{})[1]
   if not row or row.id~=-def or not row.tag then finish(false,'actual_scarab_factory_queue_head_missing');return end
   current.factoryTag=row.tag;journal('SCARAB_NATIVE_FACTORY_HEAD',builder,row.id,row.tag)
  end
  created[id]={builder=builder,kind='paid_native_build'};current.unit=id;journal('PAID_BUILD_CREATED',UnitDefs[def].name,id,builder,t);return
 end
 -- Preserve the strict provenance failure, with its actual native producer.
 local producerName,cmd='absent',nil
 if builder and alive(builder)then
  local producerDef=Spring.GetUnitDefID(builder)
  producerName=UnitDefs[producerDef] and UnitDefs[producerDef].name or 'unknown'
  if Spring.GetUnitCurrentCommand then cmd=Spring.GetUnitCurrentCommand(builder)end
 end
 journal('UNEXPECTED_NATIVE_BIRTH',id,UnitDefs[def].name,'builder',builder or -1,
  'producer',producerName,'current_command',cmd or 'none','state',state,'step',index)
 finish(false,'unaccounted_owned_unit_created_'..UnitDefs[def].name)
end
function gadget:UnitFinished(id,def,t)
 if state~='progression' or t~=team or current.unit~=id then return end
 if not created[id] or created[id].kind~='paid_native_build'then finish(false,'finished_without_paid_provenance');return end
 current.finished=true;journal('PAID_BUILD_FINISHED',UnitDefs[def].name,id,'frames',Spring.GetGameFrame()-current.start)
end
function gadget:UnitFromFactory(id,def,t,factory)
 if state=='progression'and current.row.kind=='factory'and current.unit==id and t==team and factory==current.producer then
  current.fromFactory=true;journal('PAID_SCARAB_FACTORY_EGRESS',id,factory)
 end
end
local function incomingJournal(...)
 if incomingJournalCount<64 then incomingJournalCount=incomingJournalCount+1;journal(...)elseif not incomingJournalTruncated then
  incomingJournalTruncated=true;journal('LEECH_INCOMING_JOURNAL_TRUNCATED',64)
 end
end
function gadget:UnitPreDamaged(id,def,t,damage,paralyzer,weapon,projectile,attacker)
 if abilityProof and id==form and not paralyzer and damage>0 and attacker==enemy and(state=='ability_before'or state=='ability_after'or(state=='ability_immune'and Spring.GetGameFrame()>=abilityDeadline))then
  if state=='ability_immune'then abilityProof.mode='after'end
  local hp,max=Spring.GetUnitHealth(id);local xp=Spring.GetUnitExperience(id);local ok,reason=abilityProof.Pre(Spring.GetGameFrame(),damage,weapon,projectile,attacker,hp,max,xp)
  if not ok then finish(false,reason)end
 end
 if state=='combat' and id==form and damage>0 and leechObserver then
  local hp,max=Spring.GetUnitHealth(form);local xp=Spring.GetUnitExperience(form)
  local token,reason,expected=leechObserver.IncomingPre(Spring.GetGameFrame(),hp,max,xp)
  incomingHits[id]={token=token,weapon=weapon,projectile=projectile,attacker=attacker,paralyzer=paralyzer}
  incomingJournal('LEECH_INCOMING_PRE',id,weapon,projectile or -1,attacker or -1,paralyzer,hp,max,xp,token~=nil,reason or 'verified',expected or -1)
  if not token then finish(false,'native_incoming_leech_pre_accounting_mismatch')end
 end
 if state~='combat' or attacker~=form or paralyzer or damage<=0 or Spring.AreTeamsAllied(team,t)then return end
 local cp=WeaponDefs[weapon] and WeaponDefs[weapon].customParams or {};local cap=tonumber(cp.source_life_leech_damage)
 if not cap then return end
 local victim=Spring.GetUnitHealth(id);local hp,max=Spring.GetUnitHealth(form);local xp=Spring.GetUnitExperience(form)
 if not leechObserver then
  leechObserver=leechAccounting.New(UnitDefs[Spring.GetUnitDefID(form)].health,experienceRules.healthScale)
  journal('LEECH_NATIVE_POLICY',UnitDefs[Spring.GetUnitDefID(form)].health,experienceRules.healthScale,'final_modrules_snapshot')
 end
 local frame=Spring.GetGameFrame()
 beforeHits[id]={weapon=weapon,projectile=projectile,attacker=attacker,cap=cap,token=leechObserver.Pre(frame,hp,max,xp,victim,cap)}
 journal('LEECH_PRE',id,weapon,hp,max,xp,victim,cap)
end
function gadget:UnitDamaged(id,def,t,damage,paralyzer,weapon,projectile,attacker)
 if abilityProof and id==form and not paralyzer and damage>0 and attacker==enemy and(state=='ability_before'or state=='ability_after'or state=='ability_immune')then
  local hp,max=Spring.GetUnitHealth(id);local xp=Spring.GetUnitExperience(id);local ok,reason=abilityProof.Damaged(Spring.GetGameFrame(),damage,weapon,projectile,attacker,hp,max,xp)
  abilityIncomingCount=abilityIncomingCount+1;if abilityIncomingCount<=16 then journal('ABILITY_REAL_DAMAGE',state,id,weapon,projectile,damage,hp,max,ok)end
  if not ok then finish(false,reason)end
 end
 if state=='ability_immune'and attacker==form and id==enemy and damage>0 and not paralyzer then abilityAttacked=true;journal('ABILITY_LIVE_ATTACK_REAL_HIT',form,enemy,weapon,projectile,damage);giveOrder(form,CMD.STOP,{},{});giveOrder(form,CMD.FIRE_STATE,{0},{})end
 if state=='combat' and id==form and damage>0 and leechObserver then
  local before=incomingHits[id];incomingHits[id]=nil
  local hp,max=Spring.GetUnitHealth(form);local xp=Spring.GetUnitExperience(form)
  if not before or before.weapon~=weapon or before.projectile~=projectile or before.attacker~=attacker or before.paralyzer~=paralyzer then
   incomingJournal('LEECH_INCOMING_UNMATCHED',id,weapon,projectile or -1,attacker or -1,damage,hp,max,xp)
   finish(false,'native_incoming_leech_receipt_missing');return
  end
  local okay,expected,pending=leechObserver.Incoming(before.token,damage,hp,max,xp,paralyzer)
  incomingJournal('LEECH_INCOMING_APPLIED',id,weapon,projectile or -1,attacker or -1,paralyzer,damage,hp,max,xp,okay,expected,pending or -1)
  if not okay then finish(false,'native_incoming_leech_damage_accounting_mismatch');return end
 end
 local before=beforeHits[id];beforeHits[id]=nil
 if state~='combat' or attacker~=form or not before or before.weapon~=weapon or before.projectile~=projectile or before.attacker~=attacker or paralyzer or damage<=0 then return end
 local hp,max=Spring.GetUnitHealth(form);local xp=Spring.GetUnitExperience(form)
 -- Native callback order is possession60 then fixture110, before attacker XP.
 local okay,expected,heal=leechObserver.Damaged(before.token,damage,hp,max,xp)
 journal('LEECH_IMMEDIATE',id,weapon,damage,hp,max,xp,okay,expected,heal)
 if not okay then finish(false,'native_immediate_leech_accounting_mismatch');return end
 healing[before.token.frame]=true
 if before.cap==50 then rangedHit=true elseif before.cap==35 then meleeHit=true end
 journal('REAL_HIT',id,weapon,damage,before.token.victim,before.cap,heal)

end
function gadget:GameFrame(frame)
 if regenFailure and state~='done'then finish(false,'actual_regeneration_journal_mismatch_'..regenFailure);return end
 if state=='done'then return end
 if state=='waiting'then if frame>=30 then initialize(frame)end;return end
 if frame%900==0 then
  resources('PROGRESS_'..state);journal('STEP',index,current.row and current.row.name or '')
  if state=='progression' and current.producer then
   local c=GG.Recoil40KResearch;local job=c.jobs[current.producer] and c.jobs[current.producer][current.row.name]
   journal('NATIVE_RESEARCH_QUEUE',current.producer,current.record.cmd,Spring.GetUnitCurrentCommand and Spring.GetUnitCurrentCommand(current.producer) or -1,'job',job and job.steps or -1,'active',job and tostring(job.active) or 'absent')
  end
 end
 if frame-start>fps*3000 then finish(false,'bounded_native_progression_timeout');return end
 if state~='morph' and state~='combat' and state~='revert' and state~='remorph' and state~='ability_before' and state~='ability_immune' and state~='ability_after' and state~='ability_recharge_retry' and not alive(lord)then finish(false,'paid_lord_lost');return end
 if state=='progression'then
  if current.row.kind=='capture'then
   local capture=GG.Recoil40KRelicCapture
   if capture and capture.Owned(team)then
    local receipt=capture.Receipt(relic)
    if not receipt or receipt.actor~=scarab or receipt.team~=team or receipt.owner~=team or receipt.elapsed<math.ceil(61.5*fps)or receipt.finished-receipt.nearSince<math.ceil(61.5*fps)then finish(false,'actual_relic_capture_duration_or_owner_missing');return end
    current.finished=true;journal('REAL_RELIC_CAPTURE_VERIFIED',scarab,relic,receipt.nearSince,receipt.finished,receipt.elapsed)
   elseif frame-current.start>fps*600 then finish(false,'actual_scarab_capture_timeout');return end
  elseif current.row.kind=='research'then
   local c=GG.Recoil40KResearch;local job=c.jobs[current.producer] and c.jobs[current.producer][current.row.name]
   if job then current.observed=current.observed or {steps=0,energy=0,metal=0};current.observed.steps=math.max(current.observed.steps,job.steps);current.observed.energy=math.max(current.observed.energy,job.energy);current.observed.metal=math.max(current.observed.metal,job.metal)end
   if c.HasResearch(team,current.row.name)then
    local o=current.observed;local r=current.record;local tolerance=1e-6
    if not o or o.steps<r.frames-1 or o.energy+(r.row.cost.energy or 0)/r.frames+tolerance<(r.row.cost.energy or 0)or o.metal+(r.row.cost.metal or 0)/r.frames+tolerance<(r.row.cost.metal or 0)or frame-current.start<r.frames then finish(false,'paid_research_duration_or_accounting_missing');return end
    paid[current.row.name]=true;current.finished=true;journal('PAID_RESEARCH_FINISHED',current.row.name,r.frames,o.steps,o.energy,'final_cost',r.row.cost.energy or 0)
   end
  end
  if current.finished and(current.row.kind~='factory'or current.fromFactory)then index=index+1;nextStep(frame)end
 elseif state=='approach'then
  if not alive(enemy)then finish(false,'hostile_actor_lost_before_combat');return end
  local x,y,z=Spring.GetUnitPosition(enemy);local lx,_,lz=Spring.GetUnitPosition(lord)
  local distance=math.sqrt((x-lx)^2+(z-lz)^2)
  if distance>220 then if frame%90==0 then giveOrder(lord,CMD.MOVE,{x+200,y,z},{})end
  else giveOrder(lord,CMD.STOP,{},{});giveOrder(enemy,CMD.FIRE_STATE,{2},{});giveOrder(enemy,CMD.ATTACK,{lord},{});phase('wound')end
 elseif state=='wound'then
  local hp,max=Spring.GetUnitHealth(lord)
  if hp/max<=.85 then
   giveOrder(enemy,CMD.STOP,{},{});giveOrder(enemy,CMD.FIRE_STATE,{0},{})
   giveOrder(lord,CMD.STOP,{},{});origin={id=lord,hp=hp,max=max,team=team,costs={Spring.GetUnitCosts(lord)},safePosition={Spring.GetUnitPosition(lord)}}
   journal('NATIVE_WOUND',lord,hp,max);phase('settle')
  elseif frame-entered>fps*180 then finish(false,'native_enemy_weapon_did_not_wound')end
 elseif state=='settle'then
  local _,_,_,speed=Spring.GetUnitVelocity(lord)
  if speed and speed<.025 then giveOrder(lord,possession.command,{},{});phase('morph')end
 elseif state=='morph'then
  if form and alive(form) and not alive(origin.id)then
   local hp,max=Spring.GetUnitHealth(form);local costs={Spring.GetUnitCosts(form)}
   if formsSeen~=1 or Spring.GetUnitTeam(form)~=origin.team or math.abs(hp/max-(origin.transferredFraction or origin.hp/origin.max))>.01 then finish(false,'one_for_one_identity_health_fraction_failed');return end
   for i=1,3 do if costs[i]~=origin.costs[i]then finish(false,'effective_paid_cost_changed');return end end
   journal('PAID_MORPH_VERIFIED',origin.id,form,hp,max,costs[2],costs[3]);abilityProof=abilityProofConfig.New(enemy);abilityProof.mode='before'
   giveOrder(form,CMD.STOP,{},{});giveOrder(form,CMD.FIRE_STATE,{0},{})
   giveOrder(enemy,CMD.FIRE_STATE,{2},{});giveOrder(enemy,CMD.ATTACK,{form},{});phase('ability_before')
  elseif frame-entered>fps*30 then finish(false,'possession_native_refused_or_stalled')end
 elseif state=='ability_before'then
  if not alive(form)or not alive(enemy)then finish(false,'ability_real_actor_lost');return end
  if abilityProof.before then
   local ability=GG.Recoil40KNightAbility;local eligible=ability and ability.CanActivate(form,frame)
   if not eligible or not paid[nightConfig.ResearchKey]then finish(false,'paid_night_ability_not_eligible');return end
   giveOrder(form,nightConfig.Command,{},{});abilityDeadline=Spring.GetUnitRulesParam(form,'40k_night_ability_active');abilityRecharge=Spring.GetUnitRulesParam(form,'40k_night_ability_ready')
   if abilityDeadline~=frame+15*fps or abilityRecharge~=frame+90*fps then finish(false,'actual_ability_timer_missing');return end
   abilityProof.mode='immune';phase('ability_immune');journal('PAID_ABILITY_MANUAL_STARTED',form,frame,abilityDeadline,abilityRecharge)
  elseif frame-entered>fps*90 then finish(false,'actual_incoming_before_invulnerability_missing')end
 elseif state=='ability_immune'then
  if not alive(form)or not alive(enemy)then finish(false,'ability_real_actor_lost');return end
  local hp,max=Spring.GetUnitHealth(form);local xp=Spring.GetUnitExperience(form);local okay,reason=abilityProof.Verify(frame,hp,max,xp)
  if not okay then finish(false,reason);return end
  if abilityProof.verified>0 and not current.abilityAttackIssued then
   current.abilityAttackIssued=true;giveOrder(form,CMD.FIRE_STATE,{2},{});giveOrder(form,CMD.ATTACK,{enemy},{})
  end
  if frame>=abilityDeadline then
   if abilityProof.verified<1 or not abilityAttacked or abilityProof.damagedDuring>0 or abilityProof.late<abilityDeadline-5*fps then finish(false,'actual_immunity_or_live_attack_window_unproven');return end
   local available,reason=GG.Recoil40KNightAbility.CanActivate(form,frame)
   if available or reason~='cooldown'then finish(false,'actual_ability_recharge_refusal_missing');return end
   giveOrder(form,nightConfig.Command,{},{});if Spring.GetUnitRulesParam(form,'40k_night_ability_ready')~=abilityRecharge then finish(false,'ability_cooldown_command_reset_timer');return end
   giveOrder(form,CMD.STOP,{},{});giveOrder(form,CMD.FIRE_STATE,{0},{})
   abilityProof.mode='after';phase('ability_after');journal('ABILITY_EXACT_DURATION_AND_COOLDOWN_REFUSAL',form,abilityDeadline,abilityRecharge,abilityProof.refused,abilityProof.verified)
  end
 elseif state=='ability_after'then
  if abilityProof.after then
   giveOrder(enemy,CMD.STOP,{},{});giveOrder(enemy,CMD.FIRE_STATE,{0},{})
   phase('combat');giveOrder(form,CMD.FIRE_STATE,{2},{});giveOrder(form,CMD.ATTACK,{enemy},{})
  elseif not alive(form)or frame-entered>fps*90 then finish(false,'native_damage_after_ability_expiry_missing')end
 elseif state=='combat'then
  if not alive(form)then finish(false,'manifestation_lost');return end
  local frames={};for f in pairs(healing)do frames[#frames+1]=f end;table.sort(frames)
  for _,f in ipairs(frames)do if f<frame then
   local hp,max=Spring.GetUnitHealth(form);local xp=Spring.GetUnitExperience(form)
   local okay,expected,hits,heal,incomingCount,incomingDamage=leechObserver.Finish(f,hp,max,xp)
   journal('HEAL_OBSERVED',f,hp,max,xp,okay,expected,hits,heal,'incoming_count',incomingCount or -1,'incoming_damage',incomingDamage or -1)
   if okay and heal>0 then leechProof=true else finish(false,'native_post_xp_leech_accounting_mismatch');return end
   healing[f]=nil
  end end
  if rangedHit and not meleeHit and not current.closeIssued and alive(enemy)then
   local x,y,z=Spring.GetUnitPosition(enemy);giveOrder(form,CMD.MOVE,{x,y,z},{});current.closeIssued=true;journal('NATIVE_CLOSE_FOR_MELEE',form,enemy)
  end
  if rangedHit and meleeHit and leechProof then
   local hp,max=Spring.GetUnitHealth(form);origin.revertFraction=hp/max
   giveOrder(form,CMD.STOP,{},{});giveOrder(form,CMD.FIRE_STATE,{0},{})
   giveOrder(form,possession.revertCommand,{},{});phase('revert')
  elseif not alive(enemy)then finish(false,'target_destroyed_before_two_gun_proof')
  elseif frame-entered>fps*180 then finish(false,'real_mount_or_leech_hits_missing')end
 elseif state=='revert'then
  if lord~=origin.id and alive(lord) and not alive(form)then
   local hp,max=Spring.GetUnitHealth(lord)
   if Spring.GetUnitRulesParam(lord,'40k_night_ability_ready')~=abilityRecharge then finish(false,'ability_cooldown_lost_on_reversal');return end
   if Spring.GetUnitTeam(lord)~=team or math.abs(hp/max-origin.revertFraction)>.01 then finish(false,'reversal_health_owner_failed');return end
   local review=possessionReview();cooldownDeadline=cooldownRule()
   if not review or type(cooldownDeadline)~='number'or cooldownDeadline<=frame then finish(false,'native_cooldown_rule_or_review_missing');return end
   retryLord=lord;giveOrder(lord,CMD.FIRE_STATE,{0},{});giveOrder(lord,CMD.MOVE,origin.safePosition,{})
   phase('cooldown_relocate');journal('REVERSAL_VERIFIED',lord,hp,max,'cooldown',cooldownDeadline)
   journal('NATIVE_COOLDOWN_CLEAR_MOVE',lord,origin.safePosition[1],origin.safePosition[3])
  elseif frame-entered>fps*30 then finish(false,'native_reversal_failed')end
 elseif state=='cooldown_relocate'then
  local review=possessionReview();if not review then finish(false,'native_review_lost');return end
  local x,_,z=Spring.GetUnitPosition(lord);local _,_,_,speed=Spring.GetUnitVelocity(lord)
  if (x-origin.safePosition[1])^2+(z-origin.safePosition[3])^2<16^2 and not current.cooldownStopped then
   giveOrder(lord,CMD.STOP,{},{});current.cooldownStopped=frame
  end
  if current.cooldownStopped and frame>current.cooldownStopped and speed and speed<.025 then
   local p=review.Prerequisites(lord);local rule=cooldownRule()
   if nonCooldownReady(p)and p.eligible==false and rule==p.cooldown and rule==cooldownDeadline then
    if frame+math.ceil(possession.windup*fps)+5>=rule then finish(false,'cooldown_isolation_window_lost');return end
    local last=review.LastRequest(lord);cooldownAttempt={frame=frame,serial=last and last.serial or 0}
    journal('COOLDOWN_NON_COOLDOWN_PREREQUISITES_PROVEN',lord,'cap',p.cap,'clear',p.clear,'ready',p.ready,'research',p.research,'archive',p.archive,'validLord',p.validLord,'deadline',rule)
    giveOrder(lord,possession.command,{},{});phase('cooldown_refusal')
   end
  end
  if state=='cooldown_relocate'and(frame-entered>fps*30 or frame+math.ceil(possession.windup*fps)+5>=cooldownDeadline)then finish(false,'native_cooldown_clear_settle_timeout')end
 elseif state=='cooldown_refusal'then
  local review=possessionReview();if not review then finish(false,'native_review_lost');return end
  if formsSeen~=1 or lord~=retryLord then finish(false,'recharge_did_not_refuse_repeat');return end
  local request=review.LastRequest(lord)
  if request and request.serial>cooldownAttempt.serial and request.frame>=cooldownAttempt.frame and request.command==possession.command then
   local p=request.prerequisites
   if request.begun~=false or request.pending~=false or not nonCooldownReady(p)or p.eligible~=false
    or p.cooldown~=cooldownDeadline or request.frame>=p.cooldown then finish(false,'cooldown_refusal_not_isolated');return end
   cooldownReceipt=request
  end
  if frame-entered>math.ceil(possession.windup*fps)+5 then
   if not cooldownReceipt then finish(false,'actual_cooldown_request_receipt_missing');return end
   journal('ACTUAL_COOLDOWN_REFUSAL_PROVEN',lord,cooldownReceipt.frame,cooldownDeadline,'begun',cooldownReceipt.begun,'pending',cooldownReceipt.pending)
   phase('cooldown_expiry')
  end
 elseif state=='cooldown_expiry'then
  local review=possessionReview();if not review then finish(false,'native_review_lost');return end
  local p=review.Prerequisites(lord)
  if frame>=cooldownDeadline and cooldownRule()==cooldownDeadline and nonCooldownReady(p)and p.eligible==true then
   journal('NATIVE_AFTER_COOLDOWN_ELIGIBLE',lord,frame,p.cooldown,'cap',p.cap,'clear',p.clear)
   local last=review.LastRequest(lord);current.retrySerial=last and last.serial or 0
   giveOrder(lord,possession.command,{},{});phase('remorph')
  elseif frame>cooldownDeadline+fps*30 then finish(false,'native_after_cooldown_eligibility_missing')end
 elseif state=='remorph'then
  local review=possessionReview();local request=review and review.LastRequest(retryLord)
  if request and request.serial>current.retrySerial and(request.begun~=true or request.pending~=true)then finish(false,'eligible_native_retry_refused');return end
  if formsSeen==2 and alive(form)and not alive(retryLord)then
   if not request or request.serial<=current.retrySerial or request.begun~=true then finish(false,'eligible_native_retry_receipt_missing');return end
   local hp,max=Spring.GetUnitHealth(form);local costs={Spring.GetUnitCosts(form)}
   if Spring.GetUnitTeam(form)~=team or math.abs(hp/max-origin.transferredFraction)>.01 then finish(false,'retry_identity_health_fraction_failed');return end
   for i=1,3 do if costs[i]~=origin.costs[i]then finish(false,'retry_effective_paid_cost_changed');return end end
   journal('NATIVE_AFTER_COOLDOWN_REMORPH_PROVEN',retryLord,form,hp,max)
   if Spring.GetUnitRulesParam(form,'40k_night_ability_ready')~=abilityRecharge then finish(false,'ability_cooldown_lost_on_remorph');return end
   phase('ability_recharge_retry')
  elseif frame-entered>fps*30 then finish(false,'eligible_native_retry_stalled')end
 elseif state=='ability_recharge_retry'then
  if not alive(form)then finish(false,'remorphed_ability_actor_lost');return end
  if frame>=abilityRecharge then
   local eligible=GG.Recoil40KNightAbility.CanActivate(form,frame)
   if not eligible then finish(false,'actual_ability_after_recharge_refused');return end
   giveOrder(form,nightConfig.Command,{},{});if Spring.GetUnitRulesParam(form,'40k_night_ability_active')~=frame+15*fps then finish(false,'actual_ability_reactivation_timer_missing');return end
   finish(true,'paid_source_and_earned_relic_upgrade_native_damage_before_refused_during_after_live_attack_leech_morph_reversal_both_cooldowns')
  end
 end
end

local function refusalJournal(id,frame,damage,weapon,projectile,attacker,hp,max,xp)
 if id~=form or not abilityProof or state~='ability_immune'or attacker~=enemy then return end
 local okay,reason=abilityProof.Refused(frame,damage,weapon,projectile,attacker,hp,max,xp)
 if abilityProof.refused and abilityProof.refused<=16 then journal('ABILITY_NATIVE_ZERO_ZERO_REFUSAL',id,frame,damage,weapon,projectile,attacker,hp,max,xp,okay)end
 if not okay then finish(false,reason)end
end
GG.Recoil40KNightDamageRefusal=refusalJournal
function gadget:Shutdown()if GG.Recoil40KNightRegenObserver==regenJournal then GG.Recoil40KNightRegenObserver=nil end;if GG.Recoil40KNightDamageRefusal==refusalJournal then GG.Recoil40KNightDamageRefusal=nil end end
