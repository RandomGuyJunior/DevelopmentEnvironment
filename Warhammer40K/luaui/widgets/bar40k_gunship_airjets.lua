function widget:GetInfo()
 return {name='40K Gunship stock airjets',desc='Attach the existing BAR airjet renderer to two measured engine outlets',
  author='Local project',layer=-2,enabled=true,handler=true}
end

local gunship=UnitDefNames.bar40k_ork_gunship
if not gunship then return false end
local S=Spring
local markers={'engine_exhaust_port','engine_exhaust_starboard'}
local tracked,attached={},{}
local api,renderer
local elapsed,poll,refreshAt=0,0,nil
local colorMode=S.GetConfigInt('AirjetsTeamColored',1)
local humanWitness=false
local warned,reported=false,false

local function liveRenderer()
 local owner=widgetHandler:FindWidget('Airjets GL4')
 local candidate=WG.airjets
 if owner and type(candidate)=='table' and type(candidate.addAirJet)=='function'
  and type(candidate.removeAirJet)=='function' then return owner,candidate end
end

local function remove(id)
 local row=attached[id]
 if not row then return end
 -- The native widget leaves WG.airjets behind on Shutdown. Never invoke that
 -- stale API after its renderer was removed or replaced.
 local owner,current=liveRenderer()
 if owner==row.renderer and current==row.api then
  for _,key in ipairs(row.keys) do current.removeAirJet(key) end
 end
 attached[id]=nil
end

local function clear()
 for id in pairs(attached) do remove(id) end
end

local function visible(id)
 local _,fullview=S.GetSpectatingState()
 return fullview or S.IsUnitAllied(id) or S.IsUnitInLos(id)
end

local function ready(id)
 if not S.ValidUnitID(id) or S.GetUnitIsDead(id) or not visible(id) then return false end
 local _,_,_,_,built=S.GetUnitHealth(id)
 if not built or built<1 or S.GetUnitIsStunned(id) then return false end
 -- Engine thrust supports a hovering hull even when it has no move order.
 -- Activation is an on/off flag, not an airborne-state query. Use the actual
 -- native hover-air state for allies; that ally-only API can return nil for
 -- visible enemies, for which height remains a visibility-safe fallback.
 local move=S.GetUnitMoveTypeData(id)
 if move and move.name=='gunship' then
  local state=move.aircraftState
  if state=='landed' or state=='crashing' then return false end
  if state=='takeoff' or state=='flying' or state=='hovering' then return true end
 end
 local x,y,z=S.GetUnitPosition(id)
 return x and y-S.GetGroundHeight(x,z)>10
end

local function reconcile(id)
 if not api or not ready(id) then remove(id);return end
 if attached[id] then return end
 local pieces=S.GetUnitPieceMap(id)
 if not pieces then return end
 for _,name in ipairs(markers) do
  if type(pieces[name])~='number' or pieces[name]<1 then return end
 end
 local row={api=api,renderer=renderer,keys={}}
 for _,name in ipairs(markers) do
  -- Pinned native API uses zero-based SSBO piece IDs and multiplies size by5.
  -- Its quad extends local -Z; negative length follows our measured +Z outlet.
  -- Shader ignores emitVector. Culling is disabled by the stock renderer.
  -- Width .6 =>18 world units, a slightly flared14.759-unit nozzle plume;
  -- length -12 =>59.4 outward units. Two persistent stock quads only;
  -- zero velocity scaling keeps their size unchanged when hovering.
  row.keys[#row.keys+1]=api.addAirJet(id,pieces[name]-1,.6,-12,
   {.1,.4,.6},{0,0,1},0,0,0)
 end
 attached[id]=row
 if humanWitness and not reported then
  reported=true
  S.Echo('40K_GUNSHIP_AIRJETS attached',id,#row.keys,pieces[markers[1]]-1,pieces[markers[2]]-1)
 end
end

local function track(id,defID)
 if (defID or S.GetUnitDefID(id))==gunship.id then tracked[id]=true end
end

local function rescan()
 for _,id in ipairs(S.GetAllUnits() or {}) do track(id) end
end

function widget:Initialize()
 renderer,api=liveRenderer()
 rescan()
end

function widget:Update(dt)
 elapsed=elapsed+dt;poll=poll+dt
 if poll<.25 then return end
 poll=0
 local owner,current=liveRenderer()
 if owner~=renderer or current~=api then
  clear();renderer,api=owner,current
 end
 if humanWitness and not api and not warned then
  warned=true;S.Echo('40K_GUNSHIP_AIRJETS renderer_unavailable')
 end
 local mode=S.GetConfigInt('AirjetsTeamColored',1)
 if mode~=colorMode then
  colorMode=mode
  -- Native Update checks this preference every .5s and clears its whole VBO.
  -- Reattach after that check, without changing the player's preference.
  refreshAt=elapsed+.75
 end
 if refreshAt and elapsed>=refreshAt then clear();refreshAt=nil end
 for id in pairs(tracked) do
  if not S.ValidUnitID(id) or S.GetUnitIsDead(id) then remove(id);tracked[id]=nil
  elseif not refreshAt then reconcile(id) end
 end
end

function widget:UnitCreated(id,defID) track(id,defID) end
function widget:UnitFinished(id,defID) track(id,defID) end
function widget:UnitGiven(id,defID) track(id,defID) end
function widget:UnitTaken(id,defID) remove(id);track(id,defID) end
function widget:UnitEnteredLos(id) track(id) end
function widget:UnitLeftLos(id) if not visible(id) then remove(id) end end
function widget:UnitDestroyed(id) remove(id);tracked[id]=nil end
function widget:CrashingAircraft(id) remove(id);tracked[id]=nil end
function widget:RenderUnitDestroyed(id) remove(id);tracked[id]=nil end
function widget:PlayerChanged() clear();rescan();refreshAt=elapsed+.75 end
function widget:Shutdown() clear();tracked={} end
