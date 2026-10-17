function gadget:GetInfo()return{name='40K paid Wraith native adapter fixture',desc='Dedicated paid progression and strict real-event adapter; no grants',author='Local project',layer=112,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local opts=Spring.GetModOptions()or{}
if opts.prototype_diagnostic~='expandedproduction'or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression)or tostring(opts.prototype_wraith_review)~='1'or tostring(opts.prototype_wraith_witness)~='1'or tostring(opts.prototype_wraith_acceptance)~='1'or opts.prototype_source_acceptance~='wraith'then return end
local module=VFS.Include('40k_configs/wraith_paid_native_adapter.lua')
local state='waiting';local fps=Game.gameSpeed or 30;local team,lord,enemy,base,start,wraith,proof,priorWitness
local current,index,created,paid={},1,{},{};local sites,mexes={},{};local issuing=0;local entered=0;local receipts=0;local journalLimit=false
local steps={{kind='build',name='nec_mex'},{kind='build',name='nec_mex'},{kind='build',name='nec_hq'},
 {kind='build',name='nec_generator'},{kind='build',name='nec_generator'},{kind='build',name='nec_generator'},{kind='build',name='nec_generator'},
 {kind='build',name='nec_core'},{kind='research',name='nec_awakening_1',producer='nec_hq'},{kind='factory',name='nec_wraith',producer='nec_hq'}}
local function journal(event,row,...)
 if receipts>=256 then return end
 if receipts==255 then journalLimit=true;event='JOURNAL_TRUNCATED';row={limit=256}end;receipts=receipts+1
 if type(row)~='table'then row={value=row,extra={...}}end
 local text=VFS.Include('40k_configs/wraith_paid_native_json.lua').Encode({event=event,frame=Spring.GetGameFrame(),state=state,data=row})
 Spring.Echo('40K_WRAITH_PAID '..text)
end
local function finish(ok,reason)if state=='done'then return end;state='done';Spring.SetGameRulesParam('40k_wraith_paid_result',ok and 1 or -1);journal(ok and'PASS'or'INCOMPLETE_OR_FAIL',{reason=reason})end
local function giveOrder(...)issuing=issuing+1;local ok,result=pcall(Spring.GiveOrderToUnit,...);issuing=issuing-1;if not ok then error(result,0)end;return result end
local function alive(id)return id and Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id)end
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

local function phase(nextState)state=nextState;entered=Spring.GetGameFrame();journal('STATE',{name=state})end
local function nextStep(frame)
 local row=steps[index]
 if not row then
  local hq=find('nec_hq');local receipt=created[wraith];receipt.researchPaid=paid.nec_awakening_1==true
  proof=module.New(Spring,{fps=fps,hqDef=UnitDefNames.nec_hq.id,wraithDef=UnitDefNames.nec_wraith.id,Order=giveOrder,Journal=journal,
   Controller=function()return GG.Recoil40KWraithReview end,PaidResearch=function(t)return GG.Recoil40KResearch.HasResearch(t,'nec_awakening_1')end,
   Ranged=function(w)return WeaponDefs[w]and(WeaponDefs[w].customParams or{}).source_damage_kind=='ranged'end})
  local ok,reason=proof.Begin(wraith,enemy,team,hq,receipt);if not ok then finish(false,reason);return end
  phase('before');giveOrder(wraith,CMD.FIRE_STATE,{2},{});giveOrder(wraith,CMD.ATTACK,{enemy},{});return
 end
 current={row=row,start=frame};resources('BEFORE_'..row.name)
 if row.kind=='build'then
  local d=option(lord,row.name);local p=d and site(d,row.name=='nec_mex')
  if not p then finish(false,'native_build_menu_or_real_site_missing_'..row.name);return end
  current.def=d;giveOrder(lord,-d,p,{});journal('PAID_BUILD_ORDER',{builder=lord,name=row.name,def=d,position=p,metal=UnitDefs[d].metalCost,energy=UnitDefs[d].energyCost,time=UnitDefs[d].buildTime})
 elseif row.kind=='research'then
  local r=GG.Recoil40KResearch;local record=r.records[row.name];local producer=find(row.producer)
  if not record or not producer or r.HasResearch(team,row.name)then finish(false,'missing_or_prepaid_research');return end
  current.record=record;current.producer=producer;giveOrder(producer,record.cmd,{},{});journal('PAID_RESEARCH_ORDER',{name=row.name,producer=producer,command=record.cmd,frames=record.frames,cost=record.row.cost})
 else
  local producer=find(row.producer);local d=producer and option(producer,row.name)
  if not d or find(row.name)then finish(false,'genuine_hq_wraith_menu_missing_or_prebuilt');return end
  if UnitDefs[d].metalCost<=0 or UnitDefs[d].energyCost<=0 or UnitDefs[d].buildTime<=0 then finish(false,'native_wraith_price_missing');return end
  current.def=d;current.producer=producer;current.builder=producer;giveOrder(producer,-d,{},{});journal('PAID_WRAITH_ORDER',{producer=producer,def=d,metal=UnitDefs[d].metalCost,energy=UnitDefs[d].energyCost,time=UnitDefs[d].buildTime})
 end
end
local function witness(event,id,...)
 if priorWitness then priorWitness(event,id,...)end
 if proof then proof.Witness(event,id,...)end
end
function gadget:Initialize()
 local d=UnitDefNames.nec_wraith;local weapons=d and UnitDefs[d.id].weapons
 if not weapons or not Script or type(Script.SetWatchProjectile)~='function'then finish(false,'native_projectile_watch_unavailable');return end
 for _,w in ipairs(weapons)do Script.SetWatchProjectile(w.weaponDef,true)end
 if not GG.Recoil40KWraithReview or type(GG.Recoil40KWraithWitness)~='function'then finish(false,'review_or_existing_witness_missing');return end
 priorWitness=GG.Recoil40KWraithWitness;GG.Recoil40KWraithWitness=witness
end
function gadget:UnitCommand(id,def,t,cmd,params,options,tag,playerID,fromSynced,fromLua)
 if state~='done'and team and t==team and issuing==0 then journal('OUTSIDE_FIXTURE_ORDER',{id=id,command=cmd,tag=tag,player=playerID,fromSynced=fromSynced,fromLua=fromLua})end
end
function gadget:UnitCreated(id,def,t,builder)
 if state=='done'or not team or t~=team then return end
 if state~='progression'or current.def~=def or builder~=(current.builder or lord)then finish(false,'unaccounted_owned_native_birth');return end
 local receipt={builder=builder,finished=false,egress=false}
 if current.row.kind=='factory'then local head=(Spring.GetFactoryCommands(builder,-1)or{})[1]
  if not head or head.id~=-def or not head.tag then finish(false,'native_wraith_factory_head_missing');return end
  receipt.queueDef=head.id;receipt.queueTag=head.tag;wraith=id
 end
 current.unit=id;created[id]=receipt;journal('ACTUAL_PAID_BIRTH',{id=id,def=def,builder=builder,queueDef=receipt.queueDef,queueTag=receipt.queueTag})
end
function gadget:UnitFinished(id,def,t)
 if state=='progression'and t==team and current.unit==id and created[id]then current.finished=true;created[id].finished=true;journal('ACTUAL_PAID_FINISHED',{id=id,def=def,builder=created[id].builder})end
end
function gadget:UnitFromFactory(id,def,t,factory)
 if state=='progression'and current.unit==id and current.row.kind=='factory'and factory==current.producer and t==team then created[id].egress=true;current.fromFactory=true;journal('ACTUAL_PAID_EGRESS',{id=id,factory=factory})end
end
function gadget:ProjectileCreated(id,owner,weapon)if proof then proof.Projectile(id,owner,weapon,Spring.GetGameFrame())end end
function gadget:UnitDamaged(id,def,t,damage,paralyzer,weapon,projectile,attacker)
 if not proof or state=='done'then return end
 proof.Damaged(id,damage,paralyzer,weapon,projectile,attacker,Spring.GetGameFrame())
 if state=='before'and attacker==wraith and id==enemy and damage>0 and not current.outgoingBefore then
  current.outgoingBefore=true;giveOrder(wraith,CMD.STOP,{},{});giveOrder(wraith,CMD.FIRE_STATE,{0},{});giveOrder(enemy,CMD.FIRE_STATE,{2},{});giveOrder(enemy,CMD.ATTACK,{wraith},{})
 end
end
function gadget:GameFrame(frame)
 if state=='done'then return end
 if journalLimit then finish(false,'native_journal_truncated');return end
 if state=='waiting'then
  if frame<30 then return end
  local all=Spring.GetAllUnits()or{};table.sort(all)
  for _,id in ipairs(all)do if Spring.GetUnitDefID(id)==UnitDefNames.nec_lord.id then lord=id;team=Spring.GetUnitTeam(id);break end end
  if not lord then if frame>60*fps then finish(false,'actual_starting_lord_missing')end;return end
  if #units(team)~=1 then finish(false,'unexpected_owned_start_population');return end
  for _,id in ipairs(all)do if not Spring.AreTeamsAllied(team,Spring.GetUnitTeam(id))and Spring.GetUnitTeam(id)~=Spring.GetGaiaTeamID()then
   local d=UnitDefs[Spring.GetUnitDefID(id)];if(d.customParams or{}).iscommander or(d.customParams or{}).commander or d.isBuilder then enemy=id;break end
  end end
  if not enemy or not GG.Recoil40KResearch then finish(false,'actual_hostile_or_paid_controller_missing');return end
  for _,w in ipairs(UnitDefs[Spring.GetUnitDefID(enemy)].weapons or{})do Script.SetWatchProjectile(w.weaponDef,true)end
  base={Spring.GetUnitPosition(lord)};start=frame;giveOrder(lord,CMD.FIRE_STATE,{0},{});giveOrder(enemy,CMD.FIRE_STATE,{0},{});phase('progression');nextStep(frame);return
 end
 if frame-start>fps*1200 then finish(false,'bounded_paid_native_timeout');return end
 if state=='progression'then
  if not alive(lord)then finish(false,'paid_lord_lost');return end
    if current.row.kind=='research'then
   local c=GG.Recoil40KResearch;local job=c.jobs[current.producer] and c.jobs[current.producer][current.row.name]
   if job then current.observed=current.observed or {steps=0,energy=0,metal=0};current.observed.steps=math.max(current.observed.steps,job.steps);current.observed.energy=math.max(current.observed.energy,job.energy);current.observed.metal=math.max(current.observed.metal,job.metal)end
   if c.HasResearch(team,current.row.name)then
    local o=current.observed;local r=current.record;local tolerance=1e-6
    if not o or o.steps<r.frames-1 or o.energy+(r.row.cost.energy or 0)/r.frames+tolerance<(r.row.cost.energy or 0)or o.metal+(r.row.cost.metal or 0)/r.frames+tolerance<(r.row.cost.metal or 0)or frame-current.start<r.frames then finish(false,'paid_research_duration_or_accounting_missing');return end
    paid[current.row.name]=true;current.finished=true;journal('PAID_RESEARCH_FINISHED',current.row.name,r.frames,o.steps,o.energy,'final_cost',r.row.cost.energy or 0)
   end
  end

  if current.finished and(current.row.kind~='factory'or current.fromFactory)then index=index+1;nextStep(frame)end
 elseif proof then
  proof.Frame(frame);if proof.failure then finish(false,proof.failure);return end
  if state=='before'and proof.before and current.outgoingBefore and not current.pendingAttackOrdered then
   current.pendingAttackOrdered=true;giveOrder(wraith,CMD.FIRE_STATE,{2},{});giveOrder(wraith,CMD.ATTACK,{enemy},{});journal('REAL_PENDING_ATTACK_ORDER',{actor=wraith,target=enemy})
  end
  if state=='before'and proof.mode=='phase'then phase('phase')end
  if proof.mode=='done'then local ok,missing=proof.Result();finish(ok,{missing=missing,attack_cancellation=proof.pendingCancelled==true,outgoing_zero_separate=true})end
 end
end
function gadget:Shutdown()if GG.Recoil40KWraithWitness==witness then GG.Recoil40KWraithWitness=priorWitness end end
