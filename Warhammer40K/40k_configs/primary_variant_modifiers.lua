-- Native source modifier adapter. Integration requires explicit genuine EBP identities.
-- This module neither registers research nor grants resources/units/acceptance.
local M={Version=1}
local function sorted(t)local r={};for k in pairs(t or{})do r[#r+1]=k end;table.sort(r);return r end
local function finite(x)return type(x)=='number'and x==x and x>=0 and x<math.huge end
local function hash(s)local n=1;for i=1,#s do n=(n*131+s:byte(i))%16777213 end;return n end
local function near(a,b)return finite(a)and finite(b)and math.abs(a-b)<=math.max(.0001,math.abs(b)*.000001)end
local localKeys={imp_source_hq_addon_1=true,imp_source_hq_addon_2=true,ork_source_hq_addon=true}
local primitive={health_maximum_modifier=true,cost_requisition_modifier=true,production_speed_modifier=true,population_cap_player_modifier=true}
local function leaf(s)return s:match('([^/]+)%.lua$')end
local function digest(p)
 local t={p.sha256,tostring(p.time),tostring(p.cost.metal),tostring(p.cost.energy)}
 for _,e in ipairs(p.effects)do for _,k in ipairs({'slot','type','target','value','probability','exclusive','usage_type','application_type'})do t[#t+1]=tostring(e[k])end end
 return hash(table.concat(t,'|'))
end
function M.New(C,S,defs,V,config)
 config=config or{};assert(type(config.entities)=='table','Explicit native-def to source-EBP map required')
 local R={failures={},units={},dirty={},researchSignatures={},cleanupFailures={}}
 local profiles={};for k,p in pairs(V.SourceProfiles)do profiles[k]=digest(p)end
 local opts={private=true};local prefix='40k_srcmod_'
 local function squadProfile(p)for _,e in ipairs(p.effects or{})do if e.type=='enable_squad_reinforcement'or(config.ork and e.type=='max_troopers_squad_modifier')then return true end end;return false end
 local function squadSupported(k,p,e)
  local a=config.squad
  for _,name in ipairs({'Supported','PrepareEnable','ValidateEnable','CommitEnable','AbortEnable','RestoreEnable','HasEnableReceipt'})do
   if not a or type(a[name])~='function'then return false,'squad_transaction_handler_missing' end
  end
  local okay,result=pcall(a.Supported,k,p,e);return okay and result==true,'squad_effect_not_ready'
 end
 local function get(id,k)return S.GetUnitRulesParam(id,prefix..k)end
 local function put(id,k,v)S.SetUnitRulesParam(id,prefix..k,v,opts)end
 local function fresh(k,p)return p and V.SourceProfiles[k]and profiles[k]==digest(p)and profiles[k]==digest(V.SourceProfiles[k])end
 local function identity(def)
  local path=config.entities[def];if type(path)~='string'or not path:match('^attrib/ebps/.+%.lua$')then return nil end
  return leaf(path),hash(path)
 end
 local function fail(id,reason)R.failures[id or 'profile']=reason;return false,reason end
 function R.EffectSupported(k,p)
  if not fresh(k,p)then return false,'source_profile_changed' end
  if config.primary and config.primary.Owns(k)then return config.primary.Supported(k,p)end
  if config.ork and(k=='ork_source_hq_addon'or k=='ork_source_waaagh')then return config.ork.Supported(k,p)end
  for _,e in ipairs(p.effects)do
   if e.exclusive then return false,'unresolved_full_profile:'..e.type end
   if not primitive[e.type]then
    if e.type~='enable_squad_reinforcement'then return false,'unresolved_full_profile:'..e.type end
    local okay,why=squadSupported(k,p,e);if not okay then return false,why end
   else
   local usage=e.usage_type or 'tp_mod_usage_multiplication.lua'
   if not(usage:find('addition',1,true)or usage:find('percentage',1,true)or usage:find('multiplication',1,true))then return false,'unsupported_usage' end
   if not finite(e.probability)or e.probability>1 then return false,'probability' end
   if e.type=='health_maximum_modifier'and(not finite(config.expHealthScale)or type(config.otherHealth)~='function')then return false,'health_baseline_provider_required' end
   if e.type=='population_cap_player_modifier'and not(config.populationIntegrated==true and config.population and type(config.population.Capacity)=='function')then return false,'population_handler_missing' end
   if e.type=='production_speed_modifier'then
    for def,d in pairs(defs)do if identity(def)==e.target and not(finite(d.buildSpeed)and d.buildSpeed>0)then return false,'source_producer_workrate_missing' end end
   end
   if e.type=='cost_requisition_modifier'then
    -- Native setter clamps only provided fields to >=1. Refuse any affected
    -- authored baseline whose exact source price would require that clamp.
    for def,d in pairs(defs)do local target=identity(def)
     if target==e.target then
      local out,unresolved=V.FoldPlan({metal=d.metalCost},{e})
      if #unresolved>0 or not finite(out.metal)or(out.metal~=d.metalCost and out.metal<1)then return false,'native_cost_minimum' end
     end
    end
   end
   end
  end
  return true
 end
 local function alive(id,def,team)
  local hp,max,_,_,progress=S.GetUnitHealth(id)
  return hp and hp>0 and S.GetUnitDefID(id)==def and S.GetUnitTeam(id)==team,hp,max,progress
 end
 local function baseline(id,def,team,birth)
  local source,sourcehash=identity(def);if not source then return nil,'unmapped_actor' end
  local d=defs[def];if not d then return nil,'missing_definition' end
  local valid,hp,max,progress=alive(id,def,team);if not valid then return nil,'stale_actor' end
  local stamp=hash(sourcehash..'|'..def..'|'..d.health..'|'..(d.buildSpeed or 0))
  local b
  if get(id,'version')~=nil then
   if get(id,'version')~=M.Version or get(id,'identity')~=stamp then return nil,'stale_baseline' end
   for k,fp in pairs(profiles)do local applied=get(id,'profile_'..k);if applied and applied~=fp then return nil,'stale_saved_profile' end end
   b={health=get(id,'base_health'),metal=get(id,'base_metal'),energy=get(id,'base_energy'),buildTime=get(id,'base_time'),production_speed=get(id,'base_work'),price=get(id,'locked_metal'),energyprice=get(id,'locked_energy'),birth=false,def=def,source=source}
   for _,key in ipairs({'health','metal','energy','buildTime','production_speed','price','energyprice'})do if not finite(b[key])then return nil,'invalid_saved_baseline' end end
   local bt,m,e=S.GetUnitCosts(id);if not near(bt,b.buildTime)or not near(m,b.price)or not near(e,b.energyprice)then return nil,'historical_cost_changed' end
  else
   -- Restore must never discover a boosted baseline from an old completed addon.
   if not birth and config.restoreExpected and config.restoreExpected(id)then return nil,'missing_saved_baseline' end
   local bt,m,e=S.GetUnitCosts(id)
   b={health=d.health,metal=m,energy=e,buildTime=bt,production_speed=d.buildSpeed or 0,price=m,energyprice=e,birth=birth==true,def=def,source=source}
   for _,key in ipairs({'health','metal','energy','buildTime','production_speed'})do if not finite(b[key])then return nil,'invalid_native_baseline' end end
   put(id,'version',M.Version);put(id,'identity',stamp)
   for _,key in ipairs({'health','metal','energy','buildTime'})do put(id,'base_'..(key=='buildTime'and'time'or key),b[key])end
   put(id,'base_work',b.production_speed);put(id,'locked_metal',m);put(id,'locked_energy',e)
  end
  return b
 end
 local function active(id,team,k,prospective)
  if prospective and prospective.key==k and prospective.team==team then
   return prospective.producer==nil or prospective.producer==id
  end
  if localKeys[k]then
   if get(id,'failed_'..k)==1 or not(C.sourceVariantAdapter and C.sourceVariantAdapter.LocalAddon(id,team,k))then return false end
   if squadProfile(V.SourceProfiles[k])then return config.squad and config.squad.HasEnableReceipt(team,k,id)==true end
   return true
  end
  return C.HasResearch(team,k)and S.GetTeamRulesParam(team,prefix..'failed_'..k)~=1 and S.GetTeamRulesParam(team,prefix..'research_'..k)==profiles[k]
 end
 local function plan(id,b,team,prospective,birth)
  if not finite(config.expHealthScale)or type(config.otherHealth)~='function'then return nil,'health_baseline_provider_required' end
  local out={health=b.health,metal=b.metal,production_speed=b.production_speed,population_capacity=0}
  for _,k in ipairs(sorted(profiles))do if active(id,team,k,prospective)and not(config.ork and k=='ork_source_hq_addon')then
   for _,excluded in ipairs((V.ResearchConditions[k]or{}).not_research or{})do if C.HasResearch(team,excluded)or(C.reserved[team]or{})[excluded]then return nil,'exclusive_research_conflict' end end
   local p=V.SourceProfiles[k];local okay,why=R.EffectSupported(k,p);if not okay then return nil,why end
   local rows={};for _,e in ipairs(V.ModifierPlan(k,team,id,b.source))do
    -- SBP enable is a whole-effect external transaction, never actor arithmetic.
    if primitive[e.type]and not(config.primary and config.primary.Owns(k))and not(config.ork and k=='ork_source_waaagh'and e.type=='production_speed_modifier'and defs[b.def].isFactory~=true)then rows[#rows+1]=e end
   end;local unresolved
   out,unresolved=V.FoldPlan(out,rows);if #unresolved>0 then return nil,'unresolved_actor_plan' end
  end end
  if config.ork then local changed,why=config.ork.ModifyPlan(id,b,team,prospective,birth,out);if not changed then return nil,why end;out=changed end
  if config.primary then local reason;out,reason=config.primary.ModifyPlan(id,b,team,prospective,birth,out);if not out then return nil,reason end end
  if not finite(out.health)or out.health<.1 or not finite(out.production_speed)then return nil,'invalid_modifier_result' end
  local xp=0;if config.expHealthScale and config.expHealthScale>0 then
   local _,lim=S.GetUnitExperience(id);if not finite(lim)then return nil,'experience_unavailable' end;xp=lim*config.expHealthScale
  end
  local extra=config.otherHealth and config.otherHealth(id,team,b.def)or 0
  if not finite(extra)then return nil,'other_health_unverified' end
  out.trackExperience=not near(out.health+extra,b.health)
  out.health=(out.health+extra)*(1+xp)
  if not birth then out.metal=b.price end
  if not finite(out.metal)or(out.metal~=b.price and out.metal<1)then return nil,'native_cost_minimum' end
  return out
 end
 local function apply(id,b,team,out)
  local valid,hp,max=alive(id,b.def,team);if not valid then return fail(id,'actor_changed_before_apply')end
  if not near(out.metal,b.price)then
   -- Do not pass energyCost/buildTime: zero values would become 1 natively.
   S.SetUnitCosts(id,{metalCost=out.metal})
   local bt,m,e=S.GetUnitCosts(id)
   if not near(bt,b.buildTime)or not near(m,out.metal)or not near(e,b.energyprice)then return fail(id,'native_cost_readback_failed')end
   b.price=m;put(id,'locked_metal',m)
  end
  if not near(max,out.health)then
   S.SetUnitMaxHealth(id,out.health);S.SetUnitHealth(id,{health=hp/max*out.health})
   local newhp,newmax=S.GetUnitHealth(id);if not near(newmax,out.health)or not near(newhp,hp/max*out.health)then return fail(id,'native_health_readback_failed')end
  end
  if not near(get(id,'applied_work'),out.production_speed)then
   if out.production_speed~=b.production_speed or get(id,'applied_work')~=nil then S.SetUnitBuildSpeed(id,out.production_speed)end
   put(id,'applied_work',out.production_speed)
  end
  if config.primary then local okay,why=config.primary.ApplyPlan(id,out.primaryPlan);if not okay then return fail(id,why)end end
  b.birth=false;b.team=team;b.trackExperience=out.trackExperience;b.appliedHealth=out.health;R.units[id]=b;R.dirty[id]=nil;return true
 end
 function R.Register(id,def,team,birth)
  local b,why=baseline(id,def,team,birth);if not b then return fail(id,why)end
  local out,reason=plan(id,b,team,nil,b.birth);if not out then return fail(id,reason)end
  return apply(id,b,team,out)
 end
 local function prepare(team,k,producer)
  local okay,why=R.EffectSupported(k,V.SourceProfiles[k]);if not okay then return nil,why end
  local targets={};for _,id in ipairs(sorted(C.units))do local u=C.units[id]
   if u.team==team and identity(u.def)then
    local b,reason=baseline(id,u.def,team,false);if not b then return nil,reason end
    local out,error=plan(id,b,team,{key=k,team=team,producer=producer},false);if not out then return nil,error end
    targets[#targets+1]={id=id,b=b,out=out}
   end
  end
  return targets
 end
 local function snapshot(target,team)
  local id,b=target.id,target.b;local valid,hp,max=alive(id,b.def,team)
  if not valid or not finite(hp)or not finite(max)or max<=0 then return nil,'actor_changed_before_commit' end
  local bt,m,e=S.GetUnitCosts(id)
  if not near(bt,b.buildTime)or not near(m,b.price)or not near(e,b.energyprice)then return nil,'cost_changed_before_commit' end
  local work=get(id,'applied_work')
  if not finite(work)then
   if target.out.production_speed~=b.production_speed then return nil,'owned_work_baseline_missing' end
   work=b.production_speed
  end
  local primary;if config.primary then local why;primary,why=config.primary.Snapshot(id);if not primary then return nil,why end end
  return {primary=primary,id=id,hp=hp,max=max,time=bt,metal=m,energy=e,work=work,
   appliedWork=get(id,'applied_work'),price=b.price,team=b.team,birth=b.birth,
   track=b.trackExperience,appliedHealth=b.appliedHealth,unit=R.units[id],dirty=R.dirty[id],
   profile=get(id,'profile_'..target.key)}
 end
 local function rollback(team,targets,snapshots,k)
  local good=true
  for i=#targets,1,-1 do local t,a=targets[i],snapshots[i]
   if a then
    local valid=alive(t.id,t.b.def,team)
    if not valid then good=false;fail(t.id,'rollback_actor_changed')
    else
     local okay=pcall(function()
      if config.primary and not config.primary.Restore(t.id,a.primary)then error('primary_rollback_failed')end
      local bt,m,e=S.GetUnitCosts(t.id)
      if not near(bt,a.time)or not near(e,a.energy)then error('rollback_unowned_cost_fields')end
      if not near(m,a.metal)then if a.metal<1 then error('rollback_native_cost_minimum')end;S.SetUnitCosts(t.id,{metalCost=a.metal})end
      S.SetUnitMaxHealth(t.id,a.max);S.SetUnitHealth(t.id,{health=a.hp})
      if get(t.id,'applied_work')~=a.appliedWork or t.out.production_speed~=a.work then S.SetUnitBuildSpeed(t.id,a.work)end
      local hp,max=S.GetUnitHealth(t.id);local bt,m,e=S.GetUnitCosts(t.id)
      if not near(hp,a.hp)or not near(max,a.max)or not near(bt,a.time)or not near(m,a.metal)or not near(e,a.energy)then error('rollback_native_readback_failed')end
      put(t.id,'applied_work',a.appliedWork);put(t.id,'locked_metal',a.price);put(t.id,'profile_'..k,a.profile)
      t.b.price=a.price;t.b.team=a.team;t.b.birth=a.birth;t.b.trackExperience=a.track;t.b.appliedHealth=a.appliedHealth
      R.units[t.id]=a.unit;R.dirty[t.id]=a.dirty
     end)
     if not okay then good=false;fail(t.id,'rollback_native_failed')end
    end
   end
  end
  return good
 end
 local function commit(team,k,producer,targets,token)
  local snapshots={};local a=config.squad
  for i,t in ipairs(targets)do t.key=k;local row,why=snapshot(t,team);if not row then
   if token then pcall(a.AbortEnable,token)end;return false,why end;snapshots[i]=row
  end
  if token then local ok,valid=pcall(a.ValidateEnable,token);if not ok or valid~=true then pcall(a.AbortEnable,token);return false,'squad_paid_plan_changed' end end
  -- All native and cohort plans exist before the first effect setter.
  local oldGlobal=S.GetTeamRulesParam(team,prefix..'research_'..k)
  local okay,why=pcall(function()
   for _,t in ipairs(targets)do local okay,reason=apply(t.id,t.b,team,t.out);if not okay then error(reason)end end
   if token and(a.ValidateEnable(token)~=true or a.CommitEnable(token)~=true)then error('squad_commit_failed')end
   if token and a.HasEnableReceipt(team,k,producer)~=true then error('squad_receipt_readback_failed')end
   for _,t in ipairs(targets)do put(t.id,'profile_'..k,profiles[k])end
   if producer==nil then S.SetTeamRulesParam(team,prefix..'research_'..k,profiles[k],opts);S.SetTeamRulesParam(team,prefix..'failed_'..k,nil,opts)
   else put(producer,'failed_'..k,nil)end
  end)
  if not okay then
   local aborted=true;if token then local ok,result=pcall(a.AbortEnable,token);aborted=ok and result==true end
   local restored=rollback(team,targets,snapshots,k)
   if producer==nil then local ok=pcall(S.SetTeamRulesParam,team,prefix..'research_'..k,oldGlobal,opts);restored=restored and ok end
   if producer==nil then pcall(S.SetTeamRulesParam,team,prefix..'failed_'..k,1,opts)else pcall(put,producer,'failed_'..k,1)end
   return false,tostring(why)..((aborted and restored)and ':rolled_back' or ':rollback_incomplete')
  end
  if token and a.FinishEnable then
   -- Native effects and fingerprints are already verified. Cleanup owns no
   -- native effect; report its exception without misreporting a partial profile.
   local cleaned,result=pcall(a.FinishEnable,token)
   if not cleaned or result~=true then R.cleanupFailures[producer or k]='squad_finalize_failed:'..tostring(result)end
  end
  return true
 end
 local function complete(team,k,p,producer,restoring)
  if producer~=nil then
   local u=C.units[producer];local target=u and identity(u.def);local matches=false
   for _,path in ipairs((p and p.source_producers)or{})do if leaf(path)==target then matches=true end end
   local valid,hp,max,progress;if u then valid,hp,max,progress=alive(producer,u.def,team)end
   if not u or u.team~=team or not u.finished or not matches or not valid or not progress or progress<1 then return fail(producer,'invalid_source_producer')end
  end
  if not fresh(k,p)then return fail(producer,'source_profile_changed')end
  local supported,reason=R.EffectSupported(k,p);if not supported then return fail(producer,reason)end
  local localKey=localKeys[k]
  if localKey and producer==nil then return fail(nil,'local_producer_missing')end
  if not localKey and not C.HasResearch(team,k)then return fail(producer,'paid_research_missing')end
  local token
  if squadProfile(p)then
   if restoring then
    local okay,result=pcall(config.squad.RestoreEnable,team,k,p,producer)
    if not okay or result~=true then return fail(producer,'completed_squad_receipt_missing')end
   else
    local okay,result,why=pcall(config.squad.PrepareEnable,team,k,p,producer)
    if not okay or not result then return fail(producer,why or 'squad_prepare_failed')end;token=result
   end
  end
  local prepared,targets,why=pcall(prepare,team,k,localKey and producer or nil)
  if not prepared then why=targets;targets=nil end
  if not targets then if token then pcall(config.squad.AbortEnable,token)end;return fail(producer,why)end
  local okay,result,why=pcall(commit,team,k,localKey and producer or nil,targets,token)
  if not okay or result~=true then if token then pcall(config.squad.AbortEnable,token)end;return fail(producer,why or tostring(result))end;return true
 end
 function R.EffectsCompleted(team,k,p,producer)return complete(team,k,p,producer,false)end
 function R.RestoreCompleted(team,k,p,producer)
  if localKeys[k]and producer and not(C.sourceVariantAdapter and C.sourceVariantAdapter.LocalAddon(producer,team,k))then return fail(producer,'completed_local_receipt_missing')end
  if not localKeys[k]and not R.IsApplied(team,k)then return fail(nil,'completed_global_receipt_missing')end
  return complete(team,k,p,producer,true)
 end
 function R.InstantSupported(k)return k=='ork_source_clan_armageddon'and R.EffectSupported(k,V.SourceProfiles[k])end
 function R.PrepareInstant(team,k)
  if not R.InstantSupported(k)then return nil end
  -- Preparation reads only: no baseline writes before real payment.
  for _,id in ipairs(sorted(C.units))do local u=C.units[id];if u.team==team and identity(u.def)and get(id,'version')==nil then return nil,'register_before_payment' end end
  local targets=prepare(team,k,nil);if not targets then return nil end
  return function()return commit(team,k,nil,targets)end
 end
 function R.Remove(id)R.units[id]=nil;R.dirty[id]=nil;R.failures[id]=nil end
 function R.ResearchChanged(team)for id,b in pairs(R.units)do if S.GetUnitTeam(id)==team then R.dirty[id]=true end end end
 function R.UnitExperience(id)if R.units[id]then R.dirty[id]=true end end
 function R.Frame(frame)
  if config.primary then config.primary.Frame(frame)end
  local teams={};for _,u in pairs(C.units)do teams[u.team]=true end
  for team in pairs(teams)do local signature=table.concat(sorted(C.done[team]),'|');if R.researchSignatures[team]~=signature then R.ResearchChanged(team);R.researchSignatures[team]=signature end end
  -- Experience callback precedes native max-health rewrite: defer to next frame.
  for _,id in ipairs(sorted(R.units))do local b=R.units[id];local u=C.units[id]
   if not u then R.Remove(id)
   else
    if (config.expHealthScale or 0)>0 and b.trackExperience then local hp,max=S.GetUnitHealth(id);if not hp or hp<=0 then R.Remove(id)elseif not near(max,b.appliedHealth)then R.dirty[id]=true end end
    if R.units[id]and(R.dirty[id]or b.team~=u.team)then
    local out,why=plan(id,b,u.team,nil,false);if out then apply(id,b,u.team,out);b.team=u.team else fail(id,why)end
    end
   end
  end
 end
 function R.IsApplied(team,k,producer)
  if not R.EffectSupported(k,V.SourceProfiles[k])then return false end
  if producer and get(producer,'failed_'..k)==1 or not producer and S.GetTeamRulesParam(team,prefix..'failed_'..k)==1 then return false end
  for _,excluded in ipairs((V.ResearchConditions[k]or{}).not_research or{})do if C.HasResearch(team,excluded)or(C.reserved[team]or{})[excluded]then return false end end
  if squadProfile(V.SourceProfiles[k])and not(config.squad and config.squad.HasEnableReceipt(team,k,producer)==true)then return false end
  if localKeys[k]then return producer~=nil and C.sourceVariantAdapter and C.sourceVariantAdapter.LocalAddon(producer,team,k)and get(producer,'profile_'..k)==profiles[k]end
  return C.HasResearch(team,k)and S.GetTeamRulesParam(team,prefix..'research_'..k)==profiles[k]
 end
 function R.UnitCreated(id,def,team)
  -- Call before the shared controller captures health/charges construction.
  local b,why=baseline(id,def,team,true);if not b then return fail(id,why)end
  S.SetUnitRulesParam(id,'40k_rbase_health',b.health,opts)
  local out,reason=plan(id,b,team,nil,true);if not out then return fail(id,reason)end
  return apply(id,b,team,out)
 end
 function R.BindLifecycle()
  assert(not R.bound,'Modifier lifecycle already bound');R.bound=true
  local register,remove,frame=C.Register,C.Remove,C.Frame
  function C.Register(id,def,team,finished)
   if identity(def)then local b,why=baseline(id,def,team,false);if not b then fail(id,why);return false end
    -- Exact saved source base, not an already boosted native current maximum.
    S.SetUnitRulesParam(id,'40k_rbase_health',b.health,opts)
    if C.baselines[id]then C.baselines[id].health=b.health end
   end
   register(id,def,team,finished)
   if identity(def)then return R.Register(id,def,team,false)end
  end
  function C.Remove(id,dead)local result=remove(id,dead);if dead then R.Remove(id)end;return result end
  function C.Frame(frameNumber)frame(frameNumber);R.Frame(frameNumber)end
 end
 function R.Hooks()return {EffectSupported=R.EffectSupported,EffectsCompleted=R.EffectsCompleted,RestoreCompleted=R.RestoreCompleted,InstantSupported=R.InstantSupported,PrepareInstant=R.PrepareInstant}end
 return R
end
return M
