-- Native whole-squad reservations own admission; this adapter owns presentation.
local M={Policy='wartrukk_fixed8_hidden_real_bodies_v1'}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.Install(script,S,G,D,id,def)
 local d=assert(D[def]);local cp=d.customParams or{}
 assert(cp.animsource=='ork_trukk'and cp.source_transport_policy==M.Policy and tonumber(cp.source_transport_actor_capacity)==8
  and tonumber(cp.prototype40k_transport_squad_limit)==1,'Exact full8 Wartrukk only')
 function script.TransportPickup(passenger)
  local A=G.Recoil40KSquadTransportAPI;local R=G.Recoil40KSquadTransport
  local squad=A and A.Get(passenger);local capacity=squad and A.Capacity(squad.id)
  if not squad or not finite(capacity)or capacity<1 or capacity>8 or not R or not R.Busy(passenger)
   or not R.Permit(id,passenger)or S.GetUnitTransporter(passenger)~=nil then return end
  local cargo=S.GetUnitIsTransporting(id);if type(cargo)~='table'or #cargo>=8 then return end
  for _,body in ipairs(cargo)do local other=A.Get(body);if not other or other.id~=squad.id then return end end
  -- Lua attachment piece0 is native hidden -1. Every passenger remains its
  -- existing real actor; there is no visual proxy, birth or shared payment.
  S.UnitScript.AttachUnit(0,passenger)
 end
 function script.TransportDrop(passenger,x,y,z)
  if S.GetUnitTransporter(passenger)~=id then return end
  if G.Recoil40KGroundLandings then G.Recoil40KGroundLandings[passenger]=nil end
  S.UnitScript.DropUnit(passenger)
  if S.GetUnitTransporter(passenger)==nil and finite(x)and finite(z)then
   -- Same supported native ground-UnloadLand XZ bridge as the retained Trukk.
   S.SetUnitPosition(passenger,x,z)
   local lx,ly,lz=S.GetUnitPosition(passenger)
   if lx==x and lz==z and S.GetUnitTransporter(passenger)==nil then
    G.Recoil40KGroundLandings=G.Recoil40KGroundLandings or{}
    G.Recoil40KGroundLandings[passenger]={frame=S.GetGameFrame(),transport=id,x=lx,y=ly,z=lz}
   end
  end
 end
 function script.Killed()
  -- Existing native releaseHeld policy owns cargo survival/death. The shared
  -- body-remains owner stays responsible for any actual casualty; this chassis
  -- returns only its one native wreck and adds no cargo refunds or corpses.
  local _,_,_,_,progress=S.GetUnitHealth(id)
  return type(progress)=='number'and progress>=1 and 1 or 0
 end
 return script
end
return M
