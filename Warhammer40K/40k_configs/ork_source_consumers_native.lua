-- Opt-in full source consumers. No definition/assets edits or scripted births.
local M={key='ork_source_hq_addon',waaagh='ork_source_waaagh'}
local function copy(t)local o={};for k,v in pairs(t or{})do o[k]=type(v)=='table'and copy(v)or v end;return o end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
function M.Enabled(o)return VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)and o.prototype_diagnostic=='expandedproduction'and tostring(o.prototype_ork_source_consumers_review)=='1'end
function M.New(C,S,D,V,g,CMD,fps,Native,evidence)
 local P=VFS.Include('40k_configs/ork_source_consumer_proposal.lua')
 local W=VFS.Include('40k_configs/ork_waaagh_paid_queue_proposal.lua')
 local HQ=VFS.Include('40k_configs/ork_hq_exclusive_cohorts.lua')
 local F=VFS.Include('40k_configs/ork_stormboy_factory_receipts.lua')
 local A=VFS.Include('40k_configs/ork_paid_clock_native_adapter.lua')
 local R={pending={},homes={},reinforce={},combat={},failures={}};local ledger,found,manager,population
 local entities={};for def,d in pairs(D)do entities[def]=(d.customParams or{}).source_entity end
 local function verified(def,path)
  local d=D[def];local cp=d and d.customParams or{};local e=d and evidence and(evidence.entries or{})[d.name]
  return evidence and evidence.version==1 and e and e.reviewed==true and e.source_entity==path and cp.source_entity==path
   and e.asset==cp.animsource and(d.modelname==e.asset..'.glb'or d.modelname=='objects3d/'..e.asset..'.glb') and type(e.source_model_sha256)=='string'and #e.source_model_sha256==64 and e.source_model_sha256==cp.source_model_sha256
   and type(e.generated_glb_sha256)=='string'and #e.generated_glb_sha256==64 and e.generated_glb_sha256==cp.source_native_glb_sha256
   and VFS.FileExists('objects3d/'..e.asset..'.glb')and VFS.FileExists('scripts/generated/'..e.asset..'_anim.lua')
   and e.metal==d.metalCost and e.energy==d.energyCost and e.health==d.health and e.buildTime==d.buildTime
 end
 function R.FilterEntities(input)
  local out={};for def,path in pairs(input)do if path:find('attrib/ebps/races/orks/',1,true)~=1 or verified(def,path)==true then out[def]=path end end;return out
 end
 local function hqSupported()
  if R.failed then return false,'saved_transaction_failed'end
  local hooks={localHealth=true,stormboyHealth=true,futureSluggaPrice=true,hardpoint3=true,hardpoint4=true,population20=true,genuineStormboyCohort=true,paidBirth=true,paidReinforcement=true,capture=true,save=true,rollback=true}
  local okay,why=HQ.Supported(V,P,entities,verified,hooks);if not okay then return false,why end
  local producer=false;local producerRate;local stormRow
  for def,path in pairs(entities)do
   if path==F.producer and verified(def,path)and D[def].isFactory==true and D[def].buildSpeed>0 then producer=true;producerRate=D[def].buildSpeed end
   if path==F.entity and verified(def,path)then stormRow=(evidence.entries or{})[D[def].name]end
   if path==F.entity and verified(def,path)and(D[def].health~=670 or D[def].metalCost~=50 or D[def].energyCost~=0)then return false,'source_stormboy_contract'end
   if path=='attrib/ebps/races/orks/troops/ork_slugga_boy.lua'and verified(def,path)and D[def].metalCost~=30 then return false,'source_slugga_price'end
   if path=='attrib/ebps/races/orks/structures/ork_hq.lua'and verified(def,path)then
    if D[def].health~=6000 or #(D[def].weapons or{})~=4 then return false,'source_hq_health_or_mounts'end
    for _,m in ipairs(D[def].weapons)do local w=WeaponDefs and WeaponDefs[m.weaponDef];if not w or(w.customParams or{}).source_weapon_profile~='attrib/weapon/ork_shoota_turret.lua'then return false,'source_hq_weapon_profile'end end
   end
  end
  if not stormRow or stormRow.seconds~=7 or stormRow.native_workrate~=producerRate or stormRow.buildTime~=7*producerRate then return false,'source_stormboy_time_contract'end
  return producer,'genuine_paid_stormboy_factory_missing'
 end
 function R.Supported(key,p)
  if key==M.key then return hqSupported()end
  if key==M.waaagh then
   if not hqSupported()then return false,'full_hq_transaction_missing'end
   return W.Supported(V,entities,verified,{factory=true,recruit=true,research=true,addon=true,birth=true,capture=true,rollback=true,save=true})
  end
  return false,'outside_ork_consumer_scope'
 end
 local receiptKey='40k_ork_paid_hq_receipt_v1';local snapshotKey='40k_ork_consumers_snapshot_v1'
 local function paidReceipt(id,team)
  local r=Native.Decode(S.GetUnitRulesParam(id,receiptKey));local p=V.SourceProfiles[M.key]
  return r and r.id==id and r.team==team and r.def==S.GetUnitDefID(id)and r.source==p.sha256 and r.frames==p.time*fps and r.metal==300 and r.energy==400 and type(r.tag)=='number'and r.tag>=0 and r or nil
 end
 local function paidJob(job,id,team)
  local current=C.sourceVariantAddonJobs and(C.sourceVariantAddonJobs.jobs[id]or{})[M.key];local p=V.SourceProfiles[M.key]
  local head=(S.GetUnitCommands(id,-1)or{})[1]
  return job and job==current and job.key==M.key and job.team==team and job.def==S.GetUnitDefID(id)and job.steps==p.time*fps
   and job.frames==p.time*fps and job.cost.metal==300 and job.cost.energy==400 and job.metal==300 and job.energy==400
   and head and head.id==job.cmd and head.tag==job.tag and job.active==true or false
 end
 local H={Ready=function()return hqSupported()==true end,Verified=verified,
  PaidAddon=function(job,id,team)return paidJob(job,id,team)end,
  RestoreAddon=function(proof,id,team)return proof=='native_private_receipt'and paidReceipt(id,team)~=nil and C.sourceVariantAdapter.LocalAddon(id,team,M.key)==true end,
  PaidCohort=function(token,seed,team,ids,squad)return found.Claim(token,seed,team,ids,squad)end,
  PaidReinforcement=function(token,seed,id,team,cost)return cost.metal==50 and cost.energy==0 and cost.time==7 and found.ClaimSingle(token,id,team)end,
  RestoreCohort=function(proof,seed,team,ids,squad)
   if proof~='native_private_receipt'or squad~=F.squad then return false end
   for _,id in ipairs(ids)do
    if S.GetUnitRulesParam(id,'40k_ork_cohort_seed')~=seed or S.GetUnitRulesParam(id,'40k_ork_cohort_team')~=team then return false end
    local _,m,e=S.GetUnitCosts(id);if m~=50 or e~=0 then return false end
   end;return true
  end}
 ledger=HQ.New(S,C,D,V,P,H);R.ledger=ledger
 found=F.New(S,C,D,{Ready=H.Ready,Verified=verified,
  NativeCostContract=function(def,time,m,e,seconds)
   local d=D[def];local row=d and(evidence.entries or{})[d.name]
   return row and row.seconds==seconds and row.native_workrate and time==seconds*row.native_workrate and time==d.buildTime and m==50 and e==0
  end,RestoreProof=function(proof)return proof=='native_private_receipt'end});R.found=found
 function R.ModifyPlan(id,b,team,prospective,birth,out)
  if hqSupported()~=true then return out end
  if entities[b.def]and verified(b.def,entities[b.def])then
   local t=prospective and prospective.key==M.key and R.pending[prospective.producer]
   local p,why=ledger.Plan(id,team,birth,t and t.ledger)
   if not p then return nil,why end
   out.health=out.health+p.healthAddition;out.metal=out.metal+p.requisitionAddition
   -- Native source reinforcement uses ordinary paid factory products. Only the
   -- current assigned Stormboy product receives documented combat time x2.
   local product=S.GetUnitIsBuilding(id);local seed=product and R.reinforce[product]
   if seed and R.InCombat(seed,S.GetGameFrame())then out.production_speed=out.production_speed*.5 end
  end
  return out
 end
 function R.Composite(other)
  local B={};local function dispatch(name,...)
   local args={...};local key=args[2]
   if name=='Supported'then key=args[1]end
   if key==M.key then return R[name](...)end
   return other and other[name]and other[name](...)or false
  end
  for _,name in ipairs({'Supported','PrepareEnable','RestoreEnable','HasEnableReceipt'})do local n=name;B[n]=function(...)return dispatch(n,...)end end
  for _,name in ipairs({'ValidateEnable','CommitEnable','AbortEnable','FinishEnable'})do local n=name
   B[n]=function(token)if type(token)=='table'and token.ork==R then return R[n](token)end;return other and other[n]and other[n](token)or false end
  end
  return B
 end
 function R.PrepareEnable(team,key,p,id)
  if key~=M.key or R.Supported(key,p)~=true then return nil,'full_profile_closed'end
  local job=C.sourceVariantAddonJobs and(C.sourceVariantAddonJobs.jobs[id]or{})[key]
  local token,why=ledger.Prepare(id,team,job);if not token then return nil,why end
  local pieces=S.GetUnitPieceMap(id)or{}
  for _,region in ipairs({'left','right','hull','main'})do for _,part in ipairs({'marker_turret_','aim_horz_','turret_','turret_barrel_'})do if type(pieces[part..region])~='number'then ledger.Abort(token);return nil,'genuine_hq_piece_missing'end end end
  local t={ork=R,id=id,team=team,ledger=token,job=job,prior=S.GetUnitRulesParam(id,receiptKey)};R.pending[id]=t;return t
 end
 function R.ValidateEnable(t)return t and t.ork==R and R.pending[t.id]==t and ledger.Validate(t.ledger)==true end
 function R.CommitEnable(t)
  if not R.ValidateEnable(t)or not ledger.Commit(t.ledger)then return false end
  local p=V.SourceProfiles[M.key];local r={id=t.id,team=t.team,def=t.job.def,source=p.sha256,frames=t.job.frames,metal=t.job.metal,energy=t.job.energy,tag=t.job.tag}
  local encoded=Native.Encode(r);S.SetUnitRulesParam(t.id,receiptKey,encoded,{private=true})
  return S.GetUnitRulesParam(t.id,receiptKey)==encoded
 end
 function R.AbortEnable(t)
  if not t or t.ork~=R then return false end
  local okay=ledger.Abort(t.ledger);S.SetUnitRulesParam(t.id,receiptKey,t.prior,{private=true});R.pending[t.id]=nil
  return okay and S.GetUnitRulesParam(t.id,receiptKey)==t.prior
 end
 function R.FinishEnable(t)R.pending[t.id]=nil;return true end
 function R.HasEnableReceipt(team,key,id)
  if key~=M.key or not id or not paidReceipt(id,team)then return false end
  local plan=ledger.Plan(id,team,false);return plan and plan.localCapacity==20 or false
 end
 function R.RestoreEnable(team,key,p,id)
  if key~=M.key or not paidReceipt(id,team)then return false end
  local snapshot=ledger.Snapshot();snapshot.addons[id]={team=team}
  return ledger.Restore(snapshot,'native_private_receipt')
 end
 function R.InCombat(seed,now)
  local c=ledger.Snapshot().cohorts[seed];if not c then return false end
  -- Documented native combat evidence window5s after genuine positive damage.
  for _,id in ipairs(c.ids)do local f=R.combat[id];if f and now>=f and now-f<5*fps then return true end end
  return false
 end
 local function choose(team,builder)
  local snapshot=ledger.Snapshot();local seeds={};for seed,c in pairs(snapshot.cohorts)do if c.team==team then seeds[#seeds+1]=seed end end;table.sort(seeds)
  for _,seed in ipairs(seeds)do local c=snapshot.cohorts[seed];local cap=ledger.Capacity(seed);local reservations=0;for _,target in pairs(R.reinforce)do if target==seed then reservations=reservations+1 end end
   if cap and #c.ids+reservations<cap then return seed end
  end
 end
 function R.Birth(id,def,team,builder)
  if entities[def]~=F.entity then return true end
  if not found.Created(id,def,team,builder)then R.failures[id]='source_factory_birth_refused';return false end
  R.reinforce[id]=choose(team,builder);return true
 end
 local function stamp(seed,team,ids)
  for _,id in ipairs(ids)do S.SetUnitRulesParam(id,'40k_ork_cohort_seed',seed,{private=true});S.SetUnitRulesParam(id,'40k_ork_cohort_team',team,{private=true})end
 end
 function R.Factory(id,def,team,builder)
  if entities[def]~=F.entity then return true end
  local seed=R.reinforce[id];local c=seed and ledger.Snapshot().cohorts[seed];local cap=seed and ledger.Capacity(seed)
  if seed and(not c or not cap or #c.ids>=cap)then seed=nil;R.reinforce[id]=nil end
  local okay,token,newSeed,ids=found.FromFactory(id,def,team,builder,seed~=nil)
  if not okay then R.failures[id]='paid_factory_finish_refused';return false end
  if seed then
   if not ledger.ReinforcementBirth(seed,id,token)then R.failures[id]='paid_reinforcement_admission_refused';return false end
   stamp(seed,team,{id});found.Remove(id)
  elseif token then
   if not ledger.CohortBirth(newSeed,team,ids,token)then R.failures[id]='paid_cohort_admission_refused';return false end
   R.homes[newSeed]=builder;stamp(newSeed,team,ids);for _,member in ipairs(ids)do found.Remove(member)end
  end
  R.reinforce[id]=nil;return true
 end
 function R.AllowCreation(team,def,builder)
  if entities[def]~=F.entity then return true end
  local a=builder and C.units[builder]
  return hqSupported()==true and population and population.Get(team)>=50 and a and a.finished and a.team==team and entities[a.def]==F.producer and verified(a.def,F.producer)and D[a.def].isFactory==true or false
 end
 function R.Damaged(id,damage,attacker)
  if type(damage)=='number'and damage>0 then local now=S.GetGameFrame();local u=C.units[id];if u and entities[u.def]==F.entity then R.combat[id]=now end;local a=attacker and C.units[attacker];if a and entities[a.def]==F.entity then R.combat[attacker]=now end end
 end
 function R.Removed(id,captured)
  local a=C.units[id];for product,b in pairs(found.Snapshot().births)do if b.builder==id then R.reinforce[product]=nil end end;ledger.Remove(id,captured);found.Remove(id);R.reinforce[id]=nil;R.combat[id]=nil;R.pending[id]=nil
  if captured and entities[S.GetUnitDefID(id)]=='attrib/ebps/races/orks/structures/ork_hq.lua'then
   S.SetUnitRulesParam(id,'40k_source_addon_'..M.key,0,{allied=true});S.SetUnitRulesParam(id,'40k_source_addon_source_'..M.key,0,{private=true});S.SetUnitRulesParam(id,'40k_addon_failed_'..M.key,0,{private=true});S.SetUnitRulesParam(id,receiptKey,nil,{private=true})
  end
  local live=ledger.Snapshot().cohorts;for seed in pairs(R.homes)do if not live[seed]then R.homes[seed]=nil end end;for product,seed in pairs(R.reinforce)do if not live[seed]then R.reinforce[product]=nil end end
  if a and manager then manager.ResearchChanged(a.team)end
 end
 function R.Snapshot()return{version=1,ledger=ledger.Snapshot(),found=found.Snapshot(),homes=copy(R.homes),reinforce=copy(R.reinforce),combat=copy(R.combat)}end
 function R.Restore(saved)
  if type(saved)~='table'or saved.version~=1 then return false end
  if type(saved.ledger)~='table'or type(saved.found)~='table'or type(saved.homes)~='table'or type(saved.reinforce)~='table'or type(saved.combat)~='table'then return false end
  local cohorts=saved.ledger.cohorts or{}
  for seed,builder in pairs(saved.homes)do if type(seed)~='number'or seed%1~=0 or type(builder)~='number'or builder%1~=0 or not cohorts[seed]then return false end end
  for id,seed in pairs(saved.reinforce)do local b=(saved.found.births or{})[id];local c=cohorts[seed]
   if not b or b.claimed or not c or b.team~=c.team then return false end
  end
  for id,at in pairs(saved.combat)do local u=C.units[id]
   if not u or entities[u.def]~=F.entity or type(at)~='number'or at<0 or at%1~=0 or at>S.GetGameFrame()then return false end
  end
  local before=R.Snapshot()
  if not ledger.Restore(saved.ledger,'native_private_receipt')or not found.Restore(saved.found,'native_private_receipt')then
   ledger.Restore(before.ledger,'native_private_receipt');found.Restore(before.found,'native_private_receipt');return false
  end
  R.homes=copy(saved.homes);R.reinforce=copy(saved.reinforce);R.combat=copy(saved.combat);return true
 end
 function R.Save()
  local text=Native.Encode(R.Snapshot());if text~=R.last then S.SetGameRulesParam(snapshotKey,text,{private=true});if S.GetGameRulesParam(snapshotKey)~=text then R.failed=true;return false end;R.last=text end;return true
 end
 function R.RestoreSaved()
  local text=S.GetGameRulesParam(snapshotKey);if text==nil then return true end
  local saved=Native.Decode(text);if not saved or not R.Restore(saved)then R.failed=true;return false end;R.last=text;return true
 end
 function R.Bind(m,pop)
  manager=m;population=pop
  A.Attach(C,S,D,V,{Ready=function()return R.Supported(M.waaagh,V.SourceProfiles[M.waaagh])==true end,Verified=verified,Applied=function(team,key)return manager.IsApplied(team,key)==true end},W)
  local allow=C.Allow
  function C.Allow(id,def,team,cmd,params,options)
   local r=C.commands[cmd==CMD.INSERT and params and params[2]or cmd]
   if r and(r.key==M.key or r.key==M.waaagh)and(R.Supported(r.key,V.SourceProfiles[r.key])~=true or verified(def,entities[def])~=true or entities[def]~='attrib/ebps/races/orks/structures/ork_hq.lua')then return false end
   if r and r.key==M.waaagh and manager.IsApplied(team,M.key,id)~=true then return false end
   return allow(id,def,team,cmd,params,options)
  end
  local frame=C.Frame
  function C.Frame(n)
   for id,a in pairs(C.units)do if D[a.def].isFactory and verified(a.def,entities[a.def])then manager.dirty[id]=true end end
   frame(n);R.Save()
  end
  C.sourceOrkLifecycle=R
 end
 return R
end
return M
