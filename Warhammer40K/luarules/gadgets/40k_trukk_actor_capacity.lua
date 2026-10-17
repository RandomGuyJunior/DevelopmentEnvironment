function gadget:GetInfo()return {name='40K Trukk genuine six actor capacity',desc='Reviewed footprint admission preserves six actual source slots',author='Local project',layer=0,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local o=Spring.GetModOptions()
if o.prototype_diagnostic~='roster'or tostring(o.prototype_transport_envelope_review)~='1'then return false end
local A=VFS.Include('40k_configs/ork_trukk_actor_capacity.lua').New(Spring,UnitDefs)
function gadget:Initialize()assert(not GG.Recoil40KTrukkActorCapacity,'Duplicate Trukk actor capacity');GG.Recoil40KTrukkActorCapacity=A end
function gadget:Shutdown()if GG.Recoil40KTrukkActorCapacity==A then GG.Recoil40KTrukkActorCapacity=nil end end
local rows=0
local function v(x)if x==nil then return 'UNKNOWN'end;return x end
function gadget:AllowUnitTransport(truck,truckDef,truckTeam,passenger,passengerDef,passengerTeam)
 local okay,reason,r=A.Permit(truck,passenger)
 if r.reason~='ordinary_unmodified'and rows<96 then
  rows=rows+1
  local tx,ty,tz=Spring.GetUnitPosition(truck);local px,py,pz=Spring.GetUnitPosition(passenger)
  local head=Spring.GetUnitCommands(truck,1);head=head and head[1]
  Spring.Echo('40K TRUKK ADMISSION',Spring.GetGameFrame(),truck,truckDef,truckTeam,passenger,passengerDef,passengerTeam,okay,reason,
   'source',v(r.source),'role',v(r.role),'faction',v(r.faction),'prototype',v(r.prototype),'name',v(r.name),'xsize',v(r.xsize),'footprint',v(r.footprint),
   'members',v(r.members),'used',v(r.used),'capacity',v(r.capacity),'maxSize',v(r.maxSize),'passengerMass',v(r.passengerMass),'mass',v(r.mass),'massLimit',v(r.massLimit),
   'truckPos',v(tx),v(ty),v(tz),'passengerPos',v(px),v(py),v(pz),'distance2D',tx and px and math.sqrt((tx-px)^2+(tz-pz)^2)or 'UNKNOWN',
   'loadRadius',v(UnitDefs[truckDef]and UnitDefs[truckDef].loadingRadius),'head',head and head.id or 'none','tag',head and head.tag or 'none','native_followup_not_observed',true)
 end
 return okay
end
