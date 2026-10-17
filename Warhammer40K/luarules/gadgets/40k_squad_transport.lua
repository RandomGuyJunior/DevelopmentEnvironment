function gadget:GetInfo()return{name='40K real-body squad transport reservations',desc='Native whole-fixed-slot intent; no fictitious passenger',author='Local project',layer=152,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local R;local saver;local persistenceDirty=false;local forwarding=false
local function flush()
 if not R or not saver then return end
 local ok,why=saver.Save(R);assert(ok,'Squad cargo persistence refused: '..tostring(why));persistenceDirty=false
end
local function api()return GG.Recoil40KSquadTransportAPI end
local function definition(id)
 local d=UnitDefs[id];if not d then return end
 return{size=d.xsize/2,mass=d.mass,cantBeTransported=d.cantBeTransported}
end
local function body(id)
 if not S.ValidUnitID(id)or S.GetUnitIsDead(id)then return end
 local def=S.GetUnitDefID(id);local d=definition(def);if not d then return end
 d.alive=true;d.def=def;d.team=S.GetUnitTeam(id);d.transporter=S.GetUnitTransporter(id);d.mass=S.GetUnitMass(id)
 d.jumpBusy=GG.Recoil40KAssaultJump and GG.Recoil40KAssaultJump.Busy(id)or false
 return d
end
local function carrier(id)
 local b=body(id);if not b then return end
 local d=UnitDefs[b.def];if(d.transportCapacity or 0)<=0 then return end
 local cp=d.customParams or{}
 return{alive=true,team=b.team,capacity=d.transportCapacity,maxSize=d.transportSize,minSize=d.minTransportSize,
  massCapacity=d.transportMass,minMass=d.minTransportMass,actorLimit=tonumber(cp.source_transport_actor_capacity),
  requiredProfile=cp.prototype40k_transport_profile,squadLimit=tonumber(cp.prototype40k_transport_squad_limit),
  cargo=S.GetUnitIsTransporting(id)or{}}
end
local function ensure()
 if R then return R end
 local A=api();if not A or not A.Get or not A.SlotDef or not A.Capacity or not A.Changed or not GG.Recoil40KSquads then return end
 local dependencies={
  State=function(seed)return GG.Recoil40KSquads.squads[seed]end,
  Capacity=function(seed)return api().Capacity(seed)end,SlotDef=function(seed,slot)return api().SlotDef(seed,slot)end,
  Definition=definition,Body=body,Carrier=carrier,Allied=S.AreTeamsAllied,Frame=S.GetGameFrame,
  Changed=function(seed)persistenceDirty=true;api().Changed(seed)end}
 R=VFS.Include('40k_configs/squad_transport_policy.lua').New(dependencies)
 saver=VFS.Include('40k_configs/squad_transport_save.lua').New(S,dependencies,VFS.Include('40k_configs/active_squad_profiles.lua'))
 local ok,why=saver.Restore(R);assert(ok,'Squad cargo saved state refused: '..tostring(why))
 persistenceDirty=false
 GG.Recoil40KSquadTransport=R;return R
end
local function options(opts,append)
 local code=type(opts)=='number'and opts or(opts and opts.coded or 0)
 local shift=CMD.OPT_SHIFT or 32
 if append and code%(shift*2)<shift then code=code+shift end
 return code
end
local function queued(opts)local shift=CMD.OPT_SHIFT or 32;return options(opts,false)%(shift*2)>=shift end
local function emit(carrierID,members,cmd,params,opts,passengerOrder)
 local previous=forwarding;forwarding=true
 local ok,why=pcall(function()for i,id in ipairs(members)do
   if passengerOrder then S.GiveOrderToUnit(id,cmd,params,options(opts,false))
   else S.GiveOrderToUnit(carrierID,cmd,{id},options(opts,i>1))end
  end end)
 forwarding=previous;if not ok then error(why)end
end
function gadget:AllowCommand(id,def,team,cmd,params,opts,cmdTag,playerID,fromSynced,fromLua,fromInsert)
 if forwarding then return true end
 if fromInsert then
  -- BAR dispatch already unpacked the inner command. Scheduling a queue
  -- entry must not reserve/load cargo or cancel a current reservation now.
  local A=api();local involves
  if A and A.Get then
   if cmd==CMD.LOAD_ONTO then involves=A.Get(id)
   elseif cmd==CMD.LOAD_UNITS then
    if #params==1 then involves=A.Get(params[1])
    elseif #params==4 then for _,target in ipairs(S.GetUnitsInCylinder(params[1],params[3],params[4])or{})do if A.Get(target)then involves=true;break end end end
   end
  end
  if involves then S.Echo('40K SQUAD TRANSPORT nested insert squad pickup unsupported; use normal queued load');return false end
  return true
 end
 local policy=ensure();if not policy then return true end
 local A=api()
 if cmd==CMD.INSERT and(params[2]==CMD.LOAD_UNITS or params[2]==CMD.LOAD_ONTO)then
  local involves= params[2]==CMD.LOAD_ONTO and A.Get(id)or(#params==4 and A.Get(params[4]))
  if #params==7 and params[2]==CMD.LOAD_UNITS then
   for _,target in ipairs(S.GetUnitsInCylinder(params[4],params[6],params[7])or{})do if A.Get(target)then involves=true;break end end
  end
  if involves then S.Echo('40K SQUAD TRANSPORT nested insert squad pickup unsupported; use normal queued load');return false end
 end
 if cmd==CMD.LOAD_ONTO and #params==1 then
  local s=A.Get(id);if not s then return true end
  local members,why=policy.Request(params[1],s.id)
  if not members then S.Echo('40K SQUAD TRANSPORT rejected',why);return false end
  flush() -- Pin original fixed-slot generations before the first native load.
  emit(params[1],members,cmd,params,opts,true);return false
 end
 local selectedSquad=A.Get(id)
 if selectedSquad and policy.Reserved(selectedSquad.id)and(cmd==CMD.STOP or cmd==CMD.MOVE)and not queued(opts)then policy.CancelSeed(selectedSquad.id);flush()end
 if not carrier(id)then return true end
 if cmd==CMD.LOAD_UNITS then
  local targets={};local squads={};local ordinary={}
  if #params==1 then targets={params[1]}
  elseif #params==4 then targets=S.GetUnitsInCylinder(params[1],params[3],params[4])or{};table.sort(targets)
  else return true end
  for _,target in ipairs(targets)do local s=A.Get(target)
   if s then squads[s.id]=true else ordinary[#ordinary+1]=target end
  end
  if not next(squads)then return true end
  local seeds={};for seed in pairs(squads)do seeds[#seeds+1]=seed end;table.sort(seeds)
  local members,started={},{}
  for _,seed in ipairs(seeds)do
   local ids,why=policy.Request(id,seed)
   if not ids then for _,old in ipairs(started)do policy.CancelSeed(old)end;flush();S.Echo('40K SQUAD TRANSPORT rejected',why);return false end
   started[#started+1]=seed;for _,member in ipairs(ids)do members[#members+1]=member end
  end
  flush()
  for _,target in ipairs(ordinary)do members[#members+1]=target end
  emit(id,members,cmd,params,opts,false);return false
 elseif(cmd==CMD.UNLOAD_UNITS or cmd==CMD.UNLOAD_UNIT)and not queued(opts)then policy.BeginUnload(id);flush()
 elseif(cmd==CMD.STOP or cmd==CMD.MOVE)and not queued(opts)then policy.Cancel(id);flush()end
 return true
end
function gadget:AllowUnitTransport(transport,transportDef,transportTeam,passenger,passengerDef,passengerTeam)
 local policy=ensure();if not policy then return true end
 return policy.Permit(transport,passenger)
end
-- GameFrame starts only after squad Initialize and native cargo restoration.
function gadget:Initialize()end
-- Observe genuine engine callbacks; never override native alignment/placement.
local function changed()if R then persistenceDirty=true end end
function gadget:UnitLoaded()changed()end
function gadget:UnitUnloaded()changed()end
function gadget:UnitDestroyed()changed()end
function gadget:UnitTaken()changed()end
function gadget:UnitGiven()changed()end
function gadget:GameFrame(frame)
 if frame%15==0 or persistenceDirty then local policy=ensure();if policy then policy.Tick()end end
 -- UnitDestroyed/capture observers run above squad layer40; wait until its
 -- membership update has finished before validating the persisted records.
 if persistenceDirty then flush()end
end
function gadget:Shutdown()if GG.Recoil40KSquadTransport==R then GG.Recoil40KSquadTransport=nil end end
