-- Real native lifecycle composition. Candidates remain subject to acceptance gates.
local M={}
-- Deterministic data-only snapshot encoding. No Lua source/loadstring execution.
function M.Encode(value)
 local seen={};local size=0
 local function enc(v,depth)
  assert(depth<=32,'Snapshot depth exceeded');local t=type(v);local out
  if t=='boolean'then out=v and 'b1'or'b0'
  elseif t=='number'then assert(v==v and math.abs(v)<math.huge,'Nonfinite snapshot');local n=string.format('%.17g',v);out='n'..#n..':'..n
  elseif t=='string'then out='s'..#v..':'..v
  elseif t=='table'then
   assert(not seen[v]and getmetatable(v)==nil,'Snapshot must be plain acyclic data');seen[v]=true
   local keys={};for k in pairs(v)do assert(type(k)=='number'or type(k)=='string','Snapshot key type');keys[#keys+1]=k end
   table.sort(keys,function(a,b)if type(a)~=type(b)then return type(a)<type(b)end;return a<b end)
   local parts={'t'..#keys..':'};for _,k in ipairs(keys)do parts[#parts+1]=enc(k,depth+1);parts[#parts+1]=enc(v[k],depth+1)end
   seen[v]=nil;out=table.concat(parts)
  else error('Unsupported snapshot value')end
  size=size+#out;assert(size<=2097152,'Snapshot too large');return out
 end
 local result=enc(value,0);assert(#result<=1048576,'Snapshot too large');return result
end
function M.Decode(text)
 if type(text)~='string'or #text>1048576 then return nil end
 local at=1;local nodes=0
 local function dec(depth)
  assert(depth<=32,'Snapshot depth exceeded');nodes=nodes+1;assert(nodes<=100000,'Snapshot node bound')
  local t=text:sub(at,at);at=at+1
  if t=='b'then local b=text:sub(at,at);at=at+1;assert(b=='0'or b=='1','Invalid boolean');return b=='1'end
  assert(t=='t'or t=='s'or t=='n','Invalid data tag')
  local stop=text:find(':',at,true);assert(stop and stop-at<=8,'Invalid length')
  local raw=text:sub(at,stop-1);assert(raw:match('^%d+$'),'Invalid length');local n=tonumber(raw);at=stop+1
  if t=='t'then
   assert(n<=100000,'Invalid table length');local out={}
   for i=1,n do local k=dec(depth+1);assert(type(k)=='number'or type(k)=='string','Invalid key');assert(out[k]==nil,'Duplicate key');out[k]=dec(depth+1)end;return out
  end
  assert(n>=(t=='s'and 0 or 1)and at+n-1<=#text,'Truncated data');local value=text:sub(at,at+n-1);at=at+n
  if t=='s'then return value end
  local number=tonumber(value);assert(number and number==number and math.abs(number)<math.huge and string.format('%.17g',number)==value,'Noncanonical number');return number
 end
 local okay,value=pcall(dec,0);if not okay or at~=#text+1 then return nil end;return value
end
function M.Attach(C,S,defs,V,g,marine,marineGraph,CMD,fps,Q,O)
 local policy=VFS.Include('40k_configs/40k_experience_policy.lua').Read()
 local healthScale=assert(policy.healthScale,'Actual experience policy required')
 assert(type(healthScale)=='number' and healthScale>=0 and type(C.HealthBonus)=='function','Verified common health provider required')
 local entities,targets,paths={},{},{}
 for def,d in pairs(defs)do
  local path=(d.customParams or{}).source_entity
  if type(path)=='string'and path:match('^attrib/ebps/.+%.lua$')then
   entities[def]=path;paths[path]=true;targets[path:match('([^/]+)%.lua$')]=true
  end
 end
 local manager,marinePopulation,bike
 local ork=O and VFS.Include('40k_configs/ork_source_consumers_native.lua').New(C,S,defs,V,g,CMD,fps,M,O)
 local lifecycle={failures={},command=Q and Q.command}
 local function ready()return Q and type(Q.Ready)=='function'and Q.Ready()==true and not lifecycle.failed end
 if Q then
  assert(type(Q.WholeTransactionReady)=='function'and type(Q.populationPolicy)=='table','Explicit whole-effect/population policy required')
  local bikeEntity=VFS.Include('40k_configs/primary_addon_mechanics_facts.lua').bike.source_entity
  lifecycle.bikeEntity=bikeEntity
  local pop={};for k,v in pairs(Q.populationPolicy)do pop[k]=v end
  pop.fps=fps;pop.Ready=ready
  pop.AppliedResearch=function(team,path,sha)
   for key,p in pairs(V.SourceProfiles)do if p.source==path and p.sha256==sha then return manager and manager.IsApplied(team,key)==true or false end end
   return false -- Unimplemented source cap research never receives a no-op unlock.
  end
  pop.PaidReinforcementBirth=function(id,def,team,builder,seed)
   local receipt=bike and bike.births[id];local R=bike and bike.controller
   local cohortSeed=R and R.member[builder];local j=R and R.jobs[cohortSeed]
   local head=(S.GetUnitCommands(builder,-1)or{})[1]
   return receipt and receipt.team==team and receipt.def==def and receipt.builder==builder
    and marinePopulation.member[builder]==seed and j and j.paid==1 and j.steps==10*fps and j.metal==80 and j.energy==40
    and head and head.id==Q.command and head.tag==j.tag or false
  end
  marinePopulation=VFS.Include('40k_configs/40k_marine_population.lua').New(C,S,defs,
   assert(Q.PopulationFacts,'Explicit audited population facts required'),pop)
  local b={facts=VFS.Include('40k_configs/primary_addon_mechanics_facts.lua'),
   cohortModule=VFS.Include('40k_configs/40k_marine_bike_cohorts.lua'),command=Q.command,combatEvidenceFrames=Q.combatEvidenceFrames}
  b.Ready=ready;b.WholeTransactionReady=Q.WholeTransactionReady
  b.PopulationAllowed=function(team,seed)
   local c=bike and bike.controller.cohorts[seed];local budget=c and marinePopulation.member[c.leader]
   return budget and marinePopulation.AuthorizeReinforcementOwnedBudget(team,budget)or false
  end
  b.Applied=function(team,key,id)return manager and manager.IsApplied(team,key,id)==true or false end
  bike=VFS.Include('40k_configs/40k_marine_bike_native.lua').Attach(C,S,defs,V,g,CMD,fps,b)
 end
 local population=V.Population(C,S,g.Bindings,fps,true,function(team,key)
  return manager and manager.IsApplied(team,key)and S.GetTeamRulesParam(team,'40k_source_effect_failed_'..key)~=1
 end,ork and function(team)local n=0;for id,u in pairs(C.units)do if u.team==team and manager and manager.IsApplied(team,'ork_source_hq_addon',id)then n=n+1 end end;return n end or nil)
 local primary
 if VFS.FileExists('40k_configs/ork_primary_research_facts.lua')then
  local F=V.PrimaryResearchFacts or VFS.Include('40k_configs/ork_primary_research_facts.lua');local enabled=false;for k in pairs(F.profiles)do if V.SourceProfiles[k]then enabled=true end end
  if enabled then local extra;if VFS.FileExists('40k_configs/ork_primary_research_extra_native.lua')then extra=VFS.Include('40k_configs/ork_primary_research_extra_native.lua').New(C,S,defs,WeaponDefs,F,M,Game.armorTypes)end;primary=VFS.Include('40k_configs/ork_primary_research_native.lua').New(C,S,defs,WeaponDefs,F,M,Game.armorTypes,extra)end
 end
 manager=VFS.Include('40k_configs/primary_variant_modifiers.lua').New(C,S,defs,V,{
  entities=ork and ork.FilterEntities(entities)or entities,expHealthScale=healthScale,population=population,populationIntegrated=true,
  squad=ork and ork.Composite(bike)or bike,ork=ork,primary=primary,
  otherHealth=function(id,team,def)return C.HealthBonus(team,def)end,
  restoreExpected=function(id)
   local team=S.GetUnitTeam(id)
   for key,p in pairs(V.SourceProfiles)do
    if #p.effects>0 and(C.HasResearch(team,key)or S.GetUnitRulesParam(id,'40k_source_addon_'..key)==1)then return true end
   end
   return false
  end,
 })
 if primary then primary.Bind(manager);C.sourcePrimaryResearch=primary end
 local hooks=manager.Hooks();local supported=hooks.EffectSupported
 function hooks.EffectSupported(key,p)
  -- Missing native identities cannot silently turn a full upgrade into a subset.
  -- Source producers are alternatives; the actual paid job still validates its
  -- exact living owning producer. Do not demand absent campaign alternatives.
  local producers=p.source_producers or{};local eligible=#producers==0
  for _,path in ipairs(producers)do if paths[path]then eligible=true end end
  if not eligible then return false,'unmapped_source_producer' end
  if primary and primary.Owns(key)then return supported(key,p)end
  if ork and(key=='ork_source_hq_addon'or key=='ork_source_waaagh')then return supported(key,p)end
  for _,e in ipairs(p.effects)do
   if e.type=='enable_squad_reinforcement'then
    if not bike or bike.Supported(key,p,e)~=true then return false,'unmapped_source_squad_effect' end
   elseif e.target~=''and not targets[e.target]then return false,'unmapped_source_effect_target:'..e.target end
  end
  return supported(key,p)
 end
 local instant=hooks.InstantSupported
 function hooks.InstantSupported(key)return hooks.EffectSupported(key,V.SourceProfiles[key])and instant(key)end
 hooks.Population=population.Get
 hooks.ResearchApplied=function(team,key)
  local p=V.SourceProfiles[key]
  if S.GetTeamRulesParam(team,'40k_source_effect_failed_'..key)==1 then return false end
  if primary and primary.Owns(key)then return manager.IsApplied(team,key)end
  return not p or #p.effects==0 or manager.IsApplied(team,key)
 end
 local adapter=V.Attach(C,S,defs,g,hooks,CMD)
 hooks.SourceProfiles=V.SourceProfiles;hooks.ResearchConditions=V.ResearchConditions
 VFS.Include('40k_configs/primary_variant_addon_jobs.lua').Attach(C,S,defs,g,adapter,hooks,CMD,fps)
 if ork then ork.Bind(manager,population)end
 marine.Attach(C,defs,marineGraph)
 manager.BindLifecycle()
 local frame=C.Frame
 function C.Frame(n)frame(n);population.Frame(n);if marinePopulation then marinePopulation.Frame(n);bike.Frame(n)end end
 C.sourceVariantModifiers=manager;C.sourceVariantPopulation=population
 if Q then
  local function failed(why)lifecycle.failed=true;lifecycle.failures[#lifecycle.failures+1]=why;return false end
  local function tracked(def)return Q.populationPolicy.descriptors and Q.populationPolicy.descriptors[def]~=nil end
  lifecycle.creationRefusals={}
  function lifecycle.AllowCreation(team,def,builder)
   if tracked(def)then
    if builder then lifecycle.creationRefusals[builder]=nil end
    if not ready()then return false,'policy_not_ready'end
    -- Preserve ReserveInitial's typed reason. This is admission, not an extra
    -- population reservation or an attempt to override BAR's drop-order policy.
    local allowed,reason=marinePopulation.ReserveInitial(team,def,builder)
    if not allowed and reason=='source_capacity'and builder then
     local row=(S.GetFactoryCommands(builder,-1)or{})[1]
     local descriptor=Q.populationPolicy.descriptors[def]
     local source=descriptor and Q.PopulationFacts.squads[descriptor.squad]
     local i,s=marinePopulation.Usage(team);local ci,cs=marinePopulation.Capacity(team)
     -- ReserveInitial already checked the real finished source producer, native
     -- queue head and complete coverage. Retain only the precise failed request.
     if row and row.id==-def and type(row.tag)=='number'and row.tag>0 and row.tag==math.floor(row.tag)
      and not S.GetUnitIsBuilding(builder)and not marinePopulation.reservations[builder]
      and source and ci and cs and(i+source.infantry>ci or s+source.support>cs)then
      lifecycle.creationRefusals[builder]={reason=reason,policy='stock_drop_order',frame=S.GetGameFrame(),team=team,def=def,
       builder=builder,tag=row.tag,head=row.id,infantry=i,support=s,capInfantry=ci,capSupport=cs,
       requestedInfantry=source.infantry,requestedSupport=source.support,squad=descriptor.squad,sha256=source.sha256}
     end
    end
    return allowed,reason
   end
   local path=((defs[def]or{}).customParams or{}).source_entity or ''
   if path:find('attrib/ebps/races/space_marines/troops/',1,true)==1 then return false,'unknown_source_marine'end
   return true
  end
  lifecycle.birthFailures={}
  function lifecycle.Birth(id,def,team,builder)
   local isBike=((defs[def]or{}).customParams or{}).source_entity==lifecycle.bikeEntity
   local witness,witnessReason=bike.BirthBeforeRegister(id,def,team,builder)
   if bike.births[id]then
    local seed=marinePopulation.member[builder]
    if not witness or not marinePopulation.ClaimPaidReinforcementBirth(id,def,team,builder,seed)then
     local hp,_,_,_,built=S.GetUnitHealth(id);local bt,m,e=S.GetUnitCosts(id)
     lifecycle.birthFailures[id]={reason='paid_birth_population_refused',frame=S.GetGameFrame(),witness=witness==true,witnessReason=witnessReason,
      def=def,team=team,builder=builder,budget=seed,health=hp,buildProgress=built,work=bt,metal=m,energy=e,member=marinePopulation.member[id]}
     return failed('paid_birth_population_refused')
    end
   elseif tracked(def)then
    if isBike and not witness then return failed('bike_initial_witness_refused')end
    if not marinePopulation.ClaimActualFactoryBirth(id,def,team,builder)then return failed('initial_population_refused')end
   end
   return true
  end
  function lifecycle.Factory(id,def,team,builder)
   if tracked(def)then
    if not marinePopulation.CompleteInitial(id,def,team,builder)then return failed('factory_population_refused')end
    if ((defs[def]or{}).customParams or{}).source_entity==lifecycle.bikeEntity and not bike.UnitFromFactory(id,def,team,builder)then return failed('bike_factory_witness_refused')end
   end
   return true
  end
  function lifecycle.Removed(id)lifecycle.birthFailures[id]=nil;lifecycle.creationRefusals[id]=nil;marinePopulation.UnitRemoved(id);bike.UnitDestroyed(id)end
  function lifecycle.Transferred(id)lifecycle.birthFailures[id]=nil;lifecycle.creationRefusals[id]=nil;marinePopulation.UnitTransferred(id);bike.UnitTransferred(id)end
  function lifecycle.Damaged(id,damage,attacker)bike.UnitDamaged(id,damage,attacker)end
  function lifecycle.Allow(id,def,team,cmd)return bike.AllowCommand(id,def,team,cmd)end
  function lifecycle.Fallback(id,def,team,cmd,tag)return bike.CommandFallback(id,def,team,cmd,tag)end
  function lifecycle.Snapshot()return {version=1,population=marinePopulation.Snapshot(),bike=bike.Snapshot()}end
  function lifecycle.Restore(saved)
   if type(saved)~='table'or saved.version~=1 then return failed('invalid_native_snapshot')end
   if not marinePopulation.Restore(saved.population)then return failed('population_snapshot_refused')end
   if not bike.Restore(saved.bike)then return failed('bike_snapshot_refused')end
   return true
  end
  local snapshotKey='40k_marine_native_snapshot_v1';local last
  function lifecycle.Save()
   if lifecycle.failed then return false end
   local text=M.Encode(lifecycle.Snapshot())
   if text~=last then S.SetGameRulesParam(snapshotKey,text,{private=true});if S.GetGameRulesParam(snapshotKey)~=text then return failed('snapshot_write_refused')end;last=text end
   return true
  end
  function lifecycle.RestoreSaved()
   local text=S.GetGameRulesParam(snapshotKey)
   if text==nil then return true end
   local decoded=M.Decode(text);if not decoded or not lifecycle.Restore(decoded)then return failed('saved_snapshot_refused')end
   last=text;return true
  end
  lifecycle.population=marinePopulation;lifecycle.bike=bike;C.sourceMarineLifecycle=lifecycle
 end
 return manager
end
return M
