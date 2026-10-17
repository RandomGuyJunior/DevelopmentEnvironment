-- UA literal possess_ext values; activation is free after paid research, never a factory product.
local M={command=34574,revertCommand=34575,lord='nec_lord',form='nec_nightbringer',
 research='nec_ctan_manifestation',building='nec_archive',windup=4.03000021,recharge=60,
 cost={metal=0,energy=0},transferHealthPercentage=true,sourceAction='possession',
 source='attrib/ebps/races/necrons/troops/necron_lord.lua',formHealth=15000}
-- Call during UnitDef assembly only after root artifact acceptance. Night combat
-- weapons/animations must already be genuine; this never invents a candidate.
function M.Configure(lord,form,ready)
 if ready~=true or type(lord)~='table' or type(form)~='table' or form.health~=M.formHealth then return false end
 if not lord.customparams or not lord.customparams.iscommander then return false end
 form.customparams=form.customparams or {}
 for _,k in ipairs({'iscommander','commander','faction','source_commander_founding_adaptation'})do form.customparams[k]=lord.customparams[k]end
 form.customparams.production_method='lord_transformation';form.customparams.possession_form=1
 for _,k in ipairs({'metalmake','energymake','metalstorage','energystorage','energyupkeep','metalupkeep'})do form[k]=lord[k]end
 form.maxthisunit=1;form.builder=false;form.buildoptions={}
 return true
end
-- Adapter owns native snapshots/replacement. This deterministic state machine owns
-- logical identity across forms. A failed native replacement leaves its source alive.
function M.New(api,fps)
 local pending,forms,cooldown={},{},{}
 local C={}
 local function sorted(t)local out={};for id in pairs(t)do out[#out+1]=id end;table.sort(out);return out end
 local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
 local function persist(id,kind,state)if api.persist then api.persist(id,kind,state)end end
 local function identity(id)return api.identity and api.identity(id)end
 local function finite(x)return type(x)=='number' and x==x and x>=0 and x<math.huge end
 local function snapshotValid(s)
  if type(s)~='table' or not finite(s.team) or type(s.queue)~='table' or type(s.costs)~='table' or not finite(s.firestate) or not finite(s.movestate)then return false end
  for _,k in ipairs({'buildTime','metalCost','energyCost'})do if not finite(s.costs[k])then return false end end
  for _,c in ipairs(s.queue)do
   if type(c)~='table' or type(c.id)~='number' or c.id~=math.floor(c.id) or type(c.params)~='table' then return false end
   for _,v in ipairs(c.params)do if type(v)~='number' or v~=v or math.abs(v)==math.huge then return false end end
  end;return true
 end
 function C.Export()
  local data={version=1,units={}}
  for id,s in pairs(pending)do data.units[id]={kind='pending',state=copy(s)}end
  for id,s in pairs(forms)do data.units[id]={kind='form',state=copy(s)}end
  for id,finish in pairs(cooldown)do data.units[id]={kind='cooldown',state={cooldown=finish,identity=copy(identity(id))}}end
  return data
 end
 function C.Restore(data)
  local accepted,rejected=0,0
  if type(data)~='table' or data.version~=1 or type(data.units)~='table' or not api.validIdentity then return 0,1 end
  local candidates={};for id in pairs(data.units)do if type(id)=='number' and id==math.floor(id)then candidates[id]=true else rejected=rejected+1 end end
  for _,id in ipairs(sorted(candidates))do
   local r=data.units[id];local s=type(r)=='table' and r.state;local kind=r and r.kind
   local key=kind=='form' and M.form or M.lord
   local valid=type(id)=='number' and id==math.floor(id) and type(s)=='table' and not pending[id] and not forms[id] and not cooldown[id]
    and api.validIdentity(id,s.identity,key)
   if valid and kind=='pending' then valid=snapshotValid(s.snapshot) and s.snapshot.team==s.identity.team and finite(s.finish)
   elseif valid and kind=='form' then valid=snapshotValid(s.snapshot) and s.snapshot.team==s.identity.team and finite(s.cooldown)
   elseif valid and kind=='cooldown' then valid=finite(s.cooldown)
   else valid=false end
   if valid then
    if kind=='pending'then pending[id]=copy(s) elseif kind=='form'then forms[id]=copy(s) else cooldown[id]=s.cooldown end
    accepted=accepted+1
   else rejected=rejected+1 end
  end
  return accepted,rejected
 end
 function C.CanBegin(id,frame)
  if pending[id] or forms[id] or frame<(cooldown[id] or 0) then return false end
  return api.validLord(id) and api.ready() and api.researched(id,M.research) and api.hasBuilding(id,M.building) and api.clear(id,M.form) and api.cap(id)
 end
 function C.Begin(id,frame)
  if not C.CanBegin(id,frame) then return false end
  local snapshot=api.snapshot(id)
  if not snapshot then return false end
  cooldown[id]=nil
  pending[id]={snapshot=snapshot,finish=frame+math.ceil(M.windup*fps),identity=identity(id)}
  persist(id,'pending',pending[id])
  api.pose(id,'possession',frame,pending[id].finish);return true
 end
 function C.Cancel(id)
  if pending[id]then api.cancel(id,pending[id].snapshot);pending[id]=nil;persist(id,nil)end
 end
 function C.Revert(id,frame)
  local state=forms[id];if not state or not api.alive(id) then return false end
  if not api.clear(id,M.lord) then return false end
  local new=api.replace(id,M.lord,state.snapshot,true)
  if not new then return false end
  forms[id]=nil;persist(id,nil);cooldown[new]=math.max(frame,state.cooldown);persist(new,'cooldown',{cooldown=cooldown[new],identity=identity(new)});return true,new
 end
 function C.Destroyed(id)C.Cancel(id);forms[id]=nil;cooldown[id]=nil end
 function C.Transferred(id)
  C.Cancel(id)
  if forms[id]then forms[id].identity=identity(id);forms[id].snapshot.team=forms[id].identity.team;forms[id].snapshot.queue={};persist(id,'form',forms[id])
  elseif cooldown[id]then persist(id,'cooldown',{cooldown=cooldown[id],identity=identity(id)})end
 end -- active form and cooldown follow current owner
 function C.Tick(frame)
  for _,id in ipairs(sorted(pending))do
   local s=pending[id]
   if not api.alive(id) or not api.unchanged(id,s.snapshot) or not api.ready() or not api.researched(id,M.research) or not api.hasBuilding(id,M.building) then C.Cancel(id)
   elseif frame>=s.finish then
    if not api.clear(id,M.form) then C.Cancel(id)
    else
     local new=api.replace(id,M.form,s.snapshot,false)
     if new then pending[id]=nil;forms[new]={snapshot=s.snapshot,cooldown=frame+math.ceil(M.recharge*fps),identity=identity(new)};cooldown[id]=nil;persist(new,'form',forms[new])
     else C.Cancel(id)end
    end
   end
  end
 end
 function C.IsPending(id)return pending[id]~=nil end
 function C.IsForm(id)return forms[id]~=nil end
 function C.Cooldown(id)return cooldown[id] or (forms[id] and forms[id].cooldown) or 0 end
 return C
end
return M
