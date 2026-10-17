function gadget:GetInfo()return{name='40K genuine Relic capture',desc='Source strategic-object capture ownership, not stock military capture',author='Local project',layer=64,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local o=Spring.GetModOptions()or{};if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression) or (o.prototype_diagnostic~='normal' and o.prototype_diagnostic~='expandedproduction')then return end
local M=VFS.Include('40k_configs/necron_relic_capture.lua');local P=VFS.Include('40k_configs/necron_relic_placement.lua')
local witnessEnabled=o.prototype_source_acceptance=='necrons' and o.prototype_diagnostic=='expandedproduction'
local witnessRows={};local witnessCount=0
local function witness(event,id,def,team,extra)
 if not witnessEnabled or witnessCount>=24 then return end
 witnessCount=witnessCount+1
 local hp,max,_,_,built=Spring.GetUnitHealth(id)
 local row={event=event,frame=Spring.GetGameFrame(),id=id,def=def,team=team,hp=hp,max=max,built=built,extra=extra}
 witnessRows[#witnessRows+1]=row
 Spring.Echo('40K RELIC LIFECYCLE',row.frame,event,id,def,team,hp or 'nil',max or 'nil',built or 'nil',extra or 'none')
end
local A,relic,scarab;local reviewed={};local placementAttempted=false;local gaia=Spring.GetGaiaTeamID()
local mapStamp={['Ravaged Remake v1.2']=1,['Ashen Bastion 0.1']=2}
local sourceStamp=tonumber('74da60',16)
local function ready()return relic and scarab and VFS.FileExists('objects3d/40k_relic_objective.glb') and true or false end
local function attach(id,site)
 if not ready()or not site or site.map~=Game.mapName or not P.AcceptedMaps[site.map]or site.def~=relic.id or Spring.GetUnitDefID(id)~=relic.id or Spring.GetUnitTeam(id)~=gaia then return false end
 local x,y,z=Spring.GetUnitPosition(id);if not x or math.abs(x-site.x)>.001 or math.abs(y-site.y)>.001 or math.abs(z-site.z)>.001 or y<=0 or site.clearance~=P.Clearance then return false end
 -- Receipt must be the exact result of our pre-creation native dry/clear placement
 -- finder retained by root. No manual arbitrary site table is accepted.
 if GG.Recoil40KRelicPlacementReceipt~=site then return false end
 reviewed[id]=true;Spring.SetUnitRulesParam(id,'40k_relic_reviewed',1,{private=true})
 for k,v in pairs({map=mapStamp[site.map],source=sourceStamp,x=x,y=y,z=z})do Spring.SetUnitRulesParam(id,'40k_relic_site_'..k,v,{private=true})end
 if Spring.GetUnitRulesParam(id,'40k_relic_owner')==nil then Spring.SetUnitRulesParam(id,'40k_relic_owner',-1,{public=true})end
 return true
end
local function restore(id)
 if Spring.GetUnitDefID(id)~=relic.id or Spring.GetUnitTeam(id)~=gaia or Spring.GetUnitIsDead(id)then return false end
 local hp,_,_,_,built=Spring.GetUnitHealth(id);if not hp or hp<=0 or built~=1 then return false end
 local function read(k)return Spring.GetUnitRulesParam(id,'40k_relic_site_'..k)end
 local x,y,z=Spring.GetUnitPosition(id);local owner=Spring.GetUnitRulesParam(id,'40k_relic_owner')
 local validOwner=owner==-1;for _,team in ipairs(Spring.GetTeamList()or{})do if owner==team and team~=gaia then validOwner=true end end
 if not validOwner or not x or y<=0 or Spring.GetUnitRulesParam(id,'40k_relic_reviewed')~=1
  or read('map')~=mapStamp[Game.mapName]or read('source')~=sourceStamp
  or type(read('x'))~='number'or type(read('y'))~='number'or type(read('z'))~='number'
  or math.abs(x-read('x'))>.001 or math.abs(y-read('y'))>.001 or math.abs(z-read('z'))>.001 then return false end
 reviewed[id]=true;return true
end
local function desc(id)
 if Spring.GetUnitDefID(id)~=scarab.id then return end
 if not Spring.FindUnitCmdDesc(id,M.Command)then Spring.InsertUnitCmdDesc(id,{id=M.Command,type=CMDTYPE.ICON_UNIT,name='Capture Relic',action='40kcapturerelic',tooltip='Capture a genuine Relic: source Scarab rate adaptation 61.5 seconds; enemy ownership neutralizes in 10 seconds'})end
end
function gadget:Initialize()
 gadgetHandler:RegisterCMDID(M.Command)
 relic=UnitDefNames['40k_relic_objective'];scarab=UnitDefNames.nec_scarab
 if not relic or not scarab then gadgetHandler:RemoveGadget(self);return end
 A=M.New(Spring,{relicDef=relic.id,scarabDef=scarab.id,gaiaTeam=gaia,fps=Game.gameSpeed or 30,ObjectiveRadius=110,Ready=ready,
 ObjectiveReviewed=function(id)return reviewed[id]==true end,Frame=Spring.GetGameFrame})
 A.Attach=attach;A.FindPlacement=function()local site,reason,stats=P.Find(Spring,Game,relic.id);GG.Recoil40KRelicPlacementReceipt=site;return site,reason,stats end
 if witnessEnabled then
  A.ObjectiveWitness=function()local rows={};for i,row in ipairs(witnessRows)do local copy={};for k,v in pairs(row)do copy[k]=v end;rows[i]=copy end;return rows end
 end
 GG.Recoil40KRelicCapture=A
 -- Reload requires root reattaching the still-owned neutral model/placement receipt;
 -- no model-wide or arbitrary unitparam adoption and no objective created here.
 for _,id in ipairs(Spring.GetAllUnits()or{})do
  if Spring.GetUnitDefID(id)==scarab.id then desc(id)
  elseif Spring.GetUnitDefID(id)==relic.id then
   -- Even a stale/unreviewed existing exact objective suppresses duplicate creation.
   placementAttempted=true
   if not restore(id)then Spring.Echo('40K RELIC RESTORE REFUSED',id,'stale_owner_source_map_or_position')end
  end
 end
end
function gadget:GameFrame(frame)
 if witnessEnabled and (frame==2 or frame==30)then for id in pairs(reviewed)do witness('LIVE_REVIEWED',id,relic.id,Spring.GetUnitTeam(id))end end
 if placementAttempted or frame<1 or not GG.Recoil40KResearch then return end
 placementAttempted=true
 -- Use the real ordinary creation gate; never its diagnostic/transform exception.
 local site,reason,stats=A.FindPlacement()
 if not site then
  Spring.Echo('40K RELIC PLACEMENT REFUSED',frame,reason)
  if stats then
   Spring.Echo('40K RELIC PLACEMENT FILTERS',stats.tested,stats.bounds,stats.dry_height,stats.units,stats.features,stats.native)
   for _,v in ipairs(stats.native_samples)do Spring.Echo('40K RELIC PLACEMENT NATIVE_REJECT',v.x,v.y,v.z,v.status,v.feature or -1)end
  end
  return
 end
 if GG.Recoil40KResearch.CanBuild(gaia,relic.id,nil,false)~=true then Spring.Echo('40K RELIC PLACEMENT REFUSED',frame,'native_creation_gate');return end
 local id=Spring.CreateUnit(relic.id,site.x,site.y,site.z,0,gaia,false,false)
 if not id or not A.Attach(id,site)then
  if id and Spring.ValidUnitID(id)and Spring.GetUnitDefID(id)==relic.id and Spring.GetUnitTeam(id)==gaia then Spring.DestroyUnit(id,false,true)end
  Spring.Echo('40K RELIC PLACEMENT REFUSED',frame,'native_create_or_receipt');return
 end
 Spring.SetUnitNeutral(id,true)
 witness('PLACED_REVIEWED',id,relic.id,gaia)
 Spring.Echo('40K RELIC PLACED SOURCE_ADAPTATION',frame,id,site.map,site.x,site.y,site.z)
end
function gadget:AllowCommand(id,def,team,cmd,params)
 if cmd==M.Command then return def==scarab.id and #params==1 and reviewed[params[1]]==true end
 A.Cancel(id);return true
end
function gadget:CommandFallback(id,def,team,cmd,params)
 if cmd~=M.Command then return false end
 local target=params[1];if not reviewed[target]then return true,true end
 if not A.Begin(id,target)then return true,true end
 local used,done=A.Tick(id,target,Spring.GetGameFrame())
 if done then witness('CAPTURE_END',target,relic.id,Spring.GetUnitTeam(target),Spring.GetUnitRulesParam(target,'40k_relic_owner'))end
 return used,done
end
function gadget:UnitCreated(id,def,team,builder)if relic and def==relic.id then witness('BIRTH',id,def,team,builder)end end
function gadget:UnitFinished(id,def)if def==scarab.id then desc(id)end end
function gadget:UnitPreDamaged(id,def,team,damage)if def==relic.id and reviewed[id]then return 0,0 end end
function gadget:AllowUnitTransfer(id,def)if def==relic.id then return false end;return true end
function gadget:AllowUnitBuildStep(builder,team,id,def,part)if def==relic.id then return false end;return true end
function gadget:UnitDestroyed(id,def,team,attacker,attackerDef,attackerTeam)
 if relic and def==relic.id then witness('DESTROYED',id,def,team,attacker or -1)end
 reviewed[id]=nil;A.UnitRemoved(id)
end
function gadget:UnitTaken(id)A.Cancel(id)end
function gadget:UnitGiven(id)A.Cancel(id)end
function gadget:Shutdown()if GG.Recoil40KRelicCapture==A then GG.Recoil40KRelicCapture=nil end end
