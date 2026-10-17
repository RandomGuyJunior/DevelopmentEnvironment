-- Override only attachment presentation; native admission and reservations own loading.
local M={}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function M.Install(script,S,GG,defs,unitID,unitDefID)
 local d=assert(defs[unitDefID]);local cp=d.customParams or{}
 assert(cp.animsource=='ork_looted_rhino'and cp.source_transport_policy=='one_fixed8_hidden_real_bodies_v1')
 function script.TransportPickup(passenger)
  local A=GG.Recoil40KSquadTransportAPI;local R=GG.Recoil40KSquadTransport
  local s=A and A.Get(passenger)
  if not s or s.profile~=cp.prototype40k_transport_profile or A.Capacity(s.id)~=8
   or not R or not R.Busy(passenger)or not R.Permit(unitID,passenger)
   or S.GetUnitTransporter(passenger)~=nil then return end
  for _,id in ipairs(S.GetUnitIsTransporting(unitID)or{})do
   local existing=A.Get(id);if not existing or existing.id~=s.id then return end
  end
  if #(S.GetUnitIsTransporting(unitID)or{})>=8 then return end
  -- Pinned LuaUnitScript.cpp:1457 subtracts 1: Lua 0 is native hidden piece -1.
  S.UnitScript.AttachUnit(0,passenger)
 end
 function script.TransportDrop(passenger,x,y,z)
  -- Native ownership survives save/load; no redundant script-only cargo table.
  if S.GetUnitTransporter(passenger)~=unitID then return end
  S.UnitScript.DropUnit(passenger)
  if S.GetUnitTransporter(passenger)==nil and finite(x)and finite(z)then
   -- Existing genuine ground roster's accepted native UnloadLand XZ bridge.
   S.SetUnitPosition(passenger,x,z)
  end
 end
 return script
end
return M
