-- Native footprint units, six logical passengers and model attachment points are distinct.
local M={}
function M.IsOwned(d)
 local c=d and(d.customParams or d.customparams)or {}
 return d and d.name=='ork_trukk'and c.animsource=='ork_trukk'and c.source_transport_capacity_policy=='six_actors_footprint4_v1'and tonumber(c.source_transport_actor_capacity)==6
end
function M.ActorCapacity(d,slots)
 local c=d and(d.customParams or d.customparams)or {};local n=tonumber(c.source_transport_actor_capacity)
 if n then assert(n==6 and type(slots)=='number' and slots>=1,'Missing genuine cargo attachment point');return n end
 return tonumber(d and(d.transportCapacity or d.transportcapacity))or slots
end
function M.Preflight(tu,su)
 local footprint=su and(su.xsize and su.xsize/2 or su.footprintX or su.footprintx)
 if not footprint or not su.mass or not tu.transportMass or su.mass*6>tu.transportMass or footprint>tonumber(tu.transportSize or 0)then return false end
 if M.IsOwned(tu)then return tu.transportCapacity==24 and tu.transportSize==4 and footprint==4 and M.ActorCapacity(tu,6)==6 end
 return tu.transportCapacity==6 and footprint==1
end
function M.New(S,defs)
 local A={}
 local function eligible(id)
  local d=defs[S.GetUnitDefID(id)];local c=d and(d.customParams or d.customparams)or {}
  local footprint=d and(d.xsize and d.xsize/2 or d.footprintX or d.footprintx)
  return d and tonumber(c.prototype40k)==1 and c.faction=='Orks'and c.animsource and
   (c.rosterrole=='infantry'or c.animsource=='ork_grot'or c.animsource=='ork_warboss')and
   d.canFly~=true and d.canfly~=true and type(footprint)=='number'and footprint>=1 and footprint<=4 and d.mass and d.mass>0,footprint,d
 end
 function A.Permit(truck,passenger)
  local td=S.GetUnitDefID(truck);local pdID=S.GetUnitDefID(passenger);local d=defs[td];local pd=defs[pdID];local c=pd and(pd.customParams or pd.customparams)or {}
  local r={truck=truck,passenger=passenger,truckDef=td,passengerDef=pdID,name=pd and pd.name,role=c.rosterrole,faction=c.faction,source=c.animsource,prototype=c.prototype40k,xsize=pd and pd.xsize,capacity=d and(d.transportCapacity or d.transportcapacity),maxSize=d and(d.transportSize or d.transportsize),massLimit=d and(d.transportMass or d.transportmass)}
  local function result(ok,why)r.allowed=ok;r.reason=why;return ok,why,r end
  if not M.IsOwned(d)then return result(true,'ordinary_unmodified')end
  local members=S.GetUnitIsTransporting(truck);if type(members)~='table'then return result(false,'membership_unreadable')end
  r.members=#members
  if #members>=6 then return result(false,'six_actors_full')end
  local ok,sz,ud=eligible(passenger);r.footprint=sz;r.passengerMass=ud and ud.mass
  if not ok then return result(false,'source_actor_ineligible')end
  local mass,used=ud.mass,sz
  for _,id in ipairs(members)do if id==passenger then return result(false,'already_member')end;local yes,size,memberDef=eligible(id);if not yes then return result(false,'existing_member_unreadable')end;mass=mass+memberDef.mass;used=used+size end
  r.used=used;r.mass=mass
  if used>tonumber(d.transportCapacity or d.transportcapacity or 0)then return result(false,'native_footprint_budget')end
  if mass>tonumber(d.transportMass or d.transportmass or 0)then return result(false,'native_mass_budget')end
  -- The engine still independently applies native CanTransport/size/unfinished/team/mass checks.
  return result(true,'six_actor_policy_allows_native_followup')
 end
 return A
end
return M
