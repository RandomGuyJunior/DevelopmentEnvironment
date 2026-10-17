function gadget:GetInfo()
 return {name='40K Necron possession',desc='Source Lord possession and manual reversal',author='Local project',layer=60,enabled=true}
end
local config=VFS.Include('40k_configs/necron_possession.lua')
if not gadgetHandler:IsSyncedCode()then
 local selected={}
 local function start(_,id)selected[id]=false;for _,u in ipairs(Spring.GetSelectedUnits() or {})do if u==id then selected[id]=true end end end
 local function cancel(_,id)selected[id]=nil end
 local function replace(_,old,new,team)
  local keep=selected[old];selected[old]=nil
  if keep and team==Spring.GetMyTeamID()then local list=Spring.GetSelectedUnits() or {};list[#list+1]=new;Spring.SelectUnitArray(list)end
 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('40k_nec_start',start);gadgetHandler:AddSyncAction('40k_nec_cancel',cancel);gadgetHandler:AddSyncAction('40k_nec_replace',replace)end
 function gadget:Update()for id in pairs(selected)do selected[id]=false;for _,u in ipairs(Spring.GetSelectedUnits() or {})do if u==id then selected[id]=true end end end end
 function gadget:Shutdown()for _,key in ipairs({'start','cancel','replace'})do gadgetHandler:RemoveSyncAction('40k_nec_'..key)end end
 return
end
local controller,lord,form,internal,replacing
local acceptanceAPI,acceptanceRequests=nil,{}
local damageBefore={}
local options=Spring.GetModOptions and Spring.GetModOptions() or {}
local diagnostic=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression) and (options.prototype_diagnostic=='roster' or options.prototype_diagnostic=='expandedproduction')
local possessionReview=diagnostic and options.prototype_source_acceptance=='necrons'
local public={public=true}
-- Only actual source-acceptance transition boundaries emit outcomes. No polling.
local traceContext={}
local function outcome(id,event,...)
 if possessionReview and Spring.Echo then Spring.Echo('40K NEC POSSESSION OUTCOME',Spring.GetGameFrame(),id,event,...)end
end
local function alive(id)return Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id)end
local function order(id,cmd,params,options)internal=true;Spring.GiveOrderToUnit(id,cmd,params,options);internal=false end
local function teamCount(team)
 local n=0;for _,id in ipairs(Spring.GetTeamUnits(team) or {})do local d=Spring.GetUnitDefID(id);if d==lord.id or d==form.id then n=n+1 end end;return n
end
-- Readiness is queried repeatedly by native command descriptors and windup.
-- Share immutable exports with unit scripts instead of reparsing megabytes.
local function animation(key)
 GG.Prototype40kAnimationCache=GG.Prototype40kAnimationCache or {}
 local cache=GG.Prototype40kAnimationCache
 if not cache[key]then cache[key]=VFS.Include('scripts/generated/'..key..'_anim.lua')end
 return cache[key]
end
local function ready()
 for _,key in ipairs({config.lord,config.form})do
  if (not diagnostic and not VFS.FileExists('40k_configs/validated/'..key..'.lua')) or not VFS.FileExists('objects3d/'..key..'.glb') or not VFS.FileExists('scripts/generated/'..key..'_anim.lua')then return false end
 end
 local night=animation(config.form).clips
 for key,source in pairs({idle='idle_1',walk='move_run1',fire='idle_firing',melee='melee_attack_1',cape_idle='cape_idle_1',cape_walk='cape_move_run1',cape_melee='cape_melee_idle_1'})do
  if not night or not night[key] or night[key].source~=source or not night[key].duration or night[key].duration<=0 then return false end
 end
 local clip=animation(config.lord).clips
 return clip and clip.possession and clip.possession.source==config.sourceAction and clip.possession.duration and clip.possession.duration>0
  and GG.Recoil40KResearch and type(GG.Recoil40KResearch.HasResearch)=='function'
  and type(GG.Recoil40KResearch.RegisterEffectHandler)=='function' and type(GG.Recoil40KResearch.WithCreationPermit)=='function'
end
local function idle(id)
 if not alive(id) or Spring.GetUnitTransporter(id) or Spring.GetUnitIsBuilding(id) or Spring.GetUnitIsStunned(id)then return false end
 local hp,_,_,_,progress=Spring.GetUnitHealth(id);local carried=Spring.GetUnitIsTransporting(id)
 local _,_,_,speed=Spring.GetUnitVelocity(id)
 return hp and hp>0 and progress==1 and not (carried and #carried>0) and speed and speed<.025
end
local function clear(id,key)
 if not alive(id)then return false,'actor_not_alive' end
 local d=key==config.lord and lord or form;local x,y,z=Spring.GetUnitPosition(id)
 if not x then return false,'position_missing' end
 local ground=Spring.GetGroundHeight(x,z)
 if ground<=0 then return false,'ground_not_land',ground,x,z end
 local radius=math.max(d.radius or 32,(d.xsize or 2)*(Game.squareSize or 8)/2)
 if x<radius or z<radius or x>Game.mapSizeX-radius or z>Game.mapSizeZ-radius then return false,'map_edge',radius,x,z end
 for _,other in ipairs(Spring.GetUnitsInRectangle(x-radius-128,z-radius-128,x+radius+128,z+radius+128) or {})do
  if other~=id and alive(other)then local ox,_,oz=Spring.GetUnitPosition(other);local od=UnitDefs[Spring.GetUnitDefID(other)]
   if ox and (ox-x)^2+(oz-z)^2<(radius+(od.radius or 32))^2 then return false,'unit_overlap',other,Spring.GetUnitDefID(other),math.sqrt((ox-x)^2+(oz-z)^2),radius+(od.radius or 32) end
  end
 end
 local features=Spring.GetFeaturesInRectangle(x-radius,z-radius,x+radius,z+radius) or {}
 if #features>0 then return false,'feature_rectangle',features[1],#features,radius end
 local movable=Spring.TestMoveOrder(d.id,x,y,z,0,0,0,true,false,false)
 if not movable then return false,'test_move_terrain',d.id,x,y,z,radius end
 return movable,'clear'
end
local function pose(id,label,start,finish)
 Spring.SetUnitRulesParam(id,'40k_transition_clip',label,public);Spring.SetUnitRulesParam(id,'40k_transition_start',start,public);Spring.SetUnitRulesParam(id,'40k_transition_end',finish,public)
 local mirror=GG.Prototype40kTransitionState;if mirror then mirror.known[id]=true;mirror.values[id]=label and {label,start,finish} or nil end
end
local function descriptor(id)
 if not alive(id)then return end
 local d=Spring.GetUnitDefID(id);local cmd=d==lord.id and config.command or d==form.id and config.revertCommand
 if not cmd then return end
 local desc={id=cmd,type=CMDTYPE.ICON,name=d==lord.id and 'Nightbringer' or 'Revert',action=d==lord.id and '40kpossess' or '40krevert',tooltip=d==lord.id and 'Possess the Lord after Ctan research; one-for-one health percentage transfer' or 'Return this manifestation to its Lord form',disabled=controller.IsPending(id) or (d==lord.id and not controller.CanBegin(id,Spring.GetGameFrame()))}
 local index=Spring.FindUnitCmdDesc(id,cmd);if index then Spring.EditUnitCmdDesc(id,index,desc)else Spring.InsertUnitCmdDesc(id,desc)end
end
local stateCodec=VFS.Include('40k_configs/necron_possession_state.lua')
local api={ready=ready,alive=alive}
function api.identity(id)
 if not alive(id)then return end
 local token=Spring.GetUnitRulesParam(id,'40k_nec_identity')
 if not token then token=Spring.GetGameFrame()*1048576+id;Spring.SetUnitRulesParam(id,'40k_nec_identity',token,{allied=true})end
 return {def=Spring.GetUnitDefID(id),team=Spring.GetUnitTeam(id),token=token}
end
function api.validIdentity(id,record,key)
 if not alive(id) or type(record)~='table' then return false end
 local expected=key==config.lord and lord.id or form.id
 return Spring.GetUnitDefID(id)==expected and record.def==expected and record.team==Spring.GetUnitTeam(id)
  and record.token~=nil and record.token==Spring.GetUnitRulesParam(id,'40k_nec_identity')
end
function api.persist(id,kind,state)stateCodec.Write(Spring,id,kind,state)end
function api.validLord(id)return idle(id) and Spring.GetUnitDefID(id)==lord.id end
function api.researched(id,key)return GG.Recoil40KResearch and GG.Recoil40KResearch.HasResearch(Spring.GetUnitTeam(id),key)==true end
function api.hasBuilding(id,key)
 local d=UnitDefNames[key];if not d then return false end
 for _,u in ipairs(Spring.GetTeamUnits(Spring.GetUnitTeam(id)) or {})do
  if Spring.GetUnitDefID(u)==d.id then local hp,_,_,_,p=Spring.GetUnitHealth(u);if hp and hp>0 and p==1 then return true end end
 end;return false
end
function api.cap(id)return teamCount(Spring.GetUnitTeam(id))==1 end
api.clear=clear
-- Acceptance-only read-only view of the actual controller/native prerequisites.
local function acceptancePrerequisites(id)
 if not controller or not alive(id)then return {valid=false}end
 local clearOkay,reason=clear(id,config.form)
 return {valid=true,pending=controller.IsPending(id),form=controller.IsForm(id),cooldown=controller.Cooldown(id),
  validLord=api.validLord(id),ready=ready(),research=api.researched(id,config.research),
  archive=api.hasBuilding(id,config.building),cap=api.cap(id),clear=clearOkay,reason=reason,
  eligible=controller.CanBegin(id,Spring.GetGameFrame())}
end
local function copyAcceptance(row)
 if not row then return end;local out={}
 for k,v in pairs(row)do if type(v)=='table'then local sub={};for a,b in pairs(v)do sub[a]=b end;out[k]=sub else out[k]=v end end
 return out
end
function api.snapshot(id)
 local states=Spring.GetUnitStates(id) or {};local bt,m,e=Spring.GetUnitCosts(id)
 return {team=Spring.GetUnitTeam(id),queue=Spring.GetCommandQueue(id,-1) or {},firestate=states.firestate or 2,movestate=states.movestate or 1,costs={buildTime=bt,metalCost=m,energyCost=e}}
end
function api.unchanged(id,s)return idle(id) and Spring.GetUnitTeam(id)==s.team end
function api.pose(id,label,start,finish)
 -- The actual source script blocks AimWeapon/BlockShot throughout this rule span.
 -- Preserve the user's fire state: stock Holdfire Fix responds to FIRE_STATE0
 -- with a network INSERT(STOP), which would cancel this newly pending action.
 pose(id,label,start,finish);order(id,CMD.STOP,{},{})
 SendToUnsynced('40k_nec_start',id)
end
local function replay(id,queue,construction)
 for _,c in ipairs(queue)do if c.id~=config.command and c.id~=config.revertCommand and c.id~=CMD.STOP and (c.id>0 or construction)then order(id,c.id,c.params or {},{'shift'})end end
end
function api.cancel(id,s)
 if possessionReview then
  local context=traceContext[id];local reason=context and context.reason;local detail
  if not reason then
   if not alive(id)then reason='actor_lost'
   elseif Spring.GetUnitTeam(id)~=s.team then reason='owner_changed'
   elseif not idle(id)then reason='actor_not_idle'
   elseif not ready()then reason='readiness_lost'
   elseif not api.researched(id,config.research)then reason='research_lost'
   elseif not api.hasBuilding(id,config.building)then reason='archive_lost'
   else
    local finish=Spring.GetUnitRulesParam(id,'40k_transition_end')
    if finish and Spring.GetGameFrame()>=finish then local okay,why=clear(id,config.form);if not okay then reason='finish_clearance';detail=why end end
    reason=reason or 'cancel_without_prerequisite_loss'
   end
  end
  outcome(id,reason=='replacement_native_reclaim' and 'RECLAIM_BOOKKEEPING' or 'CANCEL',reason,'detail',detail,'new',context and context.new)
  traceContext[id]=nil
 end
 if alive(id)then pose(id,nil,nil,nil);order(id,CMD.FIRE_STATE,{s.firestate},{});replay(id,s.queue,true)end
 SendToUnsynced('40k_nec_cancel',id)
end
function api.replace(id,key,original,revert)
 if not alive(id)then return end
 local hp,max,para,capture=Spring.GetUnitHealth(id);local exp=Spring.GetUnitExperience(id) or 0
 if not max or max<=0 then return end
 local x,y,z=Spring.GetUnitPosition(id);local dx,dy,dz=Spring.GetUnitDirection(id);local team=Spring.GetUnitTeam(id)
 local d=key==config.lord and lord or form;local queue=revert and (Spring.GetCommandQueue(id,-1) or {}) or original.queue
 local states=revert and (Spring.GetUnitStates(id) or {}) or original
 SendToUnsynced('40k_nec_start',id)
 replacing=true;GG.Prototype40kTransform={from=id,toDef=d.id,team=team,kind='necron_possession'}
 if possessionReview then traceContext[id]={reason='native_replace_attempt'};outcome(id,'REPLACE_BEGIN',key,'revert',revert)end
 local ok,new=pcall(function()
  local permitOK,created=GG.Recoil40KResearch.WithCreationPermit(team,d.id,id,function()
   return Spring.CreateUnit(d.id,x,y,z,math.floor(((Spring.GetUnitHeading(id) or 0)%65536)/16384+.5)%4,team,false,false)
  end)
  if possessionReview then
   if not permitOK then traceContext[id]={reason='creation_permit_refused'};outcome(id,'PERMIT_REFUSED',created)
   elseif not created then traceContext[id]={reason='native_create_nil'};outcome(id,'CREATE_NIL',key)end
  end
  if not permitOK then return nil end;return created
 end)
 GG.Prototype40kTransform=nil;replacing=false
 if possessionReview and not ok then traceContext[id]={reason='native_replace_exception'};outcome(id,'REPLACE_EXCEPTION',new)end
 if not ok or not new then SendToUnsynced('40k_nec_cancel',id);return end
 Spring.SetUnitExperience(new,exp);local _,newMax=Spring.GetUnitHealth(new)
 if not newMax or newMax<=0 then
  if possessionReview then traceContext[id]={reason='created_health_invalid'};outcome(id,'CREATED_HEALTH_INVALID',new,newMax)end
  Spring.DestroyUnit(new,false,true);SendToUnsynced('40k_nec_cancel',id);return end
 Spring.SetUnitHealth(new,{health=math.max(.001,newMax*hp/max),paralyze=(para or 0)*newMax/max,capture=capture or 0})
 Spring.SetUnitCosts(new,original.costs);if dx then Spring.SetUnitDirection(new,dx,dy,dz)end
 order(new,CMD.FIRE_STATE,{states.firestate or original.firestate},{});order(new,CMD.MOVE_STATE,{states.movestate or original.movestate},{})
 -- Reclaimed morph never awards a second paid Lord or returns its cost.
 Spring.SetUnitRulesParam(new,'40k_transform_from',id,public)
 if possessionReview then traceContext[id]={reason='replacement_native_reclaim',new=new}end
 if GG.Recoil40KNightAbility then GG.Recoil40KNightAbility.OnReplacement(id,new,team)end
 Spring.DestroyUnit(id,false,true)
 replay(new,queue,revert)
 if revert then local suspended={};for _,c in ipairs(original.queue)do if c.id<0 then suspended[#suspended+1]=c end end;replay(new,suspended,true)end
 SendToUnsynced('40k_nec_replace',id,new,team)
 if possessionReview then outcome(id,'REPLACE_COMPLETE',key,'new',new,'team',team);traceContext[id]=nil end
 return new
end
function gadget:Initialize()
 lord=UnitDefNames[config.lord];form=UnitDefNames[config.form]
 if not lord or not form or not ready()then gadgetHandler:RemoveGadget(self);return end
 lord=UnitDefs[lord.id];form=UnitDefs[form.id]
 -- Manifestation remains the same commander identity for native victory/economy.
 if not lord.customParams or not form.customParams or not lord.customParams.iscommander or lord.customParams.iscommander~=form.customParams.iscommander or form.health~=config.formHealth then gadgetHandler:RemoveGadget(self);return end
 controller=config.New(api,Game.gameSpeed or 30)
 if GG.Recoil40KResearch.RegisterEffectHandler(config.research)~=true then gadgetHandler:RemoveGadget(self);controller=nil;return end
 gadgetHandler:RegisterCMDID(config.command);gadgetHandler:RegisterCMDID(config.revertCommand)
 local saved={version=1,units={}}
 for _,id in ipairs(Spring.GetAllUnits())do local row=stateCodec.Read(Spring,id);if row then saved.units[id]=row end end
 local accepted,rejected=controller.Restore(saved)
 if Spring.Echo then Spring.Echo('40K Necron possession restore',accepted,rejected)end
 if possessionReview then
  acceptanceAPI={Prerequisites=acceptancePrerequisites,LastRequest=function(id)return copyAcceptance(acceptanceRequests[id])end}
  GG.Recoil40KNecronAcceptance=acceptanceAPI
 end
 for _,id in ipairs(Spring.GetAllUnits())do if controller.IsPending(id)then SendToUnsynced('40k_nec_start',id)end;descriptor(id)end
end
-- Explicit acceptance-only diagnostics: one read-only report per actual request,
-- never descriptor polling. Normal commands retain original short-circuit behavior.
local function reportRequest(id,d,cmd)
 if not possessionReview or not Spring.Echo then return end
 local target=d==lord.id and config.form or config.lord
 local okay,reason,a,b,c,e=clear(id,target)
 local hp,max,_,_,progress=Spring.GetUnitHealth(id)
 local _,_,_,speed=Spring.GetUnitVelocity(id)
 local carried=Spring.GetUnitIsTransporting(id)
 Spring.Echo('40K NEC POSSESSION REQUEST',Spring.GetGameFrame(),id,cmd,
  'pending',controller.IsPending(id),'form',controller.IsForm(id),'cooldown',controller.Cooldown(id),
  'validLord',api.validLord(id),'ready',ready(),'research',api.researched(id,config.research),
  'archive',api.hasBuilding(id,config.building),'cap',api.cap(id),
  'clear',okay,'reason',reason,'detail',a,b,c,e,
  'hp',hp,max,'progress',progress,'speed',speed,'stunned',Spring.GetUnitIsStunned(id),
  'transport',Spring.GetUnitTransporter(id),'building',Spring.GetUnitIsBuilding(id),'carried',carried and #carried or 0)
end
function gadget:AllowCommand(id,d,team,cmd)
 if internal or not controller then return true end
 if d~=lord.id and d~=form.id then return true end
 if cmd==config.command then
  reportRequest(id,d,cmd)
  local prerequisites=possessionReview and acceptancePrerequisites(id)
  local begun=controller.Begin(id,Spring.GetGameFrame())
  if possessionReview then
   local previous=acceptanceRequests[id]
   acceptanceRequests[id]={serial=(previous and previous.serial or 0)+1,frame=Spring.GetGameFrame(),command=cmd,
    begun=begun,pending=controller.IsPending(id),prerequisites=prerequisites}
   outcome(id,'BEGIN',begun,'pending',controller.IsPending(id))
  end
  return false
 end
 if cmd==config.revertCommand then reportRequest(id,d,cmd);controller.Revert(id,Spring.GetGameFrame());return false end
 if controller.IsPending(id)then if cmd==CMD.STOP then if possessionReview then traceContext[id]={reason='explicit_stop'}end;controller.Cancel(id);return true end;return false end
 return true
end
function gadget:AllowUnitCreation(d,builder,team)
 if not controller or replacing then return true end
 if d==form.id then return false end
 if d==lord.id and teamCount(team)>0 then return false end;return true
end
function gadget:UnitFinished(id)if controller then descriptor(id)end end
function gadget:UnitDestroyed(id)if controller then controller.Destroyed(id)end end
function gadget:UnitTaken(id)if controller then controller.Transferred(id)end end
function gadget:UnitGiven(id)if controller then controller.Transferred(id);descriptor(id)end end
function gadget:UnitLoaded(id)if controller then controller.Cancel(id)end end
function gadget:GameFrame(frame)
 if not controller then return end;controller.Tick(frame)
 if frame%15==0 then for _,id in ipairs(Spring.GetAllUnits())do descriptor(id)end end
end

function gadget:Shutdown()
 if acceptanceAPI and GG.Recoil40KNecronAcceptance==acceptanceAPI then GG.Recoil40KNecronAcceptance=nil end
 if controller then local saved=controller.Export();for id,row in pairs(saved.units)do api.persist(id,row.kind,row.state)end end
end

-- Translate source fixed35/50HP leech once per real, non-paralyzing hostile hit.
-- Source/native Night health both15000: scale1. Armor/overkill/zero damage cannot
-- create health; healing caps at the native manifestation's current maximum.
function gadget:UnitPreDamaged(id,d,team,damage,paralyzer,weapon,projectile,attacker)
 if not controller or not attacker or not controller.IsForm(attacker) or paralyzer or damage<=0 then return end
 local w=WeaponDefs[weapon];local cp=w and w.customParams
 if not cp or not tonumber(cp.source_life_leech_damage) then return end
 local hp=Spring.GetUnitHealth(id)
 damageBefore[id]={attacker=attacker,weapon=weapon,hp=math.max(0,hp or 0)}
end
function gadget:UnitDamaged(id,d,team,damage,paralyzer,weapon,projectile,attacker)
 local before=damageBefore[id];damageBefore[id]=nil
 if not before or before.attacker~=attacker or before.weapon~=weapon or paralyzer or damage<=0 or not alive(attacker) or not controller.IsForm(attacker)then return end
 if Spring.AreTeamsAllied(team,Spring.GetUnitTeam(attacker))then return end
 local amount=tonumber(WeaponDefs[weapon].customParams.source_life_leech_damage)
 local hp,max=Spring.GetUnitHealth(attacker);if not hp or hp<=0 or not max or max<=0 then return end
 local heal=math.min(damage,before.hp,amount*(form.health/config.formHealth))
 if heal>0 then Spring.SetUnitHealth(attacker,{health=math.min(max,hp+heal)})end
end
