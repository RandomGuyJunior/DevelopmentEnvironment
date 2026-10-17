function gadget:GetInfo()return{name='40K paid Spyder harvest fixture',desc='Ordinary paid progression/combat/pathing/body-currency evidence',author='Local project',layer=112,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local o=Spring.GetModOptions()or{}
if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_spyder_harvest_fixture)or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_spyder_harvest_review)or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)or o.prototype_diagnostic~='expandedproduction'then return end
if o.prototype_source_acceptance and o.prototype_source_acceptance~=''then return end
local M=VFS.Include('40k_configs/necron_spyder_harvest_fixture.lua');local fps=Game.gameSpeed or 30
local state='waiting';local team,lord,enemy,base,start,spyder,proof,feature,victim;local step=1;local current={};local sites,mexes,births={},{},{};local egress={};local egressIssued=false;local victimNumber=0;local phaseStart=0;local zeroRefusal=false
local function sorted(t)local ids={};for id in pairs(t)do ids[#ids+1]=id end;table.sort(ids);return ids end
local function log(...)Spring.Echo('40K SPYDER HARVEST FIXTURE',Spring.GetGameFrame(),...)end
local function finish(ok,why)if state=='done'then return end;state='done';Spring.SetGameRulesParam('40k_spyder_harvest_fixture_result',ok and 1 or-1);log(ok and'PASS'or'FAIL',why,'collected',proof and proof.consumed or 0,'expired',proof and proof.expired or 0)end
local function phase(s)state=s;phaseStart=Spring.GetGameFrame();log('STATE',s)end
local function live(id)return id and Spring.ValidUnitID(id)and not Spring.GetUnitIsDead(id)end
local function source(def)local d=UnitDefs[def];local cp=d and d.customParams or{};return cp.prototype40k_tech_requires or cp.prototype40k_donor or d and d.name end
local function controller()return GG.Recoil40KResearch end
local function find(name)
 for _,id in ipairs(Spring.GetTeamUnits(team)or{})do local u=controller().units[id];if u and u.name==name and u.finished and live(id)then return id end end
end
local function option(id,name)
 for _,def in ipairs(UnitDefs[Spring.GetUnitDefID(id)].buildOptions or{})do if source(def)==name then return def end end
end
local function order(id,cmd,p)Spring.GiveOrderToUnit(id,cmd,p or{},{})end
local function site(def,metal)
 local candidates={}
 if metal then
  for x=math.max(96,base[1]-1200),math.min(Game.mapSizeX-96,base[1]+1200),32 do for z=math.max(96,base[3]-1200),math.min(Game.mapSizeZ-96,base[3]+1200),32 do
   if(select(3,Spring.GetGroundInfo(x,z))or 0)>0 then candidates[#candidates+1]={x,z,(x-base[1])^2+(z-base[3])^2}end
  end end
  table.sort(candidates,function(a,b)if a[3]~=b[3]then return a[3]<b[3]end;if a[1]~=b[1]then return a[1]<b[1]end;return a[2]<b[2]end)
 else for ring=4,25 do for n=0,15 do local a=n*math.pi/8;candidates[#candidates+1]={base[1]+ring*32*math.cos(a),base[3]+ring*32*math.sin(a)}end end end
 for _,p in ipairs(candidates)do
  local x=math.floor(p[1]/16)*16+8;local z=math.floor(p[2]/16)*16+8;local y=Spring.GetGroundHeight(x,z);local clear=y>0 and x>96 and z>96 and x<Game.mapSizeX-96 and z<Game.mapSizeZ-96
  for _,old in ipairs(sites)do if(x-old[1])^2+(z-old[3])^2<160^2 then clear=false end end
  if metal then for _,old in ipairs(mexes)do if(x-old[1])^2+(z-old[3])^2<180^2 then clear=false end end end
  if clear and Spring.TestBuildOrder(def,x,y,z,0)==2 and(not metal or(select(3,Spring.GetGroundInfo(x,z))or 0)>0)then
   local p={x,y,z,0};sites[#sites+1]=p;if metal then mexes[#mexes+1]=p end;return p
  end
 end
end
local function begin(row)
 current={row=row,start=Spring.GetGameFrame()}
 if row.kind=='research'then
  local c=controller();local r=c.records[row.name];local producer=find(row.producer)
  if not r or not producer or c.HasResearch(team,row.name)then finish(false,'research_precompleted_or_unavailable');return end
  current.producer=producer;current.record=r;order(producer,r.cmd);log('PAID_RESEARCH_ORDER',producer,row.name,r.frames,r.row.cost.energy or 0)
 else
  local producer=row.kind=='factory'and find(row.producer)or lord;local def=producer and option(producer,row.name)
  if not def or not controller().CanBuild(team,def,producer,false)then finish(false,'genuine_native_menu_or_prerequisites_missing_'..row.name);return end
  local d=UnitDefs[def];if(d.metalCost or 0)<0 or(d.energyCost or 0)<0 or(d.metalCost or 0)+(d.energyCost or 0)<=0 or(d.buildTime or 0)<=0 then finish(false,'ordinary_native_price_missing');return end
  local p=row.kind=='build'and site(def,row.name=='nec_mex')or{}
  if not p then finish(false,'native_build_site_missing');return end
  current.builder=producer;current.def=def;order(producer,-def,p);log('PAID_NATIVE_ORDER',producer,row.name,def,d.metalCost,d.energyCost,d.buildTime)
 end
end
local function near(fid)
 if not live(spyder)or not Spring.ValidFeatureID(fid)then return false end
 local x,y,z=Spring.GetUnitPosition(spyder);local bx,by,bz=Spring.GetFeaturePosition(fid);return x and bx and(x-bx)^2+(z-bz)^2<=(5*8)^2 or false
end
local function outputReceipt(id)
 local work,metal,energy=Spring.GetUnitCosts(id);local def=UnitDefs[UnitDefNames.nec_warrior.id]
 if work~=def.buildTime or metal~=def.metalCost or energy~=def.energyCost then return false end
 local p=GG.Recoil40KSpyderPaidOrigin;local r=p and p.outputs[id];local c=controller();local u=c and c.units[id]
 return r and r.team==team and r.producer==spyder and r.currency=='source_bodies'and r.def==UnitDefNames.nec_warrior.id and live(id)and u and u.finished and u.team==team and Spring.GetUnitTeam(id)==team and Spring.GetUnitDefID(id)==r.def and true or false
end
local function witness(event,...)
 if state=='done'or not proof then return end
 local p={...};local f=Spring.GetGameFrame();local ok,reason=true
 if event=='BODY_BIRTH'then
  local fd=Spring.GetFeatureDefID(p[1]);local cp=(FeatureDefs[fd]or{}).customParams or{}
  if cp.source_body~=M.BodySource then finish(false,'wrong_native_source_feature');return end
  ok,reason=proof.Body(p[1],p[2],p[3],p[4],f,Spring.ValidFeatureID(p[1]));feature=p[1]
  order(enemy,CMD.STOP);order(enemy,CMD.FIRE_STATE,{0})
  if victimNumber==1 then phase('expiry')else phase('pickup');order(spyder,M.PickupCommand,{feature})end
 elseif event=='PICKUP_START'then ok,reason=proof.Pickup(p[1],p[2],p[3],GG.Recoil40KSpyderHarvestReview.Balance(spyder))
 elseif event=='BODY_CONSUMED'then
  ok,reason=proof.Consumed(p[1],p[2],p[3],f,Spring.ValidFeatureID(p[2]));if ok then phase('next_victim')end
 elseif event=='BODY_EXPIRED'then
  ok,reason=proof.Expired(p[1],p[2],Spring.ValidFeatureID(p[1]));if ok then phase('next_victim')end
 elseif event=='OUTPUT_PAID'then ok,reason=proof.OutputPaid(p[1],p[2],p[3],p[4],p[5],outputReceipt);if ok and proof.Accept()then for id in pairs(proof.outputs)do egress[id]={Spring.GetUnitPosition(id)}end;phase('output_egress')end
 elseif event=='BODY_REMOVAL_FAILED'then finish(false,'actual_native_feature_removal_not_confirmed')
 elseif event=='OUTPUT_ROLLBACK'and state=='output'then finish(false,'actual_output_rolled_back')end
 if not ok then finish(false,reason)end
end
function gadget:Initialize()if GG.Recoil40KSpyderHarvestWitness then finish(false,'harvest_witness_already_owned');return end;GG.Recoil40KSpyderHarvestWitness=witness end
function gadget:Shutdown()if GG.Recoil40KSpyderHarvestWitness==witness then GG.Recoil40KSpyderHarvestWitness=nil end end
function gadget:UnitCreated(id,def,t,builder)
 if state=='done'or not team or t~=team then return end
 if state=='output'then local ok,why=proof.NativeOutput(id,def,t,builder);if not ok then finish(false,why)end;return end
 if(state=='progression'or state=='victim_production')and current.def==def and current.builder==builder and not current.unit then
  local hp,_,_,_,built=Spring.GetUnitHealth(id)
  if not hp or hp<=0 or built>=1 then finish(false,'seeded_finished_actor_refused');return end
  if current.row.kind=='factory'then local q=(Spring.GetFactoryCommands(builder,1)or{})[1];if not q or q.id~=-def or not q.tag then finish(false,'genuine_factory_head_missing');return end;current.tag=q.tag end
  current.unit=id;births[id]={builder=builder,def=def,team=t};log('PAID_NATIVE_CREATED',id,def,builder,built);return
 end
 finish(false,'unaccounted_owned_native_birth')
end
function gadget:UnitFinished(id,def,t)
 if(state=='progression'or state=='victim_production')and current.unit==id and t==team then
  local b=births[id];local work,metal,energy=Spring.GetUnitCosts(id);local d=UnitDefs[def]
  if not b or b.def~=def or b.builder~=current.builder or work~=d.buildTime or metal~=d.metalCost or energy~=d.energyCost then finish(false,'native_finish_cost_or_provenance_missing');return end
  current.finished=true;log('PAID_NATIVE_FINISHED',id,work,metal,energy)
 end
end
function gadget:UnitFromFactory(id,def,t,factory)if current.unit==id and current.row and current.row.kind=='factory'and t==team and factory==current.builder then current.fromFactory=true end end
function gadget:UnitPreDamaged(id,def,t,damage,paralyzer,weapon,projectile,attacker)
 if proof and not paralyzer then proof.Pre(id,Spring.GetGameFrame(),Spring.GetUnitHealth(id),damage,weapon,projectile,attacker)end
end
function gadget:UnitDamaged(id,def,t,damage,paralyzer,weapon,projectile,attacker)
 if proof and not paralyzer then proof.Damaged(id,Spring.GetGameFrame(),Spring.GetUnitHealth(id),damage,weapon,projectile,attacker)end
end
function gadget:UnitDestroyed(id)if proof then proof.Destroyed(id,Spring.GetGameFrame())end;if id==spyder and state~='done'then finish(false,'genuine_paid_spyder_lost')end end
function gadget:UnitTaken(id)if id==spyder or id==victim then finish(false,'actual_capture_requires_fresh_paid_provenance_no_balance_transfer')end end
function gadget:UnitGiven(id)if id==spyder or id==victim then finish(false,'actual_owner_transfer_not_positive_acceptance')end end
function gadget:GameFrame(f)
 if state=='done'then return end
 if proof and proof.failed then finish(false,proof.failed);return end
 if start and f-start>M.MaxSeconds*fps then finish(false,'bounded_paid_fixture_timeout');return end
 if state=='waiting'then
  if f<30 then return end
  if not controller()or not GG.Recoil40KSpyderHarvestReview or not GG.Recoil40KSpyderPaidOrigin then finish(false,'actual_source_paid_harvest_adapter_not_ready');return end
  local list=Spring.GetAllUnits()or{};table.sort(list)
  for _,id in ipairs(list)do if source(Spring.GetUnitDefID(id))=='nec_lord'then lord=id;team=Spring.GetUnitTeam(id);break end end
  if not lord or #(Spring.GetTeamUnits(team)or{})~=1 then finish(false,'ordinary_single_lord_start_required');return end
  for _,id in ipairs(list)do if not Spring.AreTeamsAllied(team,Spring.GetUnitTeam(id))then local d=UnitDefs[Spring.GetUnitDefID(id)];if d.isBuilder or(d.customParams or{}).iscommander then enemy=id;break end end end
  if not enemy then finish(false,'actual_native_hostile_actor_required');return end
  base={Spring.GetUnitPosition(lord)};start=f;order(lord,CMD.FIRE_STATE,{0});order(enemy,CMD.FIRE_STATE,{0});phase('progression');begin(M.Steps[step]);return
 end
 if not live(lord)or not live(enemy)then finish(false,'actual_starting_actor_lost');return end
 if state=='progression'or state=='victim_production'then
  if current.row.kind=='research'then
   local c=controller();local j=c.jobs[current.producer]and c.jobs[current.producer][current.row.name]
   if j then current.observed=current.observed or{steps=0,energy=0,metal=0};local a=current.observed;a.steps=math.max(a.steps,j.steps);a.energy=math.max(a.energy,j.energy);a.metal=math.max(a.metal,j.metal)end
   if c.HasResearch(team,current.row.name)then local a=current.observed;local r=current.record;local cost=r.row.cost
    if not a or a.steps<r.frames-1 or a.energy+(cost.energy or 0)/r.frames+1e-6<(cost.energy or 0)or a.metal+(cost.metal or 0)/r.frames+1e-6<(cost.metal or 0)or f-current.start<r.frames then finish(false,'actual_paid_research_receipt_missing');return end
    current.finished=true
   end
  end
  if current.finished and(current.row.kind~='factory'or current.fromFactory)then
   if state=='progression'then step=step+1;if M.Steps[step]then begin(M.Steps[step])else
    spyder=current.unit;local p=GG.Recoil40KSpyderPaidOrigin
    if not p.IsPaidSpyder(spyder,team)then finish(false,'actual_paid_spyder_origin_missing');return end
    proof=M.New{spyder=spyder,enemy=enemy,team=team,warriorDef=UnitDefNames.nec_warrior.id,fps=fps}
    order(spyder,CMD.FIRE_STATE,{0});order(spyder,M.OutputCommand);phase('zero_body_refusal')
   end
   else victim=current.unit;proof.ExpectVictim(victim);order(victim,CMD.FIRE_STATE,{0});local x,y,z=Spring.GetUnitPosition(enemy);order(victim,CMD.MOVE,{x+64,y,z});phase('approach')end
  end
 elseif state=='zero_body_refusal'then
  if f-phaseStart>=2 then if GG.Recoil40KSpyderHarvestReview.Balance(spyder)~=0 or next(proof.outputs)then finish(false,'zero_body_output_not_refused');return end;zeroRefusal=true;local x=math.min(Game.mapSizeX-128,base[1]+700);local z=math.min(Game.mapSizeZ-128,base[3]+700);local y=Spring.GetGroundHeight(x,z);current.combatSite={x,y,z};order(enemy,CMD.MOVE,current.combatSite);order(spyder,CMD.MOVE,{x-240,y,z});phase('combat_staging')end
 elseif state=='combat_staging'then
  local x,y,z=Spring.GetUnitPosition(enemy);local p=current.combatSite
  if(x-p[1])^2+(z-p[3])^2<80^2 then order(enemy,CMD.STOP);phase('next_victim')elseif f-phaseStart>240*fps then finish(false,'ordinary_native_enemy_pathing_timeout')end
 elseif state=='next_victim'then
  if proof.consumed==5 then
   if not zeroRefusal or not proof.BeginOutput(GG.Recoil40KSpyderHarvestReview.Balance(spyder))then finish(false,'strict_body_currency_proof_missing');return end
   phase('output');order(spyder,M.OutputCommand)
  else victimNumber=victimNumber+1;phase('victim_production');begin{kind='factory',name='nec_warrior',producer='nec_hq'}end
 elseif state=='approach'then
  if not live(victim)then finish(false,'victim_lost_without_lethal_receipt');return end
  local x,y,z=Spring.GetUnitPosition(enemy);local vx,vy,vz=Spring.GetUnitPosition(victim)
  if(vx-x)^2+(vz-z)^2<120^2 then order(victim,CMD.STOP);order(enemy,CMD.FIRE_STATE,{2});order(enemy,CMD.ATTACK,{victim});phase('combat')end
 elseif state=='combat'then if f-phaseStart>180*fps then finish(false,'ordinary_hostile_weapon_did_not_kill');return end
 elseif state=='pickup'then local ok,why=proof.Frame(f,Spring.ValidFeatureID,GG.Recoil40KSpyderHarvestReview.Balance(spyder),near);if not ok then finish(false,why)end
 elseif state=='output_egress'then
  if not egressIssued then for _,id in ipairs(sorted(egress))do local p=egress[id];order(id,CMD.FIRE_STATE,{0});order(id,CMD.MOVE,{p[1]+120,p[2],p[3]+80})end;egressIssued=true end
  local complete=0
  for id,p in pairs(egress)do
   if not outputReceipt(id)then finish(false,'genuine_output_lost_after_native_birth');return end
   local x,y,z=Spring.GetUnitPosition(id)
   if(x-p[1])^2+(z-p[3])^2>=80^2 then complete=complete+1 end
  end
  if complete==3 then finish(true,'genuine_paid_spyder_lethal_warrior_body_expiry_native89_90_pickup_five_bodies_three_verified_warriors_egress80')
  elseif f-phaseStart>180*fps then finish(false,'three_source_outputs_native_egress_timeout')end
 elseif state=='output'and f-phaseStart>fps then finish(false,'blocked_or_missing_body_output_no_acceptance')end
end
