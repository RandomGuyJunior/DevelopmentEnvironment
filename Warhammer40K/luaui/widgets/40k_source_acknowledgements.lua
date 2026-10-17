function widget:GetInfo()return {name='40K source acknowledgements',desc='One native unsynced speaker, no queued speech',author='Local project',layer=0,enabled=true}end
local opts=Spring.GetModOptions()or{}
if opts.prototype_runtime_library_review==true or tostring(opts.prototype_runtime_library_review)=='1'then return end
if not VFS.FileExists('40k_configs/generated_audio.lua')then return end
local clips=VFS.Include('40k_configs/generated_audio.lua')
local policy=VFS.Include('40k_configs/audio_profiles.lua')
local start=Spring.GetTimer()
local busyUntil,lastEvent,lastSignature,lastSignatureTime=0,{},nil,0
local counters={}
local function seconds()return Spring.DiffTimers(Spring.GetTimer(),start)end
-- Native destruction is deferred: a dead unit can retain team/definition metadata.
-- Fail closed before choosing a representative or taking the shared speech lease.
local function livingOwned(id)
 return type(id)=='number' and id==id and id>=0 and id<math.huge and id%1==0
  and type(Spring.ValidUnitID)=='function' and Spring.ValidUnitID(id)==true
  and type(Spring.GetUnitIsDead)=='function' and Spring.GetUnitIsDead(id)==false
  and Spring.GetUnitTeam(id)==Spring.GetMyTeamID()
end
local function speaker(units,event)
 if Spring.GetSpectatingState()then return end
 local best,priority,list
 local byDef={} -- One clip/file check per selected type, not per selected soldier.
 for _,id in ipairs(units or{})do
  if livingOwned(id)then
   local defID=Spring.GetUnitDefID(id);local d=UnitDefs[defID];local cp=d and d.customParams or{}
   if tostring(cp.prototype40k)=='1'and policy.EventAllowed(d,event)then
    local available=byDef[defID]
    if not available then
     local profile=policy.Profile(d.name,cp)
     available=policy.Clips(clips,profile,event,VFS.FileExists)
     if #available==0 and event=='repair'and policy.EventAllowed(d,'move')then
      available=policy.Clips(clips,profile,'move',VFS.FileExists)
     end
     byDef[defID]=available
    end
    local commander=cp.iscommander==true or tostring(cp.iscommander)=='1'or cp.iscommander=='true'
    local rank=commander and 4 or(d.isBuilder or cp.rosterrole=='builder')and 2 or 1
    if #available>0 and(not best or rank>priority or rank==priority and id<best)then best,priority,list=id,rank,available end
   end
  end
 end
 return best,list
end
-- Optional event observers share this exact no-overlap lease with acknowledgements.
local speechBridge={}
function speechBridge.PlayRepresentative(file,volume,duration,event,id)
 local now=seconds()
 if Spring.GetSpectatingState() or not livingOwned(id)
  or type(file)~='string' or not (file:match('^sounds/40k/') or file:match('^sounds/40k_spotting/')) or not VFS.FileExists(file)
  or type(duration)~='number' or duration~=duration or duration<=0 or duration>30
  or type(volume)~='number' or volume~=volume or volume<0 or volume>1
  or now<busyUntil or (lastEvent[event] and now-lastEvent[event]<.8)then return false end
 local played=Spring.PlaySoundFile(file,volume,'ui')
 if played==false then return false end
 busyUntil=now+duration+.12;lastEvent[event]=now;return true
end
WG=WG or {};WG.Recoil40KSourceSpeech=speechBridge
function widget:Shutdown()
 if WG.Recoil40KSourceSpeech==speechBridge then WG.Recoil40KSourceSpeech=nil end
end
local function speak(event,units,signature,cooldown)
 local now=seconds()
 if now<busyUntil or (lastEvent[event] and now-lastEvent[event]<(cooldown or .8)) or (signature and signature==lastSignature and now-lastSignatureTime<2)then return false end
 local id,list=speaker(units,event)
 if not id or not list or #list==0 then return false end
 local key=list[1].file..':'..event;local nextIndex=(counters[key]or 0)+1
 local chosen=list[(nextIndex-1)%#list+1]
 if not VFS.FileExists(chosen.file)then return false end
 if not speechBridge.PlayRepresentative(chosen.file,.8,chosen.duration,event,id)then return false end
 counters[key]=nextIndex;lastSignature=signature;lastSignatureTime=now
 return true
end
function widget:SelectionChanged(units)
 local sorted,objects,seen={},{},{}
 for i,id in ipairs(units or{})do
  sorted[i]=id
  local squad=Spring.GetUnitRulesParam and Spring.GetUnitRulesParam(id,'40k_squad_id')
  local object=type(squad)=='number'and squad>0 and('squad:'..squad)or('unit:'..id)
  if not seen[object]then objects[#objects+1]=object;seen[object]=true end
 end
 table.sort(sorted);table.sort(objects)
 -- Member expansion, casualties and leader succession retain one tactical identity.
 local signature='selection:'..table.concat(objects,',')
 speak('selection',sorted,signature,.8)
end
local commands={}
for _,name in ipairs({'MOVE','FIGHT','PATROL','GUARD','LOAD_UNITS','UNLOAD_UNITS'})do if CMD[name]then commands[CMD[name]]='move' end end
if CMD.ATTACK then commands[CMD.ATTACK]='attack' end
for _,name in ipairs({'REPAIR','RECLAIM','RESTORE','RESURRECT'})do if CMD[name]then commands[CMD[name]]='repair'end end
function widget:CommandNotify(command,params,options)
 local event=type(command)=='number'and command<0 and'repair'or commands[command]
 if event then
  local parts={tostring(command)};for _,p in ipairs(params or {})do parts[#parts+1]=tostring(p)end
  speak(event,Spring.GetSelectedUnits(),'order:'..table.concat(parts,','),.8)
 end
 return false -- native commands, queueing, placement and mouse handling continue.
end
function widget:UnitFinished(id,def,team)
 local d=UnitDefs[def];local cp=d and d.customParams or{}
 -- Internals include paid casualty replacements and full-output member births.
 -- The queued product remains the sole completion speaker for its squad.
 if tostring(cp.prototype40k_squad_internal)=='1'then return end
 -- A missing native rule may return zero Lua values, not one explicit nil.
 local marker=Spring.GetUnitRulesParam and Spring.GetUnitRulesParam(id,'40k_transform_from')
 local transform=tonumber(marker)or 0
 if team==Spring.GetMyTeamID()and transform<=0 then speak('unit_complete',{id},'complete:'..id,6)end
end
-- No Update speech queue: events during a current response are discarded.
