-- Authored entity-scoped paid HQ addons. Native queue, ownership and receipts.
local M={Keys={imp_source_hq_addon_1=true,imp_source_hq_addon_2=true,ork_source_hq_addon=true}}
local function sorted(t)local o={};for k in pairs(t or{})do o[#o+1]=k end;table.sort(o);return o end
local function finite(v)return type(v)=='number'and v==v and v>=0 and v<math.huge end
local function integer(v)return finite(v)and v==math.floor(v)end
function M.Attach(C,S,defs,g,adapter,hooks,CMD,fps)
 assert(C.sourceVariantAdapter==adapter and not C.sourceVariantAddonJobs,'Attach once after variant adapter')
 assert(S.GetUnitCommands and S.GetUnitRulesParam and S.SetUnitRulesParam and S.UseTeamResource,'Native addon queue/accounting APIs required')
 assert(type(hooks.EffectsCompleted)=='function'and type(hooks.RestoreCompleted)=='function','Real complete and idempotent restored source effect handlers required')
 fps=fps or (Game and Game.gameSpeed)or 30
 assert(integer(fps)and fps>0,'Native game speed required')
 local E={jobs={},deferred={},failures={},Keys=M.Keys};local removing=false
 local oldAllow,oldFallback,oldFrame,oldCancel,oldRefresh,oldRestore,oldRegister,oldFinished=C.Allow,C.Fallback,C.Frame,C.Cancel,C.Refresh,C.RestorePending,C.Register,C.Finished
 local function recordFor(key)local r=C.records[key];return M.Keys[key]and r and not C.suppressed[key]and r or nil end
 local function commandFor(key)
  local all={};for k in pairs(C.records)do all[k]=true end;for k in pairs(C.suppressed)do all[k]=true end;for k in pairs(g.Research)do all[k]=true end
  for index,k in ipairs(sorted(all))do if k==key then return C.CommandBase+index end end
 end
 local function prefix(key)return '40k_eaddon_'..key..'_'end
 -- Fingerprints remain exactly representable in the native float rules store.
 local profiles=assert(hooks.SourceProfiles,'Copied source profiles required')
 local function fingerprint(key)return tonumber(assert(profiles[key]).sha256:sub(1,6),16)end
 local function progress(id,job,paused)
  S.SetUnitRulesParam(id,'40k_addon_command',job and job.cmd or 0,{allied=true})
  S.SetUnitRulesParam(id,'40k_addon_progress',job and job.steps/job.frames or 0,{allied=true})
  S.SetUnitRulesParam(id,'40k_addon_paused',paused and 1 or 0,{allied=true})
 end
 local function persist(id,key,job)
  local p=prefix(key);local data={version=job and 1 or 0,team=job and job.team or -1,def=job and job.def or -1,source=fingerprint(key),steps=job and job.steps or 0,metal=job and job.metal or 0,energy=job and job.energy or 0,tag=job and job.tag or -1,active=job and job.active and 1 or 0,frames=job and job.frames or 0,cost_metal=job and job.cost.metal or 0,cost_energy=job and job.cost.energy or 0,excluded_count=job and #(job.excluded or{})or 0}
  if C.sourceOrkPaidClock then data.ork_clock_carry=job and string.format('%.17g',job.orkClockCarry or 0)or '0';data.ork_clock_last=job and job.orkClockLast or 0 end
  for _,field in ipairs(sorted(data))do S.SetUnitRulesParam(id,p..field,data[field],{private=true})end
  if job then for n,tag in ipairs(job.excluded or{})do S.SetUnitRulesParam(id,p..'excluded_'..n,tag,{private=true})end end
 end
 local function eligible(id,team,key)
  local r=recordFor(key);local u=C.units[id]
  if S.GetUnitRulesParam(id,'40k_addon_failed_'..key)==1 then return false end
  if not r or not u or u.team~=team or not u.finished or u.name~=r.producer then return false end
  if S.GetUnitTeam and S.GetUnitTeam(id)~=team then return false end
  local hp,_,_,_,built=S.GetUnitHealth(id)
  return hp and hp>0 and(built==nil or built>=1)and adapter.Conditions(team,assert(hooks.ResearchConditions[key]),id)==true
 end
 local function ownedEntry(id,job,queue)
  local excluded={};for _,tag in ipairs(job.excluded or{})do excluded[tag]=true end
  for n,row in ipairs(queue or S.GetUnitCommands(id,-1)or{})do
   if row.id==job.cmd and integer(row.tag)and(job.tag~=nil and row.tag==job.tag or job.tag==nil and not excluded[row.tag])then return row,n==1 end
  end
 end
 local function removeOwned(id,job)
  if not S.GiveOrderToUnit then return end
  local hp=S.GetUnitHealth(id);if not hp or hp<=0 then return end
  local entry=ownedEntry(id,job);if not entry then return end
  removing=true;S.GiveOrderToUnit(id,CMD.REMOVE,{entry.tag},0);removing=false
 end
 function E.Cancel(id,key,remove)
  local jobs=E.jobs[id]or{}
  for _,k in ipairs(key and{key}or sorted(M.Keys))do local job=jobs[k]
   if job then jobs[k]=nil;persist(id,k,nil);if remove~=false then removeOwned(id,job)end
   elseif S.GetUnitRulesParam(id,prefix(k)..'version')==1 then
    local tag=S.GetUnitRulesParam(id,prefix(k)..'tag');local cmd=commandFor(k)
    if remove~=false and integer(tag)and cmd then removeOwned(id,{tag=tag,cmd=cmd})end
    persist(id,k,nil)
   end
   if E.deferred[id]then E.deferred[id][k]=nil end
  end
  if not next(jobs)then E.jobs[id]=nil end
  progress(id,nil,false)
 end
 function E.Allow(id,defID,team,cmd,params,options)
  if cmd==CMD.REMOVE and not removing then
   local u=C.units[id]
   if not(u and defs[u.def].isFactory and options and options.ctrl)then
    for _,tag in ipairs(params or{})do for _,key in ipairs(sorted(E.jobs[id]))do local job=E.jobs[id][key];local entry=ownedEntry(id,job)
     if(options and options.alt and job.cmd==tag)or not(options and options.alt)and(job.tag==tag or entry and entry.tag==tag)then E.Cancel(id,key,false)end
    end end
   end
  end
  local inserted=cmd==CMD.INSERT and params and params[2]
  local r=C.commands[inserted or cmd]
  if not r or not M.Keys[r.key]then return oldAllow(id,defID,team,cmd,params,options)end
  if not C.units[id]or C.units[id].def~=defID or not eligible(id,team,r.key)or adapter.LocalAddon(id,team,r.key)or(E.jobs[id]or{})[r.key]then return false end
  if not inserted and not(options and options.shift)then C.Cancel(id)end
  local excluded={};for _,row in ipairs(S.GetUnitCommands(id,-1)or{})do if row.id==r.cmd and integer(row.tag)then excluded[#excluded+1]=row.tag end end
  if #excluded>64 then return false end
  E.jobs[id]=E.jobs[id]or{}
  local cost=r.row.cost or{};local frames=math.max(1,math.ceil(r.row.time*fps))
  E.jobs[id][r.key]={key=r.key,cmd=r.cmd,team=team,def=defID,frames=frames,cost={metal=cost.metal or 0,energy=cost.energy or 0},steps=0,metal=0,energy=0,active=false,excluded=excluded}
  persist(id,r.key,E.jobs[id][r.key]);C.Refresh(id);return true
 end
 function E.Fallback(id,cmd,tag)
  local r=C.commands[cmd]
  if not r or not M.Keys[r.key]then return oldFallback(id,cmd,tag)end
  local u=C.units[id];local job=(E.jobs[id]or{})[r.key]
  if not u or not job or adapter.LocalAddon(id,u.team,r.key)or not eligible(id,job.team,r.key)then E.Cancel(id,r.key);return true,true end
  if not integer(tag)then E.Cancel(id,r.key);return true,true end
  local entry,head=ownedEntry(id,job)
  if not entry or entry.tag~=tag then E.Cancel(id,r.key);return true,true end
  job.tag=tag;job.active=head;persist(id,r.key,job);return true,false
 end
 function E.Frame()
  for _,id in ipairs(sorted(E.jobs))do
   local queue=S.GetUnitCommands(id,-1)or{}
   for _,key in ipairs(sorted(E.jobs[id]))do local job=(E.jobs[id]or{})[key]
    if job then local entry,head=ownedEntry(id,job,queue)
     if not entry or not eligible(id,job.team,key)or adapter.LocalAddon(id,job.team,key)then E.Cancel(id,key)
     else
      job.tag=entry.tag;job.active=defs[job.def].isFactory and head or job.active and head
      persist(id,key,job)
      if job.active then
       local steps,metal,energy,paid
       if C.sourceOrkPaidClock and C.sourceOrkPaidClock.Handles(id)then
        paid=C.sourceOrkPaidClock.Advance(job,id,S.GetGameFrame(),"addon");steps=job.steps;metal=job.metal;energy=job.energy
       else
        steps=job.steps+1;metal=job.cost.metal*steps/job.frames;energy=job.cost.energy*steps/job.frames
        paid=S.UseTeamResource(job.team,{metal=metal-job.metal,energy=energy-job.energy})
       end
       if paid then
        job.steps=steps;job.metal=metal;job.energy=energy;persist(id,key,job);progress(id,job,false)
        if steps>=job.frames then
         local okay,result=pcall(hooks.EffectsCompleted,job.team,key,profiles[key],id)
         if okay and result~=false then S.SetUnitRulesParam(id,'40k_source_addon_source_'..key,fingerprint(key),{private=true});S.SetUnitRulesParam(id,'40k_source_addon_'..key,1,{allied=true})
         else E.failures[id]={key=key,error=tostring(result)};S.SetUnitRulesParam(id,'40k_addon_effect_failure',1,{allied=true});S.SetUnitRulesParam(id,'40k_addon_failed_'..key,1,{private=true})end
         E.Cancel(id,key);C.Refresh(id)
        end
       else progress(id,job,true)end
      end
     end
    end
   end
  end
 end
 function E.Refresh(id)
  oldRefresh(id);local u=C.units[id];if not u then return end
  for _,key in ipairs(sorted(M.Keys))do local r=recordFor(key)
   if r and r.producer==u.name then
    local done=adapter.LocalAddon(id,u.team,key);local queued=(E.jobs[id]or{})[key]
    local disabled=not eligible(id,u.team,key)or done or queued~=nil
    local tooltip=(r.row.name or key)..'\nPer-HQ addon. Metal: '..(r.row.cost.metal or 0)..'  Energy: '..(r.row.cost.energy or 0)..'\nTime: '..r.row.time..' seconds'
    if done then tooltip=tooltip..'\nCompleted on this HQ'elseif queued then tooltip=tooltip..'\nQueued on this HQ'elseif disabled then tooltip=tooltip..'\nRequires finished owned HQ and source prerequisites'end
    local index=S.FindUnitCmdDesc and S.FindUnitCmdDesc(id,r.cmd)
    if index then S.EditUnitCmdDesc(id,index,{disabled=disabled,tooltip=tooltip})end
   end
  end
 end
 function E.RestoreCompleted(id)
  local u=C.units[id];if not u then return end
  for _,key in ipairs(sorted(M.Keys))do
   if adapter.LocalAddon(id,u.team,key)then
    local okay,result=pcall(hooks.RestoreCompleted,u.team,key,profiles[key],id)
    if not okay or result==false then
     E.failures[id]={key=key,error=tostring(result)};S.SetUnitRulesParam(id,'40k_addon_effect_failure',1,{allied=true});S.SetUnitRulesParam(id,'40k_addon_failed_'..key,1,{private=true})
    end
   end
  end
 end
 function E.Restore(onlyKey)
  for _,id in ipairs(sorted(C.units))do local u=C.units[id]
   for _,key in ipairs(sorted(M.Keys))do if not onlyKey or onlyKey==key then
    local p=prefix(key);local function read(field)return S.GetUnitRulesParam(id,p..field)end
    if read('version')==1 and not(E.jobs[id]or{})[key]then
     local r=recordFor(key)
     if not r and C.suppressed[key]then E.deferred[id]=E.deferred[id]or{};E.deferred[id][key]=true
     else
     if E.deferred[id]then E.deferred[id][key]=nil end
     local team,steps,metal,energy,tag=read('team'),read('steps'),read('metal'),read('energy'),read('tag')
     local cost=r and r.row.cost or{};local frames=r and math.max(1,math.ceil(r.row.time*fps))
     local count=read('excluded_count');local excluded={};local valid=integer(count)and count<=64
     if valid then for n=1,count do local value=read('excluded_'..n);if not integer(value)then valid=false;break end;excluded[n]=value end end
     valid=valid and r~=nil and team==u.team and read('def')==u.def and read('source')==fingerprint(key)and eligible(id,team,key)and not adapter.LocalAddon(id,team,key)
     valid=valid and integer(steps)and steps<frames and finite(metal)and finite(energy)and read('frames')==frames and read('cost_metal')==(cost.metal or 0)and read('cost_energy')==(cost.energy or 0)and(tag==-1 or integer(tag))and(read('active')==0 or read('active')==1)
     if valid then
      valid=math.abs(metal-(cost.metal or 0)*steps/frames)<=math.max(1,metal)*1e-5 and math.abs(energy-(cost.energy or 0)*steps/frames)<=math.max(1,energy)*1e-5
     end
     if valid then
      local job={key=key,cmd=r.cmd,team=team,def=u.def,frames=frames,cost={metal=cost.metal or 0,energy=cost.energy or 0},steps=steps,metal=metal,energy=energy,tag=tag~=-1 and tag or nil,active=read('active')==1,excluded=excluded}
      if C.sourceOrkPaidClock then local carry=read('ork_clock_carry');local parsed=carry==nil and 0 or tonumber(carry);if carry~=nil and(not parsed or type(carry)=='string'and string.format('%.17g',parsed)~=carry)then parsed=false end;job.orkClockCarry=parsed;job.orkClockLast=read('ork_clock_last')or 0 end
      local entry,head=ownedEntry(id,job)
      if entry then
       job.tag=entry.tag;job.active=job.active and head;E.jobs[id]=E.jobs[id]or{};E.jobs[id][key]=job;persist(id,key,job);progress(id,job,false)
      else valid=false end
     end
     if not valid then persist(id,key,nil);progress(id,nil,false)end
     end
    end
   end end
   E.RestoreCompleted(id);C.Refresh(id)
  end
 end
 C.Allow=E.Allow;C.Fallback=E.Fallback;C.Refresh=E.Refresh
 function C.Cancel(id)E.Cancel(id);return oldCancel(id)end
 function C.Frame(frame)E.Frame();return oldFrame(frame)end
 function C.Register(id,defID,team,finished)local result=oldRegister(id,defID,team,finished);E.RestoreCompleted(id);return result end
 function C.Finished(id)local result=oldFinished(id);E.RestoreCompleted(id);return result end
 function C.RestorePending(onlyKey)
  -- Old team-scoped receipts cannot be mistaken for paid entity-scoped jobs.
  -- Temporarily omit these records from the shared restore loop, preserving all
  -- unrelated controller state and always restoring the actual record registry.
  local saved={};for key in pairs(M.Keys)do saved[key]=C.records[key];C.records[key]=nil end
  local results={pcall(oldRestore,onlyKey)}
  for key,r in pairs(saved)do C.records[key]=r end
  assert(results[1],results[2]);E.Restore(onlyKey)
 end
 -- A live legacy team-scoped addon job has incompatible persistence/ownership.
 -- Fail closed through existing cancellation; never transfer its paid receipt.
 for _,id in ipairs(sorted(C.jobs))do for key in pairs(C.jobs[id])do if M.Keys[key]then C.Cancel(id);break end end end
 C.sourceVariantAddonJobs=E
 for _,id in ipairs(sorted(C.units))do C.Refresh(id)end
 return E
end
return M
