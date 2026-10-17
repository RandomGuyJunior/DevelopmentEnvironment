-- Per-post paid native commands. No unit replacement, resource production or damage writes.
local M={}
local function finite(v)return type(v)=='number'and v==v and v>=0 and v<math.huge end
local function integer(v)return finite(v)and v==math.floor(v)end
local function sorted(t)local out={};for k in pairs(t or{})do out[#out+1]=k end;table.sort(out);return out end
local PREFIX='40k_post_'
function M.Attach(C,S,defs,config,hooks,CMD,CMDTYPE,fps)
 assert(not C.listeningPosts,'Listening posts already attached')
 assert(type(hooks.Ready)=='function'and type(hooks.Apply)=='function'and type(hooks.WeaponAllowed)=='function','Complete model/effect hooks required')
 assert(integer(fps)and fps>0,'Native game speed required')
 local UPGRADE,CANCEL=config.Commands.upgrade,config.Commands.cancel
 assert(not C.commands[UPGRADE]and not C.commands[CANCEL],'Command ID collision')
 local R={units={},jobs={},failed={},pending={}};local removing=false
 local prerequisites={}
 for _,p in pairs(config.Profiles)do for _,stage in ipairs(p.stages)do for _,name in ipairs(stage.requires_buildings)do prerequisites[name]=true end end end
 local old={};for _,k in ipairs({'Allow','Fallback','Frame','Cancel','Refresh','RestorePending','Register','Finished','Remove'})do old[k]=assert(C[k])end
 local function rule(id,key)local value=S.GetUnitRulesParam(id,PREFIX..key);return value end
 local function set(id,key,value)S.SetUnitRulesParam(id,PREFIX..key,value,{allied=true})end
 local function stamp(stage)return tonumber(stage.source_sha256:sub(1,6),16)end
 local function profile(def)local d=defs[def];local p=d and config.Profiles[d.name]
  if p and (d.customParams or{}).faction==p.faction then return p end
 end
 local function finished(id,u)
  local hp,_,_,_,built=S.GetUnitHealth(id)
  return hp and hp>0 and built==1 and S.GetUnitTeam(id)==u.team and S.GetUnitDefID(id)==u.def
 end
 local function eligible(id,u,level)
  local stage=u.profile.stages[level]
  if not stage or level~=u.level+1 or R.failed[id]or not finished(id,u)or hooks.Ready(id,u.def,level)~=true then return false end
  return C.Requirement(u.team,{buildings=stage.requires_buildings},id,false)==true
 end
 local function jobRules(id,j)
  local values={job=j and 1 or 0,job_team=j and j.team or -1,job_level=j and j.level or 0,job_tag=j and j.tag or -1,
   job_steps=j and j.steps or 0,job_frames=j and j.frames or 0,job_metal=j and j.metal or 0,job_energy=j and j.energy or 0,
   job_source=j and stamp(j.stage)or 0,progress=j and j.steps/j.frames or 0}
  for _,k in ipairs(sorted(values))do set(id,k,values[k])end
 end
 local function entry(id,j)
  for n,row in ipairs(S.GetUnitCommands(id,-1)or{})do
   if row.id==UPGRADE and integer(row.tag)and row.tag==j.tag then return row,n==1 end
  end
 end
 local function cancel(id,remove)
  if not R.units[id]and not R.jobs[id]and not R.pending[id]then return end
  local j=R.jobs[id];R.jobs[id]=nil;R.pending[id]=nil;jobRules(id,nil);set(id,'paused',0)
  local u=R.units[id]
  if remove and u and S.GetUnitTeam(id)==u.team then
   local tags={}
   for _,row in ipairs(S.GetUnitCommands(id,-1)or{})do
    if row.id==UPGRADE and integer(row.tag)and(not j or row.tag==j.tag)then tags[#tags+1]=row.tag end
   end
   for _,tag in ipairs(tags)do removing=true;S.GiveOrderToUnit(id,CMD.REMOVE,{tag},{});removing=false end
  end
 end
 local function descriptor(id,cmd,desc)
  local index=S.FindUnitCmdDesc(id,cmd)
  if desc then
   if index then S.EditUnitCmdDesc(id,index,desc)else S.InsertUnitCmdDesc(id,desc)end
  elseif index then S.RemoveUnitCmdDesc(id,index)end
 end
 function R.Refresh(id)
  local u=R.units[id];if not u then return end
  local level=u.level+1;local stage=u.profile.stages[level];local j=R.jobs[id]
  local tooltip='All defensive upgrades completed on this post.'
  if stage then
   tooltip='Fortify this listening post. Metal: '..stage.metal..'  Energy: '..stage.energy..'  Time: '..stage.seconds..'s\n'
    ..'Maximum health bonus +'..stage.health_add..'; '..(stage.armed and 'armed defence.'or'unarmed fortification.')..' Resource production continues.'
   if #stage.requires_buildings>0 then
    local labels={};for _,name in ipairs(stage.requires_buildings)do for _,d in pairs(defs)do if d.name==name then labels[#labels+1]=d.humanName or d.name;break end end end
    tooltip=tooltip..'\nRequires completed '..table.concat(labels,', ')
   end
   if j then tooltip=tooltip..'\nUpgrade in progress; cancellation does not refund spent resources.'end
  end
  local desc=stage and{id=UPGRADE,type=CMDTYPE.ICON,name='Fortify '..math.min(level,2),action='40k_post_upgrade',tooltip=tooltip,disabled=not eligible(id,u,level)or j~=nil or R.pending[id]~=nil}
  descriptor(id,UPGRADE,desc)
  descriptor(id,CANCEL,(j or R.pending[id])and{id=CANCEL,type=CMDTYPE.ICON,name='Cancel upgrade',action='40k_post_cancel',tooltip='Cancel this post upgrade. Spent resources are not refunded.'}or nil)
 end
 -- Only prerequisite lifecycle events touch other registered posts. No army poll.
 local function refreshPrerequisites(actor)
  if not actor or not actor.finished or not prerequisites[actor.name]then return end
  for _,id in ipairs(sorted(R.units))do if R.units[id].team==actor.team then R.Refresh(id)end end
 end
 local function apply(id,u,level)
  local okay,result=pcall(hooks.Apply,id,u.def,level,u.profile)
  if not okay or result~=true then R.failed[id]=true;set(id,'failed',1);return false end
  u.level=level;set(id,'level',level);set(id,'source',level>0 and stamp(u.profile.stages[level])or 0);return true
 end
 function R.Register(id)
  local actor=C.units[id];local p=actor and profile(actor.def)
  if not p or hooks.Ready(id,actor.def,0)~=true then return end
  local level=rule(id,'level')or 0
  if not integer(level)or level>2 or level>0 and rule(id,'source')~=stamp(p.stages[level])then R.failed[id]=true;level=0 end
  local u={team=actor.team,def=actor.def,profile=p,level=level};R.units[id]=u
  if actor.finished and not R.failed[id]then apply(id,u,level)end
  R.Refresh(id)
 end
 function R.Restore(id)
  local u=R.units[id];if not u or rule(id,'job')~=1 then return end
  local level=rule(id,'job_level');local stage=integer(level)and u.profile.stages[level]
  local steps,tag=rule(id,'job_steps'),rule(id,'job_tag');local frames=stage and math.ceil(stage.seconds*fps)
  local metal,energy=rule(id,'job_metal'),rule(id,'job_energy')
  local valid=stage and eligible(id,u,level)and rule(id,'job_team')==u.team and rule(id,'job_source')==stamp(stage)
   and integer(steps)and steps<frames and integer(tag)and rule(id,'job_frames')==frames and finite(metal)and finite(energy)
  if valid then valid=math.abs(metal-stage.metal*steps/frames)<=math.max(1,metal)*1e-5 and math.abs(energy-stage.energy*steps/frames)<=math.max(1,energy)*1e-5 end
  if valid then
   local j={team=u.team,level=level,tag=tag,steps=steps,frames=frames,stage=stage,metal=stage.metal*steps/frames,energy=stage.energy*steps/frames}
   if entry(id,j)then R.jobs[id]=j;jobRules(id,j);R.Refresh(id);return end
  end
  cancel(id,true);R.Refresh(id)
 end
 function R.WeaponAllowed(id,mount)
  local u=R.units[id]
  return u and not R.failed[id]and finished(id,u)and hooks.Ready(id,u.def,u.level)==true and hooks.WeaponAllowed(id,u.def,u.level,mount)==true or false
 end
 function C.Allow(id,def,team,cmd,params,opts)
  if cmd==CMD.INSERT and params and(params[2]==UPGRADE or params[2]==CANCEL)then return false end
  if cmd==UPGRADE then
   local u=R.units[id]
   if not u or u.def~=def or u.team~=team or R.jobs[id]or R.pending[id]or not eligible(id,u,u.level+1)then return false end
   -- Admission reserves only this local button against duplicate clicks.
   -- Costs and persisted receipts begin only at the real native queue head.
   R.pending[id]=u.level+1;R.Refresh(id)
   return true
  elseif cmd==CANCEL then if R.units[id]then cancel(id,true);C.Refresh(id)end;return false
  elseif cmd==CMD.REMOVE and not removing then
   local j=R.jobs[id]
   if j then for _,tag in ipairs(params or{})do if opts and opts.alt and tag==UPGRADE or not(opts and opts.alt)and tag==j.tag then cancel(id,false);R.Refresh(id)end end end
  end
  return old.Allow(id,def,team,cmd,params,opts)
 end
 function C.Fallback(id,cmd,tag)
  if cmd~=UPGRADE then return old.Fallback(id,cmd,tag)end
  local u=R.units[id];local j=R.jobs[id]
  if not u or not integer(tag)then return true,true end
  if j then return true,tag~=j.tag end
  if not eligible(id,u,u.level+1)then R.pending[id]=nil;R.Refresh(id);return true,true end
  local rows=S.GetUnitCommands(id,1)or{};local head=rows[1]
  if not head or head.id~=cmd or head.tag~=tag then return true,false end
  R.pending[id]=nil
  local level=u.level+1;local stage=u.profile.stages[level]
  R.jobs[id]={team=u.team,level=level,stage=stage,frames=math.max(1,math.ceil(stage.seconds*fps)),steps=0,metal=0,energy=0,tag=tag}
  jobRules(id,R.jobs[id]);C.Refresh(id);return true,false
 end
 function C.Frame(frame)
  old.Frame(frame)
  for _,id in ipairs(sorted(R.pending))do
   local found=false;for _,row in ipairs(S.GetUnitCommands(id,-1)or{})do if row.id==UPGRADE then found=true;break end end
   if not found then R.pending[id]=nil;C.Refresh(id)end
  end
  for _,id in ipairs(sorted(R.jobs))do
   local j=R.jobs[id];local u=R.units[id];local row,head=entry(id,j)
   if not row or not u or not eligible(id,u,j.level)then cancel(id,true);C.Refresh(id)
   elseif head then
    local steps=j.steps+1;local metal=j.stage.metal*steps/j.frames;local energy=j.stage.energy*steps/j.frames
    if S.UseTeamResource(j.team,{metal=metal-j.metal,energy=energy-j.energy})then
     j.steps,j.metal,j.energy=steps,metal,energy;jobRules(id,j);set(id,'paused',0)
     if steps>=j.frames then apply(id,u,j.level);cancel(id,true);C.Refresh(id)end
    else set(id,'paused',1)end
   end
  end
 end
 function C.Cancel(id)cancel(id,true);return old.Cancel(id)end
 function C.Refresh(id)local out=old.Refresh(id);R.Refresh(id);return out end
 function C.Register(id,...)local out=old.Register(id,...);R.Register(id);refreshPrerequisites(C.units[id]);return out end
 function C.Finished(id)local out=old.Finished(id);R.Register(id);refreshPrerequisites(C.units[id]);return out end
 function C.Remove(id,dead)local actor=C.units[id];cancel(id,true);R.units[id]=nil;R.failed[id]=nil;local out=old.Remove(id,dead);refreshPrerequisites(actor);return out end
 function C.RestorePending(...)local out=old.RestorePending(...);for _,id in ipairs(sorted(C.units))do R.Register(id);R.Restore(id)end;return out end
 for _,id in ipairs(sorted(C.units))do R.Register(id);R.Restore(id)end
 R.HealthBonus=function(id)local u=R.units[id];return u and u.level>0 and u.profile.stages[u.level].health_add or 0 end
 C.listeningPosts=R;return R
end
return M
