-- Authored synced controller. Native command queue and atomic resource accounting.
local M={}
local function sorted(t)local keys={};for k in pairs(t)do keys[#keys+1]=k end;table.sort(keys);return keys end
local function finite(x)return type(x)=="number" and x==x and x>=0 and x<math.huge end
-- Optional pending-job metadata; no payment, queue or ownership arithmetic.
-- Native RulesParams accept strings. Numeric integer queue tags and boolean
-- exclusions are encoded canonically, bounded to 128 entries / 4096 bytes.
local function encodeExcluded(tags)
 if tags==nil then return "N" end
 if type(tags)~="table"or getmetatable(tags)~=nil then return "X" end
 local keys={}
 for k,v in pairs(tags)do
  if type(k)~="number"or not finite(k)or k~=math.floor(k)or k>9007199254740991 or type(v)~="boolean"then return "X"end
  keys[#keys+1]=k;if #keys>128 then return "X"end
 end
 table.sort(keys);local parts={"T"}
 for _,k in ipairs(keys)do parts[#parts+1]=string.format("%.0f",k)..":"..(tags[k]and"1"or"0")..";"end
 local encoded=table.concat(parts);return #encoded<=4096 and encoded or "X"
end
local function decodeExcluded(version,encoded)
 if version==nil then return nil,true end -- legacy absent metadata remains absent
 if version~=1 or type(encoded)~="string"or #encoded>4096 then return nil,false end
 if encoded=="N"then return nil,true end
 if encoded:sub(1,1)~="T"then return nil,false end
 local tags={};local count=0;local pos=2;local prior=-1
 while pos<=#encoded do
  local first,last,key,flag=encoded:find("(%d+):([01]);",pos)
  if first~=pos then return nil,false end
  local tag=tonumber(key);count=count+1
  if not tag or tag>9007199254740991 or tag<=prior or string.format("%.0f",tag)~=key or count>128 then return nil,false end
  tags[tag]=flag=="1";prior=tag;pos=last+1
 end
 if encodeExcluded(tags)~=encoded then return nil,false end
 return tags,true
end
function M.New(S,defs,names,weapons,armorTypes,graphs,CMD,CMDTYPE,diagnosticPolicy)
 local C={records={},commands={},requirements={},units={},counts={},complete={},done={},tiers={},jobs={},reserved={},baselines={},suppressed={},effectUnits={},nativeEffectUnits={},factions={},producerNames={}}
 local research={};local fps=(Game and Game.gameSpeed) or 30;local CANCEL=34600
 local alias={};for id,d in pairs(defs)do local cp=d.customParams or {};alias[id]=cp.prototype40k_tech_requires or cp.prototype40k_donor or d.name end
 local armor={[0]=true};for _,index in pairs(armorTypes or {})do if finite(index)and index==math.floor(index)then armor[index]=true end end
 local armorKeys=sorted(armor)
 local function effectSupported(r)
  if r.effects==nil then return not r.requires_effect_handler end
  if type(r.effects)~="table" or type(r.effects.units)~="table" then return false end
  if not(S.SetUnitMaxHealth and S.SetUnitHealth and S.SetUnitWeaponDamages and S.GetUnitWeaponDamages)then return false end
  for key in pairs(r.effects)do if key~="units" then return false end end
  for name,effect in pairs(r.effects.units)do
   if not names[name]then return false end
   for key,value in pairs(effect)do
    if key~="health_add" and key~="weapon_damage_mult" then return false end
    if not finite(value)then return false end
   end
  end
  return true
 end
 for _,graph in ipairs(graphs)do
  for name,requires in pairs(graph.Requires or {})do C.requirements[name]=requires end
  for key,row in pairs(graph.Research or {})do
   local id=type(key)=="number" and (row.id or row.name) or key
   assert(type(id)=="string" and not research[id],"Research IDs must be unique strings")
   research[id]=row
  end
 end
 local external={}
 local seq=0
 for _,key in ipairs(sorted(research))do
  seq=seq+1;assert(seq<900,"Reserved research command range exhausted")
  local row=research[key];local cost=row.cost or {}
  if names[row.producer] and finite(cost.metal or 0)and finite(cost.energy or 0)and finite(row.time)and row.time>0 and effectSupported(row)then
   local record={key=key,row=row,cmd=CANCEL+seq,frames=math.max(1,math.ceil(row.time*fps)),producer=row.producer}
   C.records[key]=record;C.commands[record.cmd]=record;C.producerNames[row.producer]=true
   for name,e in pairs((row.effects and row.effects.units)or{})do C.effectUnits[name]=true;if e.health_add or e.weapon_damage_mult then C.nativeEffectUnits[name]=true end end
  else
   C.suppressed[key]=true
   if row.requires_effect_handler and row.effects==nil and names[row.producer] and finite(cost.metal or 0)and finite(cost.energy or 0)and finite(row.time)and row.time>0 then
    external[key]={key=key,row=row,cmd=CANCEL+seq,frames=math.max(1,math.ceil(row.time*fps)),producer=row.producer}
   end
  end
 end
 local function teamState(team)
  C.counts[team]=C.counts[team]or{};C.complete[team]=C.complete[team]or{};C.done[team]=C.done[team]or{};C.reserved[team]=C.reserved[team]or{};C.tiers[team]=C.tiers[team]or 1
  if S.GetTeamRulesParam then
   C.tiers[team]=S.GetTeamRulesParam(team,"40k_tech_tier")or C.tiers[team]
   for key in pairs(C.records)do if S.GetTeamRulesParam(team,"40k_research_"..key)==1 then C.done[team][key]=true end end
  end
 end
 local function rules(id,job,paused)
  if not S.SetUnitRulesParam then return end
  S.SetUnitRulesParam(id,"40k_research_command",job and job.cmd or 0,{allied=true})
  S.SetUnitRulesParam(id,"40k_research_progress",job and job.steps/job.record.frames or 0,{allied=true})
  S.SetUnitRulesParam(id,"40k_research_paused",paused and 1 or 0,{allied=true})
 end
 local function requirement(team,r,builder,initial)
  teamState(team);r=r or {}
  if initial and r.engine_initial_exception then return true end
  if r.production_method and r.production_method~="factory" then return false end
  if (r.tier or 0)>C.tiers[team]then return false end
  for _,name in ipairs(r.buildings or {})do if (C.complete[team][name]or 0)<1 then return false end end
  for _,name in ipairs(r.research or {})do if not C.done[team][name]then return false end end
  if r.producer_min_health_fraction then
   if not builder then return false end
   local health,max=S.GetUnitHealth(builder);if not health or health/max<r.producer_min_health_fraction then return false end
  end
  return true
 end
 local permit,diagnosticPermit
 local diagnosticAttempts=0
 function C.CanBuild(team,defID,builder,initial)
  if diagnosticPermit and builder==nil then
   local token=diagnosticPermit
   if token.used then token.invalid=true;return false end
   token.used=true
   local matches=not token.invalid and token.team==team and token.def==defID and builder==nil and initial~=true
   if not matches then token.invalid=true end
   return matches
  end
  if permit then
   local token=permit;permit=nil
   return token.team==team and token.def==defID and (builder==nil or builder==token.source)
  end
  local name=alias[defID];local r=C.requirements[name];if not r then return true end
  teamState(team)
  if (name=="nec_lord"or name=="nec_nightbringer")and ((C.counts[team].nec_lord or 0)+(C.counts[team].nec_nightbringer or 0))>=1 then return false end
  if r.unit_limit and (C.counts[team][name]or 0)>=r.unit_limit then return false end
  return requirement(team,r,builder,initial)
 end
 local function producerReady(id,record,team)
  local unit=C.units[id]
  if not(unit and unit.team==team and unit.finished and unit.name==record.producer)then return false end
  if S.GetUnitTeam and S.GetUnitTeam(id)~=team then return false end
  local health,_,_,_,progress=S.GetUnitHealth(id)
  if not health or health<=0 or (progress~=nil and progress<1)then return false end
  return requirement(team,record.row.requires,id,false)
 end
 local function persist(id,key,job)
  if not S.SetUnitRulesParam then return end
  local prefix="40k_rjob_"..key.."_"
  local data={version=job and 1 or 0,team=job and job.team or -1,steps=job and job.steps or 0,metal=job and job.metal or 0,energy=job and job.energy or 0,tag=job and job.tag or -1,active=job and job.active and 1 or 0,frames=job and job.record.frames or 0,cost_metal=job and (job.record.row.cost or{}).metal or 0,cost_energy=job and (job.record.row.cost or{}).energy or 0}
  data.excluded_version=1;data.excluded_tags=job and encodeExcluded(job.excludedTags)or "N"
  if C.sourceOrkPaidClock then data.ork_clock_carry=job and string.format('%.17g',job.orkClockCarry or 0)or '0';data.ork_clock_last=job and job.orkClockLast or 0 end
  for _,field in ipairs(sorted(data))do S.SetUnitRulesParam(id,prefix..field,data[field]or 0,{private=true})end
  if S.SetTeamRulesParam then
   local ownerKey="40k_rjob_owner_"..key
   if job then S.SetTeamRulesParam(job.team,ownerKey,id,{private=true})
   end
  end
 end
 local function clear(id,key,team)
  persist(id,key,nil)
  if team~=nil and S.SetTeamRulesParam and (not S.GetTeamRulesParam or S.GetTeamRulesParam(team,"40k_rjob_owner_"..key)==id)then S.SetTeamRulesParam(team,"40k_rjob_owner_"..key,-1,{private=true})end
 end
 local removingOwned=false
 local function ownedEntry(id,job,queue)
  if not S.GetUnitCommands then return end
  for index,entry in ipairs(queue or S.GetUnitCommands(id,-1)or{})do
   if entry.id==job.cmd and type(entry.tag)=="number" and entry.tag>=0 and entry.tag<math.huge and entry.tag==math.floor(entry.tag) and
    (job.tag~=nil and entry.tag==job.tag or job.tag==nil and not(job.excludedTags or{})[entry.tag])then return entry,index==1 end
  end
 end
 local function removeOwned(id,job)
  if not(S.GetUnitCommands and S.GiveOrderToUnit)then return end
  local health=S.GetUnitHealth(id);if not health or health<=0 then return end
  local entry=ownedEntry(id,job);if not entry then return end
  -- Default REMOVE targets factory child/rally orders. No CTRL/ALT and no STOP.
  removingOwned=true;S.GiveOrderToUnit(id,CMD.REMOVE,{entry.tag},0);removingOwned=false
 end
 function C.Cancel(id)
  local jobs=C.jobs[id]
  C.jobs[id]=nil
  if jobs then for _,key in ipairs(sorted(jobs))do local job=jobs[key];C.reserved[job.team][key]=nil;clear(id,key,job.team);removeOwned(id,job)end end
  C.jobs[id]=nil;rules(id,nil,false);if C.Refresh then C.Refresh(id)end
 end
 local function edit(id,cmd,disabled,tooltip)
  if not(S.FindUnitCmdDesc and S.EditUnitCmdDesc)then return end
  local index=S.FindUnitCmdDesc(id,cmd);if index then S.EditUnitCmdDesc(id,index,{disabled=disabled,tooltip=tooltip})end
 end
 local function requirementText(team,r)
  teamState(team);local needs={};r=r or{}
  local function label(name)local d=names[name];d=d and defs[d.id];return d and(d.humanName or d.name)or name end
  for _,name in ipairs(r.buildings or{})do if(C.complete[team][name]or 0)<1 then needs[#needs+1]='Complete '..label(name)end end
  for _,key in ipairs(r.research or{})do if not C.done[team][key]then local rec=C.records[key];needs[#needs+1]='Research '..(rec and rec.row.name or key)end end
  if(r.tier or 0)>C.tiers[team]then needs[#needs+1]='Technology tier '..r.tier end
  if r.production_method and r.production_method~='factory'then needs[#needs+1]='Special production: '..r.production_method end
  return table.concat(needs,'; ')
 end
 function C.RequirementText(team,r)return requirementText(team,r)end
 function C.Refresh(id)
  local u=C.units[id];if not u then return end;teamState(u.team)
  if C.producerNames[u.name] and S.InsertUnitCmdDesc and (not S.FindUnitCmdDesc or not S.FindUnitCmdDesc(id,CANCEL))then
   S.InsertUnitCmdDesc(id,{id=CANCEL,type=CMDTYPE.ICON,name="Cancel research",action="40k_research_cancel",tooltip="Cancel this producer's queued research. Paid costs are not refunded."})
  end
  for _,key in ipairs(sorted(C.records))do local record=C.records[key]
   if record.producer==u.name then
    local row=record.row;local cost=row.cost or {};local locked=not producerReady(id,record,u.team)or C.done[u.team][key]or C.reserved[u.team][key]~=nil
    local tooltip=(row.name or key).."\nMetal: "..(cost.metal or 0).."  Energy: "..(cost.energy or 0).."\nResearch time: "..row.time.." seconds"
    if row.description then tooltip=tooltip.."\n"..row.description end
    local needs=requirementText(u.team,row.requires)
    if C.done[u.team][key]then tooltip=tooltip.."\nCompleted"
    elseif C.reserved[u.team][key]then tooltip=tooltip.."\nResearch queued or in progress"
    elseif not u.finished then tooltip=tooltip.."\nComplete this producer"
    elseif needs~=''then tooltip=tooltip.."\nRequires: "..needs end
    if S.FindUnitCmdDesc and not S.FindUnitCmdDesc(id,record.cmd)then
     S.InsertUnitCmdDesc(id,{id=record.cmd,type=CMDTYPE.ICON,name=row.label or row.name or key,action="40k_research_"..key,tooltip=tooltip,disabled=locked})
    else edit(id,record.cmd,locked,tooltip)end
   end
  end
  local d=defs[u.def]
  for _,target in ipairs(d.buildOptions or {})do
   local td=defs[target];local r=C.requirements[alias[target]]
   if td and r then
    local text=td.tooltip or td.humanName or td.name;local needs=requirementText(u.team,r)
    if r.unit_limit and(C.counts[u.team][alias[target]]or 0)>=r.unit_limit then needs=needs..(needs~=''and'; 'or'')..'Unit limit reached'end
    if r.producer_min_health_fraction then local hp,max=S.GetUnitHealth(id);if hp and max and hp/max<r.producer_min_health_fraction then needs=needs..(needs~=''and'; 'or'')..'Repair producer to '..math.floor(r.producer_min_health_fraction*100)..'% health'end end
    if needs~=''then text=text.."\nRequires: "..needs end
    edit(id,-target,not C.CanBuild(u.team,target,id,false),text)
   end
  end
 end
 -- Shared completed-effect arithmetic; read-only, including alias lookup.
 local function effectBonuses(team,name)
  local add,mult=0,1
  for _,key in ipairs(sorted(C.done[team]or{}))do
   local record=C.records[key];local e=record and record.row.effects and record.row.effects.units[name]
   if e then add=add+(e.health_add or 0);mult=mult*(e.weapon_damage_mult or 1)end
  end
  return add,mult
 end
 function C.HealthBonus(team,defID)
  local add=effectBonuses(team,alias[defID]);return add
 end
 -- Local fortification and team research share the same native XP/HP owner.
 -- A completing local job supplies its proposed addition before publishing it.
 function C.RefreshHealth(id,proposedLocalAdd)
  local u=C.units[id];if not u or not C.nativeHealthEffects then return false end
  local localAdd=proposedLocalAdd
  if localAdd==nil then localAdd=C.listeningPosts and C.listeningPosts.HealthBonus(id)or 0 end
  if not finite(localAdd)then return false end
  return C.nativeHealthEffects.Apply(id,u.def,C.HealthBonus(u.team,u.def)+localAdd)
 end
 local function effect(id,completedResearch)
  local u=C.units[id];if not u then return end
  local add,mult=effectBonuses(u.team,u.name)
  -- Unrelated research completion preserves native XP and applied HP/damage.
  -- Registration/capture reapplies only the destination owner's native plan.
  if completedResearch then
   local e=completedResearch.effects and completedResearch.effects.units[u.name]
   if not e or (e.health_add==nil and e.weapon_damage_mult==nil)then return end
  end
  local base=C.baselines[id]
  local localAdd=C.listeningPosts and C.listeningPosts.HealthBonus(id)or 0
  if not base and not(finite(localAdd)and localAdd>0)then return end
  local health,max=S.GetUnitHealth(id);if not health or not max or max<=0 then return end
  if C.nativeHealthEffects then C.RefreshHealth(id,localAdd)
  elseif base then
   local wanted=base.health+add;S.SetUnitMaxHealth(id,wanted);S.SetUnitHealth(id,{health=math.max(0,health/max*wanted)})
  end
  if not base then return end
  for mount,damage in ipairs(base.weapons)do
   local changed={};for armor,value in pairs(damage)do changed[armor]=value*mult end
   S.SetUnitWeaponDamages(id,mount,changed)
  end
 end
 local function baseline(id,defID)
  if C.baselines[id]or not C.nativeEffectUnits[alias[defID]]then return end
  local _,max=S.GetUnitHealth(id);if not max then return end
  local saved=S.GetUnitRulesParam and S.GetUnitRulesParam(id,"40k_rbase_health")
  local base={health=finite(saved)and saved>0 and saved or max,weapons={}};C.baselines[id]=base
  if S.SetUnitRulesParam then S.SetUnitRulesParam(id,"40k_rbase_health",base.health,{private=true})end
  if S.GetUnitWeaponDamages then
   for mount in ipairs(defs[defID].weapons or {})do
    local damage={};for _,armor in ipairs(armorKeys)do local key="40k_rbase_damage_"..mount.."_"..armor
     local value=S.GetUnitRulesParam and S.GetUnitRulesParam(id,key)
     if not finite(value)then value=S.GetUnitWeaponDamages(id,mount,armor)end
     if finite(value)then damage[armor]=value;if S.SetUnitRulesParam then S.SetUnitRulesParam(id,key,value,{private=true})end end end
    base.weapons[mount]=damage
   end
  end
 end
 function C.Register(id,defID,team,finished)
  if diagnosticPermit then
   local token=diagnosticPermit
   if token.used and not token.created and token.team==team and token.def==defID then token.created=id
   else token.invalid=true end
  end
  if C.units[id]then C.Remove(id,false)end;teamState(team)
  local name=alias[defID];local faction=(defs[defID].customParams or{}).faction
  if faction and not C.factions[team]then
   C.factions[team]=faction
   if faction=="Necrons" and not next(C.done[team])then C.tiers[team]=0 end
  end
  C.units[id]={team=team,name=name,def=defID,finished=finished==true}
  C.counts[team][name]=(C.counts[team][name]or 0)+1
  if finished then C.complete[team][name]=(C.complete[team][name]or 0)+1 end
  baseline(id,defID);effect(id)
  if S.InsertUnitCmdDesc then
   local producer=false;for _,record in pairs(C.records)do if record.producer==name then producer=true;break end end
   if producer and (not S.FindUnitCmdDesc or not S.FindUnitCmdDesc(id,CANCEL))then S.InsertUnitCmdDesc(id,{id=CANCEL,type=CMDTYPE.ICON,name="Cancel research",action="40k_research_cancel",tooltip="Cancel this producer's queued research. Paid costs are not refunded."})end
  end
  C.Refresh(id)
 end
 function C.Remove(id,dead)
  local u=C.units[id];if not u then return end
  C.Cancel(id);C.counts[u.team][u.name]=C.counts[u.team][u.name]-1
  if u.finished then C.complete[u.team][u.name]=C.complete[u.team][u.name]-1 end
  if C.nativeHealthEffects then C.nativeHealthEffects.Remove(id)end
  C.units[id]=nil;if dead then C.baselines[id]=nil end
 end
 function C.Finished(id)
  local u=C.units[id];if u and not u.finished then u.finished=true;C.complete[u.team][u.name]=(C.complete[u.team][u.name]or 0)+1;C.Refresh(id)end
 end
 function C.Allow(id,defID,team,cmd,params,options)
  if cmd==CANCEL then C.Cancel(id);return false end
  if cmd==CMD.STOP then C.Cancel(id);return true end
  if cmd==CMD.REMOVE then
   if removingOwned then return true end
   local u=C.units[id]
   if u and defs[u.def].isFactory and options and options.ctrl then return true end
   local jobs=C.jobs[id]or{}
   for _,tag in ipairs(params or{})do for key,job in pairs(jobs)do
    local entry=ownedEntry(id,job)
    if (options and options.alt and job.cmd==tag)or(not(options and options.alt)and (job.tag==tag or entry and entry.tag==tag))then C.reserved[job.team][key]=nil;jobs[key]=nil;clear(id,key,job.team);rules(id,nil,false)end
   end end
   return true
  end
  if cmd==CMD.INSERT and params and type(params[2])=="number" and params[2]<0 then return C.CanBuild(team,-params[2],id,false)end
  if cmd<0 then return C.CanBuild(team,-cmd,id,false)end
  local record=C.commands[cmd];if not record then return true end
  teamState(team)
  if not producerReady(id,record,team)or C.done[team][record.key]or C.reserved[team][record.key]then return false end
  if not(options and options.shift)then C.Cancel(id)end
  local excluded={}
  if S.GetUnitCommands then for _,entry in ipairs(S.GetUnitCommands(id,-1)or{})do if entry.id==cmd and entry.tag~=nil then excluded[entry.tag]=true end end end
  C.jobs[id]=C.jobs[id]or{};C.jobs[id][record.key]={cmd=cmd,record=record,team=team,steps=0,metal=0,energy=0,active=false,excludedTags=excluded}
  C.reserved[team][record.key]=id;persist(id,record.key,C.jobs[id][record.key]);C.Refresh(id);return true
 end
 function C.Fallback(id,cmd,tag)
  local record=C.commands[cmd];if not record then return false end
  local u=C.units[id];if not u then return true,true end
  if C.done[u.team][record.key]then return true,true end
  local job=C.jobs[id]and C.jobs[id][record.key]
  if not job or not producerReady(id,record,u.team)then C.Cancel(id);return true,true end
  job.active=true;job.tag=tag;persist(id,record.key,job);return true,false
 end
 -- Reconcile native queues before charging: REMOVE may run before first fallback,
 -- and another native order can replace a research command without STOP.
 local function reconcile(id,jobs)
  if not S.GetUnitCommands then return end
  local u=C.units[id];if not u then C.Cancel(id);return end
  local factory=defs[u.def].isFactory
  local found={}
  if not factory then
   for index,cmd in ipairs(S.GetUnitCommands(id,-1)or{})do if C.commands[cmd.id]then found[cmd.id]={tag=cmd.tag,head=index==1}end end
  end
  local snapshot=factory and (S.GetUnitCommands(id,-1)or{})
  for _,key in ipairs(sorted(jobs))do local job=jobs[key]
   local command,head
   if factory then command,head=ownedEntry(id,job,snapshot)else command=found[job.cmd];head=command and command.head end
   if not command or factory and (C.reserved[job.team][key]~=id or not producerReady(id,job.record,job.team))then
    if C.reserved[job.team][key]==id then C.reserved[job.team][key]=nil end
    jobs[key]=nil;clear(id,key,job.team);rules(id,nil,false)
    if factory then removeOwned(id,job)end
   else
    job.tag=command.tag
    -- Explicit factory adaptation: a real owned rally-head research job executes
    -- concurrently with ordinary native production. Never activate reservation alone.
    job.active=factory and head or not factory and job.active and head
    persist(id,key,job)
   end
  end
 end
 -- Explicit diagnostic subscription; one bounded latest receipt, never serialized.
 local paymentWatch
 local function witnessIdentity(id,key,team,tag)
  return paymentWatch and paymentWatch.id==id and paymentWatch.key==key and paymentWatch.team==team and paymentWatch.tag==tag
 end
 function C.BeginOrdinaryPaymentWitness(id,key,team,tag)
  if not(finite(id)and id%1==0 and finite(team)and team%1==0 and finite(tag)and tag%1==0 and type(key)=='string'and type(S.GetGameFrame)=='function')then return false end
  local j=C.jobs[id]and C.jobs[id][key];local u=C.units[id]
  if not(j and j.record==C.records[key]and j.team==team and j.tag==tag and u and u.team==team and u.finished and u.name==j.record.producer)then return false end
  if paymentWatch then return witnessIdentity(id,key,team,tag)==true end
  if not(finite(j.steps)and j.steps%1==0 and j.steps<=1)then return false end
  paymentWatch={id=id,key=key,team=team,tag=tag,beginStep=j.steps,successfulCalls=0,failedCalls=0,unknownReturns=0,observedMetal=0,observedEnergy=0};return true
 end
 function C.ReadOrdinaryPaymentWitness(id,key,team,tag)
  if not witnessIdentity(id,key,team,tag)or not paymentWatch.receipt then return end
  local out={};for k,v in pairs(paymentWatch.receipt)do out[k]=v end;return out
 end
 function C.EndOrdinaryPaymentWitness(id,key,team,tag)
  if not witnessIdentity(id,key,team,tag)then return false end;paymentWatch=nil;return true
 end
 local function ordinaryPaymentWitness(id,key,job,nextStep,metal,energy,paid)
  if not witnessIdentity(id,key,job.team,job.tag)then return end
  local w=paymentWatch;local ok,frame=pcall(S.GetGameFrame)
  if not(ok and finite(frame)and frame%1==0)then frame='unavailable'end
  local nativeReturn='unavailable';if type(paid)=='boolean'then nativeReturn=paid end
  local dm,de=metal-job.metal,energy-job.energy
  if paid==true then w.successfulCalls=w.successfulCalls+1;w.observedMetal=w.observedMetal+dm;w.observedEnergy=w.observedEnergy+de
  elseif paid==false then w.failedCalls=w.failedCalls+1 else w.unknownReturns=w.unknownReturns+1 end
  w.receipt={producer=id,key=key,team=job.team,tag=job.tag,frame=frame,priorStep=job.steps,nextStep=nextStep,priorMetal=job.metal,priorEnergy=job.energy,deltaMetal=dm,deltaEnergy=de,cumulativeMetal=metal,cumulativeEnergy=energy,nativeReturn=nativeReturn,nativeReturnType=type(paid),beginStep=w.beginStep,successfulCalls=w.successfulCalls,failedCalls=w.failedCalls,unknownReturns=w.unknownReturns,observedMetal=w.observedMetal,observedEnergy=w.observedEnergy,ordinaryBranch=true}
 end

 function C.Frame(frame)
  if C.nativeHealthEffects then C.nativeHealthEffects.Frame()end
  for _,id in ipairs(sorted(C.jobs))do
   local jobs=C.jobs[id];reconcile(id,jobs)
   for _,key in ipairs(sorted(jobs))do local job=jobs[key]
    if job.active then
     if not producerReady(id,job.record,job.team)then C.Cancel(id);break end
     local row=job.record.row;local cost=row.cost or {}; local nextStep,metal,energy,paid
     if C.sourceOrkPaidClock and C.sourceOrkPaidClock.Handles(id)then
      paid=C.sourceOrkPaidClock.Advance(job,id,S.GetGameFrame(),"research");nextStep=job.steps;metal=job.metal;energy=job.energy
     else
      nextStep=job.steps+1;metal=(cost.metal or 0)*nextStep/job.record.frames;energy=(cost.energy or 0)*nextStep/job.record.frames
      paid=S.UseTeamResource(job.team,{metal=metal-job.metal,energy=energy-job.energy})
      if paymentWatch then pcall(ordinaryPaymentWitness,id,key,job,nextStep,metal,energy,paid)end
     end
     if paid then
      job.steps=nextStep;job.metal=metal;job.energy=energy;persist(id,key,job);rules(id,job,false)
      if nextStep>=job.record.frames then
       C.done[job.team][key]=true;C.tiers[job.team]=math.max(C.tiers[job.team],row.grants_tier or row.tier or 0)
       C.reserved[job.team][key]=nil;jobs[key]=nil;clear(id,key,job.team)
       if S.SetTeamRulesParam then S.SetTeamRulesParam(job.team,"40k_research_"..key,1,{allied=true});S.SetTeamRulesParam(job.team,"40k_tech_tier",C.tiers[job.team],{allied=true})end
       for _,unitID in ipairs(sorted(C.units))do if C.units[unitID].team==job.team then effect(unitID,row);C.Refresh(unitID)end end
       rules(id,nil,false)
       if defs[C.units[id].def].isFactory then removeOwned(id,job)end
      end
     else rules(id,job,true)end
    end
   end
   if C.jobs[id]and not next(C.jobs[id])then C.jobs[id]=nil end
  end
  if frame%30==0 then for _,id in ipairs(sorted(C.units))do if defs[C.units[id].def].isBuilder or C.producerNames[C.units[id].name] then C.Refresh(id)end end end
 end
 local function nativeResearchCommand(id,cmd)
  if not S.GetUnitCommands then return nil end
  -- Factory research is deliberately in its real child/rally list, never a
  -- hypothetical positive command inserted into native production.
  for index,entry in ipairs(S.GetUnitCommands(id,-1)or{})do if entry.id==cmd then return entry,index==1 end end
 end
 function C.RestorePending(onlyKey)
  if not S.GetUnitRulesParam then return end
  if S.GetTeamList and S.SetTeamRulesParam then
   for _,team in ipairs(S.GetTeamList())do for key in pairs(C.records)do if not onlyKey or onlyKey==key then
    local owner=S.GetTeamRulesParam and S.GetTeamRulesParam(team,"40k_rjob_owner_"..key)
    if owner~=nil and not(C.jobs[owner]and C.jobs[owner][key])then S.SetTeamRulesParam(team,"40k_rjob_owner_"..key,-1,{private=true})end
   end end end
  end
  for _,id in ipairs(sorted(C.units))do local u=C.units[id]
   for _,key in ipairs(sorted(C.records))do if not onlyKey or onlyKey==key then
    local record=C.records[key];local prefix="40k_rjob_"..key.."_"
    local function read(field)return S.GetUnitRulesParam(id,prefix..field)end
    if read("version")==1 and not(C.jobs[id]and C.jobs[id][key])then
     local team,steps,metal,energy=read("team"),read("steps"),read("metal"),read("energy")
     local excludedTags,excludedValid=decodeExcluded(read("excluded_version"),read("excluded_tags"))
     local cost=record.row.cost or{};local entry,head=nativeResearchCommand(id,record.cmd)
     local health=S.GetUnitHealth(id)
     local valid=excludedValid and team==u.team and u.finished and health and health>0 and entry and producerReady(id,record,team)and not C.done[team][key]and not C.reserved[team][key]
     valid=valid and (read("tag")==-1 or read("tag")==entry.tag)
     if defs[u.def].isFactory then valid=valid and type(entry and entry.tag)=="number" and entry.tag>=0 and entry.tag<math.huge and entry.tag==math.floor(entry.tag) and read("tag")==entry.tag end
     valid=valid and finite(steps)and steps==math.floor(steps)and steps<record.frames and finite(metal)and finite(energy)and read("frames")==record.frames
     valid=valid and read("cost_metal")== (cost.metal or 0)and read("cost_energy")== (cost.energy or 0)
     if valid then
      local wantedM=(cost.metal or 0)*steps/record.frames;local wantedE=(cost.energy or 0)*steps/record.frames
      valid=math.abs(metal-wantedM)<=math.max(1,wantedM)*1e-5 and math.abs(energy-wantedE)<=math.max(1,wantedE)*1e-5
     end
     if valid then
      local job={cmd=record.cmd,record=record,team=team,steps=steps,metal=metal,energy=energy,tag=entry.tag,active=read("active")==1 and head}
      job.excludedTags=excludedTags
      if C.sourceOrkPaidClock then local carry=read("ork_clock_carry");local parsed=carry==nil and 0 or tonumber(carry);if carry~=nil and(not parsed or type(carry)=="string"and string.format("%.17g",parsed)~=carry)then parsed=false end;job.orkClockCarry=parsed;job.orkClockLast=read("ork_clock_last")or 0 end
      C.jobs[id]=C.jobs[id]or{};C.jobs[id][key]=job;C.reserved[team][key]=id;persist(id,key,job);rules(id,job,false)
     else clear(id,key,team);rules(id,nil,false)end
    end
   end end
   C.Refresh(id)
  end
 end
 function C.WithCreationPermit(team,defID,source,fn)
  if permit or diagnosticPermit or type(fn)~="function" then
   if diagnosticPermit then diagnosticPermit.invalid=true end return false,"Invalid or nested creation permit" end
  local u=C.units[source];local target=alias[defID]
  if not u or u.team~=team or not u.finished then return false,"Invalid completed owned source pair" end
  local lordPair=(u.name=="nec_lord"and target=="nec_nightbringer")or(u.name=="nec_nightbringer"and target=="nec_lord")
  local hwtPair=(u.name=='imp_heavy_weapon_team'and target=='imp_heavy_weapon_team_deployed')or(u.name=='imp_heavy_weapon_team_deployed'and target=='imp_heavy_weapon_team')
  if not lordPair and not hwtPair then return false,"Invalid completed owned source pair"end
  teamState(team)
  if lordPair and (C.counts[team].nec_lord or 0)+(C.counts[team].nec_nightbringer or 0)~=1 then return false,"Combined Lord cap exceeded" end
  if target=="nec_nightbringer"then
   local original=C.requirements[target];if not original or original.production_method~="lord_transformation"then return false,"Missing transformation requirements"end
   local r={};for k,v in pairs(original)do if k~="production_method"then r[k]=v end end
   if not requirement(team,r,source,false)then return false,"Transformation requirements unavailable"end
  end
  permit={team=team,def=defID,source=source}
  local results={pcall(fn)};permit=nil
  return (table.unpack or unpack)(results)
 end
 -- Separate unpaid diagnostic capability; never the Lord transformation exception.
 function C.WithDiagnosticSeedPermit(team,defID,caller,fn)
  if permit or diagnosticPermit then
   if diagnosticPermit then diagnosticPermit.invalid=true end
   return false,"Nested diagnostic creation refused"
  end
  if type(diagnosticPolicy)~="function" or type(fn)~="function" or caller~="40k_mixed_v2"
   or not(S.CreateUnit and S.DestroyUnit and S.GetUnitDefID and S.GetUnitTeam)then return false,"Diagnostic creation capability unavailable"end
  local ok,policy=pcall(diagnosticPolicy,team,defID,caller)
  local cp=defs[defID]and defs[defID].customParams or{}
  if not ok or type(policy)~="table" or policy.mode~="mixedperf2" or tostring(policy.mixedV2)~="1"
   or tostring(policy.sourceProgression)~="1" or policy.selected~=true or policy.ownedTeam~=true
   or policy.team~=team or policy.def~=defID or policy.caller~=caller
   or tostring(cp.prototype40k)~="1" or tostring(cp.prototype40k_source_progression)~="1"
   or not finite(policy.maxSeeds)or policy.maxSeeds~=math.floor(policy.maxSeeds)or policy.maxSeeds<1 or policy.maxSeeds>1717
   or diagnosticAttempts>=policy.maxSeeds then return false,"Diagnostic creation authorization refused"end
  diagnosticAttempts=diagnosticAttempts+1
  local token={team=team,def=defID,used=false,invalid=false};diagnosticPermit=token
  local made,id=pcall(fn);diagnosticPermit=nil
  local function reject(reason)
   -- Roll back only the actual synchronously registered diagnostic birth.
   if token.created then pcall(function()
    if S.GetUnitDefID(token.created)==defID and S.GetUnitTeam(token.created)==team then S.DestroyUnit(token.created,false,true)end
   end)end
   return false,reason
  end
  if not made then return reject("Diagnostic creation callback failed")end
  if not token.used or token.invalid or type(id)~="number"or token.created~=id then return reject("Diagnostic creation count/identity refused")end
  local read,actualDef,actualTeam=pcall(function()return S.GetUnitDefID(id),S.GetUnitTeam(id)end)
  if not read or actualDef~=defID or actualTeam~=team then return reject("Diagnostic created unit mismatch")end
  return true,id
 end
 function C.HasResearch(team,key)teamState(team);return C.done[team][key]==true end
 -- Explicit capability declaration by a separately acceptance-gated native gadget.
 -- This does not itself execute an ability or approve any asset/runtime marker.
 function C.RegisterEffectHandler(key)
  local record=external[key];if not record then return false end
  external[key]=nil;C.suppressed[key]=nil;C.records[key]=record;C.commands[record.cmd]=record;C.producerNames[record.producer]=true
  if S.GetTeamList then for _,team in ipairs(S.GetTeamList())do teamState(team)end end
  C.RestorePending(key)
  for _,id in ipairs(sorted(C.units))do C.Refresh(id)end
  return true,record.cmd
 end
 C.CommandBase=CANCEL;C.Requirement=requirement;return C
end
return M
